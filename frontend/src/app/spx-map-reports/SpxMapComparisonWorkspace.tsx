"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import MarkdownRenderer from "../components/MarkdownRenderer";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { confirmReportDeletion } from "../components/confirmReportDeletion";
import { spxComparisonReportDates, spxComparisonReportTitle } from "./comparisonReportDisplay";

type AnyObject = Record<string, any>;
type Report = { job_id?: string; title?: string; label?: string; observation_date?: string; created_at?: string; d1_date?: string; d2_date?: string; _d1Date?: string | null; _d2Date?: string | null; [key: string]: any };
function localDateString(date: Date) { const year = date.getFullYear(); const month = String(date.getMonth() + 1).padStart(2, "0"); const day = String(date.getDate()).padStart(2, "0"); return `${year}-${month}-${day}`; }
function defaultReportDateFrom() { const date = new Date(); date.setDate(date.getDate() - 30); return localDateString(date); }
const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
const LAST_JOB_KEY = "stocks_au_spx_map_comparison_last_job";

async function api<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await authenticatedFetch(`${baseUrl}${path}`, options);
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.detail || body.message || `Request failed (HTTP ${response.status})`);
  return body as T;
}
function message(error: unknown) { return error instanceof Error ? error.message : String(error); }
function displayField(value: unknown): string {
  if (value == null || value === "") return "unavailable";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  if (Array.isArray(value)) return value.length ? `${value.length} entries` : "none";
  if (typeof value === "object") {
    const item = value as AnyObject;
    const label = typeof item.label === "string" ? item.label : "";
    const evidence = typeof item.evidence === "string" ? item.evidence : "";
    if (label && evidence) return `${label} · ${evidence}`;
    if (label) return label;
    return "Details available";
  }
  return "unavailable";
}

