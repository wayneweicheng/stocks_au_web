"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Alert from "./ui/Alert";
import Badge from "./ui/Badge";
import Button from "./ui/Button";
import Input from "./ui/Input";
import MarkdownRenderer from "./MarkdownRenderer";
import PageHeader from "./PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type ReportSummary = {
  job_id: string;
  title: string;
  created_at?: string | null;
  stock_code?: string | null;
  status?: string | null;
};

type ReportDetail = ReportSummary & { content: string };
type ReportPageResponse = { items: ReportSummary[] };
type ProxyResponse = { data: Record<string, unknown> };

type SavedJob = {
  job_id: string;
  label: string;
  submitted_at: string;
  status?: string;
  last_checked_at?: string;
};

type TextField = {
  name: string;
  label: string;
  placeholder?: string;
  multiline?: boolean;
  defaultValue?: string;
  required?: boolean;
};

type NumberField = {
  name: string;
  label: string;
  defaultValue: number;
  min?: number;
  max?: number;
};

type Props = {
  title: string;
  subtitle: string;
  reportsEndpoint: string;
  jobsEndpoint: string;
  storageKey: string;
  submitLabel: string;
  emptyLabel: string;
  fields: Array<TextField | NumberField>;
  makeJobLabel: (values: Record<string, string | number>) => string;
};

