import unittest
from fastapi import HTTPException
from unittest.mock import patch

from app.core import db
from app.routers import support_resistance
from app.services import price_levels_30m_service


class SupportResistanceReliabilityTests(unittest.TestCase):
    def test_timed_sql_model_sets_query_timeout_and_closes_connection(self):
        class FakeCursor:
            description = [("Value",)]

            def execute(self, _query, _values):
                return None

            def fetchall(self):
                return [(7,)]

            def close(self):
                self.closed = True

        class FakeConnection:
            def __init__(self):
                self.cursor_instance = FakeCursor()
                self.closed = False

            def cursor(self):
                return self.cursor_instance

            def close(self):
                self.closed = True

        connection = FakeConnection()
        calls = {}

        def fake_get_db_connection(database=None, connection_timeout=None):
            calls["database"] = database
            calls["connection_timeout"] = connection_timeout
            return connection

        with patch.object(db, "get_db_connection", side_effect=fake_get_db_connection):
            model = db.get_timed_sql_model(
                database="StockDB_US",
                connection_timeout=4,
                query_timeout=9,
            )

            self.assertEqual(calls, {"database": "StockDB_US", "connection_timeout": 4})
            self.assertEqual(model.cnxn.timeout, 9)
            self.assertEqual(model.execute_read_query("SELECT 7", ()), [{"Value": 7}])

            model.close()

        self.assertTrue(connection.cursor_instance.closed)
        self.assertTrue(connection.closed)


    def test_support_resistance_query_failure_is_bounded_and_connection_is_closed(self):
        class FakeModel:
            def __init__(self):
                self.closed = False

            def execute_read_query(self, _query, _values):
                raise TimeoutError("query timed out")

            def close(self):
                self.closed = True

        model = FakeModel()
        with patch.object(
            price_levels_30m_service,
            "_open_support_resistance_model",
            return_value=model,
        ):
            with self.assertRaises(price_levels_30m_service.SupportResistanceDatabaseError):
                price_levels_30m_service.get_30m_support_resistance(
                    observation_datetime=None,
                    stock_codes=["SKHY"],
                    enable_live_prices=False,
                )

        self.assertTrue(model.closed)


    def test_support_resistance_returns_json_503_when_database_is_unavailable(self):
        def fail(**_kwargs):
            raise price_levels_30m_service.SupportResistanceDatabaseError("database timeout")

        with patch.object(support_resistance, "get_30m_support_resistance_for_stock", side_effect=fail):
            with self.assertRaises(HTTPException) as caught:
                support_resistance.support_resistance(
                    stock_code="SKHY",
                    observation_date=None,
                    observation_datetime=None,
                    lookback_days=10,
                    minimum_distance_atr=0.1,
                    maximum_distance_atr=3.0,
                    max_levels=5,
                    enable_live_prices=False,
                )

        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(caught.exception.detail, "database timeout")


    def test_support_resistance_rejects_overlapping_requests(self):
        acquired = support_resistance._support_resistance_slots.acquire(blocking=False)
        self.assertTrue(acquired)
        try:
            with self.assertRaises(HTTPException) as caught:
                support_resistance.support_resistance(
                    stock_code="SKHY",
                    observation_date=None,
                    observation_datetime=None,
                    lookback_days=10,
                    minimum_distance_atr=0.1,
                    maximum_distance_atr=3.0,
                    max_levels=5,
                    enable_live_prices=False,
                )
            self.assertEqual(caught.exception.status_code, 503)
        finally:
            support_resistance._support_resistance_slots.release()


if __name__ == "__main__":
    unittest.main()
