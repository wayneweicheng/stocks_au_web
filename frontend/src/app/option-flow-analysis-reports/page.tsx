"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "observation_date",
    label: "Observation date",
    placeholder: "2026-07-02",
    defaultValue: "2026-07-02",
    required: true,
  },
  {
    name: "ticker",
    label: "Ticker drill-down",
    placeholder: "Leave blank for full market, or enter MU",
    defaultValue: "",
    omitWhenBlank: true,
  },
  {
    name: "top_n",
    label: "Top trades",
    defaultValue: 10,
    min: 1,
    max: 100,
  },
  {
    name: "timeout_minutes",
    label: "Timeout minutes",
    defaultValue: 90,
    min: 1,
    max: 240,
  },
  {
    name: "model",
    label: "Model",
    placeholder: "Leave blank to use the skill-runner default",
    defaultValue: "",
    omitWhenBlank: true,
  },
];

export default function OptionFlowAnalysisReportsPage() {
  return (
    <SkillReportPage
      title="Option Flow Analysis"
      subtitle="View generated option-flow reports and run full-market significant-trade scans, with optional ticker drill-down."
      reportsEndpoint="/api/option-flow-analysis-reports"
      jobsEndpoint="/api/option-flow-analysis/jobs"
      storageKey="stocks_au_option_flow_analysis_jobs"
      submitLabel="Submit Option Flow Job"
      emptyLabel="No option-flow analysis reports found."
      fields={fields}
      makeJobLabel={(values) => {
        const date = String(values.observation_date || "observation date");
        const ticker = String(values.ticker || "").trim().toUpperCase();
        return ticker ? `${date}:${ticker}` : `${date}:full market`;
      }}
    />
  );
}
