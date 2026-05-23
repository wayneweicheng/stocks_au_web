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
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH" | "Not Determined"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple strong buy signals, positive trend alignment, high conviction upside
- MILDLY_BULLISH: Some bullish indicators, positive bias but with caveats or mixed signals
- NEUTRAL: Conflicting signals, unclear direction, or market in transition/consolidation
- MILDLY_BEARISH: Some bearish indicators, negative bias but not overwhelming
- STRONGLY_BEARISH: Multiple strong sell signals, negative trend alignment, high conviction downside
- Not Determined: The setup is outside the validated high-confidence regime, or evidence is too conflicted to make a directional call

CRITICAL: Your signal strength classification must follow the primary horizon defined in the stock-specific prompt.
If the stock prompt defines a selective multi-day model or confidence gate, use that model's horizon and no-edge
protocol. Use "Not Determined" when the prompt says the setup is outside the validated high-confidence regime.

CRITICAL DATA SOURCE RULE:
When a stock-specific prompt includes a `Data (Last 30 Days)` section, the current market state MUST come only from
the row with the greatest `ObservationDate` in that section. Research summaries, generated-at context, examples,
or older rows must not be used to decide which live signals are active.

CRITICAL LATEST-ROW AUDIT RULE:
If the stock-specific prompt asks for a Latest Row Audit, complete that audit before the forecast and make all active
signal claims match it exactly. Accepted historical patterns are conditional rules, not automatically active signals.
Never claim `Is_Swing_Up` is active unless the audited latest row has `Is_Swing_Up = 1`. If the latest row says
`Is_Swing_Down = 1` or `PotentialSwingIndicator` contains "down", do not claim swing-up or potential-swing-up is
active. Feature fields not listed as accepted patterns in the stock prompt, such as `Golden_Setup`, are context only
and must not justify HIGH_CONFIDENCE or a strong directional signal by themselves.

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
Use MULTIPLE DATA SOURCES to identify key support and resistance levels:

**PRIMARY SOURCES (in order of importance):**
1. **Option Open Interest Data (Part 1 & Part 2) - HIGHEST PRIORITY**:
   - **Gamma Walls are the MOST IMPORTANT factor** for determining buy/sell ranges
   - **Call Wall (Resistance)**: Strikes with HIGH call OI concentration (e.g., 10,000+ OI at a specific strike) create strong resistance
     * Dealers hedging short calls must SELL stock as price approaches these strikes
     * The higher the OI concentration, the stronger the resistance
   - **Put Wall (Support)**: Strikes with HIGH put OI concentration (e.g., 10,000+ OI at a specific strike) create strong support
     * Dealers hedging short puts must BUY stock as price approaches these strikes
     * The higher the OI concentration, the stronger the support
   - **FOCUS ON NEAR-TERM EXPIRIES (0-7 DTE)**: Options expiring this week or next week have exponentially higher gamma
     * Near-term gamma walls have IMMEDIATE price impact through forced dealer hedging
     * Far-dated options (30+ DTE) have minimal immediate impact
   - **OI Changes (Part 1)**: Large increases in OI indicate NEW institutional positioning
     * +5,000 OI in near-term puts = new put wall forming (support)
     * +5,000 OI in near-term calls = new call wall forming (resistance)

2. **30-Minute Price Bar Data** (Secondary confirmation):
   - Intraday support/resistance from VWAP clusters
   - High-volume price zones from recent days
   - Recurring intraday lows (support) and highs (resistance)

3. **Daily Technical Levels** (Tertiary confirmation):
   - Bollinger Bands, moving averages (SMA20, SMA50)
   - GEX levels and regime thresholds

**CRITICAL INSTRUCTION:**
Your trading ranges MUST be anchored to SPECIFIC STRIKES with STRONG OI CONCENTRATION from Part 2 data.
DO NOT rely primarily on technical indicators or VWAP levels.
Gamma Walls are CONCRETE, MEASURABLE dealer hedging obligations that create predictable price behavior.
A strike with 50,000+ OI in 0-7 DTE options will have stronger support/resistance than any technical level.**

