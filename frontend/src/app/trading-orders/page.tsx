"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

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

interface OrderSignalAudit {
  order_signal_audit_id?: number;
  order_id?: number;
  strategy_id?: number;
  stock_code?: string;
  side?: "B" | "S";
  time_frame?: string;
  intended_action?: string;
  signal_type?: string;
  signal_key?: string;
  triggered_at?: string;
  validation_status?: string;
  validation_result?: number | boolean | null;
  validation_decision?: string;
  validation_job_id?: string;
  request_payload_json?: string | Record<string, unknown> | null;
  response_payload_json?: string | Record<string, unknown> | null;
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
  entry_type: "LIMIT" | "LIMIT_MID" | "MARKET";
  entry_price?: number | null;
  quantity: number;
  profit_target_price?: number | null;
  stop_loss_price?: number | null;
  stop_loss_mode?: string;
  status: "PENDING" | "PLACED" | "OPEN" | "CLOSED" | "CANCELLED";
  backtest_run_id?: string | null;
  entry_placed_at?: string;
  entry_filled_at?: string;
  entry_fill_price?: number | null;
  entry_fill_qty?: number | null;
  exit_placed_at?: string;
  exit_filled_at?: string;
  exit_fill_price?: number | null;
  exit_fill_qty?: number | null;
  stoploss_placed_at?: string;
  stoploss_filled_at?: string;
  stoploss_fill_price?: number | null;
  stoploss_fill_qty?: number | null;
  created_at?: string;
  updated_at?: string;
  signal_audits?: OrderSignalAudit[];
}

interface TradingOrderForm {
  strategy_id: string;
  stock_code: string;
  side: "B" | "S";
  order_source_type: "MANUAL" | "SIGNAL";
  signal_type: string;
  time_frame: string;
  entry_type: "LIMIT" | "LIMIT_MID" | "MARKET";
  entry_price: string;
  quantity: string;
  profit_target_price: string;
  stop_loss_price: string;
  stop_loss_mode: string;
  status: "PENDING" | "PLACED";
  backtest_run_id: string;
}

interface OrderTimelineStage {
  key: string;
  label: string;
  description: string;
  timestamp?: string;
  sourceTimeZone?: string;
  price?: number | null;
  priceLabel?: string;
  quantity?: number | null;
  state: "done" | "current" | "waiting";
}

const ENTRY_TYPES = ["LIMIT", "LIMIT_MID", "MARKET"] as const;
const DEFAULT_ENTRY_TYPE = "LIMIT";
const SIDES = ["B", "S"] as const;
const ORDER_SOURCE_TYPES = ["MANUAL", "SIGNAL"] as const;
const TIME_FRAMES = ["1M", "5M", "15M", "30M", "1H", "4H", "1D"] as const;
const STOP_LOSS_MODES = ["BAR_CLOSE"] as const;
const STATUS_FILTERS = ["ACTIVE", "PENDING", "PLACED", "OPEN", "CLOSED", "CANCELLED", "ALL"] as const;
const SYDNEY_TIME_ZONE = "Australia/Sydney";
const US_EASTERN_TIME_ZONE = "America/New_York";

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

function hasTimezoneOffset(value: string): boolean {
  return /(?:Z|[+-]\d{2}:?\d{2})$/i.test(value.trim());
}

function parseDateTimeParts(value: string) {
  const match = value
    .trim()
    .match(/^(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?/);
  if (!match) return null;

  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
    hour: Number(match[4]),
    minute: Number(match[5]),
    second: Number(match[6] || 0),
  };
}

function getTimeZoneOffsetMs(date: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  const zonedTimeAsUtc = Date.UTC(
    Number(values.year),
    Number(values.month) - 1,
    Number(values.day),
    Number(values.hour),
    Number(values.minute),
    Number(values.second),
  );
  return zonedTimeAsUtc - date.getTime();
}

function zonedDateTimeToDate(value: string, sourceTimeZone: string): Date | null {
  const parts = parseDateTimeParts(value);
  if (!parts) return null;

  const utcGuess = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  const firstOffset = getTimeZoneOffsetMs(new Date(utcGuess), sourceTimeZone);
  const firstDate = new Date(utcGuess - firstOffset);
  const secondOffset = getTimeZoneOffsetMs(firstDate, sourceTimeZone);

  return new Date(utcGuess - secondOffset);
}

function formatSydneyDate(value?: string, sourceTimeZone = SYDNEY_TIME_ZONE) {
  if (!value) return "-";
  const d = hasTimezoneOffset(value)
    ? new Date(value)
    : zonedDateTimeToDate(value, sourceTimeZone) || new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("en-AU", {
    timeZone: SYDNEY_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    timeZoneName: "short",
  });
}

