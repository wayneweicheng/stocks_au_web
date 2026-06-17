"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Row = Record<string, any>;

function num(v: any): number | null {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function fmt(v: any, digits = 2) {
  const n = num(v);
  return n === null ? "-" : n.toLocaleString(undefined, { maximumFractionDigits: digits });
}

function BarChart({ rows, xKey, title }: { rows: Row[]; xKey: string; title: string }) {
  const width = 1000;
  const height = 360;
  const pad = 36;
  const values = rows.flatMap((r) => [num(r.CallGamma), num(r.PutGamma), num(r.NetGamma)]).filter((v): v is number => v !== null);
  if (!rows.length || !values.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const maxAbs = Math.max(...values.map((v) => Math.abs(v))) || 1;
  const zeroY = height / 2;
  const barW = Math.max(2, (width - pad * 2) / rows.length / 3);
  const yFor = (v: number) => zeroY - (v / maxAbs) * (height / 2 - pad);
  const bars: Array<[string, string, number]> = [
    ["CallGamma", "#2563eb", 0],
    ["PutGamma", "#dc2626", 1],
    ["NetGamma", "#16a34a", 2],
  ];
  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[360px] min-w-[900px] w-full" role="img" aria-label={title}>
        <rect width={width} height={height} fill="white" />
        <line x1={pad} x2={width - pad} y1={zeroY} y2={zeroY} stroke="#94a3b8" />
        {rows.map((r, i) => {
          const x = pad + i * ((width - pad * 2) / rows.length);
          return bars.map(([key, color, offset]) => {
            const v = num(r[key]);
            if (v === null) return null;
            const y = yFor(v);
            return <rect key={`${i}-${key}`} x={x + Number(offset) * barW} y={Math.min(y, zeroY)} width={barW} height={Math.abs(zeroY - y)} fill={String(color)} />;
          });
        })}
        <text x={pad} y="18" fill="#475569" fontSize="13">{title}</text>
        <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{String(rows[0][xKey])}</text>
        <text x={width - pad} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{String(rows[rows.length - 1][xKey])}</text>
      </svg>
      <div className="mt-2 flex flex-wrap gap-4 text-xs text-slate-600"><span><span className="mr-1 inline-block h-2 w-5 rounded bg-blue-600" />Call Gamma</span><span><span className="mr-1 inline-block h-2 w-5 rounded bg-red-600" />Put Gamma</span><span><span className="mr-1 inline-block h-2 w-5 rounded bg-green-600" />Net Gamma</span></div>
    </div>
  );
}

export default function GammaWallPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [stockCode, setStockCode] = useState("QQQ.US");
  const [observationDate, setObservationDate] = useState("");
  const [data, setData] = useState<{ stock_code: string; observation_date: string | null; close: number | null; by_strike: Row[]; by_expiry: Row[] } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ stock_code: stockCode.trim().toUpperCase() });
      if (observationDate) params.set("observation_date", observationDate);
      const res = await authenticatedFetch(`${baseUrl}/api/us-market-dashboards/gamma-wall?${params}`, { cache: "no-store" });
      const body = await res.json();
      if (!res.ok) throw new Error(body?.detail || `HTTP ${res.status}`);
      setData(body);
      if (!observationDate && body.observation_date) setObservationDate(body.observation_date);
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  useEffect(() => { void load(); }, []);
  const topRows = useMemo(() => [...(data?.by_strike || [])].sort((a, b) => Math.abs(num(b.NetGamma) || 0) - Math.abs(num(a.NetGamma) || 0)).slice(0, 25), [data]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    void load();
  };

  return (
    <div className="space-y-6">
      <PageHeader title="Gamma Wall" subtitle="Call, put and net gamma by strike and expiry date." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card><CardHeader><CardTitle>Filters</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_auto] md:items-end"><label className="text-sm"><span className="mb-1 block text-slate-600">Stock Code</span><Input value={stockCode} onChange={(e) => setStockCode(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Observation Date</span><Input type="date" value={observationDate} onChange={(e) => setObservationDate(e.target.value)} /></label><Button type="submit" disabled={loading}>Apply</Button></form></CardContent></Card>
      <div className="grid gap-4 md:grid-cols-3"><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Observation Date</div><div className="mt-1 text-2xl font-semibold text-slate-900">{data?.observation_date || "-"}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Close</div><div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(data?.close)}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Strikes</div><div className="mt-1 text-2xl font-semibold text-slate-900">{data?.by_strike?.length || 0}</div></CardContent></Card></div>
      <Card><CardHeader><CardTitle>Gamma by Strike</CardTitle></CardHeader><CardContent><BarChart rows={data?.by_strike || []} xKey="Strike" title={`${data?.stock_code || stockCode.toUpperCase()} gamma by strike`} /></CardContent></Card>
      <Card><CardHeader><CardTitle>Gamma by Expiry</CardTitle></CardHeader><CardContent><BarChart rows={data?.by_expiry || []} xKey="ExpiryDate" title="Gamma by expiry date" /></CardContent></Card>
      <Card><CardHeader><CardTitle>Top Net Gamma Strikes</CardTitle></CardHeader><CardContent><div className="overflow-x-auto rounded-md border border-slate-200"><table className="min-w-full text-sm"><thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Strike</th><th className="px-3 py-3 text-right">Call Gamma</th><th className="px-3 py-3 text-right">Put Gamma</th><th className="px-3 py-3 text-right">Net Gamma</th></tr></thead><tbody className="divide-y divide-slate-100">{topRows.map((r) => <tr key={r.Strike}><td className="px-3 py-3 font-medium">{fmt(r.Strike)}</td><td className="px-3 py-3 text-right">{fmt(r.CallGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.PutGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.NetGamma, 0)}</td></tr>)}{!topRows.length ? <tr><td colSpan={4} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}</tbody></table></div></CardContent></Card>
    </div>
  );
}
