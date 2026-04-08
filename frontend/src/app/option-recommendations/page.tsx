"use client";

import { useEffect, useMemo, useState } from "react";

import { authenticatedFetch } from "../utils/authenticatedFetch";

type OptionRecommendationRow = Record<string, unknown>;

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

  const columns = useMemo(() => {
    if (!rows[0]) return [];
    return Object.keys(rows[0]);
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

  const minDate = availableDates.length > 0 ? availableDates[availableDates.length - 1] : undefined;
  const maxDate = availableDates.length > 0 ? availableDates[0] : undefined;

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
    // Try various possible column names for the limit price and convert to number
    const stolimitPriceRaw = row["STOLimitPrice"] || row["STO_LimitPrice"] || row["LimitPrice"] || row["Price"] || row["STOPrice"];
    const stolimitPrice = typeof stolimitPriceRaw === "string" ? parseFloat(stolimitPriceRaw) : typeof stolimitPriceRaw === "number" ? stolimitPriceRaw : null;

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
          error: `Invalid STOLimitPrice: ${stolimitPriceRaw}. Found columns: ${Object.keys(row).filter(k => k.toLowerCase().includes('price') || k.toLowerCase().includes('limit')).join(", ")}`,
        },
      }));
      return;
    }

    // Always place 1 contract
    const quantity = 1;

    setOrderLoading((prev) => ({ ...prev, [rowIndex]: true }));
    setOrderResults((prev) => {
      const newResults = { ...prev };
      delete newResults[rowIndex];
      return newResults;
    });

    try {
      console.log("Placing option order:", { optionSymbol, quantity, stolimitPrice });
      const response = await authenticatedFetch(`${baseUrl}/api/ib/place-option-order`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          option_symbol: optionSymbol,
          quantity: quantity,
          action: "SELL",
          limit_price: stolimitPrice,
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
      <div className="mx-auto max-w-[96rem] px-6 py-10">
        <div className="mb-6">
          <h1 className="bg-gradient-to-r from-emerald-500 to-blue-600 bg-clip-text text-3xl font-semibold text-transparent sm:text-4xl">
            Option Recommendations
          </h1>
          <p className="mt-2 text-sm text-slate-600">
            Trading recommendations from <code>[Analysis].[v_CSPPriceLadder]</code>, filtered by selected trading date and ordered by rank.
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
              Query: <code>SELECT * FROM [Analysis].[v_CSPPriceLadder] WHERE TradingDate = '{tradingDate || "YYYY-MM-DD"}' ORDER BY Rank, Priority</code>
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
                {rows.map((row, index) => (
                  <tr
                    key={`${String(row["RecommendationID"] ?? index)}-${index}`}
                    className={`${index % 2 ? "bg-slate-50" : ""} transition-colors hover:bg-emerald-50/40`}
                  >
                    {columns.map((column) => (
                      <td key={column} className="whitespace-nowrap border-b border-slate-100 px-3 py-2">
                        {formatCellValue(column, row[column])}
                      </td>
                    ))}
                    <td className="whitespace-nowrap border-b border-slate-100 px-3 py-2">
                      <div className="flex flex-col gap-2 min-w-[200px]">
                        <div className="flex gap-2">
                          <button
                            type="button"
                            onClick={() => handleCheckLivePrice(index, row)}
                            disabled={quoteLoading[index]}
                            className="rounded-md bg-blue-600 px-3 py-1 text-xs font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                          >
                            {quoteLoading[index] && (
                              <div className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                            )}
                            {quoteLoading[index] ? "Loading..." : "Check Live Price"}
                          </button>
                          <button
                            type="button"
                            onClick={() => handlePlaceSTOOrder(index, row)}
                            disabled={orderLoading[index]}
                            className="rounded-md bg-emerald-600 px-3 py-1 text-xs font-medium text-white hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-400/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                          >
                            {orderLoading[index] && (
                              <div className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                            )}
                            {orderLoading[index] ? "Placing..." : "Place STO Order"}
                          </button>
                        </div>
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
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}


