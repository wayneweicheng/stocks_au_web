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
  const gexValues = rows.map((r) => num(r.TotalNetGammaChange)).filter((v): v is number => v !== null);
  const closeValues = rows.map((r) => num(r.CloseChange)).filter((v): v is number => v !== null);
  if (!rows.length || !gexValues.length || !closeValues.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const maxGex = Math.max(...gexValues.map((v) => Math.abs(v))) || 1;
  const maxClose = Math.max(...closeValues.map((v) => Math.abs(v))) || 1;
  const zeroY = height / 2;
  const step = (width - pad * 2) / rows.length;
  const barW = Math.max(3, step * 0.62);
  const yGex = (v: number) => zeroY - (v / maxGex) * (height / 2 - pad);
  const yClose = (v: number) => zeroY - (v / maxClose) * (height / 2 - pad);
  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[390px] min-w-[900px] w-full" role="img" aria-label="Total net gamma change and close change by date">
        <rect width={width} height={height} fill="white" />
        <line x1={pad} x2={width - pad} y1={zeroY} y2={zeroY} stroke="#94a3b8" />
        {rows.map((r, i) => {
          const x = pad + i * step + (step - barW) / 2;
          const g = num(r.TotalNetGammaChange);
          const c = num(r.CloseChange);
          return (
            <g key={r.ObservationDate}>
              {g !== null ? <rect x={x} y={Math.min(yGex(g), zeroY)} width={barW} height={Math.abs(zeroY - yGex(g))} fill="#0f766e" opacity="0.62" /> : null}
              {c !== null ? <rect x={x + barW * 0.18} y={Math.min(yClose(c), zeroY)} width={barW * 0.64} height={Math.abs(zeroY - yClose(c))} fill="#f97316" opacity="0.62" /> : null}
            </g>
          );
        })}
        <text x={pad} y="18" fill="#475569" fontSize="13">Total net gamma change and close change</text>
        <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{dateLabel(rows[0].ObservationDate)}</text>
        <text x={width - pad} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(rows[rows.length - 1].ObservationDate)}</text>
      </svg>
      <div className="mt-2 flex flex-wrap gap-4 text-xs text-slate-600"><span><span className="mr-1 inline-block h-2 w-6 rounded bg-teal-700" />Total Net Gamma Change</span><span><span className="mr-1 inline-block h-2 w-6 rounded bg-orange-500" />Close Change</span></div>
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
