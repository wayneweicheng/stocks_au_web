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
    def extract_trade_ranges(cls, llm_output: str) -> dict:
        """
        Extract 'Buy the Dip Range' and 'Sell the Rip Range' as plain text strings.
        Returns dict with optional keys: buy_dip_range, sell_rip_range
        """
        result: dict = {}
        try:
            if not llm_output:
                return result

            # Normalize whitespace for robust regex
            text = llm_output

            # Patterns:
            # - Buy the Dip Range: "... 618.4 - 620.3" or "not recommend" (case-insensitive)
            # - Sell the Rip Range: same styles
            # Number pattern: allows optional $ and commas
            num = r'\$?\s*(?:-?\d{1,3}(?:,\d{3})*(?:\.\d+)?|-?\d+(?:\.\d+)?)'
            range_pattern = rf'(?P<a>{num})\s*[-–—]\s*(?P<b>{num})'
            # Also support "a to b"
            range_to_pattern = rf'(?P<a2>{num})\s*(?:to|TO)\s*(?P<b2>{num})'
            not_recommend_pattern = r'(not\s+recommend(?:ed)?)'

            def find_after(label_variants: list[str]) -> Optional[str]:
                for label in label_variants:
                    # capture after label up to EOL
                    m = re.search(label + r'\s*[:\-]?\s*(.+)', text, re.IGNORECASE)
                    if m:
                        tail = m.group(1).strip()
                        # First try explicit range
                        mr = re.search(range_pattern, tail, re.IGNORECASE)
                        if mr:
                            def clean(x: str) -> str:
                                return x.replace("$", "").replace(",", "").strip()
                            a = clean(mr.group('a'))
                            b = clean(mr.group('b'))
                            return f"{a}–{b}"
                        # Alternate "a to b" phrasing
                        mr2 = re.search(range_to_pattern, tail, re.IGNORECASE)
                        if mr2:
                            def clean2(x: str) -> str:
                                return x.replace("$", "").replace(",", "").strip()
                            a = clean2(mr2.group('a2'))
                            b = clean2(mr2.group('b2'))
                            return f"{a}–{b}"
                        # Then try "not recommend"
                        mn = re.search(not_recommend_pattern, tail, re.IGNORECASE)
                        if mn:
                            return mn.group(1).lower()
                        # Otherwise return first tokenish phrase up to break
                        # but keep it conservative: only return if short
                        candidate = tail.splitlines()[0].strip()
                        if candidate and len(candidate) <= 64:
                            return candidate
                return None

            buy = find_after([
                r'buy\s+the\s+dip\s+range',
                r'buy\s+dip\s+range',
                r'buy\s+range'
            ])
            sell = find_after([
                r'sell\s+the\s+rip\s+range',
                r'sell\s+rip\s+range',
                r'sell\s+range'
            ])

            if buy:
                result['buy_dip_range'] = buy
            if sell:
                result['sell_rip_range'] = sell
        except Exception as e:
            logger.error(f"Error parsing trade ranges: {e}")

        return result

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