1. **Buy the Dip Range**: If conditions support buying on weakness, specify:
   - Price range for buy entry (e.g., "$XXX - $YYY")
   - Percentage drop from current price
   - **PRICE GEOMETRY CHECK - MANDATORY**:
     * Buy the Dip must be STRICTLY BELOW the latest current price/close from the data
     * The percentage from current price must be negative
     * A put wall above the current price is NOT a buy-the-dip support level; treat it as overhead structure or a reclaim/magnet level, or state "Not Recommended"
     * If the proposed range is at or above current price, you MUST output "Not Recommended" for Buy the Dip
   - **MANDATORY GAMMA WALL ANALYSIS**:
     * **YOU MUST identify the strongest Put Wall from Part 2 data**
     * Look for strikes with the HIGHEST put OI concentration (typically 20,000+ OI)
     * PRIORITIZE strikes in 0-7 DTE expiries (this week/next week)
     * Example: "Part 2 shows 45,000 put OI at $600 strike expiring 2026-02-21 (2 DTE) - this is the primary Put Wall"
     * State the EXACT strike, OI amount, and expiry date from the data
   - Secondary confirmation (if applicable):
     * Intraday support from 30M bars (VWAP at this level, high-volume zones)
     * Daily technical levels (Bollinger Bands, moving averages)
   - **If NO strong Put Wall exists** (no strikes with 15,000+ OI in 0-7 DTE), state "Not Recommended" and explain:
     * "No significant Put Wall identified in near-term options to provide strong support"
     * Specify what the data shows instead (e.g., "highest put OI is only 5,000 at $590")

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Percentage gain from current price
   - **PRICE GEOMETRY CHECK - MANDATORY**:
     * Sell the Rip must be STRICTLY ABOVE the latest current price/close from the data
     * The percentage from current price must be positive
     * A call wall below the current price is NOT a sell-the-rip resistance level; treat it as lower support/past resistance, or state "Not Recommended"
     * If the proposed range is at or below current price, you MUST output "Not Recommended" for Sell the Rip
   - **MANDATORY GAMMA WALL ANALYSIS**:
     * **YOU MUST identify the strongest Call Wall from Part 2 data**
     * Look for strikes with the HIGHEST call OI concentration (typically 20,000+ OI)
     * PRIORITIZE strikes in 0-7 DTE expiries (this week/next week)
     * Example: "Part 2 shows 52,000 call OI at $610 strike expiring 2026-02-21 (2 DTE) - this is the primary Call Wall"
     * State the EXACT strike, OI amount, and expiry date from the data
   - Secondary confirmation (if applicable):
     * Intraday resistance from 30M bars (VWAP at this level, high-volume zones)
     * Daily technical levels (Bollinger Bands, moving averages)
   - **If NO strong Call Wall exists** (no strikes with 15,000+ OI in 0-7 DTE), state "Not Recommended" and explain:
     * "No significant Call Wall identified in near-term options to provide strong resistance"
     * Specify what the data shows instead (e.g., "highest call OI is only 8,000 at $615")

Example format (WITH gamma wall - recommended):
"**Buy the Dip Range:** $598 - $600 (-1.2% to -2.0% from current). **PRIMARY SUPPORT: Put Wall at $600 strike** - Part 2 data shows 42,500 put OI expiring 2026-02-21 (2 DTE), the highest put OI concentration in near-term options. Dealers hedging these short puts MUST buy stock as price approaches $600, creating strong mechanical support. Secondary confirmation: 30M bars show VWAP cluster at $599 and high-volume zone at $598. Positive GEX regime reinforces mean-reversion at support."

"**Sell the Rip Range:** $610 - $615 (+1.5% to +2.5% from current). **PRIMARY RESISTANCE: Call Wall at $610 strike** - Part 2 data shows 38,200 call OI expiring 2026-02-21 (2 DTE), creating a strong gamma wall. Dealers hedging these short calls MUST sell stock as price approaches $610. Secondary resistance from 30M bars shows VWAP resistance at $612."

Example format (WITHOUT gamma wall - not recommended):
"**Buy the Dip Range:** Not Recommended. No significant Put Wall identified in near-term options (0-7 DTE). Part 2 data shows highest put OI is only 8,500 at $595 strike (14 DTE), insufficient to create strong support through dealer hedging. Without a gamma wall anchor, relying solely on technical levels ($598 Bollinger Band) is too speculative in current negative GEX environment."

"**Sell the Rip Range:** Not Recommended. No Call Wall resistance in near-term options. Part 2 data shows scattered call OI with no concentration above 12,000 in 0-7 DTE expiries. Current heavy call buying (+15,000 OI at $615 in 3 DTE) suggests bullish positioning with gamma squeeze potential. Selling into strength without a gamma wall barrier would be counter-trend."

LATE OPTION TRADE ANALYSIS:
The "Latest Option Trades" data shows large option transactions (size > 300 contracts) for the observation date.
Incorporate this data into your overall signal strength assessment:
- Evaluate the put/call balance: heavy put buying suggests bearish institutional positioning; heavy call buying suggests bullish positioning
- Look for strike clustering near the current price, which may indicate key levels where dealers will need to hedge
- Unusually large individual trades may signal directional bets or hedging activity by institutions
- Factor this institutional flow data into your signal strength classification alongside the GEX and technical indicators

