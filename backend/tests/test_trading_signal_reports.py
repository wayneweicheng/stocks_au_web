from __future__ import annotations

import json
import unittest
from datetime import date, datetime
from unittest.mock import patch

from app.repositories.trading_signal_reports import ReportCursorError, ReportFilters, TradingSignalReportRepository


class _Model:
    def __init__(self, rows):
        self.rows = rows
        self.calls = []

    def execute_read_query(self, sql, values):
        self.calls.append((sql, values))
        return self.rows

    def close(self):
        pass


def _row(public_id="00000000-0000-0000-0000-000000000001", generated=None):
    return {
        "public_report_id": public_id,
        "report_kind": "DAILY_SIGNAL",
        "report_date": date(2026, 8, 14),
        "observation_date": date(2026, 8, 14),
        "strategy_code": "SPX_GEX",
        "strategy_version_code": "v1.0.3-production",
        "deployment_key": "SPX_GEX_PAPER",
        "environment": "FORWARD_PAPER",
        "subject_instrument_code": "SPXW.US",
        "execution_instrument_code": "QQQ.US",
        "title": "Signal",
        "summary": "Summary",
        "file_name": "report.html",
        "signal_classification": "LONG_SIGNAL",
        "revision_no": 0,
        "generated_utc": generated or datetime(2026, 8, 14, 8, 0),
        "run_scheduled_utc": datetime(2026, 8, 14, 7, 30),
        "supersedes_public_report_id": None,
        "is_current": True,
    }


