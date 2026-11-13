"use client";

import { useCallback, useEffect, useState } from "react";
import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import MarkdownRenderer from "../components/MarkdownRenderer";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { confirmReportDeletion } from "../components/confirmReportDeletion";
import { comparisonApiError } from "./comparisonApiError";

type DaySnapshot = {
  trading_date: string;
  report_job_id: string;
  as_of_et: string;
  mapped_levels_and_orders: { supports: unknown[]; resistances: unknown[]; orders: unknown[] };
  expected_moves: Array<{ expiry?: string; call_price?: number; put_price?: number; quote_source?: string }>;
};
type Preview = {
  stock_code: string;
  observation_date: string;
  analysis_mode: "live_order_ideas" | "upcoming_session_plan" | "historical_review";
  d1: DaySnapshot;
  d2: DaySnapshot;
  current_market: { live_price: number | null; live_price_source?: string | null; retrieved_at_utc: string };
};
type ComparisonReport = { job_id: string; title: string; stock_code?: string; created_at?: string };

const JOB_KEY = "stocks_au_stock_map_comparison_last_job";
const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";

function nyDate(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(new Date());
  const field = (type: string) => parts.find((part) => part.type === type)?.value || "";
  return `${field("year")}-${field("month")}-${field("day")}`;
}

async function api<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await authenticatedFetch(`${baseUrl}${path}`, options);
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(comparisonApiError(body, response.status));
  return body as T;
}

function Snapshot({ label, snapshot }: { label: string; snapshot: DaySnapshot }) {
  const quote = [...(snapshot.expected_moves || [])].sort((a, b) => String(a.expiry || "").localeCompare(String(b.expiry || "")))[0];
  return <div className="rounded border border-slate-200 bg-slate-50 p-3 text-sm text-slate-700">
    <div className="font-semibold">{label} · US session {snapshot.trading_date}</div>
    <div>Latest completed report: <span className="font-mono text-xs">{snapshot.report_job_id}</span></div>
    <div>As-of: {snapshot.as_of_et} · Supports: {snapshot.mapped_levels_and_orders.supports.length} · Resistances: {snapshot.mapped_levels_and_orders.resistances.length} · Report orders: {snapshot.mapped_levels_and_orders.orders.length}</div>
    <div>Nearest ATM call + put: {quote && typeof quote.call_price === "number" && typeof quote.put_price === "number"
      ? `$${(quote.call_price + quote.put_price).toFixed(2)} (expiry ${quote.expiry}; ${quote.quote_source || "source not specified"})`
      : "Not available — analysis must flag this gap"}</div>
    <a href={`/stock-map-reports/${encodeURIComponent(snapshot.report_job_id)}/mapped-levels`} target="_blank" rel="noopener noreferrer" className="text-indigo-700 underline">Open mapped levels and orders</a>
  </div>;
}

