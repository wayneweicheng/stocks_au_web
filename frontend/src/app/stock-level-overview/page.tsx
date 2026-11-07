"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { mapAsOfTime, mapStockCode, parseStockMap, type StockMapReport } from "../support-resistance/stockMapLevels";
import { reportSymbol, sortByZoneDistance, topLevels, type RankedLevel, type SortChoice, type SortSide } from "./overview";

const QUOTE_BATCH_SIZE = 40;
type Row = { symbol: string; report: StockMapReport; price: number | null; fetchedAt: string | null; asOf: string | null; olderMap: boolean; supports: RankedLevel[]; resistances: RankedLevel[]; error?: string };
const empty = (symbol: string, report: StockMapReport): Row => ({ symbol, report, price: null, fetchedAt: null, asOf: null, olderMap: false, supports: [], resistances: [] });
const formatPrice = (price: number) => price.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

async function json(url: string, signal: AbortSignal, options: RequestInit = {}): Promise<Record<string, unknown>> {
  const response = await authenticatedFetch(url, { ...options, cache: "no-store", signal });
  const payload = await response.json();
  if (!response.ok) throw new Error(typeof payload.detail === "string" ? payload.detail : `HTTP ${response.status}`);
  return payload;
}

function LevelCell({ levels, side, price }: { levels: RankedLevel[]; side: SortSide; price: number | null }) {
  if (price === null) return <span className="text-slate-400">IB live price unavailable</span>;
  if (!levels.length) return <span className="text-slate-400">No ranked {side} zones</span>;
  return <div className="space-y-1.5">{levels.map(({ zone, distancePct }, index) => <div key={`${zone.sourceSide}-${zone.rank}-${zone.price}-${index}`} className="flex flex-wrap items-baseline justify-between gap-x-2 rounded-md bg-slate-50 px-2 py-1.5 text-xs">
    <span className="font-semibold text-slate-800">{formatPrice(zone.range_low)}–{formatPrice(zone.range_high)}</span>
    <span className={distancePct === 0 ? "font-semibold text-amber-700" : side === "support" ? "font-medium text-emerald-700" : "font-medium text-rose-700"}>{distancePct === 0 ? "Inside zone · 0.00% away" : `${distancePct.toFixed(2)}% away`}</span>
    <span className="w-full text-[11px] text-slate-500">#{index + 1} by strength · score {zone.score === null ? "—" : zone.score} · report {zone.sourceSide} rank {zone.rank}</span>
  </div>)}</div>;
}

