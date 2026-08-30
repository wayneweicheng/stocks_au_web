"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import type { TradingSignalOverview, TradingSignalOverviewItem } from "../../lib/api/trading-signal-reports";

type Props = {
  baseUrl: string;
  initialAsOf?: string;
};

function defaultAsOf(value?: string) {
  return value || new Date().toISOString().slice(0, 10);
}

function verdictClasses(verdict: TradingSignalOverviewItem["verdict"]) {
  if (verdict === "LONG") return "border-emerald-200 bg-emerald-50 text-emerald-800";
  if (verdict === "SHORT") return "border-red-200 bg-red-50 text-red-800";
  return "border-amber-200 bg-amber-50 text-amber-800";
}

function reportHref(reportId: string) {
  return `/trading-signal-reports?public_report_id=${encodeURIComponent(reportId)}`;
}

function strategyAdminHref(signal: TradingSignalOverviewItem["signals"][number]) {
  const stockCode = signal.instrument_code.replace(/\.US$/i, "");
  const query = new URLSearchParams({
    tab: "admin",
    stock_code: stockCode,
    signal_code: signal.signal_classification,
  });
  return `/trading-signal-reports?${query.toString()}`;
}

function signalActionClasses(actionCode: string) {
  if (actionCode === "WATCH") return "border-l-4 border-amber-400 bg-amber-50/70";
  if (actionCode !== "PLAN_ENTRY") return "border-l-4 border-red-400 bg-red-50/70";
  return "";
}

function formatEndAt(value?: string | null) {
  if (!value) return "Until strategy exit";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return `${parsed.toLocaleDateString("en-AU", { day: "2-digit", month: "short", year: "numeric", timeZone: "America/New_York" })} ${parsed.toLocaleTimeString("en-AU", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: "America/New_York" })} ET`;
}

