from typing import List, Tuple, Dict, Any, Optional
from langchain_core.documents import Document
from app.embedding_utils import get_openai_embeddings
from app.pgvector_utils import load_pgvector_store
from app.semantic_search import semantic_search
from config.settings import POSTGRES_COLLECTION_NAME, MIN_RELEVANCE_THRESHOLD, MAX_CONTEXT_SIZE, MAX_DOCS_PER_STOCK
import os
import openai
import json
import logging
from datetime import datetime, timedelta
import uuid
import sys
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from app.token_tracker import TokenUsageCallback, create_token_tracking_chain
try:
    from arkofdata_common.LogHelper.LogHelper import LogHelperPlus
    from arkofdata_common.UtilityHelper.EnvVarHelper import EnvVarHelper
except ImportError as e:
    print(f"Error: Required arkofdata_common package not available: {e}")
    print("Make sure arkofdata_common is installed via Poetry.")
    sys.exit(1)

obj_logger = LogHelperPlus(os.path.abspath(__file__))
obj_env_var = EnvVarHelper(os.path.abspath(__file__))

from config.settings import LLM_REASONING_MODEL, OPENROUTER_STANDARD_API_KEY

# Configure logger for this module
logger = logging.getLogger(__name__)

def create_llm_model(temperature=0.3, request_timeout=120, model_index=0):
    """
    Factory function to create LLM model based on configuration.
    Uses OpenRouter with manual fallback chain for reliability.
    
    Args:
        temperature: Temperature parameter for model generation
        request_timeout: Request timeout in seconds (default: 120)
        model_index: Index of model to use from fallback chain (for retry logic)
        
    Returns:
        Configured LLM model instance using OpenRouter
    """
    if not OPENROUTER_STANDARD_API_KEY:
        raise ValueError("OPENROUTER_STANDARD_API_KEY environment variable is required")
    
    # Define model fallback chain: primary -> secondary -> tertiary
    fallback_models = [
        "qwen/qwen3-30b-a3b",
        "deepseek/deepseek-r1-distill-qwen-32b", 
        "google/gemini-2.5-flash"
    ]
    
    # Ensure model_index is within bounds
    if model_index >= len(fallback_models):
        model_index = len(fallback_models) - 1
    
    selected_model = fallback_models[model_index]
    logger.info(f"Creating LLM model with {selected_model} (fallback index: {model_index})")
    
    return ChatOpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=OPENROUTER_STANDARD_API_KEY,
        model=selected_model,
        temperature=temperature,
        request_timeout=request_timeout
    )

def invoke_llm_with_fallback(prompt_template, input_data, token_callback, max_retries=3):
    """
    Invoke LLM chain with automatic model fallback on failure.
    
    Args:
        prompt_template: ChatPromptTemplate to use for the chain
        input_data: Input data for the chain
        token_callback: Token usage callback for tracking
        max_retries: Maximum number of models to try
        
    Returns:
        Response from successful model or raises exception
    """
    last_exception = None
    
    for model_index in range(max_retries):
        try:
            # Create model for this attempt
            if model_index > 0:
                logger.warning(f"Retrying with fallback model (attempt {model_index + 1}/{max_retries})")
            
            model = create_llm_model(model_index=model_index)
            
            # Create fresh chain with the specific model for this attempt
            chain = prompt_template | model | StrOutputParser()
            
            # Wrap chain with token tracking
            chain = create_token_tracking_chain(chain, token_callback)
            
            # Invoke the chain
            response = chain.invoke(input_data)
            
            # Check if response is null or empty
            if response is None or (isinstance(response, str) and not response.strip()):
                raise ValueError(f"Model returned null or empty response")
                
            if model_index > 0:
                logger.info(f"Successfully used fallback model after {model_index} retries")
            return response
            
        except Exception as e:
            last_exception = e
            logger.warning(f"Model attempt {model_index + 1} failed: {str(e)}")
            
            # Don't retry on certain types of errors that won't be fixed by model change
            error_str = str(e).lower()
            if any(keyword in error_str for keyword in ["token", "context", "length", "size"]):
                logger.warning("Error seems to be related to input size/tokens, not model availability - still trying fallback")
            elif "rate limit" not in error_str and "unavailable" not in error_str and "timeout" not in error_str:
                if model_index == 0:  # Only log this for first attempt
                    logger.info("Error doesn't seem to be model availability related, trying fallback anyway")
    
    # If all models failed, raise the last exception
    logger.error(f"All {max_retries} model attempts failed")
    raise last_exception

