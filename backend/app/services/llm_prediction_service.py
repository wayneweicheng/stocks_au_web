from typing import Dict, Any
from pathlib import Path
from datetime import datetime
import logging
import os

from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

logger = logging.getLogger(__name__)


class LLMPredictionService:
    """Service for generating predictions using OpenRouter LLM API."""

    def __init__(self, log_dir: str = "prediction/llm_logs"):
        """
        Initialize the LLM prediction service.

        Args:
            log_dir: Directory to store LLM interaction logs
        """
        self.log_dir = Path(log_dir)
        self._ensure_log_directory()

        # Get API key from environment
        self.api_key = os.getenv("OPENROUTER_STANDARD_API_KEY")

        if not self.api_key:
            raise ValueError("OPENROUTER_STANDARD_API_KEY environment variable is required")

        logger.info("LLM service initialized")

    def _ensure_log_directory(self):
        """Create log directory if it doesn't exist."""
        try:
            self.log_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"LLM log directory ready: {self.log_dir}")
        except Exception as e:
            logger.error(f"Failed to create log directory: {e}")
            raise

    def _create_llm_model(self, model: str, temperature: float = 0.3, request_timeout: int = 120):
        """
        Create LLM model instance.

        Args:
            model: Model name to use (e.g., qwen/qwen3-30b-a3b)
            temperature: Temperature parameter for generation
            request_timeout: Request timeout in seconds

        Returns:
            ChatOpenAI model instance
        """
        return ChatOpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=self.api_key,
            model=model,
            temperature=temperature,
            request_timeout=request_timeout
        )

    def generate_prediction(
        self,
        prompt: str,
        stock_code: str,
        observation_date: str,
        model: str = "google/gemini-2.5-flash"
    ) -> Dict[str, Any]:
        """
        Generate prediction using LLM.

        Args:
            prompt: Full prompt with template and data
            stock_code: Stock code for logging
            observation_date: Observation date for logging
            model: LLM model to use (e.g., qwen/qwen3-30b-a3b, openai/gpt-5-mini)

        Returns:
            Dictionary containing:
            - prediction_text: Generated markdown text
            - token_usage: Dict with input_tokens, output_tokens, total_tokens
            - model_used: Model name used for generation

        Raises:
            Exception: If LLM call fails after retries
        """
        logger.info(f"Generating prediction for {stock_code} on {observation_date} using model: {model}")

        # Track token usage
        input_tokens = 0
        output_tokens = 0

        try:
            # Create LLM model
            llm_model = self._create_llm_model(model)

            # Create prompt template
            prompt_template = ChatPromptTemplate.from_messages([
                ("system", "You are a quantitative trading analyst. Analyze the provided data and generate a detailed price action forecast."),
                ("user", "{prompt}")
            ])

            # Create chain
            chain = prompt_template | llm_model | StrOutputParser()

            # Invoke the chain
            response = chain.invoke({"prompt": prompt})

            # Estimate token usage (rough approximation: ~4 chars per token)
            input_tokens = len(prompt) // 4
            output_tokens = len(response) // 4
            total_tokens = input_tokens + output_tokens

            token_usage = {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "total_tokens": total_tokens
            }

            logger.info(f"LLM generation complete. Tokens: {total_tokens} (in: {input_tokens}, out: {output_tokens})")

            # Log the interaction
            self._log_llm_interaction(
                stock_code=stock_code,
                observation_date=observation_date,
                prompt=prompt,
                response=response,
                token_usage=token_usage,
                model=model
            )

            return {
                "prediction_text": response,
                "token_usage": token_usage,
                "model_used": model
            }

        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise

    def _log_llm_interaction(
        self,
        stock_code: str,
        observation_date: str,
        prompt: str,
        response: str,
        token_usage: Dict[str, int],
        model: str
    ):
        """
        Log LLM interaction to file.

        Args:
            stock_code: Stock code
            observation_date: Observation date string
            prompt: Input prompt
            response: LLM response
            token_usage: Token usage dictionary
            model: Model name used
        """
        try:
            # Normalize stock code
            base_code = stock_code.replace(".US", "").replace(".us", "").upper()

            # Generate log filename: <StockCode>_<YYYYMMDD>_<HHMMSS>.log
            timestamp = datetime.now()
            date_str = observation_date.replace("-", "")  # YYYYMMDD
            time_str = timestamp.strftime("%H%M%S")
            filename = f"{base_code}_{date_str}_{time_str}.log"
            filepath = self.log_dir / filename

            # Format log content
            log_content = f"""=== TOKEN USAGE ===
Input: {token_usage['input_tokens']} | Output: {token_usage['output_tokens']} | Total: {token_usage['total_tokens']}
Model: {model}

=== INPUT PROMPT ===
{prompt}

=== LLM RESPONSE ===
{response}

=== METADATA ===
Generated: {timestamp.isoformat()}
Stock: {base_code}
Observation Date: {observation_date}
"""

            # Write log file
            filepath.write_text(log_content, encoding="utf-8")
            logger.info(f"Saved LLM interaction log: {filename}")

        except Exception as e:
            logger.error(f"Failed to save LLM interaction log: {e}")
            # Don't raise - logging failure shouldn't break the main flow
