from __future__ import annotations

import json
import unittest

from app.repositories.trading_signal_admin import TradingSignalAdminRepository, _actual_return, _metadata_values, _stats
from app.schemas.trading_signal_admin import AdminStrategyPage


class _CatalogModel:
    def __init__(self, responses):
        self.responses = list(responses)

    def execute_read_query(self, _sql, _values):
        return self.responses.pop(0)

    def close(self):
        pass


class _ToggleCursor:
    description = []

    def __init__(self):
        self.statements = []
        self._selected = None

    def execute(self, sql, values):
        self.statements.append((sql, values))
        if "SELECT d.StrategyDeploymentID" in sql:
            self.description = [("strategy_deployment_id",), ("deployment_key",), ("environment",), ("is_enabled",), ("notification_enabled",), ("execution_enabled",)]
            self._selected = (10, "spx-gex-production", "FORWARD_PAPER", 1, 1, 0)
        return self

    def fetchone(self):
        return self._selected

    def close(self):
        pass


class _ToggleConnection:
    def __init__(self):
        self.cursor_instance = _ToggleCursor()
        self.committed = False
        self.rolled_back = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True

    def rollback(self):
        self.rolled_back = True

    def close(self):
        pass


class TradingSignalAdminHelpersTests(unittest.TestCase):
    def test_stats_are_null_when_no_finalized_instances_exist(self):
        result = _stats([])
        self.assertEqual(result["instances"], 0)
        self.assertIsNone(result["win_rate_pct"])
        self.assertIsNone(result["profit_factor"])

    def test_stats_use_directional_returns(self):
        result = _stats([
            {"directional_return_pct": 2.0},
            {"directional_return_pct": -1.0},
            {"directional_return_pct": 0.0},
        ])
        self.assertEqual(result["instances"], 3)
        self.assertEqual(result["wins"], 1)
        self.assertEqual(result["losses"], 1)
        self.assertAlmostEqual(result["win_rate_pct"], 33.3333)
        self.assertEqual(result["profit_factor"], 2.0)

    def test_actual_return_is_direction_adjusted(self):
        self.assertEqual(_actual_return("LONG", 100, 110), 10.0)
        self.assertEqual(_actual_return("SHORT", 100, 90), 10.0)
        self.assertIsNone(_actual_return("LONG", 100, None))

    def test_metadata_values_accept_lists_and_fallback_order(self):
        self.assertEqual(
            _metadata_values([{"trigger_conditions": ["A", "B"]}, {"entry_rule": "C"}], ("trigger_conditions", "entry_rule")),
            ["A", "B"],
        )

    def test_catalog_joins_stock_metadata_historical_stats_and_actual_executions(self):
        model = _CatalogModel([
            [{"strategy_definition_id": 1, "strategy_code": "META_GEX", "display_name": "META GEX", "description": "A definition"}],
            [
                {"strategy_version_id": 2, "strategy_definition_id": 1, "version_code": "v2", "implementation_key": "meta-gex@v2", "configuration_json": '{"trigger_conditions":["close above level"],"exit_conditions":["D2 close"],"directions":["LONG"]}', "research_metadata_json": None, "status": "ACTIVE", "created_utc": None, "strategy_deployment_id": 10, "deployment_key": "meta-gex-production", "environment": "FORWARD_PAPER", "is_enabled": 1, "execution_enabled": 0, "notification_enabled": 1, "deployment_configuration_json": None},
                {"strategy_version_id": 2, "strategy_definition_id": 1, "version_code": "v2", "implementation_key": "meta-gex@v2", "configuration_json": '{"trigger_conditions":["close above level"],"exit_conditions":["D2 close"],"directions":["LONG"]}', "research_metadata_json": None, "status": "ACTIVE", "created_utc": None, "strategy_deployment_id": 11, "deployment_key": "meta-gex-shadow", "environment": "MIGRATION_SHADOW", "is_enabled": 1, "execution_enabled": 0, "notification_enabled": 1, "deployment_configuration_json": None},
            ],
            [{"strategy_deployment_id": 10, "instrument_code": "META.US", "role_code": "SUBJECT"}, {"strategy_deployment_id": 11, "instrument_code": "META.US", "role_code": "SUBJECT"}],
            [{"strategy_version_id": 2, "direction": "LONG", "classification": "ENTRY"}],
            [{"strategy_version_id": 2, "strategy_deployment_id": 10, "environment": "BACKTEST", "classification": "ENTRY", "market_date": "2025-01-01", "directional_return_pct": 2.0}, {"strategy_version_id": 2, "strategy_deployment_id": 10, "environment": "BACKTEST", "classification": "ENTRY", "market_date": "2025-01-02", "directional_return_pct": -1.0}],
            [{"trade_plan_id": 99, "signal_id": 88, "strategy_version_id": 2, "strategy_version_code": "v2", "deployment_key": "meta-gex-production", "market_date": None, "classification": "ENTRY", "direction": "LONG", "execution_instrument_code": "META.US", "plan_status": "EXITED_TIME", "planned_entry_utc": None, "planned_exit_utc": None, "actual_entry_utc": None, "actual_entry_price": 100.0, "actual_exit_utc": None, "actual_exit_price": 110.0, "exit_reason": "TIME"}],
        ])
        result = TradingSignalAdminRepository(lambda: model).list_strategies()
        strategy = result["stocks"][0]["strategies"][0]
        self.assertEqual(result["stocks"][0]["stock_code"], "META.US")
        self.assertEqual(strategy["trigger_conditions"], ["close above level"])
        self.assertEqual(strategy["exit_conditions"], ["D2 close"])
        self.assertEqual(strategy["signal_names"], ["ENTRY"])
        self.assertEqual(strategy["historical_stats"]["instances"], 2)
        production = next(item for item in strategy["deployments"] if item["is_production"])
        self.assertEqual(production["production_stats"]["instances"], 2)
        self.assertIsNone(production["executions"][0]["actual_return_pct"])
        self.assertEqual(production["executions"][0]["outcome_status"], "WAITING_MARKET_DATA")
        self.assertFalse(production["execution_enabled"])

    def test_historical_card_prefers_model_builder_stats_over_runtime_outcomes(self):
        model = _CatalogModel([
            [{"strategy_definition_id": 1, "strategy_code": "META_GEX", "display_name": "META GEX", "description": "A definition"}],
            [{
                "strategy_version_id": 2,
                "strategy_definition_id": 1,
                "version_code": "v2",
                "implementation_key": "meta-gex@v2",
                "configuration_json": json.dumps({
                    "subject_instrument_code": "META.US",
                    "historical_trade_ledger": {"records": [{
                        "signal_code": "META_ENTRY",
                        "market_date": "2026-01-02",
                        "direction": "LONG",
                        "entry_timestamp": "2026-01-03T07:30:00",
                        "entry_price": 100.0,
                        "exit_timestamp": "2026-01-03T15:30:00",
                        "exit_price": 102.0,
                        "exit_reason": "D1_CASH_CLOSE",
                        "return_pct": 1.8,
                        "mfe_pct": 2.1,
                        "mae_pct": -0.4,
                        "bars_held": 17,
                        "status": "FINAL",
                        "features": {"CloseChangePct": 0.5},
                    }]},
                    "signal_definitions": [{
                        "signal_code": "META_ENTRY",
                        "display_name": "META entry",
                        "strategy_definition": "Model-builder rule",
                        "trigger_condition": "close above level",
                        "direction": "LONG",
                        "action": "PLAN_ENTRY",
                        "historical_performance": {
                            "status": "AVAILABLE",
                            "number_of_signal_instances": 15,
                            "wins": 12,
                            "losses": 3,
                            "win_rate_pct": 80.0,
                            "profit_factor": 8.0723,
                            "gross_profit_return_units": 18.0,
                            "gross_loss_return_units": 2.2,
                        },
                    }],
                }),
                "research_metadata_json": None,
                "status": "ACTIVE",
                "created_utc": None,
                "strategy_deployment_id": 10,
                "deployment_key": "meta-gex-production",
                "environment": "LIVE_MANUAL",
                "is_enabled": 1,
                "execution_enabled": 0,
                "notification_enabled": 1,
                "deployment_configuration_json": None,
            }],
            [{"strategy_deployment_id": 10, "instrument_code": "META.US", "role_code": "SUBJECT"}],
            [{"strategy_version_id": 2, "direction": "LONG", "classification": "META_ENTRY"}],
            [{"strategy_version_id": 2, "strategy_deployment_id": 10, "environment": "BACKTEST", "classification": "META_ENTRY", "market_date": "2026-01-01", "directional_return_pct": -99.0}],
            [],
        ])
        result = TradingSignalAdminRepository(lambda: model).list_strategies()
        strategy = result["stocks"][0]["strategies"][0]
        self.assertEqual(strategy["historical_stats"]["instances"], 15)
        self.assertEqual(strategy["historical_stats"]["wins"], 12)
        self.assertEqual(strategy["historical_stats"]["losses"], 3)
        self.assertAlmostEqual(strategy["historical_stats"]["win_rate_pct"], 80.0)
        self.assertAlmostEqual(strategy["historical_stats"]["profit_factor"], 18.0 / 2.2, places=4)
        self.assertEqual(strategy["historical_stats"]["source"], "MODEL_BUILDER_PACKET")
        self.assertEqual(len(strategy["historical_trades"]), 1)
        self.assertEqual(strategy["historical_trades"][0]["exit_reason"], "D1_CASH_CLOSE")

    def test_admin_response_normalizes_packet_confidence_object_to_label(self):
        model = _CatalogModel([
            [{"strategy_definition_id": 1, "strategy_code": "TEST_GEX", "display_name": "Test GEX", "description": "A definition"}],
            [{
                "strategy_version_id": 2,
                "strategy_definition_id": 1,
                "version_code": "v1",
                "implementation_key": "test-gex@v1",
                "configuration_json": json.dumps({
                    "subject_instrument_code": "TEST.US",
                    "signal_definitions": [{
                        "signal_code": "TEST_ENTRY",
                        "display_name": "Test entry",
                        "strategy_definition": "Test rule",
                        "trigger_condition": "close above level",
                        "direction": "LONG",
                        "confidence": {"label": "MEDIUM_HIGH", "score": 0.78},
                        "action": "PLAN_ENTRY",
                        "notification_level": "NORMAL",
                        "entry_policy": "Next open",
                        "holding_period": "D1",
                        "exit_conditions": [],
                        "historical_performance": {"status": "NOT_AVAILABLE"},
                    }],
                }),
                "research_metadata_json": None,
                "status": "ACTIVE",
                "created_utc": None,
                "strategy_deployment_id": 10,
                "deployment_key": "test-gex-production",
                "environment": "LIVE_MANUAL",
                "is_enabled": 1,
                "execution_enabled": 0,
                "notification_enabled": 1,
                "deployment_configuration_json": None,
            }],
            [{"strategy_deployment_id": 10, "instrument_code": "TEST.US", "role_code": "SUBJECT"}],
            [{"strategy_version_id": 2, "direction": "LONG", "classification": "TEST_ENTRY"}],
            [],
            [],
        ])
        payload = TradingSignalAdminRepository(lambda: model).list_strategies()
        page = AdminStrategyPage(**payload)
        self.assertEqual(page.stocks[0].strategies[0].signals[0].confidence, "MEDIUM_HIGH")

    def test_retired_legacy_versions_are_not_catalogued(self):
        model = _CatalogModel([
            [{"strategy_definition_id": 1, "strategy_code": "SPX_GEX", "display_name": "SPX GEX", "description": "definition"}],
            [
                {"strategy_version_id": 2, "strategy_definition_id": 1, "version_code": "v1.0.3-production", "implementation_key": "spx_gex@v1.0.3-production", "configuration_json": '{"subject_instrument_code":"SPX"}', "research_metadata_json": None, "status": "ACTIVE", "created_utc": None, "strategy_deployment_id": 10, "deployment_key": "spx-gex-production", "environment": "LIVE_MANUAL", "is_enabled": 1, "execution_enabled": 0, "notification_enabled": 1, "deployment_configuration_json": None},
                {"strategy_version_id": 3, "strategy_definition_id": 1, "version_code": "legacy-import-v1", "implementation_key": "legacy@v1", "configuration_json": '{"subject_instrument_code":"SPX"}', "research_metadata_json": None, "status": "RETIRED", "created_utc": None, "strategy_deployment_id": 11, "deployment_key": "spx-gex-legacy-import", "environment": "MIGRATION_SHADOW", "is_enabled": 0, "execution_enabled": 0, "notification_enabled": 0, "deployment_configuration_json": None},
            ],
            [{"strategy_deployment_id": 10, "instrument_code": "SPX", "role_code": "SUBJECT"}, {"strategy_deployment_id": 11, "instrument_code": "SPX", "role_code": "SUBJECT"}],
            [], [], [],
        ])
        result = TradingSignalAdminRepository(lambda: model).list_strategies()
        assert result["strategy_count"] == 1
        assert result["stocks"][0]["strategies"][0]["version_code"] == "v1.0.3-production"

    def test_production_toggle_is_audited_and_cannot_enable_broker_execution(self):
        connection = _ToggleConnection()
        result = TradingSignalAdminRepository(connection_factory=lambda **_kwargs: connection).set_production_enabled(10, False, "admin")
        self.assertFalse(result["is_enabled"])
        self.assertFalse(result["execution_enabled"])
        self.assertTrue(connection.committed)
        self.assertEqual(len(connection.cursor_instance.statements), 3)
        self.assertIn("ExecutionEnabled = 0", connection.cursor_instance.statements[1][0])
        self.assertIn("STRATEGY_PRODUCTION_TOGGLE", connection.cursor_instance.statements[2][1][0])


if __name__ == "__main__":
    unittest.main()
