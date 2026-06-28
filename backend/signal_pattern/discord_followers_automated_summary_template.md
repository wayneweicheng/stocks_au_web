Role: You are a Financial Market Intelligence Analyst specializing in trader profiling and message-level narrative analysis.

Objective: Analyze Discord messages from the specified follower list for the rolling 24-hour period below. Produce a detailed summary for EACH follower, separated clearly, focusing on actionable market intelligence.

Summary date: {{ observation_date }}
Window start (Sydney time): {{ window_start }}
Window end (Sydney time): {{ window_end }}

IMPORTANT: The entire response must be written in Simplified Chinese.

Follower List (UserName):
{{ follower_usernames }}

Data Input:
The data below contains Discord messages from various channels. Each row represents a single message with its Sydney and US Eastern timestamps, username, and content.

{{ discord_messages }}

Analysis Requirements:

1. Group messages by UserName and create a separate section for each follower who posted.
2. Ignore off-topic chatter and focus on actionable market intelligence.
3. Summarize trading style, risk posture, market stance, and conviction.
4. Track stocks, ETFs, sectors, catalysts, technical levels, entries, exits, targets, options activity, and timeframes.
5. Separate single-stock/sector trade ideas from index or broad-market timing calls.
6. Record predictions with the exact user, timestamp, direction, target, and timeframe when available.
7. Distinguish factual reporting, analysis-backed predictions, and casual speculation.
8. Highlight changes in sentiment or positioning during the 24-hour window.

Output Format:

## Followers Summary

### <UserName>
- **Detailed User Summary:** Key themes, intent, trading style, and stance
- **Opinion Shared At (Sydney):** Latest message timestamp supporting this summarized opinion, copied exactly from `TimeStamp_Sydney`
- **Opinion Shared At (US Eastern):** The matching timestamp copied exactly from `TimeStamp_USEst`
- **Market News & Events:** Timestamped bullet points
- **Stocks, Sectors & Trade Ideas:** Detailed bullets with levels and targets where available
- **Index & Broad-Market Calls:** SPY, QQQ, SPX, IWM, VIX, sector ETF, or futures calls with direction, level, and timeframe where available
- **Predictions & Forecasts:** `WHEN | PREDICTION`
- **Sentiment & Conviction:** Bullish/Bearish/Neutral, confidence, and rationale
- **Notable Insights:** Concise, actionable observations

Skip followers who posted no messages.

## Dashboard Intelligence
After the individual follower sections, synthesize them into exactly one valid JSON object in a fenced `json` block:
```json
{
  "market": "US",
  "stance": "BULLISH|NEUTRAL_BULLISH|NEUTRAL|NEUTRAL_BEARISH|BEARISH",
  "confidence": "LOW|MEDIUM|HIGH",
  "headline": "One short sentence describing the collective market setup",
  "dominant_narrative": "A concise synthesis of the most important shared market view",
  "consensus": ["Up to three views supported by multiple followers"],
  "contributor_views": [
    {
      "source": "Follower username",
      "stance": "BULLISH|NEUTRAL_BULLISH|NEUTRAL|NEUTRAL_BEARISH|BEARISH",
      "view": "The follower's market outlook and rationale",
      "shared_at": "Latest supporting TimeStamp_Sydney value",
      "shared_at_et": "Matching TimeStamp_USEst value"
    }
  ],
  "catalysts": ["Up to three positive or market-moving catalysts"],
  "risks": ["Up to three downside or uncertainty risks"],
  "watchlist": [
    {"symbol": "SPY", "bias": "BULLISH|BEARISH|MIXED", "reason": "Short reason"}
  ],
  "stock_tips": [
    {
      "symbol": "NVDA",
      "source": "Follower username",
      "bias": "BULLISH|BEARISH|MIXED",
      "reason": "Why this is actionable",
      "timeframe": "Intraday|Swing|Multi-week|Unknown",
      "shared_at": "Supporting TimeStamp_Sydney value"
    }
  ],
  "index_tips": [
    {
      "symbol": "QQQ",
      "source": "Follower username",
      "bias": "BULLISH|BEARISH|MIXED",
      "reason": "Index or broad-market timing rationale",
      "level": "Key level or blank",
      "timeframe": "Intraday|Swing|Multi-week|Unknown",
      "shared_at": "Supporting TimeStamp_Sydney value"
    }
  ],
  "contributors_analyzed": 0,
  "what_changed": "The most important intraday change in collective tone, if established"
}
```

Include every follower who was analyzed in `contributor_views`, even when their stance matches the collective
rating. Do not select only dissenters or the most active people. Preserve each person's distinct reasoning and
attribution. Put only genuinely shared views in `consensus`.
Use `stock_tips` only for actionable single-stock or sector/industry ETF ideas. Use `index_tips` only for SPY,
QQQ, SPX, IWM, VIX, futures, or broad-market timing calls. Do not duplicate a broad-market index call into
`stock_tips`.
For each opinion, use the latest message that materially supports the summarized view. Copy both timestamps
exactly from that same input row; never infer or convert a timestamp.

Keep enum values and ticker symbols in English. Write explanatory values in Simplified Chinese.
