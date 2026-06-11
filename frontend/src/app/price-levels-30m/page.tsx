"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import Select from "../components/ui/Select";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

interface PriceRange {
  price: number;
  range_low: number;
  range_high: number;
  touches: number;
  distance_pct: number;
  distance_atr: number;
  latest_touch: string | null;
  sources: Array<"30m" | "gamma">;
  gamma_wall: {
    strike: number;
    open_interest: number;
    nearest_expiry: string;
  } | null;
}

interface StockLevels {
  stock_code: string;
  database_code: string;
  latest_close: number;
  latest_bar_time: string;
  bar_count: number;
  median_bar_range: number;
  atr_daily: number | null;
  atr_period: number;
  supports: PriceRange[];
  resistances: PriceRange[];
}

interface LevelsResponse {
  observation_date: string | null;
  lookback_days: number;
  count: number;
  stocks: StockLevels[];
}

function price(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(value)) return "n/a";
  const digits = Math.abs(value) < 10 ? 3 : 2;
  return value.toLocaleString(undefined, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function LevelCell({ level, tone }: { level?: PriceRange; tone: "support" | "resistance" }) {
  if (!level) return <span className="text-slate-400">n/a</span>;
  const color = tone === "support" ? "text-emerald-700" : "text-red-700";
  const source = level.sources.includes("gamma")
    ? (level.sources.includes("30m") ? "30M + Gamma" : "Gamma wall")
    : "30M structure";
  return (
    <div className="min-w-[180px]">
      <div className={`font-semibold ${color}`}>
        {price(level.range_low)} - {price(level.range_high)}
      </div>
      <div className="mt-1 text-xs text-slate-500">
        {level.distance_pct > 0 ? "+" : ""}{level.distance_pct.toFixed(2)}%, {level.distance_atr.toFixed(2)} ATR
        {level.touches > 0 ? `, ${level.touches} touch${level.touches === 1 ? "" : "es"}` : ""}
      </div>
      <div className="mt-1 text-xs font-medium text-indigo-600">{source}</div>
      {level.gamma_wall ? (
        <div className="mt-1 text-xs text-slate-500">
          Wall {price(level.gamma_wall.strike)}, OI {level.gamma_wall.open_interest.toLocaleString()}
        </div>
      ) : null}
    </div>
  );
}

export default function PriceLevels30mPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [data, setData] = useState<LevelsResponse | null>(null);
  const [observationDate, setObservationDate] = useState("");
  const [lookbackDays, setLookbackDays] = useState("10");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadLevels = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({
        lookback_days: String(Math.max(3, Math.min(30, Number(lookbackDays) || 10))),
      });
      if (observationDate) params.set("observation_date", observationDate);
      const response = await authenticatedFetch(`${baseUrl}/api/price-levels-30m?${params}`, {
        cache: "no-store",
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      setData(body);
      if (!observationDate && body.observation_date) setObservationDate(body.observation_date);
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, lookbackDays, observationDate]);

  useEffect(() => {
    void loadLevels();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const visibleStocks = useMemo(() => {
    const query = search.trim().toUpperCase();
    return (data?.stocks || []).filter((stock) => !query || stock.stock_code.toUpperCase().includes(query));
  }, [data, search]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="30-Minute Support & Resistance"
        subtitle="Price ranges calculated from the same 30-minute bars used by the Market Flow prompt."
        actions={<Button onClick={loadLevels} disabled={loading}>{loading ? "Refreshing..." : "Refresh"}</Button>}
      />

      {error ? <Alert variant="danger">Error: {error}</Alert> : null}

      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-4">
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Observation Date</span>
              <Input type="date" value={observationDate} onChange={(event) => setObservationDate(event.target.value)} />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Lookback</span>
              <Select value={lookbackDays} onChange={(event) => setLookbackDays(event.target.value)}>
                <option value="5">5 days</option>
                <option value="10">10 days</option>
                <option value="15">15 days</option>
                <option value="20">20 days</option>
                <option value="30">30 days</option>
              </Select>
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Stock Search</span>
              <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="AVGO" />
            </label>
            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
              <div className="text-xs uppercase tracking-wide text-slate-500">Stocks</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">
                {visibleStocks.length.toLocaleString()}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Price Levels</CardTitle>
          <p className="mt-1 text-sm text-slate-600">
            Zone 1 is nearest to spot. Zones must be 0.33-3.0 times the 14-day daily ATR from the latest close.
            Near-term put and call OI walls are merged when they reinforce a 30-minute range.
          </p>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto rounded-md border border-slate-200">
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-3 py-3">Stock</th>
                  <th className="px-3 py-3 text-right">Latest Close</th>
                  <th className="px-3 py-3 text-right">Daily ATR(14)</th>
                  <th className="px-3 py-3">Support Zone 1</th>
                  <th className="px-3 py-3">Support Zone 2</th>
                  <th className="px-3 py-3">Resistance Zone 1</th>
                  <th className="px-3 py-3">Resistance Zone 2</th>
                  <th className="px-3 py-3 text-right">30M Bars</th>
                  <th className="px-3 py-3">Latest Bar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visibleStocks.map((stock) => (
                  <tr key={stock.database_code} className="align-top hover:bg-slate-50">
                    <td className="px-3 py-3 font-semibold text-slate-900">{stock.stock_code}</td>
                    <td className="px-3 py-3 text-right font-medium">{price(stock.latest_close)}</td>
                    <td className="px-3 py-3 text-right text-slate-600">{price(stock.atr_daily)}</td>
                    <td className="px-3 py-3"><LevelCell level={stock.supports[0]} tone="support" /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.supports[1]} tone="support" /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.resistances[0]} tone="resistance" /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.resistances[1]} tone="resistance" /></td>
                    <td className="px-3 py-3 text-right">{stock.bar_count}</td>
                    <td className="whitespace-nowrap px-3 py-3 text-xs text-slate-500">
                      {new Date(stock.latest_bar_time).toLocaleString()}
                    </td>
                  </tr>
                ))}
                {!visibleStocks.length ? (
                  <tr>
                    <td className="px-3 py-8 text-center text-slate-500" colSpan={9}>
                      {loading ? "Loading 30-minute levels..." : "No 30-minute price data found."}
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