export default function StockMapComparisonWorkspace({ mode }: { mode: "lab" | "viewer" }) {
  const [stock, setStock] = useState("");
  const [observationDate, setObservationDate] = useState("");
  const [preview, setPreview] = useState<Preview | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [jobId, setJobId] = useState("");
  const [status, setStatus] = useState("");
  const [reports, setReports] = useState<ComparisonReport[]>([]);
  const [selectedReport, setSelectedReport] = useState("");
  const [reportContent, setReportContent] = useState("");
  const [deletingReport, setDeletingReport] = useState(false);
  const [promptText, setPromptText] = useState("");
  const [promptFor, setPromptFor] = useState("");
  const [promptCopied, setPromptCopied] = useState(false);
  const selectionKey = `${stock.trim().toUpperCase()}|${observationDate}`;
  const visiblePrompt = promptFor === selectionKey ? promptText : "";

  useEffect(() => {
    setObservationDate(nyDate());
    setJobId(window.localStorage.getItem(JOB_KEY) || "");
  }, []);

  const loadReports = useCallback(async () => {
    setBusy(true);
    setError("");
    try {
      const response = await api<{ items: ComparisonReport[] }>("/api/stock-map-comparison-reports");
      setReports(response.items || []);
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  }, []);

  useEffect(() => { if (mode === "viewer") void loadReports(); }, [mode, loadReports]);

  const findReports = async () => {
    setBusy(true);
    setError("");
    setPreview(null);
    setPromptText("");
    setPromptCopied(false);
    try {
      const params = new URLSearchParams({ stock_code: stock.trim(), observation_date: observationDate });
      setPreview(await api<Preview>(`/api/stock-map-comparison/preview?${params}`));
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  };

  const getPrompt = async () => {
    const requestedFor = selectionKey;
    setBusy(true);
    setError("");
    setPromptText("");
    setPromptCopied(false);
    try {
      const params = new URLSearchParams({ stock_code: stock.trim(), observation_date: observationDate });
      const response = await api<{ prompt: string }>(`/api/stock-map-comparison/prompt?${params}`);
      if (!response.prompt) throw new Error("Prompt service returned no prompt.");
      setPromptFor(requestedFor);
      setPromptText(response.prompt);
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  };

  const copyPrompt = async () => {
    if (!visiblePrompt) return;
    setError("");
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(visiblePrompt);
      } else {
        const area = document.createElement("textarea");
        area.value = visiblePrompt;
        area.style.position = "fixed";
        area.style.left = "-9999px";
        document.body.appendChild(area);
        try {
          area.select();
          if (!document.execCommand("copy")) throw new Error("Copy command failed");
        } finally { document.body.removeChild(area); }
      }
      setPromptCopied(true);
    } catch { setError("Copy failed. Select the prompt text and copy it manually."); }
  };

  const submit = async () => {
    setBusy(true);
    setError("");
    try {
      const response = await api<{ data: { job_id: string; status?: string } }>("/api/stock-map-comparison/jobs", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stock_code: stock.trim(), observation_date: observationDate }),
      });
      const id = response.data?.job_id;
      if (!id) throw new Error("Skill runner did not return a job ID. Check its jobs before retrying.");
      setJobId(id);
      setStatus(response.data.status || "queued");
      window.localStorage.setItem(JOB_KEY, id);
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  };

  const checkStatus = async () => {
    if (!jobId.trim()) return;
    setBusy(true);
    setError("");
    try {
      const response = await api<{ data: { status?: string; state?: string } }>(`/api/stock-map-comparison/jobs/${encodeURIComponent(jobId.trim())}`);
      setStatus(response.data?.status || response.data?.state || "unknown");
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  };

  const openReport = async (id: string) => {
    setBusy(true);
    setError("");
    setReportContent("");
    setSelectedReport(id);
    try {
      const response = await api<{ content: string }>(`/api/stock-map-comparison-reports/${encodeURIComponent(id)}`);
      setReportContent(response.content || "No report content returned.");
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setBusy(false); }
  };

  const deleteSelectedReport = async () => {
    const report = reports.find((item) => item.job_id === selectedReport);
    if (!report || !confirmReportDeletion(report.title || report.job_id, report.job_id)) return;
    setBusy(true);
    setDeletingReport(true);
    setError("");
    try {
      await api(`/api/stock-map-comparison-reports/${encodeURIComponent(report.job_id)}`, { method: "DELETE" });
      setReports((current) => current.filter((item) => item.job_id !== report.job_id));
      setSelectedReport("");
      setReportContent("");
    } catch (exc) { setError(exc instanceof Error ? exc.message : String(exc)); }
    finally { setDeletingReport(false); setBusy(false); }
  };

  return <div className="space-y-5">
    {mode === "lab" ? <>
      <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
        <h2 className="text-lg font-semibold">Two-Day Stock Map Order Lab</h2>
        <p className="mt-1 text-sm text-slate-600">D1 is the latest completed map as-of the selected US trading date, including pre-market maps; D2 is the preceding US trading session. Both JSON reports are required. This requests advisory analysis only and never places an order.</p>
        <div className="mt-4 flex flex-wrap items-end gap-3">
          <label className="block text-sm font-medium">US stock code<Input value={stock} onChange={(event) => { setStock(event.target.value); setPreview(null); setPromptText(""); setPromptCopied(false); }} placeholder="FORM" className="mt-1" /></label>
          <label className="block text-sm font-medium">Observation date (US Eastern)<Input type="date" value={observationDate} onChange={(event) => { setObservationDate(event.target.value); setPreview(null); setPromptText(""); setPromptCopied(false); }} className="mt-1" /></label>
          <Button type="button" onClick={() => void findReports()} disabled={busy || !stock.trim() || !observationDate}>Find D1 and D2</Button>
        </div>
      </section>
      {preview ? <section className="space-y-3 rounded-lg border border-indigo-200 bg-white p-5 shadow-sm">
        <h3 className="font-semibold">Evidence selected for {preview.stock_code} · observation {preview.observation_date}</h3>
        {preview.analysis_mode === "historical_review" ? <Alert variant="warning">This observation date predates today in New York. Analysis is retrospective; it must not recommend placing an order now from historical reports.</Alert> : null}
        {preview.analysis_mode === "upcoming_session_plan" ? <Alert variant="warning">The observation date is in the future in New York. A D1 report for that date must already exist; treat any analysis as a conditional plan and revalidate prices before entry.</Alert> : null}
        <Snapshot label="D1 (observation-date map)" snapshot={preview.d1} />
        <Snapshot label="D2 (previous US session)" snapshot={preview.d2} />
        <p className="text-sm">Current price: <strong>{preview.current_market.live_price ?? "unavailable"}</strong> ({preview.current_market.live_price_source || "unknown source"}). Retrieved {preview.current_market.retrieved_at_utc}. Quote timestamp may differ.</p>
        {preview.current_market.live_price === null ? <Alert variant="warning">No live price is available. You can inspect D1/D2, but an order-plan job cannot be submitted without current-price evidence.</Alert> : null}
        <div className="flex flex-wrap gap-2">
          <Button type="button" onClick={() => void submit()} disabled={busy || preview.current_market.live_price === null}>Submit comparative analysis job</Button>
          <Button type="button" variant="secondary" onClick={() => void getPrompt()} disabled={busy}>Get Prompt</Button>
          {visiblePrompt ? <Button type="button" variant="secondary" onClick={() => void copyPrompt()} disabled={busy}>Copy Prompt</Button> : null}
        </div>
        {visiblePrompt ? <div className="space-y-2">
          <p className="text-sm text-slate-600">Copyable ChatGPT prompt built from the same D1/D2 runner input JSON. The runner receives structured JSON, not this text or its own private prompt. This preview does not submit a job; prices and evidence may change before a later submission.</p>
          <textarea aria-label="Two-Day Lab prompt" value={visiblePrompt} readOnly rows={18} className="w-full rounded border border-slate-300 bg-slate-50 p-3 font-mono text-xs text-slate-800" />
          {promptCopied ? <p role="status" className="text-sm text-green-700">Prompt copied.</p> : null}
        </div> : null}
      </section> : null}
    </> : <section className="rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-2"><h2 className="text-lg font-semibold">Two-Day Analysis Reports</h2><Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={busy}>Refresh reports</Button></div>
      {reports.length ? <div className="mt-4 flex flex-wrap gap-2">{reports.map((report) => <Button key={report.job_id} type="button" variant="secondary" onClick={() => void openReport(report.job_id)} disabled={busy}>{report.title || report.job_id}</Button>)}</div> : <p className="mt-3 text-sm text-slate-500">No comparison reports yet. Submit from the Two-Day Lab.</p>}
      {selectedReport ? <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-slate-200 pt-3"><p className="text-xs text-slate-500">Report job {selectedReport}</p><Button type="button" variant="danger" onClick={() => void deleteSelectedReport()} disabled={busy}>{deletingReport ? "Deleting…" : "Delete report"}</Button></div> : null}
      {reportContent ? <div className="mt-3"><MarkdownRenderer content={reportContent} /></div> : null}
    </section>}
    <section className="rounded-lg border border-slate-200 bg-white p-5 text-sm shadow-sm">
      <label className="font-medium">Comparison job ID<Input value={jobId} onChange={(event) => setJobId(event.target.value)} placeholder="Job ID returned after submission" className="mt-1" /></label>
      <div className="mt-2 flex items-center gap-3"><Button type="button" variant="secondary" onClick={() => void checkStatus()} disabled={busy || !jobId.trim()}>Check status</Button>{status ? <span>Status: {status}</span> : null}</div>
    </section>
    {busy ? <p className="text-sm text-slate-500">Loading…</p> : null}
    {error ? <Alert variant="danger">{error}</Alert> : null}
  </div>;
}
