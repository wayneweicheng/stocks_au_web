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

function getStockMapReportFileType(report: ReportSummary): "markdown" | "html" {
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
    name: "stock_code",
    label: "Stock code",
    defaultValue: "NVDA",
    required: true,
  },
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

export default function StockMapReportsPage() {
  return (
    <SkillReportPage
      title="Stock Map"
      subtitle="View stock support/resistance maps and submit current or historical as-at jobs through the skill-runner proxy."
      reportsEndpoint="/api/stock-map-reports"
      jobsEndpoint="/api/stock-map/jobs"
      storageKey="stocks_au_stock_map_jobs"
      submitLabel="Submit Stock Map Job"
      emptyLabel="No Stock Map reports found."
      fields={fields}
      initialTab="html"
      htmlReports={{
        label: "HTML Reports",
        getReportFileType: getStockMapReportFileType,
      }}
      reportAction={{
        label: "Open mapped levels and orders",
        getHref: (report) => {
          const stockCode = report.stock_code || String(report.raw?.stock_code || report.raw?.instrument_code || "").trim();
          const rawAsAt = String(report.raw?.observation_date || report.raw?.as_at || report.raw?.as_of_date || "");
          const observationDate = rawAsAt.match(/\d{4}-\d{2}-\d{2}/)?.[0] || "";
          const params = new URLSearchParams();
          if (stockCode) params.set("stock_code", stockCode);
          if (observationDate) params.set("observation_date", observationDate);
          const query = params.toString() ? `?${params.toString()}` : "";
          return `/stock-map-reports/${encodeURIComponent(report.job_id)}/mapped-levels${query}`;
        },
      }}
      makeJobLabel={(values) => {
        const stockCode = String(values.stock_code || "Stock").trim().toUpperCase();
        const asAt = String(values.as_at || "").trim();
        return asAt ? `${stockCode} | As-at ${asAt}` : `${stockCode} Stock Map`;
      }}
    />
  );
}