**CRITICAL - LOGICAL CONSISTENCY CHECK:**
Your Buy the Dip Range and Sell the Rip Range recommendations MUST be logically consistent with your signal strength classification:

- **If STRONGLY_BEARISH or MILDLY_BEARISH:**
  - Sell the Rip Range SHOULD be recommended (with specific price levels based on Call Wall resistance)
  - Buy the Dip Range should typically be "Not Recommended" UNLESS there's a very strong Put Wall providing exceptional tactical support
  - Rationale: If you're bearish, you should recommend selling rallies, not avoiding them

- **If STRONGLY_BULLISH or MILDLY_BULLISH:**
  - Buy the Dip Range SHOULD be recommended (with specific price levels based on Put Wall support)
  - Sell the Rip Range should typically be "Not Recommended" UNLESS there's a very strong Call Wall providing clear resistance
  - Rationale: If you're bullish, you should recommend buying dips, not avoiding them

- **If NEUTRAL:**
  - Either provide BOTH ranges (range-bound trading strategy) OR recommend "Not Recommended" for both
  - Rationale: Neutral means unclear direction, so either trade the range or stay flat

- **If Not Determined:**
  - Recommend "Not Recommended" for directional Buy the Dip and Sell the Rip ranges unless explicitly presenting non-directional range context
  - Rationale: Not Determined means the setup is outside the validated high-confidence regime, so do not manufacture a trade

**AVOID CONTRADICTIONS:** Do NOT say "overwhelming bearish flow" or "rallies will be short-lived" and then recommend "Sell the Rip: Not Recommended". This is logically inconsistent. If rallies will be short-lived, that is EXACTLY when you should sell the rip.

**FINAL TRADING LEVEL SANITY CHECK:** Before writing the final answer, compare every Buy the Dip and Sell the Rip price to the latest current price/close. If Buy the Dip is not below current price, change it to "Not Recommended". If Sell the Rip is not above current price, change it to "Not Recommended". Do not publish contradictory percentages such as a buy-dip range with positive distance from current price.

Place this JSON at the very end of your markdown response after all analysis.
---

