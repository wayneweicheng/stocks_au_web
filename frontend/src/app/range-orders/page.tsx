"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Side = "Buy" | "Sell";
type Distribution = "Pyramid" | "Even";

interface GeneratedOrder {
  index: number;
  side: Side;
  price: number;
  allocatedWeight: number;
  allocatedValue: number;
  volume: number;
  computedValue: number;
}

function toNumber(value: string): number | null {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function ceilInt(n: number): number {
  return Math.ceil(n);
}

function generateLinearPricesInclusive(a: number, b: number, count: number): number[] {
  if (count <= 1) return [round2(a)];
  const low = Math.min(a, b);
  const high = Math.max(a, b);
  const step = (high - low) / (count - 1);
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    out.push(round2(low + step * i));
  }
  return out;
}

function normalize(weights: number[]): number[] {
  const sum = weights.reduce((acc, w) => acc + w, 0);
  if (sum <= 0) return weights.map(() => 0);
  return weights.map(w => w / sum);
}

export default function RangeOrdersPage() {
  const [stockCode, setStockCode] = useState<string>("QQQ");
  const [currency, setCurrency] = useState<string>("USD");
  const [totalAmount, setTotalAmount] = useState<string>("30000");
  const [totalVolume, setTotalVolume] = useState<string>("");
  const [startPrice, setStartPrice] = useState<string>("");
  const [endPrice, setEndPrice] = useState<string>("");
  const [side, setSide] = useState<Side>("Buy");
  const [distribution, setDistribution] = useState<Distribution>("Pyramid");
  const [numOrders, setNumOrders] = useState<string>("8");
  const [ratio, setRatio] = useState<string>("1.15"); // Pyramid ratio: Order 1 to Order 2
  const [submitted, setSubmitted] = useState<boolean>(false);
  const [placing, setPlacing] = useState<boolean>(false);
  const [placeError, setPlaceError] = useState<string>("");
  const [placeResult, setPlaceResult] = useState<any | null>(null);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [quoteClose, setQuoteClose] = useState<number | null>(null);
  const [quoteLast, setQuoteLast] = useState<number | null>(null);
  const [quoteError, setQuoteError] = useState<string>("");
  const [whatIfPrice, setWhatIfPrice] = useState<number | null>(null);
  const [placeDayOrders, setPlaceDayOrders] = useState<boolean>(true);
  const [placeOvernightOrders, setPlaceOvernightOrders] = useState<boolean>(false);
  const [showCancelConfirm, setShowCancelConfirm] = useState<boolean>(false);
  const [cancelSide, setCancelSide] = useState<"BUY" | "SELL" | null>(null);
  const [cancelling, setCancelling] = useState<boolean>(false);
  const [cancelResult, setCancelResult] = useState<any | null>(null);
  const [cancelError, setCancelError] = useState<string>("");

  const parsed = useMemo(() => {
    const total = toNumber(totalAmount);
    const tv = toNumber(totalVolume);
    const sp = toNumber(startPrice);
    const ep = toNumber(endPrice);
    const n = Math.max(1, Math.min(100, Math.floor(toNumber(numOrders) ?? 0) || 8));
    const rRaw = toNumber(ratio);
    const r = rRaw && rRaw > 0 ? Math.max(0.75, Math.min(1.5, rRaw)) : 1; // clamp to [0.75,1.5]
    return { total, tv, sp, ep, n, r };
  }, [totalAmount, totalVolume, startPrice, endPrice, numOrders, ratio]);

  const canGenerate = useMemo(() => {
    const hasPrices = !!parsed.sp && parsed.sp! > 0 && !!parsed.ep && parsed.ep! > 0;
    const need = side === "Buy" ? (parsed.total && parsed.total > 0) : (parsed.tv && parsed.tv > 0);
    return hasPrices && !!need && parsed.n > 0;
  }, [parsed, side]);

  const generated = useMemo<GeneratedOrder[] | null>(() => {
    if (!canGenerate) return null;
    const pricesAsc = generateLinearPricesInclusive(parsed.sp!, parsed.ep!, parsed.n);

    // For display order:
    // - Buy: list from low to high (bottom first)
    // - Sell: list from high to low (top first)
    const displayPrices = side === "Buy" ? pricesAsc : [...pricesAsc].reverse();

    // Build display weights:
    // - Even: equal weights
    // - Pyramid: geometric sequence so that Order1:Order2 = ratio
    let displayWeights: number[] = [];
    if (distribution === "Even") {
      displayWeights = Array.from({ length: parsed.n }, () => 1 / parsed.n);
    } else {
      const raw: number[] = [];
      // Make the first order heaviest, with consecutive ratio = parsed.r
      for (let i = 0; i < parsed.n; i++) {
        raw.push(Math.pow(parsed.r, (parsed.n - 1 - i)));
      }
      displayWeights = normalize(raw);
    }

    let out: GeneratedOrder[] = [];
    if (side === "Buy" || !parsed.tv) {
      // Value-based allocation (Buy)
      for (let i = 0; i < displayPrices.length; i++) {
        const price = displayPrices[i];
        const weight = displayWeights[i] ?? 0;
        const allocatedValue = round2((parsed.total ?? 0) * weight);
        const volume = ceilInt(allocatedValue / price);
        const computedValue = round2(volume * price);
        out.push({
          index: i + 1,
          side,
          price,
          allocatedWeight: weight,
          allocatedValue,
          volume,
          computedValue,
        });
      }
    } else {
      // Volume-based allocation (Sell)
      const tv = Math.max(1, Math.floor(parsed.tv));
      for (let i = 0; i < displayPrices.length; i++) {
        const price = displayPrices[i];
        const weight = displayWeights[i] ?? 0;
        const rawVol = tv * weight;
        const volume = Math.max(1, ceilInt(rawVol));
        const computedValue = round2(volume * price);
        out.push({
          index: i + 1,
          side,
          price,
          allocatedWeight: weight,
          allocatedValue: computedValue,
          volume,
          computedValue,
        });
      }
    }
    return out;
  }, [canGenerate, parsed, distribution, side]);

  const totals = useMemo(() => {
    if (!generated) return null;
    const sumValue = generated.reduce((acc, o) => acc + o.computedValue, 0);
    const sumVolume = generated.reduce((acc, o) => acc + o.volume, 0);
    return { sumValue: round2(sumValue), sumVolume };
  }, [generated]);

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
  };

  const normalizeUsSymbol = (s: string): string => {
    const up = (s || "").trim().toUpperCase();
    if (!up) return up;
    if (up.includes(".")) return up;
    return `${up}.US`;
  };

  // Load IB quote (prev close and last) when stock code changes or after submit
  useEffect(() => {
    const loadQuote = async () => {
      setQuoteError("");
      setQuoteClose(null);
      setQuoteLast(null);
      try {
        if (!baseUrl) return;
        const sc = normalizeUsSymbol(stockCode);
        if (!sc) return;
        const res = await authenticatedFetch(`${baseUrl}/api/ib/quote?stock_code=${encodeURIComponent(sc)}`);
        if (!res.ok) {
          return;
        }
        const data = await res.json();
        const close = typeof data?.close === "number" ? data.close : null;
        const last = typeof data?.last === "number" ? data.last : null;
        setQuoteClose(close);
        setQuoteLast(last);
      } catch (err: any) {
        setQuoteError(err?.message || "Failed to load quote");
      }
    };
    if (stockCode && stockCode.trim().length > 0) {
      loadQuote();
    } else {
      setQuoteClose(null);
      setQuoteLast(null);
    }
  }, [baseUrl, stockCode]);

  const formatNA = (v: number | null | undefined, digits = 2) =>
    typeof v === "number" && isFinite(v) ? v.toFixed(digits) : "N/A";

  const formatPctNA = (v: number | null | undefined, digits = 2) =>
    typeof v === "number" && isFinite(v) ? `${v >= 0 ? "+" : ""}${v.toFixed(digits)}%` : "N/A";

  // Price slider bounds: 15% below start to 15% above end (using min/max of range)
  const sliderBounds = useMemo(() => {
    const low = Math.min(parsed.sp ?? 0, parsed.ep ?? 0);
    const high = Math.max(parsed.sp ?? 0, parsed.ep ?? 0);
    if (low <= 0 || high <= 0) return null;
    const min = Math.max(0.01, round2(low * 0.85));
    const max = round2(high * 1.15);
    return { min, max };
  }, [parsed.sp, parsed.ep]);

  // Initialize what-if price when bounds or quotes change
  useEffect(() => {
    if (!sliderBounds) {
      setWhatIfPrice(null);
      return;
    }
    const within = (p: number | null) => p != null && p >= sliderBounds.min && p <= sliderBounds.max;
    const candidates = [quoteLast, quoteClose, (sliderBounds.min + sliderBounds.max) / 2];
    const pick = candidates.find(within);
    setWhatIfPrice(typeof pick === "number" ? round2(pick) : round2((sliderBounds.min + sliderBounds.max) / 2));
  }, [sliderBounds, quoteLast, quoteClose]);

  const pnlInfo = useMemo(() => {
    if (!totals || whatIfPrice == null) return null;
    const target = totals.sumVolume * whatIfPrice;
    const pnl = side === "Buy" ? target - totals.sumValue : totals.sumValue - target;
    const pctBase = totals.sumValue || 1;
    const pct = (pnl / pctBase) * 100;
    return { pnl: round2(pnl), pct: round2(pct) };
  }, [totals, whatIfPrice, side]);

  const vsPrevClosePct = useMemo(() => {
    if (quoteClose == null || whatIfPrice == null) return null;
    if (quoteClose === 0) return null;
    const pct = ((whatIfPrice - quoteClose) / quoteClose) * 100;
    return pct;
  }, [quoteClose, whatIfPrice]);

  const onPlaceOrders = async () => {
    if (!generated || !baseUrl) return;

    // Validate at least one option is selected
    if (!placeDayOrders && !placeOvernightOrders) {
      setPlaceError("Please select at least one order placement option (Day or Overnight)");
      return;
    }

    setPlacing(true);
    setPlaceError("");
    setPlaceResult(null);
    try {
      const buySell = side === "Buy" ? "BUY" : "SELL";
      const orders = generated.map(o => ({
        stock_code: normalizeUsSymbol(stockCode),
        // Use allocatedValue to match intended budget per order
        stock_dollar_amount: Math.max(0.01, Math.round(o.allocatedValue * 100) / 100),
        buy_sell: buySell,
        limit_price: o.price,
      }));
      const res = await authenticatedFetch(`${baseUrl}/api/ib/place-orders-at-price`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          orders,
          place_day: placeDayOrders,
          place_overnight: placeOvernightOrders
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        const errDetail = typeof data?.detail === "string" ? data.detail : "Order placement failed";
        throw new Error(errDetail);
      }
      setPlaceResult(data);
    } catch (e: any) {
      setPlaceError(e?.message || "Failed to place orders");
    } finally {
      setPlacing(false);
    }
  };

  const onCancelAllOrders = async () => {
    if (!baseUrl || !stockCode || !cancelSide) return;
    setCancelling(true);
    setCancelError("");
    setCancelResult(null);

    // Create abort controller for fetch timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, 30000);

    try {
      const res = await authenticatedFetch(`${baseUrl}/api/ib/cancel-all-orders-for-stock?stock_code=${encodeURIComponent(normalizeUsSymbol(stockCode))}&side=${cancelSide}`, {
        method: "POST",
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        const errDetail = typeof data?.detail === "string" ? data.detail : "Order cancellation failed";
        throw new Error(errDetail);
      }
      setCancelResult(data);
    } catch (e: any) {
      clearTimeout(timeoutId);
      if (e.name === "AbortError") {
        setCancelError("Request timed out after 30 seconds. The backend may be busy or IB Gateway may not be responding.");
      } else {
        setCancelError(e?.message || "Failed to cancel orders");
      }
    } finally {
      clearTimeout(timeoutId);
      setCancelling(false);
      setShowCancelConfirm(false);
      setCancelSide(null);
    }
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-3xl sm:text-4xl font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
            Price Range Orders
          </h1>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => {
                setCancelSide("BUY");
                setShowCancelConfirm(true);
              }}
              disabled={!stockCode || cancelling}
              className="rounded-md bg-red-600 px-3 py-2 text-sm font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel All BUY
            </button>
            <button
              type="button"
              onClick={() => {
                setCancelSide("SELL");
                setShowCancelConfirm(true);
              }}
              disabled={!stockCode || cancelling}
              className="rounded-md bg-orange-600 px-3 py-2 text-sm font-medium text-white hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-orange-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancel All SELL
            </button>
          </div>
        </div>

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <form onSubmit={onSubmit} className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Stock Code</label>
              <input
                type="text"
                value={stockCode}
                onChange={(e) => setStockCode(e.target.value.toUpperCase())}
                placeholder="e.g., QQQ"
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Currency</label>
              <select
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                <option value="USD">USD</option>
                <option value="AUD">AUD</option>
                <option value="EUR">EUR</option>
                <option value="GBP">GBP</option>
                <option value="JPY">JPY</option>
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Total Amount ({currency})</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={side === "Buy" ? totalAmount : (totals?.sumValue ?? 0)}
                onChange={(e) => setTotalAmount(e.target.value)}
                disabled={side === "Sell"}
                required={side === "Buy"}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40 ${
                  side === "Sell" ? "border-slate-300 bg-slate-100 text-slate-500 cursor-not-allowed" : "border-slate-300 bg-white"
                }`}
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Total Volume (shares)</label>
              <input
                type="number"
                min="0"
                value={side === "Buy" ? (totals?.sumVolume ?? 0) : (totalVolume || "")}
                onChange={(e) => setTotalVolume(e.target.value)}
                disabled={side === "Buy"}
                required={side === "Sell"}
                className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40 ${
                  side === "Buy" ? "border-slate-300 bg-slate-100 text-slate-500 cursor-not-allowed" : "border-slate-300 bg-white"
                }`}
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Start Price</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={startPrice}
                onChange={(e) => setStartPrice(e.target.value)}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">End Price</label>
              <input
                type="number"
                step="0.01"
                min="0"
                value={endPrice}
                onChange={(e) => setEndPrice(e.target.value)}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Side</label>
              <select
                value={side}
                onChange={(e) => setSide(e.target.value as Side)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                <option value="Buy">Buy</option>
                <option value="Sell">Sell</option>
              </select>
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Distribution</label>
              <select
                value={distribution}
                onChange={(e) => setDistribution(e.target.value as Distribution)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              >
                <option value="Pyramid">Pyramid (more at favorable prices)</option>
                <option value="Even">Even (equal value per order)</option>
              </select>
            </div>

            {distribution === "Pyramid" && (
              <div className="sm:col-span-2">
                <label className="block text-sm mb-1 text-slate-600">
                  Pyramid ratio (Order 1 : Order 2) — {Number(parsed.r).toFixed(2)}x
                </label>
                <input
                  type="range"
                  min={0.75}
                  max={1.5}
                  step={0.01}
                  value={ratio}
                  onChange={(e) => setRatio(e.target.value)}
                  className="w-full"
                />
                <div className="mt-2 flex items-center gap-2">
                  <input
                    type="number"
                    step="0.01"
                    min={0.75}
                    max={1.5}
                    value={ratio}
                    onChange={(e) => setRatio(e.target.value)}
                    className="w-32 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                  />
                  <span className="text-xs text-slate-500">
                    Higher = more weight to earlier orders
                  </span>
                </div>
              </div>
            )}

            <div>
              <label className="block text-sm mb-1 text-slate-600">Number of Orders</label>
              <input
                type="number"
                min="1"
                max="100"
                value={numOrders}
                onChange={(e) => setNumOrders(e.target.value)}
                required
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div className="sm:col-span-2 lg:col-span-3">
              <div className="space-y-3">
                <div className="text-sm font-medium text-slate-700">Order Placement Options:</div>
                <label className="flex items-center gap-2 text-sm text-slate-600 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={placeDayOrders}
                    onChange={(e) => setPlaceDayOrders(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-300 text-blue-500 focus:ring-2 focus:ring-blue-400/40"
                  />
                  <span>Place day orders (SMART exchange, DAY TIF)</span>
                </label>
                <label className="flex items-center gap-2 text-sm text-slate-600 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={placeOvernightOrders}
                    onChange={(e) => setPlaceOvernightOrders(e.target.checked)}
                    className="w-4 h-4 rounded border-slate-300 text-blue-500 focus:ring-2 focus:ring-blue-400/40"
                  />
                  <span>Place overnight orders (OVERNIGHT exchange, DAY TIF)</span>
                </label>
                <p className="text-xs text-slate-500">
                  Select one or both options. Orders will be placed on selected exchange(s).
                </p>
              </div>
            </div>

            <div className="sm:col-span-2 lg:col-span-3">
              <button
                type="submit"
                disabled={!canGenerate}
                className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Generate Orders
              </button>
            </div>
          </form>
        </div>

        {submitted && (
          <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto">
            <div className="p-6 pb-0">
              <h2 className="text-xl font-semibold">
                Generated {side} Orders for {stockCode} ({currency})
              </h2>
              <p className="text-sm text-slate-600 mt-1">
                Range {Math.min(parsed.sp ?? 0, parsed.ep ?? 0).toFixed(2)} - {Math.max(parsed.sp ?? 0, parsed.ep ?? 0).toFixed(2)} | Total Amount: {currency} {round2((side === "Buy" ? (parsed.total ?? 0) : (totals?.sumValue ?? 0))).toLocaleString()} | Prev Close: {formatNA(quoteClose)} | Last: {formatNA(quoteLast)}
              </p>
              <p className="text-xs text-slate-500 mt-2">
                Note: Volume is rounded up to the next integer. Actual total may exceed the requested amount due to rounding.
              </p>
            </div>
            {!generated || generated.length === 0 ? (
              <div className="p-6">No orders generated.</div>
            ) : (
              <table className="min-w-full text-sm mt-4">
                <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                  <tr>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">#</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Side</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Price</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Δ vs Close</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Weight</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Allocated {currency}</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Volume</th>
                    <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Order {currency}</th>
                  </tr>
                </thead>
                <tbody>
                  {generated.map((o) => (
                    <tr key={o.index} className={`transition-colors ${o.index % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.index}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.side}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.price.toFixed(2)}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {quoteClose != null ? (() => {
                          const pct = ((o.price - quoteClose) / quoteClose) * 100;
                          return formatPctNA(pct, 2);
                        })() : "N/A"}
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{(o.allocatedWeight * 100).toFixed(1)}%</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{round2(o.allocatedValue).toLocaleString()}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{o.volume}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{round2(o.computedValue).toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
                {totals && (
                  <tfoot>
                    <tr className="bg-slate-100 font-medium">
                      <td className="px-3 py-2 border-t border-slate-200" colSpan={6}>Totals</td>
                      <td className="px-3 py-2 border-t border-slate-200">{totals.sumVolume}</td>
                      <td className="px-3 py-2 border-t border-slate-200">{totals.sumValue.toLocaleString()}</td>
                    </tr>
                  </tfoot>
                )}
              </table>
            )}
            {submitted && generated && generated.length > 0 && (
              <div className="p-6 flex flex-col gap-3">
                {sliderBounds && (
                  <div className="rounded-md border border-slate-200 p-4 bg-slate-50">
                    <div className="flex flex-col gap-3">
                      <div className="text-sm font-medium text-slate-700">What-if P/L (assuming all orders filled)</div>
                      <div className="flex items-center gap-3">
                        <input
                          type="range"
                          min={sliderBounds.min}
                          max={sliderBounds.max}
                          step={0.01}
                          value={whatIfPrice ?? sliderBounds.min}
                          onChange={(e) => setWhatIfPrice(parseFloat(e.target.value))}
                          className="w-full"
                        />
                        <input
                          type="number"
                          step="0.01"
                          value={whatIfPrice ?? ""}
                          onChange={(e) => {
                            const v = e.target.value === "" ? null : parseFloat(e.target.value);
                            if (v == null || !sliderBounds) { setWhatIfPrice(null); return; }
                            const clamped = Math.max(sliderBounds.min, Math.min(sliderBounds.max, v));
                            setWhatIfPrice(round2(clamped));
                          }}
                          className="w-28 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                        />
                      </div>
                      <div className="text-sm">
                        Range: {sliderBounds.min.toFixed(2)} – {sliderBounds.max.toFixed(2)}
                      </div>
                      <div className="text-sm">
                        P/L at {whatIfPrice != null ? whatIfPrice.toFixed(2) : "—"}:{" "}
                        <span className={`${pnlInfo ? (pnlInfo.pnl > 0 ? "text-emerald-600" : pnlInfo.pnl < 0 ? "text-red-600" : "text-slate-700") : "text-slate-500"} font-semibold`}>
                          {pnlInfo ? `${pnlInfo.pnl.toLocaleString()} (${pnlInfo.pct.toFixed(2)}%)` : "N/A"}
                        </span>
                        {` , vs Prev Close (${formatPctNA(vsPrevClosePct, 2)})`}
                      </div>
                    </div>
                  </div>
                )}
                {placeError && (
                  <div className="rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
                    {placeError}
                  </div>
                )}
                <button
                  type="button"
                  disabled={placing || !baseUrl}
                  onClick={onPlaceOrders}
                  className="self-start rounded-md bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-400/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {placing && (
                    <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                  )}
                  {placing ? "Placing..." : "Place Orders"}
                </button>
                {placing && (
                  <div className="w-64 h-1 bg-emerald-100 rounded overflow-hidden">
                    <div className="h-full w-1/3 bg-emerald-500 animate-[progress_1.2s_linear_infinite]" />
                    <style>
                      {`
                        @keyframes progress {
                          0% { transform: translateX(-100%); }
                          100% { transform: translateX(300%); }
                        }
                      `}
                    </style>
                  </div>
                )}
                {placeResult && Array.isArray(placeResult.results) && (
                  <div className="text-sm text-slate-700">
                    <div className="font-semibold mb-1">Placement results</div>
                    <ul className="list-disc pl-5">
                      {placeResult.results.map((r: any, idx: number) => {
                        const ok = !!r.ok;
                        if (!ok) {
                          return (
                            <li key={idx} className="text-red-600">
                              Order {idx + 1}: Failed - {r.error || "Unknown error"}
                            </li>
                          );
                        }

                        // New format with multiple orders (SMART + OVERNIGHT)
                        if (Array.isArray(r.orders)) {
                          return (
                            <li key={idx}>
                              <div className="font-medium">Order {idx + 1}:</div>
                              <ul className="list-none pl-4 mt-1">
                                {r.orders.map((order: any, orderIdx: number) => {
                                  if (order.error) {
                                    return (
                                      <li key={orderIdx} className="text-amber-600">
                                        [{order.exchange}] {order.stock_code} - {order.error}
                                      </li>
                                    );
                                  }
                                  return (
                                    <li key={orderIdx} className="text-emerald-600">
                                      [{order.exchange}] {order.side} {order.stock_code} x {order.qty} @ {order.limit_price} — OK (ID: {order.ib_order_id})
                                    </li>
                                  );
                                })}
                              </ul>
                            </li>
                          );
                        }

                        // Legacy format support
                        const side = r.order?.side || r.request?.buy_sell;
                        const code = r.order?.stock_code || r.request?.stock_code;
                        const qty = r.order?.qty;
                        const lp = r.order?.limit_price ?? r.request?.limit_price;
                        return (
                          <li key={idx}>
                            {side} {code} {qty ? `x ${qty}` : ""} {lp ? `@ ${lp}` : ""} — {ok ? "OK" : "Failed"}
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Cancel All Orders Confirmation Modal */}
        {showCancelConfirm && cancelSide && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
              <h2 className="text-xl font-semibold mb-4 text-slate-800">Confirm Cancel All {cancelSide} Orders</h2>
              <p className="text-slate-600 mb-6">
                Are you sure you want to cancel ALL <span className="font-semibold">{cancelSide}</span> orders for <span className="font-semibold">{stockCode}</span>?
                This will cancel {cancelSide} orders on both SMART and OVERNIGHT exchanges.
              </p>
              <div className="flex gap-3 justify-end">
                <button
                  type="button"
                  onClick={() => {
                    setShowCancelConfirm(false);
                    setCancelSide(null);
                  }}
                  disabled={cancelling}
                  className="px-4 py-2 text-sm font-medium text-slate-700 bg-slate-100 rounded-md hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-slate-400/40 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={onCancelAllOrders}
                  disabled={cancelling}
                  className={`px-4 py-2 text-sm font-medium text-white rounded-md focus:outline-none focus:ring-2 disabled:opacity-50 flex items-center gap-2 ${
                    cancelSide === "BUY"
                      ? "bg-red-600 hover:bg-red-700 focus:ring-red-400/40"
                      : "bg-orange-600 hover:bg-orange-700 focus:ring-orange-400/40"
                  }`}
                >
                  {cancelling && (
                    <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                  )}
                  {cancelling ? "Cancelling..." : `Yes, Cancel All ${cancelSide}`}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Cancel Results */}
        {cancelResult && (
          <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
            <h2 className="text-xl font-semibold mb-4">Cancellation Results</h2>
            <p className="text-slate-700 mb-3">{cancelResult.message}</p>
            {cancelResult.orders && cancelResult.orders.length > 0 && (
              <div className="text-sm">
                <div className="font-semibold mb-2">Cancelled Orders:</div>
                <ul className="list-disc pl-5">
                  {cancelResult.orders.map((order: any, idx: number) => (
                    <li key={idx} className={order.status === "cancelled" ? "text-emerald-600" : "text-red-600"}>
                      [{order.exchange}] {order.side} {order.symbol} x {order.qty} @ {order.limit_price || "N/A"} — {order.status === "cancelled" ? "Cancelled" : `Failed: ${order.error}`}
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {cancelResult.debug && (
              <div className="mt-4 text-sm bg-slate-50 p-3 rounded border border-slate-200">
                <div className="font-semibold mb-2 text-slate-700">Debug Information:</div>
                <div className="text-slate-600 space-y-1">
                  <div>Total open trades: {cancelResult.debug.total_open_trades}</div>
                  <div>Searched for symbol: {cancelResult.debug.searched_for}</div>
                  <div>Side filter: {cancelResult.debug.side_filter || "None"}</div>
                  {cancelResult.debug.sample_trades && cancelResult.debug.sample_trades.length > 0 && (
                    <div>
                      <div className="font-medium mt-2 mb-1">Sample open trades:</div>
                      <ul className="list-disc pl-5">
                        {cancelResult.debug.sample_trades.map((trade: any, idx: number) => (
                          <li key={idx}>
                            Symbol: {trade.symbol}, Exchange: {trade.exchange}, Action: {trade.action}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              </div>
            )}
            <button
              type="button"
              onClick={() => setCancelResult(null)}
              className="mt-4 px-4 py-2 text-sm font-medium text-slate-700 bg-slate-100 rounded-md hover:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-slate-400/40"
            >
              Close
            </button>
          </div>
        )}

        {/* Cancel Error */}
        {cancelError && (
          <div className="rounded-lg border border-red-200 bg-red-50 p-4 mb-6">
            <div className="text-red-700 font-semibold mb-2">Error Cancelling Orders</div>
            <p className="text-red-600 text-sm">{cancelError}</p>
            <button
              type="button"
              onClick={() => setCancelError("")}
              className="mt-3 px-4 py-2 text-sm font-medium text-red-700 bg-red-100 rounded-md hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-red-400/40"
            >
              Close
            </button>
          </div>
        )}
      </div>
    </div>
  );
}


