"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import Alert from "./ui/Alert";
import Badge from "./ui/Badge";
import Button from "./ui/Button";
import Input from "./ui/Input";
import Select from "./ui/Select";
import MarkdownRenderer from "./MarkdownRenderer";
import PageHeader from "./PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

export type ReportSummary = {
  job_id: string;
  title: string;
  created_at?: string | null;
  stock_code?: string | null;
  status?: string | null;
  file_name?: string | null;
  file_type?: string | null;
  raw?: Record<string, unknown>;
};

type ReportDetail = ReportSummary & { content: string };
type ReportPageResponse = { items: ReportSummary[] };
type ProxyResponse = { data: Record<string, unknown> };
type OptionCountAggregate = {
  ASXCode?: string;
  asx_code?: string;
  NumRecords?: number;
  num_records?: number;
  NumOptions?: number;
  num_options?: number;
  in_market_flow?: boolean;
  InMarketFlow?: boolean;
};
type OptionCountAggregatesResponse = {
  trades?: OptionCountAggregate[];
  bidask?: OptionCountAggregate[];
};
type OptionCountRow = {
  code: string;
  tradeRecords: number;
  tradeOptions: number;
  bidAskRecords: number;
  bidAskOptions: number;
  inMarketFlow: boolean;
};

type SavedJob = {
  job_id: string;
  label: string;
  submitted_at: string;
  status?: string;
  last_checked_at?: string;
};

export type TextField = {
  name: string;
  label: string;
  inputType?: "text" | "date";
  placeholder?: string;
  multiline?: boolean;
  defaultValue?: string;
  required?: boolean;
  omitWhenBlank?: boolean;
};

export type DateTimeTimezoneField = {
  name: string;
  label: string;
  inputType: "datetime-timezone";
  defaultValue?: string;
  clientDefaultValue?: () => string;
  required?: boolean;
  omitWhenBlank?: boolean;
  timezones: Array<{ label: string; value: string }>;
  defaultTimezone: string;
};

export type NumberField = {
  name: string;
  label: string;
  defaultValue: number;
  min?: number;
  max?: number;
};

export type ReportJobMode = {
  key: string;
  label: string;
  fields: Array<TextField | DateTimeTimezoneField | NumberField>;
  jobsEndpoint: string;
  submitLabel?: string;
  makeJobLabel: (values: Record<string, string | number>) => string;
};

export type ReportFileType = "markdown" | "html";
export type ReportDateRange = {
  startDate: string;
  endDate: string;
};
export type OptionCountsDateRangeFields = {
  startDateField: string;
  endDateField: string;
};

type Props = {
  title: string;
  subtitle: string;
  reportsEndpoint: string;
  jobsEndpoint: string;
  storageKey: string;
  submitLabel: string;
  emptyLabel: string;
  fields: Array<TextField | DateTimeTimezoneField | NumberField>;
  makeJobLabel: (values: Record<string, string | number>) => string;
  buildReportPrompt?: (detail: ReportDetail) => string;
  reportPromptLabel?: string;
  copyPromptLabel?: string;
  getReportDate?: (report: ReportSummary) => string;
  optionCountsEndpoint?: string;
  optionCountsTitle?: string;
  optionCountsObservationDateField?: string;
  optionCountsDateRangeFields?: OptionCountsDateRangeFields;
  canDeleteReports?: boolean;
  initialTab?: "viewer" | "html" | "runner";
  htmlReports?: {
    label?: string;
    getReportFileType: (report: ReportSummary) => ReportFileType | null;
    getReportDateRange?: (report: ReportSummary) => ReportDateRange | null;
  };
  alternateJobMode?: ReportJobMode;
};

const MAX_SAVED_JOBS = 25;
const DATE_TIME_TIMEZONE_PATTERN = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::\d{2})?(?:\s+(.+))?$/;

