"use client";

import SkillReportPage, { type ReportSummary } from "../components/SkillReportPage";

const fields = [
  { name: "observation_date", label: "Observation date", inputType: "date" as const, defaultValue: "2026-08-22", required: true },
  { name: "option_data_date", label: "Option data date", inputType: "date" as const, defaultValue: "2026-08-21", required: true },
  { name: "proposed_order_date", label: "Proposed order date", inputType: "date" as const, defaultValue: "2026-08-22", required: true },
  { name: "ticker", label: "Ticker", defaultValue: "QQQ", required: true },
  { name: "top_n", label: "Top opportunities", defaultValue: 5, min: 1, max: 100 },
  { name: "constraints", label: "Constraints", defaultValue: "Prefer defined-risk call spreads", multiline: true },
  { name: "model", label: "Model", defaultValue: "gpt-5.6-luna", required: true },
];

export default function FindBullishCallOpportunitiesPage() {
  return (
    <SkillReportPage
      title="Bullish Call Opportunities"
      subtitle="Review defined-risk bullish call and call-spread research reports, or submit a new opportunity scan."
      reportsEndpoint="/api/find-bullish-call-opportunities-reports"
      jobsEndpoint="/api/find-bullish-call-opportunities/jobs"
      storageKey="stocks_au_find_bullish_call_opportunities_jobs"
      submitLabel="Submit Bullish Calls Job"
      emptyLabel="No bullish call opportunity reports found."
      initialTab="html"
      fields={fields}
      makeJobLabel={(values) => `${String(values.ticker || "Market").toUpperCase()} bullish calls`}
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: (_report: ReportSummary) => "html",
      }}
    />
  );
}
