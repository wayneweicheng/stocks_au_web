"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Row = Record<string, any>;

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function defaultFromDate() {
  const d = new Date();
  d.setDate(d.getDate() - 180);
  return isoDate(d);
}

function num(v: any): number | null {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function fmt(v: any, digits = 2) {
  const n = num(v);
  return n === null ? "-" : n.toLocaleString(undefined, { maximumFractionDigits: digits });
}

function dateLabel(value: string) {
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function OverlayBarChart({ rows }: { rows: Row[] }) {
  const width = 1000;
  const height = 390;
  const pad = 34;
  const rightPad = 62;
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const gexValues = rows.map((r) => num(r.TotalNetGammaChange)).filter((v): v is number => v !== null);
  const closeChangeValues = rows.map((r) => num(r.CloseChange)).filter((v): v is number => v !== null);
  const closePriceValues = rows.map((r) => num(r.Close)).filter((v): v is number => v !== null);
  if (!rows.length || !gexValues.length || !closeChangeValues.length || !closePriceValues.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const maxGex = Math.max(...gexValues.map((v) => Math.abs(v))) || 1;
  const maxCloseChange = Math.max(...closeChangeValues.map((v) => Math.abs(v))) || 1;
  const closePriceMin = Math.min(...closePriceValues);
  const closePriceMax = Math.max(...closePriceValues);
  const closePricePad = (closePriceMax - closePriceMin || 1) * 0.08;
  const closeAxisMin = closePriceMin - closePricePad;
  const closeAxisMax = closePriceMax + closePricePad;
  const chartLeft = pad;
  const chartRight = width - rightPad;
  const chartWidth = chartRight - chartLeft;
  const chartTop = pad;
  const chartBottom = height - pad;
  const chartHeight = chartBottom - chartTop;
  const zeroY = height / 2;
  const step = chartWidth / rows.length;
  const barW = Math.max(3, step * 0.62);
  const yGex = (v: number) => zeroY - (v / maxGex) * (height / 2 - pad);
  const yCloseChange = (v: number) => zeroY - (v / maxCloseChange) * (height / 2 - pad);
  const xFor = (i: number) => chartLeft + i * step + step / 2;
  const yClosePrice = (v: number) => chartBottom - ((v - closeAxisMin) / (closeAxisMax - closeAxisMin || 1)) * chartHeight;
  const closePath = rows.map((r, i) => {
    const close = num(r.Close);
    return close === null ? null : `${xFor(i).toFixed(1)},${yClosePrice(close).toFixed(1)}`;
  }).filter(Boolean).join(" ");
  const activeRow = activeIndex === null ? null : rows[activeIndex];
  const activeX = activeIndex === null ? null : xFor(activeIndex);
  const updateActiveIndex = (event: any) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const chartX = ((event.clientX - rect.left) / rect.width) * width;
    const clampedX = Math.max(chartLeft, Math.min(chartRight, chartX));
    const index = Math.round((clampedX - chartLeft - step / 2) / step);
    setActiveIndex(Math.max(0, Math.min(rows.length - 1, index)));
  };

  return (
    <div>
      <div className="overflow-x-auto">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="min-w-[900px] w-full touch-pan-x cursor-crosshair select-none"
          role="img"
          aria-label="Total net gamma change and close change by date"
          onPointerMove={updateActiveIndex}
          onPointerLeave={() => setActiveIndex(null)}
        >
          <rect width={width} height={height} fill="white" />
          {[0.25, 0.5, 0.75].map((r) => <line key={r} x1={chartLeft} x2={chartRight} y1={chartTop + r * chartHeight} y2={chartTop + r * chartHeight} stroke="#f1f5f9" />)}
          <line x1={chartLeft} x2={chartRight} y1={zeroY} y2={zeroY} stroke="#94a3b8" />
          {rows.map((r, i) => {
            const x = chartLeft + i * step + (step - barW) / 2;
            const g = num(r.TotalNetGammaChange);
            const c = num(r.CloseChange);
            const isActive = activeIndex === i;
            return (
              <g key={r.ObservationDate}>
                {g !== null ? <rect x={x} y={Math.min(yGex(g), zeroY)} width={barW} height={Math.abs(zeroY - yGex(g))} fill="#0f766e" opacity={isActive ? "0.9" : "0.62"} stroke={isActive ? "#134e4a" : "none"} strokeWidth="1.2" /> : null}
                {c !== null ? <rect x={x + barW * 0.18} y={Math.min(yCloseChange(c), zeroY)} width={barW * 0.64} height={Math.abs(zeroY - yCloseChange(c))} fill="#f97316" opacity={isActive ? "0.9" : "0.62"} stroke={isActive ? "#9a3412" : "none"} strokeWidth="1.2" /> : null}
              </g>
            );
          })}
          {closePath ? <polyline points={closePath} fill="none" stroke="#2563eb" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" /> : null}
          <line x1={chartRight} x2={chartRight} y1={chartTop} y2={chartBottom} stroke="#bfdbfe" />
          {[closeAxisMax, (closeAxisMax + closeAxisMin) / 2, closeAxisMin].map((value, i) => (
            <g key={i}>
              <line x1={chartRight} x2={chartRight + 5} y1={i === 0 ? chartTop : i === 1 ? chartTop + chartHeight / 2 : chartBottom} y2={i === 0 ? chartTop : i === 1 ? chartTop + chartHeight / 2 : chartBottom} stroke="#60a5fa" />
              <text x={chartRight + 8} y={(i === 0 ? chartTop : i === 1 ? chartTop + chartHeight / 2 : chartBottom) + 4} fill="#2563eb" fontSize="11">{fmt(value)}</text>
            </g>
          ))}
          {activeRow && activeX !== null ? (
            <g pointerEvents="none">
              <line x1={activeX} x2={activeX} y1={chartTop} y2={chartBottom} stroke="#334155" strokeDasharray="4 5" opacity="0.45" />
              {num(activeRow.TotalNetGammaChange) !== null ? <circle cx={activeX} cy={yGex(num(activeRow.TotalNetGammaChange) as number)} r="4.5" fill="#0f766e" stroke="white" strokeWidth="2" /> : null}
              {num(activeRow.CloseChange) !== null ? <circle cx={activeX + barW * 0.18} cy={yCloseChange(num(activeRow.CloseChange) as number)} r="4.5" fill="#f97316" stroke="white" strokeWidth="2" /> : null}
              {num(activeRow.Close) !== null ? <circle cx={activeX} cy={yClosePrice(num(activeRow.Close) as number)} r="5" fill="#2563eb" stroke="white" strokeWidth="2" /> : null}
            </g>
          ) : null}
          <rect x={chartLeft} y={chartTop} width={chartWidth} height={chartHeight} fill="transparent" />
          <text x={pad} y="18" fill="#475569" fontSize="13">Total net gamma change, close change and close price</text>
          <text x={chartRight} y="18" fill="#2563eb" fontSize="12" textAnchor="end">Close price</text>
          <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{dateLabel(rows[0].ObservationDate)}</text>
          <text x={chartRight} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(rows[rows.length - 1].ObservationDate)}</text>
        </svg>
      </div>
      <aside className="mt-3 min-h-[82px] rounded-md bg-slate-950 p-4 text-sm text-slate-100" aria-live="polite">
        {activeRow ? (
          <div className="grid gap-3 md:grid-cols-[minmax(140px,0.7fr)_repeat(3,minmax(150px,1fr))] md:items-center">
            <div className="font-semibold">{dateLabel(String(activeRow.ObservationDate))}</div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-teal-200">Net Gamma Change</div><div className="font-medium text-teal-100">{fmt(activeRow.TotalNetGammaChange, 0)}</div></div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-orange-200">Close Change</div><div className="font-medium text-orange-100">{fmt(activeRow.CloseChange)}</div></div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-blue-200">Close</div><div className="font-medium text-blue-100">{fmt(activeRow.Close)}</div></div>
          </div>
        ) : (
          <div className="flex min-h-[50px] items-center text-xs text-slate-400">Hover the chart to inspect a data point.</div>
        )}
      </aside>
      <div className="mt-2 flex flex-wrap gap-4 text-xs text-slate-600"><span><span className="mr-1 inline-block h-2 w-6 rounded bg-teal-700" />Total Net Gamma Change</span><span><span className="mr-1 inline-block h-2 w-6 rounded bg-orange-500" />Close Change</span><span><span className="mr-1 inline-block h-2 w-6 rounded bg-blue-600" />Close Price</span></div>
    </div>
  );
}

export default function NetGexVsPriceChangePage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [stockCode, setStockCode] = useState("QQQ.US");
  const [dateFrom, setDateFrom] = useState(defaultFromDate);
  const [dateTo, setDateTo] = useState(() => isoDate(new Date()));
  const [data, setData] = useState<{ stock_code: string; rows: Row[]; count: number } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ stock_code: stockCode.trim().toUpperCase(), date_from: dateFrom, date_to: dateTo });
      const res = await authenticatedFetch(`${baseUrl}/api/us-market-dashboards/net-gex-vs-price-change?${params}`, { cache: "no-store" });
      const body = await res.json();
      if (!res.ok) throw new Error(body?.detail || `HTTP ${res.status}`);
      setData(body);
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, dateFrom, dateTo, stockCode]);

  useEffect(() => { void load(); }, []);
  const recentRows = useMemo(() => [...(data?.rows || [])].reverse().slice(0, 30), [data]);
  const submit = (e: FormEvent) => { e.preventDefault(); void load(); };

  return (
    <div className="space-y-6">
      <PageHeader title="Net GEX vs Price Change" subtitle="Overlay of total net gamma change and close price change, migrated from the Streamlit bar chart." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card><CardHeader><CardTitle>Filters</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_1fr_auto] md:items-end"><label className="text-sm"><span className="mb-1 block text-slate-600">Stock Code</span><Input value={stockCode} onChange={(e) => setStockCode(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Start Date</span><Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">End Date</span><Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} /></label><Button type="submit" disabled={loading}>Apply</Button></form></CardContent></Card>
      <Card><CardHeader><CardTitle>{data?.stock_code || stockCode.toUpperCase()} Gamma Change vs Close Change</CardTitle></CardHeader><CardContent><OverlayBarChart rows={data?.rows || []} /></CardContent></Card>
      <Card><CardHeader><CardTitle>Recent History</CardTitle></CardHeader><CardContent><div className="overflow-x-auto rounded-md border border-slate-200"><table className="min-w-full text-sm"><thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Date</th><th className="px-3 py-3 text-right">Close</th><th className="px-3 py-3 text-right">Close Change</th><th className="px-3 py-3 text-right">Total Net Gamma Change</th></tr></thead><tbody className="divide-y divide-slate-100">{recentRows.map((r) => <tr key={r.ObservationDate}><td className="px-3 py-3">{dateLabel(r.ObservationDate)}</td><td className="px-3 py-3 text-right">{fmt(r.Close)}</td><td className="px-3 py-3 text-right">{fmt(r.CloseChange)}</td><td className="px-3 py-3 text-right">{fmt(r.TotalNetGammaChange, 0)}</td></tr>)}{!recentRows.length ? <tr><td colSpan={4} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}</tbody></table></div></CardContent></Card>
    </div>
  );
}
