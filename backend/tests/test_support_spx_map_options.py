"""SPX chart's observation-date option context never queries another underlying or date."""
from datetime import date

from fastapi.testclient import TestClient

from app.main import app
from app.routers import support_resistance

AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_spx_option_context_queries_only_spxw_on_selected_observation_date(monkeypatch):
    calls = []

    def snapshot(code, d1, observation_date, reference):
        calls.append((code, d1, observation_date, reference))
        return {"source": "StockDB_US.StockData.v_OptionDelayedQuote_V2", "observation_date": d1.isoformat(),
                "spot_reference_from_d1": reference, "status": "available_historical_d1", "option_rows": [
                    {"symbol": "SPXW", "observation_date": d1.isoformat(), "expiry": "2026-10-30", "strike": 7720,
                     "right": "C", "price": 22.5, "price_source": "bid_ask_mid"},
                    {"symbol": "SPXW", "observation_date": d1.isoformat(), "expiry": "2026-10-30", "strike": 7720,
                     "right": "P", "price": 24, "price_source": "last"},
                ]}

    monkeypatch.setattr(support_resistance, "load_d1_option_rows", snapshot, raising=False)
    response = TestClient(app).get("/api/support-resistance/spx-map-options", params={
        "observation_date": "2026-10-30", "reference_price": 7721.02}, headers=AUTH)
    assert response.status_code == 200
    assert calls == [("SPXW", date(2026, 10, 30), date(2026, 10, 30), 7721.02)]
    assert response.json()["option_rows"][0]["right"] == "C"
    assert response.json()["option_rows"][1]["price_source"] == "last"


def test_spx_option_context_rejects_invalid_reference_before_sql(monkeypatch):
    monkeypatch.setattr(support_resistance, "load_d1_option_rows", lambda *args: (_ for _ in ()).throw(AssertionError("queried SQL")), raising=False)
    response = TestClient(app).get("/api/support-resistance/spx-map-options", params={
        "observation_date": "2026-10-30", "reference_price": 0}, headers=AUTH)
    assert response.status_code == 422
