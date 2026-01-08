"use client";

import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

export default function BreakoutWatchlistPage() {
  const [dateFrom, setDateFrom] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [minTurnover, setMinTurnover] = useState<number>(500000);
  const [minPctGain, setMinPctGain] = useState<number>(8.0);
  const [maxPrice, setMaxPrice] = useState<number>(5.0);
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    if (!dateFrom) return;
    setLoading(true);
    setError("");
    const params = new URLSearchParams({
      date: dateFrom,
      min_turnover: minTurnover.toString(),
      min_pct_gain: minPctGain.toString(),
      max_price: maxPrice.toString(),
    });
    authenticatedFetch(`${baseUrl}/api/breakout-watchlist?${params}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [baseUrl, dateFrom, minTurnover, minPctGain, maxPrice]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-purple-500 to-pink-600 bg-clip-text text-transparent">
          Breakout Watch List
        </h1>

        <div className="grid gap-4 sm:grid-cols-4 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Date</label>
            <div className="flex items-center gap-2">
              <button
                type="button"
                aria-label="Previous business day"
                onClick={() => {
                  const d = new Date(dateFrom);
                  d.setDate(d.getDate() - 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                  setDateFrom(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-purple-50"
              >
                ←
              </button>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40"
              />
              <button
                type="button"
                aria-label="Next business day"
                onClick={() => {
                  const d = new Date(dateFrom);
                  d.setDate(d.getDate() + 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                  setDateFrom(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-purple-50"
              >
                →
              </button>
            </div>
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Min Turnover ($)
            </label>
            <input
              type="number"
              value={minTurnover}
              onChange={(e) => setMinTurnover(Number(e.target.value))}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Min % Gain
            </label>
            <input
              type="number"
              step="0.1"
              value={minPctGain}
              onChange={(e) => setMinPctGain(Number(e.target.value))}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Max Price ($)
            </label>
            <input
              type="number"
              step="0.1"
              value={maxPrice}
              onChange={(e) => setMaxPrice(Number(e.target.value))}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40"
            />
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="mb-4 rounded-md border border-purple-200 bg-purple-50 text-purple-800 px-3 py-2 text-sm">
          <strong>Pattern Definitions:</strong>
          <ul className="mt-2 ml-4 list-disc">
            <li>
              <strong>FRESH BREAKOUT:</strong> Stock gained {minPctGain}%+ today with turnover ${minTurnover.toLocaleString()}+ and volume surge 2x+ 20-day average
            </li>
            <li>
              <strong>CONSOLIDATION:</strong> Stock had a breakout (8%+ gain with 2x volume) within last 1-3 days, now consolidating (-3% to +3%)
            </li>
          </ul>
          <p className="mt-2 text-xs">
            <strong>VolRatio:</strong> Shows how many times the breakout day volume exceeded the 20-day average (e.g., 2.5x means 2.5 times normal volume)
          </p>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-purple-300/40 border-t-purple-500" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
              <tr>
                {(rows?.[0] ? Object.keys(rows[0]) : ["No data"]).map((k) => (
                  <th
                    key={k}
                    className="px-3 py-3 text-left font-medium whitespace-nowrap"
                  >
                    {k}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td className="px-3 py-3" colSpan={99}>
                    Loading...
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td className="px-3 py-3" colSpan={99}>
                    No breakout candidates found.
                  </td>
                </tr>
              ) : (
                rows.map((row, i) => (
                  <tr
                    key={i}
                    className={`transition-colors ${
                      i % 2 ? "bg-slate-50" : ""
                    } hover:bg-purple-50/40`}
                  >
                    {Object.keys(rows[0]).map((k) => {
                      const value = row[k];
                      let cellClass = "px-3 py-2 whitespace-nowrap border-b border-slate-100";

                      // Highlight positive changes in green, negative in red
                      if (k === "Change%" && typeof value === "number") {
                        cellClass += value > 0 ? " text-green-600 font-semibold" : " text-red-600 font-semibold";
                      }

                      // Highlight pattern type
                      if (k === "Pattern") {
                        cellClass += value === "FRESH BREAKOUT"
                          ? " text-purple-700 font-semibold"
                          : " text-pink-700 font-semibold";
                      }

                      return (
                        <td key={k} className={cellClass}>
                          {String(value ?? "")}
                        </td>
                      );
                    })}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {rows.length > 0 && (
          <div className="mt-4 text-sm text-slate-600">
            Found {rows.length} breakout candidate{rows.length !== 1 ? "s" : ""}
          </div>
        )}
      </div>
    </div>
  );
}
