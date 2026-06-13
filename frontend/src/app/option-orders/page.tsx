"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import Select from "../components/ui/Select";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Right = "P" | "C";
type Action = "SELL" | "BUY";
type LiquiditySortKey = "spread" | "volume";
type SortDirection = "asc" | "desc";

interface ChainRow {
  symbol: string;
  option_symbol: string;
  expiry: string;
  expiry_date: string;
  dte: number;
  right: Right;
  strike: number;
  delayed_quote: DelayedQuote | null;
}

interface DelayedQuote {
  bid: number | null;
  ask: number | null;
  mid: number | null;
  spread_pct: number | null;
  volume: number | null;
  iv: number | null;
  observation_date: string;
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
  iv_source: string;
  iv_clues: {
    ib_contract_iv: number | null;
    ib_contract_market_data_type: number | null;
    delayed_quote_iv: number | null;
    market_implied_iv: number | null;
    nearby_contract_iv: number | null;
    delayed_atm_iv: number | null;
    underlying_implied_iv: number | null;
    underlying_historical_iv: number | null;
    underlying_iv_adjustment: number | null;
    timestamps_match_for_market_iv: boolean;
  };
  skew_adjustment: number;
  directional_iv_adjustment: number;
  warnings?: string[];
  delayed_quote: DelayedQuote | null;
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

function spreadPct(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return `${Number(value).toFixed(2)}%`;
}

function parsePositive(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function formatPriceInput(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed.toFixed(2) : value;
}

function orderSummary(action: Action, row: ChainRow | null, qty: string, limitPrice: string) {
  if (!row) return "";
  return `${action} ${qty || "?"} ${row.option_symbol} @ ${limitPrice || "?"} limit`;
}

export default function OptionOrdersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const prefillStarted = useRef(false);
  const [symbol, setSymbol] = useState("AVGO");
  const [right, setRight] = useState<Right>("P");
  const [strikeWindowPct, setStrikeWindowPct] = useState("0.25");
  const [expirations, setExpirations] = useState<ExpirationRow[]>([]);
  const [selectedExpiry, setSelectedExpiry] = useState("");
  const [chain, setChain] = useState<ChainResponse | null>(null);
  const [selectedKey, setSelectedKey] = useState("");
  const [expiryFilter, setExpiryFilter] = useState("");
  const [strikeFilter, setStrikeFilter] = useState("");
  const [liquiditySort, setLiquiditySort] = useState<{
    key: LiquiditySortKey;
    direction: SortDirection;
  } | null>(null);
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

  useEffect(() => {
    if (!baseUrl || prefillStarted.current) return;
    const params = new URLSearchParams(window.location.search);
    if (params.get("auto") !== "1") return;

    const requestedSymbol = params.get("symbol")?.trim().toUpperCase();
    const requestedRight = params.get("right");
    const requestedAction = params.get("action");
    const requestedTarget = Number(params.get("target"));
    if (
      !requestedSymbol
      || (requestedRight !== "P" && requestedRight !== "C")
      || (requestedAction !== "SELL" && requestedAction !== "BUY")
      || !Number.isFinite(requestedTarget)
      || requestedTarget <= 0
    ) {
      setError("Invalid option-order prefill link.");
      return;
    }

    prefillStarted.current = true;
    const runPrefill = async () => {
      setSymbol(requestedSymbol);
      setRight(requestedRight);
      setAction(requestedAction);
      setTargetUnderlying(requestedTarget.toFixed(2));
      setLoadingChain(true);
      setError("");
      setEstimateError("");
      setOrderResult(null);
      setEstimate(null);
      setSelectedKey("");
      setChain(null);

      try {
        const expirationParams = new URLSearchParams({ symbol: requestedSymbol });
        const expirationResponse = await authenticatedFetch(
          `${baseUrl}/api/option-orders/expirations?${expirationParams.toString()}`,
          { cache: "no-store" },
        );
        const expirationData: ExpirationsResponse = await expirationResponse.json();
        if (!expirationResponse.ok) {
          throw new Error((expirationData as any)?.detail || `HTTP ${expirationResponse.status}`);
        }

        const availableExpirations = Array.isArray(expirationData.expirations)
          ? expirationData.expirations
          : [];
        setExpirations(availableExpirations);
        const chosenExpiry = [...availableExpirations]
          .filter((item) => item.dte >= 15 && item.dte <= 21)
          .sort((left, right) => Math.abs(left.dte - 18) - Math.abs(right.dte - 18) || left.dte - right.dte)[0];
        if (!chosenExpiry) {
          throw new Error(`No ${requestedSymbol} expiry is available between 15 and 21 DTE.`);
        }
        setSelectedExpiry(chosenExpiry.expiry);

        const chainParams = new URLSearchParams({
          symbol: requestedSymbol,
          right: requestedRight,
          expiry: chosenExpiry.expiry,
          max_expiries: "1",
          strike_window_pct: "0.25",
        });
        const chainResponse = await authenticatedFetch(
          `${baseUrl}/api/option-orders/chain?${chainParams.toString()}`,
          { cache: "no-store" },
        );
        const chainData: ChainResponse = await chainResponse.json();
        if (!chainResponse.ok) {
          throw new Error((chainData as any)?.detail || `HTTP ${chainResponse.status}`);
        }
        setChain(chainData);
        setExpiryFilter(chosenExpiry.expiry);

        const chosenContract = [...(chainData.rows || [])].sort((left, right) => {
          const leftVolume = Number(left.delayed_quote?.volume);
          const rightVolume = Number(right.delayed_quote?.volume);
          const safeLeftVolume = Number.isFinite(leftVolume) ? leftVolume : -1;
          const safeRightVolume = Number.isFinite(rightVolume) ? rightVolume : -1;
          return safeRightVolume - safeLeftVolume;
        })[0];
        if (!chosenContract) {
          throw new Error(`No ${requestedRight === "P" ? "put" : "call"} contracts were returned for ${chosenExpiry.expiry_date}.`);
        }
        setSelectedKey(chosenContract.option_symbol);

        setEstimating(true);
        const estimateResponse = await authenticatedFetch(`${baseUrl}/api/option-orders/estimate`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            symbol: chosenContract.symbol,
            expiry: chosenContract.expiry,
            strike: chosenContract.strike,
            right: chosenContract.right,
            target_underlying_price: requestedTarget,
          }),
        });
        const estimateData: EstimateResponse = await estimateResponse.json();
        if (!estimateResponse.ok) {
          throw new Error((estimateData as any)?.detail || `HTTP ${estimateResponse.status}`);
        }
        setEstimate(estimateData);
        setLimitPrice(Number(estimateData.estimated_price).toFixed(2));
      } catch (exc: any) {
        setError(exc?.message || String(exc));
      } finally {
        setLoadingChain(false);
        setEstimating(false);
      }
    };

