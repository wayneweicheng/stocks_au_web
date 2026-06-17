"""Download CNN Fear & Greed history and its aligned S&P 500 series."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import pandas as pd
import requests


ROOT = Path(__file__).resolve().parent
API_URL = (
    "https://production.dataviz.cnn.io/index/fearandgreed/graphdata/{start_date}"
)
PAGE_URL = "https://edition.cnn.com/markets/fear-and-greed"
RAW_OUTPUT = ROOT / "cnn_fear_greed_raw.json"
CSV_OUTPUT = ROOT / "fear_greed_spx_history.csv"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/137.0.0.0 Safari/537.36"
    ),
    "Referer": PAGE_URL,
    "Origin": "https://edition.cnn.com",
    "Accept": "application/json, text/plain, */*",
}


def fetch_history(start_date: str, attempts: int = 6) -> dict:
    """Fetch CNN's chart JSON with retries for intermittent bot responses."""
    url = API_URL.format(start_date=start_date)
    last_error = None
    for attempt in range(attempts):
        try:
            response = requests.get(url, headers=HEADERS, timeout=60)
            if response.status_code == 200 and response.text.lstrip().startswith("{"):
                return response.json()
            last_error = RuntimeError(
                f"CNN returned HTTP {response.status_code}: {response.text[:100]}"
            )
        except (requests.RequestException, ValueError) as error:
            last_error = error
        time.sleep(2 + attempt)
    raise RuntimeError(f"Unable to download CNN history: {last_error}")


def series_frame(payload: dict, key: str, value_name: str) -> pd.DataFrame:
    frame = pd.DataFrame(payload[key]["data"])
    frame["Date"] = (
        pd.to_datetime(frame["x"], unit="ms", utc=True)
        .dt.tz_convert(None)
        .dt.normalize()
    )
    frame = frame.rename(columns={"y": value_name, "rating": f"{value_name}_Rating"})
    return frame[["Date", value_name, f"{value_name}_Rating"]]


def build_history(payload: dict) -> pd.DataFrame:
    sentiment = series_frame(
        payload, "fear_and_greed_historical", "Fear_Greed_Score"
    )
    spx = series_frame(payload, "market_momentum_sp500", "SPX_Close")
    history = sentiment.merge(spx[["Date", "SPX_Close"]], on="Date", how="inner")
    history = (
        history.sort_values("Date")
        .drop_duplicates("Date", keep="last")
        .reset_index(drop=True)
    )
    return history


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-date", default="2020-09-14")
    parser.add_argument(
        "--from-cache",
        action="store_true",
        help="Rebuild the CSV from the existing raw JSON without downloading.",
    )
    args = parser.parse_args()

    if args.from_cache:
        payload = json.loads(RAW_OUTPUT.read_text(encoding="utf-8"))
    else:
        payload = fetch_history(args.start_date)
        RAW_OUTPUT.write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8"
        )

    history = build_history(payload)
    history.to_csv(CSV_OUTPUT, index=False)
    print(
        f"Wrote {len(history):,} rows from "
        f"{history['Date'].min().date()} through {history['Date'].max().date()} "
        f"to {CSV_OUTPUT}"
    )


if __name__ == "__main__":
    main()
