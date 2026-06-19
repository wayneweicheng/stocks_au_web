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
  d.setFullYear(d.getFullYear() - 1);
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
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "2-digit" });
}

function DualLineChart({ rows }: { rows: Row[] }) {
  const width = 1000;
  const height = 420;
  const pad = 32;
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const closeValues = rows.map((r) => num(r.Close)).filter((v): v is number => v !== null);
  const gexValues = rows.map((r) => num(r.TotalNetGamma)).filter((v): v is number => v !== null);
  if (!rows.length || !closeValues.length || !gexValues.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const closeMin = Math.min(...closeValues);
  const closeMax = Math.max(...closeValues);
  const gexMin = Math.min(...gexValues);
  const gexMax = Math.max(...gexValues);
  const xFor = (i: number) => pad + (rows.length <= 1 ? 0.5 : i / (rows.length - 1)) * (width - pad * 2);
  const yFor = (v: number, min: number, max: number) => pad + (height - pad * 2) - ((v - min) / (max - min || 1)) * (height - pad * 2);
  const path = (key: string, min: number, max: number) => rows.map((r, i) => {
    const v = num(r[key]);
    if (v === null) return null;
    return `${xFor(i).toFixed(1)},${yFor(v, min, max).toFixed(1)}`;
  }).filter(Boolean).join(" ");
  const activeRow = activeIndex === null ? null : rows[activeIndex];
  const activeX = activeIndex === null ? null : xFor(activeIndex);
  const updateActiveIndex = (event: any) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const chartX = ((event.clientX - rect.left) / rect.width) * width;
    const clampedX = Math.max(pad, Math.min(width - pad, chartX));
    const index = Math.round(((clampedX - pad) / (width - pad * 2)) * (rows.length - 1));
    setActiveIndex(Math.max(0, Math.min(rows.length - 1, index)));
  };
  return (
    <div>
      <div className="overflow-x-auto">
        <svg viewBox={`0 0 ${width} ${height}`} className="min-w-[900px] w-full cursor-crosshair select-none touch-pan-x" role="img" aria-label="Net GEX vs Close" onPointerMove={updateActiveIndex} onPointerLeave={() => setActiveIndex(null)}>
          <rect width={width} height={height} fill="white" />
          {[0.25, 0.5, 0.75].map((r) => <line key={r} x1={pad} x2={width - pad} y1={pad + r * (height - pad * 2)} y2={pad + r * (height - pad * 2)} stroke="#f1f5f9" />)}
          <polyline points={path("Close", closeMin, closeMax)} fill="none" stroke="#2563eb" strokeWidth="2.4" />
          <polyline points={path("TotalNetGamma", gexMin, gexMax)} fill="none" stroke="#dc2626" strokeWidth="2.4" />
          {activeRow && activeX !== null ? (
            <g pointerEvents="none">
              <line x1={activeX} x2={activeX} y1={pad} y2={height - pad} stroke="#334155" strokeDasharray="4 5" opacity="0.45" />
              {num(activeRow.Close) !== null ? <circle cx={activeX} cy={yFor(num(activeRow.Close) as number, closeMin, closeMax)} r="5" fill="#2563eb" stroke="white" strokeWidth="2" /> : null}
              {num(activeRow.TotalNetGamma) !== null ? <circle cx={activeX} cy={yFor(num(activeRow.TotalNetGamma) as number, gexMin, gexMax)} r="5" fill="#dc2626" stroke="white" strokeWidth="2" /> : null}
            </g>
          ) : null}
          <rect x={pad} y={pad} width={width - pad * 2} height={height - pad * 2} fill="transparent" />
          <text x={pad} y="18" fill="#475569" fontSize="13">Close and total net gamma</text>
          <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{dateLabel(rows[0].ObservationDate)}</text>
          <text x={width - pad} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(rows[rows.length - 1].ObservationDate)}</text>
        </svg>
      </div>
      <aside className="mt-3 min-h-[82px] rounded-md bg-slate-950 p-4 text-sm text-slate-100" aria-live="polite">
        {activeRow ? (
          <div className="grid gap-3 md:grid-cols-[minmax(140px,0.7fr)_repeat(2,minmax(160px,1fr))] md:items-center">
            <div className="font-semibold">{dateLabel(String(activeRow.ObservationDate))}</div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-blue-200">Close</div><div className="font-medium text-blue-100">{fmt(activeRow.Close)}</div></div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-red-200">Total Net Gamma</div><div className="font-medium text-red-100">{fmt(activeRow.TotalNetGamma, 0)}</div></div>
          </div>
        ) : (
          <div className="flex min-h-[50px] items-center text-xs text-slate-400">Hover the chart to inspect a data point.</div>
        )}
      </aside>
      <div className="mt-2 flex flex-wrap gap-4 text-xs text-slate-600"><span><span className="mr-1 inline-block h-2 w-6 rounded bg-blue-600" />Close</span><span><span className="mr-1 inline-block h-2 w-6 rounded bg-red-600" />Total Net Gamma</span></div>
    </div>
  );
}

