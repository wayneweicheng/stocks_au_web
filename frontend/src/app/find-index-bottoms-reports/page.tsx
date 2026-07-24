"use client";

import SkillReportPage from "../components/SkillReportPage";

function getCurrentDateTimeInTimezone(timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  })
    .formatToParts(new Date())
    .reduce<Record<string, string>>((current, part) => {
      current[part.type] = part.value;
      return current;
    }, {});

  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute} ${timeZone}`;
}

const fields = [
  {
    name: "as_at",
    label: "Historical as-at",
    inputType: "datetime-timezone" as const,
    defaultValue: "",
    clientDefaultValue: () => getCurrentDateTimeInTimezone("America/New_York"),
    timezones: [
      { label: "US EST", value: "America/New_York" },
      { label: "AU Sydney", value: "Australia/Sydney" },
    ],
    defaultTimezone: "America/New_York",
    required: true,
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
