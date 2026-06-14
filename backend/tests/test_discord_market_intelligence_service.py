from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from app.services.discord_market_intelligence_service import (
    DEFAULT_DISCORD_SUMMARY_MODEL,
    FOLLOWER_USERNAMES,
    DiscordFollowerMarketIntelligenceService,
    DiscordMarketIntelligenceService,
)


class FakeGEXService:
    def __init__(self):
        self.window = None

    def get_discord_messages_between(self, window_start, window_end):
        self.window = (window_start, window_end)
        return [{"UserName": "Trader", "Content": "SPY bullish"}]

    def get_discord_messages_between_by_users(self, window_start, window_end, usernames):
        self.window = (window_start, window_end)
        self.usernames = usernames
        return [{"UserName": usernames[0], "Content": "SPY bullish"}]

    def format_discord_messages_as_pipe_delimited(self, rows):
        return "UserName|Content\nTrader|SPY bullish"


class FakeLLMService:
    def __init__(self):
        self.call = None

    def generate_prediction(self, **kwargs):
        self.call = kwargs
        return {"prediction_text": "# Summary\nBullish"}


class FakeTimestampGEXService(FakeGEXService):
    def get_discord_messages_between_by_users(self, window_start, window_end, usernames):
        self.window = (window_start, window_end)
        self.usernames = usernames
        return [
            {
                "UserName": "Beta",
                "TimeStamp_Sydney": datetime(2026, 6, 13, 7, 45),
                "TimeStamp_USEst": datetime(2026, 6, 12, 17, 45),
                "Content": "SPY can grind higher",
            }
        ]


def test_summary_window_is_rolling_24_hours_in_sydney():
    start, end = DiscordMarketIntelligenceService.summary_window(date(2026, 6, 13))

    assert start.isoformat() == "2026-06-12T16:00:00+10:00"
    assert end.isoformat() == "2026-06-13T16:00:00+10:00"


def test_current_summary_date_uses_last_completed_4pm_window():
    tz = ZoneInfo("Australia/Sydney")

    assert DiscordMarketIntelligenceService.current_summary_date(
        datetime(2026, 6, 13, 15, 59, tzinfo=tz)
    ) == date(2026, 6, 12)
    assert DiscordMarketIntelligenceService.current_summary_date(
        datetime(2026, 6, 13, 16, 0, tzinfo=tz)
    ) == date(2026, 6, 13)


def test_generation_is_cached_with_metadata(tmp_path: Path):
    template = tmp_path / "template.md"
    template.write_text(
        "{{ window_start }}\n{{ window_end }}\n{{ discord_messages }}",
        encoding="utf-8",
    )
    gex = FakeGEXService()
    llm = FakeLLMService()
    service = DiscordMarketIntelligenceService(
        gex_service=gex,
        llm_service=llm,
        cache_dir=str(tmp_path / "cache"),
        template_path=str(template),
    )

    generated = service.generate_summary(date(2026, 6, 13))
    cached = service.generate_summary(date(2026, 6, 13))

    assert generated["cached"] is False
    assert generated["message_count"] == 1
    assert generated["model"] == DEFAULT_DISCORD_SUMMARY_MODEL
    assert cached["cached"] is True
    assert cached["summary_markdown"] == "# Summary\nBullish"
    assert "2026-06-12T16:00:00+10:00" in llm.call["prompt"]


def test_automated_follower_generation_filters_users_and_uses_separate_cache(tmp_path: Path):
    template = tmp_path / "followers-template.md"
    template.write_text(
        "{{ follower_usernames }}\n{{ window_start }}\n{{ discord_messages }}",
        encoding="utf-8",
    )
    gex = FakeGEXService()
    llm = FakeLLMService()
    service = DiscordFollowerMarketIntelligenceService(
        gex_service=gex,
        llm_service=llm,
        cache_dir=str(tmp_path / "followers-cache"),
        template_path=str(template),
    )

    result = service.generate_summary(date(2026, 6, 13))

    assert result["cached"] is False
    assert gex.usernames == FOLLOWER_USERNAMES
    assert ", ".join(FOLLOWER_USERNAMES) in llm.call["prompt"]
    assert (tmp_path / "followers-cache" / "DISCORD_FOLLOWERS_AUTO_20260613.md").exists()


