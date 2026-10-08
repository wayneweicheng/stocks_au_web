"use client";

import SkillReportPage, { type ReportSummary } from "../components/SkillReportPage";

const fields = [
  { name: "symbols", label: "Symbols (comma separated)", defaultValue: "SPY,QQQ,IWM", required: true },
  { name: "account_equity", label: "Account equity (USD)", defaultValue: 250000, min: 1 },
  { name: "assignment_exposure", label: "Existing put assignment exposure (USD)", defaultValue: 0, min: 0 },
  {
    name: "event_clear_symbols",
    label: "Event calendars verified clear (comma separated)",
    defaultValue: "SPY,QQQ,IWM",
    required: true,
  },
  { name: "top_n", label: "Maximum ranked candidates", defaultValue: 10, min: 1, max: 25 },
  { name: "dte_min", label: "Minimum DTE", defaultValue: 30, min: 21, max: 60 },
  { name: "dte_max", label: "Maximum DTE", defaultValue: 55, min: 21, max: 60 },
  { name: "min_vol_edge", label: "Minimum IV minus forecast RV (decimal)", defaultValue: 0.02, min: 0, max: 1 },
  { name: "risk_budget_pct", label: "One-trade stress budget / equity", defaultValue: 0.02, min: 0.001, max: 0.1 },
  { name: "max_assignment_exposure_pct", label: "Maximum assignment exposure / equity", defaultValue: 0.75, min: 0.01, max: 3 },
];

export default function VolatilitySelectiveOptionsPage() {
  return (
    <SkillReportPage
      title="Volatility-Selective Options"
      subtitle="Research/shadow scan for 30-55 DTE short puts and bull put spreads. The backend freezes IBKR/StockDB data, the deterministic skill ranks IV-versus-forecast-RV edge, and hard event, liquidity, assignment, and stress-risk gates remain fail-closed. No orders are submitted."
      reportsEndpoint="/api/volatility-selective-options-reports"
      jobsEndpoint="/api/volatility-selective-options/jobs"
      storageKey="stocks_au_volatility_selective_options_jobs"
      submitLabel="Build Snapshot and Run Shadow Scan"
      emptyLabel="No volatility-selective option reports found."
      initialTab="runner"
      fields={fields}
      makeJobLabel={(values) => `${String(values.symbols || "Options").toUpperCase()} volatility scan`}
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: (_report: ReportSummary) => "html",
      }}
    />
  );
}
