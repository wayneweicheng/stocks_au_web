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
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function MultiLineChart({ rows, yKey, groupKey, title }: { rows: Row[]; yKey: string; groupKey?: string; title: string }) {
  const width = 1000;
  const height = 340;
  const pad = 28;
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const values = rows.map((r) => num(r[yKey])).filter((v): v is number => v !== null);
  if (!rows.length || !values.length) return <div className="py-12 text-center text-sm text-slate-500">No chart data.</div>;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const spread = max - min || 1;
  const groups = groupKey ? Array.from(new Set(rows.map((r) => String(r[groupKey] || "-")))) : [title];
  const dates = Array.from(new Set(rows.map((r) => String(r.ObservationDate))));
  const colors = ["#dc2626", "#0891b2", "#2563eb", "#16a34a", "#9333ea", "#f97316"];
  const xFor = (i: number, count: number) => pad + (count <= 1 ? 0.5 : i / (count - 1)) * (width - pad * 2);
  const yFor = (v: number) => pad + (height - pad * 2) - ((v - min) / spread) * (height - pad * 2);
  const activeDate = activeIndex === null ? null : dates[activeIndex];
  const activeX = activeIndex === null ? null : xFor(activeIndex, dates.length);
  const tooltipRows = activeDate === null ? [] : groups.map((group) => {
    const row = groupKey ? rows.find((r) => String(r.ObservationDate) === activeDate && String(r[groupKey] || "-") === group) : rows.find((r) => String(r.ObservationDate) === activeDate);
    return { group, row, value: row ? num(row[yKey]) : null };
  });
  const updateActiveIndex = (event: any) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const chartX = ((event.clientX - rect.left) / rect.width) * width;
    const clampedX = Math.max(pad, Math.min(width - pad, chartX));
    const index = Math.round(((clampedX - pad) / (width - pad * 2)) * (dates.length - 1));
    setActiveIndex(Math.max(0, Math.min(dates.length - 1, index)));
  };
  return (
    <div>
      <div className="overflow-x-auto">
        <svg viewBox={`0 0 ${width} ${height}`} className="min-w-[860px] w-full cursor-crosshair select-none touch-pan-x" role="img" aria-label={title} onPointerMove={updateActiveIndex} onPointerLeave={() => setActiveIndex(null)}>
          <rect width={width} height={height} fill="white" />
          {[0.25, 0.5, 0.75].map((r) => <line key={r} x1={pad} x2={width - pad} y1={pad + r * (height - pad * 2)} y2={pad + r * (height - pad * 2)} stroke="#f1f5f9" />)}
          {min < 0 && max > 0 ? <line x1={pad} x2={width - pad} y1={yFor(0)} y2={yFor(0)} stroke="#cbd5e1" /> : null}
          {groups.map((g, gi) => {
            const groupRows = groupKey ? rows.filter((r) => String(r[groupKey] || "-") === g) : rows;
            const points = groupRows.map((r, i) => {
              const v = num(r[yKey]);
              if (v === null) return null;
              return `${xFor(i, groupRows.length).toFixed(1)},${yFor(v).toFixed(1)}`;
            }).filter(Boolean).join(" ");
            return <polyline key={g} points={points} fill="none" stroke={colors[gi % colors.length]} strokeWidth="2.2" />;
          })}
          {activeDate && activeX !== null ? (
            <g pointerEvents="none">
              <line x1={activeX} x2={activeX} y1={pad} y2={height - pad} stroke="#334155" strokeDasharray="4 5" opacity="0.45" />
              {tooltipRows.map(({ group, value }, i) => value === null ? null : <circle key={group} cx={activeX} cy={yFor(value)} r="4.5" fill={colors[i % colors.length]} stroke="white" strokeWidth="2" />)}
            </g>
          ) : null}
          <rect x={pad} y={pad} width={width - pad * 2} height={height - pad * 2} fill="transparent" />
          <text x={pad} y="18" fill="#475569" fontSize="13">{title}</text>
          <text x={pad} y={height - 6} fill="#64748b" fontSize="12">{dateLabel(rows[0].ObservationDate)}</text>
          <text x={width - pad} y={height - 6} textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(rows[rows.length - 1].ObservationDate)}</text>
        </svg>
      </div>
      <aside className="mt-3 min-h-[82px] rounded-md bg-slate-950 p-4 text-sm text-slate-100" aria-live="polite">
        {activeDate ? (
          <div className="grid gap-3 md:grid-cols-[minmax(130px,0.6fr)_repeat(auto-fit,minmax(120px,1fr))] md:items-center">
            <div className="font-semibold">{dateLabel(activeDate)}</div>
            {tooltipRows.map(({ group, value }, i) => (
              <div key={group} className="flex items-center justify-between gap-4 md:block">
                <div className="flex items-center gap-2 text-slate-300"><span className="inline-block h-2 w-5 rounded" style={{ backgroundColor: colors[i % colors.length] }} />{group}</div>
                <div className="font-medium text-slate-100">{fmt(value, yKey === "SPX" ? 2 : 4)}</div>
              </div>
            ))}
          </div>
        ) : (
          <div className="flex min-h-[50px] items-center text-xs text-slate-400">Hover the chart to inspect a data point.</div>
        )}
      </aside>
      <div className="mt-2 flex flex-wrap gap-3 text-xs text-slate-600">
        {groups.map((g, i) => <span key={g}><span className="mr-1 inline-block h-2 w-5 rounded" style={{ backgroundColor: colors[i % colors.length] }} />{g}</span>)}
      </div>
    </div>
  );
}