function resolveDefaultValue(field: TextField | DateTimeTimezoneField | NumberField) {
  if (!("defaultValue" in field)) return "";
  return field.defaultValue ?? "";
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

function formatOptionalDate(value?: string | null) {
  return value ? formatDate(value) : "Date unavailable";
}

function getJobId(data: Record<string, unknown>) {
  const value = data.job_id ?? data.id;
  return value === undefined || value === null ? "" : String(value);
}

function getStatus(data: Record<string, unknown>) {
  const value = data.status ?? data.state;
  return value === undefined || value === null ? "" : String(value);
}

function statusVariant(status: string): "default" | "success" | "warning" | "danger" | "info" {
  const value = status.toLowerCase();
  if (["completed", "complete", "succeeded", "success", "done"].includes(value)) return "success";
  if (["failed", "error", "cancelled", "canceled"].includes(value)) return "danger";
  if (["running", "queued", "pending", "started"].includes(value)) return "warning";
  return "info";
}

function loadSavedJobs(storageKey: string): SavedJob[] {
  if (typeof window === "undefined") return [];
  try {
    const value = window.localStorage.getItem(storageKey);
    const parsed = value ? JSON.parse(value) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function persistSavedJobs(storageKey: string, jobs: SavedJob[]) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(storageKey, JSON.stringify(jobs.slice(0, MAX_SAVED_JOBS)));
}

function getAggregateCode(row: OptionCountAggregate) {
  return String(row.ASXCode ?? row.asx_code ?? "").trim().toUpperCase();
}

function getAggregateRecords(row: OptionCountAggregate) {
  return Number(row.NumRecords ?? row.num_records ?? 0);
}

function getAggregateOptions(row: OptionCountAggregate) {
  return Number(row.NumOptions ?? row.num_options ?? 0);
}

function getAggregateInMarketFlow(row: OptionCountAggregate) {
  return Boolean(row.in_market_flow ?? row.InMarketFlow ?? false);
}

function isNumberField(field: TextField | DateTimeTimezoneField | NumberField): field is NumberField {
  return typeof field.defaultValue === "number";
}

function isDateTimeTimezoneField(field: TextField | DateTimeTimezoneField | NumberField): field is DateTimeTimezoneField {
  return "inputType" in field && field.inputType === "datetime-timezone";
}

function splitDateTimeTimezone(value: string | number, fallbackTimezone: string) {
  const rawValue = String(value || "").trim();
  const match = rawValue.match(DATE_TIME_TIMEZONE_PATTERN);
  if (!match) return { dateTime: rawValue.replace(" ", "T"), timezone: fallbackTimezone };
  return { dateTime: `${match[1]}T${match[2]}`, timezone: (match[3] || fallbackTimezone).trim() };
}

function combineDateTimeTimezone(dateTime: string, timezone: string) {
  if (!dateTime.trim()) return "";
  return `${dateTime.replace("T", " ")} ${timezone}`.trim();
}

export default function SkillReportPage({
  title,
  subtitle,
  reportsEndpoint,
  jobsEndpoint,
  storageKey,
  submitLabel,
  emptyLabel,
  fields,
  makeJobLabel,
  buildReportPrompt,
  reportPromptLabel = "Get Prompt",
  copyPromptLabel = "Copy Prompt",
  getReportDate,
  optionCountsEndpoint,
  optionCountsTitle = "Option Counts by Stock Code",
  optionCountsObservationDateField = "observation_date",
  optionCountsDateRangeFields,
  canDeleteReports = false,
  initialTab = "viewer",
  htmlReports,
  alternateJobMode,
}: Props) {
  const baseUrl = (process.env.NEXT_PUBLIC_BACKEND_URL || "");
  const initialValues = useMemo(() => {
    const values: Record<string, string | number> = {};
    fields.forEach((field) => {
      values[field.name] = resolveDefaultValue(field);
    });
    return values;
  }, [fields]);

  const [activeTab, setActiveTab] = useState<"viewer" | "html" | "runner">(initialTab);
  const [activeJobModeKey, setActiveJobModeKey] = useState("default");
  const [values, setValues] = useState<Record<string, string | number>>(initialValues);
  const [items, setItems] = useState<ReportSummary[]>([]);
  const [selectedJobId, setSelectedJobId] = useState("");
  const selectedJobIdRef = useRef("");
  const [detail, setDetail] = useState<ReportDetail | null>(null);
  const [loadingList, setLoadingList] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [viewerError, setViewerError] = useState("");
  const [deletingJobId, setDeletingJobId] = useState("");
  const [search, setSearch] = useState("");
  const [selectedReportDate, setSelectedReportDate] = useState("");
  const [sortHtmlByRangeStartDate, setSortHtmlByRangeStartDate] = useState(false);
  const [sortHtmlRangeStartDateDescending, setSortHtmlRangeStartDateDescending] = useState(true);
  const [showOnlyOneDayHtmlReports, setShowOnlyOneDayHtmlReports] = useState(false);
  const [reportPrompt, setReportPrompt] = useState("");
  const [reportPromptCopied, setReportPromptCopied] = useState(false);
  const [reportPromptError, setReportPromptError] = useState("");
  const [htmlPreviewUrl, setHtmlPreviewUrl] = useState("");

  const [jobId, setJobId] = useState("");
  const [jobResponse, setJobResponse] = useState<Record<string, unknown> | null>(null);
  const [jobStatus, setJobStatus] = useState<Record<string, unknown> | null>(null);
  const [jobError, setJobError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [checking, setChecking] = useState(false);
  const [savedJobs, setSavedJobs] = useState<SavedJob[]>([]);
  const [aggregates, setAggregates] = useState<OptionCountAggregatesResponse | null>(null);
  const [loadingAggregates, setLoadingAggregates] = useState(false);
  const [aggregatesError, setAggregatesError] = useState("");
  const activeJobMode = alternateJobMode && activeJobModeKey === alternateJobMode.key ? alternateJobMode : null;
  const activeFields = activeJobMode?.fields || fields;
  const activeJobsEndpoint = activeJobMode?.jobsEndpoint || jobsEndpoint;
  const activeSubmitLabel = activeJobMode?.submitLabel || submitLabel;
  const activeMakeJobLabel = activeJobMode?.makeJobLabel || makeJobLabel;
  const optionCountsObservationDate = activeJobMode
    ? ""
    : String(values[optionCountsObservationDateField] || "").trim();
  const optionCountsRangeStartField = optionCountsDateRangeFields?.startDateField || "";
  const optionCountsRangeEndField = optionCountsDateRangeFields?.endDateField || "";
  const optionCountsRangeStartDate = activeJobMode && optionCountsRangeStartField
    ? String(values[optionCountsRangeStartField] || "").trim()
    : "";
  const optionCountsRangeEndDate = activeJobMode && optionCountsRangeEndField
    ? String(values[optionCountsRangeEndField] || "").trim()
    : "";

  const getReportFileType = useCallback(
    (report: ReportSummary): ReportFileType => htmlReports?.getReportFileType(report) || "markdown",
    [htmlReports]
  );

  const getReportsForTab = useCallback(
    (reportItems: ReportSummary[], tab: "viewer" | "html") => {
      const reportType = tab === "html" ? "html" : "markdown";
      return htmlReports
        ? reportItems.filter((item) => getReportFileType(item) === reportType)
        : reportItems;
    },
    [getReportFileType, htmlReports]
  );

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    const reportItems = activeTab === "runner" ? [] : getReportsForTab(items, activeTab);
    const visibleItems = reportItems.filter((item) => {
      if (selectedReportDate && getReportDate?.(item) !== selectedReportDate) return false;
      if (!query) return true;
      return `${item.title} ${item.job_id} ${item.stock_code || ""} ${item.status || ""}`.toLowerCase().includes(query);
    });

    if (activeTab !== "html" || !htmlReports?.getReportDateRange) return visibleItems;

    const getDateRange = htmlReports.getReportDateRange;
    const rangeFilteredItems = showOnlyOneDayHtmlReports
      ? visibleItems.filter((item) => {
          const range = getDateRange(item);
          return range ? range.startDate === range.endDate : false;
        })
      : visibleItems;

    if (!sortHtmlByRangeStartDate) return rangeFilteredItems;

    return [...rangeFilteredItems].sort((left, right) => {
      const leftStartDate = getDateRange(left)?.startDate || "";
      const rightStartDate = getDateRange(right)?.startDate || "";
      if (!leftStartDate && !rightStartDate) return 0;
      if (!leftStartDate) return 1;
      if (!rightStartDate) return -1;
      return sortHtmlRangeStartDateDescending
        ? rightStartDate.localeCompare(leftStartDate)
        : leftStartDate.localeCompare(rightStartDate);
    });
  }, [
    activeTab,
    getReportDate,
    getReportsForTab,
    htmlReports,
    items,
    search,
    selectedReportDate,
    sortHtmlRangeStartDateDescending,
    showOnlyOneDayHtmlReports,
    sortHtmlByRangeStartDate,
  ]);

  const reportDateCards = useMemo(() => {
    if (activeTab !== "viewer" || !getReportDate) return [];
    const counts = new Map<string, number>();
    getReportsForTab(items, "viewer").forEach((item) => {
      const reportDate = getReportDate(item);
      if (!reportDate) return;
      counts.set(reportDate, (counts.get(reportDate) || 0) + 1);
    });
    return Array.from(counts.entries())
      .map(([date, count]) => ({ date, count }))
      .sort((left, right) => right.date.localeCompare(left.date))
      .slice(0, 9);
  }, [activeTab, getReportDate, getReportsForTab, items]);

  const optionCountRows = useMemo<OptionCountRow[]>(() => {
    if (!aggregates) return [];

    const rowsByCode = new Map<string, OptionCountRow>();
    const getOrCreateRow = (code: string) => {
      const existing = rowsByCode.get(code);
      if (existing) return existing;
      const row = { code, tradeRecords: 0, tradeOptions: 0, bidAskRecords: 0, bidAskOptions: 0, inMarketFlow: false };
      rowsByCode.set(code, row);
      return row;
    };

    (aggregates.trades || []).forEach((item) => {
      const code = getAggregateCode(item);
      if (!code) return;
      const row = getOrCreateRow(code);
      row.tradeRecords = getAggregateRecords(item);
      row.tradeOptions = getAggregateOptions(item);
      row.inMarketFlow = row.inMarketFlow || getAggregateInMarketFlow(item);
    });

    (aggregates.bidask || []).forEach((item) => {
      const code = getAggregateCode(item);
      if (!code) return;
      const row = getOrCreateRow(code);
      row.bidAskRecords = getAggregateRecords(item);
      row.bidAskOptions = getAggregateOptions(item);
      row.inMarketFlow = row.inMarketFlow || getAggregateInMarketFlow(item);
    });

    return Array.from(rowsByCode.values()).sort((left, right) => left.code.localeCompare(right.code));
  }, [aggregates]);

  const saveJob = useCallback(
    (job: SavedJob) => {
      setSavedJobs((current) => {
        const next = [job, ...current.filter((item) => item.job_id !== job.job_id)].slice(0, MAX_SAVED_JOBS);
        persistSavedJobs(storageKey, next);
        return next;
      });
    },
    [storageKey]
  );

  const loadDetail = useCallback(
    async (jobIdToLoad: string) => {
      if (!jobIdToLoad) return;
      setLoadingDetail(true);
      setViewerError("");
      try {
        const res = await authenticatedFetch(`${baseUrl}${reportsEndpoint}/${encodeURIComponent(jobIdToLoad)}`);
        const payload = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
        setDetail(payload as ReportDetail);
        selectedJobIdRef.current = (payload as ReportDetail).job_id;
        setSelectedJobId((payload as ReportDetail).job_id);
        setReportPrompt("");
        setReportPromptCopied(false);
        setReportPromptError("");
      } catch (e: unknown) {
        setDetail(null);
        setReportPrompt("");
        setReportPromptCopied(false);
        setReportPromptError("");
        setViewerError(e instanceof Error ? e.message : "Failed to load report");
      } finally {
        setLoadingDetail(false);
      }
    },
    [baseUrl, reportsEndpoint]
  );

  useEffect(() => {
    if (activeTab !== "html" || !detail) {
      setHtmlPreviewUrl("");
      return;
    }

    const url = URL.createObjectURL(new Blob([detail.content], { type: "text/html" }));
    setHtmlPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [activeTab, detail]);

  const loadReports = useCallback(async () => {
    setLoadingList(true);
    setViewerError("");
    try {
      const res = await authenticatedFetch(`${baseUrl}${reportsEndpoint}`);
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
      const nextItems = ((payload as ReportPageResponse).items || []);
      setItems(nextItems);
      const reportTab = activeTab === "html" ? "html" : "viewer";
      const visibleItems = getReportsForTab(nextItems, reportTab);
      const stillSelected = visibleItems.some((item) => item.job_id === selectedJobIdRef.current);
      const jobIdToLoad = stillSelected ? selectedJobIdRef.current : visibleItems[0]?.job_id || "";
      if (jobIdToLoad) await loadDetail(jobIdToLoad);
      else {
        selectedJobIdRef.current = "";
        setSelectedJobId("");
        setDetail(null);
      }
    } catch (e: unknown) {
      setViewerError(e instanceof Error ? e.message : "Failed to load reports");
    } finally {
      setLoadingList(false);
    }
  }, [activeTab, baseUrl, getReportsForTab, loadDetail, reportsEndpoint]);

  const selectReportDate = useCallback(
    (reportDate: string) => {
      setSelectedReportDate(reportDate);
      setSearch("");
      if (!reportDate) return;
      const firstMatch = getReportsForTab(items, "viewer").find((item) => getReportDate?.(item) === reportDate);
      if (firstMatch) {
        void loadDetail(firstMatch.job_id);
      }
    },
    [getReportDate, getReportsForTab, items, loadDetail]
  );

  const prepareReportPrompt = useCallback(() => {
    if (!detail || !buildReportPrompt) return;
    try {
      const prompt = buildReportPrompt(detail);
      setReportPrompt(prompt);
      setReportPromptCopied(false);
      setReportPromptError("");
    } catch (e: unknown) {
      setReportPrompt("");
      setReportPromptCopied(false);
      setReportPromptError(e instanceof Error ? e.message : "Failed to build prompt");
    }
  }, [buildReportPrompt, detail]);

  const copyReportPrompt = useCallback(() => {
    if (!reportPrompt) return;
    try {
      const textarea = document.createElement("textarea");
      textarea.value = reportPrompt;
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      textarea.style.top = "0";
      textarea.setAttribute("readonly", "readonly");
      document.body.appendChild(textarea);
      textarea.select();
      textarea.setSelectionRange(0, textarea.value.length);
      const copied = document.execCommand("copy");
      document.body.removeChild(textarea);

      if (!copied) {
        throw new Error("Copy command was not accepted");
      }

      setReportPromptCopied(true);
      setReportPromptError("");
      setTimeout(() => setReportPromptCopied(false), 2500);
    } catch {
      setReportPromptCopied(false);
      setReportPromptError("Failed to copy. Please select and copy manually.");
    }
  }, [reportPrompt]);

  const deleteReport = useCallback(
    async (report: ReportDetail) => {
      if (!canDeleteReports) return;
      const confirmed = window.confirm(`Delete "${report.title}"?\n\nThis will remove report job ${report.job_id}.`);
      if (!confirmed) return;

      setDeletingJobId(report.job_id);
      setViewerError("");
      try {
        const res = await authenticatedFetch(`${baseUrl}${reportsEndpoint}/${encodeURIComponent(report.job_id)}`, {
          method: "DELETE",
        });
        const payload = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);

        setItems((current) => current.filter((item) => item.job_id !== report.job_id));
        if (selectedJobId === report.job_id) {
          selectedJobIdRef.current = "";
          setSelectedJobId("");
          setDetail(null);
          setReportPrompt("");
          setReportPromptCopied(false);
          setReportPromptError("");
        }
        await loadReports();
      } catch (e: unknown) {
        setViewerError(e instanceof Error ? e.message : "Failed to delete report");
      } finally {
        setDeletingJobId("");
      }
    },
    [baseUrl, canDeleteReports, loadReports, reportsEndpoint, selectedJobId]
  );

  const submitJob = useCallback(async () => {
    const missing = activeFields.find((field) => "required" in field && field.required && !String(values[field.name] || "").trim());
    if (missing) {
      setJobError(`${missing.label} is required.`);
      return;
    }

    setSubmitting(true);
    setJobError("");
    setJobResponse(null);
    setJobStatus(null);
    try {
      const requestValues = Object.fromEntries(
        Object.entries(values).filter(([name, value]) => {
          const field = activeFields.find((item) => item.name === name);
          const omitWhenBlank = !!field && "omitWhenBlank" in field && field.omitWhenBlank;
          return !(omitWhenBlank && !String(value || "").trim());
        })
      );
      const res = await authenticatedFetch(`${baseUrl}${activeJobsEndpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestValues),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
      const data = (payload as ProxyResponse).data || {};
      setJobResponse(data);
      const returnedJobId = getJobId(data);
      if (returnedJobId) {
        setJobId(returnedJobId);
        saveJob({
          job_id: returnedJobId,
          label: activeMakeJobLabel(values),
          submitted_at: new Date().toISOString(),
          status: getStatus(data) || "submitted",
        });
      }
    } catch (e: unknown) {
      setJobError(e instanceof Error ? e.message : "Failed to submit job");
    } finally {
      setSubmitting(false);
    }
  }, [activeFields, activeJobsEndpoint, activeMakeJobLabel, baseUrl, saveJob, values]);

  const checkStatusFor = useCallback(
    async (jobIdToCheck: string) => {
      const currentJobId = jobIdToCheck.trim();
      if (!currentJobId) {
        setJobError("Enter or submit a job id first.");
        return;
      }
      setChecking(true);
      setJobError("");
      try {
        const res = await authenticatedFetch(`${baseUrl}${activeJobsEndpoint}/${encodeURIComponent(currentJobId)}`);
        const payload = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
        const data = (payload as ProxyResponse).data || {};
        setJobStatus(data);
        setJobId(currentJobId);
        const existing = savedJobs.find((item) => item.job_id === currentJobId);
        saveJob({
          job_id: currentJobId,
          label: existing?.label || currentJobId,
          submitted_at: existing?.submitted_at || new Date().toISOString(),
          status: getStatus(data) || existing?.status,
          last_checked_at: new Date().toISOString(),
        });
      } catch (e: unknown) {
        setJobError(e instanceof Error ? e.message : "Failed to check job status");
      } finally {
        setChecking(false);
      }
    },
    [activeJobsEndpoint, baseUrl, saveJob, savedJobs]
  );

  useEffect(() => {
    setValues(() => {
      const nextValues: Record<string, string | number> = {};
      activeFields.forEach((field) => {
        nextValues[field.name] = resolveDefaultValue(field);
        if (isDateTimeTimezoneField(field) && field.clientDefaultValue) {
          nextValues[field.name] = field.clientDefaultValue();
        }
      });
      return nextValues;
    });
    setJobError("");
    setJobResponse(null);
    setJobStatus(null);
  }, [activeFields, activeJobModeKey]);

  useEffect(() => {
    setSavedJobs(loadSavedJobs(storageKey));
  }, [storageKey]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  useEffect(() => {
    const hasObservationDate = !activeJobMode && Boolean(optionCountsObservationDate);
    const hasDateRange = Boolean(activeJobMode && optionCountsRangeStartDate && optionCountsRangeEndDate);
    if (activeTab !== "runner" || !optionCountsEndpoint || (!hasObservationDate && !hasDateRange)) {
      setAggregates(null);
      setAggregatesError("");
      return;
    }

    let cancelled = false;
    const load = async () => {
      setLoadingAggregates(true);
      setAggregatesError("");
      try {
        const params = new URLSearchParams();
        if (hasDateRange) {
          params.set("start_date", optionCountsRangeStartDate);
          params.set("end_date", optionCountsRangeEndDate);
        } else {
          params.set("observation_date", optionCountsObservationDate);
        }
        const res = await authenticatedFetch(`${baseUrl}${optionCountsEndpoint}?${params.toString()}`);
        const payload = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
        if (!cancelled) setAggregates(payload as OptionCountAggregatesResponse);
      } catch (e: unknown) {
        if (!cancelled) setAggregatesError(e instanceof Error ? e.message : "Failed to load aggregates");
      } finally {
        if (!cancelled) setLoadingAggregates(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [
    activeJobMode,
    activeTab,
    baseUrl,
    optionCountsEndpoint,
    optionCountsObservationDate,
    optionCountsRangeEndDate,
    optionCountsRangeStartDate,
  ]);

  const visibleJobStatus = jobStatus ? getStatus(jobStatus) : jobResponse ? getStatus(jobResponse) : "";
  const optionCountsPanelEnabled = Boolean(optionCountsEndpoint && (!activeJobMode || optionCountsDateRangeFields));
  const optionCountsDateLabel = activeJobMode
    ? `${optionCountsRangeStartDate || "start date"} to ${optionCountsRangeEndDate || "end date"}`
    : optionCountsObservationDate || "the selected observation date";

  return (
    <div className="space-y-6">
      <PageHeader
        title={title}
        subtitle={subtitle}
        actions={<Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={loadingList}>{loadingList ? "Refreshing..." : "Refresh Reports"}</Button>}
      />

      <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        {(["viewer", ...(htmlReports ? ["html" as const] : []), "runner"] as const).map((key) => (
          <button
            key={key}
            type="button"
            onClick={() => {
              setActiveTab(key);
              if (key !== "viewer") setSelectedReportDate("");
            }}
            className={[
              "rounded-md px-4 py-2 text-sm font-medium transition-colors",
              activeTab === key ? "bg-indigo-600 text-white shadow-sm" : "text-slate-600 hover:bg-slate-50 hover:text-slate-900",
            ].join(" ")}
          >
            {key === "viewer" ? "Viewer" : key === "html" ? (htmlReports?.label || "HTML Reports") : "Run Job"}
          </button>
        ))}
      </div>

      {activeTab === "viewer" || activeTab === "html" ? (
        <div className="space-y-4">
          {viewerError ? <Alert variant="danger">{viewerError}</Alert> : null}
          {activeTab === "viewer" && reportDateCards.length > 0 ? (
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-6">
              <button
                type="button"
                onClick={() => selectReportDate("")}
                className={[
                  "rounded-lg border p-3 text-left shadow-sm transition-colors",
                  selectedReportDate === ""
                    ? "border-indigo-500 bg-indigo-50 text-indigo-900"
                    : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50",
                ].join(" ")}
              >
                <span className="block text-sm font-semibold">All dates</span>
                <span className="mt-1 block text-xs text-slate-500">{items.length.toLocaleString()} reports</span>
              </button>
              {reportDateCards.map((card) => (
                <button
                  key={card.date}
                  type="button"
                  onClick={() => selectReportDate(card.date)}
                  className={[
                    "rounded-lg border p-3 text-left shadow-sm transition-colors",
                    selectedReportDate === card.date
                      ? "border-indigo-500 bg-indigo-50 text-indigo-900"
                      : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50",
                  ].join(" ")}
                >
                  <span className="block text-sm font-semibold">{card.date}</span>
                  <span className="mt-1 block text-xs text-slate-500">{card.count.toLocaleString()} reports</span>
                </button>
              ))}
            </div>
          ) : null}
          {activeTab === "html" && htmlReports?.getReportDateRange ? (
            <div className="flex flex-wrap items-center gap-x-6 gap-y-3 rounded-lg border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <label className="inline-flex cursor-pointer items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={sortHtmlByRangeStartDate}
                  onChange={(event) => setSortHtmlByRangeStartDate(event.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                />
                <span>Order by range start date</span>
              </label>
              <label className="inline-flex cursor-pointer items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={sortHtmlRangeStartDateDescending}
                  onChange={(event) => setSortHtmlRangeStartDateDescending(event.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                />
                <span>Range start date descending</span>
              </label>
              <label className="inline-flex cursor-pointer items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={showOnlyOneDayHtmlReports}
                  onChange={(event) => setShowOnlyOneDayHtmlReports(event.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                />
                <span>Show only one-day range reports</span>
              </label>
            </div>
          ) : null}
          <div className="grid gap-6 lg:grid-cols-[320px_minmax(0,1fr)]">
            <aside className="rounded-lg border border-slate-200 bg-white">
              <div className="border-b border-slate-200 p-4">
                <label className="mb-1 block text-xs font-medium text-slate-600">Search reports</label>
                <Input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Title, stock, status or job id" />
              </div>
              <div className="max-h-[calc(100vh-285px)] min-h-72 overflow-y-auto p-2">
                {loadingList && items.length === 0 ? (
                  <div className="px-3 py-8 text-center text-sm text-slate-500">Loading reports...</div>
                ) : filteredItems.length === 0 ? (
                  <div className="px-3 py-8 text-center text-sm text-slate-500">{emptyLabel}</div>
                ) : (
                  <div className="space-y-1">
                    {filteredItems.map((item) => (
                      <button
                        key={item.job_id}
                        type="button"
                        onClick={() => void loadDetail(item.job_id)}
                        className={[
                          "w-full rounded-md px-3 py-3 text-left text-sm transition-colors",
                          item.job_id === selectedJobId ? "bg-indigo-50 text-indigo-800" : "text-slate-700 hover:bg-slate-50 hover:text-slate-900",
                        ].join(" ")}
                      >
                        <span className="block font-medium">{item.title}</span>
                        <span className="mt-1 block text-xs text-slate-500">{formatOptionalDate(item.created_at)}</span>
                        <span className="mt-2 flex flex-wrap items-center gap-2 text-xs text-slate-400">
                          {item.stock_code ? <span>{item.stock_code}</span> : null}
                          <span>Job {item.job_id}</span>
                          {item.status ? <Badge variant={statusVariant(item.status)}>{item.status}</Badge> : null}
                        </span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </aside>

            <section className="min-w-0 rounded-lg border border-slate-200 bg-white">
              <div className="border-b border-slate-200 bg-slate-50 px-5 py-4">
                {detail ? (
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                      <h2 className="truncate text-lg font-semibold text-slate-900">{detail.title}</h2>
                      <div className="mt-1 text-xs text-slate-500">
                        {formatOptionalDate(detail.created_at)} | Job {detail.job_id}
                        {detail.stock_code ? ` | ${detail.stock_code}` : ""}
                      </div>
                    </div>
                    <div className="flex shrink-0 flex-wrap gap-2">
                      {activeTab === "viewer" && buildReportPrompt ? (
                        <>
                          <Button type="button" variant="secondary" size="sm" onClick={prepareReportPrompt}>
                            {reportPromptLabel}
                          </Button>
                          {reportPrompt ? (
                            <Button type="button" size="sm" onClick={copyReportPrompt}>
                              {copyPromptLabel}
                            </Button>
                          ) : null}
                        </>
                      ) : null}
                      {activeTab === "html" && htmlPreviewUrl ? (
                        <a
                          href={htmlPreviewUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center justify-center rounded-md border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50"
                        >
                          Open full HTML in new tab
                        </a>
                      ) : null}
                      <Button type="button" variant="secondary" size="sm" onClick={() => void loadDetail(detail.job_id)} disabled={loadingDetail}>
                        {loadingDetail ? "Loading..." : "Reload"}
                      </Button>
                      {canDeleteReports ? (
                        <Button
                          type="button"
                          variant="danger"
                          size="sm"
                          onClick={() => void deleteReport(detail)}
                          disabled={deletingJobId === detail.job_id || loadingDetail}
                        >
                          {deletingJobId === detail.job_id ? "Deleting..." : "Delete"}
                        </Button>
                      ) : null}
                    </div>
                  </div>
                ) : (
                  <h2 className="text-lg font-semibold text-slate-900">Report Preview</h2>
                )}
              </div>
              {(reportPromptCopied || reportPromptError) && (
                <div className="border-b border-slate-200 px-5 py-3">
                  {reportPromptCopied ? (
                    <div className="text-sm text-emerald-600">
                      Prompt copied. About {Math.ceil(reportPrompt.length / 4).toLocaleString()} tokens.
                    </div>
                  ) : null}
                  {reportPromptError ? (
                    <div className="text-sm text-red-600">Error: {reportPromptError}</div>
                  ) : null}
                </div>
              )}
              <div className="min-h-[520px] p-5">
                {loadingDetail && !detail ? (
                  <div className="flex min-h-[420px] items-center justify-center text-sm text-slate-500">Loading report...</div>
                ) : detail ? (
                  activeTab === "html" ? (
                    <iframe
                      title={detail.title}
                      srcDoc={detail.content}
                      sandbox="allow-forms allow-modals allow-popups allow-scripts"
                      className="h-[60vh] min-h-[420px] w-full rounded-md border border-slate-200 bg-white sm:h-[calc(100vh-300px)] sm:min-h-[620px]"
                    />
                  ) : (
                    <MarkdownRenderer content={detail.content} />
                  )
                ) : (
                  <div className="flex min-h-[420px] items-center justify-center text-sm text-slate-500">Select a report to view it.</div>
                )}
              </div>
            </section>
          </div>
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,420px)_minmax(0,1fr)]">
          <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
            <div className="space-y-4">
              {alternateJobMode ? (
                <div className="inline-flex rounded-lg border border-slate-200 bg-slate-50 p-1">
                  <button
                    type="button"
                    onClick={() => setActiveJobModeKey("default")}
                    className={["rounded-md px-3 py-2 text-sm font-medium", !activeJobMode ? "bg-white text-indigo-700 shadow-sm" : "text-slate-600 hover:text-slate-900"].join(" ")}
                  >
                    Single-date Markdown
                  </button>
                  <button
                    type="button"
                    onClick={() => setActiveJobModeKey(alternateJobMode.key)}
                    className={["rounded-md px-3 py-2 text-sm font-medium", activeJobMode ? "bg-white text-indigo-700 shadow-sm" : "text-slate-600 hover:text-slate-900"].join(" ")}
                  >
                    {alternateJobMode.label}
                  </button>
                </div>
              ) : null}

              {activeFields.map((field) => (
                <div key={field.name}>
                  <label className="mb-1 block text-sm font-medium text-slate-700">{field.label}</label>
                  {isDateTimeTimezoneField(field) ? (
                    <div className="grid gap-2 sm:grid-cols-[minmax(0,1fr)_160px]">
                      <Input
                        type="datetime-local"
                        value={splitDateTimeTimezone(values[field.name], field.defaultTimezone).dateTime}
                        onChange={(event) =>
                          setValues((current) => {
                            const currentParts = splitDateTimeTimezone(current[field.name], field.defaultTimezone);
                            return {
                              ...current,
                              [field.name]: combineDateTimeTimezone(event.target.value, currentParts.timezone),
                            };
                          })
                        }
                      />
                      <Select
                        value={splitDateTimeTimezone(values[field.name], field.defaultTimezone).timezone}
                        onChange={(event) =>
                          setValues((current) => {
                            const currentParts = splitDateTimeTimezone(current[field.name], field.defaultTimezone);
                            return {
                              ...current,
                              [field.name]: combineDateTimeTimezone(currentParts.dateTime, event.target.value),
                            };
                          })
                        }
                      >
                        {field.timezones.map((timezone) => (
                          <option key={timezone.value} value={timezone.value}>
                            {timezone.label}
                          </option>
                        ))}
                      </Select>
                    </div>
                  ) : "multiline" in field && field.multiline ? (
                    <textarea
                      value={String(values[field.name] || "")}
                      onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))}
                      placeholder={field.placeholder}
                      rows={10}
                      className="w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    />
                  ) : (
                    <Input
                      type={isNumberField(field) ? "number" : field.inputType || "text"}
                      min={isNumberField(field) ? field.min : undefined}
                      max={isNumberField(field) ? field.max : undefined}
                      value={values[field.name]}
                      onChange={(event) =>
                        setValues((current) => ({
                          ...current,
                          [field.name]: isNumberField(field) ? Number(event.target.value) : event.target.value,
                        }))
                      }
                      placeholder={"placeholder" in field ? field.placeholder : undefined}
                    />
                  )}
                </div>
              ))}

              <Button type="button" onClick={() => void submitJob()} disabled={submitting}>{submitting ? "Submitting..." : activeSubmitLabel}</Button>

              <div className="border-t border-slate-200 pt-4">
                <label className="mb-1 block text-sm font-medium text-slate-700">Job id</label>
                <div className="flex gap-2">
                  <Input value={jobId} onChange={(event) => setJobId(event.target.value)} placeholder="Returned after submit" />
                  <Button type="button" variant="secondary" onClick={() => void checkStatusFor(jobId)} disabled={checking || !jobId.trim()} className="shrink-0">
                    {checking ? "Checking..." : "Check Job Status"}
                  </Button>
                </div>
              </div>

              {visibleJobStatus ? <div className="flex items-center gap-2 text-sm text-slate-600">Latest status:<Badge variant={statusVariant(visibleJobStatus)}>{visibleJobStatus}</Badge></div> : null}
              {jobError ? <Alert variant="danger">{jobError}</Alert> : null}

              <div className="border-t border-slate-200 pt-4">
                <div className="mb-2 text-sm font-medium text-slate-700">Job History</div>
                {savedJobs.length === 0 ? (
                  <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-4 text-sm text-slate-500">Submitted jobs will be saved here in this browser.</div>
                ) : (
                  <div className="max-h-72 space-y-2 overflow-y-auto">
                    {savedJobs.map((savedJob) => (
                      <div key={savedJob.job_id} className="rounded-md border border-slate-200 p-3">
                        <div className="flex flex-wrap items-start justify-between gap-2">
                          <div className="min-w-0">
                            <div className="font-mono text-xs text-slate-700">{savedJob.job_id}</div>
                            <div className="mt-1 text-xs text-slate-500">{savedJob.label} | submitted {formatDate(savedJob.submitted_at)}</div>
                            {savedJob.last_checked_at ? <div className="mt-1 text-xs text-slate-400">checked {formatDate(savedJob.last_checked_at)}</div> : null}
                          </div>
                          {savedJob.status ? <Badge variant={statusVariant(savedJob.status)}>{savedJob.status}</Badge> : null}
                        </div>
                        <div className="mt-3 flex flex-wrap gap-2">
                          <Button type="button" size="sm" variant="secondary" onClick={() => void checkStatusFor(savedJob.job_id)} disabled={checking}>Check Status</Button>
                          <Button type="button" size="sm" variant="ghost" onClick={() => setJobId(savedJob.job_id)}>Use Job Id</Button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </section>

          {optionCountsPanelEnabled ? (
            <section className="min-w-0 rounded-lg border border-slate-200 bg-white shadow-sm">
              <div className="border-b border-slate-200 bg-slate-50 px-5 py-4">
                <h2 className="text-lg font-semibold text-slate-900">{optionCountsTitle}</h2>
              </div>
              <div className="space-y-4 p-5">
                {loadingAggregates ? (
                  <div className="text-sm text-slate-500">Loading counts...</div>
                ) : aggregatesError ? (
                  <Alert variant="danger">{aggregatesError}</Alert>
                ) : aggregates ? (
                  optionCountRows.length > 0 ? (
                    <div className="max-h-96 overflow-auto">
                      <table className="w-full table-auto text-sm">
                        <thead className="sticky top-0 bg-white">
                          <tr className="border-b border-slate-200 text-left text-xs font-semibold text-slate-500">
                            <th className="px-2 py-2">Stock Code</th>
                            <th className="px-2 py-2 text-center">In Market Flow</th>
                            <th className="px-2 py-2 text-right">Trade Records</th>
                            <th className="px-2 py-2 text-right">Trade Options</th>
                            <th className="px-2 py-2 text-right">Bid/Ask Records</th>
                            <th className="px-2 py-2 text-right">Bid/Ask Options</th>
                          </tr>
                        </thead>
                        <tbody>
                          {optionCountRows.map((row) => (
                            <tr key={row.code} className="border-t border-slate-100">
                              <td className="px-2 py-2 font-medium text-slate-700">{row.code}</td>
                              <td className="px-2 py-2 text-center">
                                <span
                                  className={[
                                    "inline-flex rounded-full px-2 py-0.5 text-xs font-semibold",
                                    row.inMarketFlow ? "bg-emerald-100 text-emerald-700" : "bg-red-100 text-red-700",
                                  ].join(" ")}
                                >
                                  {row.inMarketFlow ? "true" : "false"}
                                </span>
                              </td>
                              <td className="px-2 py-2 text-right text-slate-600">{row.tradeRecords.toLocaleString()}</td>
                              <td className="px-2 py-2 text-right text-slate-600">{row.tradeOptions.toLocaleString()}</td>
                              <td className="px-2 py-2 text-right text-slate-600">{row.bidAskRecords.toLocaleString()}</td>
                              <td className="px-2 py-2 text-right text-slate-600">{row.bidAskOptions.toLocaleString()}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  ) : (
                    <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-4 text-sm text-slate-500">
                      No option counts found for {optionCountsDateLabel}.
                    </div>
                  )
                ) : (
                  <div className="text-sm text-slate-500">
                    {activeJobMode ? "Choose a start and end date to load counts." : "Choose an observation date to load counts."}
                  </div>
                )}
              </div>
            </section>
          ) : null}

          <section className="min-w-0 rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="border-b border-slate-200 bg-slate-50 px-5 py-4"><h2 className="text-lg font-semibold text-slate-900">Job Response</h2></div>
            <div className="space-y-4 p-5">
              <div>
                <div className="mb-2 text-sm font-medium text-slate-700">Submit response</div>
                <pre className="max-h-72 overflow-auto rounded-md bg-slate-950 p-4 text-xs text-slate-100">{jobResponse ? JSON.stringify(jobResponse, null, 2) : "Submit a job to see the response."}</pre>
              </div>
              <div>
                <div className="mb-2 text-sm font-medium text-slate-700">Status response</div>
                <pre className="max-h-96 overflow-auto rounded-md bg-slate-950 p-4 text-xs text-slate-100">{jobStatus ? JSON.stringify(jobStatus, null, 2) : "Check job status to see the latest result."}</pre>
              </div>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