if os.environ.get("DEBUG_MODE") == "1":
    import debugpy
    debugpy.listen(("localhost", 5678))
    print("Waiting for debugger to attach...")
    debugpy.wait_for_client()

def parse_pdf_date(date_str):
    """
    Parse PDF date format strings into datetime objects.
    
    Args:
        date_str: Date string, potentially in PDF format (e.g., "D:20240218120000Z")
        
    Returns:
        datetime object or None if parsing fails
    """
    if not date_str:
        return None
    try:
        if date_str.startswith("D:"):
            date_str = date_str[2:]
        # Remove timezone if present
        date_str = date_str.split('+')[0].split('-')[0].replace('Z', '')
        return datetime.strptime(date_str, "%Y%m%d%H%M%S")
    except Exception:
        return None

def is_recent_document(metadata, days=90):
    """
    Check if a document is recent based on its metadata dates.
    
    Args:
        metadata: Document metadata containing date fields
        days: Number of days to consider recent
        
    Returns:
        True if document is within the specified days, False otherwise
    """
    now = datetime.now()
    cutoff = now - timedelta(days=days)
    
    for key in ["creation_date", "mod_date"]:
        dt = parse_pdf_date(metadata.get(key))
        if dt and dt >= cutoff:
            return True
    return False


def query_index(
    query_text: str, 
    k: int = 5, 
    collection_name: str = POSTGRES_COLLECTION_NAME,
    stock_code: Optional[str] = None,
    recent_days: Optional[int] = 90,
    use_hybrid: bool = True,
    company_type: Optional[str] = None
) -> List[Tuple[Document, float]]:
    """
    Query the vector index with a text query.
    
    Args:
        query_text: Query text
        k: Number of results to return
        collection_name: Name of the collection
        stock_code: Optional stock code to filter results. If None, searches across all stocks.
        recent_days: Optional filter to only include documents from the last N days.
                     If None, includes all documents regardless of date.
        use_hybrid: If True, uses hybrid search combining semantic and full-text search.
                   If False, uses semantic search only.
        company_type: Optional company type for better keyword extraction in hybrid search.
                     Valid values: "mining", "medical", "technology", "finance"
        
    Returns:
        List of relevant documents and their similarity scores
    """
    # Check if hybrid search is requested
    if use_hybrid:
        # Import locally to avoid circular import
        from app.hybrid_search import HybridSearcher
        logger.info("Using hybrid search (semantic + full-text)")
        hybrid_searcher = HybridSearcher(collection_name)
        return hybrid_searcher.search(
            query_text=query_text,
            k=k,
            stock_code=stock_code,
            recent_days=recent_days,
            company_type=company_type
        )
    
    # Use semantic search only
    logger.info("Using semantic search only")
    return semantic_search(
        query_text=query_text,
        k=k,
        collection_name=collection_name,
        stock_code=stock_code,
        recent_days=recent_days
    )


