"use client";

import { useEffect, useMemo, useState } from "react";

interface StrategyOption {
  strategy_id: number;
  strategy_code: string;
  is_active?: boolean;
}

interface SignalTypeOption {
  signal_type: string;
  description?: string;
}

interface BacktestRun {
  backtest_run_id: string;
  started_at?: string;
  ended_at?: string;
  strategy_code?: string;
  stock_code?: string;
  time_frame?: string;
  order_source_mode?: string;
}

interface TradingOrder {
  order_id?: number;
  strategy_id: number;
  strategy_code?: string;
  stock_code: string;
  side: "B" | "S";
  order_source_type: "MANUAL" | "SIGNAL";
  signal_type?: string | null;
  time_frame: string;
  entry_type: "LIMIT" | "MARKET";
  entry_price?: number | null;
  quantity: number;
  profit_target_price?: number | null;
  stop_loss_price?: number | null;
  stop_loss_mode?: string;
  status: "PENDING" | "PLACED" | "OPEN" | "CLOSED" | "CANCELLED";
  backtest_run_id?: string | null;
  entry_placed_at?: string;
  entry_filled_at?: string;
  exit_placed_at?: string;
  exit_filled_at?: string;
  stoploss_placed_at?: string;
  stoploss_filled_at?: string;
  created_at?: string;
  updated_at?: string;
}

interface TradingOrderForm {
  strategy_id: string;
  stock_code: string;
  side: "B" | "S";
  order_source_type: "MANUAL" | "SIGNAL";
  signal_type: string;
  time_frame: string;
  entry_type: "LIMIT" | "MARKET";
  entry_price: string;
  quantity: string;
  profit_target_price: string;
  stop_loss_price: string;
  stop_loss_mode: string;
  status: "PENDING" | "PLACED";
  backtest_run_id: string;
}

const ENTRY_TYPES = ["LIMIT", "MARKET"] as const;
const SIDES = ["B", "S"] as const;
const ORDER_SOURCE_TYPES = ["MANUAL", "SIGNAL"] as const;
const TIME_FRAMES = ["1M", "5M", "15M", "30M", "1H", "4H", "1D"] as const;
const STOP_LOSS_MODES = ["BAR_CLOSE"] as const;
const STATUS_FILTERS = ["ACTIVE", "PENDING", "PLACED", "OPEN", "CLOSED", "CANCELLED", "ALL"] as const;

function normalizeStockCode(symbol: string): string {
  const s = (symbol || "").trim().toUpperCase();
  if (!s) return s;
  if (s.includes(".")) return s;
  return `${s}.US`;
}

