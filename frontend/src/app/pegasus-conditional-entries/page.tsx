"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { formatActivityTimestamp, matchesActivityFilters, waitingForReversalMessage } from "./activityStatus";
import { buyOrderVolumes, orderWeights, sellOrderVolumes, type OrderDistribution } from "./orderSizing";
import { referencePriceTiers, targetPriceTiers } from "./triggerTiers";

type Side = "B" | "S";
type TriggerSource = "TARGET_STOCK" | "REFERENCE_STOCK";
type Strategy = { strategy_id: number; strategy_code: string };
type ConditionalIntent = {
  OrderId: number; StockCode: string; Side: Side; Quantity: number; Status: string;
  ConditionVersion: number; TargetPriceThreshold?: number | null; TriggerPriceThreshold?: number | null;
  TargetPriceActivationMode?: string | null; TargetPriceTickSize?: number | null;
  TriggerPriceActivationMode?: string | null; TriggerPriceTickSize?: number | null;
  TargetCursorRegion?: string | null; TargetTouchPrice?: number | null;
  TriggerCursorRegion?: string | null; TriggerTouchPrice?: number | null; TriggerStockCode?: string | null;
  AttemptId?: string | null; AttemptState?: string | null;
  EventSourceCode?: string | null; ObservedPrice?: number | null; ObservedAtUtc?: string | null;
  ClauseResultsJson?: string | null; SubmissionState?: string | null; PublishedAtUtc?: string | null;
  EvaluatorMode?: string | null; DeploymentEpoch?: string | null;
};

const apiBase = process.env.NEXT_PUBLIC_BACKEND_URL || "";
const CONDITIONAL_ENTRY_ACCOUNT_ID = "U7667798";
const MAX_LIVE_INTENT_QUANTITY = 10;
const ACTIVITY_PAGE_SIZE = 20;