class TradingSignalReportRepositoryTests(unittest.TestCase):
    def test_catalog_is_bounded_and_does_not_select_html(self):
        model = _Model([_row()])
        rows, cursor = TradingSignalReportRepository(lambda: model).list(ReportFilters(strategy_code="SPX_GEX", limit=10))
        self.assertEqual(rows[0]["html_url"], "/api/trading-signal-reports/00000000-0000-0000-0000-000000000001.html")
        self.assertIsNone(cursor)
        self.assertNotIn("HtmlContent", model.calls[0][0])
        self.assertIn("TOP (?)", model.calls[0][0])
        self.assertIn("StrategyRun", model.calls[0][0])
        self.assertIn("ORDER BY COALESCE(sr.ScheduledEffectiveUtc", model.calls[0][0])

    def test_cursor_is_bound_to_normalized_filters(self):
        model = _Model([_row("00000000-0000-0000-0000-000000000001"), _row("00000000-0000-0000-0000-000000000002")])
        repo = TradingSignalReportRepository(lambda: model)
        _, cursor = repo.list(ReportFilters(strategy_code="SPX_GEX", limit=1))
        self.assertIsNotNone(cursor)
        with self.assertRaises(ReportCursorError):
            repo.list(ReportFilters(strategy_code="META_GEX", limit=1, cursor=cursor))

    def test_current_filter_uses_latest_correction_not_original_report(self):
        model = _Model([_row()])
        TradingSignalReportRepository(lambda: model).list(ReportFilters(current_only=True, limit=10))
        self.assertIn("newer.SupersedesReportID = r.ReportSnapshotID", model.calls[0][0])

    def test_public_report_id_filter_supports_deep_links(self):
        public_id = "00000000-0000-0000-0000-000000000001"
        model = _Model([_row(public_id)])
        rows, _ = TradingSignalReportRepository(lambda: model).list(ReportFilters(public_report_id=public_id, limit=1))
        self.assertEqual(rows[0]["public_report_id"], public_id)
        self.assertIn("CONVERT(nvarchar(36), r.PublicReportID) = ?", model.calls[0][0])
        self.assertIn(public_id, model.calls[0][1])

    def test_exclude_no_signal_uses_persisted_signal_classification(self):
        model = _Model([_row()])
        rows, _ = TradingSignalReportRepository(lambda: model).list(
            ReportFilters(strategy_code="SPX_GEX", limit=10, exclude_no_signal=True)
        )
        self.assertEqual(rows[0]["signal_classification"], "LONG_SIGNAL")
        self.assertIn("sig.Classification AS signal_classification", model.calls[0][0])
        self.assertIn("ISNULL(sig.Classification, '') <> 'NO_SIGNAL'", model.calls[0][0])

    def test_price_performance_uses_latest_close_when_cash_market_is_closed(self):
        model = _Model([{
            "latest_close": 110,
            "latest_close_date": date(2026, 8, 21),
            "tradable_date_open_price": 100,
        }])
        repo = TradingSignalReportRepository(lambda: model)
        with patch("app.repositories.trading_signal_reports.get_live_stock_prices") as live_prices:
            result = repo.price_performance(
                "qqq.us",
                date(2026, 8, 19),
                now=datetime(2026, 8, 22, 12, 0),
            )

        self.assertEqual(result["instrument_code"], "QQQ.US")
        self.assertEqual(result["close_price"], 110.0)
        self.assertEqual(result["close_price_source"], "latest_close")
        self.assertEqual(result["change_pct"], 10.0)
        live_prices.assert_not_called()

    def test_price_performance_uses_end_date_close_after_signal_ends(self):
        model = _Model([{
            "latest_close": 140,
            "latest_close_date": date(2026, 9, 3),
            "tradable_date_open_price": 100,
            "end_date_close": 125,
        }])
        repo = TradingSignalReportRepository(lambda: model)
        with patch("app.repositories.trading_signal_reports.get_live_stock_prices") as live_prices:
            result = repo.price_performance(
                "QQQ.US",
                date(2026, 9, 1),
                end_at=datetime(2026, 9, 1, 16, 0),
                now=datetime(2026, 9, 2, 10, 0),
            )

        self.assertEqual(result["close_price"], 125.0)
        self.assertEqual(result["close_price_date"], date(2026, 9, 1))
        self.assertEqual(result["close_price_source"], "end_date_close")
        self.assertEqual(result["change_pct"], 25.0)
        live_prices.assert_not_called()

    def test_price_performance_uses_live_price_during_cash_session_and_nulls_zero_open(self):
        model = _Model([{
            "latest_close": 110,
            "latest_close_date": date(2026, 8, 19),
            "tradable_date_open_price": 0,
        }])
        repo = TradingSignalReportRepository(lambda: model)
        with patch(
            "app.repositories.trading_signal_reports.get_live_stock_prices",
            return_value={"QQQ.US": {"price": 105, "source": "ib_live"}},
        ):
            result = repo.price_performance(
                "QQQ.US",
                date(2026, 8, 19),
                now=datetime(2026, 8, 20, 10, 0),
            )

        self.assertEqual(result["close_price"], 105.0)
        self.assertIsNone(result["change_pct"])

    def test_overview_keeps_latest_signal_per_strategy_and_horizon_and_requires_history(self):
        configuration = json.dumps({
            "signal_definitions": [
                {"signal_code": "LONG_D2", "historical_performance": {"status": "AVAILABLE", "instances": 10, "resolved_instances": 10, "win_rate_pct": 70}},
                {"signal_code": "LONG_D5", "historical_performance": {"status": "AVAILABLE", "instances": 20, "resolved_instances": 20, "win_rate_pct": 75}},
                {"signal_code": "SHORT_D2", "historical_performance": {"status": "NOT_AVAILABLE"}},
            ]
        })

        def row(report_date, report_id, classification, holding_period, direction, action_code="PLAN_ENTRY"):
            return {
                "report_date": report_date,
                "public_report_id": report_id,
                "strategy_code": "TEST_STRATEGY",
                "strategy_version_code": "v1",
                "subject_instrument_code": "QQQ.US",
                "execution_instrument_code": "QQQ.US",
                "title": classification,
                "generated_utc": datetime.combine(report_date, datetime.min.time()),
                "direction": direction,
                "action_code": action_code,
                "holding_period": holding_period,
                "signal_classification": classification,
                "strategy_configuration_json": configuration,
            }

        model = _Model([
            row(date(2026, 8, 18), "new-d2", "LONG_D2", "D2", "LONG"),
            row(date(2026, 8, 17), "old-d2", "LONG_D2", "D2", "LONG"),
            row(date(2026, 8, 17), "long-d5", "LONG_D5", "D5", "LONG", "WATCH"),
            row(date(2026, 8, 18), "no-history", "SHORT_D2", "D2", "SHORT"),
        ])

        result = TradingSignalReportRepository(lambda: model).overview(date(2026, 8, 19), ReportFilters(limit=2000))

        self.assertEqual(len(result["items"]), 1)
        item = result["items"][0]
        self.assertEqual(item["instrument_code"], "QQQ.US")
        self.assertEqual(item["verdict"], "LONG")
        self.assertEqual([signal["public_report_id"] for signal in item["signals"]], ["new-d2", "long-d5"])
        self.assertEqual(item["signals"][1]["action_code"], "WATCH")
        self.assertEqual(item["signals"][0]["tradable_date"], date(2026, 8, 19))
        self.assertEqual(item["signals"][0]["end_date"], date(2026, 8, 20))
        self.assertEqual(item["signals"][0]["end_at"].hour, 16)
        self.assertIn("s.HoldingPeriodCode AS holding_period", model.calls[0][0])
        self.assertIn("s.ActionCode IN ('PLAN_ENTRY', 'WATCH') OR UPPER(s.Classification) IN ('DATA_ERROR', 'NO_SIGNAL')", model.calls[0][0])
        self.assertEqual(result["data_errors"], [])

    def test_overview_surfaces_data_errors_separately(self):
        configuration = json.dumps({
            "signal_definitions": [{
                "signal_code": "MU_DOWN_DAY_INTENT_REVERSAL_HIGH",
                "trigger_condition": "QQQ.GEX_Trending_Up == 1 OR MU.GEX_ZScore < -1.0",
                "historical_performance": {"status": "AVAILABLE", "instances": 10, "resolved_instances": 10, "win_rate_pct": 70},
            }]
        })
        row = {
            "report_date": date(2026, 8, 27),
            "observation_date": date(2026, 8, 27),
            "public_report_id": "data-error-1",
            "strategy_code": "GEX_MU_CAPITALTYPE",
            "strategy_version_code": "1.1.0-production",
            "deployment_key": "gex-mu-production-1-1-0-production",
            "environment": "LIVE_MANUAL",
            "subject_instrument_code": "MU.US",
            "execution_instrument_code": "MU.US",
            "title": "MU DATA_ERROR",
            "generated_utc": datetime(2026, 8, 28, 9, 0),
            "direction": "NONE",
            "action_code": "NONE",
            "holding_period": "CUSTOM",
            "signal_classification": "DATA_ERROR",
            "signal_metrics_json": json.dumps({
                "metrics": {"PriceChangePct": -0.3},
                "trigger_evaluations": {"MU_DOWN_DAY_INTENT_REVERSAL_HIGH": None},
            }),
            "strategy_configuration_json": configuration,
        }

        result = TradingSignalReportRepository(lambda: _Model([row])).overview(date(2026, 8, 28), ReportFilters(limit=2000))

        self.assertEqual(result["items"], [])
        self.assertEqual(result["data_errors"][0]["signal_classification"], "DATA_ERROR")
        self.assertIn("MU.GEX_ZScore", result["data_errors"][0]["reason"])
        self.assertIn("QQQ.GEX_Trending_Up", result["data_errors"][0]["reason"])

    def test_overview_expires_d1_after_its_tradable_session(self):
        configuration = json.dumps({
            "signal_definitions": [{
                "signal_code": "SHORT_D1",
                "historical_performance": {"status": "AVAILABLE", "instances": 10, "resolved_instances": 10, "win_rate_pct": 70},
            }]
        })
        row = {
            "report_date": date(2026, 8, 17),
            "public_report_id": "tsla-d1",
            "strategy_code": "TSLA_STRATEGY",
            "strategy_version_code": "v1",
            "subject_instrument_code": "TSLA.US",
            "execution_instrument_code": "TSLA.US",
            "title": "TSLA short",
            "generated_utc": datetime(2026, 8, 17, 20, 0),
            "direction": "SHORT",
            "holding_period": "D1",
            "signal_classification": "SHORT_D1",
            "strategy_configuration_json": configuration,
        }

        active = TradingSignalReportRepository(lambda: _Model([row])).overview(date(2026, 8, 18), ReportFilters(limit=2000))
        expired = TradingSignalReportRepository(lambda: _Model([row])).overview(date(2026, 8, 22), ReportFilters(limit=2000))

        self.assertEqual(len(active["items"]), 1)
        self.assertEqual(active["items"][0]["signals"][0]["tradable_date"], date(2026, 8, 18))
        self.assertEqual(active["items"][0]["signals"][0]["end_date"], date(2026, 8, 18))
        self.assertEqual(expired["items"], [])
        _, two_day_end, two_day_end_at = TradingSignalReportRepository._trade_window(date(2026, 8, 17), "D2")
        self.assertEqual(two_day_end, date(2026, 8, 19))
        self.assertEqual(two_day_end_at.hour, 16)


if __name__ == "__main__":
    unittest.main()
