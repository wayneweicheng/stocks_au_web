"use client";

import { useEffect, useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import InsightTab from "../components/InsightTab";

export default function OptionInsightsPage() {
  const [observationDate, setObservationDate] = useState<string>(() => {
    const d = new Date();
    return d.toISOString().slice(0, 10);
  });
  const [stockCode, setStockCode] = useState<string>("SLV");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  // Option insights state
  const [optionPrediction, setOptionPrediction] = useState<string>("");
  const [optionPredictionLoading, setOptionPredictionLoading] = useState(false);
  const [optionPredictionError, setOptionPredictionError] = useState<string>("");
  const [optionPredictionCached, setOptionPredictionCached] = useState<boolean>(false);
  const [optionPredictionWarning, setOptionPredictionWarning] = useState<string>("");
  const [selectedOptionModel, setSelectedOptionModel] = useState<string>("google/gemini-2.5-flash");

  const [optionPromptText, setOptionPromptText] = useState<string>("");
  const [optionPromptLoading, setOptionPromptLoading] = useState(false);
  const [optionPromptError, setOptionPromptError] = useState<string>("");
  const [optionPromptCopied, setOptionPromptCopied] = useState(false);
  const [optionPromptMetadata, setOptionPromptMetadata] = useState<{
    estimatedTokens: number;
  } | null>(null);

  // Stock codes state
  const [stockCodes, setStockCodes] = useState<Array<{ stock_code: string; latest_date: string }>>([]);
  const [stockCodesLoading, setStockCodesLoading] = useState(false);
  const [latestDate, setLatestDate] = useState<string>("");

  // Signal strength matrix state
  const [signalStrengths, setSignalStrengths] = useState<
    Array<{
      stock_code: string;
      signal_strength_level: string;
      buy_dip_range?: string | null;
      sell_rip_range?: string | null;
    }>
  >([]);
  const [signalStrengthsLoading, setSignalStrengthsLoading] = useState(false);

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  // Fetch stock codes for the selected observation date
  useEffect(() => {
    setStockCodesLoading(true);
    const params = new URLSearchParams();
    if (observationDate) params.set("observation_date", observationDate);
    const url = `${baseUrl}/api/stock-codes${params.toString() ? `?${params.toString()}` : ""}`;
    authenticatedFetch(url)
      .then(async (r) => {
        if (r.ok) {
          const data = await r.json();
          setStockCodes(data);
          // Ensure selected stock code exists in the filtered list
          if (Array.isArray(data)) {
            const exists = data.some((s: { stock_code: string }) => s.stock_code === stockCode);
            if (!exists) {
              const first = data[0]?.stock_code;
              if (first) setStockCode(first);
            }
          }
        }
      })
      .catch((e) => console.error("Failed to fetch stock codes:", e))
      .finally(() => setStockCodesLoading(false));
  }, [baseUrl, observationDate, stockCode]);

  // Update latest date when stock code changes
  useEffect(() => {
    const found = stockCodes.find((s) => s.stock_code === stockCode);
    if (found) {
      setLatestDate(found.latest_date);
    } else {
      setLatestDate("");
    }
  }, [stockCode, stockCodes]);

  // Fetch signal strengths for the selected observation date (OPTION source only)
  useEffect(() => {
    if (!observationDate) return;
    setSignalStrengthsLoading(true);
    const url = `${baseUrl}/api/signal-strength?observation_date=${encodeURIComponent(
      observationDate
    )}&source_type=OPTION`;
    authenticatedFetch(url)
      .then(async (r) => {
        if (r.ok) {
          const data = await r.json();
          setSignalStrengths(Array.isArray(data) ? data : []);
        } else {
          setSignalStrengths([]);
        }
      })
      .catch((e) => {
        console.error("Failed to fetch signal strengths:", e);
        setSignalStrengths([]);
      })
      .finally(() => setSignalStrengthsLoading(false));
  }, [baseUrl, observationDate]);

  // Fetch option insight prediction
  const fetchOptionPrediction = useCallback(
    async (forceRegenerate: boolean = false) => {
      if (!observationDate || !stockCode) return;
      setOptionPredictionLoading(true);
      setOptionPredictionError("");

      const params = new URLSearchParams({
        observation_date: observationDate,
        stock_code: stockCode.trim().toUpperCase(),
        regenerate: String(forceRegenerate),
        model: selectedOptionModel,
      });

      try {
        const r = await authenticatedFetch(`${baseUrl}/api/option-insight-prediction?${params}`);
        if (!r.ok) {
          const data = await r.json().catch(() => ({}));
          throw new Error(data.detail || `HTTP ${r.status}`);
        }
        const data = await r.json();
        setOptionPrediction(data.prediction_markdown || "");
        setOptionPredictionCached(data.cached || false);
        setOptionPredictionWarning(data.warning || "");

        // Reload signal strengths after generating/regenerating
        if (!data.cached || forceRegenerate) {
          const strengthUrl = `${baseUrl}/api/signal-strength?observation_date=${encodeURIComponent(
            observationDate
          )}&source_type=OPTION`;
          authenticatedFetch(strengthUrl)
            .then(async (sr) => {
              if (sr.ok) {
                const strengthData = await sr.json();
                setSignalStrengths(Array.isArray(strengthData) ? strengthData : []);
              }
            })
            .catch((e) => console.error("Failed to refresh signal strengths:", e));
        }
      } catch (e: any) {
        setOptionPredictionError(e.message);
        setOptionPredictionWarning("");
      } finally {
        setOptionPredictionLoading(false);
      }
    },
    [baseUrl, observationDate, stockCode, selectedOptionModel]
  );

  // Fetch option prompt from API
  const fetchOptionPrompt = useCallback(async () => {
    if (!observationDate || !stockCode) return;

    setOptionPromptLoading(true);
    setOptionPromptError("");
    setOptionPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/option-insight-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setOptionPromptText(data.prompt || "");

      setOptionPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
      });
    } catch (e: any) {
      setOptionPromptError(e.message);
      setOptionPromptText("");
      setOptionPromptMetadata(null);
    } finally {
      setOptionPromptLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  // Copy option prompt to clipboard
  const copyOptionPromptToClipboard = useCallback(() => {
    if (!optionPromptText) return;

    setOptionPromptError("");
    setOptionPromptCopied(false);

    const textarea = document.createElement("textarea");
    textarea.value = optionPromptText;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";
    textarea.setAttribute("readonly", "");
    document.body.appendChild(textarea);

    try {
      textarea.focus();
      textarea.select();

      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setOptionPromptCopied(true);
      setTimeout(() => setOptionPromptCopied(false), 2000);
    } catch (clipboardError) {
      setOptionPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [optionPromptText]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          US Option Insights
        </h1>

        {/* Filters */}
        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
            <div className="flex items-center gap-2">
              <button
                type="button"
                aria-label="Previous business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() - 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-blue-50"
              >
                ←
              </button>
              <input
                type="date"
                value={observationDate}
                onChange={(e) => setObservationDate(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
              <button
                type="button"
                aria-label="Next business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() + 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-blue-50"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1 text-slate-600">
              Stock Code
              {latestDate && <span className="ml-2 text-xs text-slate-500">(Latest: {latestDate})</span>}
            </label>
            <select
              value={stockCode}
              onChange={(e) => setStockCode(e.target.value)}
              disabled={stockCodesLoading}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
            >
              {stockCodes.map((s) => (
                <option key={s.stock_code} value={s.stock_code}>
                  {s.stock_code}
                </option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        {/* Option Insights Tab */}
        <InsightTab
          title="Option Flow Insights"
          prediction={optionPrediction}
          predictionLoading={optionPredictionLoading}
          predictionError={optionPredictionError}
          predictionCached={optionPredictionCached}
          predictionWarning={optionPredictionWarning}
          selectedModel={selectedOptionModel}
          onModelChange={setSelectedOptionModel}
          onGenerate={() => fetchOptionPrediction(false)}
          onRegenerate={() => fetchOptionPrediction(true)}
          onGetPrompt={fetchOptionPrompt}
          onCopyPrompt={copyOptionPromptToClipboard}
          promptText={optionPromptText}
          promptLoading={optionPromptLoading}
          promptError={optionPromptError}
          promptCopied={optionPromptCopied}
          promptMetadata={optionPromptMetadata}
        />

        {/* Signal Strength Matrix Section */}
        <div className="mb-8">
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h2 className="text-lg font-semibold mb-4 text-slate-700">Option Signal Strength Matrix</h2>

            {signalStrengthsLoading ? (
              <div className="text-sm text-slate-600">Loading signal strengths...</div>
            ) : signalStrengths.length === 0 ? (
              <div className="text-sm text-slate-600">
                No signal strength data available for {observationDate}. Generate option insights to populate this
                matrix.
              </div>
            ) : (
              <div>
                {/* Desktop/Tablet matrix */}
                <div className="hidden sm:block overflow-x-auto">
                  <div className="inline-block min-w-full">
                    {/* Header Row */}
                    <div className="grid grid-cols-8 gap-2 mb-3 pb-2 border-b border-slate-200">
                      <div className="text-xs font-semibold text-slate-600 uppercase">Stock</div>
                      <div className="text-xs font-semibold text-center text-emerald-700">Strongly Bullish</div>
                      <div className="text-xs font-semibold text-center text-emerald-500">Mildly Bullish</div>
                      <div className="text-xs font-semibold text-center text-amber-600">Neutral</div>
                      <div className="text-xs font-semibold text-center text-orange-500">Mildly Bearish</div>
                      <div className="text-xs font-semibold text-center text-red-600">Strongly Bearish</div>
                      <div className="text-xs font-semibold text-center text-slate-600">Buy the Dip Range</div>
                      <div className="text-xs font-semibold text-center text-slate-600">Sell the Rip Range</div>
                    </div>

                    {/* Data Rows */}
                    {signalStrengths.map((item) => {
                      const level = item.signal_strength_level;
                      return (
                        <div
                          key={item.stock_code}
                          className="grid grid-cols-8 gap-2 py-2 border-b border-slate-100 hover:bg-slate-50"
                        >
                          <div className="text-sm font-medium text-slate-700">{item.stock_code}</div>

                          {/* Strongly Bullish */}
                          <div className="flex justify-center items-center">
                            {level === "STRONGLY_BULLISH" && (
                              <div className="w-6 h-6 rounded-full bg-emerald-600" title="Strongly Bullish"></div>
                            )}
                          </div>

                          {/* Mildly Bullish */}
                          <div className="flex justify-center items-center">
                            {level === "MILDLY_BULLISH" && (
                              <div className="w-6 h-6 rounded-full bg-emerald-300" title="Mildly Bullish"></div>
                            )}
                          </div>

                          {/* Neutral */}
                          <div className="flex justify-center items-center">
                            {level === "NEUTRAL" && (
                              <div className="w-6 h-6 rounded-full bg-amber-400" title="Neutral"></div>
                            )}
                          </div>

                          {/* Mildly Bearish */}
                          <div className="flex justify-center items-center">
                            {level === "MILDLY_BEARISH" && (
                              <div className="w-6 h-6 rounded-full bg-orange-400" title="Mildly Bearish"></div>
                            )}
                          </div>

                          {/* Strongly Bearish */}
                          <div className="flex justify-center items-center">
                            {level === "STRONGLY_BEARISH" && (
                              <div className="w-6 h-6 rounded-full bg-red-600" title="Strongly Bearish"></div>
                            )}
                          </div>

                          {/* Buy Dip Range */}
                          <div className="flex justify-center items-center text-xs text-slate-700">
                            {item.buy_dip_range || "—"}
                          </div>

                          {/* Sell Rip Range */}
                          <div className="flex justify-center items-center text-xs text-slate-700">
                            {item.sell_rip_range || "—"}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Mobile cards */}
                <div className="sm:hidden space-y-3">
                  {signalStrengths.map((item) => {
                    const level = item.signal_strength_level;
                    const label = (level || "").replace(/_/g, " ");
                    const color =
                      level === "STRONGLY_BULLISH"
                        ? "bg-emerald-600"
                        : level === "MILDLY_BULLISH"
                        ? "bg-emerald-300"
                        : level === "NEUTRAL"
                        ? "bg-amber-400"
                        : level === "MILDLY_BEARISH"
                        ? "bg-orange-400"
                        : level === "STRONGLY_BEARISH"
                        ? "bg-red-600"
                        : "bg-slate-300";
                    return (
                      <div key={item.stock_code} className="rounded-md border border-slate-200 p-3 bg-white">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-semibold text-slate-800">{item.stock_code}</div>
                          <div className="flex items-center gap-2">
                            <div className={`w-4 h-4 rounded-full ${color}`} aria-hidden />
                            <div className="text-xs text-slate-700 uppercase">{label}</div>
                          </div>
                        </div>
                        <div className="mt-2 grid grid-cols-2 gap-2">
                          <div className="text-xs text-slate-600">
                            <div className="font-medium text-slate-700">Buy Dip</div>
                            <div>{item.buy_dip_range || "—"}</div>
                          </div>
                          <div className="text-xs text-slate-600">
                            <div className="font-medium text-slate-700">Sell Rip</div>
                            <div>{item.sell_rip_range || "—"}</div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Information Section */}
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-lg font-semibold mb-3 text-slate-700">About Option Insights</h2>
          <div className="text-sm text-slate-700 space-y-2">
            <p>
              Option Insights analyzes open interest (OI) changes in US stock options to identify short-term market
              bias and tactical trading opportunities.
            </p>
            <p>
              <strong>Key Features:</strong>
            </p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Tracks significant OI changes (&gt;300 contracts) between yesterday and today</li>
              <li>Identifies gamma walls (support/resistance levels based on option positioning)</li>
              <li>Analyzes institutional vs. retail flow patterns</li>
              <li>Provides 1-10 day tactical outlook with specific entry/exit ranges</li>
              <li>Generates signal strength classifications (Strongly Bullish to Strongly Bearish)</li>
            </ul>
            <p className="mt-3 text-xs text-slate-500 italic">
              Note: This analysis focuses on short-term (1-10 day) price action based on options flow, not long-term
              fundamentals.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}