export default function PegasusConditionalEntriesPage() {
  const [stock, setStock] = useState("");
  const [side, setSide] = useState<Side>("B");
  const [numOrders, setNumOrders] = useState(1);
  const [totalAmount, setTotalAmount] = useState("");
  const [totalVolume, setTotalVolume] = useState("");
  const [distribution, setDistribution] = useState<OrderDistribution>("Pyramid");
  const [pyramidRatio, setPyramidRatio] = useState(1.15);
  const [triggerSource, setTriggerSource] = useState<TriggerSource>("TARGET_STOCK");
  const [referenceStock, setReferenceStock] = useState("ESMAIN.US");
  const [startPrice, setStartPrice] = useState("");
  const [endPrice, setEndPrice] = useState("");
  const [targetLivePrice, setTargetLivePrice] = useState<number | null>(null);
  const [triggerLivePrice, setTriggerLivePrice] = useState<number | null>(null);
  const [quoteLoading, setQuoteLoading] = useState(false);
  const [quoteError, setQuoteError] = useState("");
  const [quoteRefresh, setQuoteRefresh] = useState(0);
  const [positionEnabled, setPositionEnabled] = useState(false);
  const [positionOperator, setPositionOperator] = useState("LESS_THAN");
  const [positionShares, setPositionShares] = useState("");
  const [marginEnabled, setMarginEnabled] = useState(false);
  const [marginPercent, setMarginPercent] = useState("");
  const [strategyId, setStrategyId] = useState<number | null>(null);
  const [runtimeReady, setRuntimeReady] = useState(false);
  const [executionEnabled, setExecutionEnabled] = useState(false);
  const [dryRun, setDryRun] = useState(false);
  const [runtimeMode, setRuntimeMode] = useState("PUBLISH_ONLY");
  const [orderRows, setOrderRows] = useState<ConditionalIntent[]>([]);
  const [activityPage, setActivityPage] = useState(1);
  const [attemptStatusFilter, setAttemptStatusFilter] = useState("ALL");
  const [outboxModeFilter, setOutboxModeFilter] = useState("ALL");
  const [manualRefreshing, setManualRefreshing] = useState(false);
  const [lastRefreshedAt, setLastRefreshedAt] = useState<Date | null>(null);
  const [refreshError, setRefreshError] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const requestKeyRef = useRef<{ body: string; key: string } | null>(null);

  const refreshOrders = useCallback(async (manual = false) => {
    if (manual) {
      setManualRefreshing(true);
      setRefreshError("");
    }
    try {
      const response = await authenticatedFetch(`${apiBase}/api/trading-orders/conditional-entry?limit=100`, { cache: "no-store" });
      if (!response.ok) {
        if (manual) setRefreshError(`Refresh failed (HTTP ${response.status}).`);
        return;
      }
      setOrderRows(await response.json());
      setLastRefreshedAt(new Date());
    } catch {
      if (manual) setRefreshError("Refresh failed. Please try again.");
      // A transient background read failure must not interrupt quote evaluation or retries.
    } finally {
      if (manual) setManualRefreshing(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    const loadStrategy = async () => {
      try {
        const [response, statusResponse, ordersResponse] = await Promise.all([
          authenticatedFetch(`${apiBase}/api/trading-orders/strategies`, { cache: "no-store" }),
          authenticatedFetch(`${apiBase}/api/trading-orders/conditional-entry/status`, { cache: "no-store" }),
          authenticatedFetch(`${apiBase}/api/trading-orders/conditional-entry?limit=100`, { cache: "no-store" }),
        ]);
        if (!response.ok || !statusResponse.ok) throw new Error("Could not load Conditional Entry readiness.");
        const [rows, status]: [Strategy[], { enabled: boolean; execution_enabled: boolean; dry_run?: boolean; mode?: string }] = await Promise.all([response.json(), statusResponse.json()]);
        const currentOrders: ConditionalIntent[] = ordersResponse.ok ? await ordersResponse.json() : [];
        const strategy = rows.find((row) => row.strategy_code === "CONDITIONAL_ENTRY");
        if (!cancelled) {
          setStrategyId(strategy?.strategy_id ?? null);
          setRuntimeReady(status.enabled === true);
          setExecutionEnabled(status.execution_enabled === true);
          setDryRun(status.dry_run === true);
          setRuntimeMode(status.mode || "PUBLISH_ONLY");
          setOrderRows(currentOrders);
        }
      } catch (caught) {
        if (!cancelled) setError(caught instanceof Error ? caught.message : "Could not load Pegasus strategies.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void loadStrategy();
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    const targetSymbol = stock.trim().toUpperCase();
    if (!targetSymbol) {
      setTargetLivePrice(null);
      setTriggerLivePrice(null);
      setQuoteLoading(false);
      setQuoteError("");
      return;
    }
    const controller = new AbortController();
    setTargetLivePrice(null);
    setTriggerLivePrice(null);
    const loadLivePrice = async (symbol: string): Promise<number | null> => {
      const response = await authenticatedFetch(
        `${apiBase}/api/stock-map-live-price?stock_code=${encodeURIComponent(symbol)}`,
        { cache: "no-store", signal: controller.signal },
      );
      if (!response.ok) throw new Error(`IB live quote request failed (HTTP ${response.status}).`);
      const payload = await response.json();
      const price = Number(payload?.live_price);
      return Number.isFinite(price) && price > 0 ? price : null;
    };
    setQuoteLoading(true);
    setQuoteError("");
    void (async () => {
      try {
        const [targetPrice, referencePrice] = await Promise.all([
          loadLivePrice(targetSymbol),
          triggerSource === "REFERENCE_STOCK" ? loadLivePrice(referenceStock) : Promise.resolve(null),
        ]);
        if (controller.signal.aborted) return;
        setTargetLivePrice(targetPrice);
        setTriggerLivePrice(triggerSource === "TARGET_STOCK" ? targetPrice : referencePrice);
        if (targetPrice == null || (triggerSource === "REFERENCE_STOCK" && referencePrice == null)) {
          setQuoteError("IB live price unavailable for the target stock or selected trigger source.");
        }
      } catch (caught) {
        if (!controller.signal.aborted) {
          setTargetLivePrice(null);
          setTriggerLivePrice(null);
          setQuoteError(caught instanceof Error ? caught.message : "IB live price unavailable.");
        }
      } finally {
        if (!controller.signal.aborted) setQuoteLoading(false);
      }
    })();
    return () => controller.abort();
  }, [stock, triggerSource, referenceStock, quoteRefresh]);

  useEffect(() => {
    if (!runtimeReady) return;
    const timer = setInterval(() => { void refreshOrders(); }, 5000);
    return () => clearInterval(timer);
  }, [runtimeReady, refreshOrders]);

  const cancelOrder = async (orderId: number) => {
    setError("");
    try {
      const response = await authenticatedFetch(`${apiBase}/api/trading-orders/conditional-entry/${orderId}/cancel`, { method: "POST" });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(typeof result?.detail === "string" ? result.detail : "Could not cancel the Trade Intent.");
      await refreshOrders();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not cancel the Trade Intent.");
    }
  };

  const filteredOrderRows = orderRows.filter((row) => matchesActivityFilters(row, {
    attemptStatus: attemptStatusFilter,
    outboxMode: outboxModeFilter,
  }));
  const activityPageCount = Math.max(1, Math.ceil(filteredOrderRows.length / ACTIVITY_PAGE_SIZE));
  const currentActivityPage = Math.min(activityPage, activityPageCount);
  const visibleOrderRows = filteredOrderRows.slice(
    (currentActivityPage - 1) * ACTIVITY_PAGE_SIZE,
    currentActivityPage * ACTIVITY_PAGE_SIZE,
  );

  const preview = useMemo(() => {
    const count = Math.max(1, Math.min(100, Math.floor(numOrders) || 1));
    const start = Number(startPrice);
    const end = Number(endPrice);
    const rangeValid = Number.isFinite(start) && Number.isFinite(end) && start > 0 && end > 0;
    const tiers = rangeValid
      ? triggerSource === "TARGET_STOCK"
        ? targetPriceTiers(start, end, count, side)
        : referencePriceTiers(start, end, count, side)
      : [];
    const weights = orderWeights(count, distribution, pyramidRatio);
    const buySizingPrices = triggerSource === "TARGET_STOCK"
      ? tiers
      : Array.from({ length: count }, () => targetLivePrice ?? 0);
    const buyVolumes = side === "B" ? buyOrderVolumes(Number(totalAmount), buySizingPrices, weights) : [];
    const sellVolumes = side === "S" ? sellOrderVolumes(Number(totalVolume), weights) : [];
    const orderVolumes = side === "B" ? buyVolumes : sellVolumes;
    return { count, tiers, weights, orderVolumes, rangeValid };
  }, [numOrders, startPrice, endPrice, triggerSource, side, distribution, pyramidRatio, totalAmount, totalVolume, targetLivePrice]);

  const computedTotalVolume = preview.orderVolumes.reduce((sum, volume) => sum + volume, 0);
  const estimatedTotalAmount = targetLivePrice != null && preview.orderVolumes.length === preview.count
    ? Math.round(preview.orderVolumes.reduce((sum, volume) => sum + volume * targetLivePrice, 0) * 100) / 100
    : null;
  const amountDifference = side === "B" && estimatedTotalAmount != null && Number(totalAmount) > 0
    ? Math.round((estimatedTotalAmount - Number(totalAmount)) * 100) / 100
    : null;

  const canSubmit = useMemo(() => {
    const tiersValid = preview.rangeValid && preview.tiers.length === preview.count
      && new Set(preview.tiers).size === preview.count
      && (triggerSource !== "REFERENCE_STOCK" || preview.tiers.every((tier) => {
        const low = Math.min(Number(startPrice), Number(endPrice));
        const high = Math.max(Number(startPrice), Number(endPrice));
        return tier >= low && tier <= high;
      }));
    const reversalValid = triggerSource !== "TARGET_STOCK"
      || preview.tiers.every((tier) => tier >= 1 && Math.abs(tier * 100 - Math.round(tier * 100)) < 1e-7);
    const sizingValid = side === "B"
      ? Number(totalAmount) > 0 && Number.isFinite(Number(totalAmount))
        && (triggerSource === "TARGET_STOCK" || targetLivePrice != null)
        && preview.orderVolumes.length === preview.count
      : Number.isInteger(Number(totalVolume)) && Number(totalVolume) >= preview.count
        && preview.orderVolumes.length === preview.count;
    const liveQuantityCapValid = preview.orderVolumes.every((volume) => volume <= MAX_LIVE_INTENT_QUANTITY);
    const distributionValid = distribution !== "Pyramid"
      || (Number.isFinite(pyramidRatio) && pyramidRatio >= 0.75 && pyramidRatio <= 1.5);
    return stock.trim().length > 0 && tiersValid && reversalValid && sizingValid && liveQuantityCapValid && distributionValid
      && Number.isInteger(numOrders) && numOrders >= 1 && numOrders <= 100
      && (!positionEnabled || (Number(positionShares) >= 0 && Number.isInteger(Number(positionShares))))
      && (!marginEnabled || (Number(marginPercent) >= 0 && Number(marginPercent) <= 100));
  }, [stock, triggerSource, preview, startPrice, endPrice, side, totalAmount, totalVolume, targetLivePrice, numOrders, distribution, pyramidRatio, positionEnabled, positionShares, marginEnabled, marginPercent]);

  const shiftPriceRange = (amount: number) => {
    const shift = (value: string) => {
      const parsed = Number(value);
      return Number.isFinite(parsed) && parsed > 0 ? (parsed + amount).toFixed(2) : value;
    };
    setStartPrice(shift);
    setEndPrice(shift);
  };

  const submit = async () => {
    setError("");
    setNotice("");
    if (!canSubmit || !strategyId) {
      setError("Enter one valid trigger-price range, valid order sizing, and ensure the Conditional Entry strategy is installed.");
      return;
    }
    setSubmitting(true);
    try {
      const orders = Array.from({ length: preview.count }, (_, index) => ({
        strategy_id: strategyId,
        stock_code: stock.trim().toUpperCase(),
        side,
        quantity: preview.orderVolumes[index],
        ...(triggerSource === "TARGET_STOCK" ? { target_price: {
          operator: side === "B" ? "AT_OR_BELOW" : "AT_OR_ABOVE",
          threshold: preview.tiers[index],
          confirmation_mode: "TOUCH_THEN_RETRACE",
        } } : { trigger_price: {
          instrument_code: referenceStock,
          operator: side === "B" ? "AT_OR_BELOW" : "AT_OR_ABOVE",
          threshold: preview.tiers[index],
          confirmation_mode: "TOUCH_THEN_RETRACE",
        } }),
        ...((positionEnabled || marginEnabled) ? { account_id: CONDITIONAL_ENTRY_ACCOUNT_ID } : {}),
        ...(positionEnabled ? { position_condition: { operator: positionOperator, shares: Number(positionShares) } } : {}),
        ...(marginEnabled ? { maximum_margin_capacity_used: Number(marginPercent) / 100 } : {}),
      }));
      const requestBody = JSON.stringify({ orders });
      if (!requestKeyRef.current || requestKeyRef.current.body !== requestBody) {
        requestKeyRef.current = { body: requestBody, key: crypto.randomUUID() };
      }
      const response = await authenticatedFetch(`${apiBase}/api/trading-orders/conditional-entry-batch`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Idempotency-Key": requestKeyRef.current.key,
        },
        body: requestBody,
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(typeof result?.detail === "string" ? result.detail : "Conditional entries could not be created.");
      setNotice(result?.message || `Created ${result?.count ?? orders.length} conditional Trade Intents.`);
      await refreshOrders();
      requestKeyRef.current = null;
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Conditional entries could not be created.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="mx-auto max-w-5xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold text-slate-900">Pegasus Conditional Entries</h1>
        <p className="mt-1 text-sm text-slate-600">Create conditional Trade Intents with Range Orders-style order sizing and one selectable trigger-price source.</p>
      </header>

      {!runtimeReady ? <section className="rounded-lg border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950">
        <strong>Conditional Entry runtime is not enabled.</strong> This page cannot create Trade Intents until the schema and evaluator are deployed and explicitly enabled. Existing Range Orders and direct IB placement are unaffected.
      </section> : <section className="rounded-lg border border-indigo-200 bg-indigo-50 p-4 text-sm text-indigo-950">
        {runtimeMode === "DB_ONLY" ? <><strong>Database-only test mode.</strong> Price events and Execution Requests are recorded in StockDB_US; no Pub/Sub message or broker order is sent.</> : executionEnabled && dryRun ? <><strong>Execution-enabled dry run.</strong> Live conditions flow through Pub/Sub to the executor, which logs WOULD_SUBMIT decisions only; it does not connect to IB or place broker orders.</> : executionEnabled ? <><strong>Live execution enabled.</strong> The independent executor rechecks broker state and risk before submitting.</> : <><strong>Publish-only mode.</strong> Conditions can be evaluated and audited, but no broker entry will be placed.</>} Immediate conditions require a fresh outside-to-inside edge; Touch-and-Reversal Confirmation waits for a fresh one-tick retracement after the target is touched.
      </section>}

      {error ? <p role="alert" className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">{error}</p> : null}
      {notice ? <p role="status" className="rounded border border-green-300 bg-green-50 p-3 text-sm text-green-800">{notice}</p> : null}

      <section className="grid gap-4 rounded-lg border bg-white p-5 sm:grid-cols-2">
        <label className="text-sm">Target stock
          <input value={stock} onChange={(event) => setStock(event.target.value.toUpperCase())} placeholder="QQQ" className="mt-1 w-full rounded border p-2" />
        </label>
        <label className="text-sm">Side
          <select value={side} onChange={(event) => setSide(event.target.value as Side)} className="mt-1 w-full rounded border p-2">
            <option value="B">Buy shares — may reduce a short or increase a long</option><option value="S">Sell shares — may reduce a long or open/increase a short</option>
          </select>
        </label>
        <label className="text-sm">Number of Orders
          <input type="number" min="1" max="100" step="1" value={numOrders} onChange={(event) => setNumOrders(Number(event.target.value))} className="mt-1 w-full rounded border p-2" />
        </label>
        <label className="text-sm">Distribution
          <select value={distribution} onChange={(event) => setDistribution(event.target.value as OrderDistribution)} className="mt-1 w-full rounded border p-2">
            <option value="Pyramid">Pyramid (more weight to earlier orders)</option><option value="Even">Even (equal allocation)</option>
          </select>
        </label>
        {distribution === "Pyramid" ? <label className="text-sm">Pyramid ratio (Order 1 : Order 2)
          <input type="number" min="0.75" max="1.5" step="0.01" value={pyramidRatio} onChange={(event) => setPyramidRatio(Number(event.target.value))} className="mt-1 w-full rounded border p-2" />
        </label> : null}
        <label className="text-sm">Total Amount (USD)
          <input type="number" min="0.01" step="0.01" value={side === "B" ? totalAmount : (estimatedTotalAmount?.toFixed(2) ?? "")} onChange={(event) => setTotalAmount(event.target.value)} disabled={side === "S"} required={side === "B"} className={`mt-1 w-full rounded border p-2 ${side === "S" ? "bg-slate-100 text-slate-500" : ""}`} />
          {side === "S" ? <p className="mt-1 text-xs text-slate-600">Computed from Total Volume × target stock’s IB live price.</p> : null}
          <div className="mt-1 text-xs text-slate-600">
            <div>Est. at Last ({targetLivePrice != null ? `$${targetLivePrice.toFixed(2)}` : "N/A"}): USD {estimatedTotalAmount?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) ?? "N/A"}</div>
            {side === "B" && amountDifference != null ? <div className="mt-0.5">Δ vs entered: USD {amountDifference.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</div> : null}
          </div>
        </label>
        <label className="text-sm">Total Volume (shares)
          <input type="number" min={side === "B" ? undefined : numOrders} step="1" value={side === "B" ? (preview.orderVolumes.length === preview.count ? computedTotalVolume : "") : totalVolume} onChange={(event) => setTotalVolume(event.target.value)} disabled={side === "B"} required={side === "S"} className={`mt-1 w-full rounded border p-2 ${side === "B" ? "bg-slate-100 text-slate-500" : ""}`} />
          {side === "B" ? <p className="mt-1 text-xs text-slate-600">Computed from Total Amount using each target trigger tier; when using a reference stock, the target stock’s IB live price is used.</p> : <p className="mt-1 text-xs text-slate-600">Enter whole shares; each order receives at least one share.</p>}
        </label>
      </section>

      <section className="space-y-4 rounded-lg border bg-white p-5">
        <h2 className="font-semibold">Trigger stock price condition</h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="text-sm">Trigger price source
            <select value={triggerSource} onChange={(event) => setTriggerSource(event.target.value as TriggerSource)} className="mt-1 w-full rounded border p-2">
              <option value="TARGET_STOCK">Target stock</option><option value="REFERENCE_STOCK">Reference stock</option>
            </select>
          </label>
          {triggerSource === "REFERENCE_STOCK" ? <label className="text-sm">Reference stock
            <select value={referenceStock} onChange={(event) => setReferenceStock(event.target.value)} className="mt-1 w-full rounded border p-2">
              <option value="ESMAIN.US">ESMain.US</option>
            </select>
          </label> : null}
        </div>
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <span className="text-slate-600">IB live price ({triggerSource === "TARGET_STOCK" ? stock.trim().toUpperCase() || "target stock" : referenceStock}):</span>
          <strong className="text-slate-900">{quoteLoading ? "Loading…" : triggerLivePrice != null ? `$${triggerLivePrice.toFixed(2)}` : "N/A"}</strong>
          <button type="button" onClick={() => setQuoteRefresh((current) => current + 1)} disabled={quoteLoading || !stock.trim()} className="rounded border px-2 py-1 text-xs disabled:opacity-50">Refresh live price</button>
          {triggerSource === "REFERENCE_STOCK" ? <span className="text-xs text-slate-500">Target stock IB price is used separately for share sizing.</span> : null}
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <label className="text-sm">Start Price<input type="number" min="0.01" step={triggerSource === "REFERENCE_STOCK" ? "0.25" : "0.01"} value={startPrice} onChange={(event) => setStartPrice(event.target.value)} className="mt-1 w-full rounded border p-2" /></label>
          <label className="text-sm">End Price<input type="number" min="0.01" step={triggerSource === "REFERENCE_STOCK" ? "0.25" : "0.01"} value={endPrice} onChange={(event) => setEndPrice(event.target.value)} className="mt-1 w-full rounded border p-2" /></label>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm text-slate-600">Move price range</span>
          <button type="button" onClick={() => shiftPriceRange(0.25)} title="Move start and end price up by 0.25" aria-label="Move start and end price up" className="inline-flex h-9 w-9 items-center justify-center rounded border text-lg font-semibold">↑</button>
          <button type="button" onClick={() => shiftPriceRange(-0.25)} title="Move start and end price down by 0.25" aria-label="Move start and end price down" className="inline-flex h-9 w-9 items-center justify-center rounded border text-lg font-semibold">↓</button>
        </div>
        {quoteError ? <p className="text-xs text-amber-700">{quoteError}</p> : null}
        <p className="rounded bg-amber-50 p-3 text-xs text-amber-950">Touch-and-Reversal Confirmation is always used for the selected trigger source. A Buy waits for price to enter at/below its tier, then confirms after recovering one tick above it; a Sell waits for price to enter at/above its tier, then confirms after reversing one tick below. Target stocks use a $0.01 tick (minimum threshold $1.00); ESMain uses a 0.25-point tick. This is not news detection and cannot guarantee protection from sudden moves.</p>
        <p className="text-xs text-slate-600">The entered Start and End values define the range in either order. The trigger must touch its tier and then reverse by one source tick; position, margin, or time changes alone will not replay a consumed trigger.</p>
      </section>

      <section className="grid gap-4 rounded-lg border bg-white p-5 sm:grid-cols-2">
        <h2 className="font-semibold sm:col-span-2">Optional entry constraints (AND)</h2>
        <p className="text-xs text-slate-600 sm:col-span-2">Position and margin constraints use IB account {CONDITIONAL_ENTRY_ACCOUNT_ID}.</p>
        <label className="flex items-center gap-2 text-sm sm:col-span-2"><input type="checkbox" checked={positionEnabled} onChange={(event) => setPositionEnabled(event.target.checked)} />Current signed target-stock position</label>
        {positionEnabled ? <div className="flex gap-2"><select value={positionOperator} onChange={(event) => setPositionOperator(event.target.value)} className="mt-1 rounded border p-2"><option value="LESS_THAN">Less than</option><option value="GREATER_THAN">Greater than</option><option value="EQUAL">Equal to</option></select><input aria-label="Position share threshold" type="number" min="0" step="1" value={positionShares} onChange={(event) => setPositionShares(event.target.value)} placeholder="Shares" className="mt-1 w-full rounded border p-2" /></div> : null}
        <label className="flex items-center gap-2 text-sm sm:col-span-2"><input type="checkbox" checked={marginEnabled} onChange={(event) => setMarginEnabled(event.target.checked)} />Maximum margin capacity used</label>
        {marginEnabled ? <label className="text-sm">Maximum percent<input type="number" min="0" max="100" step="0.1" value={marginPercent} onChange={(event) => setMarginPercent(event.target.value)} className="mt-1 w-full rounded border p-2" /></label> : null}
      </section>

      <section className="rounded-lg border bg-white p-5">
        <h2 className="font-semibold">Per-order preview</h2>
        {preview.orderVolumes.some((volume) => volume > MAX_LIVE_INTENT_QUANTITY) ? <p role="alert" className="mt-2 rounded bg-amber-50 p-3 text-sm text-amber-900">Each Trade Intent is currently capped at {MAX_LIVE_INTENT_QUANTITY} shares by the live executor. Increase Number of Orders, change the allocation, or reduce the entered amount/volume.</p> : null}
        {preview.tiers.length !== preview.count || preview.orderVolumes.length !== preview.count ? <p className="mt-2 text-sm text-slate-500">Enter a valid trigger range and order sizing to preview.</p> : <ol className="mt-3 grid gap-2 sm:grid-cols-2">
          {Array.from({ length: preview.count }, (_, index) => <li key={index} className="rounded bg-slate-50 p-3 text-sm">Order {index + 1}: {triggerSource === "TARGET_STOCK" ? stock.trim().toUpperCase() : referenceStock} trigger {preview.tiers[index].toFixed(2)} · {preview.orderVolumes[index]} shares</li>)}
        </ol>}
        <button type="button" disabled={loading || submitting || !runtimeReady || !canSubmit || !strategyId} onClick={() => void submit()} className="mt-5 rounded bg-indigo-700 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50">
          {loading ? "Loading…" : submitting ? "Creating…" : "Create conditional Trade Intents"}
        </button>
        {!strategyId && !loading ? <p className="mt-2 text-xs text-amber-800">CONDITIONAL_ENTRY strategy is not installed in the database yet.</p> : null}
        {!runtimeReady && !loading ? <p className="mt-2 text-xs text-amber-800">The operator has not enabled all required runtime processes.</p> : null}
      </section>

      <section className="space-y-3 rounded-lg border bg-white p-5">
        <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-start">
          <div>
            <h2 className="font-semibold">Conditional Trade Intent activity</h2>
            <p className="text-xs text-slate-600">Refreshes every five seconds; DB-only mode records triggers and Execution Requests without publishing or submitting.</p>
            <p className="mt-1 text-xs text-slate-500">CLAIMED means a worker reserved the attempt, not that it filled. The attempt normally proceeds through DISPATCHED → SUBMITTING → ACCEPTED; a DRY_RUN ends as SIMULATED without changing the Trade Intent or contacting IB. Other terminal outcomes include BLOCKED, UNCERTAIN, ERROR, or CANCELLED. The submission can end ACCEPTED, SIMULATED, BLOCKED, REJECTED, UNCERTAIN, or CANCELLED. Broker acceptance is not a fill: the order may become PLACED/OPEN, then CLOSED when the position is exited.</p>
            {refreshError ? <p role="alert" className="mt-1 text-xs text-red-700">{refreshError}</p> : lastRefreshedAt ? <p role="status" className="mt-1 text-xs text-slate-500">Updated {formatActivityTimestamp(lastRefreshedAt)}</p> : null}
          </div>
          <div className="flex flex-wrap items-end gap-2">
            <label className="text-xs text-slate-600">Attempt status
              <select aria-label="Filter by latest attempt status" value={attemptStatusFilter} onChange={(event) => { setAttemptStatusFilter(event.target.value); setActivityPage(1); }} className="mt-1 block rounded border border-slate-300 bg-white px-2 py-1.5 text-sm text-slate-800">
                <option value="ALL">All attempts</option>
                <option value="NONE">No attempt</option>
                <option value="CLAIMED">CLAIMED</option>
                <option value="DISPATCHED">DISPATCHED</option>
                <option value="SUBMITTING">SUBMITTING</option>
                <option value="ACCEPTED">ACCEPTED</option>
                <option value="SIMULATED">SIMULATED</option>
                <option value="BLOCKED">BLOCKED</option>
                <option value="UNCERTAIN">UNCERTAIN</option>
                <option value="ERROR">ERROR</option>
                <option value="CANCELLED">CANCELLED</option>
              </select>
            </label>
            <label className="text-xs text-slate-600">Outbox mode
              <select aria-label="Filter by outbox mode" value={outboxModeFilter} onChange={(event) => { setOutboxModeFilter(event.target.value); setActivityPage(1); }} className="mt-1 block rounded border border-slate-300 bg-white px-2 py-1.5 text-sm text-slate-800">
                <option value="ALL">All outbox modes</option>
                <option value="NONE">No outbox</option>
                <option value="DB_ONLY">DB_ONLY</option>
                <option value="PUBLISH_ONLY">PUBLISH_ONLY</option>
                <option value="EXECUTION_ENABLED">EXECUTION_ENABLED</option>
              </select>
            </label>
            <button
              type="button"
              onClick={() => void refreshOrders(true)}
              disabled={manualRefreshing}
              aria-busy={manualRefreshing}
              className={`inline-flex min-w-28 items-center justify-center gap-2 rounded border px-3 py-1.5 text-sm font-medium transition-colors ${manualRefreshing ? "cursor-wait border-indigo-400 bg-indigo-100 text-indigo-900" : "border-slate-300 bg-white text-slate-700 hover:bg-slate-50"}`}
            >
              {manualRefreshing ? <><span aria-hidden="true" className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-indigo-700 border-t-transparent" />Refreshing…</> : "Refresh"}
            </button>
          </div>
        </div>
        {orderRows.length === 0 ? <p className="text-sm text-slate-500">No Conditional Trade Intents are visible yet.</p> : filteredOrderRows.length === 0 ? <p className="text-sm text-slate-500">No Trade Intents match these filters.</p> : <>
          <ul className="space-y-3">
          {visibleOrderRows.map((row) => <li key={row.OrderId} className="rounded border p-3 text-sm">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="font-medium">#{row.OrderId} · {row.StockCode} · {row.Side === "B" ? "BUY" : "SELL"} {row.Quantity} · {row.Status}</div>
              {row.Status === "PENDING" ? <button type="button" onClick={() => void cancelOrder(row.OrderId)} className="rounded border border-red-300 px-2 py-1 text-xs text-red-700">Cancel</button> : null}
            </div>
            <p className="mt-1 text-xs text-slate-600">Condition v{row.ConditionVersion}{row.TargetPriceThreshold != null ? ` · Target ${row.TargetPriceThreshold} ${row.TargetPriceActivationMode === "TOUCH_THEN_RETRACE" ? "(touch/reversal)" : ""}` : ""}{row.TriggerPriceThreshold != null ? ` · ESMain ${row.TriggerPriceThreshold}` : ""}</p>
            <p className="mt-1 text-xs text-slate-700">Latest attempt: {row.AttemptState || (row.TargetCursorRegion === "WAITING_FOR_REVERSAL" && row.Status === "PENDING" ? "none yet (waiting for reversal)" : "waiting for a fresh price edge")}{row.EventSourceCode ? ` · ${row.EventSourceCode} ${row.ObservedPrice ?? ""}` : ""}{row.ObservedAtUtc ? ` · observed ${formatActivityTimestamp(row.ObservedAtUtc)}` : ""}{row.SubmissionState ? ` · request ${row.SubmissionState}` : ""}{row.EvaluatorMode ? ` · outbox ${row.EvaluatorMode}` : ""}</p>
            {waitingForReversalMessage(row) ? <p className="mt-1 text-xs font-medium text-amber-800">{waitingForReversalMessage(row)}</p> : null}
            {row.ClauseResultsJson ? <details className="mt-2"><summary className="cursor-pointer text-xs text-indigo-700">Attempt observations and clause results</summary><pre className="mt-2 max-h-64 overflow-auto rounded bg-slate-50 p-2 text-[11px]">{row.ClauseResultsJson}</pre></details> : null}
          </li>)}
          </ul>
          <nav aria-label="Trade Intent activity pagination" className="flex flex-wrap items-center justify-between gap-3 border-t pt-3 text-sm">
            <p className="text-slate-600">Showing {(currentActivityPage - 1) * ACTIVITY_PAGE_SIZE + 1}–{Math.min(currentActivityPage * ACTIVITY_PAGE_SIZE, filteredOrderRows.length)} of {filteredOrderRows.length} Trade Intents</p>
            <div className="flex items-center gap-2">
              <button type="button" onClick={() => setActivityPage(Math.max(1, currentActivityPage - 1))} disabled={currentActivityPage <= 1} className="rounded border px-3 py-1.5 disabled:cursor-not-allowed disabled:opacity-50">Previous</button>
              <span aria-live="polite" className="min-w-16 text-center">Page {currentActivityPage} of {activityPageCount}</span>
              <button type="button" onClick={() => setActivityPage(Math.min(activityPageCount, currentActivityPage + 1))} disabled={currentActivityPage >= activityPageCount} className="rounded border px-3 py-1.5 disabled:cursor-not-allowed disabled:opacity-50">Next</button>
            </div>
          </nav>
        </>}
      </section>
    </main>
  );
}
