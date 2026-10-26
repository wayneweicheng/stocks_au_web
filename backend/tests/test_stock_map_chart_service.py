from datetime import date, datetime
from unittest.mock import Mock

from app.services import stock_map_chart_service as service


def test_historical_map_bars_use_report_date_and_aliases(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda: model)
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
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda: model)
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
    assert "TimeFrame IN (?, ?)" in calls[0][0]
    assert "TimeIntervalStart <= ?" in calls[0][0]
    assert calls[0][1][-4:] == ("5M", "5min", datetime(2026, 4, 28, 15), datetime(2026, 5, 1, 15))


def test_sixty_day_chart_window_does_not_change_the_as_at_cutoff(monkeypatch):
    model = Mock()
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda: model)
    monkeypatch.setattr(service, "_close_saved_price_levels_model", lambda _model: None)
    calls = []

    def query(_model, sql, params):
        calls.append((sql, params))
        return []

    monkeypatch.setattr(service, "_execute_saved_price_levels_query", query)
    service.get_stock_map_chart_bars("QQQ", date(2026, 5, 1), timeframe="5M", lookback_days=60)
    assert calls[0][1][-2:] == (datetime(2026, 3, 3), datetime(2026, 5, 2))


def test_chart_bars_reject_unsupported_timeframe_before_opening_connection(monkeypatch):
    monkeypatch.setattr(service, "_open_saved_price_levels_model", lambda: (_ for _ in ()).throw(AssertionError("opened DB")))
    try:
        service.get_stock_map_chart_bars("QQQ", timeframe="1M")
        raise AssertionError("Expected ValueError")
    except ValueError:
        pass