export default function NetGexVsClosePage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [stockCode, setStockCode] = useState("QQQ.US");
  const [dateFrom, setDateFrom] = useState(defaultFromDate);
  const [dateTo, setDateTo] = useState(() => isoDate(new Date()));
  const [data, setData] = useState<{ stock_code: string; rows: Row[]; latest_strikes: Row[]; count: number } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ stock_code: stockCode.trim().toUpperCase(), date_from: dateFrom, date_to: dateTo });
      const res = await authenticatedFetch(`${baseUrl}/api/us-market-dashboards/net-gex-vs-close?${params}`, { cache: "no-store" });
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
  const latest = data?.rows?.[data.rows.length - 1];
  const recentRows = useMemo(() => [...(data?.rows || [])].reverse().slice(0, 30), [data]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    void load();
  };

  return (
    <div className="space-y-6">
      <PageHeader title="Net GEX vs Close" subtitle="Total net gamma exposure compared with close price over time." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card><CardHeader><CardTitle>Filters</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_1fr_auto] md:items-end"><label className="text-sm"><span className="mb-1 block text-slate-600">Stock Code</span><Input value={stockCode} onChange={(e) => setStockCode(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Date From</span><Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Date To</span><Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} /></label><Button type="submit" disabled={loading}>Apply</Button></form></CardContent></Card>
      <div className="grid gap-4 md:grid-cols-4"><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Rows</div><div className="mt-1 text-2xl font-semibold text-slate-900">{data?.count || 0}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Latest Close</div><div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(latest?.Close)}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Total Net Gamma</div><div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(latest?.TotalNetGamma, 0)}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Net Gamma Change</div><div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(latest?.TotalNetGammaChange, 0)}</div></CardContent></Card></div>
      <Card><CardHeader><CardTitle>{data?.stock_code || stockCode.toUpperCase()} Close vs Total Net Gamma</CardTitle></CardHeader><CardContent><DualLineChart rows={data?.rows || []} /></CardContent></Card>
      <Card><CardHeader><CardTitle>Recent History</CardTitle></CardHeader><CardContent><div className="overflow-x-auto rounded-md border border-slate-200"><table className="min-w-full text-sm"><thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Date</th><th className="px-3 py-3 text-right">Close</th><th className="px-3 py-3 text-right">Close Change</th><th className="px-3 py-3 text-right">Call Gamma</th><th className="px-3 py-3 text-right">Put Gamma</th><th className="px-3 py-3 text-right">Net Gamma</th><th className="px-3 py-3 text-right">Net Change</th></tr></thead><tbody className="divide-y divide-slate-100">{recentRows.map((r) => <tr key={r.ObservationDate}><td className="px-3 py-3">{dateLabel(r.ObservationDate)}</td><td className="px-3 py-3 text-right">{fmt(r.Close)}</td><td className="px-3 py-3 text-right">{fmt(r.CloseChange)}</td><td className="px-3 py-3 text-right">{fmt(r.TotalCallGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.TotalPutGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.TotalNetGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.TotalNetGammaChange, 0)}</td></tr>)}{!recentRows.length ? <tr><td colSpan={7} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}</tbody></table></div></CardContent></Card>
    </div>
  );
}
