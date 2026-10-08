"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "observation_date",
    label: "Observation date",
    inputType: "date" as const,
    defaultValue: "",
    required: true,
  },
  {
    name: "stock_code",
    label: "Stock code (optional)",
    placeholder: "e.g. SKK or SKK.AX",
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
];

const rangeFields = [
  {
    name: "stock_code",
    label: "Stock code",
    placeholder: "e.g. SKK or SKK.AX",
    defaultValue: "",
    required: true,
  },
  {
    name: "start_date",
    label: "Start date",
    inputType: "date" as const,
    defaultValue: "",
    required: true,
  },
  {
    name: "end_date",
    label: "End date",
    inputType: "date" as const,
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

export default function AsxMicrostructureAccumulationReportsPage() {
  return (
    <SkillReportPage
      title="ASX Microstructure Accumulation"
      subtitle="View accumulation reports and scan all ASX stocks or a specific stock through the skill-runner proxy."
      reportsEndpoint="/api/asx-microstructure-accumulation-reports"
      jobsEndpoint="/api/asx-microstructure-accumulation/jobs"
      storageKey="stocks_au_asx_microstructure_accumulation_jobs"
      submitLabel="Submit Accumulation Job"
      emptyLabel="No ASX microstructure accumulation reports found."
      fields={fields}
      alternateJobMode={{
        key: "range",
        label: "Stock date range",
        fields: rangeFields,
        jobsEndpoint: "/api/asx-microstructure-accumulation/jobs",
        submitLabel: "Submit Range Job",
        makeJobLabel: (values) => {
          const stockCode = String(values.stock_code || "Stock").trim().toUpperCase();
          return `${stockCode} | ${values.start_date} to ${values.end_date}`;
        },
      }}
      makeJobLabel={(values) => {
        const stockCode = String(values.stock_code || "All stocks").trim().toUpperCase();
        return `${stockCode} | ${values.observation_date}`;
      }}
    />
  );
}