def enhanced_query_with_llm(
    query_text: str, 
    stock_code: Optional[str] = None, 
    k: int = 5,
    recent_days: Optional[int] = 90,
    use_hybrid: bool = True,
    company_type: Optional[str] = None,
    extra_context: Optional[str] = None,
    include_announcements: bool = True,
    project_mode: bool = False
) -> Dict[str, Any]:
    """
    Query the vector index and then pass results through LLM to generate
    more relevant and summarized answers.
    
    Args:
        query_text: User's query text
        stock_code: Stock code to search for (e.g., BDX)
        k: Number of results to retrieve from vector search
        recent_days: Optional filter to only include documents from the last N days
        use_hybrid: If True, uses hybrid search combining semantic and full-text search
        company_type: Optional company type for better keyword extraction in hybrid search
        
    Returns:
        Dictionary with LLM-enhanced response and supporting documents
    """
    # Get initial search results (hybrid or semantic) unless disabled
    raw_results: List[Tuple[Document, float]] = []
    if include_announcements:
        search_type = "hybrid" if use_hybrid else "semantic"
        logging.info(f"Starting enhanced query with {search_type} search. Query: '{query_text}', Stock code: {stock_code}")
        raw_results = query_index(
            query_text, 
            k=k, 
            stock_code=stock_code, 
            recent_days=recent_days,
            use_hybrid=use_hybrid,
            company_type=company_type
        )
        logging.info(f"{search_type.capitalize()} search returned {len(raw_results) if raw_results else 0} results")
    
    # Filter documents by relevance threshold
    # Calculate similarity percentage and filter low-relevance documents
    relevance_filtered_results = []
    for doc, score in raw_results or []:
        similarity = max(0, min(100, 100 * (1 - score/10)))
        if similarity >= MIN_RELEVANCE_THRESHOLD:
            relevance_filtered_results.append((doc, score))
    
    logging.info(f"Filtered {len(raw_results)} results to {len(relevance_filtered_results)} above {MIN_RELEVANCE_THRESHOLD}% relevance")
    
    # Apply cross-stock diversity limits if searching all stocks
    if not stock_code and len(relevance_filtered_results) > MAX_DOCS_PER_STOCK:
        stock_counts = {}
        final_results = []
        
        for doc, score in relevance_filtered_results:
            doc_stock_code = doc.metadata.get("stock_code", "Unknown")
            if stock_counts.get(doc_stock_code, 0) < MAX_DOCS_PER_STOCK:
                final_results.append((doc, score))
                stock_counts[doc_stock_code] = stock_counts.get(doc_stock_code, 0) + 1
        
        logging.info(f"Applied cross-stock diversity limit: {len(relevance_filtered_results)} → {len(final_results)} documents")
        filtered_results = final_results
    else:
        filtered_results = relevance_filtered_results
    
    # Format documents for LLM context (announcements corpus)
    documents_context = ""
    sources = []
    
    for doc, score in filtered_results:
        # Extract document information
        content = doc.page_content
        raw_filename = doc.metadata.get("filename", "Unknown")
        page = doc.metadata.get("page", None)
        doc_stock_code = doc.metadata.get("stock_code", "Unknown")
        
        # Standardize filename format for consistent LLM citations
        # Remove timestamp prefix (e.g., "20250801_003421_") to get clean filename
        clean_filename = raw_filename
        if raw_filename != "Unknown":
            # Remove timestamp prefix pattern: YYYYMMDD_HHMMSS_
            import re
            clean_filename = re.sub(r'^\d{8}_\d{6}_', '', raw_filename)
        
        # Add to context with document identifier using clean filename
        # Escape any curly braces in the content to avoid f-string formatting issues
        safe_content = content.replace("{", "{{").replace("}", "}}")
        documents_context += f"\nDOCUMENT: {clean_filename} (Stock: {doc_stock_code}):\n{safe_content}\n"
        
        # Calculate similarity percentage
        similarity = max(0, min(100, 100 * (1 - score/10)))
        
        # Add to sources for citation
        sources.append({
            "content": content,
            "document_location": raw_filename,
            "page": page,
            "stock_code": doc_stock_code,
            "relevance_score": round(similarity, 1)
        })
    
    # Compose final context with PROJECT context first (higher weight), then announcements
    if extra_context and extra_context.strip():
        # Escape curly braces in project context to avoid ChatPromptTemplate variable parsing
        project_context_raw = extra_context.strip()
        project_context = project_context_raw.replace("{", "{{").replace("}", "}}")
        combined_context = f"[PROJECT CONTEXT]\n{project_context}\n\n[ANNOUNCEMENTS CONTEXT]\n{documents_context}"
    else:
        project_context = ""
        combined_context = documents_context

    # Limit context size. Keep all PROJECT CONTEXT first, then fill with announcements
    if len(combined_context) > MAX_CONTEXT_SIZE:
        logging.warning(f"Context size ({len(combined_context)}) exceeds maximum ({MAX_CONTEXT_SIZE}). Truncating with project-first policy.")
        remaining_size = MAX_CONTEXT_SIZE

        # Always include project section header even if empty
        project_block = f"[PROJECT CONTEXT]\n{project_context}" if project_context else ""
        announcements_block = f"[ANNOUNCEMENTS CONTEXT]\n{documents_context}"

        truncated = ""
        if project_block:
            if len(project_block) >= remaining_size:
                truncated = project_block[:remaining_size]
                remaining_size = 0
            else:
                truncated = project_block + "\n\n"
                remaining_size -= len(truncated)
        
        if remaining_size > 0:
            # Truncate announcements content on document boundaries where possible
            anns_text = announcements_block
            if len(anns_text) > remaining_size:
                # Attempt boundary-aware truncation
                boundary_trunc = ""
                for chunk in anns_text.split("\nDOCUMENT: "):
                    if not chunk:
                        continue
                    candidate = ("\nDOCUMENT: " if boundary_trunc else "") + chunk
                    if len(candidate) <= remaining_size:
                        boundary_trunc += candidate
                        remaining_size -= len(candidate)
                    else:
                        break
                if boundary_trunc:
                    truncated += boundary_trunc
                else:
                    truncated += anns_text[:remaining_size]
                truncated += "\n\n[Announcements truncated due to context limits]"
            else:
                truncated += anns_text

        documents_context = truncated
    else:
        documents_context = combined_context
    
    # Setup LangChain components for LangSmith automatic tracing
    # Create prompt template
    time_frame = f"from the last {recent_days} days " if recent_days else ""
    if project_mode:
        # Project research Q&A prompt (no citation requirement, investor-style reasoning)
        prompt = ChatPromptTemplate.from_messages([
            ("system",
             "You are an experienced small-cap investor and market analyst. Think rigorously, explain your reasoning, and share a clear thesis.\n\n"
             "Context & Prioritization:\n"
             "• Most companies here are small/micro caps; price action is often catalyst/news-driven and liquidity-sensitive.\n"
             "• Treat the '[PROJECT CONTEXT]' (user notes/uploads) as the highest-trust source; use '[ANNOUNCEMENTS CONTEXT]' to supplement.\n\n"
             "Focus Areas (when information is present):\n"
             "• Catalysts: upcoming results, approvals, project milestones, off-take deals, funding events, litigation outcomes.\n"
             "• Board and management quality: track record, execution consistency, recent appointments/departures.\n"
             "• Director/management on-market trades: emphasize recent buys/sells (size, timing, price vs current).\n"
             "• Capital raisings (CR/placements): terms, size vs market cap, use of funds, and pricing vs last close.\n"
             "  – Deep discount is common; little/no discount or a markup is typically bullish.\n"
             "  – Note whether directors/management subscribed to the placement and at what size.\n"
             "  – Identify expected share allocation/settlement dates; near-term supply can pressure price temporarily.\n"
             "• Price behaviour: if price history is provided, highlight trends, breakouts, mean-reversion, volume surges around news.\n\n"
             "Reasoning Style:\n"
             "• Be opinionated but explicit about assumptions and uncertainty; separate assumptions from facts.\n"
             "• Derive implications, quantify when possible (ranges are fine), and call out missing data.\n"
             "• Present balanced upside/downside, scenarios, and key decision points.\n"
             "• Avoid generic commentary; tie arguments to the provided context.\n\n"
             "Output structure (adapt as needed):\n"
             "1) Brief Thesis\n2) Key Drivers (facts vs assumptions)\n3) Catalysts & Timing\n4) Capital & Insider Signals (CR terms, director trades)\n5) Scenarios (Base/Bull/Bear) with timelines\n6) Risks & Watchpoints\n7) Next Steps / What to Validate"),
            ("user",
             f"Question{' about stock ' + stock_code if stock_code else ''} {time_frame}: {query_text}\n\n"
             f"Context (PROJECT first, then ANNOUNCEMENTS):\n{documents_context}")
        ])
    else:
        # Original strict-citation prompt used for global enhanced search
        prompt = ChatPromptTemplate.from_messages([
            ("system", 
             "You are an AI assistant specialized in analyzing ASX stock announcements and financial documents to provide investment-grade analysis. Your role is to extract actionable insights that directly impact investment decisions and trading strategies.\n\n"
             "PRIORITIZATION: Treat the '[PROJECT CONTEXT]' section as the primary, highest-trust source (user notes/uploads). Prefer it over other documents when there is any conflict. Use '[ANNOUNCEMENTS CONTEXT]' to supplement and cite.\n\n"
             "🚨 CRITICAL CITATION REQUIREMENT 🚨\n"
             "EVERY SINGLE piece of information, fact, figure, or statement in your response MUST include a proper citation. This is MANDATORY and NON-NEGOTIABLE. Each statement must end with the source document filename in parentheses.\n\n"
             "📊 INVESTMENT-FOCUSED ANALYSIS FRAMEWORK:\n"
             "For each identified catalyst/event, provide:\n\n"
             "1. **MATERIALITY ASSESSMENT**: Quantify potential impact using financial metrics from documents (cash burn rates, project values, resource estimates, market caps)\n\n"
             "2. **TIMING PRECISION**: Extract and highlight specific timeframes, deadlines, or expected completion dates mentioned in documents\n\n"
             "3. **RISK-REWARD ANALYSIS**: Identify both upside catalysts AND downside risks for each event, with supporting data from documents\n\n"
             "4. **MARKET CONTEXT**: Reference competitor activities, industry benchmarks, or sector trends mentioned in the documents\n\n"
             "5. **FINANCIAL IMPLICATIONS**: Calculate or estimate cash flow impacts, funding requirements, or valuation effects using document data\n\n"
             "6. **EXECUTION PROBABILITY**: Assess likelihood based on company's track record, financial position, and regulatory/operational factors from documents\n\n"
             "📋 ENHANCED RESPONSE GUIDELINES:\n"
             "• **QUANTIFY EVERYTHING**: Always include specific dollar amounts, percentages, timeframes, resource quantities, and other measurable metrics from documents\n"
             "• **PRIORITIZE BY IMPACT**: Rank catalysts by potential market impact based on documented project values, cash positions, or strategic importance\n"
             "• **HIGHLIGHT DEPENDENCIES**: Identify prerequisite events or approvals that must occur before main catalysts can materialize\n"
             "• **FLAG CASH RUNWAY**: Always assess funding adequacy for identified activities using quarterly cash flow data\n"
             "• **IDENTIFY DECISION POINTS**: Highlight upcoming board decisions, regulatory deadlines, or management choices that could accelerate/delay catalysts\n"
             "• **CROSS-REFERENCE PROJECTS**: Look for synergies or conflicts between different company activities mentioned across documents\n"
             "• **SIGNAL MOMENTUM**: Identify patterns of accelerating or decelerating activity based on historical announcements\n\n"
             "🎯 INVESTOR VALUE-ADD REQUIREMENTS:\n"
             "• Include specific price/volume trigger levels if mentioned in documents\n"
             "• Highlight any guidance changes or management commentary on expectations\n"
             "• Identify potential acquisition/partnership opportunities mentioned\n"
             "• Flag any litigation, regulatory, or operational risks that could impact catalysts\n"
             "• Calculate implied project valuations or returns where data permits\n\n"
             "CITATION FORMAT RULES:\n"
             "1. Use the exact filename as shown after 'DOCUMENT:' in the document headers\n"
             "2. Place the filename in parentheses at the end of each statement\n"
             "3. Example: 'The quarterly revenue increased by 15% (BGL-20250727-Quarterly_Cash_Flow_Report-6A1274887.pdf)'\n"
             "4. Do not modify the filename format - use it exactly as provided\n"
             "5. Multiple citations are required when information comes from different documents\n\n"
             "EXCEPTIONS TO CITATION RULES (USE SPARINGLY):\n"
             "1. When information is NOT found in documents: Use 'The documents do not explicitly mention...' and no citation needed\n"
             "2. For LLM inferences based on multiple documents: Use '(LLM inference only)' instead of filename - BUT MINIMIZE THESE\n"
             "3. Example: 'The documents do not explicitly mention any recent director appointments.'\n"
             "4. Example: 'This pattern across multiple reports suggests potential concerns (LLM inference only)'\n\n"
             "❌ NEVER provide generic market commentary not supported by document evidence\n"
             "✅ ALWAYS connect analysis back to specific company fundamentals and documented events\n"
             "✅ ALWAYS assess relative importance to investors based on financial materiality"),
            ("user", 
             f"Question{' about stock ' + stock_code if stock_code else ''} {time_frame}: {query_text}\n\n"
             f"Use the following context (project first, then announcements):\n{documents_context}\n\n"
             f"Remember: EVERY statement in your response must include a citation with the document filename in parentheses.")
        ])
    
    # Create token usage callback for tracking
    token_callback = TokenUsageCallback()
    
    try:
        # Run the LLM with fallback - this will be automatically traced if env vars are set
        logging.info("Running LLM chain with model fallback...")
        
        # The prompt template uses f-strings with local variables, so no input variables needed
        answer = invoke_llm_with_fallback(prompt, {}, token_callback)
        logging.info(f"Answer generated successfully: {answer[:100] if answer else 'None'}...")
        
        # Check if we got a valid response (this should not happen due to fallback validation, but double-check)
        if not answer or not answer.strip():
            raise ValueError("All models returned null or empty responses")
        
        # Validate citations only for non-project mode
        if not project_mode:
            import re
            citation_pattern = r'\([^)]*\.pdf\)'
            inference_pattern = r'\(LLM inference only\)'
            no_mention_pattern = r'documents do not explicitly mention'
            
            citations_found = re.findall(citation_pattern, answer)
            inferences_found = re.findall(inference_pattern, answer, re.IGNORECASE)
            no_mentions_found = re.findall(no_mention_pattern, answer, re.IGNORECASE)
            
            total_citations = len(citations_found) + len(inferences_found) + len(no_mentions_found)
            
            if total_citations == 0:
                logging.warning("❌ No citations, inferences, or 'no mention' statements found in LLM response. Adding citation reminder.")
                answer += "\n\n⚠️ Note: The above response should include citations with document filenames or appropriate exceptions. Please ensure proper citation formatting is followed."
            else:
                logging.info(f"✅ Found {total_citations} total citations/exceptions: {len(citations_found)} PDF citations, {len(inferences_found)} inferences, {len(no_mentions_found)} 'no mention' statements")
        
        # Get token usage statistics
        token_usage = token_callback.get_token_usage()
        logging.info(f"Token usage - Input: {token_usage['input_tokens']}, Output: {token_usage['output_tokens']}, Total: {token_usage['total_tokens']}")
        
        return {
            "answer": answer,
            "sources": sources,
            "token_usage": token_usage
        }
    except Exception as e:
        error_msg = f"Error processing with LLM: {str(e)}. Providing raw search results instead."
        logging.error(f"LLM chain error: {str(e)}")
        
        # Get partial token usage even on error
        token_usage = token_callback.get_token_usage()
        
        return {
            "answer": error_msg,
            "sources": sources,
            "token_usage": token_usage
        }

