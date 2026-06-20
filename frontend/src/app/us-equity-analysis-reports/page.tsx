"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Badge from "../components/ui/Badge";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import MarkdownRenderer from "../components/MarkdownRenderer";
import PageHeader from "../components/PageHeader";
import Select from "../components/ui/Select";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type TabKey = "viewer" | "runner";

type ReportSummary = {
  job_id: string;
  title: string;
  created_at?: string | null;
  stock_code?: string | null;
  status?: string | null;
  raw?: Record<string, unknown>;
};

type ReportDetail = ReportSummary & {
  content: string;
};

type ReportPage = {
  items: ReportSummary[];
};

type ProxyResponse = {
  data: Record<string, unknown>;
};

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

export default function UsEquityAnalysisReportsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const [activeTab, setActiveTab] = useState<TabKey>("viewer");
  const [items, setItems] = useState<ReportSummary[]>([]);
  const [selectedJobId, setSelectedJobId] = useState("");
  const [detail, setDetail] = useState<ReportDetail | null>(null);
  const [loadingList, setLoadingList] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [viewerError, setViewerError] = useState("");
  const [search, setSearch] = useState("");

  const [stockCode, setStockCode] = useState("MU");
  const [reportDetail, setReportDetail] = useState("normal");
  const [jobId, setJobId] = useState("");
  const [jobResponse, setJobResponse] = useState<Record<string, unknown> | null>(null);
  const [jobStatus, setJobStatus] = useState<Record<string, unknown> | null>(null);
  const [jobError, setJobError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [checking, setChecking] = useState(false);

  const filteredItems = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return items;
    return items.filter((item) =>
      `${item.title} ${item.job_id} ${item.stock_code || ""} ${item.status || ""}`.toLowerCase().includes(query)
    );
  }, [items, search]);

  const loadDetail = useCallback(
    async (jobIdToLoad: string) => {
      if (!baseUrl || !jobIdToLoad) return;
      setLoadingDetail(true);
      setViewerError("");
      try {
        const res = await authenticatedFetch(
          `${baseUrl}/api/us-equity-analysis-reports/${encodeURIComponent(jobIdToLoad)}`
        );
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          throw new Error(data.detail || `HTTP ${res.status}`);
        }
        const data: ReportDetail = await res.json();
        setDetail(data);
        setSelectedJobId(data.job_id);
      } catch (e: unknown) {
        setDetail(null);
        setViewerError(e instanceof Error ? e.message : "Failed to load report");
      } finally {
        setLoadingDetail(false);
      }
    },
    [baseUrl]
  );

  const loadReports = useCallback(async () => {
    if (!baseUrl) {
      setViewerError("NEXT_PUBLIC_BACKEND_URL is not configured.");
      return;
    }
    setLoadingList(true);
    setViewerError("");
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/us-equity-analysis-reports`);
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${res.status}`);
      }
      const data: ReportPage = await res.json();
      const nextItems = data.items || [];
      setItems(nextItems);

      const stillSelected = nextItems.some((item) => item.job_id === selectedJobId);
      const jobIdToLoad = stillSelected ? selectedJobId : nextItems[0]?.job_id || "";
      if (jobIdToLoad) {
        await loadDetail(jobIdToLoad);
      } else {
        setSelectedJobId("");
        setDetail(null);
      }
    } catch (e: unknown) {
      setViewerError(e instanceof Error ? e.message : "Failed to load reports");
    } finally {
      setLoadingList(false);
    }
  }, [baseUrl, loadDetail, selectedJobId]);

  const submitJob = useCallback(async () => {
    if (!baseUrl) {
      setJobError("NEXT_PUBLIC_BACKEND_URL is not configured.");
      return;
    }

    const symbol = stockCode.trim().toUpperCase();
    if (!symbol) {
      setJobError("Enter a stock code.");
      return;
    }

    setSubmitting(true);
    setJobError("");
    setJobResponse(null);
    setJobStatus(null);
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/us-equity-analysis/jobs`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          stock_code: symbol,
          report_detail: reportDetail,
        }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(payload.detail || `HTTP ${res.status}`);
      }
      const data = (payload as ProxyResponse).data || {};
      setJobResponse(data);
      const returnedJobId = getJobId(data);
      if (returnedJobId) setJobId(returnedJobId);
    } catch (e: unknown) {
      setJobError(e instanceof Error ? e.message : "Failed to submit job");
    } finally {
      setSubmitting(false);
    }
  }, [baseUrl, reportDetail, stockCode]);

  const checkStatus = useCallback(async () => {
    if (!baseUrl) {
      setJobError("NEXT_PUBLIC_BACKEND_URL is not configured.");
      return;
    }
    const currentJobId = jobId.trim();
    if (!currentJobId) {
      setJobError("Enter or submit a job id first.");
      return;
    }

    setChecking(true);
    setJobError("");
    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/us-equity-analysis/jobs/${encodeURIComponent(currentJobId)}`
      );
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(payload.detail || `HTTP ${res.status}`);
      }
      setJobStatus((payload as ProxyResponse).data || {});
    } catch (e: unknown) {
      setJobError(e instanceof Error ? e.message : "Failed to check job status");
    } finally {
      setChecking(false);
    }
  }, [baseUrl, jobId]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  const visibleJobStatus = jobStatus ? getStatus(jobStatus) : jobResponse ? getStatus(jobResponse) : "";

  return (
    <div className="space-y-6">
      <PageHeader
        title="US Equity Analysis Reports"
        subtitle="View generated US equity reports and submit new analysis jobs through the backend skill-runner proxy."
        actions={
          <Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={loadingList}>
            {loadingList ? "Refreshing..." : "Refresh Reports"}
          </Button>
        }
      />

      <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        {[
          ["viewer", "Viewer"],
          ["runner", "Run Job"],
        ].map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setActiveTab(key as TabKey)}
            className={[
              "rounded-md px-4 py-2 text-sm font-medium transition-colors",
              activeTab === key
                ? "bg-indigo-600 text-white shadow-sm"
                : "text-slate-600 hover:bg-slate-50 hover:text-slate-900",
            ].join(" ")}
          >
            {label}
          </button>
        ))}
      </div>

      {activeTab === "viewer" ? (
        <div className="space-y-4">
          {viewerError ? <Alert variant="danger">{viewerError}</Alert> : null}

          <div className="grid gap-6 lg:grid-cols-[320px_minmax(0,1fr)]">
            <aside className="rounded-lg border border-slate-200 bg-white">
              <div className="border-b border-slate-200 p-4">
                <label className="mb-1 block text-xs font-medium text-slate-600">
                  Search reports
                </label>
                <Input
                  type="search"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Stock, status or job id"
                />
              </div>

              <div className="max-h-[calc(100vh-285px)] min-h-72 overflow-y-auto p-2">
                {loadingList && items.length === 0 ? (
                  <div className="px-3 py-8 text-center text-sm text-slate-500">Loading reports...</div>
                ) : filteredItems.length === 0 ? (
                  <div className="px-3 py-8 text-center text-sm text-slate-500">
                    No US equity analysis reports found.
                  </div>
                ) : (
                  <div className="space-y-1">
                    {filteredItems.map((item) => {
                      const active = item.job_id === selectedJobId;
                      const itemStatus = item.status || "";
                      return (
                        <button
                          key={item.job_id}
                          type="button"
                          onClick={() => void loadDetail(item.job_id)}
                          className={[
                            "w-full rounded-md px-3 py-3 text-left text-sm transition-colors",
                            active
                              ? "bg-indigo-50 text-indigo-800"
                              : "text-slate-700 hover:bg-slate-50 hover:text-slate-900",
                          ].join(" ")}
                        >
                          <span className="block font-medium">{item.title}</span>
                          <span className="mt-1 block text-xs text-slate-500">
                            {formatOptionalDate(item.created_at)}
                          </span>
                          <span className="mt-2 flex flex-wrap items-center gap-2 text-xs text-slate-400">
                            {item.stock_code ? <span>{item.stock_code}</span> : null}
                            <span>Job {item.job_id}</span>
                            {itemStatus ? (
                              <Badge variant={statusVariant(itemStatus)}>{itemStatus}</Badge>
                            ) : null}
                          </span>
                        </button>
                      );
                    })}
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
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      onClick={() => void loadDetail(detail.job_id)}
                      disabled={loadingDetail}
                    >
                      {loadingDetail ? "Loading..." : "Reload"}
                    </Button>
                  </div>
                ) : (
                  <h2 className="text-lg font-semibold text-slate-900">Report Preview</h2>
                )}
              </div>

              <div className="min-h-[520px] p-5">
                {loadingDetail && !detail ? (
                  <div className="flex min-h-[420px] items-center justify-center text-sm text-slate-500">
                    Loading report...
                  </div>
                ) : detail ? (
                  <MarkdownRenderer content={detail.content} />
                ) : (
                  <div className="flex min-h-[420px] items-center justify-center text-sm text-slate-500">
                    Select a report to view it.
                  </div>
                )}
              </div>
            </section>
          </div>
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,420px)_minmax(0,1fr)]">
          <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
            <div className="space-y-4">
              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Stock code
                </label>
                <Input
                  value={stockCode}
                  onChange={(event) => setStockCode(event.target.value.toUpperCase())}
                  placeholder="MU"
                />
              </div>

              <div>
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Report detail
                </label>
                <Select value={reportDetail} onChange={(event) => setReportDetail(event.target.value)}>
                  <option value="normal">normal</option>
                  <option value="detailed">detailed</option>
                  <option value="brief">brief</option>
                </Select>
              </div>

              <Button type="button" onClick={() => void submitJob()} disabled={submitting}>
                {submitting ? "Submitting..." : "Submit Analysis Job"}
              </Button>

              <div className="border-t border-slate-200 pt-4">
                <label className="mb-1 block text-sm font-medium text-slate-700">
                  Job id
                </label>
                <div className="flex gap-2">
                  <Input
                    value={jobId}
                    onChange={(event) => setJobId(event.target.value)}
                    placeholder="Returned after submit"
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={() => void checkStatus()}
                    disabled={checking || !jobId.trim()}
                    className="shrink-0"
                  >
                    {checking ? "Checking..." : "Check Job Status"}
                  </Button>
                </div>
              </div>

              {visibleJobStatus ? (
                <div className="flex items-center gap-2 text-sm text-slate-600">
                  Latest status:
                  <Badge variant={statusVariant(visibleJobStatus)}>{visibleJobStatus}</Badge>
                </div>
              ) : null}

              {jobError ? <Alert variant="danger">{jobError}</Alert> : null}
            </div>
          </section>

          <section className="min-w-0 rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="border-b border-slate-200 bg-slate-50 px-5 py-4">
              <h2 className="text-lg font-semibold text-slate-900">Job Response</h2>
            </div>
            <div className="space-y-4 p-5">
              <div>
                <div className="mb-2 text-sm font-medium text-slate-700">Submit response</div>
                <pre className="max-h-72 overflow-auto rounded-md bg-slate-950 p-4 text-xs text-slate-100">
                  {jobResponse ? JSON.stringify(jobResponse, null, 2) : "Submit a job to see the response."}
                </pre>
              </div>

              <div>
                <div className="mb-2 text-sm font-medium text-slate-700">Status response</div>
                <pre className="max-h-96 overflow-auto rounded-md bg-slate-950 p-4 text-xs text-slate-100">
                  {jobStatus ? JSON.stringify(jobStatus, null, 2) : "Check job status to see the latest result."}
                </pre>
              </div>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
