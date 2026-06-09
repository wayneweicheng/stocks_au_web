"use client";

import { useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import Select from "../components/ui/Select";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Right = "P" | "C";
type Action = "SELL" | "BUY";

interface ChainRow {
  symbol: string;
  option_symbol: string;
  expiry: string;
  expiry_date: string;
  dte: number;
  right: Right;
  strike: number;
}

interface ChainResponse {
  ok: boolean;
  symbol: string;
  underlying: {
    reference_price: number | null;
    bid: number | null;
    ask: number | null;
    last: number | null;
    close: number | null;
  };
  expirations: string[];
  rows: ChainRow[];
}

interface ExpirationRow {
  expiry: string;
  expiry_date: string;
  dte: number;
}

interface ExpirationsResponse {
  ok: boolean;
  symbol: string;
  underlying: ChainResponse["underlying"];
  expirations: ExpirationRow[];
}

interface EstimateResponse {
  ok: boolean;
  option_symbol: string;
  estimated_price: number;
  base_case: number;
  optimistic: number;
  conservative: number;
  adjusted_iv: number;
  contract_iv: number;
  skew_adjustment: number;
  directional_iv_adjustment: number;
  warnings?: string[];
  quote: {
    bid: number | null;
    ask: number | null;
    mid: number | null;
    iv: number | null;
    delta: number | null;
    gamma: number | null;
    theta: number | null;
    vega: number | null;
  };
}

interface OrderResult {
  ok: boolean;
  message?: string;
  ib_order_id?: number;
  option_symbol?: string;
  warnings?: string[];
  error?: string;
  detail?: string;
}

function money(value: number | null | undefined, digits = 2) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return `$${Number(value).toFixed(digits)}`;
}

function num(value: number | null | undefined, digits = 2) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return Number(value).toLocaleString(undefined, { maximumFractionDigits: digits });
}

function pct(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return `${(Number(value) * 100).toFixed(1)}%`;
}

