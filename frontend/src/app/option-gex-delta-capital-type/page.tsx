"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Row = Record<string, any>;

function isoDate(date: Date) { return date.toISOString().slice(0, 10); }
function defaultFromDate() { const d = new Date(); d.setDate(d.getDate() - 180); return isoDate(d); }
function num(v: any): number | null { const n = Number(v); return Number.isFinite(n) ? n : null; }
function fmt(v: any, digits = 2) { const n = num(v); return n === null ? "-" : n.toLocaleString(undefined, { maximumFractionDigits: digits }); }
function dateLabel(value: string) { const d = new Date(value); return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString(undefined, { month: "short", day: "numeric" }); }

function StackedBarLineChart({ rows, yKey, title, threshold }: { rows: Row[]; yKey: string; title: string; threshold?: number }) {
  const width = 1000, height = 420, pad = 36;
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const dates = Array.from(new Set(rows.map((r) => String(r.ObservationDate))));
  const caps = Array.from(new Set(rows.map((r) => String(r.CapitalType || "-"))));
  const closeByDate = new Map<string, number>();
  rows.forEach((r) => { const c = num(r.Close); if (c !== null) closeByDate.set(String(r.ObservationDate), c); });
  const totals = dates.map((d) => rows.filter((r) => String(r.ObservationDate) === d).reduce((s, r) => s + Math.max(0, num(r[yKey]) || 0), 0));
  const maxTotal = Math.max(...totals, 1);
  const closes = Array.from(closeByDate.values());
  if (!dates.length || !rows.length || !closes.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const closeMin = Math.min(...closes);
  const closeMax = Math.max(...closes);
  const colors = ["#2563eb", "#dc2626", "#16a34a", "#f97316", "#9333ea", "#0891b2"];
  const step = (width - pad * 2) / dates.length;
  const barW = Math.max(4, step * 0.72);
  const yBar = (v: number) => height - pad - (v / maxTotal) * (height - pad * 2);
  const yClose = (v: number) => pad + (height - pad * 2) - ((v - closeMin) / (closeMax - closeMin || 1)) * (height - pad * 2);
  const xFor = (i: number) => pad + i * step + step / 2;
  const closePath = dates.map((d, i) => { const c = closeByDate.get(d); return c === undefined ? null : `${xFor(i).toFixed(1)},${yClose(c).toFixed(1)}`; }).filter(Boolean).join(" ");
  const thresholdY = threshold === undefined ? null : yBar(threshold);
  const activeDate = activeIndex === null ? null : dates[activeIndex];
  const activeX = activeIndex === null ? null : xFor(activeIndex);
  const activeSegments = activeDate === null ? [] : caps.map((cap) => ({
    cap,
    value: rows.filter((r) => String(r.ObservationDate) === activeDate && String(r.CapitalType || "-") === cap).reduce((s, r) => s + Math.max(0, num(r[yKey]) || 0), 0),
  }));
  const activeTotal = activeSegments.reduce((sum, item) => sum + item.value, 0);
  const activeClose = activeDate === null ? undefined : closeByDate.get(activeDate);
  const updateActiveIndex = (event: any) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const chartX = ((event.clientX - rect.left) / rect.width) * width;
    const clampedX = Math.max(pad, Math.min(width - pad, chartX));
    const index = Math.round((clampedX - pad - step / 2) / step);
    setActiveIndex(Math.max(0, Math.min(dates.length - 1, index)));
  };
  return (
    <div>
      <div className="overflow-x-auto">
        <svg viewBox={`0 0 ${width} ${height}`} className="min-w-[900px] w-full cursor-crosshair select-none touch-pan-x" role="img" aria-label={title} onPointerMove={updateActiveIndex} onPointerLeave={() => setActiveIndex(null)}>
          <rect width={width} height={height} fill="white" />
          {thresholdY !== null ? <line x1={pad} x2={width - pad} y1={thresholdY} y2={thresholdY} stroke="#dc2626" strokeDasharray="7 7" /> : null}
          {dates.map((d, i) => {
            let acc = 0;
            const x = pad + i * step + (step - barW) / 2;
            return caps.map((cap, ci) => {
              const v = rows.filter((r) => String(r.ObservationDate) === d && String(r.CapitalType || "-") === cap).reduce((s, r) => s + Math.max(0, num(r[yKey]) || 0), 0);
              if (!v) return null;
              const y0 = yBar(acc);
              acc += v;
              const y1 = yBar(acc);
              return <rect key={`${d}-${cap}`} x={x} y={y1} width={barW} height={Math.max(0, y0 - y1)} fill={colors[ci % colors.length]} opacity={activeIndex === i ? "0.96" : "0.82"} stroke={activeIndex === i ? "#334155" : "none"} strokeWidth="0.8" />;
            });
          })}
          <polyline points={closePath} fill="none" stroke="#6d28d9" strokeWidth="2.3" />
          {rows.filter((r) => r.Swing === 0 || r.Swing === 1).map((r) => {
            const i = dates.indexOf(String(r.ObservationDate));
            const c = num(r.Close);
            if (i < 0 || c === null) return null;
            return <circle key={`${r.ObservationDate}-${r.CapitalType}-${r.Swing}`} cx={xFor(i)} cy={yClose(c)} r="3" fill={r.Swing === 1 ? "#84cc16" : "#fde047"} stroke="#334155" strokeWidth="0.7" />;
          })}
          {activeDate && activeX !== null ? (
            <g pointerEvents="none">
              <line x1={activeX} x2={activeX} y1={pad} y2={height - pad} stroke="#334155" strokeDasharray="4 5" opacity="0.45" />
              {activeClose !== undefined ? <circle cx={activeX} cy={yClose(activeClose)} r="5" fill="#6d28d9" stroke="white" strokeWidth="2" /> : null}
            </g>
          ) : null}
          <rect x={pad} y={pad} width={width - pad * 2} height={height - pad * 2} fill="transparent" />
          <text x={pad} y="18" fill="#475569" fontSize="13">{title}</text>
          <text x={pad} y={height - 8} fill="#64748b" fontSize="12">{dateLabel(dates[0])}</text>
          <text x={width - pad} y={height - 8} textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(dates[dates.length - 1])}</text>
        </svg>
      </div>
      <aside className="mt-3 min-h-[96px] rounded-md bg-slate-950 p-4 text-sm text-slate-100" aria-live="polite">
        {activeDate ? (
          <div className="space-y-3">
            <div className="grid gap-3 md:grid-cols-[minmax(130px,0.6fr)_repeat(2,minmax(130px,1fr))] md:items-center">
              <div className="font-semibold">{dateLabel(activeDate)}</div>
              <div className="flex items-center justify-between gap-4 md:block"><div className="text-violet-200">Close</div><div className="font-medium text-violet-100">{fmt(activeClose)}</div></div>
              <div className="flex items-center justify-between gap-4 md:block"><div className="text-slate-300">Total</div><div className="font-medium text-slate-100">{fmt(activeTotal, yKey === "GEXDeltaPerc" ? 2 : 0)}</div></div>
            </div>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {activeSegments.map(({ cap, value }, i) => (
                <div key={cap} className="flex items-center justify-between gap-4 rounded border border-slate-800 px-3 py-2">
                  <div className="flex items-center gap-2 text-slate-300"><span className="inline-block h-2 w-5 rounded" style={{ backgroundColor: colors[i % colors.length] }} />{cap}</div>
                  <div className="font-medium text-slate-100">{fmt(value, yKey === "GEXDeltaPerc" ? 2 : 0)}</div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="flex min-h-[64px] items-center text-xs text-slate-400">Hover the chart to inspect a data point.</div>
        )}
      </aside>
      <div className="mt-2 flex flex-wrap gap-3 text-xs text-slate-600">{caps.map((cap, i) => <span key={cap}><span className="mr-1 inline-block h-2 w-5 rounded" style={{ backgroundColor: colors[i % colors.length] }} />{cap}</span>)}<span><span className="mr-1 inline-block h-2 w-5 rounded bg-violet-700" />Close</span></div>
    </div>
  );
}

export default function OptionGexDeltaCapitalTypePage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [stockCode, setStockCode] = useState("QQQ.US");
  const [dateFrom, setDateFrom] = useState(defaultFromDate);
  const [dateTo, setDateTo] = useState(() => isoDate(new Date()));
  const [threshold, setThreshold] = useState(50);
  const [selectedCaps, setSelectedCaps] = useState<string[]>([]);
  const [data, setData] = useState<{ capital_types: string[]; rows: Row[]; table_rows: Row[]; count: number; stock_code: string } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true); setError("");
    try {
      const params = new URLSearchParams({ stock_code: stockCode.trim().toUpperCase(), date_from: dateFrom, date_to: dateTo });
      selectedCaps.forEach((cap) => params.append("capital_type", cap));
      const res = await authenticatedFetch(`${baseUrl}/api/us-market-dashboards/option-gex-delta-capital-type?${params}`, { cache: "no-store" });
      const body = await res.json();
      if (!res.ok) throw new Error(body?.detail || `HTTP ${res.status}`);
      setData(body);
      if (!selectedCaps.length && body.capital_types?.length) setSelectedCaps(body.capital_types.slice(0, 4));
    } catch (e: any) { setError(e?.message || String(e)); } finally { setLoading(false); }
  }, [baseUrl, dateFrom, dateTo, selectedCaps, stockCode]);

  useEffect(() => { void load(); }, []);
  const visibleRows = useMemo(() => (data?.rows || []).filter((r) => !selectedCaps.length || selectedCaps.includes(String(r.CapitalType))), [data, selectedCaps]);
  const recentTable = (data?.table_rows || []).slice(0, 30);
  const submit = (e: FormEvent) => { e.preventDefault(); void load(); };

  return (
    <div className="space-y-6">
      <PageHeader title="Option GEX Delta by Capital Type" subtitle="Daily GEX delta, GEX delta percentage and close price by capital type." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card><CardHeader><CardTitle>Filters</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_1fr_2fr_auto] md:items-end"><label className="text-sm"><span className="mb-1 block text-slate-600">Stock Code</span><Input value={stockCode} onChange={(e) => setStockCode(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">Start Date</span><Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} /></label><label className="text-sm"><span className="mb-1 block text-slate-600">End Date</span><Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} /></label><div className="text-sm"><span className="mb-1 block text-slate-600">Capital Type</span><div className="flex flex-wrap gap-2">{(data?.capital_types || []).map((cap) => <label key={cap} className="inline-flex items-center gap-2 rounded-md border border-slate-200 bg-white px-3 py-2"><input type="checkbox" checked={selectedCaps.includes(cap)} onChange={(e) => setSelectedCaps((prev) => e.target.checked ? [...prev, cap] : prev.filter((c) => c !== cap))} />{cap}</label>)}</div></div><Button type="submit" disabled={loading}>Apply</Button></form></CardContent></Card>
      <div className="grid gap-4 md:grid-cols-3"><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Rows</div><div className="mt-1 text-2xl font-semibold text-slate-900">{data?.count || 0}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Capital Types</div><div className="mt-1 text-2xl font-semibold text-slate-900">{selectedCaps.length}</div></CardContent></Card><Card><CardContent className="p-4"><div className="text-xs uppercase tracking-wide text-slate-500">Threshold</div><input type="range" min={0} max={100} value={threshold} onChange={(e) => setThreshold(Number(e.target.value))} className="mt-3 w-full accent-indigo-600" /><div className="mt-1 text-sm font-medium text-slate-700">{threshold}</div></CardContent></Card></div>
      <Card><CardHeader><CardTitle>GEX Delta by Day</CardTitle></CardHeader><CardContent><StackedBarLineChart rows={visibleRows} yKey="GEXDelta" title={`${data?.stock_code || stockCode.toUpperCase()} GEX delta by day`} /></CardContent></Card>
      <Card><CardHeader><CardTitle>GEX Delta Percentage by Day</CardTitle></CardHeader><CardContent><StackedBarLineChart rows={visibleRows} yKey="GEXDeltaPerc" title="GEX delta percentage of the day" threshold={threshold} /></CardContent></Card>
      <Card><CardHeader><CardTitle>GEX Insight Table</CardTitle></CardHeader><CardContent><div className="overflow-x-auto rounded-md border border-slate-200"><table className="min-w-full text-sm"><thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Date</th><th className="px-3 py-3">Insight</th><th className="px-3 py-3 text-right">BC %</th><th className="px-3 py-3 text-right">BC % Pre</th><th className="px-3 py-3 text-right">BP %</th><th className="px-3 py-3 text-right">BP % Pre</th><th className="px-3 py-3 text-right">Close</th></tr></thead><tbody className="divide-y divide-slate-100">{recentTable.map((r) => <tr key={r.ObservationDate}><td className="px-3 py-3">{dateLabel(r.ObservationDate)}</td><td className="px-3 py-3">{r.GEXInsight || "-"}</td><td className="px-3 py-3 text-right">{fmt(r.BC_GEXDeltaPerc)}</td><td className="px-3 py-3 text-right">{fmt(r.BC_GEXDeltaPerc_Pre)}</td><td className="px-3 py-3 text-right">{fmt(r.BP_GEXDeltaPerc)}</td><td className="px-3 py-3 text-right">{fmt(r.BP_GEXDeltaPerc_Pre)}</td><td className="px-3 py-3 text-right">{fmt(r.Close)}</td></tr>)}{!recentTable.length ? <tr><td colSpan={7} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}</tbody></table></div></CardContent></Card>
    </div>
  );
}
