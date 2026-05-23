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
        "STRONGLY_BEARISH",
        "NOT_DETERMINED",
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
            Signal strength level (e.g., "STRONGLY_BULLISH" or "NOT_DETERMINED") or None if not found/invalid
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
    def is_valid_price_range(cls, range_text: str, context: str = "") -> bool:
        """
        Validate that a range text represents a valid price range, not DTE or other values.

        Args:
            range_text: The extracted range text (e.g., "618.4–620.3" or "0–7")
            context: The surrounding context text to check for DTE keywords

        Returns:
            True if valid price range, False otherwise
        """
        # Extract the numeric values from the range
        parts = range_text.split('–')
        if len(parts) != 2:
            return False

        try:
            lower = float(parts[0].strip())
            upper = float(parts[1].strip())

            # Condition 1: Reject if lower bound is 0
            # Price ranges should never start at 0
            if lower == 0:
                logger.warning(f"Rejected price range starting at 0: {range_text}")
                return False

            # Condition 2: Reject if context contains "DTE" VERY close to the numbers (within 20 chars)
            # This indicates it's a Days To Expiration range, not a price range
            # Find the range pattern in context to get precise positioning
            range_pos = context.upper().find(range_text.replace('–', '-').upper())
            if range_pos == -1:
                # Try finding with original dash characters
                range_pos = context.upper().find(parts[0].strip())

            if range_pos != -1:
                # Check within 20 characters before or after the range
                window_start = max(0, range_pos - 20)
                window_end = min(len(context), range_pos + len(range_text) + 20)
                nearby_text = context[window_start:window_end].upper()

                if "DTE" in nearby_text or "DAYS TO EXPIRATION" in nearby_text:
                    logger.warning(f"Rejected range with DTE in close proximity: {range_text}")
                    return False

            # Condition 3: Reject unrealistic ranges (both numbers < 10)
            # Most stock/ETF prices are above 10, so 0-7 or 3-5 are likely DTE values
            if lower < 10 and upper < 10:
                logger.warning(f"Rejected suspiciously low range (likely DTE): {range_text}")
                return False

            return True
        except (ValueError, IndexError):
            return False

    @classmethod
    def extract_trade_ranges(cls, llm_output: str) -> dict:
        """
        Extract 'Buy the Dip Range' and 'Sell the Rip Range' as plain text strings.
        Returns dict with optional keys: buy_dip_range, sell_rip_range

        Validates that extracted ranges are valid price ranges and not DTE values.
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
            # Number pattern: allows optional $ and commas, supports any positive number
            # Pattern explanation: \d+ (any digits) optional comma-grouped thousands, optional decimal
            num = r'\$?\s*\d+(?:,\d{3})*(?:\.\d+)?'
            range_pattern = rf'(?P<a>{num})\s*[-–—]\s*(?P<b>{num})'
            # Also support "a to b"
            range_to_pattern = rf'(?P<a2>{num})\s*(?:to|TO)\s*(?P<b2>{num})'
            not_recommend_pattern = r'(not\s+recommend(?:ed)?)'

            def find_after(label_variants: list[str]) -> Optional[str]:
                for label in label_variants:
                    # Strategy 1: Find ALL occurrences of the label and try each one
                    # This handles cases where the label appears multiple times (e.g., as header then in text)
                    for m in re.finditer(label + r'\s*[:\-]?\s*(.+)', text, re.IGNORECASE):
                        tail = m.group(1).strip()
                        # Capture more context (up to 200 chars) for DTE validation
                        context_start = max(0, m.start() - 100)
                        context_end = min(len(text), m.end() + 200)
                        context = text[context_start:context_end]

                        # PRIORITY 1: Check for "not recommend" FIRST (before trying to extract ranges)
                        # This prevents false positives from ranges mentioned in explanatory text
                        mn = re.search(not_recommend_pattern, tail, re.IGNORECASE)
                        if mn:
                            return mn.group(1).lower()

                        # PRIORITY 2: Try explicit range on same line
                        mr = re.search(range_pattern, tail, re.IGNORECASE)
                        if mr:
                            def clean(x: str) -> str:
                                return x.replace("$", "").replace(",", "").strip()
                            a = clean(mr.group('a'))
                            b = clean(mr.group('b'))
                            candidate_range = f"{a}–{b}"

                            # Validate the range before returning
                            if cls.is_valid_price_range(candidate_range, context):
                                return candidate_range
                            else:
                                logger.info(f"Skipping invalid price range: {candidate_range}")
                                continue

                        # PRIORITY 3: Alternate "a to b" phrasing on same line
                        mr2 = re.search(range_to_pattern, tail, re.IGNORECASE)
                        if mr2:
                            def clean2(x: str) -> str:
                                return x.replace("$", "").replace(",", "").strip()
                            a = clean2(mr2.group('a2'))
                            b = clean2(mr2.group('b2'))
                            candidate_range = f"{a}–{b}"

                            # Validate the range before returning
                            if cls.is_valid_price_range(candidate_range, context):
                                return candidate_range
                            else:
                                logger.info(f"Skipping invalid price range: {candidate_range}")
                                continue

                    # Strategy 2: If no match on same line, look in next few lines after FIRST occurrence
                    # This handles multi-line format like:
                    # "Sell the Rip Range:\n\nPrice Range for Sell Entry: $605 - $610"
                    first_match = re.search(label + r'\s*[:\-]?\s*', text, re.IGNORECASE)
                    if first_match:
                        pos = first_match.end()
                        # Look in next 500 characters for the range pattern
                        next_chunk = text[pos:pos + 500]
                        # Capture context for validation
                        context_start = max(0, first_match.start() - 100)
                        context_end = min(len(text), pos + 500)
                        context = text[context_start:context_end]

                        # Look for "Price Range" pattern (common in multi-line format)
                        price_range_match = re.search(
                            r'price\s+range[^\n]*[:\-]\s*(.+)',
                            next_chunk,
                            re.IGNORECASE
                        )
                        if price_range_match:
                            tail = price_range_match.group(1).strip()
                            # Try to extract range from this tail
                            mr = re.search(range_pattern, tail, re.IGNORECASE)
                            if mr:
                                def clean(x: str) -> str:
                                    return x.replace("$", "").replace(",", "").strip()
                                a = clean(mr.group('a'))
                                b = clean(mr.group('b'))
                                candidate_range = f"{a}–{b}"

                                # Validate the range before returning
                                if cls.is_valid_price_range(candidate_range, context):
                                    return candidate_range
                                else:
                                    logger.info(f"Skipping invalid price range in multi-line: {candidate_range}")

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
