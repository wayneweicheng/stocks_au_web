from datetime import date, datetime
from unittest.mock import Mock

from app.services import stock_map_chart_service as service


def test_chart_uses_longer_bounded_timeout_and_sargable_code_timeframe_filters(monkeypatch):
    model = Mock()
    opened = []
    statements = []
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: opened.append(kwargs) or model)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _: None)
    monkeypatch.setattr(service, "_execute_saved_price_levels_query", lambda _model, sql, params: statements.append((sql, params)) or [])

    service.get_stock_map_chart_bars("QQQ", date(2026, 10, 30))

    assert opened == [{"query_timeout": 20}]
    assert len(statements) == 1
    sql, params = statements[0]
    assert "ASXCode IN (CONVERT(varchar(10), ?), CONVERT(varchar(10), ?))" in sql
    assert "TimeFrame IN (CONVERT(varchar(10), ?))" in sql
    assert "QQQ.US" in params and "30M" in params
    assert "TimeIntervalStart >= ? AND TimeIntervalStart < ?" in sql


def test_chart_service_supports_15m_context_bars(monkeypatch):
    calls = []
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: Mock())
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _: None)
    monkeypatch.setattr(service, "_execute_saved_price_levels_query", lambda _model, sql, params: calls.append((sql, params)) or [])

    result = service.get_stock_map_chart_bars("SPX", observation_datetime=datetime(2026, 10, 30, 12), timeframe="15M")

    assert result["bars"] == []
    assert len(calls) == 1
    assert calls[0][1][0] == "SPXW.US"
    assert "TimeFrame IN (CONVERT(varchar(10), ?))" in calls[0][0]
    assert calls[0][1][1] == "15M"


def test_spx_map_uses_spxw_candles_without_changing_stock_aliases(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: model)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _: None)
    calls = []

    def query(_model, sql, params):
        calls.append(params)
        return [{"TimeIntervalStart": datetime(2026, 10, 30, 8), "Open": 7720,
                 "High": 7725, "Low": 7710, "Close": 7721, "Volume": 100}]

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    result = service.get_stock_map_chart_bars("spx", date(2026, 10, 30))
    assert result["stock_code"] == "SPX"
    assert result["bars"][0]["close"] == 7721
    assert calls[0][0] == "SPXW.US"
    assert "SPX.US" not in calls[0] and "SPX" not in calls[0]
    assert calls[0][-1] == datetime(2026, 10, 31)


def test_spx_derived_instruments_read_only_their_underlying_candles(monkeypatch):
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: Mock())
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _: None)
    calls = []

    def query(_model, sql, params):
        calls.append(params)
        return []

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    for display_code, sql_code in (("ESMain", "ESMain.US"), ("SPY_D", "SPY.US"),
                                   ("QQQ_D", "QQQ.US"), ("SPXL_D", "SPXL.US"),
                                   ("TQQQ_D", "TQQQ.US"), ("SOXL_D", "SOXL.US"),
                                   ("SOXX_D", "SOXX.US")):
        result = service.get_stock_map_chart_bars(display_code, date(2026, 10, 30))
        assert result["bars"] == []
        assert calls[-1][0] == sql_code
        assert display_code not in calls[-1]  # _D is a chart label, never an SQL stock.


def test_historical_map_bars_use_report_date_and_aliases(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: model)
    close = Mock()
    monkeypatch.setattr(service, "_close_saved_price_levels_model", close)
    calls = []

    def query(_model, sql, params):
        calls.append((sql, params))
        return [{"TimeIntervalStart": datetime(2026, 5, 1, 15), "Open": 100,
                 "High": 101, "Low": 99, "Close": 100.5, "Volume": 50}]

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    result = service.get_stock_map_chart_bars("qqq", date(2026, 5, 1))
    assert result["bars"][0]["close"] == 100.5
    assert calls[0][1][-2:] == (datetime(2026, 4, 22), datetime(2026, 5, 2))
    assert "QQQ.US" in calls[0][1]
    close.assert_called_once_with(model)


def test_current_map_includes_latest_bar(monkeypatch):
    monkeypatch.setattr(service, "_open_saved_price_levels_model", Mock)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda model: None)
    latest = datetime(2026, 5, 1, 15)
    calls = []

    def query(_model, sql, params):
        calls.append(params)
        if len(calls) == 1:
            return [{"TimeIntervalStart": latest}]
        return [{"TimeIntervalStart": latest, "Open": 100, "High": 101,
                 "Low": 99, "Close": 100.5, "Volume": 50}]

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    assert len(service.get_stock_map_chart_bars("QQQ")["bars"]) == 1
    assert calls[1][-1] > latest


def test_five_minute_bars_use_actual_timeframe_and_as_at_cutoff(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: model)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _model: None)
    calls = []

    def query(_model, sql, params):
        calls.append((sql, params))
        return [
            {"TimeIntervalStart": datetime(2026, 5, 1, 14, 55), "Open": 100,
             "High": 101, "Low": 99, "Close": 100.5, "Volume": 50},
            {"TimeIntervalStart": datetime(2026, 5, 1, 14, 55), "Open": 100,
             "High": 101, "Low": 99, "Close": 100.5, "Volume": 50},
        ]

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    result = service.get_stock_map_chart_bars(
        "QQQ", timeframe="5M", observation_datetime=datetime(2026, 5, 1, 15),
        lookback_days=3, end_inclusive=True,
    )
    assert len(result["bars"]) == 1
    assert result["bars"][0]["time"] == "2026-05-01T14:55:00"
    assert "TimeFrame IN (CONVERT(varchar(10), ?), CONVERT(varchar(10), ?))" in calls[0][0]
    assert "TimeIntervalStart <= ?" in calls[0][0]
    assert calls[0][1][-4:] == ("5M", "5min", datetime(2026, 4, 28, 15), datetime(2026, 5, 1, 15))


def test_sixty_day_chart_window_does_not_change_the_as_at_cutoff(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: model)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _model: None)
    calls = []

    def query(_model, sql, params):
        calls.append((sql, params))
        return []

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    service.get_stock_map_chart_bars("QQQ", date(2026, 5, 1), timeframe="5M", lookback_days=60)
    assert calls[0][1][-2:] == (datetime(2026, 3, 3), datetime(2026, 5, 2))


def test_chart_bars_reject_unsupported_timeframe_before_opening_connection(monkeypatch):
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda **kwargs: (_ for _ in ()).throw(AssertionError("opened DB")))
    try:
        service.get_stock_map_chart_bars("QQQ", timeframe="1M")
        raise AssertionError("Expected ValueError")
    except ValueError:
        pass
