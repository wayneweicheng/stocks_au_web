"use client";

import { useEffect, useRef, useState } from "react";

import MarkdownRenderer from "./MarkdownRenderer";
import {
  DEFAULT_MARKET_FLOW_MODEL,
  SHARED_MARKET_FLOW_MODEL_OPTIONS,
} from "./llmModelOptions";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type TippedStock = {
  stock_code: string;
  total_ratings: number;
  bullish_count: number;
  latest_rating_date?: string | null;
  avg_trade_value_5d?: number | null;
  latest_analysis_date?: string | null;
  overall_score?: number | null;
  overall_rating?: string | null;
  processing_status?: string | null;
  processing_id?: number | null;
};

type TippedStocksResponse = {
  items: TippedStock[];
};

type ProcessResponse = {
  processing_id: number;
  status: string;
  stock_code: string;
  observation_date: string;
  model: string;
  report_available: boolean;
};

type StatusResponse = {
  processing_id: number;
  stock_code: string;
  observation_date?: string | null;
  status: string;
  started_at?: string | null;
  completed_at?: string | null;
  error_message?: string | null;
  requested_by?: string | null;
  model?: string | null;
  report_available: boolean;
};

type ReportResponse = {
  report_id: number;
  stock_code: string;
  observation_date?: string | null;
  report_markdown?: string | null;
  report_json?: Record<string, unknown> | null;
  model?: string | null;
  status?: string | null;
  processed_at?: string | null;
  processed_by?: string | null;
  tokens_used?: number | null;
  processing_time_seconds?: number | null;
};

type BulkProcessResponse = {
  total_submitted: number;
  processing_ids: number[];
  stock_codes: string[];
};

const DEFAULT_MODEL = DEFAULT_MARKET_FLOW_MODEL;
const BULK_ITEMS_PER_PAGE = 100;

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function formatTradeValue(value?: number | null) {
  if (value === null || value === undefined || Number.isNaN(value)) {
    return "N/A";
  }
  if (value >= 1_000_000) {
    return `$${(value / 1_000_000).toFixed(2)}M`;
  }
  if (value >= 1_000) {
    return `$${(value / 1_000).toFixed(1)}K`;
  }
  return `$${value.toFixed(0)}`;
}

function getOverallRatingBadgeColor(rating?: string | null) {
  const normalized = (rating || "").trim().toLowerCase();
  if (!normalized) {
    return "";
  }
  if (normalized.includes("strongly recommended buy")) {
    return "bg-emerald-200 text-emerald-950";
  }
  if (normalized.includes("mildly recommended buy")) {
    return "bg-green-100 text-green-800";
  }
  if (normalized.includes("strongly bullish")) {
    return "bg-emerald-200 text-emerald-950";
  }
  if (normalized.includes("mildly bullish")) {
    return "bg-green-100 text-green-800";
  }
  if (normalized.includes("bullish")) {
    return "bg-emerald-100 text-emerald-800";
  }
  if (normalized.includes("hold / watchlist") || normalized.includes("hold/watchlist")) {
    return "bg-amber-100 text-amber-800";
  }
  if (normalized.includes("strongly bearish")) {
    return "bg-red-200 text-red-950";
  }
  if (normalized.includes("mildly bearish")) {
    return "bg-rose-100 text-rose-800";
  }
  if (normalized.includes("bearish")) {
    return "bg-red-100 text-red-800";
  }
  if (normalized.includes("neutral")) {
    return "bg-amber-100 text-amber-800";
  }
  return "bg-slate-100 text-slate-700";
}

