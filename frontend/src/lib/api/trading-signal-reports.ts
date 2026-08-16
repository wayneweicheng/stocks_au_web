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
  revision_no: number;
  generated_utc: string;
  supersedes_public_report_id?: string | null;
  is_current: boolean;
  html_url: string;
};

export type TradingSignalReportPage = {
  items: TradingSignalReport[];
  next_cursor?: string | null;
  limit: number;
};

export function buildTradingSignalReportsQuery(filters: Record<string, string | undefined>) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  return query.toString();
}
