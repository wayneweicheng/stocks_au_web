"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type GexRow = {
  ASXCode: string;
  ObservationDate: string;
  NoOfOption: number | null;
  GEX: number | null;
  FormattedGEX: string | null;
  Close: number | null;
  Prev1Close: number | null;
  Prev2Close: number | null;
  FormattedPrev1GEX: string | null;
  SwingIndicator: string | null;
  PotentialSwingIndicator: string | null;
  GEXChange: number | null;
  ClosePriceChange: number | null;
  RSI: number | null;
};

type GexResponse = {
  stock_code: string;
  date_from: string;
  date_to: string;
  count: number;
  gex_mean: number | null;
  gex_std: number | null;
  upper_bound: number | null;
  lower_bound: number | null;
  rows: GexRow[];
};

const PAGE_SIZE = 20;

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function defaultFromDate() {
  const d = new Date();
  d.setFullYear(d.getFullYear() - 1);
  return isoDate(d);
}

function numberValue(value: number | null | undefined) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function compactNumber(value: number | null | undefined, digits = 2) {
  const n = numberValue(value);
  if (n === null) return "-";
  return n.toLocaleString(undefined, {
    maximumFractionDigits: digits,
    minimumFractionDigits: Math.abs(n) < 10 ? Math.min(2, digits) : 0,
  });
}

function pct(value: number | null | undefined) {
  const n = numberValue(value);
  if (n === null) return "-";
  return `${n > 0 ? "+" : ""}${n.toFixed(2)}%`;
}

function dateLabel(value: string) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "2-digit" });
}

