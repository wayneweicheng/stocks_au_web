from datetime import datetime
from unittest.mock import patch

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.routers import trading_orders as router


def _order(**overrides):
    payload = {
        "strategy_id": 77,
        "stock_code": "QQQ",
        "side": "B",
        "quantity": 2,
        "target_price": {"operator": "AT_OR_BELOW", "threshold": 500.0},
    }
    payload.update(overrides)
    return router.ConditionalEntryOrderCreate(**payload)


def test_target_only_order_normalizes_to_conditional_entry_with_no_legacy_activation():
    normalized = router._normalize_conditional_entry_order(_order())

    assert normalized["order_kind"] == "CONDITIONAL_ENTRY"
    assert normalized["stock_code"] == "QQQ.US"
    assert normalized["entry_type"] == "LIMIT"
    assert normalized["condition"]["target_price_threshold"] == 500.0
    assert normalized["condition"]["target_price_activation_mode"] == "TOUCH_THEN_RETRACE"
    assert normalized["condition"]["target_price_tick_size"] == 0.01
    assert normalized["condition"]["trigger_stock_code"] is None


def test_target_reversal_confirmation_persists_server_derived_stock_tick():
    normalized = router._normalize_conditional_entry_order(_order(
        target_price={
            "operator": "AT_OR_BELOW", "threshold": 656.0,
            "confirmation_mode": "TOUCH_THEN_RETRACE",
        },
    ))
    condition = normalized["condition"]
    assert condition["target_price_activation_mode"] == "TOUCH_THEN_RETRACE"
    assert condition["target_price_tick_size"] == 0.01


def test_reversal_confirmation_rejects_unsupported_price_increment_and_trigger_source_mode():
    with pytest.raises(HTTPException, match=r"at least \$1\.00"):
        router._normalize_conditional_entry_order(_order(target_price={
            "operator": "AT_OR_BELOW", "threshold": 0.5,
            "confirmation_mode": "TOUCH_THEN_RETRACE",
        }))
    with pytest.raises(HTTPException, match="only to target-stock"):
        router._normalize_conditional_entry_order(_order(
            target_price=None,
            trigger_price={
                "instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW",
                "threshold": 5000, "confirmation_mode": "TOUCH_THEN_RETRACE",
            },
        ))