export default function SpxMapComparisonWorkspace({ mode }: { mode: "lab" | "viewer" }) {
  const [observationDate, setObservationDate] = useState("");
  const [preview, setPreview] = useState<AnyObject | null>(null);
  const [prompt, setPrompt] = useState("");
  const [copied, setCopied] = useState(false);
  const [jobId, setJobId] = useState("");
  const [jobStatus, setJobStatus] = useState("");
  const [reports, setReports] = useState<Report[]>([]);
  const [reportDateFrom, setReportDateFrom] = useState(defaultReportDateFrom);
  const [reportDateTo, setReportDateTo] = useState(() => localDateString(new Date()));
  const [reportsTotal, setReportsTotal] = useState(0);
  const [hasMoreReports, setHasMoreReports] = useState(false);
  const [selectedId, setSelectedId] = useState("");
  const [reportContent, setReportContent] = useState("");
  const [deletingReport, setDeletingReport] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const date = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
    setObservationDate(date);
    setJobId(window.localStorage.getItem(LAST_JOB_KEY) || "");
  }, []);

  const loadReports = useCallback(async (offset = 0, append = false) => {
    setBusy(true); setError("");
    try {
      const params = new URLSearchParams({ date_from: reportDateFrom, date_to: reportDateTo, offset: String(offset), limit: "30" });
      const payload = await api<AnyObject>(`/api/spx-map-comparison/reports?${params.toString()}`);
      const listed = (Array.isArray(payload) ? payload : payload.items || payload.reports || []) as Report[];
      const enriched = listed.map((report) => {
        const dates = spxComparisonReportDates(report);
        return { ...report, _d1Date: dates.d1, _d2Date: dates.d2 };
      });
      setReports((current) => append ? [...current, ...enriched] : enriched);
      setReportsTotal(typeof payload.total === "number" ? payload.total : enriched.length);
      setHasMoreReports(Boolean(payload.has_more));
      if (!append) { setSelectedId(""); setReportContent(""); }
    } catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  }, [reportDateFrom, reportDateTo]);
  const loadReportsRef = useRef(loadReports);
  useEffect(() => { loadReportsRef.current = loadReports; }, [loadReports]);
  useEffect(() => { if (mode === "viewer") void loadReportsRef.current(); }, [mode]);

  const findReports = async () => {
    setBusy(true); setError(""); setPreview(null); setPrompt(""); setCopied(false);
    try { setPreview(await api<AnyObject>("/spx-map-comparison-preview", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ observation_date: observationDate }) })); }
    catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  };
  const canonical = preview?.comparison_input || preview?.data?.comparison_input;
  const inputId = preview?.input_id || preview?.data?.input_id || canonical?.input_id;
  const getPrompt = async () => {
    if (!inputId) return;
    setBusy(true); setError(""); setPrompt(""); setCopied(false);
    try {
      const snapshots = [["D1", canonical?.D1], ["D2", canonical?.D2]] as const;
      const effectivePriceContext = Array.isArray(preview?.effective_price_context)
        ? preview.effective_price_context
        : await Promise.all(snapshots.map(async ([label, day]) => {
        const snapshot = day && typeof day === "object" ? day as AnyObject : {};
        const source = snapshot.source && typeof snapshot.source === "object" ? snapshot.source as AnyObject : {};
        const report = snapshot.report && typeof snapshot.report === "object" ? snapshot.report as AnyObject : {};
        const asOf = source.as_of_et || report.as_of_et || null;
        const tradingDate = source.trading_date || report.observation_date || (typeof asOf === "string" ? asOf.slice(0, 10) : null);
        if (!asOf || !tradingDate) return { day: label, as_of_et: asOf, effective_prices: null, unavailable_reason: "report as-of timestamp/date unavailable" };
        try {
          const query = new URLSearchParams({ observation_date: String(tradingDate), as_of_et: String(asOf) });
          const prices = await api<AnyObject>(`/api/spx-map-prices?${query.toString()}`);
          return { day: label, as_of_et: asOf, effective_prices: prices.effective_prices || null,
            source: prices.effective_price_source || "unavailable", timestamp: prices.effective_price_timestamp || null,
            timestamps: prices.effective_price_timestamps || {}, es_spx_basis: prices.effective_price_basis ?? null,
            basis_observation_date: prices.historical_close_date || null, basis_dates: prices.historical_close_dates || {} };
        } catch (priceError) {
          return { day: label, as_of_et: asOf, effective_prices: null, unavailable_reason: message(priceError) };
        }
        }));
      const result = await api<AnyObject>("/api/spx-map-comparison/prompt", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ preview, effective_price_context: effectivePriceContext }) });
      const basePrompt = result.prompt || result.data?.prompt || "";
      if (!basePrompt) throw new Error("Prompt endpoint returned no prompt.");
      setPrompt(basePrompt.trim());
    } catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  };
  const copyPrompt = async () => {
    try { await navigator.clipboard.writeText(prompt); setCopied(true); }
    catch { setError("Could not access clipboard. Select the prompt text and copy it manually."); }
  };
  const submit = async () => {
    if (!inputId) return;
    setBusy(true); setError("");
    try {
      const result = await api<AnyObject>("/api/jobs/spx-map-comparison", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ observation_date: observationDate, input_id: inputId, timeout_minutes: 30 }) });
      const id = result.job_id || result.data?.job_id;
      if (!id) throw new Error("Runner did not return a job ID.");
      setJobId(id); setJobStatus(result.status || result.data?.status || "queued"); window.localStorage.setItem(LAST_JOB_KEY, id);
    } catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  };
  const checkStatus = async () => {
    if (!jobId.trim()) return;
    setBusy(true); setError("");
    try { const result = await api<AnyObject>(`/api/spx-map-comparison/jobs/${encodeURIComponent(jobId.trim())}`); setJobStatus(result.status || result.data?.status || "unknown"); }
    catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  };
  const openReport = async (id: string) => {
    setBusy(true); setError(""); setSelectedId(id); setReportContent("");
    try {
      const result = await api<AnyObject>(`/api/spx-map-comparison/jobs/${encodeURIComponent(id)}/report`);
      setReportContent(result.content || result.report || result.data?.content || "");
      if (!result.content && !result.report && !result.data?.content) throw new Error("Report content is not available yet.");
    } catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  };
  const deleteSelectedReport = async () => {
    const report = reports.find((item) => (item.job_id || String(item.id || "")) === selectedId);
    if (!report || !confirmReportDeletion(report.title || "SPX comparison", selectedId)) return;
    setBusy(true); setDeletingReport(true); setError("");
    try {
      await api<AnyObject>(`/api/spx-map-comparison/reports/${encodeURIComponent(selectedId)}`, { method: "DELETE" });
      setReports((current) => current.filter((item) => (item.job_id || String(item.id || "")) !== selectedId));
      setReportsTotal((current) => Math.max(0, current - 1));
      setSelectedId(""); setReportContent("");
    } catch (exc) { setError(message(exc)); }
    finally { setDeletingReport(false); setBusy(false); }
  };
  // The runner returns report snapshots under comparison_input.D1/D2, each
  // containing separate source provenance and a normalized report summary.
  const d1 = canonical?.D1 || preview?.D1 || preview?.d1;
  const d2 = canonical?.D2 || preview?.D2 || preview?.d2;

  return <div className="space-y-5">
    {mode === "lab" ? <>
      <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold">SPX Two-Day Comparison Lab</h2>
        <p className="mt-1 text-sm text-slate-600">Select a US trading date to find its completed D1 SPX map and the preceding US session’s D2 map. Preview first; prompt generation does not submit a job. Comparison reports are retrospective/advisory and never execute orders.</p>
        <div className="mt-4 flex flex-wrap items-end gap-3"><label className="text-sm font-medium">US observation date<Input type="date" value={observationDate} onChange={(event) => { setObservationDate(event.target.value); setPreview(null); setPrompt(""); }} className="mt-1" /></label><Button type="button" onClick={() => void findReports()} disabled={busy || !observationDate}>Find D1 and D2</Button></div>
      </section>
      {preview ? <section className="space-y-3 rounded-lg border border-indigo-200 bg-white p-5 shadow-sm">
        <h3 className="font-semibold">Selected comparison · {observationDate}</h3>
        {inputId ? <p className="break-all text-xs text-slate-500">Input ID: {inputId}</p> : <Alert variant="warning">Preview returned no input_id; refresh preview before prompt generation or submission.</Alert>}
        {[ ["D1", d1], ["D2", d2] ].map(([label, day]) => {
          const snapshot = day && typeof day === "object" ? day as AnyObject : null;
          const source = snapshot?.source && typeof snapshot.source === "object" ? snapshot.source as AnyObject : {};
          const report = snapshot?.report && typeof snapshot.report === "object" ? snapshot.report as AnyObject : {};
          const summary = preview?.evidence_summary?.[String(label)] || preview?.data?.evidence_summary?.[String(label)] || {};
          const supportCount = Array.isArray(report.support_zones) ? report.support_zones.length : null;
          const resistanceCount = Array.isArray(report.resistance_zones) ? report.resistance_zones.length : null;
          return <div key={String(label)} className="rounded border bg-slate-50 p-3 text-sm">
            <strong>{label} · {source.trading_date || summary.trading_date || "date unavailable"}</strong>
            {snapshot ? <div className="mt-2 grid gap-x-6 gap-y-1 text-slate-700 sm:grid-cols-2">
              <div>Source job: <span className="font-mono text-xs">{source.job_id || "unavailable"}</span></div>
              <div>As of ET: {source.as_of_et || report.as_of_et || "unavailable"}</div>
              <div>Support zones: {supportCount ?? "unavailable"}</div>
              <div>Resistance zones: {resistanceCount ?? "unavailable"}</div>
              <div>Structural bias: {displayField(report.structural_bias)}</div>
              <div>Execution condition: {displayField(report.execution_condition)}</div>
            </div> : <p className="mt-1 text-amber-800">Selected report snapshot unavailable.</p>}
          </div>;
        })}
        <div className="flex flex-wrap gap-2"><Button type="button" variant="secondary" onClick={() => void getPrompt()} disabled={busy || !inputId}>Generate Prompt</Button><Button type="button" onClick={() => void submit()} disabled={busy || !inputId}>Submit Comparison Job</Button></div>
        {prompt ? <div className="space-y-2"><p className="text-xs text-slate-600">Copyable prompt with the canonical D1/D2 evidence and each report's as-of effective prices. This action has not submitted a job.</p><textarea aria-label="SPX comparison prompt" readOnly value={prompt} rows={14} className="w-full rounded border border-slate-300 bg-slate-50 p-3 font-mono text-xs"/><Button type="button" variant="secondary" onClick={() => void copyPrompt()}>{copied ? "Copied" : "Copy Prompt"}</Button></div> : null}
      </section> : null}
    </> : <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-4"><div><h2 className="text-lg font-semibold">SPX Two-Day Analysis Reports</h2><p className="mt-1 text-sm text-slate-600">Select a report to open its analysis. Each entry identifies the D1 and D2 US trading dates.</p><p className="mt-1 text-xs text-slate-500">Report bodies are loaded only when selected; the list shows up to 30 reports per page.</p></div><div className="flex flex-wrap items-end gap-2"><label className="text-xs text-slate-600">D1 date from<Input type="date" value={reportDateFrom} onChange={(event) => setReportDateFrom(event.target.value)} className="mt-1" /></label><label className="text-xs text-slate-600">D1 date to<Input type="date" value={reportDateTo} onChange={(event) => setReportDateTo(event.target.value)} className="mt-1" /></label><Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={busy}>Apply dates</Button></div></div>
      <p className="mt-2 text-xs text-slate-500">Showing {reports.length} of {reportsTotal} matching reports.</p>
      {reports.length ? <div className="mt-4 grid gap-2 sm:grid-cols-2 xl:grid-cols-3">{reports.map((report, index) => {
        const id = report.job_id || String(report.id || "");
        const isSelected = selectedId === id;
        return <button key={id || index} type="button" onClick={() => void openReport(id)} disabled={busy || !id} aria-pressed={isSelected}
          className={`rounded-lg border p-3 text-left transition-colors disabled:cursor-wait disabled:opacity-60 ${isSelected ? "border-indigo-500 bg-indigo-50 ring-1 ring-indigo-200" : "border-slate-200 bg-white hover:border-indigo-300 hover:bg-slate-50"}`}>
          <span className="block text-xs font-semibold uppercase tracking-wide text-indigo-700">{spxComparisonReportTitle({ d1: report._d1Date || null, d2: report._d2Date || null })}</span>
          <span className="mt-1 block font-medium text-slate-900">{report.title || "SPX comparison"}</span>
          <span className="mt-2 block break-all font-mono text-[10px] text-slate-500">Job {id || "unavailable"}</span>
          {report.created_at ? <span className="mt-1 block text-xs text-slate-500">Generated {report.created_at}</span> : null}
        </button>;
      })}</div> : <p className="mt-3 text-sm text-slate-500">No SPX comparison reports match the selected D1 date range.</p>}
      {hasMoreReports ? <div className="mt-4 text-center"><Button type="button" variant="secondary" onClick={() => void loadReports(reports.length, true)} disabled={busy}>Load older reports</Button></div> : null}
      {selectedId ? <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-slate-200 pt-3"><p className="text-xs text-slate-500">Selected report job {selectedId}</p><Button type="button" variant="danger" onClick={() => void deleteSelectedReport()} disabled={busy}>{deletingReport ? "Deleting…" : "Delete report"}</Button></div> : null}
      {reportContent ? <div className="mt-4 border-t border-slate-200 pt-4"><MarkdownRenderer content={reportContent}/></div> : selectedId && busy ? <p className="mt-4 text-sm text-slate-500">Loading selected report…</p> : null}
    </section>}
    <section className="rounded-lg border border-slate-200 bg-white p-5 text-sm shadow-sm"><label className="font-medium">Comparison job ID<Input value={jobId} onChange={(event) => setJobId(event.target.value)} placeholder="Job ID returned by the runner" className="mt-1"/></label><div className="mt-2 flex items-center gap-3"><Button type="button" variant="secondary" onClick={() => void checkStatus()} disabled={busy || !jobId.trim()}>Check status</Button>{jobStatus ? <span>Status: {jobStatus}</span> : null}{jobStatus.toLowerCase() === "succeeded" || jobStatus.toLowerCase() === "completed" ? <Button type="button" variant="secondary" onClick={() => void openReport(jobId)}>Open report</Button> : null}</div></section>
    {busy ? <p className="text-sm text-slate-500">Loading…</p> : null}{error ? <Alert variant="danger">{error}</Alert> : null}
  </div>;
}
