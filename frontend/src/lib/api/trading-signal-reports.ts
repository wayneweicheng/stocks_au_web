export type TradingSignalReport = {
  public_report_id: string;
  report_kind: string;
  report_date: string;
  observation_date?: string | null;
  strategy_code: string;
  strategy_version_code: string;
  deployment_key: string;
  environment: string;
  subject_instrument_code?: string | null;
  execution_instrument_code?: string | null;
  title: string;
  summary?: string | null;
  file_name?: string | null;
  signal_classification?: string | null;
  revision_no: number;
  generated_utc: string;
  run_scheduled_utc: string;
  supersedes_public_report_id?: string | null;
  is_current: boolean;
  html_url: string;
};

export type TradingSignalReportPage = {
  items: TradingSignalReport[];
  next_cursor?: string | null;
  limit: number;
};

export type TradingSignalOverviewSignal = {
  public_report_id: string;
  report_date: string;
  tradable_date: string;
  end_date?: string | null;
  end_at?: string | null;
  strategy_code: string;
  strategy_version_code: string;
  instrument_code: string;
  direction: "LONG" | "SHORT";
  action_code: "PLAN_ENTRY" | "WATCH" | string;
  holding_period: string;
  signal_classification: string;
  title: string;
  html_url: string;
  historical_win_rate_pct: number;
  historical_instances: number;
  historical_resolved_instances: number;
  historical_profit_factor?: number | null;
  historical_average_return_pct?: number | null;
};

export type TradingSignalPricePerformance = {
  instrument_code: string;
  tradable_date: string;
  tradable_date_open_price: number | null;
  close_price: number | null;
  close_price_date: string | null;
  close_price_source: string | null;
  change_pct: number | null;
};

export type TradingSignalOverviewDataError = {
  public_report_id: string;
  report_date: string;
  observation_date: string | null;
  strategy_code: string;
  strategy_version_code: string;
  deployment_key: string;
  environment: string;
  instrument_code: string;
  signal_classification: string;
  title: string;
  reason: string;
  html_url: string;
};

export type TradingSignalOverviewItem = {
  instrument_code: string;
  verdict: "LONG" | "SHORT" | "CONFLICTING";
  signal_count: number;
  long_count: number;
  short_count: number;
  latest_report_date: string;
  signals: TradingSignalOverviewSignal[];
};

export type TradingSignalOverview = {
  as_of: string;
  items: TradingSignalOverviewItem[];
  data_errors: TradingSignalOverviewDataError[];
};

export function buildTradingSignalReportsQuery(filters: Record<string, string | undefined>) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  return query.toString();
}
