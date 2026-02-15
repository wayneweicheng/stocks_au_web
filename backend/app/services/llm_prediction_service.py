from typing import Dict, Any
from pathlib import Path
from datetime import datetime
import logging
import os

import httpx
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage

logger = logging.getLogger(__name__)

# Models that use extended thinking / reasoning tokens.
# These models split their output into a "reasoning" phase (thinking tokens)
# and a "content" phase (the actual answer).  Without an explicit max_tokens
# budget the reasoning phase can exhaust the entire limit, leaving content="".
_REASONING_MODEL_PREFIXES = (
    "deepseek/deepseek-r",   # DeepSeek-R1 family
    "qwen/qwen3",            # Qwen3 thinking variants
    "qwen/qwq",              # QwQ reasoning
    "openai/o1",             # OpenAI o1 family
    "openai/o3",             # OpenAI o3 family
    "google/gemini-2.0-flash-thinking",
    "google/gemini-2.5",     # Gemini 2.5 thinking
)


def _is_reasoning_model(model: str) -> bool:
    m = model.lower()
    return any(m.startswith(p) for p in _REASONING_MODEL_PREFIXES)


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

    # Only Gemini and GPT models are considered fast (2-minute timeout).
    # Everything else (Qwen, DeepSeek, Grok, etc.) gets the slow timeout.
    _FAST_MODEL_PREFIXES = (
        "google/gemini",
        "openai/gpt",
    )
    _FAST_TIMEOUT = 120
    _SLOW_TIMEOUT = 600  # 10 minutes for reasoning/large/slow models

    # Default max_tokens for generation.
    # Reasoning models need a large budget because thinking tokens are counted
    # inside max_tokens.  Without this, the model can exhaust the token budget
    # during the thinking phase and produce empty content.
    _DEFAULT_MAX_TOKENS = 8000
    _REASONING_MAX_TOKENS = 20000

    def _get_timeout_for_model(self, model: str) -> int:
        """Return an appropriate request timeout (seconds) based on the model name."""
        model_lower = model.lower()
        if any(model_lower.startswith(p) for p in self._FAST_MODEL_PREFIXES):
            return self._FAST_TIMEOUT
        return self._SLOW_TIMEOUT

    def _create_llm_model(self, model: str, temperature: float = 0.3, request_timeout: int | None = None):
        """
        Create LLM model instance.

        Args:
            model: Model name to use (e.g., qwen/qwen3-30b-a3b)
            temperature: Temperature parameter for generation
            request_timeout: Request timeout in seconds. Defaults to a model-aware value.

        Returns:
            ChatOpenAI model instance
        """
        if request_timeout is None:
            request_timeout = self._get_timeout_for_model(model)

        is_reasoning = _is_reasoning_model(model)
        max_tokens = self._REASONING_MAX_TOKENS if is_reasoning else self._DEFAULT_MAX_TOKENS

        logger.info(
            "Creating LLM model '%s' with timeout=%ss max_tokens=%s reasoning_model=%s",
            model, request_timeout, max_tokens, is_reasoning,
        )

        # Pass an explicit httpx.Timeout so connect, read, write, and pool
        # timeouts are all set — a plain int only sets the connect timeout
        # in some httpx/openai versions, leaving the read phase uncapped.
        timeout = httpx.Timeout(request_timeout)
        http_client = httpx.Client(timeout=timeout)

        # Build OpenRouter-specific extra_body fields.
        # These are passed directly into the JSON request body by the openai client
        # (via the top-level extra_body param — NOT inside model_kwargs which would
        # trigger a UserWarning).
        extra_body: Dict[str, Any] = {}

        # For reasoning models, suppress raw thinking tokens in the response body
        # so they don't consume the output token budget and leave content="".
        if is_reasoning:
            extra_body["include_reasoning"] = False

        # Friendli has a tighter context window than other providers for many models
        # and rejects large prompts with a 422 "input is too long" error.  Tell
        # OpenRouter to skip Friendli while still allowing fallback to any other
        # available provider.
        extra_body["provider"] = {
            "ignore": ["Friendli"],
            "allow_fallbacks": True,
        }

        return ChatOpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=self.api_key,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            request_timeout=request_timeout,
            http_client=http_client,
            extra_body=extra_body,
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

        try:
            # Create LLM model and invoke directly (not via chain) so we can
            # inspect the raw AIMessage and extract real token usage +
            # finish_reason.
            llm_model = self._create_llm_model(model)

            messages = [
                SystemMessage(content="You are a quantitative trading analyst. Analyze the provided data and generate a detailed price action forecast."),
                HumanMessage(content=prompt),
            ]

            ai_message = llm_model.invoke(messages)

            # --- Extract response text -------------------------------------------
            # Standard models put the answer in ai_message.content.
            # Some reasoning models (Qwen3, DeepSeek-R1) put the thinking tokens
            # in additional_kwargs["reasoning_content"] and the final answer in
            # content.  If content is empty we fall back to reasoning_content so
            # the result is never silently discarded.
            response_text: str = ai_message.content or ""
            if not response_text:
                reasoning = ai_message.additional_kwargs.get("reasoning_content", "")
                if reasoning:
                    logger.warning(
                        "Model '%s' returned empty content — reasoning_content present (%d chars). "
                        "This usually means the token budget was exhausted during thinking. "
                        "Using reasoning_content as fallback.",
                        model, len(reasoning),
                    )
                    response_text = reasoning
                else:
                    logger.error(
                        "Model '%s' returned empty content AND empty reasoning_content. "
                        "full additional_kwargs: %s",
                        model, ai_message.additional_kwargs,
                    )

            # --- Extract real token usage from response metadata -----------------
            usage_meta = ai_message.response_metadata.get("token_usage") or {}
            input_tokens: int = (
                usage_meta.get("prompt_tokens")
                or usage_meta.get("input_tokens")
                or len(prompt) // 4
            )
            output_tokens: int = (
                usage_meta.get("completion_tokens")
                or usage_meta.get("output_tokens")
                or len(response_text) // 4
            )
            total_tokens: int = usage_meta.get("total_tokens") or (input_tokens + output_tokens)

            # --- Check finish_reason ---------------------------------------------
            finish_reason: str = ai_message.response_metadata.get("finish_reason", "unknown")
            if finish_reason == "length":
                logger.warning(
                    "Model '%s' stopped due to token limit (finish_reason=length). "
                    "Response may be truncated. Tokens used: %d in / %d out. "
                    "Consider increasing max_tokens or reducing prompt size.",
                    model, input_tokens, output_tokens,
                )
            else:
                logger.info(
                    "LLM generation complete. finish_reason=%s tokens: %d (in: %d, out: %d)",
                    finish_reason, total_tokens, input_tokens, output_tokens,
                )

            token_usage = {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "total_tokens": total_tokens,
                "finish_reason": finish_reason,
            }

            # Log the interaction
            self._log_llm_interaction(
                stock_code=stock_code,
                observation_date=observation_date,
                prompt=prompt,
                response=response_text,
                token_usage=token_usage,
                model=model
            )

            return {
                "prediction_text": response_text,
                "token_usage": token_usage,
                "model_used": model
            }

        except Exception as e:
            logger.error("LLM generation failed [%s]: %s", type(e).__name__, e, exc_info=True)
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
            finish_reason = token_usage.get("finish_reason", "unknown")
            log_content = f"""=== TOKEN USAGE ===
Input: {token_usage['input_tokens']} | Output: {token_usage['output_tokens']} | Total: {token_usage['total_tokens']}
Finish reason: {finish_reason}
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
