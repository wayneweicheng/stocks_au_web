"""Build context pack for LLM main context."""

from typing import Dict, Any
from datetime import date


def build_context_pack(
    stock_code: str,
    stock_code_base: str,
    observation_date: date,
    effective_trade_date: date,
    broker_effective_date: date,
    announcement_count: int,
    price_days: int,
    broker_setup_days: int,
    broker_micro_days: int,
    broker_historical_rows: int = 0,
) -> Dict[str, Any]:
    """
    Build context pack for main LLM context.
    Target: ~1,500 tokens
    This is a lightweight summary that points to the compact artifacts.
    """
    return {
        "metadata": {
            "stock_code": stock_code,
            "stock_code_base": stock_code_base,
            "observation_date": observation_date.isoformat(),
            "effective_trade_date": effective_trade_date.isoformat(),
            "broker_effective_date": broker_effective_date.isoformat()
        },
        "data_coverage": {
            "announcements": announcement_count,
            "price_days": price_days,
            "broker_setup_days": broker_setup_days,
            "broker_micro_days": broker_micro_days,
            "broker_historical_rows": broker_historical_rows,
        },
        "analysis_instructions": {
            "approach": "Use compact artifacts to generate comprehensive stock analysis",
            "scoring_weights": {
                "fundamental": 0.20,
                "newsflow_catalyst": 0.30,
                "technical": 0.20,
                "broker": 0.30
            },
            "overall_setup_state_bands": {
                "80-100": "Strongly Bullish",
                "70-79.99": "Bullish",
                "65-69.99": "Mildly Bullish",
                "45-64.99": "Neutral",
                "35-44.99": "Mildly Bearish",
                "0-34.99": "Bearish"
            }
        },
        "artifact_manifest": [
            "announcement_compact.json",
            "price_ta_compact.json",
            "broker_compact.json",
            "liquidity_compact.json"
        ]
    }