export default function StockAnalysisTab() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const [stocks, setStocks] = useState<TippedStock[]>([]);
  const [stocksLoading, setStocksLoading] = useState(false);
  const [selectedStock, setSelectedStock] = useState("");
  const [observationDate, setObservationDate] = useState(todayIsoDate);
  const [selectedModel, setSelectedModel] = useState(DEFAULT_MODEL);
  const [processingId, setProcessingId] = useState<number | null>(null);
  const [status, setStatus] = useState<"idle" | "loading" | "processing" | "completed" | "error">("idle");
  const [statusMessage, setStatusMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [report, setReport] = useState<ReportResponse | null>(null);

  const [selectedStocks, setSelectedStocks] = useState<Set<string>>(new Set());
  const [bulkObservationDate, setBulkObservationDate] = useState(todayIsoDate);
  const [bulkModel, setBulkModel] = useState(DEFAULT_MODEL);
  const [bulkProcessing, setBulkProcessing] = useState(false);
  const [bulkMessage, setBulkMessage] = useState("");
  const [bulkExpanded, setBulkExpanded] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);

  const pollingRef = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
      }
    };
  }, []);

  useEffect(() => {
    void loadStocks();
  }, [bulkObservationDate]);

  useEffect(() => {
    const hasActiveBulkProcessing = stocks.some(
      (stock) => stock.processing_status === "Pending" || stock.processing_status === "Processing"
    );
    if (!hasActiveBulkProcessing) {
      return;
    }

    const refreshId = window.setInterval(() => {
      void loadStocks({ preserveMessage: true });
    }, 2000);

    return () => {
      window.clearInterval(refreshId);
    };
  }, [stocks, bulkObservationDate]);

  useEffect(() => {
    if (!selectedStock || !observationDate) {
      setReport(null);
      setStatus("idle");
      setStatusMessage("");
      setErrorMessage("");
      return;
    }
    void loadExistingReport(selectedStock, observationDate);
  }, [selectedStock, observationDate]);

  useEffect(() => {
    if (processingId === null || status !== "processing") {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
      return;
    }

    const poll = async () => {
      try {
        const res = await authenticatedFetch(`${baseUrl}/api/stock-analysis/status/${processingId}`);
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        const data: StatusResponse = await res.json();
        setStatusMessage(buildStatusMessage(data));

        if (data.report_available || data.status === "Completed") {
          setStatus("completed");
          if (pollingRef.current !== null) {
            window.clearInterval(pollingRef.current);
            pollingRef.current = null;
          }
          await loadExistingReport(data.stock_code, data.observation_date || observationDate, false);
        } else if (data.status === "Error") {
          setStatus("error");
          setErrorMessage(data.error_message || "Stock analysis failed.");
          if (pollingRef.current !== null) {
            window.clearInterval(pollingRef.current);
            pollingRef.current = null;
          }
        }
      } catch (error) {
        setStatus("error");
        setErrorMessage(error instanceof Error ? error.message : "Failed to poll stock analysis status.");
        if (pollingRef.current !== null) {
          window.clearInterval(pollingRef.current);
          pollingRef.current = null;
        }
      }
    };

    void poll();
    pollingRef.current = window.setInterval(() => {
      void poll();
    }, 2000);

    return () => {
      if (pollingRef.current !== null) {
        window.clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
    };
  }, [baseUrl, observationDate, processingId, status]);

  async function loadStocks(options?: { preserveMessage?: boolean }) {
    setStocksLoading(true);
    if (!options?.preserveMessage) {
      setBulkMessage("");
    }
    try {
      // Always pass observation_date to show status for that specific date
      const url = `${baseUrl}/api/stock-analysis/tipped-stocks?observation_date=${bulkObservationDate}`;
      console.log("Loading stocks with URL:", url);
      const res = await authenticatedFetch(url);
      if (!res.ok) {
        const errorText = await res.text();
        console.error("Failed to load stocks:", res.status, errorText);
        throw new Error(`HTTP ${res.status}: ${errorText}`);
      }
      const data: TippedStocksResponse = await res.json();
      console.log("Loaded stocks:", data.items?.length || 0, "stocks");
      setStocks(data.items || []);
      if (!selectedStock && data.items?.length) {
        setSelectedStock(data.items[0].stock_code);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : "Failed to load tipped stocks.";
      console.error("Load stocks error:", errorMsg);
      setBulkMessage(errorMsg);
    } finally {
      setStocksLoading(false);
    }
  }

  async function loadExistingReport(stockCode: string, reportDate: string, resetStatus = true) {
    setErrorMessage("");
    if (resetStatus) {
      setStatus("loading");
      setStatusMessage("Checking for an existing saved report...");
    }
    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/stock-analysis/report/${encodeURIComponent(stockCode)}/${encodeURIComponent(reportDate)}`
      );
      if (res.status === 404) {
        setReport(null);
        if (resetStatus) {
          setStatus("idle");
          setStatusMessage("No saved report for this stock/date yet.");
        }
        return;
      }
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data: ReportResponse = await res.json();
      setReport(data);
      setStatus("completed");
      setStatusMessage("Saved report loaded.");
    } catch (error) {
      setReport(null);
      setStatus(resetStatus ? "error" : "idle");
      setErrorMessage(error instanceof Error ? error.message : "Failed to load report.");
    }
  }

  async function handleProcess() {
    if (!selectedStock) {
      setErrorMessage("Please choose a stock first.");
      return;
    }

    setErrorMessage("");
    setStatus("processing");
    setStatusMessage("Queueing stock analysis...");
    setReport(null);

    try {
      const res = await authenticatedFetch(`${baseUrl}/api/stock-analysis/process`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          stock_code: selectedStock,
          observation_date: observationDate,
          model: selectedModel,
        }),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => "");
        throw new Error(detail || `HTTP ${res.status}`);
      }

      const data: ProcessResponse = await res.json();
      setProcessingId(data.processing_id);
      if (data.report_available) {
        setStatus("completed");
        setStatusMessage("Saved report detected. Loading report...");
        await loadExistingReport(data.stock_code, data.observation_date, false);
        return;
      }

      setStatus(data.status === "Completed" ? "completed" : "processing");
      setStatusMessage("Stock analysis is running...");
    } catch (error) {
      setStatus("error");
      setErrorMessage(error instanceof Error ? error.message : "Failed to start stock analysis.");
    }
  }

  async function handleBulkProcess() {
    if (selectedStocks.size === 0) {
      setBulkMessage("Please select at least one stock.");
      return;
    }

    setBulkMessage("");
    setBulkProcessing(true);

    try {
      const res = await authenticatedFetch(`${baseUrl}/api/stock-analysis/process-bulk`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          stock_codes: Array.from(selectedStocks),
          observation_date: bulkObservationDate,
          model: bulkModel,
        }),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => "");
        throw new Error(detail || `HTTP ${res.status}`);
      }

      const data: BulkProcessResponse = await res.json();
      setBulkMessage(`Successfully queued ${data.total_submitted} stocks for processing.`);
      setStocks((currentStocks) =>
        currentStocks.map((stock) =>
          data.stock_codes.includes(stock.stock_code)
            ? {
                ...stock,
                processing_status: "Pending",
              }
            : stock
        )
      );
      setSelectedStocks(new Set());
      void loadStocks({ preserveMessage: true });
    } catch (error) {
      setBulkMessage(error instanceof Error ? error.message : "Failed to queue bulk stock analysis.");
    } finally {
      setBulkProcessing(false);
    }
  }

  function toggleStockSelection(stockCode: string) {
    const newSelection = new Set(selectedStocks);
    if (newSelection.has(stockCode)) {
      newSelection.delete(stockCode);
    } else {
      newSelection.add(stockCode);
    }
    setSelectedStocks(newSelection);
  }

  function toggleSelectAll() {
    const startIdx = (currentPage - 1) * BULK_ITEMS_PER_PAGE;
    const endIdx = startIdx + BULK_ITEMS_PER_PAGE;
    const pageStocks = stocks.slice(startIdx, endIdx);
    const pageStockCodes = new Set(pageStocks.map((s) => s.stock_code));

    const allSelected = pageStocks.every((s) => selectedStocks.has(s.stock_code));
    const newSelection = new Set(selectedStocks);

    if (allSelected) {
      pageStockCodes.forEach((code) => newSelection.delete(code));
    } else {
      pageStockCodes.forEach((code) => newSelection.add(code));
    }

    setSelectedStocks(newSelection);
  }

  const selectedStockSummary = stocks.find((item) => item.stock_code === selectedStock) || null;
  const isBusy = status === "processing";

  const totalPages = Math.ceil(stocks.length / BULK_ITEMS_PER_PAGE);
  const startIdx = (currentPage - 1) * BULK_ITEMS_PER_PAGE;
  const endIdx = startIdx + BULK_ITEMS_PER_PAGE;
  const paginatedStocks = stocks.slice(startIdx, endIdx);
  const allPageSelected = paginatedStocks.length > 0 && paginatedStocks.every((s) => selectedStocks.has(s.stock_code));

  return (
    <section className="space-y-6">
      <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <h2 className="text-lg font-medium text-slate-900">Stock Analysis</h2>
            <p className="mt-1 max-w-3xl text-sm text-slate-600">
              Generate a saved AI report for a tipped ASX stock using announcements, price action, broker flow, and liquidity context.
            </p>
          </div>
          <button
            type="button"
            onClick={() => void loadStocks()}
            disabled={stocksLoading}
            className="rounded-md border border-slate-300 px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          >
            {stocksLoading ? "Refreshing..." : "Refresh Stocks"}
          </button>
        </div>

        <div className="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Tipped Stock</label>
            <select
              value={selectedStock}
              onChange={(e) => setSelectedStock(e.target.value)}
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Select stock...</option>
              {stocks.map((stock) => (
                <option key={stock.stock_code} value={stock.stock_code}>
                  {stock.stock_code} ({stock.bullish_count}/{stock.total_ratings} bullish)
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Observation Date</label>
            <input
              type="date"
              value={observationDate}
              onChange={(e) => setObservationDate(e.target.value)}
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">Model</label>
            <select
              value={selectedModel}
              onChange={(e) => setSelectedModel(e.target.value)}
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {SHARED_MARKET_FLOW_MODEL_OPTIONS.map((model) => (
                <option key={model.value} value={model.value}>
                  {model.label}
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-end">
            <button
              type="button"
              onClick={handleProcess}
              disabled={!selectedStock || !observationDate || isBusy}
              className="w-full rounded-md bg-gradient-to-r from-indigo-600 to-blue-600 px-4 py-2 text-sm text-white hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isBusy ? "Processing..." : report ? "Regenerate Report" : "Generate Report"}
            </button>
          </div>
        </div>

        {selectedStockSummary && (
          <div className="mt-4 grid gap-3 sm:grid-cols-3">
            <div className="rounded-lg border border-slate-100 bg-slate-50 p-3">
              <div className="text-xs font-medium uppercase tracking-wide text-slate-500">Ratings</div>
              <div className="mt-1 text-sm font-semibold text-slate-800">
                {selectedStockSummary.bullish_count} bullish / {selectedStockSummary.total_ratings} total
              </div>
            </div>
            <div className="rounded-lg border border-slate-100 bg-slate-50 p-3">
              <div className="text-xs font-medium uppercase tracking-wide text-slate-500">Latest Rating</div>
              <div className="mt-1 text-sm font-semibold text-slate-800">
                {selectedStockSummary.latest_rating_date || "N/A"}
              </div>
            </div>
            <div className="rounded-lg border border-slate-100 bg-slate-50 p-3">
              <div className="text-xs font-medium uppercase tracking-wide text-slate-500">Latest Analysis</div>
              <div className="mt-1 text-sm font-semibold text-slate-800">
                {selectedStockSummary.latest_analysis_date || "None saved"}
              </div>
            </div>
          </div>
        )}

        {(statusMessage || errorMessage) && (
          <div
            className={`mt-4 rounded-lg border px-4 py-3 text-sm ${
              errorMessage
                ? "border-red-200 bg-red-50 text-red-700"
                : status === "completed"
                ? "border-emerald-200 bg-emerald-50 text-emerald-700"
                : "border-slate-200 bg-slate-50 text-slate-700"
            }`}
          >
            {errorMessage || statusMessage}
          </div>
        )}
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h2 className="text-lg font-medium text-slate-900">Bulk Processing</h2>
            <p className="mt-1 max-w-3xl text-sm text-slate-600">
              Select multiple stocks to process them in bulk. Perfect for processing a large number of tipped stocks.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <div className="text-sm text-slate-600">
              {selectedStocks.size} stock{selectedStocks.size !== 1 ? "s" : ""} selected
            </div>
            <button
              type="button"
              onClick={() => setBulkExpanded((expanded) => !expanded)}
              aria-expanded={bulkExpanded}
              aria-controls="stock-analysis-bulk-processing"
              className="inline-flex items-center gap-2 rounded-md border border-slate-300 px-3 py-2 text-sm text-slate-700 hover:bg-slate-50"
            >
              <span aria-hidden="true" className="text-base leading-none">
                {bulkExpanded ? "-" : "+"}
              </span>
              {bulkExpanded ? "Collapse" : "Expand"}
            </button>
          </div>
        </div>

        {bulkExpanded && (
          <div id="stock-analysis-bulk-processing" className="mt-6">
            <div className="mb-4 grid gap-4 md:grid-cols-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Observation Date</label>
                <input
                  type="date"
                  value={bulkObservationDate}
                  onChange={(e) => setBulkObservationDate(e.target.value)}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="mb-1 block text-xs font-medium text-slate-600">Model</label>
                <select
                  value={bulkModel}
                  onChange={(e) => setBulkModel(e.target.value)}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  {SHARED_MARKET_FLOW_MODEL_OPTIONS.map((model) => (
                    <option key={model.value} value={model.value}>
                      {model.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-end">
                <button
                  type="button"
                  onClick={handleBulkProcess}
                  disabled={selectedStocks.size === 0 || bulkProcessing}
                  className="w-full rounded-md bg-gradient-to-r from-emerald-600 to-green-600 px-4 py-2 text-sm text-white hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {bulkProcessing ? "Processing..." : `Process ${selectedStocks.size} Stock${selectedStocks.size !== 1 ? "s" : ""}`}
                </button>
              </div>
            </div>

            {bulkMessage && (
              <div className="mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
                {bulkMessage}
              </div>
            )}

            <div className="overflow-hidden rounded-lg border border-slate-200">
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-slate-200">
                  <thead className="bg-slate-50">
                    <tr>
                      <th className="px-4 py-3 text-left">
                        <input
                          type="checkbox"
                          checked={allPageSelected}
                          onChange={toggleSelectAll}
                          className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-2 focus:ring-indigo-500"
                        />
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Stock Code
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Total Ratings
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Bullish Count
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Latest Rating
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Avg Trade Value 5D
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Overall Rating
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium uppercase tracking-wide text-slate-600">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200 bg-white">
                    {stocksLoading ? (
                      <tr>
                        <td colSpan={8} className="px-4 py-8 text-center text-sm text-slate-500">
                          Loading stocks...
                        </td>
                      </tr>
                    ) : paginatedStocks.length === 0 ? (
                      <tr>
                        <td colSpan={8} className="px-4 py-8 text-center text-sm text-slate-500">
                          No stocks available
                        </td>
                      </tr>
                    ) : (
                      paginatedStocks.map((stock) => {
                        const ratingBadgeColor = getOverallRatingBadgeColor(stock.overall_rating);

                        const statusBadgeColor =
                          stock.processing_status === "Processing"
                            ? "bg-blue-100 text-blue-800"
                            : stock.processing_status === "Pending"
                            ? "bg-yellow-100 text-yellow-800"
                            : "";

                        return (
                          <tr
                            key={stock.stock_code}
                            className={`hover:bg-slate-50 ${selectedStocks.has(stock.stock_code) ? "bg-indigo-50" : ""}`}
                          >
                            <td className="px-4 py-3">
                              <input
                                type="checkbox"
                                checked={selectedStocks.has(stock.stock_code)}
                                onChange={() => toggleStockSelection(stock.stock_code)}
                                className="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-2 focus:ring-indigo-500"
                              />
                            </td>
                            <td className="px-4 py-3 text-sm font-medium text-slate-900">{stock.stock_code}</td>
                            <td className="px-4 py-3 text-sm text-slate-600">{stock.total_ratings}</td>
                            <td className="px-4 py-3 text-sm text-slate-600">{stock.bullish_count}</td>
                            <td className="px-4 py-3 text-sm text-slate-600">{stock.latest_rating_date || "N/A"}</td>
                            <td className="px-4 py-3 text-sm text-slate-600">{formatTradeValue(stock.avg_trade_value_5d)}</td>
                            <td className="px-4 py-3 text-sm">
                              {stock.overall_rating ? (
                                <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${ratingBadgeColor}`}>
                                  {stock.overall_score} - {stock.overall_rating}
                                </span>
                              ) : (
                                <span className="text-slate-400">-</span>
                              )}
                            </td>
                            <td className="px-4 py-3 text-sm">
                              {stock.processing_status ? (
                                <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${statusBadgeColor}`}>
                                  {stock.processing_status}
                                </span>
                              ) : stock.overall_rating ? (
                                <span className="inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-medium text-emerald-800">
                                  Ready
                                </span>
                              ) : (
                                <span className="text-slate-400">Not Processed</span>
                              )}
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>

              {totalPages > 1 && (
                <div className="flex items-center justify-between border-t border-slate-200 bg-slate-50 px-4 py-3">
                  <div className="text-sm text-slate-600">
                    Page {currentPage} of {totalPages} ({stocks.length} total stocks)
                  </div>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                      disabled={currentPage === 1}
                      className="rounded-md border border-slate-300 px-3 py-1 text-sm text-slate-700 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Previous
                    </button>
                    <button
                      type="button"
                      onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                      disabled={currentPage === totalPages}
                      className="rounded-md border border-slate-300 px-3 py-1 text-sm text-slate-700 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      Next
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
        <div className="flex flex-col gap-3 border-b border-slate-200 bg-slate-50 px-6 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h3 className="text-lg font-medium text-slate-800">Analysis Report</h3>
            {report && (
              <p className="mt-1 text-xs text-slate-500">
                {report.stock_code} • {report.observation_date} • {report.model || "Model unavailable"}
              </p>
            )}
          </div>
          {report && (
            <div className="text-xs text-slate-500">
              Processed {report.processed_at ? new Date(report.processed_at).toLocaleString() : "N/A"}
              {report.tokens_used ? ` • ${report.tokens_used.toLocaleString()} tokens` : ""}
              {report.processing_time_seconds ? ` • ${report.processing_time_seconds.toFixed(1)}s` : ""}
            </div>
          )}
        </div>

        <div className="p-6">
          {status === "processing" ? (
            <div className="py-10 text-center text-sm text-slate-500">
              {statusMessage || "Stock analysis is running. This panel will update automatically when the report is ready."}
            </div>
          ) : report?.report_markdown ? (
            <div className="max-w-none">
              <MarkdownRenderer content={report.report_markdown} />
            </div>
          ) : (
            <div className="py-10 text-center text-sm text-slate-500">
              Choose a tipped stock and observation date, then generate a report.
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

function buildStatusMessage(data: StatusResponse) {
  if (data.status === "Pending") {
    return data.error_message || "Queued and waiting to start...";
  }
  if (data.status === "Processing") {
    return data.error_message || "Building compact data and generating the report...";
  }
  if (data.status === "Completed") {
    return "Report generation completed.";
  }
  if (data.status === "Error") {
    return data.error_message || "Stock analysis failed.";
  }
  return data.status;
}