def test_dashboard_digest_uses_structured_block(tmp_path: Path):
    cache = tmp_path / "cache"
    cache.mkdir()
    (cache / "DISCORD_20260613.md").write_text(
        """## Executive Summary
Markets were mixed.

## Dashboard Intelligence
```json
{
  "market": "US",
  "stance": "NEUTRAL_BULLISH",
  "confidence": "HIGH",
  "headline": "Semiconductors lead a selective advance.",
  "dominant_narrative": "Leadership is narrow but improving.",
  "catalysts": ["Cooling inflation"],
  "risks": ["Weak software breadth"],
  "watchlist": [{"symbol": "NVDA", "bias": "BULLISH", "reason": "Leadership"}],
  "what_changed": "Tone improved from neutral."
}
```""",
        encoding="utf-8",
    )
    service = DiscordMarketIntelligenceService(cache_dir=str(cache))

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["available"] is True
    assert digest["stance"] == "NEUTRAL_BULLISH"
    assert digest["stance_score"] == 62
    assert digest["watchlist"][0]["symbol"] == "NVDA"
    assert digest["what_changed"] == "Tone improved from neutral."


def test_dashboard_digest_requires_an_exact_summary_date(tmp_path: Path):
    cache = tmp_path / "cache"
    cache.mkdir()
    (cache / "DISCORD_20260612.md").write_text(
        """## Executive Summary
The index is resilient, but participation remains narrow.

## Market News & Events
* Cooling inflation supports risk assets.

## Stock & Sector Discussion
* **Semiconductors**: NVDA and AMD remain leaders.

## Overall Sentiment Analysis
* **Overall**: Neutral-Bearish.
* **Bullish driver**: Semiconductors remain firm.
* **Bearish driver**: Software breadth is weak and creates downside risk.
""",
        encoding="utf-8",
    )
    service = DiscordMarketIntelligenceService(cache_dir=str(cache))

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["available"] is False
    assert digest["summary_date"] is None
    assert digest["source_status"] == "No cached market-intelligence summary for 2026-06-13"


def test_dashboard_digest_parses_legacy_summary_for_exact_date(tmp_path: Path):
    cache = tmp_path / "cache"
    cache.mkdir()
    (cache / "DISCORD_20260612.md").write_text(
        """## Executive Summary
The index is resilient, but participation remains narrow.

## Stock & Sector Discussion
* **Semiconductors**: NVDA and AMD remain leaders.

## Overall Sentiment Analysis
* **Overall**: Neutral-Bearish.
""",
        encoding="utf-8",
    )
    service = DiscordMarketIntelligenceService(cache_dir=str(cache))

    digest = service.get_dashboard_digest(date(2026, 6, 12))

    assert digest["available"] is True
    assert digest["summary_date"] == "2026-06-12"
    assert digest["stance"] == "NEUTRAL_BEARISH"


def test_follower_dashboard_digest_uses_follower_cache_and_preserves_dissent(tmp_path: Path):
    cache = tmp_path / "followers-cache"
    cache.mkdir()
    (cache / "DISCORD_FOLLOWERS_AUTO_20260613.md").write_text(
        """## Followers Summary

### Alpha
- **Detailed User Summary:** Semiconductors remain the strongest leadership group.
- **Market News & Events:** 2026-06-13 14:35 | Semiconductors remain strong.
- **Sentiment & Conviction:** Bullish, high conviction.
- **Notable Insights:** Buy pullbacks while NVDA holds support.

### Beta
- **Detailed User Summary:** SPY can grind higher if volatility stays contained.
- **Sentiment & Conviction:** Bullish, medium conviction.
- **Notable Insights:** Breadth needs to improve for a durable breakout.

### Contrarian
- **Detailed User Summary:** Index strength is masking weak participation.
- **Sentiment & Conviction:** Bearish, high conviction.
- **Notable Insights:** A break in mega-cap leadership could expose downside risk.
""",
        encoding="utf-8",
    )
    service = DiscordFollowerMarketIntelligenceService(
        cache_dir=str(cache),
        manual_cache_dir=str(tmp_path / "manual-cache"),
    )

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["available"] is True
    assert digest["stance"] == "BULLISH"
    assert digest["contributors_analyzed"] == 3
    assert digest["source"].startswith("Selected Discord followers")
    assert digest["contributor_views"] == [
        {
            "source": "Alpha",
            "stance": "BULLISH",
            "view": "Semiconductors remain the strongest leadership group.",
            "shared_at": "2026-06-13 14:35",
            "shared_at_et": "2026-06-13 00:35",
        },
        {
            "source": "Beta",
            "stance": "BULLISH",
            "view": "SPY can grind higher if volatility stays contained.",
            "shared_at": None,
            "shared_at_et": None,
        },
        {
            "source": "Contrarian",
            "stance": "BEARISH",
            "view": "Index strength is masking weak participation.",
            "shared_at": None,
            "shared_at_et": None,
        }
    ]


