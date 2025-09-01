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

  // Compute dynamic color scale from returned data
  const { posMax, negMax, columns } = useMemo(() => {
    if (!txns || txns.length === 0) return { posMax: 0, negMax: 0, columns: [] as string[] };
    const cols = Object.keys(txns[0]);
    const transKey = cols.find((c) => c.toLowerCase() === "transvalue") || "TransValue";
    const indKey = cols.find((c) => c.toLowerCase().includes("actbuysell")) || "ActBuySellInd";
    let pMax = 0;
    let nMax = 0;
    const toNum = (val: any) => {
      if (val == null) return 0;
      if (typeof val === "number") return val;
      const s = String(val).replace(/,/g, "");
      const num = Number(s);
      return Number.isFinite(num) ? num : 0;
    };
    for (const row of txns) {
      const v = toNum(row[transKey]);
      const ind = String(row[indKey] ?? "");
      if (ind === "B") pMax = Math.max(pMax, Math.abs(v));
      else if (ind === "S") nMax = Math.max(nMax, Math.abs(v));
    }
    return { posMax: pMax, negMax: nMax, columns: cols };
  }, [txns]);

  const rowStyle = (row: Txn): any => {
    if (!row || !columns.length) return undefined;
    const transKey = columns.find((c) => c.toLowerCase() === "transvalue") || "TransValue";
    const indKey = columns.find((c) => c.toLowerCase().includes("actbuysell")) || "ActBuySellInd";
    const ind = String(row[indKey] ?? "");
    const raw = row[transKey];
    const value = typeof raw === "number" ? raw : Number(String(raw ?? "").replace(/,/g, "")) || 0;
    if (ind === "B" && posMax > 0) {
      const alpha = Math.max(0.06, Math.min(0.85, Math.abs(value) / posMax));
      return { backgroundColor: `rgba(16, 185, 129, ${alpha})` };
    }
    if (ind === "S" && negMax > 0) {
      const alpha = Math.max(0.06, Math.min(0.85, Math.abs(value) / negMax));
      return { backgroundColor: `rgba(239, 68, 68, ${alpha})` };
    }
    return undefined;
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-6xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-emerald-500 to-green-600 bg-clip-text text-transparent">Order Book & Transaction History</h1>

        <div className="grid gap-4 sm:grid-cols-3 mb-6">
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
                className="rounded-md border border-white/20 bg-white/5 px-2 py-2 text-sm hover:bg-white/10"
              >
                ←
              </button>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                readOnly
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/40 focus:border-emerald-400/40"
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
            <label className="block text-sm mb-1 text-slate-600">Stock</label>
            <select
              value={selected}
              onChange={(e) => setSelected(e.target.value)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400/40 focus:border-emerald-400/40"
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

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-slate-900/30 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-emerald-300/40 border-t-emerald-500" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
              <tr>
                {(txns?.[0] ? Object.keys(txns[0]) : ["No data"]).map((k) => (
                  <th key={k} className="px-3 py-3 text-left font-medium whitespace-nowrap">{k}</th>
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
                  <tr key={i} className="transition-colors" style={rowStyle(row)}>
                    {Object.keys(txns[0]).map((k) => (
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


