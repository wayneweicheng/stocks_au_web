import json
import re
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class SignalStrengthParser:
    """Service for parsing signal strength classification from LLM predictions."""

    VALID_LEVELS = {
        "STRONGLY_BULLISH",
        "MILDLY_BULLISH",
        "NEUTRAL",
        "MILDLY_BEARISH",
        "STRONGLY_BEARISH"
    }

    @classmethod
    def extract_signal_strength(cls, llm_output: str) -> Optional[str]:
        """
        Extract signal strength classification from LLM markdown output.

        Looks for JSON block at the end of the output containing:
        {
          "signal_strength": "STRONGLY_BULLISH" | ...
        }

        Args:
            llm_output: Markdown text from LLM prediction

        Returns:
            Signal strength level (e.g., "STRONGLY_BULLISH") or None if not found/invalid
        """
        if not llm_output:
            logger.warning("Empty LLM output provided to signal strength parser")
            return None

        try:
            # Strategy 1: Look for JSON code block with signal_strength field (3 backticks)
            json_pattern = r'```json\s*\{[^}]*"signal_strength"\s*:\s*"([^"]+)"[^}]*\}\s*```'
            match = re.search(json_pattern, llm_output, re.IGNORECASE | re.DOTALL)

            if match:
                signal_strength = match.group(1).strip().upper().replace(" ", "_")
                if signal_strength in cls.VALID_LEVELS:
                    logger.info(f"Extracted signal strength from JSON block (3 backticks): {signal_strength}")
                    return signal_strength
                else:
                    logger.warning(f"Invalid signal strength in JSON block: {signal_strength}")

            # Strategy 1b: Look for JSON code block with 2 backticks (common LLM mistake)
            json_pattern_2tick = r'``json\s*\{[^}]*"signal_strength"\s*:\s*"([^"]+)"[^}]*\}\s*``'
            match = re.search(json_pattern_2tick, llm_output, re.IGNORECASE | re.DOTALL)

            if match:
                signal_strength = match.group(1).strip().upper().replace(" ", "_")
                if signal_strength in cls.VALID_LEVELS:
                    logger.info(f"Extracted signal strength from JSON block (2 backticks): {signal_strength}")
                    return signal_strength
                else:
                    logger.warning(f"Invalid signal strength in JSON block (2 backticks): {signal_strength}")

            # Strategy 2: Look for inline JSON object (without code block)
            inline_json_pattern = r'\{[^}]*"signal_strength"\s*:\s*"([^"]+)"[^}]*\}'
            match = re.search(inline_json_pattern, llm_output, re.IGNORECASE | re.DOTALL)

            if match:
                signal_strength = match.group(1).strip().upper().replace(" ", "_")
                if signal_strength in cls.VALID_LEVELS:
                    logger.info(f"Extracted signal strength from inline JSON: {signal_strength}")
                    return signal_strength
                else:
                    logger.warning(f"Invalid signal strength in inline JSON: {signal_strength}")

            # Strategy 3: Parse last JSON-like structure in the output
            # Look for the last occurrence of {...} that might contain signal_strength
            json_blocks = re.findall(r'\{[^{}]*\}', llm_output, re.DOTALL)
            for json_block in reversed(json_blocks):  # Check from end to start
                try:
                    parsed = json.loads(json_block)
                    if isinstance(parsed, dict) and "signal_strength" in parsed:
                        signal_strength = str(parsed["signal_strength"]).strip().upper().replace(" ", "_")
                        if signal_strength in cls.VALID_LEVELS:
                            logger.info(f"Extracted signal strength from parsed JSON: {signal_strength}")
                            return signal_strength
                except json.JSONDecodeError:
                    continue

            # Strategy 4: Fallback - look for plain text mentions of signal levels
            # (less reliable, but better than nothing)
            for level in cls.VALID_LEVELS:
                # Look for pattern like "Signal Strength: STRONGLY_BULLISH" or similar
                fallback_pattern = rf'signal[_\s]*strength[:\s]*{level}'
                if re.search(fallback_pattern, llm_output, re.IGNORECASE):
                    logger.info(f"Extracted signal strength from fallback text match: {level}")
                    return level

            logger.warning("No valid signal strength classification found in LLM output")
            return None

        except Exception as e:
            logger.error(f"Error parsing signal strength: {e}")
            return None

    @classmethod
    def validate_signal_strength(cls, signal_strength: Optional[str]) -> bool:
        """
        Validate that signal strength is one of the allowed levels.

        Args:
            signal_strength: Signal strength string to validate

        Returns:
            True if valid, False otherwise
        """
        return signal_strength in cls.VALID_LEVELS
