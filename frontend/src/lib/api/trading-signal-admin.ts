export type AdminPerformanceStats = {
  instances: number;
  wins: number;
  losses: number;
  win_rate_pct: number | null;
  profit_factor: number | null;
  average_return_pct: number | null;
  median_return_pct: number | null;
  gross_profit_pct: number | null;
  gross_loss_pct: number | null;
  source?: string | null;
  source_reference?: string | null;
};

export type AdminExecution = {
  trade_plan_id: number | null;
  signal_id: number;
  strategy_version_id: number;
  strategy_version_code: string;
  deployment_key: string;
  market_date: string | null;
  classification: string | null;
  direction: string | null;
  execution_instrument_code: string | null;
  plan_status: string;
  planned_entry_utc: string | null;
  planned_exit_utc: string | null;
  actual_entry_utc: string | null;
  actual_entry_price: number | null;
  actual_exit_utc: string | null;
  actual_exit_price: number | null;
  exit_reason: string | null;
  actual_return_pct: number | null;
  calculated_entry_price: number | null;
  calculated_exit_price: number | null;
  calculated_exit_reason: string | null;
  outcome_status: string;
  outcome_horizon: string | null;
  outcome_finalized_utc: string | null;
  execution_mode: string;
};

export type AdminEvaluationSchedule = {
  timezone_name: string | null;
  local_time: string | null;
  cadence_seconds: number | null;
  interval_minutes: number | null;
  window_end: string | null;
};

export type AdminDeployment = {
  strategy_deployment_id: number;
  deployment_key: string;
  environment: string;
  is_enabled: boolean;
  notification_enabled: boolean;
  execution_enabled: boolean;
  is_production: boolean;
  notification_only: boolean;
  evaluation_schedule: AdminEvaluationSchedule | null;
  production_stats: AdminPerformanceStats;
  executions: AdminExecution[];
};

export type AdminSignalDefinition = {
  signal_code: string;
  display_name: string;
  strategy_definition: string;
  trigger_condition: string;
  direction: string;
  confidence: string;
  confidence_score: number | null;
  action: string;
  notification_level: string;
  entry_policy: string;
  holding_period: string;
  exit_conditions: { kind: string; description: string; horizon: string | null }[];
  historical_performance: {
    status: string;
    instances: number;
    sample_start: string | null;
    sample_end: string | null;
    measurement_horizon: string;
    win_rate_pct: number | null;
    profit_factor: number | null;
    average_return_pct: number | null;
    median_return_pct: number | null;
    source_reference: string;
    as_of_utc: string;
    notes: string;
  };
};

export type AdminHistoricalTrade = {
  signal_code: string;
  market_date: string;
  direction: string;
  entry_timestamp: string | null;
  entry_price: number | null;
  exit_timestamp: string | null;
  exit_price: number | null;
  exit_reason: string;
  gross_return_pct: number | null;
  return_pct: number | null;
  mfe_pct: number | null;
  mae_pct: number | null;
  bars_held: number | null;
  same_bar_ambiguity: boolean;
  status: string;
  features: Record<string, unknown>;
};

export type AdminStrategyVersion = {
  strategy_version_id: number;
  strategy_code: string;
  display_name: string;
  version_code: string;
  implementation_key: string | null;
  status: string;
  created_utc: string | null;
  strategy_definition: string;
  trigger_conditions: string[];
  exit_conditions: string[];
  signal_names: string[];
  signals: AdminSignalDefinition[];
  directions: string[];
  configuration: Record<string, unknown>;
  historical_stats: AdminPerformanceStats;
  historical_trades: AdminHistoricalTrade[];
  deployments: AdminDeployment[];
};

export type AdminStockGroup = {
  stock_code: string;
  strategies: AdminStrategyVersion[];
};

export type AdminStrategyPage = {
  generated_utc: string;
  stocks: AdminStockGroup[];
  strategy_count: number;
  production_deployment_count: number;
  enabled_production_deployment_count: number;
};
