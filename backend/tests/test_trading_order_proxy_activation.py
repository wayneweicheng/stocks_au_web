from datetime import datetime
import json
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.routers import trading_orders as router


def _intent(**overrides):
    payload = {
        "strategy_id": 1,
        "stock_code": "NVDA",
        "side": "B",
        "order_source_type": "MANUAL",
        "time_frame": "5M",
        "entry_type": "LIMIT",
        "entry_price": None,
        "quantity": 1,
        "notional_amount": None,
        "profit_target_price": None,
        "stop_loss_price": None,
        "status": "PENDING",
        "activation": {
            "instrument_code": "ESMAIN.US",
            "lower_price": 670.0,
            "upper_price": 670.0,
            "target_price_offset_pct": -0.15,
        },
        "entry_risk": {
            "profit_target": {"unit": "PERCENT", "value": 1.0},
            "stop_loss": {"unit": "PERCENT", "value": 0.5},
        },
    }
    payload.update(overrides)
    return router.TradingOrderCreate(**payload)


def test_conditional_order_accepts_limit_price_resolved_from_target_bar_at_activation():
    normalized = router._normalize_order_inputs(_intent(entry_type="LIMIT"))

    assert normalized["entry_type"] == "LIMIT"
    assert normalized["entry_price"] is None


def test_conditional_order_requires_fixed_esmain_proxy():
    order = _intent(activation={"instrument_code": "QQQ.US", "lower_price": 1, "upper_price": 1})

    with pytest.raises(HTTPException) as exc_info:
        router._normalize_order_inputs(order)
    assert "ESMAIN.US" in exc_info.value.detail


def test_conditional_order_accepts_fixed_share_quantity_without_notional_or_exit_rules():
    normalized = router._normalize_order_inputs(_intent(quantity=3, entry_risk=None))
    meta = json.loads(normalized["meta_json"])

    assert normalized["quantity"] == 3
    assert meta["conditional_entry"]["quantity_mode"] == "FIXED"
    assert "notional_amount" not in meta["conditional_entry"]
    assert "profit_target" not in meta["conditional_entry"]
    assert "stop_loss" not in meta["conditional_entry"]


def test_conditional_order_accepts_only_one_optional_exit_rule():
    normalized = router._normalize_order_inputs(_intent(entry_risk={
        "profit_target": None,
        "stop_loss": {"unit": "PERCENT", "value": 0.5},
    }))
    meta = json.loads(normalized["meta_json"])

    assert "profit_target" not in meta["conditional_entry"]
    assert meta["conditional_entry"]["stop_loss"] == {"unit": "PERCENT", "value": 0.5}


def test_conditional_order_defaults_to_same_session_8pm_expiry(monkeypatch):
    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            current = cls(2026, 10, 16, 10, 0)
            return current.replace(tzinfo=tz) if tz is not None else current

    monkeypatch.setattr(router, "datetime", FrozenDateTime)

    normalized = router._normalize_order_inputs(_intent())

    assert normalized["activation"]["expires_at"] == datetime(2026, 10, 16, 20, 0)


def test_conditional_order_rejects_expiry_beyond_current_session(monkeypatch):
    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            current = cls(2026, 10, 16, 10, 0)
            return current.replace(tzinfo=tz) if tz is not None else current

    monkeypatch.setattr(router, "datetime", FrozenDateTime)
    order = _intent(activation={
        "instrument_code": "ESMAIN.US",
        "lower_price": 670.0,
        "upper_price": 670.0,
        "target_price_offset_pct": -0.15,
        "expires_at": "2026-10-19T20:00:00",
    })

    with pytest.raises(HTTPException, match="current eligible session day only"):
        router._normalize_order_inputs(order)


def test_activation_list_returns_persisted_per_order_tier():
    class FakeModel:
        def execute_read_query(self, sql, params):
            assert 'TriggerPrice' in sql
            assert params == (42,)
            return [{'OrderId': 42, 'ProxyStockCode': 'ESMAIN.US',
                     'LowerPrice': 7400.5, 'UpperPrice': 7404.25,
                     'TriggerPrice': 7402.25, 'State': 'ARMED'}]

    activation = router._load_order_proxy_activations(FakeModel(), [42])[42]
    assert activation['trigger_price'] == 7402.25
    assert activation['state'] == 'ARMED'