export default function TradingSignalOverviewTab({ baseUrl, initialAsOf }: Props) {
  const [asOf, setAsOf] = useState(() => defaultAsOf(initialAsOf));
  const [instrumentFilter, setInstrumentFilter] = useState("");
  const [overview, setOverview] = useState<TradingSignalOverview | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadOverview = useCallback(async () => {
    if (!asOf) return;
    setLoading(true);
    setError("");
    try {
      const query = new URLSearchParams({ as_of: asOf });
      const response = await authenticatedFetch(`${baseUrl}/api/trading-signal-reports/overview?${query}`);
      const payload = (await response.json().catch(() => ({}))) as TradingSignalOverview & { detail?: string };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      setOverview(payload);
    } catch (caught: unknown) {
      setOverview(null);
      setError(caught instanceof Error ? caught.message : "Unable to load signal overview");
    } finally {
      setLoading(false);
    }
  }, [asOf, baseUrl]);

  useEffect(() => {
    void loadOverview();
  }, [loadOverview]);

  const items = useMemo(() => {
    const filter = instrumentFilter.trim().toUpperCase();
    return (overview?.items || []).filter((item) => !filter || item.instrument_code.toUpperCase().includes(filter));
  }, [instrumentFilter, overview]);

  return (
    <div className="space-y-4">
      <section className="rounded-lg border border-indigo-100 bg-indigo-50/60 p-4 text-sm text-indigo-950">
        <p className="font-semibold">As-of signal overview</p>
        <p className="mt-1 text-indigo-900/80">
          Shows only signals whose tradable window is active on the selected date. The report date is the source date; trading starts on the next US cash session, and D1/D2/D5 horizons end after that many US cash sessions. NO SIGNAL reports and signals without available historical evidence are excluded. Data-quality errors are shown separately below and are never treated as NO SIGNAL.
        </p>
      </section>

      <section className="grid gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm sm:grid-cols-[180px_minmax(0,1fr)_auto] sm:items-end">
        <label className="text-sm font-medium text-slate-700">
          As-of date
          <Input type="date" value={asOf} onChange={(event) => setAsOf(event.target.value)} className="mt-1" />
        </label>
        <label className="text-sm font-medium text-slate-700">
          Instrument filter
          <Input placeholder="e.g. QQQ or AMD" value={instrumentFilter} onChange={(event) => setInstrumentFilter(event.target.value)} className="mt-1" />
        </label>
        <Button type="button" onClick={() => void loadOverview()} disabled={loading || !asOf}>
          {loading ? "Loading..." : "Refresh overview"}
        </Button>
      </section>

      {error ? <Alert variant="danger">{error}</Alert> : null}
      {!loading && overview && items.length === 0 && overview.data_errors.length === 0 ? <Alert variant="info">No qualifying signals with available historical evidence were found for this date.</Alert> : null}

      {!loading && overview && overview.data_errors.length > 0 ? (
        <section className="rounded-lg border border-red-200 bg-red-50 p-4 shadow-sm">
          <div className="flex items-center justify-between gap-3">
            <h2 className="text-base font-bold text-red-900">Data-quality errors</h2>
            <span className="rounded-full bg-red-200 px-2 py-0.5 text-xs font-bold text-red-900">{overview.data_errors.length}</span>
          </div>
          <p className="mt-1 text-xs text-red-800">These evaluations reached the runtime but could not produce a deterministic signal. Review the source report; they are not NO SIGNAL results.</p>
          <div className="mt-3 space-y-2">
            {overview.data_errors.map((dataError) => (
              <div key={dataError.public_report_id} className="rounded-md border border-red-200 bg-white p-3 text-sm">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="font-semibold text-slate-900">{dataError.instrument_code.replace(/\.US$/i, "")} · {dataError.report_date} · {dataError.strategy_version_code}</p>
                  <a href={reportHref(dataError.public_report_id)} className="font-semibold text-indigo-700 underline decoration-indigo-300 underline-offset-2 hover:text-indigo-900">Open report →</a>
                </div>
                <p className="mt-1 text-xs text-slate-600">{dataError.deployment_key} · {dataError.environment} · {dataError.signal_classification}</p>
                <p className="mt-1 text-xs font-medium text-red-800">{dataError.reason}</p>
              </div>
            ))}
          </div>
        </section>
      ) : null}

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {items.map((item) => (
          <article key={item.instrument_code} className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="flex items-start justify-between gap-3 border-b border-slate-200 p-4">
              <div>
                <h2 className="text-lg font-bold text-slate-950">{item.instrument_code.replace(/\.US$/i, "")}</h2>
                <p className="mt-1 text-xs text-slate-500">Latest active report: {item.latest_report_date}</p>
              </div>
              <span className={`rounded-full border px-2.5 py-1 text-xs font-bold ${verdictClasses(item.verdict)}`}>
                {item.verdict}
              </span>
            </div>
            <div className="grid grid-cols-3 gap-2 border-b border-slate-100 p-4 text-center text-xs">
              <div><strong className="block text-base text-slate-900">{item.signal_count}</strong><span className="text-slate-500">Signals</span></div>
              <div><strong className="block text-base text-emerald-700">{item.long_count}</strong><span className="text-slate-500">Long</span></div>
              <div><strong className="block text-base text-red-700">{item.short_count}</strong><span className="text-slate-500">Short</span></div>
            </div>
            <div className="divide-y divide-slate-100">
              {item.signals.map((signal) => (
                <div key={`${signal.strategy_code}-${signal.holding_period}-${signal.public_report_id}`} className={`p-4 text-sm ${signalActionClasses(signal.action_code)}`}>
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className={`font-bold ${signal.direction === "LONG" ? "text-emerald-700" : "text-red-700"}`}>
                        {signal.direction} · {signal.holding_period}
                        {signal.action_code !== "PLAN_ENTRY" ? <span className={`ml-2 rounded px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide ${signal.action_code === "WATCH" ? "bg-amber-200 text-amber-900" : "bg-red-200 text-red-900"}`}>{signal.action_code}</span> : null}
                      </p>
                      <p className="mt-1 text-xs text-slate-600">Report {signal.report_date} · Tradable {signal.tradable_date}</p>
                      <p className="mt-1 text-xs font-medium text-slate-600">
                        Ends {formatEndAt(signal.end_at)} · <a
                          href={strategyAdminHref(signal)}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="font-semibold text-indigo-700 underline decoration-indigo-300 underline-offset-2 hover:text-indigo-900"
                        >
                          {signal.signal_classification}
                        </a>
                      </p>
                    </div>
                    <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-700">
                      {signal.historical_win_rate_pct.toFixed(1)}% historical
                    </span>
                  </div>
                  <p className="mt-2 text-xs text-slate-500">
                    {signal.historical_instances} instances · <a
                      href={strategyAdminHref(signal)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="font-semibold text-indigo-700 underline decoration-indigo-300 underline-offset-2 hover:text-indigo-900"
                    >
                      {signal.strategy_code}
                    </a>
                    {signal.historical_profit_factor != null ? ` · PF ${signal.historical_profit_factor.toFixed(2)}` : ""}
                  </p>
                  <a href={reportHref(signal.public_report_id)} className="mt-2 inline-block text-xs font-semibold text-indigo-700 hover:text-indigo-900">
                    Open source report →
                  </a>
                </div>
              ))}
            </div>
          </article>
        ))}
      </section>
    </div>
  );
}