def test_trigger_only_esmain_condition_is_valid_and_price_tiers_are_not_order_entry_prices():
    normalized = router._normalize_conditional_entry_order(_order(
        target_price=None,
        trigger_price={"instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 5000.0},
    ))

    assert normalized["condition"]["target_price_threshold"] is None
    assert normalized["condition"]["trigger_stock_code"] == "ESMAIN.US"
    assert normalized["condition"]["trigger_price_activation_mode"] == "TOUCH_THEN_RETRACE"
    assert normalized["condition"]["trigger_price_tick_size"] == 0.25
    assert normalized["entry_price"] is None


def test_constraint_only_entry_is_rejected():
    with pytest.raises(HTTPException, match="(?i)at least one price"):
        router._normalize_conditional_entry_order(_order(target_price=None))


def test_entry_rejects_combining_target_and_reference_price_conditions():
    with pytest.raises(HTTPException, match="either a target-stock price condition or a reference-stock trigger condition"):
        router._normalize_conditional_entry_order(_order(
            trigger_price={"instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 5000},
        ))


def test_unsupported_trigger_symbol_and_non_side_aware_operator_are_rejected():
    with pytest.raises(HTTPException, match="ESMAIN.US"):
        router._normalize_conditional_entry_order(_order(
            target_price=None,
            trigger_price={"instrument_code": "NQMAIN.US", "operator": "AT_OR_BELOW", "threshold": 18000},
        ))
    with pytest.raises(HTTPException, match="side-aware"):
        router._normalize_conditional_entry_order(_order(
            target_price={"operator": "AT_OR_ABOVE", "threshold": 500},
        ))


def test_optional_signed_position_and_margin_conditions_are_persistable():
    normalized = router._normalize_conditional_entry_order(_order(
        position_condition={"operator": "LESS_THAN", "shares": 120},
        account_id="DU123456",
        maximum_margin_capacity_used=0.60,
    ))

    assert normalized["condition"]["position_operator"] == "LESS_THAN"
    assert normalized["condition"]["position_shares"] == 120
    assert normalized["condition"]["account_id"] == "DU123456"
    assert normalized["condition"]["maximum_margin_capacity_used"] == 0.60


def test_account_condition_requires_account_and_valid_comparator():
    with pytest.raises(HTTPException, match="account_id"):
        router._normalize_conditional_entry_order(_order(
            position_condition={"operator": "LESS_THAN", "shares": 120},
        ))
    with pytest.raises(HTTPException, match="position operator"):
        router._normalize_conditional_entry_order(_order(
            position_condition={"operator": "CLOSE_ENOUGH", "shares": 120}, account_id="DU123456",
        ))


def test_new_batch_persists_target_only_orders_and_conditions_atomically(monkeypatch):
    class FakeModel:
        calls = []

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_update_usp(self, sql, params):
            self.calls.append((sql, params))

        def execute_read_query(self, _sql, _params):
            return []

    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "false")
    batch = router.ConditionalEntryBatchCreate(orders=[
        _order(target_price={"operator": "AT_OR_BELOW", "threshold": 500.0}, quantity=2),
        _order(target_price={"operator": "AT_OR_BELOW", "threshold": 490.0}, quantity=3),
    ])
    with patch.object(router, "SQLServerModel", FakeModel):
        result = router.create_conditional_entry_batch(batch, idempotency_key="bb9d49d2-6c16-44da-993c-e21eae6e6432")

    assert result["count"] == 2
    assert result["order_kind"] == "CONDITIONAL_ENTRY"
    assert result["replayed"] is False
    assert len(FakeModel.calls) == 1
    sql, params = FakeModel.calls[0]
    assert "BEGIN TRANSACTION" in sql and "ROLLBACK TRANSACTION" in sql
    assert "Trading.ConditionalEntryBatchRequest" in sql
    assert sql.count("INSERT INTO Trading.Orders") == 2
    assert sql.count("INSERT INTO Trading.ConditionalEntryCondition") == 2
    assert sql.count("'CONDITIONAL_ENTRY'") == 3
    assert len(params) == 4 + (4 + 17) * 2
    assert "TargetPriceActivationMode" in sql
    assert "'LIMIT'" in sql
    assert params[11] == "IMMEDIATE"
    assert params[3] == 77


def test_conditional_entry_batch_idempotency_replays_same_body_and_rejects_key_reuse(monkeypatch):
    class FakeModel:
        request = None
        writes = 0

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, _sql, params):
            if self.request and params[0] == self.request[0]:
                return [{"RequestHash": self.request[1], "OrderCount": self.request[2]}]
            return []

        def execute_update_usp(self, _sql, params):
            FakeModel.writes += 1
            FakeModel.request = (params[0], params[1], params[2])

    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false")
    key = "77902c72-934a-4ef0-81a2-95a4571ac560"
    batch = router.ConditionalEntryBatchCreate(orders=[_order()])
    with patch.object(router, "SQLServerModel", FakeModel):
        created = router.create_conditional_entry_batch(batch, idempotency_key=key)
        replayed = router.create_conditional_entry_batch(batch, idempotency_key=key)
        with pytest.raises(HTTPException, match="different batch"):
            router.create_conditional_entry_batch(
                router.ConditionalEntryBatchCreate(orders=[_order(quantity=4)]),
                idempotency_key=key,
            )

    assert created["replayed"] is False
    assert replayed["replayed"] is True
    assert FakeModel.writes == 1


def test_db_only_mode_needs_schema_and_evaluator_but_not_pubsub_or_executor(monkeypatch):
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY", "false")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "false")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DRY_RUN", "false")

    status = router.get_conditional_entry_status()

    assert status["enabled"] is True
    assert status["dry_run"] is False
    assert status["mode"] == "DB_ONLY"
    assert status["execution_enabled"] is False


def test_executor_readiness_requires_execution_fill_id_schema_gate(monkeypatch):
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "false")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTION_SCHEMA_READY", "false")

    assert router.get_conditional_entry_status()["enabled"] is False
    assert router.get_conditional_entry_status()["execution_enabled"] is False


