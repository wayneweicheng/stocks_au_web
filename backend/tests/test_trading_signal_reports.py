from __future__ import annotations

import unittest
from datetime import date, datetime

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
        "revision_no": 0,
        "generated_utc": generated or datetime(2026, 8, 14, 8, 0),
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

    def test_cursor_is_bound_to_normalized_filters(self):
        model = _Model([_row("00000000-0000-0000-0000-000000000001"), _row("00000000-0000-0000-0000-000000000002")])
        repo = TradingSignalReportRepository(lambda: model)
        _, cursor = repo.list(ReportFilters(strategy_code="SPX_GEX", limit=1))
        self.assertIsNotNone(cursor)
        with self.assertRaises(ReportCursorError):
            repo.list(ReportFilters(strategy_code="META_GEX", limit=1, cursor=cursor))

    def test_public_report_id_filter_supports_deep_links(self):
        public_id = "00000000-0000-0000-0000-000000000001"
        model = _Model([_row(public_id)])
        rows, _ = TradingSignalReportRepository(lambda: model).list(ReportFilters(public_report_id=public_id, limit=1))
        self.assertEqual(rows[0]["public_report_id"], public_id)
        self.assertIn("CONVERT(nvarchar(36), r.PublicReportID) = ?", model.calls[0][0])
        self.assertIn(public_id, model.calls[0][1])


if __name__ == "__main__":
    unittest.main()
