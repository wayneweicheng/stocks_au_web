"use client";

import { useEffect, useMemo, useState } from "react";

type Stock = { ASXCode?: string; CompanyName?: string } & Record<string, any>;
type Txn = Record<string, any>;

export default function OrderBookPage() {
  const [stocks, setStocks] = useState<Stock[]>([]);
  const [selected, setSelected] = useState<string>("");
  const [dateFrom, setDateFrom] = useState<string>(() => new Date().toISOString().slice(0, 10));
  const [txns, setTxns] = useState<Txn[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  useEffect(() => {
    fetch(`${baseUrl}/api/stocks`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((data) => {
        setStocks(data);
        if (data?.length) setSelected(data[0].ASXCode || "");
      })
      .catch((e) => setError(e.message));
  }, [baseUrl]);

  useEffect(() => {
    if (!selected || !dateFrom) return;
    setLoading(true);
    setError("");
    fetch(`${baseUrl}/api/transactions?date_from=${dateFrom}&code=${encodeURIComponent(selected)}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setTxns)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [baseUrl, selected, dateFrom]);

  const stockOptions = useMemo(() =>
    stocks.map((s) => ({
      value: s.ASXCode || "",
      label: s.CompanyName ? `${s.ASXCode} - ${s.CompanyName}` : (s.ASXCode || ""),
    })), [stocks]);

  return (
    <div className="min-h-screen bg-white dark:bg-slate-950 text-slate-900 dark:text-slate-100">
      <div className="mx-auto max-w-6xl px-6 py-10">
        <h1 className="text-2xl sm:text-3xl font-semibold mb-6">Order Book & Transaction History</h1>

        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1">Date</label>
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
                className="rounded-md border border-slate-300 dark:border-slate-700 px-2 py-2 text-sm"
              >
                ←
              </button>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                readOnly
                className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-3 py-2 text-sm"
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
                className="rounded-md border border-slate-300 dark:border-slate-700 px-2 py-2 text-sm"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1">Stock</label>
            <select
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
              className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-3 py-2 text-sm"
            >
              {stockOptions.map((o) => (
                <option key={o.value} value={o.value}>{o.label}</option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-300 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="rounded-lg border border-slate-200 dark:border-slate-800 overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-white/70 dark:bg-slate-950/70 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-slate-400 border-t-slate-900 dark:border-slate-600 dark:border-t-white" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 dark:bg-slate-900">
              <tr>
                {(txns?.[0] ? Object.keys(txns[0]) : ["No data"]).map((k) => (
                  <th key={k} className="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-300 whitespace-nowrap">{k}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td className="px-3 py-3" colSpan={99}>Loading...</td></tr>
              ) : txns.length === 0 ? (
                <tr><td className="px-3 py-3" colSpan={99}>No data found.</td></tr>
              ) : (
                txns.map((row, i) => (
                  <tr key={i} className={i % 2 ? "bg-slate-50/40 dark:bg-slate-900/40" : ""}>
                    {Object.keys(txns[0]).map((k) => (
                      <td key={k} className="px-3 py-2 whitespace-nowrap">{String(row[k] ?? "")}</td>
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