def test_follower_dashboard_backfills_missing_time_from_latest_message(tmp_path: Path):
    cache = tmp_path / "followers-cache"
    cache.mkdir()
    (cache / "DISCORD_FOLLOWERS_AUTO_20260613.md").write_text(
        """## Followers Summary

### Beta
- **Detailed User Summary:** SPY can grind higher if volatility stays contained.
- **Sentiment & Conviction:** Bullish, medium conviction.
""",
        encoding="utf-8",
    )
    service = DiscordFollowerMarketIntelligenceService(
        gex_service=FakeTimestampGEXService(),
        cache_dir=str(cache),
        manual_cache_dir=str(tmp_path / "manual-cache"),
    )

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["contributor_views"][0]["shared_at"] == "2026-06-13 07:45:00"
    assert digest["contributor_views"][0]["shared_at_et"] == "2026-06-12 17:45:00"


def test_follower_dashboard_prefers_newer_manual_cache(tmp_path: Path):
    automated_cache = tmp_path / "automated-cache"
    manual_cache = tmp_path / "manual-cache"
    automated_cache.mkdir()
    manual_cache.mkdir()
    automated_path = automated_cache / "DISCORD_FOLLOWERS_AUTO_20260613.md"
    manual_path = manual_cache / "DISCORD_FOLLOWERS_20260613.md"
    automated_path.write_text(
        "## Followers Summary\n\n### Alpha\n- **Detailed User Summary:** Old view.\n",
        encoding="utf-8",
    )
    manual_path.write_text(
        """## Followers Summary

### Alpha
- **Detailed User Summary:** Regenerated view.
- **Opinion Shared At (Sydney):** 2026-06-13 09:25:55
- **Opinion Shared At (US Eastern):** 2026-06-12 19:25:55
""",
        encoding="utf-8",
    )
    automated_path.touch()
    manual_path.touch()
    manual_path.touch()
    service = DiscordFollowerMarketIntelligenceService(
        cache_dir=str(automated_cache),
        manual_cache_dir=str(manual_cache),
    )

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["contributor_views"][0]["view"] == "Regenerated view."
    assert digest["contributor_views"][0]["shared_at"] == "2026-06-13 09:25:55"


def test_follower_dashboard_digest_requires_exact_follower_cache_date(tmp_path: Path):
    cache = tmp_path / "followers-cache"
    cache.mkdir()
    (cache / "DISCORD_FOLLOWERS_AUTO_20260612.md").write_text(
        "## Followers Summary\n\n### Alpha\n- **Sentiment & Conviction:** Bullish.",
        encoding="utf-8",
    )
    service = DiscordFollowerMarketIntelligenceService(
        cache_dir=str(cache),
        manual_cache_dir=str(tmp_path / "manual-cache"),
    )

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["available"] is False
    assert digest["summary_date"] is None


def test_follower_legacy_consensus_requires_repeated_focus(tmp_path: Path):
    cache = tmp_path / "followers-cache"
    cache.mkdir()
    (cache / "DISCORD_FOLLOWERS_AUTO_20260613.md").write_text(
        """## Followers Summary

### Alpha
- **Stocks, Sectors & Trade Ideas:** NVDA and SPCX.
- **Sentiment & Conviction:** Bullish.
- **Notable Quotes & Insights:** NVDA leadership remains intact.

### Beta
- **Stocks, Sectors & Trade Ideas:** SPCX volatility is elevated.
- **Sentiment & Conviction:** Neutral.
- **Notable Quotes & Insights:** Wait for price discovery.
""",
        encoding="utf-8",
    )
    service = DiscordFollowerMarketIntelligenceService(cache_dir=str(cache))

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["consensus"] == ["SPCX was a shared focus across 2 follower profiles."]
    assert "2 follower profiles were analyzed" in digest["dominant_narrative"]


def test_follower_dashboard_lists_every_active_profile_without_a_cap(tmp_path: Path):
    cache = tmp_path / "followers-cache"
    cache.mkdir()
    profiles = []
    for index in range(10):
        profiles.append(
            f"""### Trader{index}
- **Detailed User Summary:** Outlook from trader {index}.
- **Sentiment & Conviction:** {"Bullish" if index < 5 else "Neutral"}.
"""
        )
    profiles.append(
        """### NoPost
- *(该用户在提供的数据中没有发言记录，跳过)*
"""
    )
    (cache / "DISCORD_FOLLOWERS_AUTO_20260613.md").write_text(
        "## Followers Summary\n\n" + "\n".join(profiles),
        encoding="utf-8",
    )
    service = DiscordFollowerMarketIntelligenceService(
        cache_dir=str(cache),
        manual_cache_dir=str(tmp_path / "manual-cache"),
    )

    digest = service.get_dashboard_digest(date(2026, 6, 13))

    assert digest["contributors_analyzed"] == 10
    assert len(digest["contributor_views"]) == 10
    assert [item["source"] for item in digest["contributor_views"]] == [
        f"Trader{index}" for index in range(10)
    ]
