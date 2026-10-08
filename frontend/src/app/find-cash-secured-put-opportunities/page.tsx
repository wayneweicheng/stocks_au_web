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
  { name: "order_date", label: "Order date", inputType: "date" as const, defaultValue: "", clientDefaultValue: getTodayISO, required: true },
  { name: "ticker", label: "Ticker", defaultValue: "MU", required: true },
  { name: "top_n", label: "Top opportunities", defaultValue: 5, min: 1, max: 100 },
  { name: "constraints", label: "Constraints", defaultValue: "Only recommend assignment prices below $720", multiline: true },
  { name: "model", label: "Model", defaultValue: "gpt-5.6-luna", required: true },
];

export default function FindCashSecuredPutOpportunitiesPage() {
  return (
    <SkillReportPage
      title="Cash-Secured Put Opportunities"
      subtitle="Review assignment-first cash-secured put research reports, or submit a new opportunity scan."
      reportsEndpoint="/api/find-cash-secured-put-opportunities-reports"
      jobsEndpoint="/api/find-cash-secured-put-opportunities/jobs"
      storageKey="stocks_au_find_cash_secured_put_opportunities_jobs"
      submitLabel="Submit Cash-Secured Puts Job"
      emptyLabel="No cash-secured put opportunity reports found."
      initialTab="html"
      fields={fields}
      makeJobLabel={(values) => `${String(values.ticker || "Market").toUpperCase()} cash-secured puts`}
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: (_report: ReportSummary) => "html",
      }}
    />
  );
}
