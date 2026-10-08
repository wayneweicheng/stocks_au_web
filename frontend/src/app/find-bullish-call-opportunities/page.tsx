"use client";

import SkillReportPage, { type ReportSummary } from "../components/SkillReportPage";

function getTodayISO() {
  const date = new Date();
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// Keep this aligned with the default Observation date used by market-flow/page.tsx.
function getMarketFlowObservationDate() {
  const date = new Date();
  date.setDate(date.getDate() - 1);
  while (date.getDay() === 0 || date.getDay() === 6) date.setDate(date.getDate() - 1);
  return date.toISOString().slice(0, 10);
}

const fields = [
  { name: "observation_date", label: "Observation date", inputType: "date" as const, defaultValue: "", clientDefaultValue: getTodayISO, required: true },
  { name: "option_data_date", label: "Option data date", inputType: "date" as const, defaultValue: "", clientDefaultValue: getMarketFlowObservationDate, required: true },
  { name: "proposed_order_date", label: "Proposed order date", inputType: "date" as const, defaultValue: "", clientDefaultValue: getTodayISO, required: true },
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