def test_conditional_order_persists_target_risk_plan_and_spy_activation():
    normalized = router._normalize_order_inputs(_intent())

    assert normalized["stock_code"] == "NVDA.US"
    assert normalized["activation"]["proxy_stock_code"] == "ESMAIN.US"
    assert normalized["activation"]["lower_price"] == 670.0
    assert '"unit": "PERCENT"' in normalized["meta_json"]
    assert '"quantity_mode": "FIXED"' in normalized["meta_json"]
    assert '"target_price_offset_pct": -0.15' in normalized["meta_json"]


@pytest.mark.parametrize(('side', 'expected'), [
    ('B', [7404.25, 7402.25, 7400.50]),
    ('S', [7400.50, 7402.50, 7404.25]),
])
def test_esmain_batch_persists_fixed_tick_aligned_tiers(side, expected):
    class FakeModel:
        def __init__(self, database):
            assert database == 'StockDB_US'
        def execute_update_usp(self, sql, params):
            self.params = params
            FakeModel.last = self

    activation = {'instrument_code': 'ESMAIN.US', 'lower_price': 7400.5, 'upper_price': 7404.25}
    with patch.object(router, 'SQLServerModel', FakeModel):
        result = router.create_conditional_order_batch(router.TradingOrderBatchCreate(
            orders=[_intent(stock_code='QQQ', side=side, activation={**activation, 'trigger_price': tier})
                    for tier in expected]
        ))
    assert result['count'] == 3
    assert [FakeModel.last.params[i * 19 + 17] for i in range(3)] == expected


def test_range_without_distinct_es_ticks_rejects_batch():
    with pytest.raises(HTTPException, match='distinct 0.25-point tiers'):
        router.create_conditional_order_batch(router.TradingOrderBatchCreate(orders=[
            _intent(activation={'lower_price': 7400.5, 'upper_price': 7400.75})
            for _ in range(3)
        ]))


def test_single_short_intent_persists_lower_edge_as_es_trigger():
    class FakeModel:
        def __init__(self, database):
            assert database == 'StockDB_US'
        def execute_update_usp(self, sql, params):
            assert 'TriggerPrice' in sql
            FakeModel.last_params = params

    with patch.object(router, 'SQLServerModel', FakeModel):
        router.create_trading_order(_intent(side='S', activation={
            'instrument_code': 'ESMAIN.US', 'lower_price': 7400.5,
            'upper_price': 7404.25, 'trigger_price': 7400.5,
        }))
    assert FakeModel.last_params[-2] == 7400.5


def test_single_intent_cannot_override_side_specific_es_tier():
    with pytest.raises(HTTPException, match='Single ESMain trigger'):
        router.create_trading_order(_intent(activation={
            'instrument_code': 'ESMAIN.US', 'lower_price': 7400.5,
            'upper_price': 7404.25, 'trigger_price': 7400.5,
        }))


def test_batch_rejects_wrong_tier_or_mixed_target_before_any_write():
    a = {'instrument_code': 'ESMAIN.US', 'lower_price': 7400.5, 'upper_price': 7404.25}
    with pytest.raises(HTTPException, match='tiers differ'):
        router.create_conditional_order_batch(router.TradingOrderBatchCreate(orders=[
            _intent(activation={**a, 'trigger_price': 7404.25}),
            _intent(activation={**a, 'trigger_price': 7403.0}),
        ]))
    with pytest.raises(HTTPException, match='one target'):
        router.create_conditional_order_batch(router.TradingOrderBatchCreate(orders=[
            _intent(activation=a), _intent(stock_code='AMD', activation=a),
        ]))


def test_conditional_batch_is_one_atomic_database_write():
    class FakeModel:
        calls = []

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_update_usp(self, sql, params):
            self.calls.append((sql, params))

    with patch.object(router, "SQLServerModel", FakeModel):
        result = router.create_conditional_order_batch(
            router.TradingOrderBatchCreate(orders=[
                _intent(activation={'lower_price': 670.0, 'upper_price': 670.5}),
                _intent(activation={'lower_price': 670.0, 'upper_price': 670.5}),
            ])
        )

    assert result["count"] == 2
    assert len(FakeModel.calls) == 1
    sql, params = FakeModel.calls[0]
    assert "BEGIN TRANSACTION" in sql and "ROLLBACK TRANSACTION" in sql
    assert sql.count("INSERT INTO Trading.OrderActivation") == 2
    assert params.count("ESMAIN.US") == 0  # fixed proxy is a SQL literal, not caller-controlled data
    assert len(params) == 38
    assert params[17] == 670.5 and params[36] == 670.0
    first_batch_id = json.loads(params[14])["conditional_entry"]["batch_id"]
    second_batch_id = json.loads(params[33])["conditional_entry"]["batch_id"]
    assert first_batch_id == second_batch_id
