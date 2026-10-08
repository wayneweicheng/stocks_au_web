import unittest
from datetime import date
from unittest.mock import patch

from fastapi import HTTPException

from app.routers import breakout_watchlist


class BreakoutWatchlistTests(unittest.TestCase):
    def test_refresh_uses_supported_update_stored_procedure_method(self):
        class FakeModel:
            def __init__(self):
                self.update_calls = []

            def execute_update_usp(self, query, values):
                self.update_calls.append((query, values))

            def execute_read_query(self, query, values):
                return [{"Symbol": "ABC"}]

        model = FakeModel()
        with patch.object(breakout_watchlist, "get_sql_model", return_value=model):
            results = breakout_watchlist.get_breakout_watchlist(
                observation_date=date(2026, 10, 2),
                refresh=True,
                username="test-user",
            )

        self.assertEqual(results, [{"Symbol": "ABC"}])
        self.assertEqual(len(model.update_calls), 1)
        self.assertIn("usp_CalculateBreakoutWatchlist", model.update_calls[0][0])
        self.assertEqual(model.update_calls[0][1], (date(2026, 10, 2),))

    def test_refresh_failure_is_returned_to_the_caller(self):
        class FailingModel:
            def execute_update_usp(self, query, values):
                raise RuntimeError("duplicate key")

            def execute_read_query(self, query, values):
                raise AssertionError("The read query must not run after refresh failure")

        with patch.object(breakout_watchlist, "get_sql_model", return_value=FailingModel()):
            with self.assertRaises(HTTPException) as raised:
                breakout_watchlist.get_breakout_watchlist(
                    observation_date=date(2026, 10, 5),
                    refresh=True,
                    username="test-user",
                )

        self.assertEqual(raised.exception.status_code, 503)
        self.assertIn("duplicate key", str(raised.exception.detail))


if __name__ == "__main__":
    unittest.main()
