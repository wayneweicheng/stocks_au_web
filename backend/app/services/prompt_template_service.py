from typing import Optional, Tuple
from pathlib import Path
import logging
import re

logger = logging.getLogger(__name__)


class PromptTemplateService:
    """Service for loading and processing prompt templates from signal_pattern directory."""

    # System instruction for signal strength classification
    SIGNAL_STRENGTH_SYSTEM_PROMPT = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

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

CRITICAL: Your signal strength classification must be based PRIMARILY on tomorrow's (next trading day) expected price action.
While you may reference longer-term trends (next 5 days) in your analysis, the signal strength rating should reflect
your conviction about tomorrow's direction and magnitude. Tomorrow's forecast is the primary focus - do not give equal
weight to multi-day projections when determining the signal strength.

GAMMA EXPOSURE (GEX) FLIP ANALYSIS:
You MUST calculate and report the approximate price change that would cause GEX to flip regimes:
- If current GEX is POSITIVE: Calculate the price drop (in dollars and percentage) needed to flip GEX negative.
  This shows how much downside would shift from mean-reverting regime to trend-following regime.
- If current GEX is NEGATIVE: Calculate the price increase (in dollars and percentage) needed to flip GEX positive.
  This shows how much upside would shift from trend-following regime to mean-reverting regime.

This is a critical risk assessment for understanding regime change thresholds.
Include this calculation in your analysis section before the signal strength JSON.

Example formats:
"**GEX Flip Level:** Current GEX is positive. A price drop to approximately $XXX (-X.XX% from current) would likely
flip GEX negative, changing the market regime from mean-reverting to trend-following."

"**GEX Flip Level:** Current GEX is negative. A price increase to approximately $XXX (+X.XX% from current) would likely
flip GEX positive, changing the market regime from trend-following to mean-reverting."

TRADING LEVELS RECOMMENDATION:
You MUST provide actionable trading levels based on your analysis:

1. **Buy the Dip Range**: If conditions support buying on weakness, specify:
   - Price range for buy entry (e.g., "$XXX - $YYY")
   - Percentage drop from current price
   - Rationale based on technical levels (support, Bollinger Bands, key moving averages, GEX levels, etc.)
   - If NOT recommending buy the dip, explicitly state "Not Recommended" and explain why (e.g., bearish trend, no support, negative signals)

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Percentage gain from current price
   - Rationale based on technical levels (resistance, Bollinger Bands, key moving averages, GEX levels, etc.)
   - If NOT recommending sell the rip, explicitly state "Not Recommended" and explain why (e.g., bullish trend, breakout potential, positive signals)

Example format:
"**Buy the Dip Range:** $XXX - $YYY (-X.X% to -Y.Y% from current). This range aligns with the lower Bollinger Band and previous support at the SMA50. Positive GEX suggests dealers will provide support at these levels."

"**Sell the Rip Range:** Not Recommended. Current momentum is strongly bullish with Golden Setup active. Selling into strength would be counter-trend with high risk of missing further upside."

Place this JSON at the very end of your markdown response after all analysis.
---

"""

    def __init__(self, template_dir: str = "signal_pattern"):
        """
        Initialize the template service.

        Args:
            template_dir: Directory containing signal pattern templates
        """
        self.template_dir = Path(template_dir)
        if not self.template_dir.exists():
            logger.warning(f"Template directory does not exist: {self.template_dir}")

    def normalize_stock_code(self, stock_code: str) -> str:
        """
        Normalize stock code for template file lookup.

        Args:
            stock_code: Stock code (with or without .US suffix)

        Returns:
            Uppercase base stock code without .US suffix
        """
        return stock_code.replace(".US", "").replace(".us", "").upper()

    def get_template(self, stock_code: str) -> Tuple[str, bool]:
        """
        Load prompt template for stock.

        Args:
            stock_code: Stock code (with or without .US suffix)

        Returns:
            Tuple of (template_content, used_fallback)
            - template_content: Template content from <StockCode>.md file
            - used_fallback: True if SPXW.md fallback was used, False if stock-specific template found

        Raises:
            FileNotFoundError: If neither stock-specific nor fallback template exists
        """
        base_code = self.normalize_stock_code(stock_code)
        template_path = self.template_dir / f"{base_code}.md"

        # Try stock-specific template first
        if template_path.exists():
            try:
                content = template_path.read_text(encoding="utf-8")
                logger.info(f"Loaded template: {template_path.name} ({len(content)} characters)")
                return content, False
            except Exception as e:
                logger.error(f"Failed to read template {template_path}: {e}")
                # Fall through to fallback

        # Fallback to SPXW.md
        logger.warning(f"Template not found for {base_code}, falling back to SPXW.md")
        fallback_path = self.template_dir / "SPXW.md"

        if not fallback_path.exists():
            raise FileNotFoundError(
                f"Neither {template_path.name} nor fallback SPXW.md found in {self.template_dir}"
            )

        try:
            content = fallback_path.read_text(encoding="utf-8")
            logger.info(f"Loaded fallback template: SPXW.md ({len(content)} characters)")
            return content, True
        except Exception as e:
            logger.error(f"Failed to read fallback template {fallback_path}: {e}")
            raise

    def inject_variables(
        self,
        template: str,
        recent_data: str,
        stock_code: Optional[str] = None,
        observation_date: Optional[str] = None,
        include_signal_strength_prompt: bool = True
    ) -> str:
        """
        Replace template variables with actual values.

        Replaces:
        - {{ recent_data }} with tab-delimited data
        - {{ stock_code }} with base stock code (optional)
        - {{ observation_date }} with observation date (optional)

        If {{ recent_data }} placeholder not found in template, appends recent_data to end.

        Args:
            template: Template content with placeholders
            recent_data: Tab-delimited GEX features data
            stock_code: Base stock code (optional)
            observation_date: Observation date string (optional)
            include_signal_strength_prompt: Whether to prepend signal strength classification instructions

        Returns:
            Template with variables replaced
        """
        # Prepend signal strength classification instructions if requested
        result = self.SIGNAL_STRENGTH_SYSTEM_PROMPT + template if include_signal_strength_prompt else template

        # Check if {{ recent_data }} placeholder exists
        has_recent_data_placeholder = "{{ recent_data }}" in result or "{{recent_data}}" in result

        # Replace {{ recent_data }} (with or without spaces)
        result = result.replace("{{ recent_data }}", recent_data)
        result = result.replace("{{recent_data}}", recent_data)

        # If {{ recent_data }} placeholder not found, append to end
        if not has_recent_data_placeholder:
            logger.info("No {{ recent_data }} placeholder found, appending data to end of template")
            result = result.rstrip() + "\n\n## Data (Last 30 Days)\n\n" + recent_data

        # Replace optional variables if provided
        if stock_code is not None:
            base_code = self.normalize_stock_code(stock_code)
            result = result.replace("{{ stock_code }}", base_code)
            result = result.replace("{{stock_code}}", base_code)

        if observation_date is not None:
            result = result.replace("{{ observation_date }}", observation_date)
            result = result.replace("{{observation_date}}", observation_date)

        logger.info(f"Injected variables into template ({len(result)} characters after injection)")

        return result
