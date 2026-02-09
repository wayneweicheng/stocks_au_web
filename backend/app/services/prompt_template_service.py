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
You MUST provide actionable trading levels based on your analysis.
Use the 30-Minute Price Bar data to identify key intraday support and resistance levels,
VWAP clusters, and high-volume price zones from the last 5 trading days. These levels
should be the primary basis for determining the price ranges below.

1. **Buy the Dip Range**: If conditions support buying on weakness, specify:
   - Price range for buy entry (e.g., "$XXX - $YYY")
   - Percentage drop from current price
   - Rationale based on intraday support levels identified from 30-minute bars (VWAP, high-volume zones, recurring intraday lows), combined with daily technical levels (Bollinger Bands, moving averages, GEX levels)
   - If NOT recommending buy the dip, explicitly state "Not Recommended" and explain why (e.g., bearish trend, no support, negative signals)

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Percentage gain from current price
   - Rationale based on intraday resistance levels identified from 30-minute bars (VWAP, high-volume zones, recurring intraday highs), combined with daily technical levels (Bollinger Bands, moving averages, GEX levels)
   - If NOT recommending sell the rip, explicitly state "Not Recommended" and explain why (e.g., bullish trend, breakout potential, positive signals)

Example format:
"**Buy the Dip Range:** $XXX - $YYY (-X.X% to -Y.Y% from current). This range aligns with the lower Bollinger Band and previous support at the SMA50. Positive GEX suggests dealers will provide support at these levels."

"**Sell the Rip Range:** Not Recommended. Current momentum is strongly bullish with Golden Setup active. Selling into strength would be counter-trend with high risk of missing further upside."

LATE OPTION TRADE ANALYSIS:
The "Latest Option Trades" data shows large option transactions (size > 300 contracts) for the observation date.
Incorporate this data into your overall signal strength assessment:
- Evaluate the put/call balance: heavy put buying suggests bearish institutional positioning; heavy call buying suggests bullish positioning
- Look for strike clustering near the current price, which may indicate key levels where dealers will need to hedge
- Unusually large individual trades may signal directional bets or hedging activity by institutions
- Factor this institutional flow data into your signal strength classification alongside the GEX and technical indicators

Place this JSON at the very end of your markdown response after all analysis.
---

"""

    # System instruction for option insights signal strength classification (without GEX-specific instructions)
    OPTION_SIGNAL_STRENGTH_PROMPT = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

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

CRITICAL FOCUS - SHORT-TERM TACTICAL ANALYSIS (1-5 Days):
Your signal strength classification should reflect the IMMEDIATE tactical bias indicated by option flow for the next 1-5 trading days.

**NEAR-TERM EXPIRY PRIORITIZATION:**
Option OI changes in NEAR-TERM expiries (0-7 DTE, Days To Expiration) have SIGNIFICANTLY MORE IMPACT than longer-dated options.
When analyzing the data, you MUST weight near-term expiry options much more heavily because:

1. **Dealer Gamma Exposure**: Near-term options have exponentially higher gamma, forcing dealers to hedge more aggressively
2. **Immediate Price Impact**: OI changes in weekly/front-month options create immediate buying/selling pressure
3. **Conviction Signal**: Large OI increases in near-term strikes indicate high-conviction directional positioning
4. **Time-Sensitive**: Far-dated options (30+ DTE) have minimal immediate impact on price action

**Analysis Priority (by DTE):**
- **0-7 DTE (Weeklies/Front Week)**: HIGHEST priority - Maximum gamma exposure, immediate dealer hedging required
- **8-14 DTE (Next Week)**: HIGH priority - Significant near-term impact
- **15-30 DTE (Front Month)**: MODERATE priority - Some near-term relevance
- **30+ DTE (Back Months)**: LOW priority - Minimal immediate impact, background positioning only

When reporting top strikes and flow patterns, EXPLICITLY PRIORITIZE and CALL OUT near-term expiry option changes.
If there are large OI changes in 0-7 DTE options, these should dominate your analysis and signal strength determination.

Example prioritization:
"The most significant flow is in THIS FRIDAY's (3 DTE) $150 calls with +5,000 OI. This near-term positioning
suggests immediate bullish pressure through dealer gamma hedging, far outweighing the -2,000 OI decrease in
the 45 DTE $155 calls."

TRADING LEVELS RECOMMENDATION:
Based on your option flow analysis (gamma walls from NEAR-TERM options, support/resistance from front-week positioning), provide:

1. **Buy the Dip Range**: If conditions support buying on weakness, specify:
   - Price range for buy entry (e.g., "$XXX - $YYY")
   - Rationale based on put wall (support) identified from NEAR-TERM put OI concentrations
   - Reference specific strikes and expiries driving the support level
   - If NOT recommending buy the dip, explicitly state "Not Recommended" and explain why

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Rationale based on call wall (resistance) identified from NEAR-TERM call OI concentrations
   - Reference specific strikes and expiries driving the resistance level
   - If NOT recommending sell the rip, explicitly state "Not Recommended" and explain why

Example format:
"**Buy the Dip Range:** $148 - $150. This range aligns with the Put Wall at $150 where THIS FRIDAY's expiry
shows +8,500 put OI concentration. Dealers will aggressively buy stock to hedge as price approaches this level."

"**Sell the Rip Range:** Not Recommended. Current option flow shows heavy call buying in 0-7 DTE strikes,
suggesting bullish institutional positioning with imminent gamma squeeze potential above $155."

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
        include_signal_strength_prompt: bool = True,
        option_trades: Optional[str] = None,
        price_bars_30m: Optional[str] = None,
    ) -> str:
        """
        Replace template variables with actual values.

        Replaces:
        - {{ recent_data }} with tab-delimited data
        - {{ stock_code }} with base stock code (optional)
        - {{ observation_date }} with observation date (optional)
        - {{ option_trades }} with option trade data (optional)
        - {{ price_bars_30m }} with 30-minute price bar data (optional)

        If a placeholder is not found in the template, the data is appended to the end.

        Args:
            template: Template content with placeholders
            recent_data: Tab-delimited GEX features data
            stock_code: Base stock code (optional)
            observation_date: Observation date string (optional)
            include_signal_strength_prompt: Whether to prepend signal strength classification instructions
            option_trades: Formatted option trade data (optional)
            price_bars_30m: Formatted 30-minute price bar data (optional)

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

        # Inject option trades data
        if option_trades is not None:
            has_placeholder = "{{ option_trades }}" in result or "{{option_trades}}" in result
            if has_placeholder:
                result = result.replace("{{ option_trades }}", option_trades)
                result = result.replace("{{option_trades}}", option_trades)
            else:
                result = result.rstrip() + "\n\n## Latest Option Trades (Size > 300)\n\n" + option_trades

        # Inject 30-minute price bar data
        if price_bars_30m is not None:
            has_placeholder = "{{ price_bars_30m }}" in result or "{{price_bars_30m}}" in result
            if has_placeholder:
                result = result.replace("{{ price_bars_30m }}", price_bars_30m)
                result = result.replace("{{price_bars_30m}}", price_bars_30m)
            else:
                result = result.rstrip() + "\n\n## 30-Minute Price Bars (Last 5 Days)\n\n" + price_bars_30m

        logger.info(f"Injected variables into template ({len(result)} characters after injection)")

        return result
