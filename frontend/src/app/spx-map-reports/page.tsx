"use client";

import SkillReportPage, { type ReportSummary } from "../components/SkillReportPage";

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

function getDailyObservationDate(report: ReportSummary): string | null {
  const content = (report as ReportSummary & { content?: string }).content || "";
  const text = content
    .replace(/<[^>]*>/g, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&rarr;|&#8594;|&#x2192;/gi, "→");
  const auditStart = text.search(/(?:结构\s*\/\s*审计\s*)?Structure\s*&\s*Audit/i);
  const auditSection = auditStart >= 0 ? text.slice(auditStart) : "";
  const dailySection = auditSection.match(/Daily[\s\S]{0,1500}/i)?.[0] || "";
  return dailySection.match(/\d{4}-\d{2}-\d{2}/)?.[0] || null;
}

function getSpxMapReportFileType(report: ReportSummary): "markdown" | "html" {
  const raw = report.raw || {};
  const metadata = [
    report.file_name,
    report.file_type,
    raw.file_name,
    raw.filename,
    raw.report_file,
    raw.report_filename,
    raw.report_path,
    raw.relative_path,
    raw.path,
    raw.file,
    raw.report,
    raw.name,
    raw.format,
    raw.extension,
    raw.mime_type,
    raw.content_type,
    raw.mime,
    raw.type,
    JSON.stringify(raw),
  ]
    .filter((value) => typeof value === "string")
    .join(" ")
    .toLowerCase();

  return /text\/html|\.(?:html?|xhtml)(?:\b|$)|\bhtml\b/.test(metadata) ? "html" : "markdown";
}

const fields = [
  {
    name: "as_at",
    label: "As-at",
    inputType: "datetime-timezone" as const,
    defaultValue: "",
    clientDefaultValue: () => getCurrentDateTimeInTimezone("Australia/Sydney"),
    timezones: [
      { label: "AU Sydney", value: "Australia/Sydney" },
      { label: "US Eastern", value: "America/New_York" },
    ],
    defaultTimezone: "Australia/Sydney",
    required: true,
  },
  {
    name: "timeout_minutes",
    label: "Timeout minutes",
    defaultValue: 120,
    min: 1,
    max: 240,
  },
  {
    name: "model",
    label: "Model",
    defaultValue: "gpt-5.6-luna",
  },
];

export default function SpxMapReportsPage() {
  return (
    <SkillReportPage
      title="SPX Map"
      subtitle="View SPX support/resistance maps and submit current or historical as-at jobs through the skill-runner proxy."
      reportsEndpoint="/api/spx-map-reports"
      jobsEndpoint="/api/spx-map/jobs"
      storageKey="stocks_au_spx_map_jobs"
      submitLabel="Submit SPX Map Job"
      emptyLabel="No SPX Map reports found."
      fields={fields}
      initialTab="html"
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: getSpxMapReportFileType,
      }}
      reportAction={{
        label: "Open mapped levels and orders",
        getHref: (report) => {
          const observationDate = getDailyObservationDate(report);
          const query = observationDate ? `?observation_date=${encodeURIComponent(observationDate)}` : "";
          return `/spx-map-reports/${encodeURIComponent(report.job_id)}/mapped-levels${query}`;
        },
      }}
      makeJobLabel={(values) => {
        const asAt = String(values.as_at || "").trim();
        return asAt ? `As-at | ${asAt}` : "Current SPX Map";
      }}
    />
  );
}
