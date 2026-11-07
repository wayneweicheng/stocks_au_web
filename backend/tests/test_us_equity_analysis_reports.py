import unittest
from unittest.mock import patch

from app.routers import us_equity_analysis_reports as reports


class UsEquityAnalysisReportTests(unittest.TestCase):
    def test_detail_fetch_does_not_reload_entire_report_catalog(self):
        job = {
            "job_id": "job-1", "job_type": "us-equity-analysis", "status": "succeeded",
            "created_at": "2026-11-03T10:00:00+00:00", "stock_code": "MU",
        }
        report = {"job_id": "job-1", "label": "MU", "content": "# MU report"}
        with (
            patch.object(reports, "get_job", return_value=job),
            patch.object(reports, "get_job_report", return_value=report),
            patch.object(reports, "list_us_equity_analysis_reports", side_effect=AssertionError("must not scan the report catalog")),
        ):
            detail = reports.get_us_equity_analysis_report("job-1", username="admin")

        self.assertEqual(detail.job_id, "job-1")
        self.assertEqual(detail.stock_code, "MU")
        self.assertEqual(detail.created_at, job["created_at"])
        self.assertEqual(detail.content, "# MU report")


if __name__ == "__main__":
    unittest.main()