function pointsFor(
  rows: GexRow[],
  key: keyof GexRow,
  min: number,
  max: number,
  width: number,
  top: number,
  height: number
) {
  const spread = max - min || 1;
  return rows
    .map((row, index) => {
      const value = numberValue(row[key] as number | null);
      if (value === null) return null;
      const x = rows.length === 1 ? width / 2 : (index / (rows.length - 1)) * width;
      const y = top + height - ((value - min) / spread) * height;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .filter(Boolean)
    .join(" ");
}

function Chart({ data }: { data: GexResponse }) {
  const rows = data.rows;
  const width = 1000;
  const priceTop = 24;
  const priceHeight = 320;
  const rsiTop = 410;
  const rsiHeight = 150;

  const priceValues = rows.map((r) => numberValue(r.Close)).filter((v): v is number => v !== null);
  const gexValues = rows
    .flatMap((r) => [numberValue(r.GEX), data.upper_bound, data.lower_bound])
    .filter((v): v is number => v !== null);
  const priceMin = Math.min(...priceValues);
  const priceMax = Math.max(...priceValues);
  const gexMin = Math.min(...gexValues);
  const gexMax = Math.max(...gexValues);
  const pricePad = (priceMax - priceMin || Math.max(Math.abs(priceMax), 1)) * 0.08;
  const gexPad = (gexMax - gexMin || Math.max(Math.abs(gexMax), 1)) * 0.08;
  const pricePath = pointsFor(rows, "Close", priceMin - pricePad, priceMax + pricePad, width, priceTop, priceHeight);
  const gexPath = pointsFor(rows, "GEX", gexMin - gexPad, gexMax + gexPad, width, priceTop, priceHeight);
  const rsiPath = pointsFor(rows, "RSI", 0, 100, width, rsiTop, rsiHeight);
  const rsi70 = rsiTop + rsiHeight - 0.7 * rsiHeight;
  const rsi30 = rsiTop + rsiHeight - 0.3 * rsiHeight;
  const gexScale = (value: number) => priceTop + priceHeight - ((value - (gexMin - gexPad)) / ((gexMax + gexPad) - (gexMin - gexPad) || 1)) * priceHeight;
  const upperY = data.upper_bound === null ? null : gexScale(data.upper_bound);
  const lowerY = data.lower_bound === null ? null : gexScale(data.lower_bound);

  if (!rows.length || !priceValues.length || !gexValues.length) {
    return <div className="py-16 text-center text-sm text-slate-500">Not enough numeric data to draw the chart.</div>;
  }

  return (
    <div className="overflow-x-auto">
      <svg viewBox={`0 0 ${width} 600`} className="h-[520px] min-w-[900px] w-full" role="img" aria-label="Price, GEX and RSI chart">
        <rect x="0" y="0" width={width} height="600" fill="white" />
        <line x1="0" x2={width} y1={priceTop + priceHeight} y2={priceTop + priceHeight} stroke="#e2e8f0" />
        <line x1="0" x2={width} y1={rsiTop + rsiHeight} y2={rsiTop + rsiHeight} stroke="#e2e8f0" />
        {[0.25, 0.5, 0.75].map((ratio) => (
          <line key={ratio} x1="0" x2={width} y1={priceTop + ratio * priceHeight} y2={priceTop + ratio * priceHeight} stroke="#f1f5f9" />
        ))}
        <polyline points={pricePath} fill="none" stroke="#2563eb" strokeWidth="2.5" />
        <polyline points={gexPath} fill="none" stroke="#dc2626" strokeWidth="2.2" />
        {upperY !== null ? <line x1="0" x2={width} y1={upperY} y2={upperY} stroke="#f97316" strokeDasharray="8 8" /> : null}
        {lowerY !== null ? <line x1="0" x2={width} y1={lowerY} y2={lowerY} stroke="#7c3aed" strokeDasharray="8 8" /> : null}
        {rows.map((row, index) => {
          const close = numberValue(row.Close);
          const swing = String(row.SwingIndicator || "").toLowerCase();
          if (close === null || (swing !== "swing up" && swing !== "swing down")) return null;
          const x = rows.length === 1 ? width / 2 : (index / (rows.length - 1)) * width;
          const y = priceTop + priceHeight - ((close - (priceMin - pricePad)) / ((priceMax + pricePad) - (priceMin - pricePad) || 1)) * priceHeight;
          const up = swing === "swing up";
          return (
            <path
              key={`${row.ObservationDate}-${swing}`}
              d={up ? `M ${x} ${y - 8} L ${x - 8} ${y + 8} L ${x + 8} ${y + 8} Z` : `M ${x} ${y + 8} L ${x - 8} ${y - 8} L ${x + 8} ${y - 8} Z`}
              fill={up ? "#059669" : "#dc2626"}
            />
          );
        })}
        <line x1="0" x2={width} y1={rsi70} y2={rsi70} stroke="#dc2626" strokeDasharray="6 7" />
        <line x1="0" x2={width} y1={rsi30} y2={rsi30} stroke="#059669" strokeDasharray="6 7" />
        <polyline points={rsiPath} fill="none" stroke="#16a34a" strokeWidth="2.2" />
        <text x="0" y="18" fill="#475569" fontSize="13">Close Price and GEX</text>
        <text x="0" y={rsiTop - 12} fill="#475569" fontSize="13">RSI(4)</text>
        <text x="0" y="588" fill="#64748b" fontSize="12">{dateLabel(rows[0].ObservationDate)}</text>
        <text x={width} y="588" textAnchor="end" fill="#64748b" fontSize="12">{dateLabel(rows[rows.length - 1].ObservationDate)}</text>
      </svg>
      <div className="mt-3 flex flex-wrap gap-4 text-xs text-slate-600">
        <span><span className="mr-1 inline-block h-2 w-6 rounded bg-blue-600" />Close</span>
        <span><span className="mr-1 inline-block h-2 w-6 rounded bg-red-600" />GEX</span>
        <span><span className="mr-1 inline-block h-2 w-6 rounded bg-orange-500" />Upper bound</span>
        <span><span className="mr-1 inline-block h-2 w-6 rounded bg-violet-600" />Lower bound</span>
        <span><span className="mr-1 inline-block h-2 w-6 rounded bg-green-600" />RSI(4)</span>
      </div>
    </div>
  );
}

export default function CalculatedGexPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [stockCode, setStockCode] = useState("QQQ.US");
  const [dateFrom, setDateFrom] = useState(defaultFromDate);
  const [dateTo, setDateTo] = useState(() => isoDate(new Date()));
  const [data, setData] = useState<GexResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [page, setPage] = useState(1);

  const loadData = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({
        stock_code: stockCode.trim().toUpperCase(),
        date_from: dateFrom,
        date_to: dateTo,
      });
      const response = await authenticatedFetch(`${baseUrl}/api/calculated-gex?${params}`, { cache: "no-store" });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      setData(body);
      setPage(1);
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, dateFrom, dateTo, stockCode]);

  useEffect(() => {
    void loadData();
  }, []);

  const rowsDesc = useMemo(() => [...(data?.rows || [])].reverse(), [data]);
  const totalPages = Math.max(1, Math.ceil(rowsDesc.length / PAGE_SIZE));
  const visibleRows = rowsDesc.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const latest = data?.rows[data.rows.length - 1];

  const submit = (event: FormEvent) => {
    event.preventDefault();
    void loadData();
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Calculated GEX by Stocks"
        subtitle="Close price, calculated GEX, swing markers and RSI(4) from StockDB_US calculated GEX history."
        actions={<Button onClick={loadData} disabled={loading}>{loading ? "Loading..." : "Refresh"}</Button>}
      />

      {error ? <Alert variant="danger">Error: {error}</Alert> : null}

      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={submit} className="grid gap-4 md:grid-cols-[1.2fr_1fr_1fr_auto] md:items-end">
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Stock Code</span>
              <Input value={stockCode} onChange={(event) => setStockCode(event.target.value)} placeholder="QQQ.US" />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Date From</span>
              <Input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Date To</span>
              <Input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} />
            </label>
            <Button type="submit" disabled={loading}>{loading ? "Loading..." : "Apply"}</Button>
          </form>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="text-xs uppercase tracking-wide text-slate-500">Rows</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{data?.count ?? 0}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-xs uppercase tracking-wide text-slate-500">Latest Close</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{compactNumber(latest?.Close)}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-xs uppercase tracking-wide text-slate-500">Latest GEX</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{latest?.FormattedGEX || compactNumber(latest?.GEX)}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-xs uppercase tracking-wide text-slate-500">RSI(4)</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{compactNumber(latest?.RSI, 1)}</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{data?.stock_code || stockCode.toUpperCase()} Price vs GEX</CardTitle>
        </CardHeader>
        <CardContent>
          {data?.rows?.length ? <Chart data={data} /> : (
            <div className="py-16 text-center text-sm text-slate-500">
              {loading ? "Loading calculated GEX data..." : "No data found for the selected stock and date range."}
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <CardTitle>History</CardTitle>
          <div className="flex items-center gap-2 text-sm text-slate-600">
            <Button variant="secondary" size="sm" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>Previous</Button>
            <span>Page {page} of {totalPages}</span>
            <Button variant="secondary" size="sm" onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>Next</Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto rounded-md border border-slate-200">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-3 py-3">Date</th>
                  <th className="px-3 py-3 text-right">Options</th>
                  <th className="px-3 py-3 text-right">Close</th>
                  <th className="px-3 py-3 text-right">Close Change</th>
                  <th className="px-3 py-3 text-right">GEX</th>
                  <th className="px-3 py-3 text-right">GEX Change</th>
                  <th className="px-3 py-3">Swing</th>
                  <th className="px-3 py-3">Potential Swing</th>
                  <th className="px-3 py-3 text-right">RSI(4)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visibleRows.map((row) => (
                  <tr key={row.ObservationDate} className="hover:bg-slate-50">
                    <td className="whitespace-nowrap px-3 py-3 font-medium text-slate-900">{dateLabel(row.ObservationDate)}</td>
                    <td className="px-3 py-3 text-right">{compactNumber(row.NoOfOption, 0)}</td>
                    <td className="px-3 py-3 text-right">{compactNumber(row.Close)}</td>
                    <td className={["px-3 py-3 text-right", (row.ClosePriceChange || 0) >= 0 ? "text-emerald-700" : "text-red-700"].join(" ")}>
                      {pct(row.ClosePriceChange)}
                    </td>
                    <td className="px-3 py-3 text-right">{row.FormattedGEX || compactNumber(row.GEX)}</td>
                    <td className={["px-3 py-3 text-right", (row.GEXChange || 0) >= 0 ? "text-emerald-700" : "text-red-700"].join(" ")}>
                      {compactNumber(row.GEXChange)}
                    </td>
                    <td className="px-3 py-3">{row.SwingIndicator || "-"}</td>
                    <td className="px-3 py-3">{row.PotentialSwingIndicator || "-"}</td>
                    <td className="px-3 py-3 text-right">{compactNumber(row.RSI, 1)}</td>
                  </tr>
                ))}
                {!visibleRows.length ? (
                  <tr>
                    <td className="px-3 py-8 text-center text-slate-500" colSpan={9}>
                      {loading ? "Loading calculated GEX data..." : "No data found."}
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