function formatPrice(value?: number | null): string {
  if (value == null) return "-";
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return String(value);
  return numeric.toLocaleString("en-AU", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  });
}

function toDateTimeLocalValue(date = new Date()): string {
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function formatEntryType(entryType: string): string {
  return entryType === "LIMIT_MID" ? "LIMIT @ MID" : entryType;
}

function formatPayloadJson(value?: string | Record<string, unknown> | null): string {
  if (value == null || value === "") return "-";
  if (typeof value !== "string") return JSON.stringify(value, null, 2);

  try {
    return JSON.stringify(JSON.parse(value), null, 2);
  } catch {
    return value;
  }
}

function getApiValidationCounts(audits?: OrderSignalAudit[]) {
  const safeAudits = audits || [];
  return safeAudits.reduce(
    (counts, audit) => {
      const action = (audit.intended_action || "").toLowerCase();
      if (action.includes("entry")) counts.entry += 1;
      if (action.includes("exit")) counts.exit += 1;
      counts.total += 1;
      return counts;
    },
    { total: 0, entry: 0, exit: 0 },
  );
}

function canCancelTradingOrder(order?: Pick<TradingOrder, "status"> | null): boolean {
  return order?.status === "PENDING" || order?.status === "PLACED";
}

function hasApprovedValidation(audits?: OrderSignalAudit[]): boolean {
  return (audits || []).some(
    (audit) => String(audit.validation_decision || "").trim().toUpperCase() === "APPROVED",
  );
}

function buildOrderTimeline(order: TradingOrder): OrderTimelineStage[] {
  const status = (order.status || "").toUpperCase();
  const exitPlacedTimestamp = order.exit_placed_at || order.exit_filled_at;
  const exitPlacedSourceTimeZone = order.exit_placed_at ? US_EASTERN_TIME_ZONE : SYDNEY_TIME_ZONE;
  const stageState = (
    timestamp: string | undefined,
    currentWhen: boolean,
  ): OrderTimelineStage["state"] => {
    if (timestamp) return "done";
    return currentWhen ? "current" : "waiting";
  };

  const stages: OrderTimelineStage[] = [
    {
      key: "created",
      label: "Order pending",
      description: "Website order created and waiting for the engine.",
      timestamp: order.created_at,
      sourceTimeZone: SYDNEY_TIME_ZONE,
      state: stageState(order.created_at, status === "PENDING"),
    },
    {
      key: "entry_placed",
      label: "Entry order placed",
      description: "Entry order submitted to the broker or backtest engine.",
      timestamp: order.entry_placed_at,
      sourceTimeZone: US_EASTERN_TIME_ZONE,
      price: order.entry_price,
      priceLabel: "Placed price",
      state: stageState(order.entry_placed_at, status === "PLACED"),
    },
    {
      key: "entry_filled",
      label: "Entry order filled",
      description: "Position opened after the entry order was filled.",
      timestamp: order.entry_filled_at,
      sourceTimeZone: SYDNEY_TIME_ZONE,
      price: order.entry_fill_price,
      priceLabel: "Execution price",
      quantity: order.entry_fill_qty,
      state: stageState(order.entry_filled_at, status === "OPEN"),
    },
    {
      key: "exit_placed",
      label: "Exit order placed",
      description: "Profit target or normal exit order submitted.",
      timestamp: exitPlacedTimestamp,
      sourceTimeZone: exitPlacedSourceTimeZone,
      state: stageState(exitPlacedTimestamp, false),
    },
    {
      key: "exit_filled",
      label: "Exit order filled",
      description: "Position closed by the exit order.",
      timestamp: order.exit_filled_at,
      sourceTimeZone: SYDNEY_TIME_ZONE,
      price: order.exit_fill_price,
      priceLabel: "Execution price",
      quantity: order.exit_fill_qty,
      state: stageState(order.exit_filled_at, status === "CLOSED" && !order.stoploss_filled_at),
    },
  ];

  if (order.stop_loss_price != null || order.stoploss_placed_at || order.stoploss_filled_at) {
    stages.push(
      {
        key: "stoploss_placed",
        label: "Stop loss placed",
        description: "Protective stop-loss order submitted.",
        timestamp: order.stoploss_placed_at,
        sourceTimeZone: US_EASTERN_TIME_ZONE,
        state: stageState(order.stoploss_placed_at, false),
      },
      {
        key: "stoploss_filled",
        label: "Stop loss filled",
        description: "Position closed by the stop-loss order.",
        timestamp: order.stoploss_filled_at,
        sourceTimeZone: SYDNEY_TIME_ZONE,
        price: order.stoploss_fill_price,
        priceLabel: "Execution price",
        quantity: order.stoploss_fill_qty,
        state: stageState(order.stoploss_filled_at, status === "CLOSED" && !order.exit_filled_at),
      },
    );
  }

  if (status === "CANCELLED") {
    stages.push({
      key: "cancelled",
      label: "Order cancelled",
      description: "Order cancelled before the remaining lifecycle completed.",
      timestamp: order.updated_at,
      sourceTimeZone: SYDNEY_TIME_ZONE,
      state: "done",
    });
  }

  return stages;
}

export default function TradingOrdersPage() {
  const baseUrl = (process.env.NEXT_PUBLIC_BACKEND_URL || "");

  const [mode, setMode] = useState<"live" | "backtest">("live");
  const [statusFilter, setStatusFilter] = useState<(typeof STATUS_FILTERS)[number]>("ACTIVE");
  const [stockFilter, setStockFilter] = useState<string>("");
  const [backtestFilter, setBacktestFilter] = useState<string>("");
  const [approvedOnly, setApprovedOnly] = useState(false);

  const [strategies, setStrategies] = useState<StrategyOption[]>([]);
  const [signalTypes, setSignalTypes] = useState<SignalTypeOption[]>([]);
  const [backtestRuns, setBacktestRuns] = useState<BacktestRun[]>([]);

  const [orders, setOrders] = useState<TradingOrder[]>([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [editingId, setEditingId] = useState<number | null>(null);
  const [selectedOrder, setSelectedOrder] = useState<TradingOrder | null>(null);
  const [exitFillPrice, setExitFillPrice] = useState("");
  const [exitFillTime, setExitFillTime] = useState("");
  const [savingExitFill, setSavingExitFill] = useState(false);

  const [form, setForm] = useState<TradingOrderForm>({
    strategy_id: "",
    stock_code: "",
    side: "B",
    order_source_type: "MANUAL",
    signal_type: "NEWTON",
    time_frame: "5M",
    entry_type: DEFAULT_ENTRY_TYPE,
    entry_price: "",
    quantity: "",
    profit_target_price: "",
    stop_loss_price: "",
    stop_loss_mode: "BAR_CLOSE",
    status: "PENDING",
    backtest_run_id: "",
  });

  const [validationErrors, setValidationErrors] = useState<{
    profit_target?: string;
    stop_loss?: string;
  }>({});

  const selectedStrategyCode = useMemo(() => {
    const match = strategies.find((s) => String(s.strategy_id) === String(form.strategy_id));
    return match?.strategy_code || "";
  }, [strategies, form.strategy_id]);
  const isTripleBeacon = selectedStrategyCode.trim().toUpperCase() === "TRIPLE_BEACON";
  const isNewton = selectedStrategyCode.trim().toUpperCase() === "NEWTON";
  useEffect(() => {
    const loadLookups = async () => {
      try {
        const [strategyRes, signalRes, backtestRes] = await Promise.all([
          authenticatedFetch(`${baseUrl}/api/trading-orders/strategies`),
          authenticatedFetch(`${baseUrl}/api/trading-orders/signal-types`),
          authenticatedFetch(`${baseUrl}/api/trading-orders/backtest-runs`),
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
      const res = await authenticatedFetch(`${baseUrl}/api/trading-orders?${params.toString()}`);
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

  useEffect(() => {
    if (!isTripleBeacon) return;
    setForm((prev) => ({
      ...prev,
      entry_type: DEFAULT_ENTRY_TYPE,
      entry_price: "",
      profit_target_price: "",
      stop_loss_price: "",
    }));
  }, [isTripleBeacon]);

  useEffect(() => {
    if (!isNewton) return;
    setForm((prev) => ({
      ...prev,
      order_source_type: "SIGNAL",
      signal_type: "NEWTON",
      time_frame: "5M",
      entry_type: DEFAULT_ENTRY_TYPE,
      entry_price: "",
      stop_loss_mode: "BAR_CLOSE",
    }));
  }, [isNewton]);

  useEffect(() => {
    if (!selectedOrder || selectedOrder.status !== "OPEN" || selectedOrder.exit_filled_at) {
      setExitFillPrice("");
      setExitFillTime("");
      return;
    }
    setExitFillPrice("");
    setExitFillTime(toDateTimeLocalValue());
  }, [selectedOrder?.order_id]);

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

    // Check for validation errors
    if (validationErrors.profit_target || validationErrors.stop_loss) {
      setError(validationErrors.profit_target || validationErrors.stop_loss || "Please fix validation errors.");
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
      entry_price: form.entry_type === "MARKET" || form.entry_type === "LIMIT_MID" ? null : toOptionalFloat(form.entry_price),
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
        res = await authenticatedFetch(`${baseUrl}/api/trading-orders/${editingId}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
      } else {
        res = await authenticatedFetch(`${baseUrl}/api/trading-orders`, {
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
        entry_type: DEFAULT_ENTRY_TYPE,
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
      entry_type: order.entry_type || DEFAULT_ENTRY_TYPE,
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
      entry_type: DEFAULT_ENTRY_TYPE,
      entry_price: "",
      quantity: "",
      profit_target_price: "",
      stop_loss_price: "",
      status: "PENDING",
    }));
  };

  const handleCancelOrder = async (orderId: number): Promise<boolean> => {
    if (!confirm("Cancel this order?")) return false;
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/trading-orders/${orderId}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const result = await res.json();
      setMessage(result.message || "Cancelled");
      await loadOrders();
      return true;
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to cancel order");
      return false;
    }
  };

  const handleRecordExitFill = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setMessage("");

    const orderId = selectedOrder?.order_id;
    const fillPrice = Number(exitFillPrice);
    if (!orderId || selectedOrder?.status !== "OPEN") {
      setError("Only an OPEN order can have a manual exit fill recorded.");
      return;
    }
    if (!Number.isFinite(fillPrice) || fillPrice <= 0) {
      setError("Exit fill price must be greater than zero.");
      return;
    }
    if (!exitFillTime) {
      setError("Exit fill time is required.");
      return;
    }

    try {
      setSavingExitFill(true);
      const res = await authenticatedFetch(`${baseUrl}/api/trading-orders/${orderId}/exit-fill`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ fill_price: fillPrice, fill_time: exitFillTime }),
      });
      const result = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(result.detail || `HTTP ${res.status}`);
      }

      setSelectedOrder((previous) => {
        if (!previous || previous.order_id !== orderId) return previous;
        return {
          ...previous,
          status: "CLOSED",
          exit_filled_at: result.exit_filled_at || exitFillTime,
          exit_fill_price: result.exit_fill_price ?? fillPrice,
          exit_fill_qty: result.exit_fill_qty ?? previous.quantity,
          updated_at: new Date().toISOString(),
        };
      });
      setMessage(result.message || "Manual exit fill recorded successfully.");
      await loadOrders();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to record exit fill");
    } finally {
      setSavingExitFill(false);
    }
  };

  // Real-time validation effect
  useEffect(() => {
    if (form.entry_type === "MARKET" || form.entry_type === "LIMIT_MID") {
      setValidationErrors({});
      return;
    }

    const entryNum = toOptionalFloat(form.entry_price);
    const targetNum = toOptionalFloat(form.profit_target_price);
    const stopNum = toOptionalFloat(form.stop_loss_price);
    const errors: { profit_target?: string; stop_loss?: string } = {};

    if (entryNum != null && form.side === "B") {
      // Long order validation
      if (targetNum != null && targetNum <= entryNum) {
        errors.profit_target = "Profit Target must be above Entry Price for Long orders";
      }
      if (stopNum != null && stopNum >= entryNum) {
        errors.stop_loss = "Stop Loss must be below Entry Price for Long orders";
      }
    }

    if (entryNum != null && form.side === "S") {
      // Short order validation
      if (targetNum != null && targetNum >= entryNum) {
        errors.profit_target = "Profit Target must be below Entry Price for Short orders";
      }
      if (stopNum != null && stopNum <= entryNum) {
        errors.stop_loss = "Stop Loss must be above Entry Price for Short orders";
      }
    }

    setValidationErrors(errors);
  }, [form.entry_price, form.profit_target_price, form.stop_loss_price, form.side, form.entry_type]);

  const profitStats = useMemo(() => {
    const qty = Number(form.quantity || 0);
    const entry = Number(form.entry_price || 0);
    const stop = Number(form.stop_loss_price || 0);
    const target = Number(form.profit_target_price || 0);
    if (!entry) return null;

    let potentialLoss = null;
    let potentialProfit = null;
    let lossPercent = null;
    let profitPercent = null;
    let ratio = null;

    if (stop > 0) {
      potentialLoss = Math.abs(entry - stop) * (qty || 1);
      lossPercent = ((Math.abs(entry - stop) / entry) * 100);
    }

    if (target > 0) {
      potentialProfit = Math.abs(target - entry) * (qty || 1);
      profitPercent = ((Math.abs(target - entry) / entry) * 100);
    }

    if (potentialLoss && potentialProfit && potentialLoss > 0) {
      ratio = potentialProfit / potentialLoss;
    }

    return { potentialLoss, potentialProfit, lossPercent, profitPercent, ratio };
  }, [form.quantity, form.entry_price, form.stop_loss_price, form.profit_target_price]);

  const selectedOrderTimeline = selectedOrder ? buildOrderTimeline(selectedOrder) : [];
  const selectedSignalAudits = selectedOrder?.signal_audits || [];
  const visibleSignalAudits = approvedOnly
    ? selectedSignalAudits.filter((audit) => hasApprovedValidation([audit]))
    : selectedSignalAudits;

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
                <option value="B">B – Long (Buy)</option>
                <option value="S">S – Short (Sell)</option>
              </select>
              {form.side === "S" && (
                <p className="mt-1 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
                  Short orders require <code className="font-mono">ENABLE_SHORTING=true</code> in the engine config. Broker approval for short selling may also be required.
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Order Source</label>
              <select
                value={form.order_source_type}
                onChange={(e) => setForm({ ...form, order_source_type: e.target.value as any })}
                disabled={isNewton}
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
                {form.signal_type === "SMA_CROSS" && !signalTypes.some((s) => s.signal_type === "SMA_CROSS") && (
                  <option value="SMA_CROSS">SMA_CROSS - Simple moving average cross</option>
                )}
                {form.signal_type === "NEWTON" && !signalTypes.some((s) => s.signal_type === "NEWTON") && (
                  <option value="NEWTON">NEWTON - Newton combined validation signal</option>
                )}
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
                disabled={isNewton}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  isNewton
                    ? "border-slate-200 bg-slate-100 text-slate-500"
                    : "border-slate-300 bg-white focus:ring-blue-400/40 focus:border-blue-400/40"
                }`}
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
                  <option key={t} value={t}>{formatEntryType(t)}</option>
                ))}
              </select>
              {isNewton && (
                <p className="mt-0.5 text-xs text-slate-500">NEWTON defaults to a limit entry.</p>
              )}
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Entry Price</label>
              <input
                type="number"
                step="0.01"
                value={form.entry_price}
                onChange={(e) => setForm({ ...form, entry_price: e.target.value })}
                disabled={form.entry_type === "MARKET" || form.entry_type === "LIMIT_MID"}
                placeholder={form.entry_type === "LIMIT_MID" ? "MID" : undefined}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  form.entry_type === "MARKET" || form.entry_type === "LIMIT_MID"
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
              <label className="block text-sm mb-1 text-slate-600">
                Profit Target
                {profitStats?.profitPercent != null && !validationErrors.profit_target && (
                  <span className="ml-2 text-green-600 font-medium">
                    (+{profitStats.profitPercent.toFixed(2)}%)
                  </span>
                )}
              </label>
              <input
                type="number"
                step="0.01"
                value={form.profit_target_price}
                onChange={(e) => setForm({ ...form, profit_target_price: e.target.value })}
                disabled={isTripleBeacon}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  isTripleBeacon
                    ? "border-slate-200 bg-slate-100 text-slate-500"
                    : validationErrors.profit_target
                    ? "border-red-400 bg-red-50/30 focus:ring-red-400/40 focus:border-red-400"
                    : "border-slate-300 bg-white focus:ring-blue-400/40 focus:border-blue-400/40"
                }`}
              />
              {!isTripleBeacon && validationErrors.profit_target && (
                <p className="mt-1 text-xs text-red-600">
                  {validationErrors.profit_target}
                </p>
              )}
              {!isTripleBeacon && !validationErrors.profit_target && (
                <p className="mt-0.5 text-xs text-slate-500">
                  {form.side === "S" ? "Short: target must be below entry price" : "Long: target must be above entry price"}
                </p>
              )}
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">
                Stop Loss
                {profitStats?.lossPercent != null && !validationErrors.stop_loss && (
                  <span className="ml-2 text-red-600 font-medium">
                    (-{profitStats.lossPercent.toFixed(2)}%)
                  </span>
                )}
              </label>
              <input
                type="number"
                step="0.01"
                value={form.stop_loss_price}
                onChange={(e) => setForm({ ...form, stop_loss_price: e.target.value })}
                disabled={isTripleBeacon}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 ${
                  isTripleBeacon
                    ? "border-slate-200 bg-slate-100 text-slate-500"
                    : validationErrors.stop_loss
                    ? "border-red-400 bg-red-50/30 focus:ring-red-400/40 focus:border-red-400"
                    : "border-slate-300 bg-white focus:ring-blue-400/40 focus:border-blue-400/40"
                }`}
              />
              {!isTripleBeacon && validationErrors.stop_loss && (
                <p className="mt-1 text-xs text-red-600">
                  {validationErrors.stop_loss}
                </p>
              )}
              {!isTripleBeacon && !validationErrors.stop_loss && (
                <p className="mt-0.5 text-xs text-slate-500">
                  {form.side === "S" ? "Short: stop must be above entry price (bar-close trigger)" : "Long: stop must be below entry price (bar-close trigger)"}
                </p>
              )}
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
        {profitStats && (profitStats.potentialLoss != null || profitStats.potentialProfit != null) && (
          <div className="rounded-lg border border-amber-200 bg-amber-50 text-amber-900 px-4 py-3 mb-6 text-sm">
            <div className="font-medium mb-1">
              Risk/Reward (estimate) &mdash;{" "}
              <span className={form.side === "S" ? "text-red-700" : "text-green-700"}>
                {form.side === "S" ? "Short" : "Long"}
              </span>
            </div>
            <div className="flex flex-wrap gap-x-6 gap-y-1">
              {profitStats.potentialLoss != null && (
                <>
                  <div>Potential loss: ${Math.round(profitStats.potentialLoss).toLocaleString()}</div>
                  <div>Loss %: <span className="text-red-700 font-medium">{profitStats.lossPercent?.toFixed(2)}%</span></div>
                </>
              )}
              {profitStats.potentialProfit != null && (
                <>
                  <div>Potential profit: ${Math.round(profitStats.potentialProfit).toLocaleString()}</div>
                  <div>Profit %: <span className="text-green-700 font-medium">{profitStats.profitPercent?.toFixed(2)}%</span></div>
                </>
              )}
              {profitStats.ratio != null && (
                <div>Profit/Loss ratio: <span className="font-medium">{profitStats.ratio.toFixed(2)}</span></div>
              )}
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
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">API Validations</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Entry</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Entry Fill</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Exit / Stop Fill</th>
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
                  const canEdit = canCancelTradingOrder(o);
                  const validationCounts = getApiValidationCounts(o.signal_audits);
                  return (
                    <tr
                      key={o.order_id || i}
                      onClick={() => setSelectedOrder(o)}
                      className={`cursor-pointer transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}
                      title="View order history"
                    >
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.order_id}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.strategy_code || o.strategy_id}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium">{o.stock_code}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        <span className={`inline-block px-1.5 py-0.5 rounded text-xs font-semibold ${
                          o.side === "S"
                            ? "bg-red-100 text-red-700"
                            : "bg-green-100 text-green-700"
                        }`}>
                          {o.side === "S" ? "S Short" : "B Long"}
                        </span>
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.order_source_type}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.signal_type || "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        <div className="flex items-center gap-2">
                          <span className={`rounded px-2 py-0.5 text-xs font-semibold ${
                            validationCounts.total > 0
                              ? "bg-blue-100 text-blue-700"
                              : "bg-slate-100 text-slate-500"
                          }`}>
                            {validationCounts.total}
                          </span>
                          <span className="text-xs text-slate-500">
                            E {validationCounts.entry} / X {validationCounts.exit}
                          </span>
                        </div>
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {formatEntryType(o.entry_type)} {o.entry_price != null ? `@ ${o.entry_price}` : ""}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {o.entry_fill_price != null ? formatPrice(o.entry_fill_price) : "-"}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {o.stoploss_fill_price != null
                          ? `Stop ${formatPrice(o.stoploss_fill_price)}`
                          : o.exit_fill_price != null
                          ? `Exit ${formatPrice(o.exit_fill_price)}`
                          : "-"}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.quantity}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.profit_target_price ?? "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.stop_loss_price ?? "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.status}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.backtest_run_id ? "Backtest" : "Live"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{formatSydneyDate(o.created_at)}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {o.order_id && (
                          <div className="flex gap-1">
                            <button
                              onClick={(event) => {
                                event.stopPropagation();
                                if (canEdit) handleEdit(o);
                              }}
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
                              onClick={(event) => {
                                event.stopPropagation();
                                if (canEdit) handleCancelOrder(o.order_id!);
                              }}
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

        {selectedOrder && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 px-4 py-6"
            onClick={() => setSelectedOrder(null)}
          >
            <div
              className="w-full max-w-3xl max-h-[90vh] overflow-y-auto rounded-lg bg-white shadow-xl"
              onClick={(event) => event.stopPropagation()}
            >
              <div className="sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-slate-200 bg-white px-6 py-4">
                <div>
                  <h2 className="text-xl font-semibold text-slate-900">
                    Order {selectedOrder.order_id} History
                  </h2>
                  <p className="mt-1 text-sm text-slate-600">
                    {selectedOrder.strategy_code || selectedOrder.strategy_id} / {selectedOrder.stock_code} / {selectedOrder.backtest_run_id ? "Backtest" : "Live"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {canCancelTradingOrder(selectedOrder) && selectedOrder.order_id && (
                    <button
                      type="button"
                      onClick={async () => {
                        const cancelled = await handleCancelOrder(selectedOrder.order_id!);
                        if (cancelled) setSelectedOrder(null);
                      }}
                      className="rounded-md bg-red-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-red-700"
                    >
                      Cancel order
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => setSelectedOrder(null)}
                    className="rounded-md border border-slate-200 px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50"
                  >
                    Close
                  </button>
                </div>
              </div>

              <div className="px-6 py-5">
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 mb-6 text-sm">
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Status</div>
                    <div className="font-medium text-slate-900">{selectedOrder.status}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Side</div>
                    <div className="font-medium text-slate-900">{selectedOrder.side === "S" ? "Short" : "Long"}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Entry</div>
                    <div className="font-medium text-slate-900">
                      {formatEntryType(selectedOrder.entry_type)} {selectedOrder.entry_price != null ? `@ ${selectedOrder.entry_price}` : ""}
                    </div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Quantity</div>
                    <div className="font-medium text-slate-900">{selectedOrder.quantity}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Source</div>
                    <div className="font-medium text-slate-900">{selectedOrder.order_source_type}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Signal</div>
                    <div className="font-medium text-slate-900">{selectedOrder.signal_type || "-"}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Target</div>
                    <div className="font-medium text-slate-900">{selectedOrder.profit_target_price ?? "-"}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-wide text-slate-500">Stop</div>
                    <div className="font-medium text-slate-900">{selectedOrder.stop_loss_price ?? "-"}</div>
                  </div>
                </div>

                {selectedOrder.status === "OPEN" && !selectedOrder.exit_filled_at && (
                  <form
                    onSubmit={handleRecordExitFill}
                    className="mb-6 rounded-md border border-amber-200 bg-amber-50 px-4 py-4"
                  >
                    <div className="mb-3">
                      <h3 className="text-base font-semibold text-slate-900">Record exit fill</h3>
                      <p className="mt-1 text-sm text-slate-600">
                        Enter the actual exit execution price and Sydney time. The full order quantity will be recorded and the order will be marked CLOSED.
                      </p>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-3 sm:items-end">
                      <div>
                        <label className="block text-xs font-medium uppercase tracking-wide text-slate-600" htmlFor="exit-fill-price">
                          Filled price
                        </label>
                        <input
                          id="exit-fill-price"
                          type="number"
                          min="0.0001"
                          step="0.0001"
                          value={exitFillPrice}
                          onChange={(event) => setExitFillPrice(event.target.value)}
                          required
                          className="mt-1 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-400/40"
                          placeholder="e.g. 217.35"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium uppercase tracking-wide text-slate-600" htmlFor="exit-fill-time">
                          Filled time (Sydney)
                        </label>
                        <input
                          id="exit-fill-time"
                          type="datetime-local"
                          step="1"
                          value={exitFillTime}
                          onChange={(event) => setExitFillTime(event.target.value)}
                          required
                          className="mt-1 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-400/40"
                        />
                      </div>
                      <button
                        type="submit"
                        disabled={savingExitFill}
                        className="rounded-md bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-700 disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {savingExitFill ? "Saving..." : "Save exit fill"}
                      </button>
                    </div>
                  </form>
                )}

                <div className="space-y-0">
                  {selectedOrderTimeline.map((stage, index) => {
                    const isDone = stage.state === "done";
                    const isCurrent = stage.state === "current";
                    return (
                      <div key={stage.key} className="relative flex gap-4 pb-5 last:pb-0">
                        {index < selectedOrderTimeline.length - 1 && (
                          <div className="absolute left-[11px] top-6 h-full w-px bg-slate-200" />
                        )}
                        <div
                          className={`relative z-[1] mt-1 h-6 w-6 rounded-full border-2 ${
                            isDone
                              ? "border-green-500 bg-green-500 text-white"
                              : isCurrent
                              ? "border-blue-500 bg-blue-50 text-blue-700"
                              : "border-slate-300 bg-white text-slate-400"
                          }`}
                        />
                        <div className="min-w-0 flex-1 rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
                          <div className="flex flex-wrap items-center justify-between gap-2">
                            <div className="font-medium text-slate-900">{stage.label}</div>
                            <span
                              className={`rounded px-2 py-0.5 text-xs font-medium ${
                                isDone
                                  ? "bg-green-100 text-green-700"
                                  : isCurrent
                                  ? "bg-blue-100 text-blue-700"
                                  : "bg-slate-100 text-slate-500"
                              }`}
                            >
                              {isDone ? "Done" : isCurrent ? "Current" : "Waiting"}
                            </span>
                          </div>
                          <div className="mt-1 text-sm text-slate-600">{stage.description}</div>
                          <div className="mt-2 grid gap-1 text-xs text-slate-500 sm:grid-cols-2">
                            <div>
                              Time: <span className="font-medium text-slate-700">{formatSydneyDate(stage.timestamp, stage.sourceTimeZone)}</span>
                            </div>
                            {stage.price != null && (
                              <div>
                                {stage.priceLabel || "Price"}: <span className="font-medium text-slate-700">{formatPrice(stage.price)}</span>
                              </div>
                            )}
                            {stage.quantity != null && (
                              <div>
                                Filled qty: <span className="font-medium text-slate-700">{stage.quantity}</span>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>

                <div className="mt-6">
                  <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                    <h3 className="text-base font-semibold text-slate-900">Signal API Audit</h3>
                    <div className="flex items-center gap-3">
                      <label className="flex items-center gap-2 text-xs text-slate-700">
                        <input
                          type="checkbox"
                          checked={approvedOnly}
                          onChange={(e) => setApprovedOnly(e.target.checked)}
                          className="h-4 w-4 rounded border-slate-300 text-green-600 focus:ring-green-500"
                        />
                        Approved only
                      </label>
                      <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                        {visibleSignalAudits.length} {visibleSignalAudits.length === 1 ? "entry" : "entries"}
                      </span>
                    </div>
                  </div>

                  {visibleSignalAudits.length === 0 ? (
                    <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
                      {approvedOnly ? "No approved signal API audit entries found for this order." : "No signal API audit entries found for this order."}
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {visibleSignalAudits.map((audit, index) => (
                        <div
                          key={audit.order_signal_audit_id || `${audit.signal_key || "audit"}-${index}`}
                          className="rounded-md border border-slate-200 bg-white"
                        >
                          <div className="border-b border-slate-100 bg-slate-50 px-4 py-3">
                            <div className="flex flex-wrap items-center justify-between gap-2">
                              <div className="font-medium text-slate-900">
                                {audit.signal_type || "Signal"} {audit.intended_action ? `/ ${audit.intended_action}` : ""}
                              </div>
                              <span
                                className={`rounded px-2 py-0.5 text-xs font-medium ${
                                  String(audit.validation_status || "").toUpperCase() === "REJECTED"
                                    ? "bg-red-100 text-red-700"
                                    : String(audit.validation_status || "").toUpperCase() === "ACCEPTED"
                                    ? "bg-green-100 text-green-700"
                                    : "bg-slate-100 text-slate-600"
                                }`}
                              >
                                {audit.validation_status || "Unknown"}
                              </span>
                            </div>
                            <div className="mt-2 grid gap-2 text-xs text-slate-600 sm:grid-cols-2">
                              <div>
                                Triggered: <span className="font-medium text-slate-800">{formatSydneyDate(audit.triggered_at, US_EASTERN_TIME_ZONE)}</span>
                              </div>
                              <div>
                                Decision: <span className={`font-medium ${
                                  String(audit.validation_decision || "").toUpperCase() === "APPROVED"
                                    ? "text-green-700"
                                    : "text-slate-800"
                                }`}>{audit.validation_decision || "-"}</span>
                              </div>
                              <div>
                                Result: <span className="font-medium text-slate-800">{audit.validation_result ?? "-"}</span>
                              </div>
                              <div>
                                Job: <span className="font-medium text-slate-800 break-all">{audit.validation_job_id || "-"}</span>
                              </div>
                              <div className="sm:col-span-2">
                                Signal key: <span className="font-medium text-slate-800 break-all">{audit.signal_key || "-"}</span>
                              </div>
                            </div>
                          </div>

                          <div className="grid gap-3 px-4 py-3 lg:grid-cols-2">
                            <div>
                              <div className="mb-1 text-xs font-medium uppercase tracking-wide text-slate-500">Request</div>
                              <pre className="max-h-72 overflow-auto rounded border border-slate-200 bg-slate-950 p-3 text-xs leading-relaxed text-slate-100 whitespace-pre-wrap break-words">
                                {formatPayloadJson(audit.request_payload_json)}
                              </pre>
                            </div>
                            <div>
                              <div className="mb-1 text-xs font-medium uppercase tracking-wide text-slate-500">Response</div>
                              <pre className="max-h-72 overflow-auto rounded border border-slate-200 bg-slate-950 p-3 text-xs leading-relaxed text-slate-100 whitespace-pre-wrap break-words">
                                {formatPayloadJson(audit.response_payload_json)}
                              </pre>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="mt-5 rounded-md border border-slate-200 bg-white px-4 py-3 text-sm text-slate-600">
                  Last updated: <span className="font-medium text-slate-800">{formatSydneyDate(selectedOrder.updated_at)}</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