function parsePositive(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function orderSummary(action: Action, row: ChainRow | null, qty: string, limitPrice: string) {
  if (!row) return "";
  return `${action} ${qty || "?"} ${row.option_symbol} @ ${limitPrice || "?"} limit`;
}

export default function OptionOrdersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [symbol, setSymbol] = useState("AVGO");
  const [right, setRight] = useState<Right>("P");
  const [strikeWindowPct, setStrikeWindowPct] = useState("0.25");
  const [expirations, setExpirations] = useState<ExpirationRow[]>([]);
  const [selectedExpiry, setSelectedExpiry] = useState("");
  const [chain, setChain] = useState<ChainResponse | null>(null);
  const [selectedKey, setSelectedKey] = useState("");
  const [expiryFilter, setExpiryFilter] = useState("");
  const [strikeFilter, setStrikeFilter] = useState("");
  const [loadingChain, setLoadingChain] = useState(false);
  const [estimating, setEstimating] = useState(false);
  const [placing, setPlacing] = useState(false);
  const [error, setError] = useState("");
  const [estimateError, setEstimateError] = useState("");
  const [orderResult, setOrderResult] = useState<OrderResult | null>(null);
  const [estimate, setEstimate] = useState<EstimateResponse | null>(null);
  const [targetUnderlying, setTargetUnderlying] = useState("");
  const [action, setAction] = useState<Action>("SELL");
  const [quantity, setQuantity] = useState("1");
  const [limitPrice, setLimitPrice] = useState("");
  const [bracketExitPct, setBracketExitPct] = useState("30");
  const [showConfirm, setShowConfirm] = useState(false);

  const selectedRow = useMemo(() => {
    if (!chain || !selectedKey) return null;
    return chain.rows.find((row) => row.option_symbol === selectedKey) || null;
  }, [chain, selectedKey]);

  const filteredRows = useMemo(() => {
    const strikeSearch = Number(strikeFilter);
    return (chain?.rows || [])
      .filter((row) => !expiryFilter || row.expiry === expiryFilter)
      .filter((row) => !strikeFilter || !Number.isFinite(strikeSearch) || Math.abs(row.strike - strikeSearch) < 0.0001)
      .slice(0, 600);
  }, [chain, expiryFilter, strikeFilter]);

  const assignmentExposure = useMemo(() => {
    const qty = parsePositive(quantity);
    if (!selectedRow || !qty || action !== "SELL" || selectedRow.right !== "P") return null;
    return selectedRow.strike * 100 * qty;
  }, [action, quantity, selectedRow]);

  const bracketExitPrice = useMemo(() => {
    const entry = parsePositive(limitPrice);
    const pctValue = Number(bracketExitPct);
    if (!entry || !Number.isFinite(pctValue) || pctValue < 0) return null;
    const pctDecimal = pctValue / 100;
    const raw = action === "BUY" ? entry * (1 + pctDecimal) : entry * Math.max(0.01, 1 - pctDecimal);
    return Math.round((raw + Number.EPSILON) * 100) / 100;
  }, [action, bracketExitPct, limitPrice]);

  const loadExpirations = async () => {
    if (!baseUrl) return;
    setLoadingChain(true);
    setError("");
    setEstimateError("");
    setOrderResult(null);
    setEstimate(null);
    setSelectedKey("");
    setChain(null);
    setExpirations([]);
    setSelectedExpiry("");
    try {
      const params = new URLSearchParams({
        symbol: symbol.trim().toUpperCase(),
      });
      const response = await authenticatedFetch(`${baseUrl}/api/option-orders/expirations?${params.toString()}`, {
        cache: "no-store",
      });
      const data: ExpirationsResponse = await response.json();
      if (!response.ok) throw new Error((data as any)?.detail || `HTTP ${response.status}`);
      setExpirations(Array.isArray(data.expirations) ? data.expirations : []);
      setTargetUnderlying(data?.underlying?.reference_price ? String(data.underlying.reference_price) : "");
      setSelectedExpiry(data?.expirations?.[0]?.expiry || "");
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setLoadingChain(false);
    }
  };

  const loadChain = async () => {
    if (!baseUrl) return;
    if (!selectedExpiry) {
      setError("Load expiries and select an expiry first.");
      return;
    }
    setLoadingChain(true);
    setError("");
    setEstimateError("");
    setOrderResult(null);
    setEstimate(null);
    setSelectedKey("");
    try {
      const params = new URLSearchParams({
        symbol: symbol.trim().toUpperCase(),
        right,
        expiry: selectedExpiry,
        max_expiries: "1",
        strike_window_pct: String(Math.max(0.01, Math.min(2, Number(strikeWindowPct) || 0.25))),
      });
      const response = await authenticatedFetch(`${baseUrl}/api/option-orders/chain?${params.toString()}`, {
        cache: "no-store",
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data?.detail || `HTTP ${response.status}`);
      setChain(data);
      setTargetUnderlying(data?.underlying?.reference_price ? String(data.underlying.reference_price) : "");
      setExpiryFilter(selectedExpiry);
    } catch (exc: any) {
      setError(exc?.message || String(exc));
      setChain(null);
    } finally {
      setLoadingChain(false);
    }
  };

  const selectRow = (row: ChainRow) => {
    setSelectedKey(row.option_symbol);
    setEstimate(null);
    setEstimateError("");
    setOrderResult(null);
    setLimitPrice("");
  };

  const estimatePrice = async () => {
    if (!baseUrl || !selectedRow) return;
    const target = parsePositive(targetUnderlying);
    if (!target) {
      setEstimateError("Enter a valid target underlying price.");
      return;
    }
    setEstimating(true);
    setEstimateError("");
    setOrderResult(null);
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/option-orders/estimate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          symbol: selectedRow.symbol,
          expiry: selectedRow.expiry,
          strike: selectedRow.strike,
          right: selectedRow.right,
          target_underlying_price: target,
        }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data?.detail || `HTTP ${response.status}`);
      setEstimate(data);
      setLimitPrice(Number(data.estimated_price).toFixed(2));
    } catch (exc: any) {
      setEstimateError(exc?.message || String(exc));
      setEstimate(null);
    } finally {
      setEstimating(false);
    }
  };

  const placeOrder = async () => {
    if (!baseUrl || !selectedRow) return;
    const qty = parsePositive(quantity);
    const price = parsePositive(limitPrice);
    if (!qty || !Number.isInteger(qty)) {
      setOrderResult({ ok: false, error: "Quantity must be a positive whole number." });
      return;
    }
    if (!price) {
      setOrderResult({ ok: false, error: "Limit price must be positive." });
      return;
    }
    setPlacing(true);
    setOrderResult(null);
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/ib/place-option-order`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          option_symbol: selectedRow.option_symbol,
          quantity: qty,
          action,
          limit_price: price,
          bracket_exit_price: bracketExitPrice,
          parent_tif: "DAY",
          bracket_exit_tif: "GTC",
        }),
      });
      const data = await response.json();
      if (!response.ok) {
        setOrderResult({ ok: false, error: data?.detail || data?.error || `HTTP ${response.status}` });
      } else {
        setOrderResult(data);
      }
    } catch (exc: any) {
      setOrderResult({ ok: false, error: exc?.message || String(exc) });
    } finally {
      setPlacing(false);
      setShowConfirm(false);
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Option Orders"
        subtitle="Manual IB option-chain order entry with target-underlying repricing."
        actions={
          <>
            <Button variant="secondary" onClick={loadExpirations} disabled={loadingChain}>
              {loadingChain ? "Loading..." : "Load Expiries"}
            </Button>
            <Button onClick={loadChain} disabled={loadingChain || !selectedExpiry}>
              {loadingChain ? "Loading..." : "Load Contracts"}
            </Button>
          </>
        }
      />

      {error ? <Alert variant="danger">Error: {error}</Alert> : null}

      <Card>
        <CardHeader>
          <CardTitle>Chain Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-5">
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Stock</span>
              <Input value={symbol} onChange={(event) => setSymbol(event.target.value.toUpperCase())} placeholder="AVGO" />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Type</span>
              <Select value={right} onChange={(event) => setRight(event.target.value as Right)}>
                <option value="P">Puts</option>
                <option value="C">Calls</option>
              </Select>
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Expiry</span>
              <Select value={selectedExpiry} onChange={(event) => setSelectedExpiry(event.target.value)}>
                <option value="">Load expiries first</option>
                {expirations.map((item) => (
                  <option key={item.expiry} value={item.expiry}>
                    {item.expiry_date} ({item.dte} DTE)
                  </option>
                ))}
              </Select>
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Strike Window</span>
              <Input type="number" min="0.01" max="2" step="0.01" value={strikeWindowPct} onChange={(event) => setStrikeWindowPct(event.target.value)} />
            </label>
            <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm">
              <div className="text-xs uppercase text-slate-500">Underlying</div>
              <div className="mt-1 font-semibold">{money(chain?.underlying?.reference_price)}</div>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Card>
          <CardHeader>
            <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
              <div>
                <CardTitle>Available Contracts</CardTitle>
                <p className="mt-1 text-sm text-slate-600">
                  {chain ? `${chain.rows.length.toLocaleString()} contracts loaded for ${selectedExpiry}. Showing up to 600 rows.` : "Load expiries, choose one expiry, then load contracts."}
                </p>
              </div>
              <div className="grid gap-2 md:grid-cols-2">
                <Select value={expiryFilter} onChange={(event) => setExpiryFilter(event.target.value)}>
                  {(chain?.expirations || []).map((expiry) => (
                    <option key={expiry} value={expiry}>{expiry}</option>
                  ))}
                </Select>
                <Input value={strikeFilter} onChange={(event) => setStrikeFilter(event.target.value)} placeholder="Exact strike" />
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="max-h-[560px] overflow-auto rounded-md border border-slate-200">
              <table className="min-w-full text-sm">
                <thead className="sticky top-0 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-3 py-2">Select</th>
                    <th className="px-3 py-2">Expiry</th>
                    <th className="px-3 py-2">DTE</th>
                    <th className="px-3 py-2">Type</th>
                    <th className="px-3 py-2 text-right">Strike</th>
                    <th className="px-3 py-2">Option Symbol</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredRows.map((row) => {
                    const selected = selectedRow?.option_symbol === row.option_symbol;
                    return (
                      <tr key={row.option_symbol} className={selected ? "bg-indigo-50" : "hover:bg-slate-50"}>
                        <td className="px-3 py-2">
                          <button
                            type="button"
                            onClick={() => selectRow(row)}
                            className={`rounded-md px-3 py-1 text-xs font-medium ${selected ? "bg-indigo-600 text-white" : "border border-slate-200 bg-white text-slate-700"}`}
                          >
                            {selected ? "Selected" : "Select"}
                          </button>
                        </td>
                        <td className="px-3 py-2">{row.expiry_date}</td>
                        <td className="px-3 py-2">{row.dte}</td>
                        <td className="px-3 py-2">{row.right === "P" ? "Put" : "Call"}</td>
                        <td className="px-3 py-2 text-right">{num(row.strike, 2)}</td>
                        <td className="px-3 py-2 font-mono text-xs">{row.option_symbol}</td>
                      </tr>
                    );
                  })}
                  {!filteredRows.length ? (
                    <tr>
                      <td className="px-3 py-6 text-center text-slate-500" colSpan={6}>
                        {loadingChain ? "Loading..." : "No contracts loaded."}
                      </td>
                    </tr>
                  ) : null}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>

        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Estimator</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="rounded-md bg-slate-50 p-3 text-sm">
                <div className="text-xs uppercase text-slate-500">Selected</div>
                <div className="mt-1 break-all font-mono text-xs">{selectedRow?.option_symbol || "None"}</div>
              </div>
              <label className="text-sm">
                <span className="mb-1 block text-slate-600">Target Underlying Price</span>
                <Input type="number" min="0" step="0.01" value={targetUnderlying} onChange={(event) => setTargetUnderlying(event.target.value)} />
              </label>
              <Button onClick={estimatePrice} disabled={!selectedRow || estimating} className="w-full">
                {estimating ? "Estimating..." : "Estimate Option Price"}
              </Button>
              {estimateError ? <Alert variant="danger">{estimateError}</Alert> : null}
              {estimate ? (
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div className="rounded-md border border-slate-200 p-3">
                    <div className="text-xs uppercase text-slate-500">Limit Default</div>
                    <div className="mt-1 text-xl font-semibold">{money(estimate.estimated_price)}</div>
                  </div>
                  <div className="rounded-md border border-slate-200 p-3">
                    <div className="text-xs uppercase text-slate-500">IV</div>
                    <div className="mt-1 text-xl font-semibold">{pct(estimate.adjusted_iv)}</div>
                  </div>
                  <div>Bid: {money(estimate.quote.bid)}</div>
                  <div>Ask: {money(estimate.quote.ask)}</div>
                  <div>Mid: {money(estimate.quote.mid)}</div>
                  <div>Delta: {num(estimate.quote.delta, 3)}</div>
                  <div>Base: {money(estimate.base_case, 4)}</div>
                  <div>Conservative: {money(estimate.conservative, 4)}</div>
                  {estimate.warnings?.length ? (
                    <div className="col-span-2">
                      <Alert variant="warning">{estimate.warnings.join(" ")}</Alert>
                    </div>
                  ) : null}
                </div>
              ) : null}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Order Ticket</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <label className="text-sm">
                  <span className="mb-1 block text-slate-600">Action</span>
                  <Select value={action} onChange={(event) => setAction(event.target.value as Action)}>
                    <option value="SELL">Sell</option>
                    <option value="BUY">Buy</option>
                  </Select>
                </label>
                <label className="text-sm">
                  <span className="mb-1 block text-slate-600">Quantity</span>
                  <Input type="number" min="1" step="1" value={quantity} onChange={(event) => setQuantity(event.target.value)} />
                </label>
              </div>
              <label className="text-sm">
                <span className="mb-1 block text-slate-600">Limit Price</span>
                <Input type="number" min="0" step="0.01" value={limitPrice} onChange={(event) => setLimitPrice(event.target.value)} />
              </label>
              <div className="space-y-2 rounded-md border border-slate-200 bg-slate-50 p-3">
                <div className="flex items-center justify-between gap-3 text-sm">
                  <span className="font-medium text-slate-700">Bracket Exit</span>
                  <span className="text-slate-600">
                    {bracketExitPct}% {action === "BUY" ? "above" : "below"} entry
                  </span>
                </div>
                <input
                  type="range"
                  min="5"
                  max="100"
                  step="5"
                  value={bracketExitPct}
                  onChange={(event) => setBracketExitPct(event.target.value)}
                  className="w-full"
                />
                <div className="grid grid-cols-2 gap-3 text-xs text-slate-600">
                  <div>Entry: {money(parsePositive(limitPrice))}</div>
                  <div>Exit limit: {money(bracketExitPrice)}</div>
                </div>
              </div>
              {assignmentExposure !== null ? (
                <Alert variant="warning">Sell-put assignment exposure: {money(assignmentExposure, 0)}</Alert>
              ) : action === "SELL" && selectedRow?.right === "C" ? (
                <Alert variant="warning">Sell-call risk can be very large if uncovered. Confirm your existing position before placing.</Alert>
              ) : null}
              <Button
                variant="danger"
                onClick={() => setShowConfirm(true)}
                disabled={!selectedRow || placing || !parsePositive(limitPrice) || !parsePositive(quantity) || !bracketExitPrice}
                className="w-full"
              >
                {placing ? "Placing..." : "Place Order"}
              </Button>
              {orderResult ? (
                <Alert variant={orderResult.ok ? "success" : "danger"}>
                  {orderResult.ok
                    ? `${orderResult.message || "Order placed."}${orderResult.ib_order_id ? ` Order ID: ${orderResult.ib_order_id}` : ""}`
                    : `Order failed: ${orderResult.error || orderResult.detail || "Unknown error"}`}
                </Alert>
              ) : null}
            </CardContent>
          </Card>
        </div>
      </div>

      {showConfirm && selectedRow ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 px-4">
          <div className="w-full max-w-lg rounded-xl bg-white p-6 shadow-xl">
            <h2 className="text-lg font-semibold text-slate-900">Confirm Option Order</h2>
            <p className="mt-2 text-sm text-slate-600">Review carefully before sending this order to IB.</p>
            <div className="mt-4 rounded-md bg-slate-50 p-4 font-mono text-sm">
              {orderSummary(action, selectedRow, quantity, limitPrice)}
              <div className="mt-2">
                Bracket exit: {action === "BUY" ? "SELL" : "BUY"} {quantity || "?"} @ {money(bracketExitPrice)} GTC
                ({bracketExitPct}% {action === "BUY" ? "above" : "below"} entry)
              </div>
            </div>
            {assignmentExposure !== null ? (
              <div className="mt-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
                Assignment exposure: {money(assignmentExposure, 0)}
              </div>
            ) : null}
            <div className="mt-5 flex justify-end gap-3">
              <Button variant="secondary" onClick={() => setShowConfirm(false)} disabled={placing}>Cancel</Button>
              <Button variant="danger" onClick={placeOrder} disabled={placing}>{placing ? "Sending..." : "Send to IB"}</Button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