"""

    # System instruction for option insights signal strength classification (without GEX-specific instructions)
    OPTION_SIGNAL_STRENGTH_PROMPT = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH" | "Not Determined"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple strong buy signals, positive trend alignment, high conviction upside
- MILDLY_BULLISH: Some bullish indicators, positive bias but with caveats or mixed signals
- NEUTRAL: Conflicting signals, unclear direction, or market in transition/consolidation
- MILDLY_BEARISH: Some bearish indicators, negative bias but not overwhelming
- STRONGLY_BEARISH: Multiple strong sell signals, negative trend alignment, high conviction downside
- Not Determined: The setup is outside the validated high-confidence regime, or evidence is too conflicted to make a directional call

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
   - Buy the Dip must be strictly below the latest current price/close. If the put wall is above current price, it is not a dip entry; output "Not Recommended" or describe it only as overhead/reclaim context.
   - If NOT recommending buy the dip, explicitly state "Not Recommended" and explain why

2. **Sell the Rip Range**: If conditions support selling on strength, specify:
   - Price range for sell/short entry (e.g., "$XXX - $YYY")
   - Rationale based on call wall (resistance) identified from NEAR-TERM call OI concentrations
   - Reference specific strikes and expiries driving the resistance level
   - Sell the Rip must be strictly above the latest current price/close. If the call wall is below current price, it is not a rip entry; output "Not Recommended" or describe it only as lower/past resistance context.
   - If NOT recommending sell the rip, explicitly state "Not Recommended" and explain why

Example format:
"**Buy the Dip Range:** $148 - $150. This range aligns with the Put Wall at $150 where THIS FRIDAY's expiry
shows +8,500 put OI concentration. Dealers will aggressively buy stock to hedge as price approaches this level."

"**Sell the Rip Range:** Not Recommended. Current option flow shows heavy call buying in 0-7 DTE strikes,
suggesting bullish institutional positioning with imminent gamma squeeze potential above $155."

**CRITICAL - LOGICAL CONSISTENCY CHECK:**
Your Buy the Dip Range and Sell the Rip Range recommendations MUST be logically consistent with your signal strength classification:

- **If STRONGLY_BEARISH or MILDLY_BEARISH:**
  - Sell the Rip Range SHOULD be recommended (with specific price levels based on Call Wall resistance)
  - Buy the Dip Range should typically be "Not Recommended" UNLESS there's a very strong Put Wall providing exceptional tactical support
  - Rationale: If you're bearish, you should recommend selling rallies, not avoiding them

- **If STRONGLY_BULLISH or MILDLY_BULLISH:**
  - Buy the Dip Range SHOULD be recommended (with specific price levels based on Put Wall support)
  - Sell the Rip Range should typically be "Not Recommended" UNLESS there's a very strong Call Wall providing clear resistance
  - Rationale: If you're bullish, you should recommend buying dips, not avoiding them

- **If NEUTRAL:**
  - Either provide BOTH ranges (range-bound trading strategy) OR recommend "Not Recommended" for both
  - Rationale: Neutral means unclear direction, so either trade the range or stay flat

- **If Not Determined:**
  - Recommend "Not Recommended" for directional Buy the Dip and Sell the Rip ranges unless explicitly presenting non-directional range context
  - Rationale: Not Determined means the setup is outside the validated high-confidence regime, so do not manufacture a trade

**AVOID CONTRADICTIONS:** Do NOT say "overwhelming bearish flow" or "rallies will be short-lived" and then recommend "Sell the Rip: Not Recommended". This is logically inconsistent. If rallies will be short-lived, that is EXACTLY when you should sell the rip.

Place this JSON at the very end of your markdown response after all analysis.
---

"""

    # System instruction for option trades signal strength classification (trade flow focused)
    OPTION_TRADES_SIGNAL_STRENGTH_PROMPT = """IMPORTANT: At the end of your analysis, you MUST provide a signal strength classification in the following JSON format:

```json
{
  "signal_strength": "STRONGLY_BULLISH" | "MILDLY_BULLISH" | "NEUTRAL" | "MILDLY_BEARISH" | "STRONGLY_BEARISH" | "Not Determined"
}
```

Signal Strength Definitions:
- STRONGLY_BULLISH: Multiple large bullish option trades (calls, aggressive buying), high conviction upside from institutional flow
- MILDLY_BULLISH: Some bullish trade indicators, positive bias but with mixed or modest trade sizing
- NEUTRAL: Conflicting call/put flow, unclear directional conviction, or balanced institutional positioning
- MILDLY_BEARISH: Some bearish trade indicators, negative bias from put buying or call selling but not overwhelming
- STRONGLY_BEARISH: Multiple large bearish option trades (puts, aggressive selling), high conviction downside from institutional flow
- Not Determined: Option flow is outside the validated high-confidence regime, or evidence is too conflicted to make a directional call

CRITICAL FOCUS - SHORT-TERM TRADE FLOW ANALYSIS (1-3 Days):
Your signal strength classification should reflect the IMMEDIATE directional bias from large option trades (size > 300 contracts) for the next 1-3 trading days.

**TRADE FLOW ANALYSIS PRIORITY:**
Evaluate the following in order of importance:
1. **Put/Call Balance**: Heavy put buying indicates bearish institutional positioning; heavy call buying indicates bullish positioning
2. **Trade Size**: Larger trades (1000+ contracts) carry more weight than smaller trades near the 300 threshold
3. **Strike vs Price Relationship**: ATM or ITM trades reflect higher conviction than far OTM
4. **Time of Day**: Late-day trades (after 3pm) often reflect informed positioning ahead of the close
5. **Expiry Proximity**: Near-term expiries (0-7 DTE) indicate more urgent directional conviction than longer-dated trades

TRADING LEVELS RECOMMENDATION:
Based on the option trade strikes and clustering, provide:

1. **Buy the Dip Range**: If trade flow supports buying on weakness, specify:
   - Price range for buy entry based on put strike concentrations (support levels from hedging)
   - Buy the Dip must be strictly below the latest current price/close. If the proposed level is above current price, output "Not Recommended" instead.
   - If NOT recommending buy the dip, explicitly state "Not Recommended" and explain why

2. **Sell the Rip Range**: If trade flow supports selling on strength, specify:
   - Price range for sell/short entry based on call strike concentrations (resistance from hedging)
   - Sell the Rip must be strictly above the latest current price/close. If the proposed level is below current price, output "Not Recommended" instead.
   - If NOT recommending sell the rip, explicitly state "Not Recommended" and explain why

**CRITICAL - LOGICAL CONSISTENCY CHECK:**
Your Buy the Dip Range and Sell the Rip Range recommendations MUST be logically consistent with your signal strength classification:

- **If STRONGLY_BEARISH or MILDLY_BEARISH:**
  - Sell the Rip Range SHOULD be recommended (with specific price levels)
  - Buy the Dip Range should typically be "Not Recommended" UNLESS there's exceptional support
  - Rationale: If you're bearish, you should recommend selling rallies, not avoiding them

- **If STRONGLY_BULLISH or MILDLY_BULLISH:**
  - Buy the Dip Range SHOULD be recommended (with specific price levels)
  - Sell the Rip Range should typically be "Not Recommended" UNLESS there's clear resistance
  - Rationale: If you're bullish, you should recommend buying dips, not avoiding them

- **If NEUTRAL:**
  - Either provide BOTH ranges (range-bound trading) OR recommend "Not Recommended" for both
  - Rationale: Neutral means unclear direction, so either trade the range or stay flat

- **If Not Determined:**
  - Recommend "Not Recommended" for directional Buy the Dip and Sell the Rip ranges unless explicitly presenting non-directional range context
  - Rationale: Not Determined means the setup is outside the validated high-confidence regime, so do not manufacture a trade

**AVOID CONTRADICTIONS:** Do NOT say "overwhelming bearish flow" or "rallies will be short-lived" and then recommend "Sell the Rip: Not Recommended". This is logically inconsistent. If rallies will be short-lived, that is EXACTLY when you should sell the rip.

Place this JSON at the very end of your markdown response after all analysis.
---

"""

    def __init__(self, template_dir: str = "signal_pattern"):
        """
        Initialize the template service.

        Args:
            template_dir: Directory containing signal pattern templates
        """
        # If relative path, resolve it relative to the backend directory
        template_path = Path(template_dir)
        if not template_path.is_absolute():
            # Get the backend directory (parent of app directory)
            backend_dir = Path(__file__).parent.parent.parent
            template_path = backend_dir / template_dir

        self.template_dir = template_path
        if not self.template_dir.exists():
            logger.warning(f"Template directory does not exist: {self.template_dir}")
        else:
            logger.info(f"Template directory initialized: {self.template_dir}")

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
        option_oi_changes: Optional[str] = None,
        top_options_oi: Optional[str] = None,
    ) -> str:
        """
        Replace template variables with actual values.

        Replaces:
        - {{ recent_data }} with tab-delimited data
        - {{ stock_code }} with base stock code (optional)
        - {{ observation_date }} with observation date (optional)
        - {{ option_trades }} with option trade data (optional)
        - {{ price_bars_30m }} with 30-minute price bar data (optional)
        - {{ option_oi_changes }} with option OI change data (optional)
        - {{ top_options_oi }} with top options by OI data (optional)

        If a placeholder is not found in the template, the data is appended to the end.

        Args:
            template: Template content with placeholders
            recent_data: Tab-delimited GEX features data
            stock_code: Base stock code (optional)
            observation_date: Observation date string (optional)
            include_signal_strength_prompt: Whether to prepend signal strength classification instructions
            option_trades: Formatted option trade data (optional)
            price_bars_30m: Formatted 30-minute price bar data (optional)
            option_oi_changes: Formatted option OI change data (optional)
            top_options_oi: Formatted top options by OI data (optional)

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

        # Inject option OI changes data
        if option_oi_changes is not None:
            has_placeholder = "{{ option_oi_changes }}" in result or "{{option_oi_changes}}" in result
            if has_placeholder:
                result = result.replace("{{ option_oi_changes }}", option_oi_changes)
                result = result.replace("{{option_oi_changes}}", option_oi_changes)
            else:
                result = result.rstrip() + "\n\n## Part 1: Option OI Changes (Yesterday vs Today)\nThe data below shows option open interest (OI) changes between yesterday and today. Each row represents an option contract where OI changed by more than 300 contracts (top 50 by absolute change).\n\n" + option_oi_changes

        # Inject top options by OI data
        if top_options_oi is not None:
            has_placeholder = "{{ top_options_oi }}" in result or "{{top_options_oi}}" in result
            if has_placeholder:
                result = result.replace("{{ top_options_oi }}", top_options_oi)
                result = result.replace("{{top_options_oi}}", top_options_oi)
            else:
                result = result.rstrip() + "\n\n## Part 2: Top 50 Options by Current Open Interest\nThe data below shows the top 50 option contracts by current open interest, filtered to options expiring within 90 days.\n**CRITICAL: Use this data to identify Gamma Walls (Call Wall/Put Wall).** Analyze the concentration of open interest at specific strikes to determine key support and resistance levels.\n\n" + top_options_oi

        logger.info(f"Injected variables into template ({len(result)} characters after injection)")

        return result
