"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import TradingSignalAdminTab from "./TradingSignalAdminTab";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { buildTradingSignalReportsQuery, TradingSignalReport, TradingSignalReportPage } from "../../lib/api/trading-signal-reports";

function formatDateTime(value: string) {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
}

export default function TradingSignalReportsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const initialReportId = useRef(searchParams.get("public_report_id") || "");
  const [reports, setReports] = useState<TradingSignalReport[]>([]);
  const [selectedId, setSelectedId] = useState(searchParams.get("public_report_id") || "");
  const [search, setSearch] = useState(searchParams.get("search") || "");
  const [strategy, setStrategy] = useState(searchParams.get("strategy_code") || "");
  const [instrument, setInstrument] = useState(searchParams.get("instrument_code") || "");
  const [environment, setEnvironment] = useState(searchParams.get("environment") || "");
  const [reportKind, setReportKind] = useState(searchParams.get("report_kind") || "");
  const [dateFrom, setDateFrom] = useState(searchParams.get("date_from") || "");
  const [dateTo, setDateTo] = useState(searchParams.get("date_to") || "");
  const [activeTab, setActiveTab] = useState(searchParams.get("tab") === "admin" ? "admin" : "reports");
  const [cursor, setCursor] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reportUrl, setReportUrl] = useState<string | null>(null);
  const [reportLoading, setReportLoading] = useState(false);
  const [reportError, setReportError] = useState("");
  const reportUrls = useRef<Record<string, string>>({});
  const selected = useMemo(() => reports.find((item) => item.public_report_id === selectedId) || null, [reports, selectedId]);

  const syncUrl = useCallback((reportId?: string) => {
    const query = buildTradingSignalReportsQuery({ strategy_code: strategy || undefined, instrument_code: instrument || undefined, environment: environment || undefined, report_kind: reportKind || undefined, search: search || undefined, date_from: dateFrom || undefined, date_to: dateTo || undefined, public_report_id: reportId || selectedId || undefined, tab: activeTab === "admin" ? "admin" : undefined });
    router.replace(`${pathname}${query ? `?${query}` : ""}`, { scroll: false });
  }, [activeTab, dateFrom, dateTo, environment, instrument, pathname, reportKind, router, search, selectedId, strategy]);

  const loadReports = useCallback(async (append = false, reportId?: string) => {
    setLoading(true);
    setError("");
    try {
      const query = buildTradingSignalReportsQuery({ strategy_code: strategy || undefined, instrument_code: instrument || undefined, environment: environment || undefined, report_kind: reportKind || undefined, search: search || undefined, date_from: dateFrom || undefined, date_to: dateTo || undefined, limit: "50", cursor: append ? cursor || undefined : undefined });
      const response = await authenticatedFetch(`${baseUrl}/api/trading-signal-reports?${query}`);
      const payload = (await response.json().catch(() => ({}))) as Partial<TradingSignalReportPage> & { detail?: string };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      let items = payload.items || [];
      if (!append && reportId && !items.some((item) => item.public_report_id === reportId)) {
        const requestedQuery = buildTradingSignalReportsQuery({ public_report_id: reportId, limit: "1" });
        const requestedResponse = await authenticatedFetch(`${baseUrl}/api/trading-signal-reports?${requestedQuery}`);
        if (requestedResponse.ok) {
          const requestedPayload = (await requestedResponse.json().catch(() => ({}))) as Partial<TradingSignalReportPage>;
          items = [...(requestedPayload.items || []), ...items];
        }
      }
      setReports((current) => (append ? [...current, ...items] : items));
      setCursor(payload.next_cursor || null);
      if (!append) setSelectedId((current) => (current && items.some((item) => item.public_report_id === current) ? current : items[0]?.public_report_id || ""));
    } catch (caught: unknown) {
      setError(caught instanceof Error ? caught.message : "Unable to load reports");
      if (!append) setReports([]);
    } finally {
      setLoading(false);
    }
  }, [baseUrl, cursor, dateFrom, dateTo, environment, instrument, reportKind, search, strategy]);

  useEffect(() => { void loadReports(false, initialReportId.current || undefined); }, [loadReports]);
  useEffect(() => { syncUrl(); }, [selectedId, syncUrl]);

  useEffect(() => {
    let active = true;
    setReportError("");
    setReportUrl(null);

    if (!selected) {
      setReportLoading(false);
      return () => { active = false; };
    }

    const cachedUrl = reportUrls.current[selected.public_report_id];
    if (cachedUrl) {
      setReportUrl(cachedUrl);
      setReportLoading(false);
      return () => { active = false; };
    }

    setReportLoading(true);
    void authenticatedFetch(`${baseUrl}${selected.html_url}`)
      .then(async (response) => {
        if (!response.ok) {
          const payload = (await response.json().catch(() => ({}))) as { detail?: string };
          throw new Error(payload.detail || `HTTP ${response.status}`);
        }
        return response.text();
      })
      .then((html) => {
        if (!active) return;
        const objectUrl = URL.createObjectURL(new Blob([html], { type: "text/html;charset=utf-8" }));
        reportUrls.current[selected.public_report_id] = objectUrl;
        setReportUrl(objectUrl);
      })
      .catch((caught: unknown) => {
        if (!active) return;
        setReportError(caught instanceof Error ? caught.message : "Unable to load report");
      })
      .finally(() => {
        if (active) setReportLoading(false);
      });

    return () => { active = false; };
  }, [baseUrl, selected]);

  useEffect(() => () => {
    Object.values(reportUrls.current).forEach((objectUrl) => URL.revokeObjectURL(objectUrl));
  }, []);

  const strategies = Array.from(new Set(reports.map((item) => item.strategy_code))).sort();
  const environments = Array.from(new Set(reports.map((item) => item.environment))).sort();
  const kinds = Array.from(new Set(reports.map((item) => item.report_kind))).sort();
  return (
    <div className="space-y-6">
      <PageHeader title="Trading Signal Reports" subtitle="Browse immutable reports from any registered strategy and instrument." actions={activeTab === "reports" ? <Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={loading}>{loading ? "Refreshing..." : "Refresh"}</Button> : null} />
      <div role="tablist" aria-label="Trading signal reports sections" className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        <button type="button" role="tab" aria-selected={activeTab === "reports"} onClick={() => setActiveTab("reports")} className={`rounded-md px-4 py-2 text-sm font-medium ${activeTab === "reports" ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-50"}`}>Reports</button>
        <button type="button" role="tab" aria-selected={activeTab === "admin"} onClick={() => setActiveTab("admin")} className={`rounded-md px-4 py-2 text-sm font-medium ${activeTab === "admin" ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-50"}`}>Strategy Admin</button>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {activeTab === "reports" ? <>
      <section className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm md:grid-cols-4">
        <Input aria-label="Search reports" placeholder="Search reports" value={search} onChange={(event) => setSearch(event.target.value)} />
        <Input aria-label="Date from" type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} />
        <Input aria-label="Date to" type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} />
        <select aria-label="Strategy" value={strategy} onChange={(event) => setStrategy(event.target.value)} className="rounded-md border border-slate-300 px-3 py-2 text-sm"><option value="">All strategies</option>{strategies.map((item) => <option key={item}>{item}</option>)}</select>
        <Input aria-label="Instrument" placeholder="Instrument" value={instrument} onChange={(event) => setInstrument(event.target.value)} />
        <select aria-label="Environment" value={environment} onChange={(event) => setEnvironment(event.target.value)} className="rounded-md border border-slate-300 px-3 py-2 text-sm"><option value="">All environments</option>{environments.map((item) => <option key={item}>{item}</option>)}</select>
        <select aria-label="Report kind" value={reportKind} onChange={(event) => setReportKind(event.target.value)} className="rounded-md border border-slate-300 px-3 py-2 text-sm"><option value="">All report kinds</option>{kinds.map((item) => <option key={item}>{item}</option>)}</select>
        <Button type="button" onClick={() => void loadReports()}>Apply filters</Button>
      </section>
      <div className="grid gap-4 lg:grid-cols-[360px_minmax(0,1fr)]">
        <aside className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm"><div className="max-h-[calc(100vh-330px)] min-h-[520px] overflow-y-auto p-2">{loading && reports.length === 0 ? <div className="p-8 text-center text-sm text-slate-500">Loading reports...</div> : reports.length === 0 ? <div className="p-8 text-center text-sm text-slate-500">No reports found.</div> : reports.map((report) => <button key={report.public_report_id} type="button" onClick={() => { setSelectedId(report.public_report_id); syncUrl(report.public_report_id); }} className={`w-full rounded-md px-3 py-3 text-left text-sm ${report.public_report_id === selectedId ? "bg-indigo-50 text-indigo-800" : "text-slate-700 hover:bg-slate-50"}`}><span className="block font-semibold">{report.title}</span><span className="mt-1 block text-xs text-slate-500">{report.report_date} · {report.strategy_code} · {report.report_kind}</span><span className="mt-1 block text-xs text-slate-500">{formatDateTime(report.generated_utc)}</span><span className="mt-2 inline-flex rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">{report.is_current ? "Current" : `Revision ${report.revision_no}`}</span></button>)}{cursor ? <Button type="button" variant="secondary" className="m-2 w-[calc(100%-1rem)]" onClick={() => void loadReports(true)} disabled={loading}>Load more</Button> : null}</div></aside>
        <section className="min-w-0 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm"><div className="border-b border-slate-200 p-4">{selected ? <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"><div><h2 className="text-lg font-semibold text-slate-900">{selected.title}</h2><p className="mt-1 text-xs text-slate-500">{selected.strategy_code} {selected.strategy_version_code} · {selected.environment} · {selected.report_date}</p><p className="mt-1 text-xs text-slate-500">Subject {selected.subject_instrument_code || "n/a"} · Execution {selected.execution_instrument_code || "n/a"} · {selected.is_current ? "Current" : `Superseded revision ${selected.revision_no}`}</p></div>{reportUrl ? <a href={reportUrl} target="_blank" rel="noopener noreferrer" className="inline-flex shrink-0 rounded-md border border-slate-200 px-3 py-2 text-sm text-slate-700 hover:bg-slate-50">Open report</a> : <span className="inline-flex shrink-0 rounded-md border border-slate-200 px-3 py-2 text-sm text-slate-400">{reportLoading ? "Loading report..." : "Open report"}</span>}</div> : <h2 className="text-lg font-semibold text-slate-900">Select a report</h2>}</div><div className="min-h-[620px] p-5">{reportError ? <Alert variant="danger">{reportError}</Alert> : reportLoading ? <div className="flex min-h-[520px] items-center justify-center text-sm text-slate-500">Loading report...</div> : reportUrl && selected ? <iframe title={selected.title} src={reportUrl} sandbox="" className="h-[calc(100vh-330px)] min-h-[620px] w-full rounded-md border border-slate-200 bg-white" /> : <div className="flex min-h-[520px] items-center justify-center text-sm text-slate-500">Select a report to view it.</div>}</div></section>
      </div>
      </> : <TradingSignalAdminTab baseUrl={baseUrl} />}
    </div>
  );
}