export default function MarketClvTrendPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [dateFrom, setDateFrom] = useState(defaultFromDate);
  const [dateTo, setDateTo] = useState(() => isoDate(new Date()));
  const [selectedCaps, setSelectedCaps] = useState<string[]>([]);
  const [data, setData] = useState<{ market_caps: string[]; rows: Row[]; count: number } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ date_from: dateFrom, date_to: dateTo });
      selectedCaps.forEach((cap) => params.append("market_cap", cap));
      const res = await authenticatedFetch(`${baseUrl}/api/us-market-dashboards/market-clv-trend?${params}`, { cache: "no-store" });
      const body = await res.json();
      if (!res.ok) throw new Error(body?.detail || `HTTP ${res.status}`);
      setData(body);
      if (!selectedCaps.length && body.market_caps?.length) setSelectedCaps(body.market_caps.slice(0, 3));
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, dateFrom, dateTo, selectedCaps]);

  useEffect(() => { void load(); }, []);

  const visibleRows = useMemo(() => {
    const caps = selectedCaps.length ? selectedCaps : data?.market_caps?.slice(0, 3) || [];
    return (data?.rows || []).filter((r) => !caps.length || caps.includes(String(r.MarketCap)));
  }, [data, selectedCaps]);
  const todayRows = visibleRows.slice(-30).reverse();

  const submit = (e: FormEvent) => {
    e.preventDefault();
    void load();
  };

  return (
    <div className="space-y-6">
      <PageHeader title="Market CLV Trend" subtitle="Market close-location value by market-cap bucket, migrated from the Streamlit CLV dashboard." actions={<Button onClick={load} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>} />
      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      <Card>
        <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
        <CardContent>
          <form onSubmit={submit} className="grid gap-4 md:grid-cols-[1fr_1fr_2fr_auto] md:items-end">
            <label className="text-sm"><span className="mb-1 block text-slate-600">Start Date</span><Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} /></label>
            <label className="text-sm"><span className="mb-1 block text-slate-600">End Date</span><Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} /></label>
            <div className="text-sm">
              <span className="mb-1 block text-slate-600">Market Cap</span>
              <div className="flex flex-wrap gap-2">
                {(data?.market_caps || []).map((cap) => (
                  <label key={cap} className="inline-flex items-center gap-2 rounded-md border border-slate-200 bg-white px-3 py-2">
                    <input type="checkbox" checked={selectedCaps.includes(cap)} onChange={(e) => setSelectedCaps((prev) => e.target.checked ? [...prev, cap] : prev.filter((c) => c !== cap))} />
                    {cap}
                  </label>
                ))}
              </div>
            </div>
            <Button type="submit" disabled={loading}>Apply</Button>
          </form>
        </CardContent>
      </Card>
      <div className="grid gap-4 md:grid-cols-2">
        <Card><CardHeader><CardTitle>CLV by Day</CardTitle></CardHeader><CardContent><MultiLineChart rows={visibleRows} yKey="CLV" groupKey="MarketCap" title="CLV by market cap" /></CardContent></Card>
        <Card><CardHeader><CardTitle>SPX by Day</CardTitle></CardHeader><CardContent><MultiLineChart rows={visibleRows.filter((r, i, a) => i === a.findIndex((x) => x.ObservationDate === r.ObservationDate))} yKey="SPX" title="SPX" /></CardContent></Card>
      </div>
      <Card>
        <CardHeader><CardTitle>Recent Rows</CardTitle></CardHeader>
        <CardContent>
          <div className="overflow-x-auto rounded-md border border-slate-200">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500"><tr><th className="px-3 py-3">Date</th><th className="px-3 py-3">Market Cap</th><th className="px-3 py-3 text-right">CLV</th><th className="px-3 py-3 text-right">MA5</th><th className="px-3 py-3 text-right">MA10</th><th className="px-3 py-3 text-right">MA20</th><th className="px-3 py-3 text-right">SPX</th></tr></thead>
              <tbody className="divide-y divide-slate-100">
                {todayRows.map((r, i) => <tr key={`${r.ObservationDate}-${r.MarketCap}-${i}`}><td className="px-3 py-3">{dateLabel(r.ObservationDate)}</td><td className="px-3 py-3">{r.MarketCap}</td><td className="px-3 py-3 text-right">{fmt(r.CLV, 4)}</td><td className="px-3 py-3 text-right">{fmt(r.CLVMA5, 4)}</td><td className="px-3 py-3 text-right">{fmt(r.CLVMA10, 4)}</td><td className="px-3 py-3 text-right">{fmt(r.CLVMA20, 4)}</td><td className="px-3 py-3 text-right">{fmt(r.SPX)}</td></tr>)}
                {!todayRows.length ? <tr><td colSpan={7} className="px-3 py-8 text-center text-slate-500">{loading ? "Loading..." : "No data found."}</td></tr> : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
