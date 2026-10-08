"use client";

import SkillReportPage, { type ReportSummary } from "../../components/SkillReportPage";

const exampleDataset = JSON.stringify(
  {
    dataset_name: "replace-with-point-in-time-snapshots",
    initial_capital: 100000,
    monte_carlo_iterations: 2000,
    config: { profit_capture: 0.6, time_exit_dte: 14, risk_delta_exit: 0.45 },
    snapshots: [],
  },
  null,
  2,
);

const fields = [
  {
    name: "dataset_json",
    label: "Historical dataset JSON",
    defaultValue: exampleDataset,
    multiline: true,
    required: true,
  },
  { name: "model", label: "Execution mode", defaultValue: "deterministic", required: true },
];

export default function VolatilityBacktestPage() {
  return (
    <SkillReportPage
      title="Volatility-Selective Backtest"
      subtitle="Run time-ordered option research with conservative entry economics, forward-only outcomes, walk-forward windows, parameter-neighborhood stability, Monte Carlo trade-sequence testing, and regime attribution. The dataset must be point-in-time and must provide forward_market data after each entry snapshot."
      reportsEndpoint="/api/volatility-selective-backtest-reports"
      jobsEndpoint="/api/volatility-selective-backtest/jobs"
      storageKey="stocks_au_volatility_selective_backtest_jobs"
      submitLabel="Run Deterministic Backtest"
      emptyLabel="No volatility backtest reports found."
      initialTab="runner"
      fields={fields}
      makeJobLabel={() => "Volatility-selective backtest"}
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: (_report: ReportSummary) => "html",
      }}
    />
  );
}
