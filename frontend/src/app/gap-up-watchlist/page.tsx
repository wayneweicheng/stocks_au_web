"use client";

import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

export default function GapUpWatchlistPage() {
  const [dateFrom, setDateFrom] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [refreshing, setRefreshing] = useState(false);

  // Fixed parameters (read-only, embedded in SQL logic)
  const gapPct = 6.0;
  const volumeMultiplier = 5.0;
  const minVolumeValue = 600000;
  const minPrice = 0.02;
  const closeLocation = 0.5;

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const changeKeys = new Set(["Change%", "GapUp%", "1dChange", "2dChange", "5dChange", "10dChange"]);
  const changeClassFor = (n: number) => {
    if (!isFinite(n)) return "";
    if (n >= 20) return " text-green-800 bg-green-100";
    if (n >= 10) return " text-green-700 bg-green-50";
    if (n >= 5) return " text-green-600 bg-green-50";
    if (n > 0) return " text-green-600 bg-green-50";
    if (n <= -20) return " text-red-800 bg-red-100";
    if (n <= -10) return " text-red-700 bg-red-50";
    if (n <= -5) return " text-red-600 bg-red-50";
    if (n < 0) return " text-red-600 bg-red-50";
    return "";
  };

  const fetchData = (refresh: boolean = false) => {
    if (!dateFrom) return;
    setLoading(true);
    setError("");
    const params = new URLSearchParams({
      date: dateFrom,
      refresh: refresh.toString(),
    });
    authenticatedFetch(`${baseUrl}/api/gap-up-watchlist?${params}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => {
        setLoading(false);
        setRefreshing(false);
      });
  };

  const handleRefresh = () => {
    setRefreshing(true);
    fetchData(true);
  };

  useEffect(() => {
    fetchData(false);
  }, [baseUrl, dateFrom]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-cyan-600 bg-clip-text text-transparent">
          Gap Up Watchlist
        </h1>

        <div className="grid gap-4 sm:grid-cols-3 lg:grid-cols-7 mb-6">
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
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-blue-50"
              >
                ←
              </button>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
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
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-blue-50"
              >
                →
              </button>
            </div>
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Gap % (vs Prev High)
            </label>
            <input
              type="number"
              step="0.1"
              value={gapPct}
              disabled
              className="w-full rounded-md border border-slate-300 bg-slate-100 px-3 py-2 text-sm text-slate-500 cursor-not-allowed"
              title="Fixed parameter (embedded in SQL logic)"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Volume Multiplier
            </label>
            <input
              type="number"
              step="0.1"
              value={volumeMultiplier}
              disabled
              className="w-full rounded-md border border-slate-300 bg-slate-100 px-3 py-2 text-sm text-slate-500 cursor-not-allowed"
              title="Fixed parameter (embedded in SQL logic)"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Min Volume ($)
            </label>
            <input
              type="number"
              value={minVolumeValue}
              disabled
              className="w-full rounded-md border border-slate-300 bg-slate-100 px-3 py-2 text-sm text-slate-500 cursor-not-allowed"
              title="Fixed parameter (embedded in SQL logic)"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Min Price ($)
            </label>
            <input
              type="number"
              step="0.01"
              value={minPrice}
              disabled
              className="w-full rounded-md border border-slate-300 bg-slate-100 px-3 py-2 text-sm text-slate-500 cursor-not-allowed"
              title="Fixed parameter (embedded in SQL logic)"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Close Location (0-1)
            </label>
            <input
              type="number"
              step="0.1"
              value={closeLocation}
              disabled
              className="w-full rounded-md border border-slate-300 bg-slate-100 px-3 py-2 text-sm text-slate-500 cursor-not-allowed"
              title="Fixed parameter (embedded in SQL logic)"
            />
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">&nbsp;</label>
            <button
              type="button"
              onClick={handleRefresh}
              disabled={refreshing || loading}
              className="w-full rounded-md border border-blue-300 bg-blue-100 px-3 py-2 text-sm text-blue-700 hover:bg-blue-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              title="Recalculate results for this date"
            >
              {refreshing ? "Refreshing..." : "🔄 Refresh Data"}
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="mb-4 rounded-md border border-blue-200 bg-blue-50 text-blue-800 px-3 py-2 text-sm">
          <strong>Gap Up Strategy Conditions:</strong>
          <ul className="mt-2 ml-4 list-disc space-y-1">
            <li>
              <strong>Gap Up:</strong> Today's low must be at least {gapPct}% higher than yesterday's high
            </li>
            <li>
              <strong>Volume Surge:</strong> Today's volume must be at least {volumeMultiplier}x the 20-day average AND at least ${minVolumeValue.toLocaleString()}
            </li>
            <li>
              <strong>Close Location:</strong> (Close - Low) / (High - Low) must be greater than {closeLocation} (stock closes in upper portion of range)
            </li>
            <li>
              <strong>Bullish Candle:</strong> Close must be higher than Open
            </li>
            <li>
              <strong>New High:</strong> Close must be higher than the highest close in the last 60 days
            </li>
            <li>
              <strong>Price Filter:</strong> Stock price must be above ${minPrice}
            </li>
          </ul>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
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
                    No gap up candidates found.
                  </td>
                </tr>
              ) : (
                rows.map((row, i) => (
                  <tr
                    key={i}
                    className={`transition-colors ${
                      i % 2 ? "bg-slate-50" : ""
                    } hover:bg-blue-50/40`}
                  >
                    {Object.keys(rows[0]).map((k) => {
                      const value = row[k];
                      let cellClass = "px-3 py-2 whitespace-nowrap border-b border-slate-100";

                      // Color scale for change fields
                      if (changeKeys.has(k)) {
                        const num =
                          typeof value === "number"
                            ? value
                            : (typeof value === "string"
                                ? parseFloat(value.replace(/[, %]+/g, ""))
                                : NaN);
                        if (isFinite(num)) {
                          cellClass += changeClassFor(num) + " font-semibold";
                        }
                      }

                      // Highlight symbol
                      if (k === "Symbol") {
                        cellClass += " text-blue-700 font-semibold";
                      }

                      return (
                        <td key={k} className={cellClass}>
                          {[...changeKeys].includes(k)
                            ? (value === null || value === undefined ? "N/A" : String(value))
                            : String(value ?? "")}
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
            Found {rows.length} gap up candidate{rows.length !== 1 ? "s" : ""}
          </div>
        )}
      </div>
    </div>
  );
}
