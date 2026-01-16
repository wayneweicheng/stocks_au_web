"use client";

import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type SortOption = "Ann Date" | "MC";

export default function TradingHaltPage() {
  const [rows, setRows] = useState<Record<string, unknown>[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [sortBy, setSortBy] = useState<SortOption>("Ann Date");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const fetchData = () => {
    setLoading(true);
    setError("");
    const params = new URLSearchParams({
      sortBy: sortBy,
    });
    authenticatedFetch(`${baseUrl}/api/trading-halt?${params}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData();
  }, [baseUrl, sortBy]);

  // Identify the ASXCode column for clickable links
  const getAsxCodeKey = (row: Record<string, unknown>): string | null => {
    const keys = Object.keys(row);
    for (const key of keys) {
      if (key.toLowerCase().includes("asxcode") || key.toLowerCase() === "code" || key.toLowerCase() === "symbol") {
        return key;
      }
    }
    return null;
  };

  const asxCodeKey = rows.length > 0 ? getAsxCodeKey(rows[0]) : null;

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-red-500 to-orange-600 bg-clip-text text-transparent">
          Trading Halt
        </h1>

        <div className="grid gap-4 sm:grid-cols-4 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Order By</label>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as SortOption)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400/40 focus:border-red-400/40"
            >
              <option value="Ann Date">Announcement Date</option>
              <option value="MC">Market Cap</option>
            </select>
          </div>
          <div>
            <label className="block text-sm mb-1 text-slate-600">&nbsp;</label>
            <button
              type="button"
              onClick={fetchData}
              disabled={loading}
              className="w-full rounded-md border border-red-300 bg-red-100 px-3 py-2 text-sm text-red-700 hover:bg-red-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? "Loading..." : "Refresh"}
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="mb-4 rounded-md border border-orange-200 bg-orange-50 text-orange-800 px-3 py-2 text-sm">
          <strong>Trading Halt:</strong> Stocks currently in trading halt on the ASX. Click on a stock code to view its charts.
        </div>

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-red-300/40 border-t-red-500" />
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
              {loading && rows.length === 0 ? (
                <tr>
                  <td className="px-3 py-3" colSpan={99}>
                    Loading...
                  </td>
                </tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td className="px-3 py-3" colSpan={99}>
                    No trading halt stocks found.
                  </td>
                </tr>
              ) : (
                rows.map((row, i) => (
                  <tr
                    key={i}
                    className={`transition-colors ${
                      i % 2 ? "bg-slate-50" : ""
                    } hover:bg-red-50/40`}
                  >
                    {Object.keys(rows[0]).map((k) => {
                      const value = row[k];
                      const cellClass = "px-3 py-2 whitespace-nowrap border-b border-slate-100";

                      // Make ASXCode column clickable to open integrated charts
                      if (asxCodeKey && k === asxCodeKey && value) {
                        const rawCode = String(value);
                        // Extract just the stock code (first 3-4 chars before any suffix)
                        const symbol = rawCode.replace(/\.AX$/i, "").replace(/\.AU$/i, "").substring(0, Math.min(rawCode.length, 4)).trim();
                        return (
                          <td key={k} className={cellClass}>
                            <button
                              onClick={() => {
                                window.open(`/integrated-charts?symbol=${encodeURIComponent(symbol)}&market=ASX`, "_blank");
                              }}
                              className="text-red-600 hover:text-red-800 hover:underline font-medium cursor-pointer"
                              title={`Open charts for ${symbol}`}
                            >
                              {rawCode}
                            </button>
                          </td>
                        );
                      }

                      return (
                        <td key={k} className={cellClass}>
                          {value === null || value === undefined ? "" : String(value)}
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
            Found {rows.length} stock{rows.length !== 1 ? "s" : ""} in trading halt
          </div>
        )}
      </div>
    </div>
  );
}
