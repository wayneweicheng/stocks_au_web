"""D1 option snapshot uses the specified daily SQL observation, never retrieval timestamps."""
from datetime import date, datetime

from app.services import stock_map_option_snapshot


def test_qqq_d1_option_pair_uses_only_exact_observation_date_and_last_fallback(monkeypatch):
    seen = []

    class FakeModel:
        def execute_read_query(self, sql, values):
            seen.append((sql, values))
            return [
                {"ASXCode": "QQQ.US", "ObservationDate": date(2026, 10, 28), "ExpiryDate": date(2026, 10, 29), "Strike": 724,
                 "PorC": "C", "Bid": 0, "Ask": 0, "LastTradePrice": 3.96},
                {"ASXCode": "QQQ.US", "ObservationDate": datetime(2026, 10, 28, 0), "ExpiryDate": date(2026, 10, 29), "Strike": 724,
                 "PorC": "P", "Bid": 0, "Ask": 0, "LastTradePrice": 4.22},
                {"ASXCode": "QQQ.US", "ObservationDate": date(2026, 10, 27), "ExpiryDate": date(2026, 10, 29), "Strike": 724,
                 "PorC": "C", "Bid": 5, "Ask": 6, "LastTradePrice": 5.5},
            ]

        def close(self):
            pass

    monkeypatch.setattr(stock_map_option_snapshot, "get_timed_sql_model", lambda **kwargs: FakeModel())
    result = stock_map_option_snapshot.load_d1_option_rows("QQQ", date(2026, 10, 28), date(2026, 10, 29), 723.88)
    assert len(seen) == 1
    sql, params = seen[0]
    assert "StockDB_US.StockData.v_OptionDelayedQuote_V2" in sql
    assert "ObservationDate = CONVERT(date, ?)" in sql
    assert "CreateDate" not in sql and "LastTradeTime" not in sql
    assert "2026-10-28" in params and "2026-10-27" not in params
    assert result["observation_date"] == "2026-10-28"
    assert [(row["right"], row["price"], row["price_source"]) for row in result["option_rows"]] == [
        ("C", 3.96, "last"), ("P", 4.22, "last")]
    assert all(row["expiry"] == "2026-10-29" and row["strike"] == 724 for row in result["option_rows"])
    assert result["spot_reference_from_d1"] == 723.88


def test_premarket_d1_on_observation_date_never_falls_back_to_d2_options(monkeypatch):
    seen = []

    class FakeModel:
        def execute_read_query(self, sql, values):
            seen.append(values)
            return [
                {"ASXCode": "SOXL.US", "ObservationDate": date(2026, 10, 29), "ExpiryDate": date(2026, 10, 30),
                 "Strike": 82, "PorC": "P", "Bid": 3, "Ask": 4},
                {"ASXCode": "SOXL.US", "ObservationDate": date(2026, 10, 30), "ExpiryDate": date(2026, 10, 30),
                 "Strike": 82, "PorC": "C", "Bid": 1, "Ask": 2},
            ]

        def close(self):
            pass

    monkeypatch.setattr(stock_map_option_snapshot, "get_timed_sql_model", lambda **kwargs: FakeModel())
    result = stock_map_option_snapshot.load_d1_option_rows("SOXL", date(2026, 10, 30), date(2026, 10, 30), 82.07)
    assert seen[0][2:4] == ("2026-10-30", "2026-10-30")
    assert result["observation_date"] == "2026-10-30"
    assert result["option_rows"] == []  # A D2 put cannot complete the D1 call.


def test_bid_ask_mid_preferred_over_last_for_a_complete_d1_pair(monkeypatch):
    class FakeModel:
        def execute_read_query(self, sql, values):
            return [
                {"ObservationDate": date(2026, 10, 28), "ExpiryDate": date(2026, 10, 29),
                 "Strike": 100, "PorC": "C", "Bid": 2, "Ask": 4, "LastTradePrice": 9},
                {"ObservationDate": date(2026, 10, 28), "ExpiryDate": date(2026, 10, 29),
                 "Strike": 100, "PorC": "P", "Bid": 0, "Ask": 0, "LastTradePrice": 1.25},
            ]

        def close(self):
            pass

    monkeypatch.setattr(stock_map_option_snapshot, "get_timed_sql_model", lambda **kwargs: FakeModel())
    result = stock_map_option_snapshot.load_d1_option_rows("FORM", date(2026, 10, 28), date(2026, 10, 29), 101)
    assert [(row["right"], row["price"], row["price_source"]) for row in result["option_rows"]] == [
        ("C", 3.0, "bid_ask_mid"), ("P", 1.25, "last")]


def test_spxw_nearest_strike_is_preferred_over_earlier_farther_expiry(monkeypatch):
    seen = []
    model_options = []

    class FakeModel:
        def execute_read_query(self, sql, values):
            seen.append((sql, values))
            return [
                {"ASXCode": "SPXW.US", "ObservationDate": date(2026, 10, 30), "ExpiryDate": date(2026, 10, 30),
                 "Strike": 7750, "PorC": "C", "Bid": 20, "Ask": 22},
                {"ASXCode": "SPXW.US", "ObservationDate": date(2026, 10, 30), "ExpiryDate": date(2026, 10, 30),
                 "Strike": 7750, "PorC": "P", "Bid": 25, "Ask": 27},
                {"ASXCode": "SPXW.US", "ObservationDate": date(2026, 10, 30), "ExpiryDate": date(2026, 11, 2),
                 "Strike": 7720, "PorC": "C", "Bid": 19, "Ask": 21},
                {"ASXCode": "SPXW.US", "ObservationDate": date(2026, 10, 30), "ExpiryDate": date(2026, 11, 2),
                 "Strike": 7720, "PorC": "P", "Bid": 18, "Ask": 20},
            ]

        def close(self):
            pass

    monkeypatch.setattr(stock_map_option_snapshot, "get_timed_sql_model", lambda **kwargs: (model_options.append(kwargs) or FakeModel()))
    result = stock_map_option_snapshot.load_d1_option_rows("SPXW", date(2026, 10, 30), date(2026, 10, 30), 7721.02)
    assert model_options == [{"database": "StockDB_US", "connection_timeout": 5, "query_timeout": 60}]
    assert "WITH (NOLOCK)" in seen[0][0]
    assert "SPXW.US" in seen[0][1]
    assert "ORDER BY ABS(Strike" in seen[0][0]
    assert [(row["strike"], row["expiry"]) for row in result["option_rows"]] == [(7720, "2026-11-02")] * 2


def test_missing_put_price_never_invents_a_pair(monkeypatch):
    class FakeModel:
        def execute_read_query(self, sql, values):
            return [
                {"ObservationDate": date(2026, 10, 28), "ExpiryDate": date(2026, 10, 29),
                 "Strike": 100, "PorC": "C", "Bid": 2, "Ask": 4, "LastTradePrice": 9},
                {"ObservationDate": date(2026, 10, 28), "ExpiryDate": date(2026, 10, 29),
                 "Strike": 100, "PorC": "P", "Bid": 0, "Ask": 0, "LastTradePrice": 0},
            ]

        def close(self):
            pass

    monkeypatch.setattr(stock_map_option_snapshot, "get_timed_sql_model", lambda **kwargs: FakeModel())
    result = stock_map_option_snapshot.load_d1_option_rows("FORM", date(2026, 10, 28), date(2026, 10, 29), 101)
    assert result["option_rows"] == []
    assert result["status"] == "no_valid_pair"
