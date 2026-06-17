from __future__ import annotations

import json
import logging
import operator
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urlparse
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

from app.core.db import get_db_connection


logger = logging.getLogger("app.bet_odds_monitor")
SYDNEY_TZ = ZoneInfo("Australia/Sydney")
TAB_HOSTS = {"www.tab.com.au", "tab.com.au"}
TAB_API_HOSTS = ("https://webapi.tab.com.au", "https://api.beta.tab.com.au")
COMPARATORS = {
    ">=": operator.ge,
    ">": operator.gt,
    "<=": operator.le,
    "<": operator.lt,
    "=": operator.eq,
}


@dataclass(frozen=True)
class TabMatchPath:
    sport_name: str
    competition_name: str
    match_name: str
    tournament_name: str | None = None

    def api_path(self) -> str:
        base = (
            f"/v1/tab-info-service/sports/{quote(self.sport_name, safe='')}"
            f"/competitions/{quote(self.competition_name, safe='')}"
        )
        if self.tournament_name:
            base += f"/tournaments/{quote(self.tournament_name, safe='')}"
        return f"{base}/matches/{quote(self.match_name, safe='')}"


def parse_tab_match_url(source_url: str) -> TabMatchPath:
    parsed = urlparse(source_url.strip())
    if parsed.scheme != "https" or parsed.hostname not in TAB_HOSTS:
        raise ValueError("Only HTTPS TAB match URLs from tab.com.au are supported")

    parts = [unquote(part) for part in parsed.path.split("/") if part]
    try:
        sports_index = parts.index("sports")
        competitions_index = parts.index("competitions", sports_index + 1)
        matches_index = parts.index("matches", competitions_index + 1)
    except ValueError as exc:
        raise ValueError("URL must be a TAB sports match page") from exc

    if competitions_index + 1 >= len(parts) or matches_index + 1 >= len(parts):
        raise ValueError("TAB URL is missing competition or match details")

    tournament_name = None
    if "tournaments" in parts[competitions_index + 2 : matches_index]:
        tournament_index = parts.index("tournaments", competitions_index + 2)
        if tournament_index + 1 < matches_index:
            tournament_name = parts[tournament_index + 1]

    return TabMatchPath(
        sport_name=parts[sports_index + 2],
        competition_name=parts[competitions_index + 1],
        tournament_name=tournament_name,
        match_name=parts[matches_index + 1],
    )


def sydney_local_to_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        value = value.replace(tzinfo=SYDNEY_TZ)
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def automatic_expiry_from_start_time(start_time: str) -> datetime:
    normalized = start_time.strip().replace("Z", "+00:00")
    match_start = datetime.fromisoformat(normalized)
    if match_start.tzinfo is None:
        match_start = match_start.replace(tzinfo=timezone.utc)
    return match_start.astimezone(SYDNEY_TZ) - timedelta(minutes=30)


def _fetch_json(url: str, timeout_seconds: int = 10) -> dict[str, Any]:
    request = Request(
        url,
        headers={
            "Accept": "application/json, text/plain, */*",
            "Origin": "https://www.tab.com.au",
            "Referer": "https://www.tab.com.au/",
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/137.0.0.0 Safari/537.36"
            ),
        },
    )
    with urlopen(request, timeout=timeout_seconds) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_tab_match(source_url: str) -> dict[str, Any]:
    match_path = parse_tab_match_url(source_url)
    errors: list[str] = []
    for host in TAB_API_HOSTS:
        url = (
            f"{host}{match_path.api_path()}"
            "?jurisdiction=NSW&homeState=NSW"
        )
        try:
            return _fetch_json(url)
        except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
            errors.append(f"{host}: {exc}")
    raise RuntimeError("TAB odds request failed. " + " | ".join(errors))


def _first_value(data: dict[str, Any], names: tuple[str, ...]) -> Any:
    for name in names:
        value = data.get(name)
        if value is not None:
            return value
    return None


def _decimal_odds(proposition: dict[str, Any]) -> Decimal | None:
    value = _first_value(
        proposition,
        (
            "returnWin",
            "winOdds",
            "odds",
            "price",
            "decimalOdds",
            "fixedOdds",
        ),
    )
    if isinstance(value, dict):
        value = _first_value(value, ("returnWin", "win", "price", "odds"))
    if value in (None, "", "SUSP"):
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError):
        return None


