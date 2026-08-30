"use client";

import SkillReportPage, { type ReportSummary } from "../components/SkillReportPage";

const fields = [
  { name: "observation_date", label: "Observation date", inputType: "date" as const, defaultValue: "2026-08-22", required: true },
  { name: "option_data_date", label: "Option data date", inputType: "date" as const, defaultValue: "2026-08-21", required: true },
  { name: "order_date", label: "Order date", inputType: "date" as const, defaultValue: "2026-08-22", required: true },
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
