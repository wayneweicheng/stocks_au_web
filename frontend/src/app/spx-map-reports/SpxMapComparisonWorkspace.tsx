"use client";

import { useCallback, useEffect, useState } from "react";
import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import MarkdownRenderer from "../components/MarkdownRenderer";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type AnyObject = Record<string, any>;
type Report = { job_id?: string; title?: string; observation_date?: string; created_at?: string; [key: string]: any };
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
  const [selectedId, setSelectedId] = useState("");
  const [reportContent, setReportContent] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const date = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
    setObservationDate(date);
    setJobId(window.localStorage.getItem(LAST_JOB_KEY) || "");
  }, []);

  const loadReports = useCallback(async () => {
    setBusy(true); setError("");
    try {
      const payload = await api<AnyObject>("/api/spx-map-comparison/reports");
      setReports(Array.isArray(payload) ? payload : payload.items || payload.reports || []);
    } catch (exc) { setError(message(exc)); }
    finally { setBusy(false); }
  }, []);
  useEffect(() => { if (mode === "viewer") void loadReports(); }, [mode, loadReports]);

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
      const effectivePriceContext = await Promise.all(snapshots.map(async ([label, day]) => {
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
      const result = await api<AnyObject>("/spx-map-comparison-prompt", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ preview, effective_price_context: effectivePriceContext }) });
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
    </> : <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm"><div className="flex flex-wrap items-center justify-between gap-2"><h2 className="text-lg font-semibold">SPX Two-Day Analysis Reports</h2><Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={busy}>Refresh reports</Button></div>
      {reports.length ? <div className="mt-4 flex flex-wrap gap-2">{reports.map((report, index) => { const id = report.job_id || String(report.id || ""); return <Button key={id || index} type="button" variant="secondary" onClick={() => void openReport(id)} disabled={busy || !id}>{report.title || `${report.observation_date || "SPX comparison"} · ${id}`}</Button>; })}</div> : <p className="mt-3 text-sm text-slate-500">No SPX comparison reports found.</p>}
      {selectedId ? <p className="mt-4 text-xs text-slate-500">Report job {selectedId}</p> : null}{reportContent ? <div className="mt-3"><MarkdownRenderer content={reportContent}/></div> : null}</section>}
    <section className="rounded-lg border border-slate-200 bg-white p-5 text-sm shadow-sm"><label className="font-medium">Comparison job ID<Input value={jobId} onChange={(event) => setJobId(event.target.value)} placeholder="Job ID returned by the runner" className="mt-1"/></label><div className="mt-2 flex items-center gap-3"><Button type="button" variant="secondary" onClick={() => void checkStatus()} disabled={busy || !jobId.trim()}>Check status</Button>{jobStatus ? <span>Status: {jobStatus}</span> : null}{jobStatus.toLowerCase() === "succeeded" || jobStatus.toLowerCase() === "completed" ? <Button type="button" variant="secondary" onClick={() => void openReport(jobId)}>Open report</Button> : null}</div></section>
    {busy ? <p className="text-sm text-slate-500">Loading…</p> : null}{error ? <Alert variant="danger">{error}</Alert> : null}
  </div>;
}
