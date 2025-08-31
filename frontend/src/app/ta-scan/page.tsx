"use client";

import { useEffect, useMemo, useState } from "react";

const SORT_OPTIONS = [
  "Price Changes",
  "Alert CreateDate",
  "Alert Occurrence",
  "Alert Type Name",
  "Market Cap",
  "Value Over MC",
];

export default function TAScanPage() {
  const [dateFrom, setDateFrom] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [sortBy, setSortBy] = useState<string>(SORT_OPTIONS[0]);
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    if (!dateFrom) return;
    setLoading(true);
    setError("");
    fetch(`${baseUrl}/api/ta-scan?date=${dateFrom}&sort_by=${encodeURIComponent(sortBy)}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [baseUrl, dateFrom, sortBy]);

  return (
    <div className="min-h-screen text-slate-100">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-cyan-300 to-blue-400 bg-clip-text text-transparent">TA Scan Results</h1>

        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-300">Date</label>
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
                className="rounded-md border border-white/20 bg-white/5 px-2 py-2 text-sm hover:bg-white/10"
              >
                ←
              </button>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                readOnly
                className="w-full rounded-md border border-white/20 bg-white/5 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-cyan-400/40 focus:border-cyan-400/40"
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
                className="rounded-md border border-white/20 bg-white/5 px-2 py-2 text-sm hover:bg-white/10"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1 text-slate-300">Sort by</label>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="w-full rounded-md border border-white/20 bg-white/5 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-cyan-400/40 focus:border-cyan-400/40"
            >
              {SORT_OPTIONS.map((o) => (
                <option key={o} value={o}>{o}</option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-400/40 bg-red-500/10 text-red-300 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="rounded-lg border border-white/10 bg-white/5 overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-slate-900/30 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-cyan-300/40 border-t-cyan-400" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 z-10 bg-slate-900/70 backdrop-blur text-slate-300 uppercase text-xs tracking-wide">
              <tr>
                {(rows?.[0] ? Object.keys(rows[0]) : ["No data"]).map((k) => (
                  <th key={k} className="px-3 py-3 text-left font-medium whitespace-nowrap border-b border-white/10">{k}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td className="px-3 py-3" colSpan={99}>Loading...</td></tr>
              ) : rows.length === 0 ? (
                <tr><td className="px-3 py-3" colSpan={99}>No data found.</td></tr>
              ) : (
                rows.map((row, i) => (
                  <tr key={i} className={`transition-colors ${i % 2 ? "bg-white/2.5" : ""} hover:bg-white/10`}>
                    {Object.keys(rows[0]).map((k) => (
                      <td key={k} className="px-3 py-2 whitespace-nowrap border-b border-white/5">{String(row[k] ?? "")}</td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}


