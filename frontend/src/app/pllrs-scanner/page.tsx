"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

interface Row { [key: string]: any }

export default function PLLRSScannerPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL as string;

  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const [observationDate, setObservationDate] = useState<string>("");
  const [maxTodayChange, setMaxTodayChange] = useState<string>("");
  const [entryPrice, setEntryPrice] = useState<string>("");
  const [targetPrice, setTargetPrice] = useState<string>("");
  const [stopPrice, setStopPrice] = useState<string>("");
  const [limit, setLimit] = useState<number>(200);

  // Display only these fields (case-insensitive lookup for safety)
  const FIELDS: { keys: string[]; label: string; type?: "date" | "number" | "text"; multiline?: boolean }[] = [
    { keys: ["ObservationDate"], label: "Observation Date", type: "date" },
    { keys: ["ASXCode"], label: "ASX Code" },
    { keys: ["ClosePrice"], label: "Close Price", type: "number" },
    { keys: ["TodayPriceChange"], label: "Today Price Change", type: "number" },
    { keys: ["SupportPrice"], label: "Support Price", type: "number" },
    { keys: ["ResistancePrice"], label: "Resistance Price", type: "number" },
    { keys: ["AggressorBuyRatio"], label: "Aggressor Buy Ratio", type: "number" },
    { keys: ["TotalActiveBuyVolume", "totalActiveBuyVolume"], label: "Total Active Buy Volume", type: "number" },
    { keys: ["TotalActiveSellVolume", "totalActiveSellVolume"], label: "Total Active Sell Volume", type: "number" },
    { keys: ["EntryPrice"], label: "Entry Price", type: "number" },
    { keys: ["TargetPrice"], label: "Target Price", type: "number" },
    { keys: ["StopPrice"], label: "Stop Price", type: "number" },
  ];

  const getValue = (row: Row, keys: string[]) => {
    // Try exact first, then case-insensitive
    for (const k of keys) {
      if (k in row) return row[k];
    }
    const lowerMap: Record<string, any> = {};
    Object.keys(row).forEach((rk) => (lowerMap[rk.toLowerCase()] = row[rk]));
    for (const k of keys) {
      const v = lowerMap[k.toLowerCase()];
      if (v !== undefined) return v;
    }
    return undefined;
  };

  const load = async () => {
    try {
      setLoading(true);
      setError("");
      const params = new URLSearchParams();
      if (observationDate) params.set("observation_date", observationDate);
      if (maxTodayChange) params.set("max_today_change", maxTodayChange);
      if (entryPrice) params.set("entry_price", entryPrice);
      if (targetPrice) params.set("target_price", targetPrice);
      if (stopPrice) params.set("stop_price", stopPrice);
      params.set("limit", String(limit));
      const url = `${baseUrl}/api/pllrs-scanner?${params.toString()}`;
      const res = await authenticatedFetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setRows(data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); /* initial */ // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          PLLRS Scanner Results
        </h1>

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Filters</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
              <input type="date" value={observationDate} onChange={(e) => setObservationDate(e.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Max Today Price Change (≤)</label>
              <input type="number" step="0.000001" value={maxTodayChange} onChange={(e) => setMaxTodayChange(e.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Entry Price</label>
              <input type="number" step="0.000001" value={entryPrice} onChange={(e) => setEntryPrice(e.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Target Price</label>
              <input type="number" step="0.000001" value={targetPrice} onChange={(e) => setTargetPrice(e.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Stop Price</label>
              <input type="number" step="0.000001" value={stopPrice} onChange={(e) => setStopPrice(e.target.value)} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Limit</label>
              <input type="number" min={1} max={2000} value={limit} onChange={(e) => setLimit(parseInt(e.target.value || "200"))} className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40" />
            </div>
          </div>
          <div className="mt-4 flex gap-2">
            <button onClick={load} disabled={loading} className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed">
              {loading ? "Loading..." : "Apply Filters"}
            </button>
          </div>
        </div>

        {error && <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">Error: {error}</div>}

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          <div className="flex items-center justify-between p-4 pb-0">
            <h2 className="text-lg font-semibold">Results</h2>
            <div className="text-sm text-slate-600">{rows.length} rows</div>
          </div>
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}
          {rows.length === 0 ? (
            <div className="p-6 text-center text-slate-500">No results.</div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  {FIELDS.map((f) => (
                    <th key={f.label} className="px-3 py-3 text-left font-medium whitespace-nowrap">{f.label}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                    {FIELDS.map((f) => {
                      const raw = getValue(r, f.keys);
                      let content: string = "-";
                      if (raw !== undefined && raw !== null) {
                        if (f.type === "date") {
                          try { content = new Date(String(raw)).toLocaleString(); } catch { content = String(raw); }
                        } else if (f.type === "number") {
                          const num = Number(raw);
                          content = Number.isFinite(num) ? String(num) : String(raw);
                        } else {
                          content = String(raw);
                        }
                      }
                      return (
                        <td key={f.label} className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{content}</td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}


