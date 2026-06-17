from fastapi.testclient import TestClient

from app.main import app
from app.routers import market_theme_reports


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_market_theme_report_upload_list_and_read(tmp_path, monkeypatch):
    monkeypatch.setattr(market_theme_reports, "REPORT_DIR", tmp_path)
    monkeypatch.setattr(market_theme_reports, "INDEX_PATH", tmp_path / "index.json")
    client = TestClient(app)

    create = client.post(
        "/api/market-theme-reports",
        headers=_auth(),
        json={
            "title": "Market Themes - Test",
            "filename": "market-themes-2026-06-17_0730.md",
            "content": "# Market Themes\n\n- AI leadership",
            "created_at": "2026-06-17T07:30:00+10:00",
        },
    )

    assert create.status_code == 200
    created = create.json()
    assert created["filename"] == "market-themes-2026-06-17_0730.md"
    assert created["title"] == "Market Themes - Test"

    listing = client.get("/api/market-theme-reports", headers=_auth())

    assert listing.status_code == 200
    items = listing.json()["items"]
    assert len(items) == 1
    assert items[0]["filename"] == "market-themes-2026-06-17_0730.md"

    detail = client.get(
        "/api/market-theme-reports/market-themes-2026-06-17_0730.md",
        headers=_auth(),
    )

    assert detail.status_code == 200
    assert detail.json()["content"] == "# Market Themes\n\n- AI leadership"


def test_market_theme_report_rejects_path_traversal(tmp_path, monkeypatch):
    monkeypatch.setattr(market_theme_reports, "REPORT_DIR", tmp_path)
    monkeypatch.setattr(market_theme_reports, "INDEX_PATH", tmp_path / "index.json")
    client = TestClient(app)

    response = client.post(
        "/api/market-theme-reports",
        headers=_auth(),
        json={
            "filename": "../escape.md",
            "content": "# bad",
        },
    )

    assert response.status_code == 400