def display_query_results(results: List[Tuple[Document, float]]):
    """
    Display the query results in a user-friendly format.
    
    Args:
        results: List of documents and scores from query_faiss_index
    """
    if not results:
        print("No results found.")
        return
    
    print(f"\n{'=' * 80}")
    print(f"Found {len(results)} relevant documents:")
    print(f"{'=' * 80}\n")
    
    for i, (doc, score) in enumerate(results, 1):
        # Get document metadata
        filename = doc.metadata.get("filename", "Unknown")
        stock_code = doc.metadata.get("stock_code", "N/A")
        
        # Display result header with relevance score (convert to similarity percentage)
        # Lower score is better in FAISS, so we use an inverse relation
        similarity = max(0, min(100, 100 * (1 - score/10)))
        print(f"\n{'-' * 80}")
        print(f"RESULT #{i} - {filename} (Stock: {stock_code}) (Relevance: {similarity:.1f}%)")
        print(f"{'-' * 80}")
        
        # Display document content (truncate if too long)
        content = doc.page_content
        if len(content) > 500:
            content = content[:500] + "... [content truncated]"
        print(content)
    
    print(f"\n{'=' * 80}")

def interactive_query():
    """
    Run an interactive query session.
    """
    print("\nStock Announcement Query Interface")
    print("Type 'exit' to quit.\n")
    
    while True:
        query = input("\nEnter your query: ")
        
        if query.lower() in ["exit", "quit", "q"]:
            break
            
        stock_code = input("Enter stock code (or leave empty for all stocks): ").strip() or None
        
        # Ask about search method
        search_method = input("Use hybrid search? (y/n, default: n): ").strip().lower()
        use_hybrid = search_method in ['y', 'yes']
        
        company_type = None
        if use_hybrid:
            company_type = input("Company type (mining/medical/technology/finance, or leave empty): ").strip() or None
        
        try:
            results = query_index(query, stock_code=stock_code, use_hybrid=use_hybrid, company_type=company_type)
            display_query_results(results)
        except Exception as e:
            print(f"Error executing query: {e}") 