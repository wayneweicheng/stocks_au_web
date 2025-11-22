"use client";

import { useEffect, useMemo, useRef, useState } from "react";

interface StrategyOrderType { id: number; name: string; raw: string }

interface StrategyOrder {
  id?: number;
  stock_code: string;
  trade_account_name?: string;
  order_type_id: number;
  trigger_price: number;
  total_volume: number;
  entry_price: number;
  stop_loss_price: number;
  exit_price: number;
  bar_completed_in_min?: string;
  option_symbol?: string | null;
  option_buy_sell?: string | null;
  buy_condition_type?: string | null; // UI: BuyConditionType, stored as BuyConditionType in AdditionalSettings
  created_date?: string;
  order_type?: string;
}

const BAR_MIN_OPTIONS = ["5 mins", "15 mins", "30 mins", "1 hour"] as const;
const OPTION_BUY_SELL = ["N/A", "SELL", "BUY"] as const;
const BUY_CONDITION_TYPES = ["N/A", "SMA_UPTURN", "DRAGONFLY", "DROP_WINDOW_REVERSAL"] as const;

export default function StrategyOrdersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const [types, setTypes] = useState<StrategyOrderType[]>([]);
  const [selectedTypeId, setSelectedTypeId] = useState<number | null>(null);
  const [orders, setOrders] = useState<StrategyOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string>("");
  const [error, setError] = useState<string>("");
  const [editingId, setEditingId] = useState<number | null>(null);

  const [form, setForm] = useState<StrategyOrder>({
    stock_code: "",
    order_type_id: -1,
    trigger_price: 0,
    total_volume: 0,
    entry_price: 0,
    stop_loss_price: 0,
    exit_price: 0,
    bar_completed_in_min: "5 mins",
    option_symbol: undefined,
    option_buy_sell: "N/A",
    buy_condition_type: "N/A",
  });

  const profitStats = useMemo(() => {
    const qty = Number(form.total_volume || 0);
    const entry = Number(form.entry_price || 0);
    const stop = Number(form.stop_loss_price || 0);
    const exit = Number(form.exit_price || 0);
    if (qty <= 0 || entry <= 0 || stop <= 0 || exit <= 0) {
      return null;
    }
    const multiplier = (form.stock_code || "").includes("_") ? 5 : 1;
    const potentialLoss = (entry - stop) * qty * multiplier;
    const potentialProfit = (exit - entry) * qty * multiplier;
    const ratio = potentialLoss > 0 ? potentialProfit / potentialLoss : null;
    const percChangeWin = entry > 0 ? Math.abs(((exit - entry) * 100) / entry) : null;
    const percChangeLoss = entry > 0 ? Math.abs(((entry - stop) * 100) / entry) : null;
    const tradeValue = entry * qty;
    return { potentialLoss, potentialProfit, ratio, percChangeWin, percChangeLoss, tradeValue };
  }, [form.total_volume, form.entry_price, form.stop_loss_price, form.exit_price, form.stock_code]);

  useEffect(() => {
    const loadTypes = async () => {
      try {
        const res = await fetch(`${baseUrl}/api/strategy-orders/types`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setTypes(data);
        const firstValid = data.find((x: StrategyOrderType) => x.id !== -1);
        setSelectedTypeId(firstValid ? firstValid.id : -1);
        setForm((prev) => ({ ...prev, order_type_id: firstValid ? firstValid.id : -1 }));
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : "Unknown error");
      }
    };
    loadTypes();
  }, [baseUrl]);

  const latestRequestId = useRef(0);

  const loadOrders = async (typeId: number | null) => {
    try {
      setLoading(true);
      const query = typeId != null ? `?order_type_id=${typeId}` : "";
      const tsSep = query ? "&" : "?";
      const url = `${baseUrl}/api/strategy-orders${query}${tsSep}_ts=${Date.now()}`;
      const requestId = ++latestRequestId.current;
      const res = await fetch(url, { cache: 'no-store', headers: { 'Cache-Control': 'no-cache' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (requestId === latestRequestId.current) {
        setOrders(Array.isArray(data) ? data : []);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders(selectedTypeId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedTypeId, baseUrl]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setMessage("");
    setSubmitting(true);
    try {
      const normalized = (form.stock_code || "").trim().toUpperCase();
      let stockCode = normalized;
      if (normalized && normalized.indexOf(".") === -1) {
        stockCode = `${normalized}.US`;
      }
      const payload = {
        ...form,
        stock_code: stockCode,
        buy_condition_type: (form.buy_condition_type ?? "N/A") === "N/A" ? null : form.buy_condition_type,
      };

      let res: Response;
      if (editingId) {
        res = await fetch(`${baseUrl}/api/strategy-orders/${editingId}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else {
        res = await fetch(`${baseUrl}/api/strategy-orders`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      setMessage(result.message || "Success");
      setEditingId(null);
      setForm({
        stock_code: "",
        order_type_id: selectedTypeId ?? -1,
        trigger_price: 0,
        total_volume: 0,
        entry_price: 0,
        stop_loss_price: 0,
        exit_price: 0,
        bar_completed_in_min: "5 mins",
        option_symbol: undefined,
        option_buy_sell: "N/A",
        buy_condition_type: "N/A",
      });
      const typeIdToLoad = selectedTypeId; // snapshot
      await loadOrders(typeIdToLoad);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = (order: StrategyOrder) => {
    setEditingId(order.id || null);
    setForm({
      stock_code: order.stock_code,
      order_type_id: order.order_type_id ?? selectedTypeId ?? -1,
      trigger_price: order.trigger_price,
      total_volume: order.total_volume,
      entry_price: order.entry_price,
      stop_loss_price: order.stop_loss_price,
      exit_price: order.exit_price,
      bar_completed_in_min: order.bar_completed_in_min,
      option_symbol: order.option_symbol,
      option_buy_sell: order.option_buy_sell ?? "N/A",
      buy_condition_type: order.buy_condition_type ?? "N/A",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleCancel = () => {
    setEditingId(null);
    setForm({
      stock_code: "",
      order_type_id: selectedTypeId ?? -1,
      trigger_price: 0,
      total_volume: 0,
      entry_price: 0,
      stop_loss_price: 0,
      exit_price: 0,
      bar_completed_in_min: "5 mins",
      option_symbol: undefined,
      option_buy_sell: "N/A",
      buy_condition_type: "N/A",
    });
  };

  const handleDelete = async (id: number) => {
    if (!confirm("Are you sure you want to delete this strategy order?")) return;
    try {
      const res = await fetch(`${baseUrl}/api/strategy-orders/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      setMessage(result.message || "Deleted");
      const typeIdToLoad = selectedTypeId; // snapshot
      await loadOrders(typeIdToLoad);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    }
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          Manage Strategy Orders
        </h1>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">Error: {error}</div>
        )}
        {message && (
          <div className="mb-4 rounded-md border border-green-200 bg-green-50 text-green-700 px-3 py-2 text-sm">{message}</div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">{editingId ? "Edit Strategy Order" : "Create New Strategy Order"}</h2>
          <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Type</label>
              <select
                value={form.order_type_id}
                onChange={(e) => {
                  const val = parseInt(e.target.value, 10);
                  setForm({ ...form, order_type_id: val });
                  setSelectedTypeId(val);
                }}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {types.map((t) => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Stock Code</label>
              <input
                type="text"
                value={form.stock_code}
                onChange={(e) => setForm({ ...form, stock_code: e.target.value })}
                required
                placeholder="e.g., QQQ or QQQ.US"
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">BuyConditionType</label>
              <select
                value={form.buy_condition_type ?? "N/A"}
                onChange={(e) => setForm({ ...form, buy_condition_type: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {BUY_CONDITION_TYPES.map((opt) => (
                  <option key={opt} value={opt}>{opt}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Trigger Price</label>
              <input
                type="number"
                step="0.01"
                value={form.trigger_price}
                onChange={(e) => setForm({ ...form, trigger_price: e.target.value ? parseFloat(e.target.value) : 0 })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Volume</label>
              <input
                type="number"
                value={form.total_volume || ""}
                onChange={(e) => {
                  const raw = e.target.value;
                  const sanitized = raw.replace(/^0+(?=\d)/, "");
                  setForm({ ...form, total_volume: sanitized ? parseInt(sanitized, 10) : 0 });
                }}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Entry Price</label>
              <input
                type="number"
                step="0.01"
                value={form.entry_price}
                onChange={(e) => setForm({ ...form, entry_price: e.target.value ? parseFloat(e.target.value) : 0 })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Stop Loss Price</label>
              <input
                type="number"
                step="0.01"
                value={form.stop_loss_price}
                onChange={(e) => setForm({ ...form, stop_loss_price: e.target.value ? parseFloat(e.target.value) : 0 })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Exit Price</label>
              <input
                type="number"
                step="0.01"
                value={form.exit_price}
                onChange={(e) => setForm({ ...form, exit_price: e.target.value ? parseFloat(e.target.value) : 0 })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Bar Complete In Mins</label>
              <select
                value={form.bar_completed_in_min}
                onChange={(e) => setForm({ ...form, bar_completed_in_min: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {BAR_MIN_OPTIONS.map((o) => (
                  <option key={o} value={o}>{o}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Option Buy/Sell</label>
              <select
                value={form.option_buy_sell ?? "N/A"}
                onChange={(e) => setForm({ ...form, option_buy_sell: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {OPTION_BUY_SELL.map((o) => (
                  <option key={o} value={o}>{o}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Option Symbol</label>
              <input
                type="text"
                value={form.option_symbol ?? ""}
                onChange={(e) => setForm({ ...form, option_symbol: e.target.value })}
                placeholder="Optional"
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div className="sm:col-span-2 lg:col-span-3 flex gap-2">
              <button
                type="submit"
                disabled={submitting}
                className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {submitting && (
                  <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                )}
                {submitting ? (editingId ? "Updating..." : "Creating...") : (editingId ? "Update Order" : "Create Order")}
              </button>
              {editingId && (
                <button
                  type="button"
                  onClick={handleCancel}
                  disabled={submitting}
                  className="rounded-md bg-gray-500 px-4 py-2 text-sm font-medium text-white hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        {profitStats && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 text-amber-900 px-4 py-3 mb-6 text-sm">
            <div className="font-medium mb-1">Profitability (estimates)</div>
            <div className="flex flex-wrap gap-x-6 gap-y-1">
              <div>Trade value: {Math.round(profitStats.tradeValue).toLocaleString()}</div>
              <div>Potential loss: {Math.round(profitStats.potentialLoss).toLocaleString()}</div>
              <div>Potential profit: {Math.round(profitStats.potentialProfit).toLocaleString()}</div>
              <div>
                Profit/Loss ratio: {profitStats.ratio != null ? profitStats.ratio.toFixed(2) : "-"}
              </div>
              <div>
                Win % change: {profitStats.percChangeWin != null ? profitStats.percChangeWin.toFixed(2) : "-"}%
              </div>
              <div>
                Loss % change: {profitStats.percChangeLoss != null ? profitStats.percChangeLoss.toFixed(2) : "-"}%
              </div>
            </div>
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          <h2 className="text-xl font-semibold p-6 pb-0">Existing Strategy Orders</h2>

          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}

          {orders.length === 0 ? (
            <div className="p-6 text-center text-slate-500">No strategy orders found.</div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">OrderID</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order Type</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Stock Code</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Trigger</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Volume</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Entry</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Stop</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Exit</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Bar</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">BuyConditionType</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Option</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Created</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Actions</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((o, i) => (
                  <tr key={o.id || i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.id}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.order_type || o.order_type_id}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium">{o.stock_code}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.trigger_price}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.total_volume}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.entry_price}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.stop_loss_price}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.exit_price}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.bar_completed_in_min || "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.buy_condition_type ?? "N/A"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.option_symbol || "-"} {o.option_buy_sell ? `(${o.option_buy_sell})` : ""}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.created_date ? new Date(o.created_date).toLocaleString() : "-"}</td>
                    <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                      {o.id && (
                        <div className="flex gap-1">
                          <button
                            onClick={() => handleEdit(o)}
                            title="Edit order"
                            className="p-1.5 rounded hover:bg-blue-50 text-blue-600 hover:text-blue-700 transition-colors"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
                            </svg>
                          </button>
                          <button
                            onClick={() => o.id && handleDelete(o.id)}
                            title="Delete order"
                            className="p-1.5 rounded hover:bg-red-50 text-red-600 hover:text-red-700 transition-colors"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                            </svg>
                          </button>
                        </div>
                      )}
                    </td>
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