def test_executor_runtime_status_exposes_non_broker_dry_run(monkeypatch):
    for name in (
        "PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY",
        "PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY",
        "PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY",
        "PEGASUS_CONDITIONAL_ENTRY_EXECUTION_SCHEMA_READY", "PEGASUS_CONDITIONAL_ENTRY_DRY_RUN",
    ):
        monkeypatch.setenv(name, "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "false")

    status = router.get_conditional_entry_status()

    assert status["enabled"] is True
    assert status["execution_enabled"] is True
    assert status["mode"] == "EXECUTION_ENABLED"
    assert status["dry_run"] is True


def test_batch_endpoint_is_closed_until_all_runtime_parts_are_ready(monkeypatch):
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_PUBLISHER_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_READY", "false")
    with pytest.raises(HTTPException, match="not enabled"):
        router.create_conditional_entry_batch(router.ConditionalEntryBatchCreate(orders=[_order()]))
    assert router.get_conditional_entry_status()["enabled"] is False


def test_conditional_entry_list_exposes_persisted_target_touch_without_an_attempt(monkeypatch):
    class FakeModel:
        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, query, _params):
            assert "Trading.ConditionalEntryCursor" in query
            assert "target_cursor.ConditionVersion = c.ConditionVersion" in query
            assert "target_cursor.SourceCode = o.StockCode" in query
            assert "target_cursor.Region AS TargetCursorRegion" in query
            assert "target_cursor.TouchPrice AS TargetTouchPrice" in query
            return [{"OrderId": 2032, "Status": "PENDING", "AttemptState": None,
                     "TargetCursorRegion": "WAITING_FOR_REVERSAL", "TargetTouchPrice": 683.45}]

    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    with patch.object(router, "SQLServerModel", FakeModel):
        listed = router.list_conditional_entry_orders(limit=100, status=None)
    assert listed[0]["AttemptState"] is None
    assert listed[0]["TargetCursorRegion"] == "WAITING_FOR_REVERSAL"
    assert listed[0]["TargetTouchPrice"] == 683.45


def test_conditional_entry_batch_is_exercised_through_authenticated_http_route(monkeypatch):
    from app.routers.auth import verify_credentials

    app = FastAPI()
    app.include_router(router.router)

    class FakeModel:
        writes = []

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, _sql, _params):
            return []

        def execute_update_usp(self, sql, params):
            self.writes.append((sql, params))

    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false")
    with patch.object(router, "SQLServerModel", FakeModel):
        app.dependency_overrides[verify_credentials] = lambda: "test-user"
        try:
            response = TestClient(app).post(
                "/api/trading-orders/conditional-entry-batch",
                headers={"Idempotency-Key": "c01ed105-940a-4fe4-bbb7-9c2158a9281a"},
                json={"orders": [
                    {"strategy_id": 77, "stock_code": "QQQ", "side": "B", "quantity": 2,
                     "target_price": {"operator": "AT_OR_BELOW", "threshold": 500}},
                ]},
            )
        finally:
            app.dependency_overrides.pop(verify_credentials, None)

    assert response.status_code == 200
    assert response.json()["order_kind"] == "CONDITIONAL_ENTRY"
    assert FakeModel.writes and "Trading.ConditionalEntryCondition" in FakeModel.writes[0][0]


def test_manual_exit_fill_uses_actual_conditional_entry_filled_quantity(monkeypatch):
    class FakeModel:
        updates = []

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, query, params):
            if "GROUP BY o.Status, o.ExitFilledAt" in query:
                return [{"Status": "OPEN", "ExitFilledAt": None, "Quantity": 5,
                         "OrderKind": "CONDITIONAL_ENTRY", "EntryFilledQuantity": 2}]
            if "SELECT TOP 1 FillId" in query:
                return []
            raise AssertionError("Unexpected query")

        def execute_update_usp(self, query, params):
            self.updates.append((query, params))

    monkeypatch.setattr(router, "SQLServerModel", FakeModel)
    fill_time = datetime(2026, 11, 13, 15, 45)
    result = router.record_trading_order_exit_fill(
        17, router.TradingOrderExitFill(fill_price=101.25, fill_time=fill_time),
    )

    assert result["message"] == "Manual exit fill recorded successfully."
    assert FakeModel.updates[0][1][-1] == 2


def test_generic_order_cancel_cannot_bypass_conditional_entry_compare_set():
    class FakeModel:
        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, query, params):
            assert "SELECT OrderKind FROM Trading.Orders" in query
            assert params == (17,)
            return [{"OrderKind": "CONDITIONAL_ENTRY"}]

        def execute_update_usp(self, *_args):
            raise AssertionError("legacy DELETE route must not update a Conditional Entry")

    with patch.object(router, "SQLServerModel", FakeModel):
        with pytest.raises(HTTPException, match="Conditional Entry cancellation endpoint"):
            router.cancel_trading_order(17)


