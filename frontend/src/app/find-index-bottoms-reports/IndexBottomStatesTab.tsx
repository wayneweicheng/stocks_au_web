"use client";

import { useCallback, useEffect, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { authenticatedFetch } from "../utils/authenticatedFetch";

const PAGE_SIZE = 20;
const HORIZONS = [1, 2, 3, 5, 10] as const;

type Close = { price: number; timeframe: string; bar_end_et: string } | null;
type Change = { date: string; close: Close; percent: number | null };
type SymbolPrices = { base: Close; returns: Record<string, Change> };
type TimelineItem = {
  job_id: string;
  as_of_et: string | null;
  state: string;
  description: string;
  score: number | null;
  prices: Record<"SPY" | "QQQ", SymbolPrices> | null;
};
type TimelinePage = { items: TimelineItem[]; page: number; page_size: number; total: number; price_error: string | null };

function etTime(value: string | null) {
  return value ? `${value.slice(0, 10)} ${value.slice(11, 16)} ET` : "As-at unavailable";
}

function number(value: number | null) {
  return value === null ? "—" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function changeCell(change?: Change) {
  if (!change || change.percent === null) return <span className="text-slate-400" title={change ? `No completed close on ${change.date}` : "Price unavailable"}>—</span>;
  const changeText = `${change.percent >= 0 ? "+" : ""}${change.percent.toFixed(2)}%`;
  const close = change.close;
  return <span className={change.percent >= 0 ? "text-emerald-700" : "text-red-700"}
    title={`${change.date} cash close ${number(close?.price ?? null)} (${close?.timeframe || "n/a"}, ${etTime(close?.bar_end_et ?? null)})`}>{changeText}</span>;
}

export function PriceTable({ item }: { item: TimelineItem }) {
  return <div className="overflow-x-auto">
    <table className="min-w-[750px] w-full text-left text-sm">
      <thead><tr className="border-b border-slate-200 text-xs uppercase tracking-wide text-slate-500">
        <th className="p-2">Index</th><th className="p-2">At report as-at</th>
        {HORIZONS.map((day) => <th key={day} className="p-2">D{day}</th>)}
      </tr></thead>
      <tbody>{(["SPY", "QQQ"] as const).map((symbol) => {
        const prices = item.prices?.[symbol];
        return <tr key={symbol} className="border-b border-slate-100 last:border-0">
          <th className="p-2 font-semibold text-slate-700">{symbol}</th>
          <td className="p-2 font-mono text-slate-800">{number(prices?.base?.price ?? null)}
            {prices?.base ? <span className="ml-1 text-xs text-slate-500" title={`Completed ${prices.base.timeframe} candle ending ${etTime(prices.base.bar_end_et)}`}>({prices.base.timeframe})</span> : null}
          </td>
          {HORIZONS.map((day) => <td key={day} className="p-2 font-mono" title={prices?.returns?.[String(day)]?.date || ""}>{changeCell(prices?.returns?.[String(day)])}</td>)}
        </tr>;
      })}</tbody>
    </table>
  </div>;
}

export default function IndexBottomStatesTab() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [page, setPage] = useState(1);
  const [data, setData] = useState<TimelinePage | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const load = useCallback(async (signal?: AbortSignal) => {
    setLoading(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/find-index-bottoms-reports/states?page=${page}&page_size=${PAGE_SIZE}`, { cache: "no-store", signal });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.detail || `Unable to load index-bottom states: HTTP ${response.status}`);
      if (!signal?.aborted) setData(payload as TimelinePage);
    } catch (exc) {
      if (!signal?.aborted) setError(exc instanceof Error ? exc.message : "Unable to load index-bottom states.");
    } finally {
      if (!signal?.aborted) setLoading(false);
    }
  }, [baseUrl, page]);
  useEffect(() => {
    const controller = new AbortController();
    void load(controller.signal);
    return () => controller.abort();
  }, [load]);

  const pages = Math.max(1, Math.ceil((data?.total || 0) / PAGE_SIZE));
  return <section className="space-y-4">
    <div className="flex flex-wrap items-center justify-between gap-2">
      <div><h2 className="text-lg font-semibold text-slate-900">Report states and subsequent SPY/QQQ closes</h2>
        <p className="text-sm text-slate-600">One entry per report as-at (New York time), including multiple reports on one day. D1 is the next US trading day after the as-at date; D2/D3/D5/D10 count trading sessions. Changes compare that session’s cash close with the latest completed 5M price at as-at, or a newer available 30M bar. Hover for price dates and source timestamps.</p></div>
      <Button type="button" variant="secondary" onClick={() => void load()} disabled={loading}>Refresh</Button>
    </div>
    {error ? <Alert variant="danger">{error}</Alert> : null}
    {data?.price_error ? <Alert variant="warning">{data.price_error}</Alert> : null}
    {loading ? <div className="text-sm text-slate-500">Loading reports and prices…</div> : null}
    {!loading && data?.items.length === 0 ? <div className="text-sm text-slate-500">No completed reports found.</div> : null}
    {!loading ? data?.items.map((item) => <article key={item.job_id} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <div><div className="text-xs font-medium text-slate-500">{etTime(item.as_of_et)} · Report {item.job_id}</div>
          <h3 className="mt-1 font-semibold text-slate-900">{item.state}</h3></div>
        {item.score !== null ? <span className="rounded bg-slate-100 px-2 py-1 text-xs text-slate-700">Raw confidence {item.score}/100</span> : null}
      </div>
      <div className="mt-3"><PriceTable item={item} /></div>
      <details className="mt-3 rounded border border-slate-200 bg-slate-50 p-3 text-sm">
        <summary className="cursor-pointer font-medium text-slate-700">Report reasoning, score and evidence completeness</summary>
        <div className="mt-3 whitespace-pre-wrap text-slate-700">{item.description.replace(/\*{1,2}/g, "").replace(/^#{1,4}\s*/gm, "") || "No extractable state description; consult the original report."}</div>
      </details>
    </article>) : null}
    <div className="flex items-center justify-between gap-3 text-sm text-slate-700">
      <span>{data?.total ?? 0} reports · page {page} of {pages}</span>
      <div className="flex gap-2"><Button type="button" variant="secondary" disabled={page <= 1 || loading} onClick={() => setPage((current) => current - 1)}>Previous</Button>
        <Button type="button" variant="secondary" disabled={page >= pages || loading} onClick={() => setPage((current) => current + 1)}>Next</Button></div>
    </div>
  </section>;
}
