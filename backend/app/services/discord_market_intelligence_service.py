"""Automated Discord market-intelligence summary generation."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
import json
import logging
from pathlib import Path
import re
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo

from app.services.gex_data_service import GEXDataService
from app.services.llm_prediction_service import LLMPredictionService
from app.services.prediction_cache_service import PredictionCacheService

logger = logging.getLogger("app.discord_market_intelligence")

SYDNEY_TIMEZONE = ZoneInfo("Australia/Sydney")
US_EASTERN_TIMEZONE = ZoneInfo("America/New_York")
DEFAULT_DISCORD_SUMMARY_MODEL = "google/gemma-4-26b-a4b-it"
FOLLOWER_USERNAMES = [
    "Fanfansd",
    "Williambayc6866",
    "A_beelining_capybara",
    "Ming09082",
    "Will01138",
    "Lancebao",
    "Royalflush88888",
    "Jayoscar2238",
    "Sr5772",
    "Yuanzidan",
]
STANCE_SCORES = {
    "BULLISH": 75,
    "NEUTRAL_BULLISH": 62,
    "NEUTRAL": 50,
    "NEUTRAL_BEARISH": 38,
    "BEARISH": 25,
}


def _plain_text(value: str) -> str:
    value = re.sub(r"!\[[^\]]*]\([^)]*\)", "", value)
    value = re.sub(r"\[([^\]]+)]\([^)]*\)", r"\1", value)
    value = re.sub(r"[*_`#>]", "", value)
    value = re.sub(r"^\s*[-+]\s+", "", value)
    return re.sub(r"\s+", " ", value).strip()


def _truncate(value: str, limit: int = 420) -> str:
    value = _plain_text(value)
    if len(value) <= limit:
        return value
    return value[: limit - 1].rstrip(" ,.;:，。；：") + "…"


def _first_sentence(value: str) -> str:
    value = _plain_text(value)
    match = re.match(r"^(.+?[.!?。！？])", value)
    return _truncate(match.group(1) if match else value, 180)


def _sections(markdown: str) -> Dict[str, str]:
    matches = list(re.finditer(r"(?m)^##\s+(.+?)\s*$", markdown))
    result: Dict[str, str] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(markdown)
        result[match.group(1).strip().lower()] = markdown[match.end() : end].strip()
    return result


def _bullets(section: str) -> List[str]:
    values = []
    for line in section.splitlines():
        if re.match(r"^\s*[-*+]\s+", line):
            text = _truncate(line)
            if text and text not in values:
                values.append(text)
    return values


def _infer_stance(text: str) -> str:
    normalized = text.lower().replace("-", "_").replace(" ", "_")
    if "neutral_bearish" in normalized or "中性偏谨慎" in text or "中性偏空" in text:
        return "NEUTRAL_BEARISH"
    if "neutral_bullish" in normalized or "中性偏乐观" in text or "中性偏多" in text:
        return "NEUTRAL_BULLISH"
    if "bearish" in normalized or "看跌" in text or "悲观" in text:
        return "BEARISH"
    if "bullish" in normalized or "看涨" in text or "乐观" in text:
        return "BULLISH"
    return "NEUTRAL"


def _extract_structured_digest(markdown: str) -> Optional[Dict[str, Any]]:
    match = re.search(
        r"##\s+Dashboard Intelligence\s*.*?```json\s*(\{.*?\})\s*```",
        markdown,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return None
    try:
        value = json.loads(match.group(1))
        return value if isinstance(value, dict) else None
    except json.JSONDecodeError:
        logger.warning("Discord summary contains an invalid Dashboard Intelligence JSON block")
        return None


def _latest_timestamp_in_profile(body: str) -> tuple[str, str]:
    matches = re.findall(r"\b(\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?::\d{2})?)\b", body)
    parsed = []
    for value in matches:
        try:
            timestamp = datetime.fromisoformat(value).replace(tzinfo=SYDNEY_TIMEZONE)
        except ValueError:
            continue
        parsed.append(timestamp)
    if not parsed:
        return "", ""

    latest = max(parsed)
    display_format = "%Y-%m-%d %H:%M:%S" if latest.second else "%Y-%m-%d %H:%M"
    return (
        latest.strftime(display_format),
        latest.astimezone(US_EASTERN_TIMEZONE).strftime(display_format),
    )


def _follower_profiles(markdown: str) -> List[Dict[str, str]]:
    matches = list(re.finditer(r"(?m)^###\s+(.+?)\s*$", markdown))
    profiles = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(markdown)
        body = markdown[match.end() : end].strip()
        details = ""
        sentiment = ""
        notable = ""
        shared_at = ""
        shared_at_et = ""
        for line in body.splitlines():
            plain = _plain_text(line)
            lowered = plain.lower()
            if "detailed user summary:" in lowered:
                details = plain.split(":", 1)[-1].strip()
            elif "sentiment & conviction:" in lowered:
                sentiment = plain.split(":", 1)[-1].strip()
            elif "notable" in lowered and "insights:" in lowered:
                notable = plain.split(":", 1)[-1].strip()
            elif "opinion shared at (sydney):" in lowered:
                shared_at = plain.split(":", 1)[-1].strip()
            elif "opinion shared at (us eastern):" in lowered:
                shared_at_et = plain.split(":", 1)[-1].strip()
        if not shared_at:
            shared_at, shared_at_et = _latest_timestamp_in_profile(body)
        lowered_body = body.lower()
        if not details and any(
            marker in lowered_body
            for marker in (
                "no messages",
                "did not post",
                "没有发言",
                "无发言",
                "未见发言",
                "跳过",
            )
        ):
            continue
        profiles.append(
            {
                "name": _plain_text(match.group(1)),
                "details": details,
                "sentiment": sentiment,
                "notable": notable,
                "shared_at": shared_at,
                "shared_at_et": shared_at_et,
                "body": body,
            }
        )
    return profiles


class DiscordMarketIntelligenceService:
    """Generate and persist one rolling 24-hour Discord summary per Sydney day."""

    def __init__(
        self,
        gex_service: Optional[GEXDataService] = None,
        llm_service: Optional[LLMPredictionService] = None,
        cache_dir: str = "llm_output/discord_message_summary",
        template_path: str = "signal_pattern/discord_summary_template.md",
        cache_key: str = "DISCORD",
        usernames: Optional[List[str]] = None,
    ):
        self.gex_service = gex_service or GEXDataService()
        self.llm_service = llm_service
        self.cache_service = PredictionCacheService(cache_dir=cache_dir)
        self.cache_dir = Path(cache_dir)
        self.template_path = Path(template_path)
        self.cache_key = cache_key
        self.usernames = usernames

    @staticmethod
    def summary_window(summary_date: date) -> tuple[datetime, datetime]:
        window_end = datetime.combine(summary_date, time(16, 0), SYDNEY_TIMEZONE)
        return window_end - timedelta(hours=24), window_end

    @staticmethod
    def current_summary_date(now: Optional[datetime] = None) -> date:
        local_now = now.astimezone(SYDNEY_TIMEZONE) if now else datetime.now(SYDNEY_TIMEZONE)
        if local_now.timetz().replace(tzinfo=None) < time(16, 0):
            return local_now.date() - timedelta(days=1)
        return local_now.date()

    def _metadata_path(self, summary_date: date) -> Path:
        return self.cache_dir / f"{self.cache_key}_{summary_date:%Y%m%d}.json"

    def _read_metadata(self, summary_date: date) -> Dict[str, Any]:
        path = self._metadata_path(summary_date)
        if not path.exists():
            return {}
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            logger.warning("Could not read Discord summary metadata %s: %s", path, exc)
            return {}

    def _write_metadata(self, summary_date: date, metadata: Dict[str, Any]) -> None:
        path = self._metadata_path(summary_date)
        temporary_path = path.with_suffix(".json.tmp")
        temporary_path.write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        temporary_path.replace(path)

    def get_cached_summary(self, summary_date: date) -> Optional[Dict[str, Any]]:
        summary = self.cache_service.get_cached_prediction(self.cache_key, summary_date)
        if summary is None:
            return None

        metadata = self._read_metadata(summary_date)
        window_start, window_end = self.summary_window(summary_date)
        if (
            metadata.get("window_start") != window_start.isoformat()
            or metadata.get("window_end") != window_end.isoformat()
            or metadata.get("cache_key") not in (None, self.cache_key)
        ):
            logger.info(
                "Ignoring legacy or mismatched Discord summary cache for %s",
                summary_date,
            )
            return None

        return {
            "summary_markdown": summary,
            "observation_date": summary_date.isoformat(),
            "summary_date": summary_date.isoformat(),
            "window_start": metadata["window_start"],
            "window_end": metadata["window_end"],
            "generated_at": metadata.get("generated_at"),
            "message_count": metadata.get("message_count"),
            "cached": True,
            "model": metadata.get("model", DEFAULT_DISCORD_SUMMARY_MODEL),
        }

    def _cached_dates(self, as_of: date) -> List[date]:
        values = []
        for path in self.cache_dir.glob(f"{self.cache_key}_????????.md"):
            try:
                value = datetime.strptime(
                    path.stem.removeprefix(f"{self.cache_key}_"),
                    "%Y%m%d",
                ).date()
            except ValueError:
                continue
            if value <= as_of:
                values.append(value)
        return sorted(values, reverse=True)

    def _read_legacy_cache(self, summary_date: date) -> Optional[Dict[str, Any]]:
        path = self.cache_dir / f"{self.cache_key}_{summary_date:%Y%m%d}.md"
        try:
            markdown = path.read_text(encoding="utf-8").strip()
        except OSError as exc:
            logger.warning("Could not read Discord summary cache %s: %s", path, exc)
            return None
        if not markdown:
            return None

        metadata = self._read_metadata(summary_date)
        window_start, window_end = self.summary_window(summary_date)
        return {
            "summary_markdown": markdown,
            "summary_date": summary_date.isoformat(),
            "window_start": metadata.get("window_start", window_start.isoformat()),
            "window_end": metadata.get("window_end", window_end.isoformat()),
            "generated_at": metadata.get("generated_at"),
            "message_count": metadata.get("message_count"),
            "model": metadata.get("model"),
        }

    @staticmethod
    def _dashboard_digest(summary: Dict[str, Any]) -> Dict[str, Any]:
        markdown = summary["summary_markdown"]
        structured = _extract_structured_digest(markdown) or {}
        sections = _sections(markdown)
        profiles = _follower_profiles(markdown)
        executive = sections.get("executive summary", "")
        sentiment = sections.get("overall sentiment analysis", "")
        news = sections.get("market news & events", "")
        stock_discussion = sections.get("stock & sector discussion", "")

        executive_lines = [
            _truncate(line)
            for line in executive.splitlines()
            if _plain_text(line)
        ]
        profile_stances = [
            (profile["name"], _infer_stance(profile["sentiment"] or profile["body"]))
            for profile in profiles
        ]
        stance_counts: Dict[str, int] = {}
        for _, profile_stance in profile_stances:
            stance_counts[profile_stance] = stance_counts.get(profile_stance, 0) + 1
        inferred_follower_stance = (
            max(stance_counts, key=stance_counts.get) if stance_counts else "NEUTRAL"
        )
        stance_distribution = ", ".join(
            f"{count} {profile_stance.lower().replace('_', ' ')}"
            for profile_stance, count in sorted(
                stance_counts.items(),
                key=lambda item: (-item[1], item[0]),
            )
        )
        follower_narrative = (
            f"{len(profiles)} follower profiles were analyzed. "
            f"Views were distributed as {stance_distribution}. "
            "The collective stance reflects the most common view, while material minority opinions are preserved below."
            if profiles
            else ""
        )
        narrative = _truncate(
            str(
                structured.get("dominant_narrative")
                or (executive_lines[0] if executive_lines else follower_narrative)
            ),
            520,
        )
        stance = str(
            structured.get("stance")
            or (inferred_follower_stance if profiles else _infer_stance(sentiment + "\n" + executive))
        ).upper()
        if stance not in STANCE_SCORES:
            stance = "NEUTRAL"

        sentiment_bullets = _bullets(sentiment)
        catalysts = structured.get("catalysts")
        if not isinstance(catalysts, list):
            catalysts = [
                value
                for value in sentiment_bullets
                if any(key in value for key in ("看多", "利好", "bullish", "Bullish"))
            ] or _bullets(news)
            if not catalysts and profiles:
                catalysts = [
                    profile["details"]
                    for profile, (_, profile_stance) in zip(profiles, profile_stances)
                    if profile_stance in {"BULLISH", "NEUTRAL_BULLISH"} and profile["details"]
                ]
        risks = structured.get("risks")
        if not isinstance(risks, list):
            risks = [
                value
                for value in sentiment_bullets
                if any(key in value for key in ("看空", "风险", "担忧", "压力", "bearish", "risk"))
            ]
            if not risks and profiles:
                risks = [
                    profile["details"]
                    for profile, (_, profile_stance) in zip(profiles, profile_stances)
                    if profile_stance in {"BEARISH", "NEUTRAL_BEARISH"} and profile["details"]
                ]

        watchlist = structured.get("watchlist")
        shared_symbols = []
        if not isinstance(watchlist, list):
            excluded = {
                "AI", "AST", "CNBC", "CPI", "CPO", "EST", "ETF", "FED", "FOMO", "GDP", "IPO", "PCB", "PPI",
                "SPX", "US", "USD", "VIX",
            }
            candidates = re.findall(
                r"(?<![A-Z])\$?([A-Z]{2,6})(?![A-Z])",
                stock_discussion or markdown,
            )
            counts: Dict[str, int] = {}
            for symbol in candidates:
                if symbol not in excluded:
                    counts[symbol] = counts.get(symbol, 0) + 1
            if profiles:
                profile_mentions = {
                    symbol: sum(
                        1
                        for profile in profiles
                        if re.search(rf"(?<![A-Z])\$?{re.escape(symbol)}(?![A-Z])", profile["body"])
                    )
                    for symbol in counts
                }
                shared_symbols = [
                    (symbol, count)
                    for symbol, count in sorted(
                        profile_mentions.items(),
                        key=lambda item: (-item[1], item[0]),
                    )
                    if count >= 2
                ]
            watchlist = [
                {"symbol": symbol, "bias": "MIXED"}
                for symbol, _ in sorted(counts.items(), key=lambda item: (-item[1], item[0]))[:8]
            ]

        confidence = str(structured.get("confidence") or "").upper()
        if confidence not in {"LOW", "MEDIUM", "HIGH"}:
            confidence = (
                "HIGH" if "高" in sentiment else "LOW" if "低" in sentiment else "MEDIUM"
            )

        contributor_views = structured.get("contributor_views")
        if profiles:
            contributor_views = [
                {
                    "source": name,
                    "stance": profile_stance,
                    "view": _truncate(
                        next(
                            (
                                profile["details"]
                                or profile["sentiment"]
                                or profile["notable"]
                                for profile in profiles
                                if profile["name"] == name
                            ),
                            "",
                        ),
                        220,
                    ),
                    "shared_at": next(
                        (
                            profile["shared_at"]
                            for profile in profiles
                            if profile["name"] == name
                        ),
                        "",
                    ) or None,
                    "shared_at_et": next(
                        (
                            profile["shared_at_et"]
                            for profile in profiles
                            if profile["name"] == name
                        ),
                        "",
                    ) or None,
                }
                for name, profile_stance in profile_stances
            ]
        elif not isinstance(contributor_views, list):
            contributor_views = structured.get("dissenting_views")
            if not isinstance(contributor_views, list):
                contributor_views = []

        consensus = structured.get("consensus")
        if not isinstance(consensus, list):
            consensus = [
                f"{symbol} was a shared focus across {count} follower profiles."
                for symbol, count in shared_symbols
            ][:3]

        return {
            "available": True,
            "market": "US",
            "summary_date": summary["summary_date"],
            "window_start": summary.get("window_start"),
            "window_end": summary.get("window_end"),
            "generated_at": summary.get("generated_at"),
            "message_count": summary.get("message_count"),
            "stance": stance,
            "stance_score": STANCE_SCORES[stance],
            "confidence": confidence,
            "headline": _first_sentence(
                str(
                    structured.get("headline")
                    or (
                        f"Follower positioning was {stance.lower().replace('_', ' ')}, "
                        "with material minority views."
                        if profiles
                        else narrative
                    )
                )
            ),
            "dominant_narrative": narrative,
            "catalysts": [_truncate(str(value), 220) for value in catalysts[:3]],
            "risks": [_truncate(str(value), 220) for value in risks[:3]],
            "watchlist": watchlist[:8],
            "consensus": [_truncate(str(value), 220) for value in consensus[:3]],
            "contributor_views": contributor_views,
            "contributors_analyzed": len(profiles) or structured.get("contributors_analyzed"),
            "what_changed": _truncate(str(structured.get("what_changed") or ""), 240),
            "source": summary.get("source", "Discord rolling 24-hour market intelligence"),
        }

    def get_dashboard_digest(self, as_of: date) -> Dict[str, Any]:
        cached_dates = self._cached_dates(as_of)
        if as_of not in cached_dates:
            return {
                "available": False,
                "market": "US",
                "summary_date": None,
                "source": "Discord rolling 24-hour market intelligence",
                "source_status": f"No cached market-intelligence summary for {as_of.isoformat()}",
            }

        current = self._read_legacy_cache(as_of)
        if current is None:
            return {
                "available": False,
                "market": "US",
                "summary_date": None,
                "source": "Discord rolling 24-hour market intelligence",
                "source_status": "The latest cached market-intelligence summary could not be read",
            }

        digest = self._dashboard_digest(current)
        previous_dates = [value for value in cached_dates if value < as_of]
        if not digest["what_changed"] and previous_dates:
            previous = self._read_legacy_cache(previous_dates[0])
            if previous:
                previous_digest = self._dashboard_digest(previous)
                if previous_digest["stance"] != digest["stance"]:
                    digest["what_changed"] = (
                        f"Stance changed from {previous_digest['stance'].replace('_', ' ')} "
                        f"to {digest['stance'].replace('_', ' ')}."
                    )
                else:
                    digest["what_changed"] = (
                        f"Stance remains {digest['stance'].replace('_', ' ')}; "
                        "the dominant narrative and watchlist have been refreshed."
                    )
        return digest

    def generate_summary(
        self,
        summary_date: date,
        force_regenerate: bool = False,
        model: str = DEFAULT_DISCORD_SUMMARY_MODEL,
    ) -> Dict[str, Any]:
        if not force_regenerate:
            cached = self.get_cached_summary(summary_date)
            if cached:
                return cached

        window_start, window_end = self.summary_window(summary_date)
        if self.usernames:
            rows = self.gex_service.get_discord_messages_between_by_users(
                window_start,
                window_end,
                self.usernames,
            )
        else:
            rows = self.gex_service.get_discord_messages_between(window_start, window_end)
        if not rows:
            raise ValueError(
                f"No Discord messages found between {window_start.isoformat()} "
                f"and {window_end.isoformat()}"
            )
        if not self.template_path.exists():
            raise FileNotFoundError(f"Discord summary template not found: {self.template_path}")

        discord_data = self.gex_service.format_discord_messages_as_pipe_delimited(rows)
        template = self.template_path.read_text(encoding="utf-8")
        prompt = template
        replacements = {
            "{{ observation_date }}": summary_date.isoformat(),
            "{{observation_date}}": summary_date.isoformat(),
            "{{ window_start }}": window_start.isoformat(),
            "{{window_start}}": window_start.isoformat(),
            "{{ window_end }}": window_end.isoformat(),
            "{{window_end}}": window_end.isoformat(),
            "{{ discord_messages }}": discord_data,
            "{{discord_messages}}": discord_data,
            "{{ follower_usernames }}": ", ".join(self.usernames or []),
            "{{follower_usernames}}": ", ".join(self.usernames or []),
        }
        for placeholder, value in replacements.items():
            prompt = prompt.replace(placeholder, value)

        llm_service = self.llm_service or LLMPredictionService()
        llm_result = llm_service.generate_prediction(
            prompt=prompt,
            stock_code="DISCORD",
            observation_date=summary_date.isoformat(),
            model=model,
        )
        summary = (llm_result.get("prediction_text") or "").strip()
        if not summary:
            raise ValueError("LLM returned an empty Discord market-intelligence summary")

        generated_at = datetime.now(SYDNEY_TIMEZONE).isoformat()
        metadata = {
            "summary_date": summary_date.isoformat(),
            "window_start": window_start.isoformat(),
            "window_end": window_end.isoformat(),
            "generated_at": generated_at,
            "message_count": len(rows),
            "model": model,
            "cache_key": self.cache_key,
        }
        self.cache_service.save_prediction(self.cache_key, summary_date, summary)
        self._write_metadata(summary_date, metadata)

        return {
            "summary_markdown": summary,
            "observation_date": summary_date.isoformat(),
            **metadata,
            "cached": False,
        }

    def get_latest_or_generate(
        self,
        force_regenerate: bool = False,
        model: str = DEFAULT_DISCORD_SUMMARY_MODEL,
        now: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        summary_date = self.current_summary_date(now)
        return self.generate_summary(summary_date, force_regenerate, model)


class DiscordFollowerMarketIntelligenceService(DiscordMarketIntelligenceService):
    """Automated rolling summary restricted to the configured follower list."""

    def __init__(
        self,
        gex_service: Optional[GEXDataService] = None,
        llm_service: Optional[LLMPredictionService] = None,
        cache_dir: str = "llm_output/discord_message_summary_followers_automated",
        template_path: str = "signal_pattern/discord_followers_automated_summary_template.md",
        manual_cache_dir: str = "llm_output/discord_message_summary_followers",
    ):
        self.manual_cache_dir = manual_cache_dir
        super().__init__(
            gex_service=gex_service,
            llm_service=llm_service,
            cache_dir=cache_dir,
            template_path=template_path,
            cache_key="DISCORD_FOLLOWERS_AUTO",
            usernames=FOLLOWER_USERNAMES,
        )

    @staticmethod
    def _dashboard_digest(summary: Dict[str, Any]) -> Dict[str, Any]:
        summary = {
            **summary,
            "source": "Selected Discord followers, rolling 24-hour intelligence",
        }
        return DiscordMarketIntelligenceService._dashboard_digest(summary)

    @staticmethod
    def _format_message_timestamp(value: Any) -> Optional[str]:
        if value is None:
            return None
        if isinstance(value, datetime):
            return value.strftime("%Y-%m-%d %H:%M:%S")
        text = str(value).strip()
        return text or None

    def _fill_missing_follower_times(
        self,
        digest: Dict[str, Any],
        summary_date: date,
    ) -> Dict[str, Any]:
        views = digest.get("contributor_views") or []
        missing = {
            str(view.get("source") or "").casefold()
            for view in views
            if view.get("source") and not view.get("shared_at")
        }
        if not missing:
            return digest

        window_start, window_end = self.summary_window(summary_date)
        try:
            rows = self.gex_service.get_discord_messages_between_by_users(
                window_start,
                window_end,
                self.usernames or FOLLOWER_USERNAMES,
            )
        except Exception as exc:
            logger.warning(
                "Could not backfill follower opinion times for %s: %s",
                summary_date,
                exc,
            )
            return digest

        latest_by_user: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            username = str(row.get("UserName") or "").casefold()
            if username in missing and username not in latest_by_user:
                latest_by_user[username] = row

        for view in views:
            username = str(view.get("source") or "").casefold()
            row = latest_by_user.get(username)
            if not row or view.get("shared_at"):
                continue
            view["shared_at"] = self._format_message_timestamp(row.get("TimeStamp_Sydney"))
            view["shared_at_et"] = self._format_message_timestamp(row.get("TimeStamp_USEst"))
        return digest

    def _manual_cache_is_newer(self, summary_date: date) -> bool:
        automated_path = self._metadata_path(summary_date).with_suffix(".md")
        manual_path = (
            Path(self.manual_cache_dir)
            / f"DISCORD_FOLLOWERS_{summary_date:%Y%m%d}.md"
        )
        if not manual_path.exists():
            return False
        if not automated_path.exists():
            return True
        return manual_path.stat().st_mtime > automated_path.stat().st_mtime

    def get_dashboard_digest(self, as_of: date) -> Dict[str, Any]:
        automated = super().get_dashboard_digest(as_of)
        if automated["available"] and not self._manual_cache_is_newer(as_of):
            return self._fill_missing_follower_times(automated, as_of)

        same_day_manual = DiscordMarketIntelligenceService(
            cache_dir=self.manual_cache_dir,
            cache_key="DISCORD_FOLLOWERS",
            usernames=FOLLOWER_USERNAMES,
        ).get_dashboard_digest(as_of)
        if same_day_manual["available"]:
            same_day_manual["source"] = (
                "Selected Discord followers, same-day follower intelligence"
            )
            return self._fill_missing_follower_times(same_day_manual, as_of)
        if automated["available"]:
            return self._fill_missing_follower_times(automated, as_of)
        return automated
