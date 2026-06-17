"use client";

import { Fragment, useEffect, useMemo, useRef, useState } from "react";

import { authenticatedFetch } from "../utils/authenticatedFetch";

type OptionRecommendationRow = Record<string, unknown>;

const HIDDEN_GRID_COLUMNS = new Set([
  "Allocation",
  "NormalizedRank",
  "OptionRankForTicker",
  "IV_Pct",
  "Optimistic",
  "AnnualizedYield",
  "BufferPct",
  "PremiumMid",
  "RecommendationID",
  "ObservationDate",
]);

interface QuoteResult {
  ok: boolean;
  stock_code: string;
  last: number | null;
  close: number | null;
  bid: number | null;
  ask: number | null;
  mid: number | null;
  source?: string;
  error?: string;
}

interface OrderResult {
  ok: boolean;
  message?: string;
  ib_order_id?: number;
  warnings?: string[];
  parent?: {
    ib_order_id: number | null;
    action: string;
    qty: number;
    limit_price: number;
    tif: string;
  };
  exit?: {
    ib_order_id: number | null;
    action: string;
    qty: number;
    limit_price: number;
    tif: string;
  };
  orders?: Array<{
    exchange: string;
    stock_code: string;
    qty: number;
    limit_price: number;
    side: string;
    ib_order_id: number;
  }>;
  error?: string;
}

interface RepriceSTOResult {
  ok: boolean;
  sto_limit_price: number;
  adjusted_iv?: number;
  error?: string;
}

function formatCellValue(key: string, value: unknown): string {
  if (value === null || value === undefined) return "";

  if (typeof value === "number") {
    const lowerKey = key.toLowerCase();
    const fractionDigits =
      lowerKey.includes("pct") || lowerKey.includes("yield") || lowerKey.includes("decimal") || lowerKey.includes("allocation")
        ? 4
        : lowerKey.includes("price") || lowerKey.includes("strike") || lowerKey.includes("entry") || lowerKey.includes("basecase") || lowerKey.includes("optimistic")
          ? 2
          : 0;
    return value.toLocaleString(undefined, {
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    });
  }

  if (typeof value === "string") {
    if (/^\d{4}-\d{2}-\d{2}(T.*)?$/.test(value)) {
      return value.slice(0, 10);
    }
    return value;
  }

  return String(value);
}

function shiftBusinessDay(isoDate: string, direction: -1 | 1): string {
  const next = new Date(`${isoDate}T00:00:00`);
  next.setDate(next.getDate() + direction);
  while (next.getDay() === 0 || next.getDay() === 6) {
    next.setDate(next.getDate() + direction);
  }
  return next.toISOString().slice(0, 10);
}

function normalizeUsSymbol(symbol: string): string {
  const s = (symbol || "").trim().toUpperCase();
  if (!s) return s;
  if (s.includes(".")) return s;
  return `${s}.US`;
}