    void runPrefill();
  }, [baseUrl]);

  const selectedRow = useMemo(() => {
    if (!chain || !selectedKey) return null;
    return chain.rows.find((row) => row.option_symbol === selectedKey) || null;
  }, [chain, selectedKey]);

  const filteredRows = useMemo(() => {
    const strikeSearch = Number(strikeFilter);
    const rows = (chain?.rows || [])
      .filter((row) => !expiryFilter || row.expiry === expiryFilter)
      .filter((row) => !strikeFilter || !Number.isFinite(strikeSearch) || Math.abs(row.strike - strikeSearch) < 0.0001);

    if (liquiditySort) {
      rows.sort((left, right) => {
        const leftValue = liquiditySort.key === "spread"
          ? left.delayed_quote?.spread_pct
          : left.delayed_quote?.volume;
        const rightValue = liquiditySort.key === "spread"
          ? right.delayed_quote?.spread_pct
          : right.delayed_quote?.volume;
        const leftMissing = leftValue === null || leftValue === undefined || !Number.isFinite(Number(leftValue));
        const rightMissing = rightValue === null || rightValue === undefined || !Number.isFinite(Number(rightValue));
        if (leftMissing && rightMissing) return left.strike - right.strike;
        if (leftMissing) return 1;
        if (rightMissing) return -1;
        const comparison = Number(leftValue) - Number(rightValue);
        return liquiditySort.direction === "asc" ? comparison : -comparison;
      });
    }

    return rows.slice(0, 600);
  }, [chain, expiryFilter, liquiditySort, strikeFilter]);

  const toggleLiquiditySort = (key: LiquiditySortKey) => {
    setLiquiditySort((current) => {
      if (current?.key === key) {
        return { key, direction: current.direction === "asc" ? "desc" : "asc" };
      }
      return { key, direction: key === "spread" ? "asc" : "desc" };
    });
  };

  const sortIndicator = (key: LiquiditySortKey) => {
    if (liquiditySort?.key !== key) return "";
    return liquiditySort.direction === "asc" ? " ▲" : " ▼";
  };

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
      setTargetUnderlying(
        data?.underlying?.reference_price
          ? Number(data.underlying.reference_price).toFixed(2)
          : "",
      );
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
      setTargetUnderlying(
        data?.underlying?.reference_price
          ? Number(data.underlying.reference_price).toFixed(2)
          : "",
      );
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
                  <th className="px-3 py-2 text-right">Bid</th>
                  <th className="px-3 py-2 text-right">Ask</th>
                  <th className="px-3 py-2 text-right">
                    <button
                      type="button"
                      onClick={() => toggleLiquiditySort("spread")}
                      className="font-semibold hover:text-slate-900"
                      title="Sort by bid-ask spread"
                    >
                      Spread{sortIndicator("spread")}
                    </button>
                  </th>
                  <th className="px-3 py-2 text-right">
                    <button
                      type="button"
                      onClick={() => toggleLiquiditySort("volume")}
                      className="font-semibold hover:text-slate-900"
                      title="Sort by volume"
                    >
                      Volume{sortIndicator("volume")}
                    </button>
                  </th>
                  <th className="px-3 py-2">Option Symbol</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredRows.map((row) => {
                    const selected = selectedRow?.option_symbol === row.option_symbol;
                    const illiquid = row.delayed_quote?.spread_pct !== null
                      && row.delayed_quote?.spread_pct !== undefined
                      && row.delayed_quote.spread_pct > 3;
                    const liquid = row.delayed_quote?.spread_pct !== null
                      && row.delayed_quote?.spread_pct !== undefined
                      && row.delayed_quote.spread_pct < 3;
                    return (
                      <tr
                        key={row.option_symbol}
                        className={`${illiquid ? "bg-pink-100 hover:bg-pink-200" : liquid ? "bg-emerald-50 hover:bg-emerald-100" : "hover:bg-slate-50"} ${selected ? "outline outline-2 outline-inset outline-indigo-500" : ""}`}
                      >
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
                        <td className="px-3 py-2 text-right">{money(row.delayed_quote?.bid)}</td>
                        <td className="px-3 py-2 text-right">{money(row.delayed_quote?.ask)}</td>
                        <td className={`px-3 py-2 text-right ${illiquid ? "font-semibold text-pink-800" : ""}`}>
                          {spreadPct(row.delayed_quote?.spread_pct)}
                        </td>
                        <td className="px-3 py-2 text-right">{num(row.delayed_quote?.volume, 0)}</td>
                        <td className="px-3 py-2 font-mono text-xs">{row.option_symbol}</td>
                      </tr>
                    );
                  })}
                  {!filteredRows.length ? (
                    <tr>
                      <td className="px-3 py-6 text-center text-slate-500" colSpan={10}>
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
                {selectedRow?.delayed_quote ? (
                  <div className="mt-2 grid grid-cols-2 gap-x-3 gap-y-1 text-xs text-slate-600">
                    <div>Bid: {money(selectedRow.delayed_quote.bid)}</div>
                    <div>Ask: {money(selectedRow.delayed_quote.ask)}</div>
                    <div>Mid: {money(selectedRow.delayed_quote.mid)}</div>
                    <div className={Number(selectedRow.delayed_quote.spread_pct) > 3 ? "font-semibold text-pink-700" : Number(selectedRow.delayed_quote.spread_pct) < 3 ? "font-semibold text-emerald-700" : ""}>
                      Spread: {spreadPct(selectedRow.delayed_quote.spread_pct)}
                    </div>
                    <div>Volume: {num(selectedRow.delayed_quote.volume, 0)}</div>
                    <div>Quote date: {selectedRow.delayed_quote.observation_date || "n/a"}</div>
                  </div>
                ) : null}
              </div>
              <label className="text-sm">
                <span className="mb-1 block text-slate-600">Target Underlying Price</span>
                <Input
                  type="number"
                  min="0"
                  step="0.01"
                  value={targetUnderlying}
                  onChange={(event) => setTargetUnderlying(event.target.value)}
                  onBlur={() => setTargetUnderlying((value) => formatPriceInput(value))}
                />
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
                    <div className="mt-1 text-xs text-slate-500">{estimate.iv_source}</div>
                  </div>
                  <div>Bid: {money(estimate.delayed_quote?.bid ?? estimate.quote.bid)}</div>
                  <div>Ask: {money(estimate.delayed_quote?.ask ?? estimate.quote.ask)}</div>
                  <div>Mid: {money(estimate.delayed_quote?.mid ?? estimate.quote.mid)}</div>
                  <div className={Number(estimate.delayed_quote?.spread_pct) > 3 ? "font-semibold text-pink-700" : Number(estimate.delayed_quote?.spread_pct) < 3 ? "font-semibold text-emerald-700" : ""}>
                    Spread: {spreadPct(estimate.delayed_quote?.spread_pct)}
                  </div>
                  <div>Volume: {num(estimate.delayed_quote?.volume, 0)}</div>
                  <div>Delta: {num(estimate.quote.delta, 3)}</div>
                  <div>Base: {money(estimate.base_case, 4)}</div>
                  <div>Conservative: {money(estimate.conservative, 4)}</div>
                  <div className="col-span-2 rounded-md border border-slate-200 bg-slate-50 p-3 text-xs text-slate-600">
                    <div className="mb-2 font-semibold text-slate-700">IV evidence</div>
                    <div className="grid grid-cols-2 gap-x-3 gap-y-1">
                      <div>
                        IB contract: {pct(estimate.iv_clues.ib_contract_iv)}
                        {estimate.iv_clues.ib_contract_market_data_type
                          ? ` (type ${estimate.iv_clues.ib_contract_market_data_type})`
                          : ""}
                      </div>
                      <div>Delayed quote: {pct(estimate.iv_clues.delayed_quote_iv)}</div>
                      <div>
                        Live midpoint: {pct(estimate.iv_clues.market_implied_iv)}
                        {!estimate.iv_clues.timestamps_match_for_market_iv ? " (timestamp mismatch)" : ""}
                      </div>
                      <div>Nearby contract: {pct(estimate.iv_clues.nearby_contract_iv)}</div>
                      <div>Delayed near-ATM: {pct(estimate.iv_clues.delayed_atm_iv)}</div>
                      <div>Underlying implied: {pct(estimate.iv_clues.underlying_implied_iv)}</div>
                      <div>Underlying historical: {pct(estimate.iv_clues.underlying_historical_iv)}</div>
                      <div>Underlying adjustment: {pct(estimate.iv_clues.underlying_iv_adjustment)}</div>
                    </div>
                  </div>
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
                Entry: {action} {quantity || "?"} @ {money(parsePositive(limitPrice))} DAY
              </div>
              <div className="mt-1 text-sm text-slate-600">
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
