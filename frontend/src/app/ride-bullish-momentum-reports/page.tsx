"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "as_at",
    label: "Historical as-at (optional)",
    inputType: "datetime-timezone" as const,
    defaultValue: "",
    timezones: [
      { label: "US Eastern", value: "America/New_York" },
      { label: "AU Sydney", value: "Australia/Sydney" },
    ],
    defaultTimezone: "America/New_York",
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
    defaultValue: "gpt-5.6-luna",
    omitWhenBlank: true,
  },
];

export default function RideBullishMomentumReportsPage() {
  return (
    <SkillReportPage
      title="Ride Bullish Momentum"
      subtitle="View bullish-momentum reports and run current or historical as-at jobs through the skill-runner proxy."
      reportsEndpoint="/api/ride-bullish-momentum-reports"
      jobsEndpoint="/api/ride-bullish-momentum/jobs"
      storageKey="stocks_au_ride_bullish_momentum_jobs"
      submitLabel="Submit Bullish Momentum Job"
      emptyLabel="No bullish-momentum reports found."
      fields={fields}
      makeJobLabel={(values) => {
        const asAt = String(values.as_at || "").trim();
        return asAt ? `Historical | ${asAt}` : "Current bullish momentum analysis";
      }}
    />
  );
}