function roundCurrency(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function getTargetPriceRaw(row: OptionRecommendationRow): unknown {
  return row["TargetPrice"] ?? row["Target_Price"] ?? row["TargetUnderlying"] ?? row["target_underlying"];
}

function getStoLimitPriceRaw(row: OptionRecommendationRow): unknown {
  return row["STOLimitPrice"] ?? row["STO_LimitPrice"] ?? row["LimitPrice"] ?? row["Price"] ?? row["STOPrice"];
}

function parsePriceInput(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string") {
    const normalized = value.trim().replace(/[$,]/g, "");
    if (!normalized) return null;
    const parsed = Number.parseFloat(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function formatPriceInput(value: unknown): string {
  const parsed = parsePriceInput(value);
  return parsed == null ? "" : parsed.toFixed(2);
}

export default function OptionRecommendationsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const [tradingDate, setTradingDate] = useState<string>("");
  const [availableDates, setAvailableDates] = useState<string[]>([]);
  const [rows, setRows] = useState<OptionRecommendationRow[]>([]);
  const [loadingDates, setLoadingDates] = useState(false);
  const [loadingRows, setLoadingRows] = useState(false);
  const [error, setError] = useState("");

  // State for IB operations
  const [quoteLoading, setQuoteLoading] = useState<Record<number, boolean>>({});
  const [quoteResults, setQuoteResults] = useState<Record<number, QuoteResult>>({});
  const [orderLoading, setOrderLoading] = useState<Record<number, boolean>>({});
  const [orderResults, setOrderResults] = useState<Record<number, OrderResult>>({});
  const [stoPriceInputs, setStoPriceInputs] = useState<Record<number, string>>({});
  const [targetPriceInputs, setTargetPriceInputs] = useState<Record<number, string>>({});
  const [repriceLoading, setRepriceLoading] = useState<Record<number, boolean>>({});
  const [repriceErrors, setRepriceErrors] = useState<Record<number, string>>({});
  const [collapsedStocks, setCollapsedStocks] = useState<Record<string, boolean>>({});
  const [collapsedOptions, setCollapsedOptions] = useState<Record<string, boolean>>({});
  const repriceTimers = useRef<Record<number, ReturnType<typeof setTimeout>>>({});
  const repriceSequence = useRef<Record<number, number>>({});

  useEffect(() => {
    let cancelled = false;

    async function loadDates() {
      if (!baseUrl) return;
      setLoadingDates(true);
      setError("");
      try {
        const response = await authenticatedFetch(`${baseUrl}/api/option-recommendations/dates`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (cancelled) return;
        const normalized = Array.isArray(data) ? data.filter((value): value is string => typeof value === "string") : [];
        setAvailableDates(normalized);
        if (normalized.length > 0) {
          setTradingDate((current) => current || normalized[0]);
        }
      } catch (exc) {
        if (!cancelled) {
          setError(exc instanceof Error ? exc.message : "Failed to load trading dates");
        }
      } finally {
        if (!cancelled) {
          setLoadingDates(false);
        }
      }
    }

    loadDates();

    return () => {
      cancelled = true;
    };
  }, [baseUrl]);

  useEffect(() => {
    let cancelled = false;

    async function loadRows() {
      if (!baseUrl || !tradingDate) return;
      setLoadingRows(true);
      setError("");
      try {
        const response = await authenticatedFetch(
          `${baseUrl}/api/option-recommendations?trading_date=${encodeURIComponent(tradingDate)}`
        );
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        if (cancelled) return;
        setRows(Array.isArray(data) ? data : []);
      } catch (exc) {
        if (!cancelled) {
          setRows([]);
          setError(exc instanceof Error ? exc.message : "Failed to load option recommendations");
        }
      } finally {
        if (!cancelled) {
          setLoadingRows(false);
        }
      }
    }

    loadRows();

    return () => {
      cancelled = true;
    };
  }, [baseUrl, tradingDate]);

  useEffect(() => {
    const nextInputs: Record<number, string> = {};
    const nextTargetInputs: Record<number, string> = {};
    rows.forEach((row, index) => {
      const targetPrice = formatPriceInput(getTargetPriceRaw(row));
      nextTargetInputs[index] = targetPrice;
      nextInputs[index] = formatPriceInput(getStoLimitPriceRaw(row));
    });
    Object.values(repriceTimers.current).forEach((timer) => clearTimeout(timer));
    repriceTimers.current = {};
    repriceSequence.current = {};
    setTargetPriceInputs(nextTargetInputs);
    setStoPriceInputs(nextInputs);
    setRepriceLoading({});
    setRepriceErrors({});
    setOrderResults({});
    setQuoteResults({});
    setCollapsedStocks({});
    setCollapsedOptions({});
  }, [rows]);

  useEffect(() => {
    return () => {
      Object.values(repriceTimers.current).forEach((timer) => clearTimeout(timer));
    };
  }, []);

  const columns = useMemo(() => {
    if (!rows[0]) return [];
    return Object.keys(rows[0]).filter((column) => !HIDDEN_GRID_COLUMNS.has(column));
  }, [rows]);

  const summary = useMemo(() => {
    const tickerSet = new Set<string>();
    let annualizedYieldTotal = 0;
    let annualizedYieldCount = 0;

    for (const row of rows) {
      const ticker = row["Ticker"];
      if (typeof ticker === "string" && ticker) {
        tickerSet.add(ticker);
      }

      const annualizedYield = row["AnnualizedYield"];
      if (typeof annualizedYield === "number" && Number.isFinite(annualizedYield)) {
        annualizedYieldTotal += annualizedYield;
        annualizedYieldCount += 1;
      }
    }

    return {
      totalRows: rows.length,
      tickers: tickerSet.size,
      averageAnnualizedYield:
        annualizedYieldCount > 0 ? annualizedYieldTotal / annualizedYieldCount : null,
    };
  }, [rows]);

  const groupedRows = useMemo(() => {
    const stockGroups: Array<{
      ticker: string;
      rowCount: number;
      options: Array<{
        optionSymbol: string;
        rows: Array<{ row: OptionRecommendationRow; index: number }>;
      }>;
    }> = [];
    const stockIndex = new Map<string, number>();

    rows.forEach((row, index) => {
      const ticker = typeof row["Ticker"] === "string" && row["Ticker"] ? row["Ticker"] : "Unknown";
      const optionSymbol =
        typeof row["OptionSymbol"] === "string" && row["OptionSymbol"] ? row["OptionSymbol"] : "Unknown option";

      let stockGroup = stockGroups[stockIndex.get(ticker) ?? -1];
      if (!stockGroup) {
        stockGroup = { ticker, rowCount: 0, options: [] };
        stockIndex.set(ticker, stockGroups.length);
        stockGroups.push(stockGroup);
      }

      stockGroup.rowCount += 1;
      let optionGroup = stockGroup.options.find((group) => group.optionSymbol === optionSymbol);
      if (!optionGroup) {
        optionGroup = { optionSymbol, rows: [] };
        stockGroup.options.push(optionGroup);
      }

      optionGroup.rows.push({ row, index });
    });

    return stockGroups;
  }, [rows]);

  const minDate = availableDates.length > 0 ? availableDates[availableDates.length - 1] : undefined;
  const maxDate = availableDates.length > 0 ? availableDates[0] : undefined;

  const requestRepriceSTO = async (rowIndex: number, row: OptionRecommendationRow, targetPriceInput: string) => {
    if (!baseUrl) return;

    const recommendationId = parsePriceInput(row["RecommendationID"]);
    const targetPrice = parsePriceInput(targetPriceInput);
    if (!recommendationId || !targetPrice || targetPrice <= 0) {
      setStoPriceInputs((prev) => ({ ...prev, [rowIndex]: "" }));
      setRepriceLoading((prev) => ({ ...prev, [rowIndex]: false }));
      return;
    }

    const sequence = (repriceSequence.current[rowIndex] ?? 0) + 1;
    repriceSequence.current[rowIndex] = sequence;
    setRepriceLoading((prev) => ({ ...prev, [rowIndex]: true }));
    setRepriceErrors((prev) => {
      const next = { ...prev };
      delete next[rowIndex];
      return next;
    });

    try {
      const response = await authenticatedFetch(`${baseUrl}/api/option-recommendations/reprice-sto`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          recommendation_id: Math.trunc(recommendationId),
          target_price: targetPrice,
        }),
      });
      const data: RepriceSTOResult & { detail?: string } = await response.json();
      if (repriceSequence.current[rowIndex] !== sequence) return;

      if (!response.ok || typeof data.sto_limit_price !== "number") {
        throw new Error(data.detail || data.error || "Failed to reprice STO limit");
      }

      setStoPriceInputs((prev) => ({ ...prev, [rowIndex]: data.sto_limit_price.toFixed(2) }));
    } catch (err: unknown) {
      if (repriceSequence.current[rowIndex] !== sequence) return;
      setRepriceErrors((prev) => ({
        ...prev,
        [rowIndex]: err instanceof Error ? err.message : "Failed to reprice STO limit",
      }));
    } finally {
      if (repriceSequence.current[rowIndex] === sequence) {
        setRepriceLoading((prev) => ({ ...prev, [rowIndex]: false }));
      }
    }
  };

  const handleTargetPriceChange = (rowIndex: number, row: OptionRecommendationRow, value: string) => {
    setTargetPriceInputs((prev) => ({ ...prev, [rowIndex]: value }));
    setRepriceErrors((prev) => {
      const next = { ...prev };
      delete next[rowIndex];
      return next;
    });

    if (repriceTimers.current[rowIndex]) {
      clearTimeout(repriceTimers.current[rowIndex]);
    }

    if (!parsePriceInput(value)) {
      setStoPriceInputs((prev) => ({ ...prev, [rowIndex]: "" }));
      setRepriceLoading((prev) => ({ ...prev, [rowIndex]: false }));
      return;
    }

    setRepriceLoading((prev) => ({ ...prev, [rowIndex]: true }));
    repriceTimers.current[rowIndex] = setTimeout(() => {
      void requestRepriceSTO(rowIndex, row, value);
    }, 350);
  };

  const handleCheckLivePrice = async (rowIndex: number, row: OptionRecommendationRow) => {
    if (!baseUrl) return;

    // Debug: Log all available columns and their values
    console.log("Row data:", row);
    console.log("Available columns:", Object.keys(row));

    // For options, use OptionSymbol instead of Ticker
    const optionSymbol = row["OptionSymbol"];
    if (!optionSymbol || typeof optionSymbol !== "string") {
      setQuoteResults((prev) => ({
        ...prev,
        [rowIndex]: {
          ok: false,
          stock_code: "",
          error: `Missing option symbol. Available keys: ${Object.keys(row).join(", ")}`,
          last: null,
          close: null,
          bid: null,
          ask: null,
          mid: null,
        },
      }));
      return;
    }

    setQuoteLoading((prev) => ({ ...prev, [rowIndex]: true }));
    setQuoteResults((prev) => {
      const newResults = { ...prev };
      delete newResults[rowIndex];
      return newResults;
    });

    try {
      console.log("Fetching option quote for:", optionSymbol);
      const response = await authenticatedFetch(
        `${baseUrl}/api/ib/option-quote?option_symbol=${encodeURIComponent(optionSymbol)}`
      );
      const data = await response.json();
      console.log("Option quote response:", data);

      setQuoteResults((prev) => ({
        ...prev,
        [rowIndex]: data,
      }));
    } catch (err: unknown) {
      setQuoteResults((prev) => ({
        ...prev,
        [rowIndex]: {
          ok: false,
          stock_code: optionSymbol,
          error: err instanceof Error ? err.message : "Failed to fetch option quote",
          last: null,
          close: null,
          bid: null,
          ask: null,
          mid: null,
        },
      }));
    } finally {
      setQuoteLoading((prev) => ({ ...prev, [rowIndex]: false }));
    }
  };

  const handlePlaceSTOOrder = async (rowIndex: number, row: OptionRecommendationRow) => {
    if (!baseUrl) return;

    // Debug: Log all available columns and their values
    console.log("Row data for order:", row);
    console.log("Available columns:", Object.keys(row));

    const optionSymbol = row["OptionSymbol"];
    const defaultStoLimitPriceRaw = getStoLimitPriceRaw(row);
    const stoLimitPriceInput = stoPriceInputs[rowIndex] ?? formatPriceInput(defaultStoLimitPriceRaw);
    const stolimitPrice = parsePriceInput(stoLimitPriceInput);

    if (!optionSymbol || typeof optionSymbol !== "string") {
      setOrderResults((prev) => ({
        ...prev,
        [rowIndex]: {
          ok: false,
          error: `Missing option symbol. Available keys: ${Object.keys(row).join(", ")}`,
        },
      }));
      return;
    }

    if (!stolimitPrice || isNaN(stolimitPrice) || stolimitPrice <= 0) {
      setOrderResults((prev) => ({
        ...prev,
        [rowIndex]: {
          ok: false,
          error: `Invalid STO price: ${stoLimitPriceInput || "blank"}. Default STOLimitPrice: ${String(defaultStoLimitPriceRaw ?? "N/A")}. Found columns: ${Object.keys(row).filter(k => k.toLowerCase().includes('price') || k.toLowerCase().includes('limit')).join(", ")}`,
        },
      }));
      return;
    }

    // Always place 1 contract as a bracket: DAY sell-to-open entry and GTC
    // buy-to-close exit at 70% of the entry credit.
    const quantity = 1;
    const bracketExitPrice = roundCurrency(stolimitPrice * 0.7);

    setOrderLoading((prev) => ({ ...prev, [rowIndex]: true }));
    setOrderResults((prev) => {
      const newResults = { ...prev };
      delete newResults[rowIndex];
      return newResults;
    });

    try {
      console.log("Placing option bracket order:", { optionSymbol, quantity, stolimitPrice, bracketExitPrice });
      const response = await authenticatedFetch(`${baseUrl}/api/ib/place-option-order`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          option_symbol: optionSymbol,
          quantity: quantity,
          action: "SELL",
          limit_price: stolimitPrice,
          bracket_exit_price: bracketExitPrice,
          parent_tif: "DAY",
          bracket_exit_tif: "GTC",
        }),
      });

      const data = await response.json();
      console.log("Order placement response:", data);

      if (!response.ok) {
        const errDetail = typeof data?.detail === "string" ? data.detail : "Order placement failed";
        setOrderResults((prev) => ({
          ...prev,
          [rowIndex]: {
            ok: false,
            error: errDetail,
          },
        }));
      } else {
        setOrderResults((prev) => ({
          ...prev,
          [rowIndex]: {
            ok: true,
            message: data.message,
            ib_order_id: data.ib_order_id,
            parent: data.parent,
            exit: data.exit,
            warnings: Array.isArray(data.warnings) ? data.warnings : undefined,
            orders: data.orders,
          },
        }));
      }
    } catch (err: unknown) {
      setOrderResults((prev) => ({
        ...prev,
        [rowIndex]: {
          ok: false,
          error: err instanceof Error ? err.message : "Failed to place order",
        },
      }));
    } finally {
      setOrderLoading((prev) => ({ ...prev, [rowIndex]: false }));
    }
  };

  return (
    <div className="min-h-screen text-slate-800">
      <div className="w-full max-w-none px-4 py-10 sm:px-6">
        <div className="mb-6">
          <h1 className="bg-gradient-to-r from-emerald-500 to-blue-600 bg-clip-text text-3xl font-semibold text-transparent sm:text-4xl">
            Option Recommendations
          </h1>
          <p className="mt-2 text-sm text-slate-600">
            Trading recommendations from <code>[Analysis].[v_CSPPriceLadder]</code>, filtered by selected trading date and capped at four options per ticker.
          </p>
        </div>

        <div className="mb-6 rounded-lg border border-slate-200 bg-white p-5">
          <div className="grid gap-4 lg:grid-cols-[minmax(320px,420px)_repeat(3,minmax(120px,1fr))]">
            <div>
              <label className="mb-1 block text-sm text-slate-600">Trading Date</label>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  aria-label="Previous business day"
                  onClick={() => setTradingDate((current) => (current ? shiftBusinessDay(current, -1) : current))}
                  disabled={!tradingDate}
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm hover:bg-emerald-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
{"<"}
                </button>
                <input
                  type="date"
                  value={tradingDate}
                  min={minDate}
                  max={maxDate}
                  onChange={(e) => setTradingDate(e.target.value)}
                  className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:border-emerald-400/40 focus:outline-none focus:ring-2 focus:ring-emerald-400/40"
                />
                <button
                  type="button"
                  aria-label="Next business day"
                  onClick={() => setTradingDate((current) => (current ? shiftBusinessDay(current, 1) : current))}
                  disabled={!tradingDate}
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm hover:bg-emerald-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
{">"}
                </button>
              </div>
              {loadingDates && <p className="mt-2 text-xs text-slate-500">Loading available dates...</p>}
            </div>

            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
              <div className="text-xs uppercase tracking-wide text-slate-500">Rows</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">{summary.totalRows.toLocaleString()}</div>
            </div>

            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
              <div className="text-xs uppercase tracking-wide text-slate-500">Tickers</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">{summary.tickers.toLocaleString()}</div>
            </div>

            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
              <div className="text-xs uppercase tracking-wide text-slate-500">Avg Yield</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">
                {summary.averageAnnualizedYield == null ? "N/A" : summary.averageAnnualizedYield.toFixed(4)}
              </div>
            </div>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            Error: {error}
          </div>
        )}

        <div className="relative overflow-x-auto rounded-lg border border-slate-200 bg-white">
          {loadingRows && (
            <div className="absolute inset-0 z-10 flex items-center justify-center bg-white/60 backdrop-blur-sm">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-emerald-300/40 border-t-emerald-500" />
            </div>
          )}

          <div className="border-b border-slate-200 px-6 py-4">
            <div className="text-sm font-medium text-slate-900">Results</div>
            <div className="mt-1 text-xs text-slate-500">
              Query: <code>SELECT * FROM [Analysis].[v_CSPPriceLadder] WHERE TradingDate = '{tradingDate || "YYYY-MM-DD"}' AND OptionRankForTicker &lt;= 4 ORDER BY Ticker, OptionSymbol, STOLimitPrice</code>
            </div>
          </div>

          {rows.length === 0 ? (
            <div className="px-6 py-10 text-center text-slate-500">
              {loadingRows ? "Loading..." : "No data found for the selected date."}
            </div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 border-b border-slate-200 bg-white text-[11px] uppercase tracking-wide text-slate-600">
                <tr>
                  {columns.map((column) => (
                    <th key={column} className="whitespace-nowrap px-3 py-3 text-left font-medium">
                      {column}
                    </th>
                  ))}
                  <th className="whitespace-nowrap px-3 py-3 text-left font-medium">Actions</th>
                </tr>
              </thead>
              <tbody>
                {groupedRows.map((stockGroup) => {
                  const stockCollapsed = Boolean(collapsedStocks[stockGroup.ticker]);
                  return (
                    <Fragment key={stockGroup.ticker}>
                      <tr className="border-b border-slate-200 bg-slate-100">
                        <td colSpan={columns.length + 1} className="px-3 py-2">
                          <button
                            type="button"
                            aria-expanded={!stockCollapsed}
                            onClick={() =>
                              setCollapsedStocks((prev) => ({
                                ...prev,
                                [stockGroup.ticker]: !prev[stockGroup.ticker],
                              }))
                            }
                            className="flex w-full items-center gap-2 text-left text-sm font-semibold text-slate-800"
                          >
                            <span className="inline-flex h-5 w-5 items-center justify-center rounded border border-slate-300 bg-white text-xs">
                              {stockCollapsed ? "+" : "-"}
                            </span>
                            <span>{stockGroup.ticker}</span>
                            <span className="text-xs font-normal text-slate-500">
                              {stockGroup.options.length} options, {stockGroup.rowCount} rows
                            </span>
                          </button>
                        </td>
                      </tr>

                      {!stockCollapsed &&
                        stockGroup.options.map((optionGroup) => {
                          const optionKey = `${stockGroup.ticker}|${optionGroup.optionSymbol}`;
                          const optionCollapsed = Boolean(collapsedOptions[optionKey]);
                          return (
                            <Fragment key={optionKey}>
                              <tr className="border-b border-slate-100 bg-slate-50">
                                <td colSpan={columns.length + 1} className="px-3 py-2">
                                  <button
                                    type="button"
                                    aria-expanded={!optionCollapsed}
                                    onClick={() =>
                                      setCollapsedOptions((prev) => ({
                                        ...prev,
                                        [optionKey]: !prev[optionKey],
                                      }))
                                    }
                                    className="flex w-full items-center gap-2 pl-6 text-left text-xs font-semibold text-slate-700"
                                  >
                                    <span className="inline-flex h-5 w-5 items-center justify-center rounded border border-slate-300 bg-white text-xs">
                                      {optionCollapsed ? "+" : "-"}
                                    </span>
                                    <span>{optionGroup.optionSymbol}</span>
                                    <span className="text-xs font-normal text-slate-500">
                                      {optionGroup.rows.length} row{optionGroup.rows.length === 1 ? "" : "s"}
                                    </span>
                                  </button>
                                </td>
                              </tr>

                              {!optionCollapsed &&
                                optionGroup.rows.map(({ row, index }) => (
                                  <tr
                                    key={`${String(row["RecommendationID"] ?? index)}-${index}`}
                                    className={`${index % 2 ? "bg-slate-50" : ""} transition-colors hover:bg-emerald-50/40`}
                                  >
                                    {columns.map((column) => {
                                      const isTargetPriceColumn = column === "TargetPrice";
                                      return (
                                        <td key={column} className="whitespace-nowrap border-b border-slate-100 px-3 py-2">
                                          {isTargetPriceColumn ? (
                                            <input
                                              type="number"
                                              min="0"
                                              step="0.01"
                                              value={targetPriceInputs[index] ?? formatPriceInput(getTargetPriceRaw(row))}
                                              onChange={(e) => handleTargetPriceChange(index, row, e.target.value)}
                                              disabled={orderLoading[index]}
                                              className="w-24 rounded-md border border-slate-300 bg-white px-2 py-1 text-xs font-normal text-slate-800 focus:border-emerald-400/40 focus:outline-none focus:ring-2 focus:ring-emerald-400/40 disabled:cursor-not-allowed disabled:opacity-50"
                                            />
                                          ) : (
                                            formatCellValue(column, row[column])
                                          )}
                                        </td>
                                      );
                                    })}
                                    <td className="whitespace-nowrap border-b border-slate-100 px-3 py-2">
                                      <div className="flex min-w-[430px] flex-col gap-2">
                                        <div className="flex flex-nowrap items-end gap-2">
                                          <label className="flex shrink-0 flex-col gap-1 text-[11px] font-medium uppercase tracking-wide text-slate-500">
                                            <span className="whitespace-nowrap">STO Price</span>
                                            <input
                                              type="number"
                                              min="0"
                                              step="0.01"
                                              value={stoPriceInputs[index] ?? formatPriceInput(getStoLimitPriceRaw(row))}
                                              readOnly
                                              disabled={orderLoading[index] || repriceLoading[index]}
                                              className="w-24 rounded-md border border-slate-300 bg-slate-50 px-2 py-1 text-xs font-normal text-slate-800 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"
                                            />
                                          </label>
                                          <button
                                            type="button"
                                            onClick={() => handleCheckLivePrice(index, row)}
                                            disabled={quoteLoading[index]}
                                            className="flex shrink-0 items-center gap-1 whitespace-nowrap rounded-md bg-blue-600 px-3 py-1 text-xs font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:cursor-not-allowed disabled:opacity-50"
                                          >
                                            {quoteLoading[index] && (
                                              <div className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                                            )}
                                            {quoteLoading[index] ? "Loading..." : "Check Live Price"}
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => handlePlaceSTOOrder(index, row)}
                                            disabled={orderLoading[index] || repriceLoading[index]}
                                            className="flex shrink-0 items-center gap-1 whitespace-nowrap rounded-md bg-emerald-600 px-3 py-1 text-xs font-medium text-white hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-400/40 disabled:cursor-not-allowed disabled:opacity-50"
                                          >
                                            {orderLoading[index] && (
                                              <div className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                                            )}
                                            {orderLoading[index] ? "Placing..." : repriceLoading[index] ? "Repricing..." : "Place STO Order"}
                                          </button>
                                        </div>
                                        {repriceErrors[index] && (
                                          <div className="text-xs text-red-600">
                                            Reprice error: {repriceErrors[index]}
                                          </div>
                                        )}
                                        {quoteResults[index] && (
                                          <div className={`text-xs ${quoteResults[index].ok ? "text-slate-700" : "text-red-600"}`}>
                                            {quoteResults[index].ok ? (
                                              <div className="flex flex-col gap-0.5">
                                                <div>
                                                  Bid: {quoteResults[index].bid != null ? `$${quoteResults[index].bid?.toFixed(2)}` : "N/A"} |
                                                  Ask: {quoteResults[index].ask != null ? `$${quoteResults[index].ask?.toFixed(2)}` : "N/A"} |
                                                  Mid: {quoteResults[index].mid != null ? `$${quoteResults[index].mid?.toFixed(2)}` : "N/A"}
                                                </div>
                                                {quoteResults[index].source && (
                                                  <div className="text-slate-500">Source: {quoteResults[index].source?.toUpperCase()}</div>
                                                )}
                                              </div>
                                            ) : (
                                              <div>Error: {quoteResults[index].error}</div>
                                            )}
                                          </div>
                                        )}
                                        {orderResults[index] && (
                                          <div className={`text-xs ${orderResults[index].ok ? "text-emerald-700" : "text-red-600"}`}>
                                            {orderResults[index].ok ? (
                                              <div className="flex flex-col gap-0.5">
                                                <div className="font-medium">{orderResults[index].message}</div>
                                                {orderResults[index].parent && (
                                                  <div className="text-slate-600">
                                                    Parent ID: {orderResults[index].parent?.ib_order_id ?? "N/A"} ({orderResults[index].parent?.tif})
                                                  </div>
                                                )}
                                                {orderResults[index].exit && (
                                                  <div className="text-slate-600">
                                                    Exit ID: {orderResults[index].exit?.ib_order_id ?? "N/A"} ({orderResults[index].exit?.tif} @ ${orderResults[index].exit?.limit_price.toFixed(2)})
                                                  </div>
                                                )}
                                                {orderResults[index].ib_order_id != null && (
                                                  <div className="text-slate-600">
                                                    Order ID: {orderResults[index].ib_order_id}
                                                  </div>
                                                )}
                                                {orderResults[index].warnings && orderResults[index].warnings!.length > 0 && (
                                                  <div className="text-amber-700">
                                                    IB warning: {orderResults[index].warnings!.join(" | ")}
                                                  </div>
                                                )}
                                                {orderResults[index].orders && orderResults[index].orders!.length > 0 && (
                                                  <div className="text-slate-600">
                                                    Order ID: {orderResults[index].orders![0].ib_order_id}
                                                  </div>
                                                )}
                                              </div>
                                            ) : (
                                              <div>Error: {orderResults[index].error}</div>
                                            )}
                                          </div>
                                        )}
                                      </div>
                                    </td>
                                  </tr>
                                ))}
                            </Fragment>
                          );
                        })}
                    </Fragment>
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