def test_generic_order_update_rejects_conditional_entry_term_edits(monkeypatch):
    class FakeModel:
        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, query, params):
            assert "SELECT OrderKind FROM Trading.Orders" in query
            assert params == (17,)
            return [{"OrderKind": "CONDITIONAL_ENTRY"}]

    order = router.TradingOrderUpdate(
        strategy_id=77, stock_code="QQQ", side="B", order_source_type="MANUAL",
        time_frame="5M", entry_type="LIMIT", quantity=2,
    )
    with patch.object(router, "SQLServerModel", FakeModel):
        with pytest.raises(HTTPException, match="Cancel and recreate a Conditional Entry"):
            router.update_trading_order(17, order)


def test_conditional_entry_http_route_rejects_unauthenticated_request():
    app = FastAPI()
    app.include_router(router.router)
    response = TestClient(app).get("/api/trading-orders/conditional-entry/status")

    assert response.status_code == 401


def test_conditional_entry_read_and_cancel_endpoints_preserve_audit_and_compare_set(monkeypatch):
    class FakeModel:
        updates = []

        def __init__(self, database):
            assert database == "StockDB_US"

        def execute_read_query(self, query, _params):
            if "SELECT Status, EntryPlacedAt" in query:
                return [{"Status": "PENDING", "EntryPlacedAt": None, "EntryFilledAt": None}]
            return [{"OrderId": 5, "AttemptState": "BLOCKED", "SubmissionState": None}]

        def execute_update_usp(self, query, params):
            self.updates.append((query, params))

    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_API_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_SCHEMA_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EVALUATOR_READY", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_DB_ONLY_ENABLED", "true")
    monkeypatch.setenv("PEGASUS_CONDITIONAL_ENTRY_EXECUTOR_ENABLED", "false")
    with patch.object(router, "SQLServerModel", FakeModel):
        listed = router.list_conditional_entry_orders(limit=100, status=None)
        cancelled = router.cancel_conditional_entry(5)

    assert listed[0]["AttemptState"] == "BLOCKED"
    assert cancelled["status"] == "CANCELLED"
    query, params = FakeModel.updates[0]
    assert "Status = 'CANCELLED'" in query
    assert "Status = 'PENDING'" in query
    assert "DELETE FROM" not in query.upper()
    assert params == (5, 5, 5, 5)


def test_batch_rejects_mixed_price_source_selection_and_wrong_tier_order():
    with pytest.raises(HTTPException, match="same price activation sources"):
        router._validate_conditional_entry_batch([
            _order(target_price={"operator": "AT_OR_BELOW", "threshold": 500}),
            _order(target_price=None, trigger_price={
                "instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 5000,
            }),
        ])
    with pytest.raises(HTTPException, match="server-calculated ladder"):
        router._validate_conditional_entry_batch([
            _order(target_price={"operator": "AT_OR_BELOW", "threshold": 500}),
            _order(target_price={"operator": "AT_OR_BELOW", "threshold": 492}),
            _order(target_price={"operator": "AT_OR_BELOW", "threshold": 480}),
        ])


def test_batch_uses_server_rebuilt_target_and_es_ladders():
    target_only = router._validate_conditional_entry_batch([
        _order(target_price={"operator": "AT_OR_BELOW", "threshold": 500}),
        _order(target_price={"operator": "AT_OR_BELOW", "threshold": 495}),
        _order(target_price={"operator": "AT_OR_BELOW", "threshold": 490}),
    ])
    assert [item["condition"]["target_price_threshold"] for item in target_only] == [500, 495, 490]

    es_only = router._validate_conditional_entry_batch([
        _order(target_price=None, trigger_price={
            "instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 5000,
        }),
        _order(target_price=None, trigger_price={
            "instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 4999.5,
        }),
        _order(target_price=None, trigger_price={
            "instrument_code": "ESMAIN.US", "operator": "AT_OR_BELOW", "threshold": 4999,
        }),
    ])
    assert [item["condition"]["trigger_price_threshold"] for item in es_only] == [5000, 4999.5, 4999]
