from __future__ import annotations

import argparse
import json
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .report import render_html_report
from .service import SPXGEXStrategyService


def _service() -> SPXGEXStrategyService:
    return SPXGEXStrategyService()


def parse_as_of(value: str, timezone_name: str | None = None) -> datetime:
    """Parse an as-of instant, requiring a timezone when no UTC offset is supplied."""
    raw = value.strip()
    formats = ("%Y-%m-%d %I:%M%p", "%Y-%m-%d %I:%M %p")
    normalized = raw[:-1] + "+00:00" if raw.upper().endswith("Z") else raw
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        parsed = None
        for date_format in formats:
            try:
                parsed = datetime.strptime(raw, date_format)
                break
            except ValueError:
                continue
        if parsed is None:
            raise ValueError(
                "invalid --as-of value; use an ISO timestamp such as "
                "'2026-08-05 17:30' or '2026-08-05T17:30:00+10:00'"
            )

    if parsed.tzinfo is not None:
        return parsed
    if not timezone_name:
        raise ValueError("--timezone is required when --as-of does not include a UTC offset")
    try:
        timezone = ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError as exc:
        raise ValueError(f"unknown timezone: {timezone_name}") from exc
    return parsed.replace(tzinfo=timezone)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SPXW GEX signal assistant")
    subparsers = parser.add_subparsers(dest="command", required=True)
    daily = subparsers.add_parser("daily", help="run the daily signal job as of now or a supplied timestamp")
    daily.add_argument(
        "--as-of",
        help="historical as-of timestamp; defaults to the current time",
    )
    daily.add_argument(
        "--timezone",
        help="IANA timezone for an as-of timestamp without an offset, e.g. Australia/Sydney",
    )
    notification = daily.add_mutually_exclusive_group()
    notification.add_argument(
        "--force-notification",
        action="store_true",
        help="send a notification for this manual run even if its signal was already notified",
    )
    notification.add_argument(
        "--no-notification",
        action="store_true",
        help="generate and save the report without sending any Pushover notification",
    )
    subparsers.add_parser("monitor", help="run the persisted-position monitor now")
    subparsers.add_parser("live-nq", help="print current IB NQMAIN versus yesterday close")
    subparsers.add_parser("report", help="print the configured HTML report URL")
    backtest = subparsers.add_parser("backtest", help="run the supplied-file causal backtest")
    backtest.add_argument("--start", required=True)
    backtest.add_argument("--end", required=True)
    backtest.add_argument("--initial-capital", type=float, default=100000.0)
    backtest.add_argument("--exposure", type=float, default=1.0)
    backtest.add_argument("--data-mode", choices=("sql", "file"), default=None)

    trade = subparsers.add_parser("trade", help="record manual execution status")
    trade_sub = trade.add_subparsers(dest="trade_command", required=True)
    confirm = trade_sub.add_parser("confirm")
    confirm.add_argument("trade_id")
    confirm.add_argument("--entry", type=float, default=None)
    confirm.add_argument("--quantity", type=float, default=None)
    trade_sub.add_parser("skip").add_argument("trade_id")
    close = trade_sub.add_parser("close")
    close.add_argument("trade_id")
    close.add_argument("--price", type=float, required=True)

    args = parser.parse_args(argv)
    service = _service()
    if args.command == "daily":
        as_of = None
        if args.as_of:
            try:
                as_of = parse_as_of(args.as_of, args.timezone)
            except ValueError as exc:
                parser.error(str(exc))
        print(
            json.dumps(
                service.run_daily_signal(
                    now=as_of,
                    force_notification=args.force_notification,
                    send_notification=not args.no_notification,
                ),
                indent=2,
                default=str,
            )
        )
        return 0
    if args.command == "monitor":
        print(json.dumps(service.run_position_monitor(), indent=2, default=str))
        return 0
    if args.command == "live-nq":
        from .ib_market_data import get_live_nq_snapshot

        print(json.dumps(get_live_nq_snapshot(), indent=2, default=str))
        return 0
    if args.command == "report":
        print(service._report_url())
        return 0
    if args.command == "backtest":
        from datetime import date
        from .backtest import run_backtest, run_sql_backtest

        data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
        if data_mode == "sql":
            result = run_sql_backtest(
                service.settings.spx_gex_source_database,
                date.fromisoformat(args.start),
                date.fromisoformat(args.end),
                args.initial_capital,
                args.exposure,
            )
        else:
            result = run_backtest(
                service._resolve_path(service.settings.spx_gex_gex_path),
                service._resolve_path(service.settings.spx_gex_nq_path),
                date.fromisoformat(args.start),
                date.fromisoformat(args.end),
                args.initial_capital,
                args.exposure,
            )
        print(json.dumps(result, indent=2, default=str))
        return 0
    if args.command == "trade":
        trade = service.store.trade(args.trade_id)
        if trade is None:
            parser.error(f"unknown trade id: {args.trade_id}")
        if args.trade_command == "confirm":
            service.store.update_trade(
                args.trade_id,
                actual_status="EXECUTED",
                actual_entry=args.entry or trade["entry_price"],
                actual_quantity=args.quantity or trade["quantity"],
            )
        elif args.trade_command == "skip":
            service.store.update_trade(args.trade_id, actual_status="SKIPPED_BY_USER")
        elif args.trade_command == "close":
            entry = float(trade["actual_entry"] or trade["entry_price"])
            quantity = float(trade["actual_quantity"] or trade["quantity"] or 0)
            direction = 1.0 if trade["direction"] == "LONG" else -1.0
            actual_pnl = quantity * (args.price - entry) * direction
            service.store.update_trade(
                args.trade_id,
                actual_status="CLOSED_MANUALLY",
                actual_exit=args.price,
                actual_pnl=actual_pnl,
            )
        print(json.dumps(dict(service.store.trade(args.trade_id)), indent=2, default=str))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