const MAX_SAVED_JOBS = 25;

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
}: Props) {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const initialValues = useMemo(() => {
    const values: Record<string, string | number> = {};
    fields.forEach((field) => {
      values[field.name] = "defaultValue" in field ? field.defaultValue : "";
    });
    return values;
  }, [fields]);

  const [activeTab, setActiveTab] = useState<"viewer" | "runner">("viewer");
  const [values, setValues] = useState<Record<string, string | number>>(initialValues);
  const [items, setItems] = useState<ReportSummary[]>([]);
  const [selectedJobId, setSelectedJobId] = useState("");
  const [detail, setDetail] = useState<ReportDetail | null>(null);
  const [loadingList, setLoadingList] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [viewerError, setViewerError] = useState("");
  const [search, setSearch] = useState("");

  const [jobId, setJobId] = useState("");
  const [jobResponse, setJobResponse] = useState<Record<string, unknown> | null>(null);
  const [jobStatus, setJobStatus] = useState<Record<string, unknown> | null>(null);
  const [jobError, setJobError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [checking, setChecking] = useState(false);
  const [savedJobs, setSavedJobs] = useState<SavedJob[]>([]);

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return items;
    return items.filter((item) =>
      `${item.title} ${item.job_id} ${item.stock_code || ""} ${item.status || ""}`.toLowerCase().includes(query)
    );
  }, [items, search]);

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
      if (!baseUrl || !jobIdToLoad) return;
      setLoadingDetail(true);
      setViewerError("");
      try {
        const res = await authenticatedFetch(`${baseUrl}${reportsEndpoint}/${encodeURIComponent(jobIdToLoad)}`);
        const payload = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
        setDetail(payload as ReportDetail);
        setSelectedJobId((payload as ReportDetail).job_id);
      } catch (e: unknown) {
        setDetail(null);
        setViewerError(e instanceof Error ? e.message : "Failed to load report");
      } finally {
        setLoadingDetail(false);
      }
    },
    [baseUrl, reportsEndpoint]
  );

  const loadReports = useCallback(async () => {
    if (!baseUrl) {
      setViewerError("NEXT_PUBLIC_BACKEND_URL is not configured.");
      return;
    }
    setLoadingList(true);
    setViewerError("");
    try {
      const res = await authenticatedFetch(`${baseUrl}${reportsEndpoint}`);
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(payload.detail || `HTTP ${res.status}`);
      const nextItems = ((payload as ReportPageResponse).items || []);
      setItems(nextItems);
      const stillSelected = nextItems.some((item) => item.job_id === selectedJobId);
      const jobIdToLoad = stillSelected ? selectedJobId : nextItems[0]?.job_id || "";
      if (jobIdToLoad) await loadDetail(jobIdToLoad);
      else {
        setSelectedJobId("");
        setDetail(null);
      }
    } catch (e: unknown) {
      setViewerError(e instanceof Error ? e.message : "Failed to load reports");
    } finally {
      setLoadingList(false);
    }
  }, [baseUrl, loadDetail, reportsEndpoint, selectedJobId]);

  const submitJob = useCallback(async () => {
    if (!baseUrl) {
      setJobError("NEXT_PUBLIC_BACKEND_URL is not configured.");
      return;
    }
    const missing = fields.find((field) => "required" in field && field.required && !String(values[field.name] || "").trim());
    if (missing) {
      setJobError(`${missing.label} is required.`);
      return;
    }

    setSubmitting(true);
    setJobError("");
    setJobResponse(null);
    setJobStatus(null);
    try {
      const res = await authenticatedFetch(`${baseUrl}${jobsEndpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(values),
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
          label: makeJobLabel(values),
          submitted_at: new Date().toISOString(),
          status: getStatus(data) || "submitted",
        });
      }
    } catch (e: unknown) {
      setJobError(e instanceof Error ? e.message : "Failed to submit job");
    } finally {
      setSubmitting(false);
    }
  }, [baseUrl, fields, jobsEndpoint, makeJobLabel, saveJob, values]);

  const checkStatusFor = useCallback(
    async (jobIdToCheck: string) => {
      if (!baseUrl) {
        setJobError("NEXT_PUBLIC_BACKEND_URL is not configured.");
        return;
      }
      const currentJobId = jobIdToCheck.trim();
      if (!currentJobId) {
        setJobError("Enter or submit a job id first.");
        return;
      }
      setChecking(true);
      setJobError("");
      try {
        const res = await authenticatedFetch(`${baseUrl}${jobsEndpoint}/${encodeURIComponent(currentJobId)}`);
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
    [baseUrl, jobsEndpoint, saveJob, savedJobs]
  );

  useEffect(() => {
    setValues(initialValues);
  }, [initialValues]);

  useEffect(() => {
    setSavedJobs(loadSavedJobs(storageKey));
  }, [storageKey]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  const visibleJobStatus = jobStatus ? getStatus(jobStatus) : jobResponse ? getStatus(jobResponse) : "";

  return (
    <div className="space-y-6">
      <PageHeader
        title={title}
        subtitle={subtitle}
        actions={<Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={loadingList}>{loadingList ? "Refreshing..." : "Refresh Reports"}</Button>}
      />

      <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        {(["viewer", "runner"] as const).map((key) => (
          <button
            key={key}
            type="button"
            onClick={() => setActiveTab(key)}
            className={[
              "rounded-md px-4 py-2 text-sm font-medium transition-colors",
              activeTab === key ? "bg-indigo-600 text-white shadow-sm" : "text-slate-600 hover:bg-slate-50 hover:text-slate-900",
            ].join(" ")}
          >
            {key === "viewer" ? "Viewer" : "Run Job"}
          </button>
        ))}
      </div>

      {activeTab === "viewer" ? (
        <div className="space-y-4">
          {viewerError ? <Alert variant="danger">{viewerError}</Alert> : null}
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
                    <Button type="button" variant="secondary" size="sm" onClick={() => void loadDetail(detail.job_id)} disabled={loadingDetail}>
                      {loadingDetail ? "Loading..." : "Reload"}
                    </Button>
                  </div>
                ) : (
                  <h2 className="text-lg font-semibold text-slate-900">Report Preview</h2>
                )}
              </div>
              <div className="min-h-[520px] p-5">
                {loadingDetail && !detail ? (
                  <div className="flex min-h-[420px] items-center justify-center text-sm text-slate-500">Loading report...</div>
                ) : detail ? (
                  <MarkdownRenderer content={detail.content} />
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
              {fields.map((field) => (
                <div key={field.name}>
                  <label className="mb-1 block text-sm font-medium text-slate-700">{field.label}</label>
                  {"multiline" in field && field.multiline ? (
                    <textarea
                      value={String(values[field.name] || "")}
                      onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))}
                      placeholder={field.placeholder}
                      rows={10}
                      className="w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    />
                  ) : (
                    <Input
                      type={"min" in field ? "number" : "text"}
                      min={"min" in field ? field.min : undefined}
                      max={"max" in field ? field.max : undefined}
                      value={values[field.name]}
                      onChange={(event) =>
                        setValues((current) => ({
                          ...current,
                          [field.name]: "min" in field ? Number(event.target.value) : event.target.value,
                        }))
                      }
                      placeholder={"placeholder" in field ? field.placeholder : undefined}
                    />
                  )}
                </div>
              ))}

              <Button type="button" onClick={() => void submitJob()} disabled={submitting}>{submitting ? "Submitting..." : submitLabel}</Button>

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