export default function StockLevelOverviewPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [loaded, setLoaded] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState("");
  const [sort, setSort] = useState<SortChoice>(null);
  const controller = useRef<AbortController | null>(null);

  const refresh = useCallback(async () => {
    controller.current?.abort();
    const abort = new AbortController();
    controller.current = abort;
    setRows([]); setTotal(0); setLoaded(0); setError(""); setLoading(true);
    try {
      const payload = await json(`${baseUrl}/api/stock-map-reports`, abort.signal);
      const reports = (Array.isArray(payload.items) ? payload.items : []) as StockMapReport[];
      const latest = new Map<string, StockMapReport>();
      for (const report of [...reports].sort((a, b) => (b.created_at || "").localeCompare(a.created_at || ""))) {
        const symbol = reportSymbol(report);
        if (symbol && !latest.has(symbol) && (!report.status || report.status.toLowerCase() === "succeeded")) latest.set(symbol, report);
      }
      const selected = [...latest.entries()];
      if (abort.signal.aborted) return;
      setTotal(selected.length);
      // Batch quote-only IB requests rather than opening one IB session per report.
      for (let offset = 0; offset < selected.length && !abort.signal.aborted; offset += QUOTE_BATCH_SIZE) {
        const batch = selected.slice(offset, offset + QUOTE_BATCH_SIZE);
        let prices: Record<string, unknown> = {};
        let fetchedAt: string | null = null;
        let quoteError: string | null = null;
        try {
          const quotePayload = await json(`${baseUrl}/api/stock-map-live-prices`, abort.signal, {
            method: "POST", headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ symbols: batch.map(([symbol]) => symbol) }),
          });
          if (quotePayload.prices && typeof quotePayload.prices === "object" && !Array.isArray(quotePayload.prices)) prices = quotePayload.prices as Record<string, unknown>;
          fetchedAt = typeof quotePayload.fetched_at_utc === "string" ? quotePayload.fetched_at_utc : null;
        } catch (exc) {
          if (abort.signal.aborted) return;
          quoteError = exc instanceof Error ? exc.message : String(exc);
        }
        let cursor = 0;
        await Promise.all(Array.from({ length: Math.min(4, batch.length) }, async () => {
          while (cursor < batch.length && !abort.signal.aborted) {
            const [symbol, report] = batch[cursor++];
            const candidate = prices[symbol];
            const price = typeof candidate === "number" && Number.isFinite(candidate) && candidate > 0 ? candidate : null;
            let row: Row = { ...empty(symbol, report), price, fetchedAt: price !== null ? fetchedAt : null,
              error: quoteError ? `IB quotes unavailable: ${quoteError}` : undefined };
            try {
              const mapPayload = await json(`${baseUrl}/api/stock-map-reports/${encodeURIComponent(report.job_id)}/json`, abort.signal);
              const map = parseStockMap(mapPayload.data ?? mapPayload);
              if (!map) throw new Error("No readable Stock Map JSON");
              if (mapStockCode(map) !== symbol) throw new Error("Report symbol does not match stock");
              const asOf = mapAsOfTime(map, report)?.label ?? null;
              const mapTimestamp = typeof map.as_of_et === "string" ? Date.parse(map.as_of_et) : NaN;
              row = { ...row, asOf, olderMap: Number.isFinite(mapTimestamp) && Date.now() - mapTimestamp > 7 * 86_400_000,
                ...(price !== null ? topLevels(map, price) : { supports: [], resistances: [] }) };
            } catch (exc) {
              if (abort.signal.aborted) return;
              row = { ...row, error: exc instanceof Error ? exc.message : String(exc) };
            }
            if (!abort.signal.aborted) { setRows((current) => [...current, row]); setLoaded((current) => current + 1); }
          }
        }));
      }
    } catch (exc) {
      if (!abort.signal.aborted) setError(exc instanceof Error ? exc.message : String(exc));
    } finally {
      if (!abort.signal.aborted) setLoading(false);
    }
  }, [baseUrl]);

  useEffect(() => { void refresh(); return () => controller.current?.abort(); }, [refresh]);
  const shown = useMemo(() => sortByZoneDistance(rows.filter((row) => row.symbol.includes(filter.trim().toUpperCase())), sort), [rows, filter, sort]);
  const toggleSort = (side: SortSide) => setSort((previous) => ({ side, direction: previous?.side === side && previous.direction === "asc" ? "desc" : "asc" }));
  const sortHeader = (side: SortSide) => <th className="w-[31%] px-4 py-3" aria-sort={sort?.side === side ? sort.direction === "asc" ? "ascending" : "descending" : "none"}>
    <button type="button" onClick={() => toggleSort(side)} className="inline-flex items-center gap-2 rounded text-left hover:text-indigo-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-600"
      aria-label={`Sort all stocks by closest of top 2 ${side} zones; ${sort?.side === side && sort.direction === "asc" ? "descending" : "ascending"}`}>
      Top 2 {side} zones <span aria-hidden="true" className="text-base text-indigo-600">{sort?.side === side ? sort.direction === "asc" ? "↑" : "↓" : "↕"}</span>
    </button>
  </th>;

  return <div className="space-y-5">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div><h1 className="text-2xl font-bold text-slate-900">Stock levels overview</h1><p className="mt-1 text-sm text-slate-600">Compare the two strongest mapped zones on each side of the IB real-time stock price.</p></div>
      <button type="button" onClick={() => void refresh()} disabled={loading} className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700 disabled:opacity-50">{loading ? "Loading…" : "Refresh"}</button>
    </div>
    <p className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">Saved Stock Maps are not refreshed automatically. Only IB real-time stock quotes are used: missing or delayed quotes show N/A, never a 30-minute close. Zones are classified against the IB price, ranked by report score (then original rank), and their distance is measured to the nearest zone edge as a percentage of that price. A zone spanning the price reads “Inside zone”. Quotes are snapshots taken on refresh; check map dates and current conditions before acting.</p>
    <div className="flex flex-wrap items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
      <label className="text-sm font-medium text-slate-700">Symbol <input value={filter} onChange={(event) => setFilter(event.target.value)} placeholder="Search symbol" className="ml-2 rounded-md border border-slate-300 px-3 py-1.5 text-sm" /></label>
      <span className="ml-auto text-xs text-slate-500">{loading ? `Loaded ${loaded}/${total}` : `${shown.length} shown`} · {total} symbols with reports · Click a zone column heading to sort by the nearest of its top two (click again to reverse).</span>
    </div>
    {error && <p role="alert" className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-800">Could not load reports: {error}</p>}
    <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm"><table className="w-full min-w-[850px] text-left text-sm"><thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-600"><tr><th className="px-4 py-3">Stock / map</th><th className="px-4 py-3">IB live price</th>{sortHeader("support")}{sortHeader("resistance")}</tr></thead><tbody className="divide-y divide-slate-100">{shown.map((row) => <tr key={row.symbol} className="align-top"><td className="px-4 py-3"><Link className="font-bold text-indigo-700 hover:underline" href={`/support-resistance?stock=${encodeURIComponent(row.symbol)}&tab=stock-map`}>{row.symbol}</Link><div className="mt-1 text-xs text-slate-500">Map as-of: {row.asOf || "Unknown"}</div>{row.olderMap && <div className="mt-1 text-xs font-semibold text-amber-700">Map older than 7 days</div>}<Link href={`/stock-map-reports/${encodeURIComponent(row.report.job_id)}/mapped-levels?stock_code=${encodeURIComponent(row.symbol)}`} className="mt-1 inline-block text-xs text-indigo-600 hover:underline">Report details ↗</Link></td><td className="px-4 py-3"><div className="font-semibold text-slate-800">{row.price === null ? "N/A" : formatPrice(row.price)}</div><div className="mt-1 text-xs text-slate-500">{row.fetchedAt ? `IB quote fetched ${row.fetchedAt.replace("T", " ").slice(0, 19)} UTC` : "IB real-time quote unavailable"}</div>{row.error && <div className="mt-1 max-w-[220px] break-words text-xs text-red-700" title={row.error}>{row.error}</div>}</td><td className="px-4 py-3"><LevelCell levels={row.supports} side="support" price={row.price} /></td><td className="px-4 py-3"><LevelCell levels={row.resistances} side="resistance" price={row.price} /></td></tr>)}</tbody></table>{!loading && !error && !rows.length && <p className="p-8 text-center text-sm text-slate-500">No Stock Map reports found. <Link className="text-indigo-600 underline" href="/stock-map-reports">Create a Stock Map</Link> first.</p>}{!loading && rows.length > 0 && !shown.length && <p className="p-6 text-center text-sm text-slate-500">No matching symbols.</p>}</div>
  </div>;
}
