"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "input_text",
    label: "Input text",
    placeholder: "Paste the long event write-up, keynote summary, article text, or market narrative here.",
    multiline: true,
    defaultValue: "",
    required: true,
  },
  {
    name: "timeout_minutes",
    label: "Timeout minutes",
    defaultValue: 90,
    min: 1,
    max: 240,
  },
];

export default function ShisoLeafStockHunterReportsPage() {
  return (
    <SkillReportPage
      title="Shiso Leaf Stock Hunter"
      subtitle="View Shiso Leaf stock hunter reports and submit long-form narrative scans through the skill-runner proxy."
      reportsEndpoint="/api/shiso-leaf-stock-hunter-reports"
      jobsEndpoint="/api/shiso-leaf-stock-hunter/jobs"
      storageKey="stocks_au_shiso_leaf_stock_hunter_jobs"
      submitLabel="Submit Hunter Job"
      emptyLabel="No Shiso Leaf stock hunter reports found."
      fields={fields}
      makeJobLabel={(values) => `Shiso Leaf | ${String(values.input_text || "").slice(0, 48) || "input text"}`}
    />
  );
}