def extract_market_options(match_data: dict[str, Any]) -> list[dict[str, Any]]:
    options: list[dict[str, Any]] = []
    markets = match_data.get("markets") or match_data.get("topMarkets") or []
    for market_index, market in enumerate(markets):
        market_name = str(
            _first_value(market, ("betOption", "name", "marketName"))
            or f"Market {market_index + 1}"
        )
        propositions = market.get("propositions") or market.get("selections") or []
        for proposition_index, proposition in enumerate(propositions):
            selection_name = str(
                _first_value(
                    proposition,
                    ("name", "propositionName", "selectionName", "competitorName"),
                )
                or f"Selection {proposition_index + 1}"
            )
            line = _first_value(proposition, ("line", "handicap", "points"))
            display_name = selection_name
            if line not in (None, "") and str(line) not in selection_name:
                try:
                    numeric_line = Decimal(str(line))
                    line_label = f"+{line}" if numeric_line > 0 else str(line)
                except InvalidOperation:
                    line_label = str(line)
                display_name = f"{selection_name} {line_label}"
            options.append(
                {
                    "market_name": market_name,
                    # Include the line in the persisted identity. TAB commonly
                    # reuses a base name such as "Japan" across many handicaps.
                    "selection_name": display_name,
                    "raw_selection_name": selection_name,
                    "display_name": display_name,
                    "proposition_id": str(
                        _first_value(
                            proposition,
                            ("id", "propositionId", "propositionNumber", "selectionId"),
                        )
                        or ""
                    ),
                    "odds": float(odds) if (odds := _decimal_odds(proposition)) else None,
                    "line": line,
                    "is_open": bool(
                        _first_value(proposition, ("isOpen", "allowWin"))
                        or str(proposition.get("bettingStatus", "")).lower() == "open"
                    ),
                }
            )
    return options


def discover_markets(source_url: str) -> dict[str, Any]:
    path = parse_tab_match_url(source_url)
    data = fetch_tab_match(source_url)
    start_time = data.get("startTime")
    expires_at_sydney = (
        automatic_expiry_from_start_time(start_time).isoformat()
        if start_time
        else None
    )
    return {
        "sport_name": path.sport_name,
        "competition_name": path.competition_name,
        "tournament_name": path.tournament_name,
        "match_name": str(data.get("name") or path.match_name),
        "start_time": start_time,
        "expires_at_sydney": expires_at_sydney,
        "markets": extract_market_options(data),
    }


def compare_odds(observed: Decimal, comparison_operator: str, target: Decimal) -> bool:
    comparator = COMPARATORS.get(comparison_operator)
    if comparator is None:
        raise ValueError(f"Unsupported comparison operator: {comparison_operator}")
    return comparator(observed, target)


