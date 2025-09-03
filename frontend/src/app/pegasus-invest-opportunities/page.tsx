"use client";

import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

const PEGASUS_GROUP_OPTIONS = [
  "Tier 1",
  "Tier 2", 
  "Tier 3",
];

export default function PegasusInvestOpportunitiesPage() {
  const [observationDate, setObservationDate] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [pegasusGroup, setPegasusGroup] = useState<string>(PEGASUS_GROUP_OPTIONS[0]);
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    if (!observationDate) return;
    setLoading(true);
    setError("");
    authenticatedFetch(`${baseUrl}/api/pegasus-invest-opportunities?observation_date=${observationDate}&tier=${encodeURIComponent(pegasusGroup)}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setRows)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [baseUrl, observationDate, pegasusGroup]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-emerald-500 to-green-600 bg-clip-text text-transparent">Pegasus Invest Opportunities</h1>

        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
            <div className="flex items-center gap-2">
              <button
                type="button"
                aria-label="Previous business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() - 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-emerald-50"
              >
                ←
              </button>
              <input
                type="date"
                value={observationDate}
                onChange={(e) => setObservationDate(e.target.value)}
                readOnly
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/40 focus:border-emerald-400/40"
              />
              <button
                type="button"
                aria-label="Next business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() + 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-emerald-50"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1 text-slate-600">Pegasus Group</label>
            <select
              value={pegasusGroup}
              onChange={(e) => setPegasusGroup(e.target.value)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/40 focus:border-emerald-400/40"
            >
              {PEGASUS_GROUP_OPTIONS.map((o) => (
                <option key={o} value={o}>{o}</option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-emerald-300/40 border-t-emerald-500" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
              <tr>
                {(rows?.[0] ? Object.keys(rows[0]) : ["No data"]).map((k) => (
                  <th key={k} className="px-3 py-3 text-left font-medium whitespace-nowrap">{k}</th>
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
                  <tr key={i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-emerald-50/40`}>
                    {Object.keys(rows[0]).map((k) => (
                      <td key={k} className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{String(row[k] ?? "")}</td>
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