function toOptionalFloat(value: string): number | null {
  const v = value.trim();
  if (!v) return null;
  const parsed = Number(v);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatDate(value?: string) {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString();
}

export default function TradingOrdersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const [mode, setMode] = useState<"live" | "backtest">("live");
  const [statusFilter, setStatusFilter] = useState<(typeof STATUS_FILTERS)[number]>("ACTIVE");
  const [stockFilter, setStockFilter] = useState<string>("");
  const [backtestFilter, setBacktestFilter] = useState<string>("");

  const [strategies, setStrategies] = useState<StrategyOption[]>([]);
  const [signalTypes, setSignalTypes] = useState<SignalTypeOption[]>([]);
  const [backtestRuns, setBacktestRuns] = useState<BacktestRun[]>([]);

  const [orders, setOrders] = useState<TradingOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [editingId, setEditingId] = useState<number | null>(null);

  const [form, setForm] = useState<TradingOrderForm>({
    strategy_id: "",
    stock_code: "",
    side: "B",
    order_source_type: "MANUAL",
    signal_type: "",
    time_frame: "5M",
    entry_type: "LIMIT",
    entry_price: "",
    quantity: "",
    profit_target_price: "",
    stop_loss_price: "",
    stop_loss_mode: "BAR_CLOSE",
    status: "PENDING",
    backtest_run_id: "",
  });
  useEffect(() => {
    const loadLookups = async () => {
      try {
        const [strategyRes, signalRes, backtestRes] = await Promise.all([
          fetch(`${baseUrl}/api/trading-orders/strategies`),
          fetch(`${baseUrl}/api/trading-orders/signal-types`),
          fetch(`${baseUrl}/api/trading-orders/backtest-runs`),
        ]);

        if (strategyRes.ok) {
          const strategyData = await strategyRes.json();
          setStrategies(Array.isArray(strategyData) ? strategyData : []);
          if (!form.strategy_id && Array.isArray(strategyData) && strategyData.length > 0) {
            setForm((prev) => ({ ...prev, strategy_id: String(strategyData[0].strategy_id) }));
          }
        }

        if (signalRes.ok) {
          const signalData = await signalRes.json();
          setSignalTypes(Array.isArray(signalData) ? signalData : []);
        }

        if (backtestRes.ok) {
          const backtestData = await backtestRes.json();
          setBacktestRuns(Array.isArray(backtestData) ? backtestData : []);
          if (!form.backtest_run_id && Array.isArray(backtestData) && backtestData.length > 0) {
            setForm((prev) => ({ ...prev, backtest_run_id: String(backtestData[0].backtest_run_id || "") }));
          }
        }
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : "Failed to load lookups");
      }
    };

    loadLookups();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [baseUrl]);

  const loadOrders = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      params.set("mode", mode);
      if (statusFilter && statusFilter !== "ALL") {
        if (statusFilter === "ACTIVE") {
          params.set("status", "PENDING,PLACED,OPEN");
        } else {
          params.set("status", statusFilter);
        }
      }
      if (stockFilter.trim()) {
        params.set("stock_code", normalizeStockCode(stockFilter));
      }
      if (mode === "backtest" && backtestFilter) {
        params.set("backtest_run_id", backtestFilter);
      }
      params.set("_ts", String(Date.now()));
      const res = await fetch(`${baseUrl}/api/trading-orders?${params.toString()}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setOrders(Array.isArray(data) ? data : []);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load orders");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrders();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, statusFilter, backtestFilter, baseUrl]);

  useEffect(() => {
    if (mode === "live") {
      setForm((prev) => ({ ...prev, backtest_run_id: "" }));
    } else if (!form.backtest_run_id && backtestRuns.length > 0) {
      setForm((prev) => ({ ...prev, backtest_run_id: String(backtestRuns[0].backtest_run_id || "") }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, backtestRuns]);
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setMessage("");

    if (!form.strategy_id) {
      setError("Strategy is required.");
      return;
    }
    if (!form.stock_code.trim()) {
      setError("Stock code is required.");
      return;
    }
    if (form.order_source_type === "SIGNAL" && !form.signal_type.trim()) {
      setError("Signal type is required for SIGNAL orders.");
      return;
    }
    if (mode === "backtest" && !form.backtest_run_id) {
      setError("Backtest Run is required for backtest orders.");
      return;
    }
    const qty = Number(form.quantity);
    if (!Number.isFinite(qty) || qty <= 0) {
      setError("Quantity must be a positive number.");
      return;
    }

    const payload = {
      strategy_id: Number(form.strategy_id),
      stock_code: normalizeStockCode(form.stock_code),
      side: form.side,
      order_source_type: form.order_source_type,
      signal_type: form.order_source_type === "SIGNAL" ? form.signal_type.trim() : null,
      time_frame: form.time_frame,
      entry_type: form.entry_type,
      entry_price: form.entry_type === "MARKET" ? null : toOptionalFloat(form.entry_price),
      quantity: qty,
      profit_target_price: toOptionalFloat(form.profit_target_price),
      stop_loss_price: toOptionalFloat(form.stop_loss_price),
      stop_loss_mode: form.stop_loss_mode || "BAR_CLOSE",
      status: form.status,
      backtest_run_id: mode === "backtest" ? form.backtest_run_id : null,
    };

    try {
      setSubmitting(true);
      let res: Response;
      if (editingId) {
        res = await fetch(`${baseUrl}/api/trading-orders/${editingId}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else {
        res = await fetch(`${baseUrl}/api/trading-orders`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      setMessage(result.message || "Success");
      setEditingId(null);
      setForm((prev) => ({
        ...prev,
        stock_code: "",
        entry_price: "",
        quantity: "",
        profit_target_price: "",
        stop_loss_price: "",
        status: "PENDING",
      }));
      await loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to submit order");
    } finally {
      setSubmitting(false);
    }
  };

  const handleEdit = (order: TradingOrder) => {
    if (!order.order_id) return;
    setEditingId(order.order_id);
    setMode(order.backtest_run_id ? "backtest" : "live");
    setForm({
      strategy_id: String(order.strategy_id ?? ""),
      stock_code: order.stock_code || "",
      side: order.side,
      order_source_type: order.order_source_type,
      signal_type: order.signal_type || "",
      time_frame: order.time_frame || "5M",
      entry_type: order.entry_type || "LIMIT",
      entry_price: order.entry_price != null ? String(order.entry_price) : "",
      quantity: order.quantity != null ? String(order.quantity) : "",
      profit_target_price: order.profit_target_price != null ? String(order.profit_target_price) : "",
      stop_loss_price: order.stop_loss_price != null ? String(order.stop_loss_price) : "",
      stop_loss_mode: order.stop_loss_mode || "BAR_CLOSE",
      status: (order.status === "PLACED" ? "PLACED" : "PENDING"),
      backtest_run_id: order.backtest_run_id || "",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setForm((prev) => ({
      ...prev,
      stock_code: "",
      entry_price: "",
      quantity: "",
      profit_target_price: "",
      stop_loss_price: "",
      status: "PENDING",
    }));
  };

  const handleCancelOrder = async (orderId: number) => {
    if (!confirm("Cancel this order?")) return;
    try {
      const res = await fetch(`${baseUrl}/api/trading-orders/${orderId}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      setMessage(result.message || "Cancelled");
      await loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to cancel order");
    }
  };

  const profitStats = useMemo(() => {
    const qty = Number(form.quantity || 0);
    const entry = Number(form.entry_price || 0);
    const stop = Number(form.stop_loss_price || 0);
    const target = Number(form.profit_target_price || 0);
    if (!qty || !entry || !stop || !target) return null;
    const potentialLoss = Math.abs(entry - stop) * qty;
    const potentialProfit = Math.abs(target - entry) * qty;
    const ratio = potentialLoss > 0 ? potentialProfit / potentialLoss : null;
    return { potentialLoss, potentialProfit, ratio };
  }, [form.quantity, form.entry_price, form.stop_loss_price, form.profit_target_price]);
  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
          <h1 className="text-3xl sm:text-4xl font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
            Pegasus Trading Orders
          </h1>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setMode("live")}
              className={`rounded-full px-4 py-1.5 text-sm font-medium border transition-colors ${
                mode === "live"
                  ? "bg-blue-600 text-white border-blue-600"
                  : "bg-white text-slate-700 border-slate-200 hover:bg-slate-50"
              }`}
            >
              Live
            </button>
            <button
              onClick={() => setMode("backtest")}
              className={`rounded-full px-4 py-1.5 text-sm font-medium border transition-colors ${
                mode === "backtest"
                  ? "bg-indigo-600 text-white border-indigo-600"
                  : "bg-white text-slate-700 border-slate-200 hover:bg-slate-50"
              }`}
            >
              Backtest
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}
        {message && (
          <div className="mb-4 rounded-md border border-green-200 bg-green-50 text-green-700 px-3 py-2 text-sm">
            {message}
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white p-5 mb-6">
          <div className="flex flex-wrap gap-3 items-end">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Status Filter</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as any)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {STATUS_FILTERS.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Stock Filter</label>
              <input
                type="text"
                value={stockFilter}
                onChange={(e) => setStockFilter(e.target.value)}
                placeholder="e.g. QQQ"
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>
            {mode === "backtest" && (
              <div className="min-w-[260px]">
                <label className="block text-sm mb-1 text-slate-600">Backtest Run Filter</label>
                <select
                  value={backtestFilter}
                  onChange={(e) => setBacktestFilter(e.target.value)}
                  className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                >
                  <option value="">All Runs</option>
                  {backtestRuns.map((r) => (
                    <option key={r.backtest_run_id} value={String(r.backtest_run_id)}>
                      {r.strategy_code || "Strategy"} - {r.stock_code || "Stock"} - {r.time_frame || "TF"} - {String(r.backtest_run_id).slice(0, 8)}
                    </option>
                  ))}
                </select>
              </div>
            )}
            <div className="flex gap-2">
              <button
                onClick={loadOrders}
                className="rounded-md bg-slate-700 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
              >
                Refresh
              </button>
            </div>
          </div>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <h2 className="text-xl font-semibold mb-4">
            {editingId ? "Edit Trading Order" : "Create Trading Order"}
          </h2>
          <form onSubmit={handleSubmit} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Strategy</label>
              <select
                value={form.strategy_id}
                onChange={(e) => setForm({ ...form, strategy_id: e.target.value })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {strategies.map((s) => (
                  <option key={s.strategy_id} value={s.strategy_id}>
                    {s.strategy_code}
                  </option>
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
              <label className="block text-sm mb-1 text-slate-600">Side</label>
              <select
                value={form.side}
                onChange={(e) => setForm({ ...form, side: e.target.value as "B" | "S" })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {SIDES.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Source</label>
              <select
                value={form.order_source_type}
                onChange={(e) => setForm({ ...form, order_source_type: e.target.value as any })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {ORDER_SOURCE_TYPES.map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Signal Type</label>
              <select
                value={form.signal_type}
                onChange={(e) => setForm({ ...form, signal_type: e.target.value })}
                disabled={form.order_source_type === "MANUAL"}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  form.order_source_type === "MANUAL"
                    ? "border-slate-200 bg-slate-100 text-slate-500"
                    : "border-slate-300 bg-white focus:ring-blue-400/40 focus:border-blue-400/40"
                }`}
              >
                <option value="">Select signal</option>
                {signalTypes.map((s) => (
                  <option key={s.signal_type} value={s.signal_type}>
                    {s.signal_type}{s.description ? ` - ${s.description}` : ""}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Time Frame</label>
              <select
                value={form.time_frame}
                onChange={(e) => setForm({ ...form, time_frame: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {TIME_FRAMES.map((tf) => (
                  <option key={tf} value={tf}>{tf}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Entry Type</label>
              <select
                value={form.entry_type}
                onChange={(e) => setForm({ ...form, entry_type: e.target.value as any })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {ENTRY_TYPES.map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Entry Price</label>
              <input
                type="number"
                step="0.01"
                value={form.entry_price}
                onChange={(e) => setForm({ ...form, entry_price: e.target.value })}
                disabled={form.entry_type === "MARKET"}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  form.entry_type === "MARKET"
                    ? "border-slate-200 bg-slate-100 text-slate-500"
                    : "border-slate-300 bg-white focus:ring-blue-400/40 focus:border-blue-400/40"
                }`}
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Quantity</label>
              <input
                type="number"
                value={form.quantity}
                onChange={(e) => setForm({ ...form, quantity: e.target.value })}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Profit Target</label>
              <input
                type="number"
                step="0.01"
                value={form.profit_target_price}
                onChange={(e) => setForm({ ...form, profit_target_price: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Stop Loss</label>
              <input
                type="number"
                step="0.01"
                value={form.stop_loss_price}
                onChange={(e) => setForm({ ...form, stop_loss_price: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Stop Loss Mode</label>
              <select
                value={form.stop_loss_mode}
                onChange={(e) => setForm({ ...form, stop_loss_mode: e.target.value })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                {STOP_LOSS_MODES.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Status</label>
              <select
                value={form.status}
                onChange={(e) => setForm({ ...form, status: e.target.value as any })}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                <option value="PENDING">PENDING</option>
                <option value="PLACED">PLACED</option>
              </select>
            </div>

            {mode === "backtest" && (
              <div className="sm:col-span-2 lg:col-span-3">
                <label className="block text-sm mb-1 text-slate-600">Backtest Run</label>
                <select
                  value={form.backtest_run_id}
                  onChange={(e) => setForm({ ...form, backtest_run_id: e.target.value })}
                  className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                >
                  <option value="">Select backtest run</option>
                  {backtestRuns.map((r) => (
                    <option key={r.backtest_run_id} value={String(r.backtest_run_id)}>
                      {r.strategy_code || "Strategy"} - {r.stock_code || "Stock"} - {r.time_frame || "TF"} - {String(r.backtest_run_id).slice(0, 8)}
                    </option>
                  ))}
                </select>
              </div>
            )}

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
                  onClick={handleCancelEdit}
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
            <div className="font-medium mb-1">Risk/Reward (estimate)</div>
            <div className="flex flex-wrap gap-x-6 gap-y-1">
              <div>Potential loss: {Math.round(profitStats.potentialLoss).toLocaleString()}</div>
              <div>Potential profit: {Math.round(profitStats.potentialProfit).toLocaleString()}</div>
              <div>Profit/Loss ratio: {profitStats.ratio != null ? profitStats.ratio.toFixed(2) : "-"}</div>
            </div>
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          <h2 className="text-xl font-semibold p-6 pb-0">Orders</h2>

          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}

          {orders.length === 0 ? (
            <div className="p-6 text-center text-slate-500">No orders found.</div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order ID</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Strategy</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Stock</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Side</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Source</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Signal</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Entry</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Qty</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Target</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Stop</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Status</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Mode</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Created</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Actions</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((o, i) => {
                  const canEdit = o.status === "PENDING" || o.status === "PLACED";
                  return (
                    <tr key={o.order_id || i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.order_id}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.strategy_code || o.strategy_id}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium">{o.stock_code}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.side}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.order_source_type}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.signal_type || "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {o.entry_type} {o.entry_price != null ? `@ ${o.entry_price}` : ""}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.quantity}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.profit_target_price ?? "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.stop_loss_price ?? "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.status}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.backtest_run_id ? "Backtest" : "Live"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{formatDate(o.created_at)}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {o.order_id && (
                          <div className="flex gap-1">
                            <button
                              onClick={() => canEdit && handleEdit(o)}
                              title={canEdit ? "Edit order" : "Only PENDING/PLACED orders can be edited"}
                              className={`p-1.5 rounded transition-colors ${
                                canEdit ? "hover:bg-blue-50 text-blue-600 hover:text-blue-700" : "text-slate-400 cursor-not-allowed"
                              }`}
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
                              </svg>
                            </button>
                            <button
                              onClick={() => canEdit && handleCancelOrder(o.order_id!)}
                              title={canEdit ? "Cancel order" : "Only PENDING/PLACED orders can be cancelled"}
                              className={`p-1.5 rounded transition-colors ${
                                canEdit ? "hover:bg-red-50 text-red-600 hover:text-red-700" : "text-slate-400 cursor-not-allowed"
                              }`}
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                              </svg>
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
