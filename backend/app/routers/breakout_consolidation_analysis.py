from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Dict, Any, List
from datetime import date, datetime
from pathlib import Path
from app.routers.auth import verify_credentials
from app.services.breakout_data_service import BreakoutDataService
from app.services.breakout_cache_service import BreakoutCacheService
from app.services.llm_prediction_service import LLMPredictionService
from app.services.signal_strength_parser import SignalStrengthParser
from app.services.signal_strength_db_service import SignalStrengthDBService
import logging

router = APIRouter(prefix="/api", tags=["breakout-consolidation-analysis"])
logger = logging.getLogger("app.breakout_consolidation_analysis")

TEMPLATE_PATH = Path("prompt_template/breakout_consolidation/template.md")


@router.get("/breakout-consolidation-stock-codes")
def get_breakout_consolidation_stock_codes(
    observation_date: date = Query(..., description="Observation date, e.g. 2026-01-09"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    """
    Returns list of stock codes with CONSOLIDATION pattern for given observation date.

    Args:
        observation_date: Observation date for query
        username: Authenticated username (injected by dependency)

    Returns:
        List of dictionaries containing ASXCode and related fields
    """
    try:
        breakout_service = BreakoutDataService()

        logger.info(f"Querying consolidation stock codes for {observation_date} (user: {username})")
        stock_codes = breakout_service.get_consolidation_stock_codes(observation_date)

        logger.info(f"Found {len(stock_codes)} consolidation stocks for {observation_date}")
        return stock_codes

    except Exception as e:
        logger.error(f"Error querying consolidation stock codes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/breakout-consolidation-analysis")
def get_breakout_consolidation_analysis(
    observation_date: date = Query(..., description="Observation date, e.g. 2026-01-09"),
    stock_code: str = Query(..., min_length=1, description="Stock code, e.g. SKK.AX"),
    regenerate: bool = Query(False, description="Force regeneration even if cached file exists"),
    model: str = Query("google/gemini-2.5-flash", description="LLM model to use for generation"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns breakout consolidation analysis markdown content.
    Checks cache first, generates via LLM if needed.

    Args:
        observation_date: Observation date for analysis
        stock_code: Stock code (e.g., SKK.AX)
        regenerate: Force regeneration bypassing cache
        model: LLM model name (e.g., google/gemini-2.5-flash, openai/gpt-4o-2024-11-20)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - analysis_markdown: Markdown content
        - cached: Whether result was from cache
        - cache_file: Cache filename
        - observation_date: Observation date string
        - stock_code: Stock code
        - token_usage: LLM token usage (if generated)
        - generated_at: ISO timestamp
        - signal_strength: Extracted signal strength (if available)
    """
    try:
        # Initialize services
        cache_service = BreakoutCacheService()
        breakout_service = BreakoutDataService()
        llm_service = LLMPredictionService()

        # Normalize stock code
        normalized_code = breakout_service.normalize_stock_code(stock_code)

        logger.info(
            f"Breakout consolidation analysis request for {normalized_code} on {observation_date} "
            f"(regenerate={regenerate}, model={model}, user={username})"
        )

        # Check cache if not regenerating
        cached_analysis = None
        if not regenerate:
            cached_analysis = cache_service.get_cached_prediction(normalized_code, observation_date)

        if cached_analysis is not None:
            # Return cached analysis
            logger.info(f"Returning cached analysis for {normalized_code}")
            return {
                "analysis_markdown": cached_analysis,
                "cached": True,
                "cache_file": cache_service.get_cache_filename(normalized_code, observation_date),
                "observation_date": observation_date.isoformat(),
                "stock_code": normalized_code,
                "token_usage": None,
                "generated_at": datetime.now().isoformat()
            }

        # Generate new analysis
        logger.info(f"Generating new analysis for {normalized_code}")

        # Step 1: Get the BreakoutDate (when the breakout actually occurred)
        try:
            breakout_date = breakout_service.get_breakout_date(normalized_code, observation_date)
            logger.info(f"Using BreakoutDate: {breakout_date} for broker transaction query")
        except ValueError as ve:
            raise HTTPException(status_code=404, detail=str(ve))
        except Exception as e:
            logger.error(f"Failed to get BreakoutDate: {e}")
            raise HTTPException(
                status_code=503,
                detail=f"Failed to get BreakoutDate: {str(e)}"
            )

        # Step 2: Query price history data
        try:
            price_history_rows = breakout_service.get_price_history(normalized_code, observation_date)
            if not price_history_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No price history found for {normalized_code} up to {observation_date}"
                )
            logger.info(f"Retrieved {len(price_history_rows)} price history rows for {normalized_code}")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Price history query failed: {e}")
            raise HTTPException(
                status_code=503,
                detail=f"Failed to query price history: {str(e)}"
            )

        # Step 3: Query broker transaction data (using BreakoutDate, not ObservationDate)
        try:
            broker_transaction_rows = breakout_service.get_broker_transactions(
                normalized_code, breakout_date  # Use breakout date instead of observation date
            )

            # VALIDATION: Broker transaction data is required - fail if missing
            if not broker_transaction_rows:
                error_msg = (
                    f"No broker transaction data found for {normalized_code} on breakout date {breakout_date}. "
                    f"Cannot generate analysis without broker tape reading data. "
                    f"Please verify that broker transaction data exists for this stock and date."
                )
                logger.error(error_msg)
                raise HTTPException(status_code=404, detail=error_msg)

            logger.info(
                f"Retrieved {len(broker_transaction_rows)} broker transaction rows for {normalized_code} "
                f"on breakout date {breakout_date}"
            )
        except HTTPException:
            # Re-raise HTTP exceptions (404 for missing data, 400 for 2000 row limit)
            raise
        except ValueError as ve:
            # This is the 2000 row limit error
            raise HTTPException(status_code=400, detail=str(ve))
        except Exception as e:
            logger.error(f"Broker transaction query failed: {e}")
            raise HTTPException(
                status_code=503,
                detail=f"Failed to query broker transactions: {str(e)}"
            )

        # Step 3: Format data as tab-delimited
        price_history_data = breakout_service.format_as_tab_delimited(
            price_history_rows,
            title=""
        )
        broker_report_data = breakout_service.format_as_tab_delimited(
            broker_transaction_rows,
            title=""
        )

        # Step 4: Load template
        try:
            if not TEMPLATE_PATH.exists():
                raise FileNotFoundError(f"Template not found at {TEMPLATE_PATH}")

            template_content = TEMPLATE_PATH.read_text(encoding="utf-8")
            logger.info(f"Loaded template from {TEMPLATE_PATH} ({len(template_content)} characters)")
        except Exception as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail=f"Template loading failed: {str(e)}")

        # Step 5: Replace template variables
        prompt = template_content.replace("<Price History Data>", price_history_data)
        prompt = prompt.replace("<Broker Report Data>", broker_report_data)

        # Add signal strength classification instructions at the beginning
        signal_strength_instructions = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple strong buy signals, positive trend alignment, high conviction upside
- MILDLY_BULLISH: Some bullish indicators, positive bias but with caveats or mixed signals
- NEUTRAL: Conflicting signals, unclear direction, or market in transition/consolidation
- MILDLY_BEARISH: Some bearish indicators, negative bias but not overwhelming
- STRONGLY_BEARISH: Multiple strong sell signals, negative trend alignment, high conviction downside

Place this JSON at the very end of your markdown response after all analysis.
---

"""
        prompt = signal_strength_instructions + prompt

        logger.info(f"Prepared prompt for LLM ({len(prompt)} characters)")

        # Step 6: Generate analysis via LLM
        try:
            llm_result = llm_service.generate_prediction(
                prompt=prompt,
                stock_code=normalized_code,
                observation_date=observation_date.isoformat(),
                model=model
            )
            analysis_text = llm_result["prediction_text"]
            token_usage = llm_result["token_usage"]
        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise HTTPException(status_code=500, detail=f"LLM service unavailable: {str(e)}")

        # Step 7: Save to cache
        try:
            cache_service.save_prediction(normalized_code, observation_date, analysis_text)
        except Exception as e:
            logger.error(f"Cache save failed: {e}")
            # Don't fail the request if cache save fails

        # Step 8: Extract and save signal strength to database
        signal_strength = None
        try:
            logger.info(f"Attempting to extract signal strength from analysis (length: {len(analysis_text)} chars)")
            signal_strength = SignalStrengthParser.extract_signal_strength(analysis_text)

            if signal_strength:
                logger.info(f"✓ Extracted signal strength: {signal_strength} for {normalized_code}")
                db_service = SignalStrengthDBService()

                logger.info(
                    f"Attempting to save signal strength to database: {normalized_code} on {observation_date} "
                    f"-> {signal_strength}"
                )
                success = db_service.upsert_signal_strength(
                    stock_code=normalized_code,
                    observation_date=observation_date,
                    signal_strength_level=signal_strength
                )

                if success:
                    logger.info(f"✓ Successfully saved signal strength: {normalized_code} -> {signal_strength}")
                else:
                    logger.error(f"✗ Database upsert returned False for {normalized_code}")
            else:
                logger.warning(f"✗ No signal strength extracted from LLM output for {normalized_code}")
                logger.debug(f"Last 500 chars of analysis: {analysis_text[-500:]}")
        except Exception as e:
            logger.error(f"✗ Signal strength extraction/save failed for {normalized_code}: {e}", exc_info=True)
            # Don't fail the request if signal strength save fails

        # Return generated analysis
        return {
            "analysis_markdown": analysis_text,
            "cached": False,
            "cache_file": cache_service.get_cache_filename(normalized_code, observation_date),
            "observation_date": observation_date.isoformat(),
            "stock_code": normalized_code,
            "token_usage": token_usage,
            "generated_at": datetime.now().isoformat(),
            "signal_strength": signal_strength
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in breakout consolidation analysis endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/breakout-consolidation-prompt")
def get_breakout_consolidation_prompt(
    observation_date: date = Query(..., description="Observation date, e.g. 2026-01-09"),
    stock_code: str = Query(..., min_length=1, description="Stock code, e.g. SKK.AX"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns the LLM prompt text (template + injected data) without generating analysis.

    Args:
        observation_date: Observation date for prompt
        stock_code: Stock code (e.g., SKK.AX)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - prompt: Full prompt text with template and data
        - stock_code: Stock code
        - observation_date: Observation date string
        - template_file: Template filename used
        - prompt_length: Character count for monitoring
    """
    try:
        # Initialize services
        breakout_service = BreakoutDataService()

        # Normalize stock code
        normalized_code = breakout_service.normalize_stock_code(stock_code)

        logger.info(f"Prompt request for {normalized_code} on {observation_date} (user: {username})")

        # Get the BreakoutDate
        try:
            breakout_date = breakout_service.get_breakout_date(normalized_code, observation_date)
            logger.info(f"Using BreakoutDate: {breakout_date} for broker transaction query")
        except ValueError as ve:
            raise HTTPException(status_code=404, detail=str(ve))
        except Exception as e:
            logger.error(f"Failed to get BreakoutDate: {e}")
            raise HTTPException(status_code=503, detail=f"Failed to get BreakoutDate: {str(e)}")

        # Query price history data
        try:
            price_history_rows = breakout_service.get_price_history(normalized_code, observation_date)
            if not price_history_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No price history found for {normalized_code} up to {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Price history query failed: {e}")
            raise HTTPException(status_code=503, detail=f"Failed to query price history: {str(e)}")

        # Query broker transaction data (using BreakoutDate)
        try:
            broker_transaction_rows = breakout_service.get_broker_transactions(
                normalized_code, breakout_date  # Use breakout date instead of observation date
            )

            # VALIDATION: Broker transaction data is required - fail if missing
            if not broker_transaction_rows:
                error_msg = (
                    f"No broker transaction data found for {normalized_code} on breakout date {breakout_date}. "
                    f"Cannot generate prompt without broker tape reading data. "
                    f"Please verify that broker transaction data exists for this stock and date."
                )
                logger.error(error_msg)
                raise HTTPException(status_code=404, detail=error_msg)

            logger.info(
                f"Retrieved {len(broker_transaction_rows)} broker transaction rows for {normalized_code} "
                f"on breakout date {breakout_date}"
            )
        except HTTPException:
            # Re-raise HTTP exceptions (404 for missing data, 400 for 2000 row limit)
            raise
        except ValueError as ve:
            # This is the 2000 row limit error
            raise HTTPException(status_code=400, detail=str(ve))
        except Exception as e:
            logger.error(f"Broker transaction query failed: {e}")
            raise HTTPException(status_code=503, detail=f"Failed to query broker transactions: {str(e)}")

        # Format data as tab-delimited
        price_history_data = breakout_service.format_as_tab_delimited(price_history_rows, title="")
        broker_report_data = breakout_service.format_as_tab_delimited(broker_transaction_rows, title="")

        # Load template
        try:
            if not TEMPLATE_PATH.exists():
                raise FileNotFoundError(f"Template not found at {TEMPLATE_PATH}")

            template_content = TEMPLATE_PATH.read_text(encoding="utf-8")
        except Exception as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail=f"Template loading failed: {str(e)}")

        # Replace template variables
        prompt = template_content.replace("<Price History Data>", price_history_data)
        prompt = prompt.replace("<Broker Report Data>", broker_report_data)

        # Add signal strength classification instructions
        signal_strength_instructions = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple strong buy signals, positive trend alignment, high conviction upside
- MILDLY_BULLISH: Some bullish indicators, positive bias but with caveats or mixed signals
- NEUTRAL: Conflicting signals, unclear direction, or market in transition/consolidation
- MILDLY_BEARISH: Some bearish indicators, negative bias but not overwhelming
- STRONGLY_BEARISH: Multiple strong sell signals, negative trend alignment, high conviction downside

Place this JSON at the very end of your markdown response after all analysis.
---

"""
        prompt = signal_strength_instructions + prompt

        # Return prompt
        return {
            "prompt": prompt,
            "stock_code": normalized_code,
            "observation_date": observation_date.isoformat(),
            "template_file": "breakout_consolidation/template.md",
            "prompt_length": len(prompt),
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
