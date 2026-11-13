import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth, skill_report_pages

AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


class SkillReportDeletionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.deleted_path = Path(self.temp.name) / "deleted.json"
        self.client = TestClient(app)
        self.auth_patch = patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"})
        self.auth_patch.start()
        self.addCleanup(self.auth_patch.stop)
        self.deleted_patch = patch.object(skill_report_pages, "DELETED_REPORTS_PATH", self.deleted_path)
        self.deleted_patch.start()
        self.addCleanup(self.deleted_patch.stop)
        self.cache_patch = patch.object(skill_report_pages, "_REPORT_SUMMARY_CACHE", {})
        self.cache_patch.start()
        self.addCleanup(self.cache_patch.stop)
        self.addCleanup(self.temp.cleanup)

    def test_delete_spx_and_stock_map_reports_hides_markdown_or_html_report(self):
        def list_reports(job_type):
            return [{"job_id": f"{job_type}-1", "title": f"{job_type} report", "filename": "report.html"}]

        with patch.object(skill_report_pages, "list_reports", side_effect=list_reports):
            for route, job_type in (("spx-map-reports", "spx-map"), ("stock-map-reports", "stock-map")):
                report_id = f"{job_type}-1"
                listing = self.client.get(f"/api/{route}", headers=AUTH)
                self.assertEqual(listing.status_code, 200)
                self.assertEqual([item["job_id"] for item in listing.json()["items"]], [report_id])
                deleted = self.client.delete(f"/api/{route}/{report_id}", headers=AUTH)
                self.assertEqual(deleted.status_code, 200)
                self.assertTrue(deleted.json()["deleted"])
                self.assertEqual(self.client.get(f"/api/{route}", headers=AUTH).json()["items"], [])
                self.assertEqual(self.client.get(f"/api/{route}/{report_id}", headers=AUTH).status_code, 404)

    def test_delete_stock_map_analysis_viewer_report(self):
        with patch.object(skill_report_pages, "list_reports", return_value=[{"job_id": "comparison-123", "title": "NVDA comparison"}]):
            listing = self.client.get("/api/stock-map-comparison-reports", headers=AUTH)
            self.assertEqual(listing.json()["items"][0]["job_id"], "comparison-123")
            deleted = self.client.delete("/api/stock-map-comparison-reports/comparison-123", headers=AUTH)
            self.assertEqual(deleted.status_code, 200)
            self.assertEqual(self.client.get("/api/stock-map-comparison-reports", headers=AUTH).json()["items"], [])
            self.assertEqual(self.client.get("/api/stock-map-comparison-reports/comparison-123", headers=AUTH).status_code, 404)

    def test_spx_comparison_reports_filter_by_d1_date_and_paginate(self):
        reports = [
            {"job_id": "old", "label": "SPX:2025-12-01:2025-11-28", "created_at": "2025-12-01T22:00:00Z"},
            {"job_id": "newer", "label": "SPX:2026-06-01:2026-05-29", "created_at": "2026-06-01T22:00:00Z"},
            {"job_id": "newest", "label": "SPX:2026-06-02:2026-06-01", "created_at": "2026-06-02T22:00:00Z"},
        ]
        with patch.object(skill_report_pages, "call_skill_runner", return_value=reports):
            response = self.client.get(
                "/api/spx-map-comparison/reports?date_from=2026-05-01&date_to=2026-06-30&limit=1",
                headers=AUTH,
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual([item["job_id"] for item in response.json()["items"]], ["newest"])
            self.assertEqual(response.json()["total"], 2)
            self.assertTrue(response.json()["has_more"])
            next_page = self.client.get(
                "/api/spx-map-comparison/reports?date_from=2026-05-01&date_to=2026-06-30&limit=1&offset=1",
                headers=AUTH,
            )
            self.assertEqual([item["job_id"] for item in next_page.json()["items"]], ["newer"])
            self.assertFalse(next_page.json()["has_more"])

    def test_delete_spx_analysis_viewer_report_filters_runner_listing_and_detail(self):
        runner = patch.object(skill_report_pages, "call_skill_runner", return_value={
            "reports": [{"job_id": "spx-comparison-1", "title": "SPX comparison"},
                        {"job_id": "spx-comparison-2", "title": "SPX comparison"}]
        })
        with runner:
            listing = self.client.get("/api/spx-map-comparison/reports", headers=AUTH)
            self.assertEqual(listing.status_code, 200)
            self.assertEqual([item["job_id"] for item in listing.json()["items"]], ["spx-comparison-1", "spx-comparison-2"])
            deleted = self.client.delete("/api/spx-map-comparison/reports/spx-comparison-1", headers=AUTH)
            self.assertEqual(deleted.status_code, 200)
            listing = self.client.get("/api/spx-map-comparison/reports", headers=AUTH)
            self.assertEqual([item["job_id"] for item in listing.json()["items"]], ["spx-comparison-2"])
            detail = self.client.get("/api/spx-map-comparison/jobs/spx-comparison-1/report", headers=AUTH)
            self.assertEqual(detail.status_code, 404)

    def test_delete_requires_authentication(self):
        self.assertEqual(self.client.delete("/api/spx-map-reports/example").status_code, 401)


if __name__ == "__main__":
    unittest.main()
