"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import MarkdownRenderer from "./MarkdownRenderer";
import {
  DEFAULT_MARKET_FLOW_MODEL,
  SHARED_MARKET_FLOW_MODEL_OPTIONS,
} from "./llmModelOptions";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type StageStatus = "pending" | "running" | "completed" | "failed";
type JobStatus = "queued" | "running" | "completed" | "failed";

type RefreshStage = {
  key: string;
  label: string;
  status: StageStatus;
  started_at?: string | null;
  completed_at?: string | null;
  detail?: string | null;
  output?: string | null;
};

type RefreshJob = {
  job_id: number;
  stock_code: string;
  observation_date: string;
  start_date: string;
  end_date: string;
  requested_by?: string | null;
  status: JobStatus;
  created_at?: string | null;
  started_at?: string | null;
  completed_at?: string | null;
  error_message?: string | null;
  report_available: boolean;
  report_id?: number | null;
  report_model?: string | null;
  report_processed_at?: string | null;
  report_processing_id?: number | null;
  report_processing_status?: string | null;
  stages: RefreshStage[];
};

type RefreshListResponse = {
  items: RefreshJob[];
  total: number;
  observation_date: string;
};

type ReportResponse = {
  report_id: number;
  stock_code: string;
  observation_date?: string | null;
  report_markdown?: string | null;
  model?: string | null;
  processed_at?: string | null;
};

function localIsoDate() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function normalizeInput(value: string) {
  const code = value.trim().toUpperCase();
  return code.endsWith(".AX") ? code.slice(0, -3) : code;
}

function statusClass(status: StageStatus | JobStatus | string) {
  switch (status.toLowerCase()) {
    case "completed":
      return "bg-emerald-100 text-emerald-800 border-emerald-200";
    case "running":
    case "processing":
      return "bg-blue-100 text-blue-800 border-blue-200";
    case "failed":
    case "error":
      return "bg-red-100 text-red-800 border-red-200";
    case "queued":
    case "pending":
      return "bg-amber-100 text-amber-800 border-amber-200";
    default:
      return "bg-slate-100 text-slate-700 border-slate-200";
  }
}

function formatDateTime(value?: string | null) {
  if (!value) {
    return "";
  }
  return new Date(value).toLocaleString();
}

function isActive(job: RefreshJob) {
  return (
    job.status === "queued" ||
    job.status === "running" ||
    job.report_processing_status === "Pending" ||
    job.report_processing_status === "Processing"
  );
}

