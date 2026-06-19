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
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const values = rows.flatMap((r) => [num(r.CallGamma), num(r.PutGamma), num(r.NetGamma)]).filter((v): v is number => v !== null);
  if (!rows.length || !values.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const maxAbs = Math.max(...values.map((v) => Math.abs(v))) || 1;
  const zeroY = height / 2;
  const step = (width - pad * 2) / rows.length;
  const barW = Math.max(5, Math.min(28, step * 0.26));
  const yFor = (v: number) => zeroY - (v / maxAbs) * (height / 2 - pad);
  const xFor = (i: number) => pad + i * step + step / 2;
  const bars: Array<[string, string, number]> = [
    ["CallGamma", "#2563eb", 0],
    ["PutGamma", "#dc2626", 1],
    ["NetGamma", "#16a34a", 2],
  ];
  const activeRow = activeIndex === null ? null : rows[activeIndex];
  const activeX = activeIndex === null ? null : xFor(activeIndex);
  const updateActiveIndex = (event: any) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const chartX = ((event.clientX - rect.left) / rect.width) * width;
    const clampedX = Math.max(pad, Math.min(width - pad, chartX));
    const index = Math.round((clampedX - pad - step / 2) / step);
    setActiveIndex(Math.max(0, Math.min(rows.length - 1, index)));
  };
  return (
    <div>
      <div className="overflow-x-auto">
        <svg viewBox={`0 0 ${width} ${height}`} className="min-w-[900px] w-full cursor-crosshair select-none touch-pan-x" role="img" aria-label={title} onPointerMove={updateActiveIndex} onPointerLeave={() => setActiveIndex(null)}>
          <rect width={width} height={height} fill="white" />
          <line x1={pad} x2={width - pad} y1={zeroY} y2={zeroY} stroke="#94a3b8" />
          {rows.map((r, i) => {
            const x = pad + i * step + (step - barW * 3) / 2;
            return bars.map(([key, color, offset]) => {
              const v = num(r[key]);
              if (v === null) return null;
              const y = yFor(v);
              return <rect key={`${i}-${key}`} x={x + Number(offset) * barW} y={Math.min(y, zeroY)} width={barW} height={Math.abs(zeroY - y)} fill={String(color)} opacity={activeIndex === i ? "0.96" : "0.82"} stroke={activeIndex === i ? "#334155" : "none"} strokeWidth="0.8" />;
            });
          })}
          {activeRow && activeX !== null ? (
            <g pointerEvents="none">
              <line x1={activeX} x2={activeX} y1={pad} y2={height - pad} stroke="#334155" strokeDasharray="4 5" opacity="0.45" />
              {bars.map(([key, color, offset]) => {
                const value = num(activeRow[key]);
                if (value === null) return null;
                return <circle key={key} cx={activeX + (Number(offset) - 1) * barW} cy={yFor(value)} r="4.5" fill={String(color)} stroke="white" strokeWidth="2" />;
              })}
            </g>
          ) : null}
          <rect x={pad} y={pad} width={width - pad * 2} height={height - pad * 2} fill="transparent" />
          <text x={pad} y="18" fill="#475569" fontSize="13">{title}</text>
          <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{String(rows[0][xKey])}</text>
          <text x={width - pad} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{String(rows[rows.length - 1][xKey])}</text>
        </svg>
      </div>
      <aside className="mt-3 min-h-[82px] rounded-md bg-slate-950 p-4 text-sm text-slate-100" aria-live="polite">
        {activeRow ? (
          <div className="grid gap-3 md:grid-cols-[minmax(140px,0.7fr)_repeat(3,minmax(150px,1fr))] md:items-center">
            <div className="font-semibold">{String(activeRow[xKey])}</div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-blue-200">Call Gamma</div><div className="font-medium text-blue-100">{fmt(activeRow.CallGamma, 0)}</div></div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-red-200">Put Gamma</div><div className="font-medium text-red-100">{fmt(activeRow.PutGamma, 0)}</div></div>
            <div className="flex items-center justify-between gap-4 md:block"><div className="text-green-200">Net Gamma</div><div className="font-medium text-green-100">{fmt(activeRow.NetGamma, 0)}</div></div>
          </div>
        ) : (
          <div className="flex min-h-[50px] items-center text-xs text-slate-400">Hover the chart to inspect a data point.</div>
        )}
      </aside>
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
  const [strikeMin, setStrikeMin] = useState("");
  const [strikeMax, setStrikeMax] = useState("");

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
  const strikeBounds = useMemo(() => {
    const strikes = (data?.by_strike || []).map((r) => num(r.Strike)).filter((v): v is number => v !== null);
    return strikes.length ? { min: Math.min(...strikes), max: Math.max(...strikes) } : null;
  }, [data]);
  useEffect(() => {
    if (!strikeBounds) return;
    setStrikeMin(String(strikeBounds.min));
    setStrikeMax(String(strikeBounds.max));
  }, [strikeBounds?.min, strikeBounds?.max]);
  const filteredStrikeRows = useMemo(() => {
    const min = num(strikeMin);
    const max = num(strikeMax);
    return (data?.by_strike || []).filter((row) => {
      const strike = num(row.Strike);
      if (strike === null) return false;
      return (min === null || strike >= min) && (max === null || strike <= max);
    });
  }, [data, strikeMax, strikeMin]);
  const topRows = useMemo(() => [...filteredStrikeRows].sort((a, b) => Math.abs(num(b.NetGamma) || 0) - Math.abs(num(a.NetGamma) || 0)).slice(0, 25), [filteredStrikeRows]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    void load();
  };

  return (
    <div className="space-y-6">
      <PageHeader title="Gamma Wall" subtitle="Call, put and net gamma by strike and expiry date." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card><CardHeader><CardTitle>Filters</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_auto] md:items-end"><label className="text-sm"><span className="mb-1 block text-slate-600">Stock Code</span><Input value={stockCode} onChange={(e) => setStockCode(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Observation Date</span><Input type="date" value={observationDate} onChange={(e) => setObservationDate(e.target.value)} /></label><Button type="submit" disabled={loading}>Apply</Button></form></CardContent></Card>
      <div className="grid gap-4 md:grid-cols-3"><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Observation Date</div><div className="mt-1 text-2xl font-semibold text-slate-900">{data?.observation_date || "-"}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Close</div><div className="mt-1 text-2xl font-semibold text-slate-900">{fmt(data?.close)}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Strikes</div><div className="mt-1 text-2xl font-semibold text-slate-900">{filteredStrikeRows.length || 0} / {data?.by_strike?.length || 0}</div></CardContent></Card></div>
      <Card><CardHeader><CardTitle>Strike Range</CardTitle></CardHeader><CardContent><div className="grid gap-4 md:grid-cols-2"><label className="text-sm"><span className="mb-1 block text-slate-600">Min Strike</span><Input type="number" step="0.01" value={strikeMin} onChange={(e) => setStrikeMin(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Max Strike</span><Input type="number" step="0.01" value={strikeMax} onChange={(e) => setStrikeMax(e.target.value)} /></label></div>{strikeBounds ? <div className="mt-4 grid gap-3 md:grid-cols-2"><input type="range" min={strikeBounds.min} max={strikeBounds.max} step="0.01" value={num(strikeMin) ?? strikeBounds.min} onChange={(e) => setStrikeMin(e.target.value)} className="w-full accent-emerald-600" /><input type="range" min={strikeBounds.min} max={strikeBounds.max} step="0.01" value={num(strikeMax) ?? strikeBounds.max} onChange={(e) => setStrikeMax(e.target.value)} className="w-full accent-emerald-600" /></div> : null}</CardContent></Card>
      <Card><CardHeader><CardTitle>Gamma by Strike</CardTitle></CardHeader><CardContent><BarChart rows={filteredStrikeRows} xKey="Strike" title={`${data?.stock_code || stockCode.toUpperCase()} gamma by strike`} /></CardContent></Card>
      <Card><CardHeader><CardTitle>Gamma by Expiry</CardTitle></CardHeader><CardContent><BarChart rows={data?.by_expiry || []} xKey="ExpiryDate" title="Gamma by expiry date" /></CardContent></Card>
      <Card><CardHeader><CardTitle>Top Net Gamma Strikes</CardTitle></CardHeader><CardContent><div className="overflow-x-auto rounded-md border border-slate-200"><table className="min-w-full text-sm"><thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Strike</th><th className="px-3 py-3 text-right">Call Gamma</th><th className="px-3 py-3 text-right">Put Gamma</th><th className="px-3 py-3 text-right">Net Gamma</th></tr></thead><tbody className="divide-y divide-slate-100">{topRows.map((r) => <tr key={r.Strike}><td className="px-3 py-3 font-medium">{fmt(r.Strike)}</td><td className="px-3 py-3 text-right">{fmt(r.CallGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.PutGamma, 0)}</td><td className="px-3 py-3 text-right">{fmt(r.NetGamma, 0)}</td></tr>)}{!topRows.length ? <tr><td colSpan={4} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}</tbody></table></div></CardContent></Card>
    </div>
  );
}
