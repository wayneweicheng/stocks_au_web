from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth, support_resistance


AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_five_minute_chart_endpoint_is_authenticated_and_forwards_cutoff(monkeypatch):
    monkeypatch.setattr(auth, "get_credentials", lambda: {"username": "admin", "password": "password123"})
    calls = []

    def fake_bars(stock_code, observation_date=None, **kwargs):
        calls.append((stock_code, observation_date, kwargs))
        return {"stock_code": stock_code, "bars": [{"time": "2026-05-01T14:55:00", "close": 100.5}]}

    monkeypatch.setattr(support_resistance, "get_stock_map_chart_bars", fake_bars)
    client = TestClient(app)
    url = "/api/support-resistance/chart-bars?stock_code=QQQ&timeframe=5M&observation_datetime=2026-05-01T15:00:00&lookback_days=3&end_inclusive=true"
    assert client.get(url).status_code == 401
    response = client.get(url, headers=AUTH)
    assert response.status_code == 200
    assert response.json()["bars"][0]["close"] == 100.5
    assert calls == [("QQQ", None, {"timeframe": "5M", "observation_datetime": datetime(2026, 5, 1, 15), "lookback_days": 3, "end_inclusive": True})]
    assert client.get("/api/support-resistance/chart-bars?stock_code=QQQ&timeframe=1M", headers=AUTH).status_code == 422