class BetOddsMonitorService:
    def list_monitors(self) -> list[dict[str, Any]]:
        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT
                    m.MonitorID, m.Name, m.SourceURL, m.SportName,
                    m.CompetitionName, m.TournamentName, m.MatchName,
                    m.TargetUserID, u.DisplayName AS TargetUserName,
                    m.ScanIntervalMinutes, m.ExpiresAtUtc, m.AlertOnce,
                    m.IsActive, m.LastScanAtUtc, m.NextScanAtUtc,
                    m.LastSuccessAtUtc, m.LastError, m.CreatedDateUtc,
                    CASE
                        WHEN m.ExpiresAtUtc <= SYSUTCDATETIME() THEN 'expired'
                        WHEN m.IsActive = 0 THEN 'paused'
                        WHEN m.LastError IS NOT NULL THEN 'error'
                        ELSE 'active'
                    END AS Status
                FROM [Notification].[BetOddsMonitors] m
                INNER JOIN [Notification].[Users] u ON u.UserID = m.TargetUserID
                ORDER BY m.CreatedDateUtc DESC
                """
            )
            monitors = self._rows(cursor)
            for monitor in monitors:
                monitor["criteria"] = self._criteria(connection, monitor["monitor_id"])
            return monitors

    def get_monitor(self, monitor_id: int) -> dict[str, Any] | None:
        monitors = [
            monitor
            for monitor in self.list_monitors()
            if monitor["monitor_id"] == monitor_id
        ]
        return monitors[0] if monitors else None

    def create_monitor(self, payload: dict[str, Any]) -> dict[str, Any]:
        path = parse_tab_match_url(payload["source_url"])
        expires_at_utc = sydney_local_to_utc(payload["expires_at_sydney"])
        if expires_at_utc <= datetime.utcnow():
            raise ValueError("Expiry must be in the future")

        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                INSERT INTO [Notification].[BetOddsMonitors] (
                    Name, SourceURL, SportName, CompetitionName, TournamentName,
                    MatchName, TargetUserID, ScanIntervalMinutes, ExpiresAtUtc,
                    AlertOnce, IsActive, NextScanAtUtc
                )
                OUTPUT INSERTED.MonitorID
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, SYSUTCDATETIME())
                """,
                payload["name"],
                payload["source_url"],
                path.sport_name,
                path.competition_name,
                path.tournament_name,
                path.match_name,
                payload["target_user_id"],
                payload["scan_interval_minutes"],
                expires_at_utc,
                payload["alert_once"],
            )
            monitor_id = int(cursor.fetchone()[0])
            self._replace_criteria(connection, monitor_id, payload["criteria"])
            connection.commit()
        return self.get_monitor(monitor_id) or {"monitor_id": monitor_id}

    def update_monitor(self, monitor_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        path = parse_tab_match_url(payload["source_url"])
        expires_at_utc = sydney_local_to_utc(payload["expires_at_sydney"])
        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                UPDATE [Notification].[BetOddsMonitors]
                SET Name = ?, SourceURL = ?, SportName = ?, CompetitionName = ?,
                    TournamentName = ?, MatchName = ?, TargetUserID = ?,
                    ScanIntervalMinutes = ?, ExpiresAtUtc = ?, AlertOnce = ?,
                    IsActive = ?, NextScanAtUtc = SYSUTCDATETIME(),
                    LastError = NULL, UpdatedDateUtc = SYSUTCDATETIME()
                WHERE MonitorID = ?
                """,
                payload["name"],
                payload["source_url"],
                path.sport_name,
                path.competition_name,
                path.tournament_name,
                path.match_name,
                payload["target_user_id"],
                payload["scan_interval_minutes"],
                expires_at_utc,
                payload["alert_once"],
                payload["is_active"],
                monitor_id,
            )
            if cursor.rowcount == 0:
                raise LookupError("Monitor not found")
            self._replace_criteria(connection, monitor_id, payload["criteria"])
            connection.commit()
        return self.get_monitor(monitor_id) or {"monitor_id": monitor_id}

    def delete_monitor(self, monitor_id: int) -> None:
        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "DELETE FROM [Notification].[BetOddsMonitors] WHERE MonitorID = ?",
                monitor_id,
            )
            if cursor.rowcount == 0:
                raise LookupError("Monitor not found")
            connection.commit()

    def scan_due_monitors(self) -> dict[str, int]:
        now = datetime.utcnow()
        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT MonitorID
                FROM [Notification].[BetOddsMonitors]
                WHERE IsActive = 1
                  AND ExpiresAtUtc > ?
                  AND (NextScanAtUtc IS NULL OR NextScanAtUtc <= ?)
                ORDER BY COALESCE(NextScanAtUtc, CreatedDateUtc)
                """,
                now,
                now,
            )
            monitor_ids = [int(row[0]) for row in cursor.fetchall()]

        result = {"due": len(monitor_ids), "scanned": 0, "failed": 0}
        for monitor_id in monitor_ids:
            try:
                self.scan_monitor(monitor_id)
                result["scanned"] += 1
            except Exception:
                result["failed"] += 1
                logger.exception("Bet odds scan failed for monitor %s", monitor_id)
        return result

    def scan_monitor(self, monitor_id: int) -> dict[str, Any]:
        monitor = self.get_monitor(monitor_id)
        if not monitor:
            raise LookupError("Monitor not found")

        now = datetime.utcnow()
        if monitor["expires_at_utc"] <= now:
            return {"monitor_id": monitor_id, "status": "expired"}

        try:
            options = extract_market_options(fetch_tab_match(monitor["source_url"]))
            option_lookup = {
                (option["market_name"].casefold(), option["selection_name"].casefold()): option
                for option in options
            }
            proposition_lookup = {
                option["proposition_id"]: option
                for option in options
                if option["proposition_id"]
            }
            scans = []
            with get_db_connection() as connection:
                for criterion in monitor["criteria"]:
                    option = proposition_lookup.get(criterion["proposition_id"] or "")
                    if option is None:
                        option = option_lookup.get(
                            (
                                criterion["market_name"].casefold(),
                                criterion["selection_name"].casefold(),
                            )
                        )
                    if option is None or option["odds"] is None:
                        self._record_missing(connection, monitor_id, criterion, now)
                        scans.append(
                            {
                                "criterion_id": criterion["criterion_id"],
                                "status": "unavailable",
                            }
                        )
                        continue

                    observed = Decimal(str(option["odds"]))
                    target = Decimal(str(criterion["target_odds"]))
                    matched = compare_odds(
                        observed,
                        criterion["comparison_operator"],
                        target,
                    )
                    alert_queued = self._should_alert(monitor, criterion, matched)
                    if alert_queued:
                        self._queue_alert(connection, monitor, criterion, observed, now)
                    self._update_criterion(
                        connection,
                        monitor_id,
                        criterion,
                        observed,
                        matched,
                        alert_queued,
                        now,
                    )
                    scans.append(
                        {
                            "criterion_id": criterion["criterion_id"],
                            "status": "matched" if matched else "not_matched",
                            "observed_odds": float(observed),
                            "alert_queued": alert_queued,
                        }
                    )

                connection.cursor().execute(
                    """
                    UPDATE [Notification].[BetOddsMonitors]
                    SET LastScanAtUtc = ?, LastSuccessAtUtc = ?, LastError = NULL,
                        NextScanAtUtc = DATEADD(MINUTE, ScanIntervalMinutes, ?),
                        UpdatedDateUtc = ?
                    WHERE MonitorID = ?
                    """,
                    now,
                    now,
                    now,
                    now,
                    monitor_id,
                )
                connection.commit()
            return {"monitor_id": monitor_id, "status": "scanned", "criteria": scans}
        except Exception as exc:
            self._record_monitor_error(monitor_id, str(exc), now)
            raise

    @staticmethod
    def _rows(cursor) -> list[dict[str, Any]]:
        columns = [column[0] for column in cursor.description]
        return [
            {
                BetOddsMonitorService._snake_case(column): value
                for column, value in zip(columns, row)
            }
            for row in cursor.fetchall()
        ]

    @staticmethod
    def _snake_case(value: str) -> str:
        output = []
        for index, char in enumerate(value):
            if char.isupper() and index and not value[index - 1].isupper():
                output.append("_")
            output.append(char.lower())
        return "".join(output)

    def _criteria(self, connection, monitor_id: int) -> list[dict[str, Any]]:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT CriterionID, MonitorID, MarketName, SelectionName, PropositionID,
                   ComparisonOperator, TargetOdds, LatestOdds, PreviousOdds,
                   LastCheckedAtUtc, LastMatchedAtUtc, LastAlertAtUtc, AlertCount,
                   IsCurrentlyMatched
            FROM [Notification].[BetOddsCriteria]
            WHERE MonitorID = ?
            ORDER BY CriterionID
            """,
            monitor_id,
        )
        return self._rows(cursor)

    @staticmethod
    def _replace_criteria(connection, monitor_id: int, criteria: list[dict[str, Any]]) -> None:
        cursor = connection.cursor()
        cursor.execute(
            "DELETE FROM [Notification].[BetOddsCriteria] WHERE MonitorID = ?",
            monitor_id,
        )
        for criterion in criteria:
            cursor.execute(
                """
                INSERT INTO [Notification].[BetOddsCriteria] (
                    MonitorID, MarketName, SelectionName, PropositionID,
                    ComparisonOperator, TargetOdds
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                monitor_id,
                criterion["market_name"],
                criterion["selection_name"],
                criterion.get("proposition_id") or None,
                criterion["comparison_operator"],
                criterion["target_odds"],
            )

    @staticmethod
    def _should_alert(
        monitor: dict[str, Any],
        criterion: dict[str, Any],
        matched: bool,
    ) -> bool:
        if not matched:
            return False
        if monitor["alert_once"]:
            return int(criterion["alert_count"] or 0) == 0
        return not bool(criterion["is_currently_matched"])

    @staticmethod
    def _queue_alert(
        connection,
        monitor: dict[str, Any],
        criterion: dict[str, Any],
        observed: Decimal,
        now: datetime,
    ) -> None:
        title = f"Bet odds target: {monitor['match_name']}"
        body = (
            f"{criterion['selection_name']} ({criterion['market_name']}) is {observed:.2f}. "
            f"Target: {criterion['comparison_operator']} {Decimal(str(criterion['target_odds'])):.2f}. "
            f"Checked {now.replace(tzinfo=timezone.utc).astimezone(SYDNEY_TZ):%d %b %Y %I:%M %p} Sydney."
        )
        event_data = json.dumps(
            {
                "monitor_id": monitor["monitor_id"],
                "criterion_id": criterion["criterion_id"],
                "observed_odds": float(observed),
            }
        )
        message_metadata = json.dumps({"sound": "cashregister"})
        cursor = connection.cursor()
        cursor.execute(
            """
            INSERT INTO [Notification].[MessageQueue] (
                EventType, EventSourceID, EventSourceTable, EventData,
                MessageTitle, MessageBody, MessageURL, MessageMetadata, TargetUserID,
                NotificationChannel, Priority, ScheduledSendDate, Status,
                QueuedBy
            ) VALUES (
                'bet_odds_alert', ?, '[Notification].[BetOddsCriteria]', ?,
                ?, ?, ?, ?, ?, 'pushover', 1, GETDATE(), 'pending',
                'bet_odds_monitor'
            )
            """,
            str(criterion["criterion_id"]),
            event_data,
            title,
            body,
            monitor["source_url"],
            message_metadata,
            monitor["target_user_id"],
        )

    @staticmethod
    def _update_criterion(
        connection,
        monitor_id: int,
        criterion: dict[str, Any],
        observed: Decimal,
        matched: bool,
        alert_queued: bool,
        now: datetime,
    ) -> None:
        cursor = connection.cursor()
        cursor.execute(
            """
            UPDATE [Notification].[BetOddsCriteria]
            SET PreviousOdds = LatestOdds, LatestOdds = ?, LastCheckedAtUtc = ?,
                LastMatchedAtUtc = CASE WHEN ? = 1 THEN ? ELSE LastMatchedAtUtc END,
                LastAlertAtUtc = CASE WHEN ? = 1 THEN ? ELSE LastAlertAtUtc END,
                AlertCount = AlertCount + CASE WHEN ? = 1 THEN 1 ELSE 0 END,
                IsCurrentlyMatched = ?, UpdatedDateUtc = ?
            WHERE CriterionID = ?
            """,
            observed,
            now,
            matched,
            now,
            alert_queued,
            now,
            alert_queued,
            matched,
            now,
            criterion["criterion_id"],
        )
        cursor.execute(
            """
            INSERT INTO [Notification].[BetOddsScanHistory] (
                MonitorID, CriterionID, ScannedAtUtc, Status, ObservedOdds,
                WasMatched, AlertQueued
            ) VALUES (?, ?, ?, 'success', ?, ?, ?)
            """,
            monitor_id,
            criterion["criterion_id"],
            now,
            observed,
            matched,
            alert_queued,
        )

    @staticmethod
    def _record_missing(
        connection,
        monitor_id: int,
        criterion: dict[str, Any],
        now: datetime,
    ) -> None:
        cursor = connection.cursor()
        cursor.execute(
            """
            UPDATE [Notification].[BetOddsCriteria]
            SET PreviousOdds = LatestOdds, LatestOdds = NULL,
                LastCheckedAtUtc = ?, IsCurrentlyMatched = 0,
                UpdatedDateUtc = ?
            WHERE CriterionID = ?
            """,
            now,
            now,
            criterion["criterion_id"],
        )
        cursor.execute(
            """
            INSERT INTO [Notification].[BetOddsScanHistory] (
                MonitorID, CriterionID, ScannedAtUtc, Status, Message
            ) VALUES (?, ?, ?, 'unavailable', 'Selection was not returned by TAB')
            """,
            monitor_id,
            criterion["criterion_id"],
            now,
        )

    @staticmethod
    def _record_monitor_error(monitor_id: int, error: str, now: datetime) -> None:
        with get_db_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                UPDATE [Notification].[BetOddsMonitors]
                SET LastScanAtUtc = ?, LastError = ?,
                    NextScanAtUtc = DATEADD(MINUTE, ScanIntervalMinutes, ?),
                    UpdatedDateUtc = ?
                WHERE MonitorID = ?
                """,
                now,
                error[:2000],
                now,
                now,
                monitor_id,
            )
            cursor.execute(
                """
                INSERT INTO [Notification].[BetOddsScanHistory] (
                    MonitorID, ScannedAtUtc, Status, Message
                ) VALUES (?, ?, 'error', ?)
                """,
                monitor_id,
                now,
                error[:2000],
            )
            connection.commit()