export default function AsxDataRefreshTab() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const pollingRef = useRef<number | null>(null);
  const [stockCode, setStockCode] = useState("");
  const [observationDate, setObservationDate] = useState(localIsoDate);
  const [model, setModel] = useState(DEFAULT_MARKET_FLOW_MODEL);
  const [jobs, setJobs] = useState<RefreshJob[]>([]);
  const [selectedJobId, setSelectedJobId] = useState<number | null>(null);
  const [selectedJobIds, setSelectedJobIds] = useState<Set<number>>(new Set());
  const [report, setReport] = useState<ReportResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [reportBusy, setReportBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const selectedJob = useMemo(
    () => jobs.find((job) => job.job_id === selectedJobId) || jobs[0] || null,
    [jobs, selectedJobId]
  );

  useEffect(() => {
    void loadJobs(observationDate);
  }, [observationDate]);

  useEffect(() => {
    return () => {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
      }
    };
  }, []);

  useEffect(() => {
    const shouldPoll = jobs.some(isActive);
    if (!shouldPoll) {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
      return;
    }

    pollingRef.current = window.setInterval(() => {
      void loadJobs(observationDate, { silent: true });
    }, 2500);

    return () => {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
    };
  }, [jobs, observationDate]);

  async function loadJobs(dateValue: string, options?: { silent?: boolean }) {
    if (!options?.silent) {
      setLoading(true);
      setError("");
      setMessage("");
    }
    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/asx-data-refresh/jobs?observation_date=${encodeURIComponent(dateValue)}`
      );
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${res.status}`);
      }
      const data: RefreshListResponse = await res.json();
      setJobs(data.items || []);
      setSelectedJobIds((current) => {
        const available = new Set((data.items || []).map((job) => job.job_id));
        return new Set(Array.from(current).filter((jobId) => available.has(jobId)));
      });
      if (data.items?.length && !data.items.some((job) => job.job_id === selectedJobId)) {
        setSelectedJobId(data.items[0].job_id);
      }
      if (!data.items?.length) {
        setSelectedJobId(null);
        setReport(null);
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Failed to load refresh jobs.");
    } finally {
      setLoading(false);
    }
  }

  async function submitRefresh(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setMessage("");
    const normalized = normalizeInput(stockCode);
    if (!normalized) {
      setError("Please enter an ASX code.");
      return;
    }
    setSubmitting(true);
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/asx-data-refresh/jobs`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stock_code: normalized }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${res.status}`);
      }
      const data: RefreshJob = await res.json();
      setObservationDate(data.observation_date);
      setStockCode(normalized);
      setSelectedJobId(data.job_id);
      setReport(null);
      await loadJobs(data.observation_date, { silent: true });
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : "Failed to start refresh.");
    } finally {
      setSubmitting(false);
    }
  }

  async function generateReport(job: RefreshJob) {
    setError("");
    setMessage("");
    setReportBusy(true);
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/asx-data-refresh/jobs/${job.job_id}/report`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${res.status}`);
      }
      const data: RefreshJob = await res.json();
      setSelectedJobId(data.job_id);
      setMessage(data.report_available ? "Saved report is available." : "Report generation queued.");
      await loadJobs(data.observation_date, { silent: true });
    } catch (generateError) {
      setError(generateError instanceof Error ? generateError.message : "Failed to generate report.");
    } finally {
      setReportBusy(false);
    }
  }

  async function generateSelectedReports() {
    const selected = jobs.filter((job) => selectedJobIds.has(job.job_id));
    if (!selected.length) {
      setMessage("Select at least one completed refresh job.");
      return;
    }
    setReportBusy(true);
    setError("");
    setMessage("");
    try {
      for (const job of selected) {
        if (job.status === "completed" && !job.report_available && !job.report_processing_status) {
          const res = await authenticatedFetch(`${baseUrl}/api/asx-data-refresh/jobs/${job.job_id}/report`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model }),
          });
          if (!res.ok) {
            const data = await res.json().catch(() => ({}));
            throw new Error(data.detail || `HTTP ${res.status}`);
          }
        }
      }
      setSelectedJobIds(new Set());
      setMessage(`Queued report generation for ${selected.length} selected stock${selected.length === 1 ? "" : "s"}.`);
      await loadJobs(observationDate, { silent: true });
    } catch (bulkError) {
      setError(bulkError instanceof Error ? bulkError.message : "Failed to queue selected reports.");
    } finally {
      setReportBusy(false);
    }
  }

  async function loadReport(job: RefreshJob) {
    setError("");
    setReport(null);
    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/stock-analysis/report/${encodeURIComponent(job.stock_code)}/${encodeURIComponent(job.observation_date)}`
      );
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${res.status}`);
      }
      const data: ReportResponse = await res.json();
      setSelectedJobId(job.job_id);
      setReport(data);
    } catch (reportError) {
      setError(reportError instanceof Error ? reportError.message : "Failed to load report.");
    }
  }

  function toggleSelected(jobId: number) {
    setSelectedJobIds((current) => {
      const next = new Set(current);
      if (next.has(jobId)) {
        next.delete(jobId);
      } else {
        next.add(jobId);
      }
      return next;
    });
  }

  return (
    <section className="space-y-6">
      <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="mb-5">
          <h2 className="text-lg font-medium text-slate-900">Start Refresh</h2>
          <p className="mt-1 text-sm text-slate-600">
            Submit a stock for today. Use the history date below to return to any previous observation day.
          </p>
        </div>
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <form onSubmit={submitRefresh} className="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div className="w-full sm:w-48">
              <label className="block text-xs font-medium text-slate-600 mb-1">ASX Code</label>
              <input
                type="text"
                value={stockCode}
                onChange={(e) => setStockCode(e.target.value)}
                placeholder="BHP or BHP.AX"
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
            >
              {submitting ? "Starting..." : "Start Refresh"}
            </button>
          </form>

          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">Model</label>
              <select
                value={model}
                onChange={(e) => setModel(e.target.value)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                {SHARED_MARKET_FLOW_MODEL_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex items-end">
              <button
                type="button"
                onClick={generateSelectedReports}
                disabled={reportBusy || selectedJobIds.size === 0}
                className="w-full rounded-md border border-indigo-300 px-4 py-2 text-sm font-medium text-indigo-700 hover:bg-indigo-50 disabled:opacity-50"
              >
                Generate Selected
              </button>
            </div>
          </div>
        </div>
        {error && <div className="mt-3 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>}
        {message && <div className="mt-3 rounded-md bg-blue-50 px-3 py-2 text-sm text-blue-700">{message}</div>}
      </div>

      <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
        <div className="flex flex-col gap-4 border-b border-slate-200 px-6 py-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h2 className="text-lg font-medium text-slate-900">Previous Stocks And Reports</h2>
            <p className="mt-1 text-sm text-slate-600">
              Change the observation date to see stocks refreshed on that day, inspect stage output, generate missing reports, or view saved reports.
            </p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">History Date</label>
              <input
                type="date"
                value={observationDate}
                onChange={(e) => setObservationDate(e.target.value)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>
          <button
            type="button"
            onClick={() => void loadJobs(observationDate)}
            disabled={loading}
            className="rounded-md border border-slate-300 px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          >
            {loading ? "Refreshing..." : "Refresh"}
          </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-left text-slate-600">
                <th className="w-10 px-4 py-2 font-medium"></th>
                <th className="px-3 py-2 font-medium">Stock</th>
                <th className="px-3 py-2 font-medium">Refresh</th>
                <th className="px-3 py-2 font-medium">Report</th>
                <th className="px-3 py-2 font-medium">Created</th>
                <th className="px-3 py-2 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {jobs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                    No refresh jobs for {observationDate}.
                  </td>
                </tr>
              ) : (
                jobs.map((job) => (
                  <tr
                    key={job.job_id}
                    className={`border-b border-slate-100 hover:bg-slate-50 ${
                      selectedJob?.job_id === job.job_id ? "bg-indigo-50/50" : ""
                    }`}
                  >
                    <td className="px-4 py-3">
                      <input
                        type="checkbox"
                        checked={selectedJobIds.has(job.job_id)}
                        onChange={() => toggleSelected(job.job_id)}
                        disabled={job.status !== "completed" || job.report_available || !!job.report_processing_status}
                      />
                    </td>
                    <td className="px-3 py-3 font-semibold text-slate-900">{job.stock_code}</td>
                    <td className="px-3 py-3">
                      <span className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-medium ${statusClass(job.status)}`}>
                        {job.status}
                      </span>
                      <div className="mt-1 text-xs text-slate-500">
                        {job.start_date} to {job.end_date}
                      </div>
                    </td>
                    <td className="px-3 py-3">
                      {job.report_available ? (
                        <span className="text-emerald-700">Generated</span>
                      ) : job.report_processing_status ? (
                        <span className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-medium ${statusClass(job.report_processing_status)}`}>
                          {job.report_processing_status}
                        </span>
                      ) : (
                        <span className="text-slate-500">Not generated</span>
                      )}
                      {job.report_processed_at && (
                        <div className="mt-1 text-xs text-slate-500">{formatDateTime(job.report_processed_at)}</div>
                      )}
                    </td>
                    <td className="px-3 py-3 text-slate-600">{formatDateTime(job.created_at)}</td>
                    <td className="px-3 py-3 text-right">
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedJobId(job.job_id);
                            setReport(null);
                          }}
                          className="rounded-md border border-slate-300 px-3 py-1.5 text-xs hover:bg-slate-50"
                        >
                          Details
                        </button>
                        {job.report_available ? (
                          <button
                            type="button"
                            onClick={() => void loadReport(job)}
                            className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700"
                          >
                            View
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => void generateReport(job)}
                            disabled={reportBusy || job.status !== "completed" || !!job.report_processing_status}
                            className="rounded-md bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
                          >
                            Generate
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {selectedJob && (
        <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
          <div className="flex flex-col gap-3 border-b border-slate-200 px-6 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-base font-semibold text-slate-900">{selectedJob.stock_code} Stage Details</h3>
              <div className="mt-1 text-xs text-slate-500">
                Observation {selectedJob.observation_date}
                {selectedJob.started_at ? ` | Started ${formatDateTime(selectedJob.started_at)}` : ""}
              </div>
            </div>
            <span className={`inline-flex w-fit rounded-full border px-3 py-1 text-xs font-medium ${statusClass(selectedJob.status)}`}>
              {selectedJob.status}
            </span>
          </div>

          {selectedJob.error_message && (
            <div className="mx-6 mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
              {selectedJob.error_message}
            </div>
          )}

          <div className="divide-y divide-slate-100">
            {selectedJob.stages.map((stage, index) => (
              <div key={stage.key} className="px-6 py-4">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <div className="flex items-center gap-3">
                      <span className="flex h-7 w-7 items-center justify-center rounded-full bg-slate-100 text-xs font-semibold text-slate-700">
                        {index + 1}
                      </span>
                      <div className="font-medium text-slate-900">{stage.label}</div>
                    </div>
                    {stage.detail && <div className="mt-2 text-xs text-slate-500 break-all">{stage.detail}</div>}
                    {(stage.started_at || stage.completed_at) && (
                      <div className="mt-2 text-xs text-slate-500">
                        {stage.started_at ? `Started ${formatDateTime(stage.started_at)}` : ""}
                        {stage.completed_at ? ` | Completed ${formatDateTime(stage.completed_at)}` : ""}
                      </div>
                    )}
                  </div>
                  <span className={`inline-flex w-fit rounded-full border px-2.5 py-1 text-xs font-medium ${statusClass(stage.status)}`}>
                    {stage.status}
                  </span>
                </div>
                {stage.output && (
                  <pre className="mt-3 max-h-72 overflow-auto rounded-md bg-slate-950 p-3 text-xs leading-5 text-slate-100">
                    {stage.output}
                  </pre>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {report && (
        <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
          <div className="border-b border-slate-200 px-6 py-4">
            <h3 className="text-base font-semibold text-slate-900">
              Report: {report.stock_code} {report.observation_date}
            </h3>
            <div className="mt-1 text-xs text-slate-500">
              {report.model || ""}
              {report.processed_at ? ` | ${formatDateTime(report.processed_at)}` : ""}
            </div>
          </div>
          <div className="p-6">
            <MarkdownRenderer content={report.report_markdown || ""} />
          </div>
        </div>
      )}
    </section>
  );
}
