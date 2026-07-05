"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "as_at",
    label: "Historical as-at",
    placeholder: "2026-06-22 16:00 America/New_York",
    defaultValue: "",
    omitWhenBlank: true,
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

export default function FindIndexBottomsReportsPage() {
  return (
    <SkillReportPage
      title="Find Index Bottoms"
      subtitle="View index-bottom analysis reports and run current or historical cutoff-aware jobs through the skill-runner proxy."
      reportsEndpoint="/api/find-index-bottoms-reports"
      jobsEndpoint="/api/find-index-bottoms/jobs"
      storageKey="stocks_au_find_index_bottoms_jobs"
      submitLabel="Submit Index Bottom Job"
      emptyLabel="No index-bottom reports found."
      fields={fields}
      makeJobLabel={(values) => {
        const asAt = String(values.as_at || "").trim();
        return asAt ? `Historical | ${asAt}` : "Current index-bottom analysis";
      }}
    />
  );
}
