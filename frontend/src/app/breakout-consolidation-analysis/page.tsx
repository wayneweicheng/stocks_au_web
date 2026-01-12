"use client";

import { useEffect, useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import MarkdownRenderer from "../components/MarkdownRenderer";

export default function BreakoutConsolidationAnalysisPage() {
  const [observationDate, setObservationDate] = useState<string>(() => {
    const d = new Date();
    return d.toISOString().slice(0, 10);
  });
  const [stockCode, setStockCode] = useState<string>("");
  const [stockCodes, setStockCodes] = useState<Array<{ ASXCode: string }>>([]);
  const [stockCodesLoading, setStockCodesLoading] = useState(false);
  const [stockCodesError, setStockCodesError] = useState<string>("");

  // Analysis state
  const [analysis, setAnalysis] = useState<string>("");
  const [analysisLoading, setAnalysisLoading] = useState(false);
  const [analysisError, setAnalysisError] = useState<string>("");
  const [analysisCached, setAnalysisCached] = useState<boolean>(false);
  const [selectedModel, setSelectedModel] = useState<string>("google/gemini-2.5-flash");

  // Prompt state
  const [promptText, setPromptText] = useState<string>("");
  const [promptLoading, setPromptLoading] = useState(false);
  const [promptError, setPromptError] = useState<string>("");
  const [promptCopied, setPromptCopied] = useState(false);

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  // Fetch consolidation stock codes when observation date changes
  useEffect(() => {
    if (!observationDate) return;

    setStockCodesLoading(true);
    setStockCodesError("");

    const params = new URLSearchParams();
    params.set("observation_date", observationDate);
    const url = `${baseUrl}/api/breakout-consolidation-stock-codes?${params}`;

    authenticatedFetch(url)
      .then(async (r) => {
        if (r.ok) {
          const data = await r.json();
          setStockCodes(Array.isArray(data) ? data : []);

          // Auto-select first stock if available and current selection is invalid
          if (Array.isArray(data) && data.length > 0) {
            const exists = data.some((s: { ASXCode: string }) => s.ASXCode === stockCode);
            if (!exists || !stockCode) {
              setStockCode(data[0].ASXCode);
            }
          } else {
            setStockCode("");
          }
        } else {
          const errorData = await r.json().catch(() => ({}));
          setStockCodesError(errorData.detail || `HTTP ${r.status}`);
          setStockCodes([]);
          setStockCode("");
        }
      })
      .catch((e) => {
        console.error("Failed to fetch consolidation stock codes:", e);
        setStockCodesError(e.message);
        setStockCodes([]);
        setStockCode("");
      })
      .finally(() => setStockCodesLoading(false));
  }, [baseUrl, observationDate]);

  // Fetch analysis
  const fetchAnalysis = useCallback(async (forceRegenerate: boolean = false) => {
    if (!observationDate || !stockCode) return;

    setAnalysisLoading(true);
    setAnalysisError("");

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
      regenerate: String(forceRegenerate),
      model: selectedModel
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/breakout-consolidation-analysis?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setAnalysis(data.analysis_markdown || "");
      setAnalysisCached(data.cached || false);
    } catch (e: any) {
      setAnalysisError(e.message);
    } finally {
      setAnalysisLoading(false);
    }
  }, [baseUrl, observationDate, stockCode, selectedModel]);

  // Fetch prompt from API (doesn't copy yet)
  const fetchPrompt = useCallback(async () => {
    if (!observationDate || !stockCode) return;

    setPromptLoading(true);
    setPromptError("");
    setPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/breakout-consolidation-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setPromptText(data.prompt || "");
    } catch (e: any) {
      setPromptError(e.message);
      setPromptText("");
    } finally {
      setPromptLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  // Copy prompt to clipboard (synchronous, mobile-friendly)
  const copyPromptToClipboard = useCallback(() => {
    if (!promptText) return;

    setPromptError("");
    setPromptCopied(false);

    // Mobile-friendly copy: Use a temporary textarea
    const textarea = document.createElement("textarea");
    textarea.value = promptText;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";
    textarea.setAttribute("readonly", "");
    document.body.appendChild(textarea);

    try {
      textarea.focus();
      textarea.select();

      // Use execCommand for maximum mobile compatibility
      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setPromptCopied(true);
      // Reset success message after 2 seconds
      setTimeout(() => setPromptCopied(false), 2000);
    } catch (clipboardError) {
      setPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [promptText]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-purple-500 to-pink-600 bg-clip-text text-transparent">
          Breakout Consolidation Analysis
        </h1>

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
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-purple-50"
              >
                ←
              </button>
              <input
                type="date"
                value={observationDate}
                onChange={(e) => setObservationDate(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40"
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
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-purple-50"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1 text-slate-600">
              Stock Code (Consolidation Pattern)
            </label>
            <select
              value={stockCode}
              onChange={(e) => setStockCode(e.target.value)}
              disabled={stockCodesLoading || stockCodes.length === 0}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40 focus:border-purple-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {stockCodes.length === 0 && !stockCodesLoading && (
                <option value="">No consolidation stocks available for this date</option>
              )}
              {stockCodesLoading && (
                <option value="">Loading...</option>
              )}
              {stockCodes.map((s) => (
                <option key={s.ASXCode} value={s.ASXCode}>
                  {s.ASXCode}
                </option>
              ))}
            </select>
            {stockCodesError && (
              <div className="mt-1 text-xs text-red-600">Error: {stockCodesError}</div>
            )}
          </div>
        </div>

        {/* Analysis Section */}
        <div className="mb-8">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
              <h2 className="text-lg font-semibold text-slate-700">Breakout Consolidation Analysis</h2>

              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={selectedModel}
                  onChange={(e) => setSelectedModel(e.target.value)}
                  className="w-full sm:w-auto rounded-md border border-slate-300 px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="google/gemini-2.5-flash">Gemini 2.5 Flash</option>
                  <option value="google/gemini-3-flash-preview">Gemini 3 Flash Preview</option>
                  <option value="google/gemini-2.5-pro">Gemini 2.5 Pro</option>
                  <option value="google/gemini-3-pro-preview">Gemini 3 Pro Preview</option>
                  <option value="openai/gpt-5-mini">GPT-5 Mini</option>
                  <option value="openai/gpt-5.1">GPT-5.1</option>
                  <option value="openai/gpt-5.2">GPT-5.2</option>
                  <option value="openai/gpt-4.1-mini">GPT-4.1 Mini</option>
                  <option value="openai/gpt-4o-2024-11-20">GPT-4o (2024-11-20)</option>
                  <option value="openai/gpt-4o-mini-2024-07-18">GPT-4o Mini (2024-07-18)</option>
                  <option value="qwen/qwen3-30b-a3b">Qwen3 30B</option>
                  <option value="deepseek/deepseek-v3.2">DeepSeek V3.2</option>
                  <option value="deepseek/deepseek-r1-0528-qwen3-8b">DeepSeek R1 Qwen3 8B</option>
                  <option value="anthropic/claude-3.7-sonnet:thinking">Claude 3.7 Sonnet (Thinking)</option>
                  <option value="x-ai/grok-4.1-fast">Grok 4.1 Fast</option>
                </select>
                <button
                  type="button"
                  onClick={() => fetchAnalysis(false)}
                  disabled={analysisLoading || !stockCode}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-blue-500 bg-blue-500 px-3 py-1.5 text-sm text-white hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {analysisLoading && !analysis ? "Generating..." : "Generate"}
                </button>
                <button
                  type="button"
                  onClick={() => fetchAnalysis(true)}
                  disabled={analysisLoading || !stockCode}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-purple-500 bg-white px-3 py-1.5 text-sm text-purple-600 hover:bg-purple-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {analysisLoading && analysis ? "Regenerating..." : "Regenerate"}
                </button>
                <button
                  type="button"
                  onClick={fetchPrompt}
                  disabled={promptLoading || !observationDate || !stockCode}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-slate-400 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  title="Fetch LLM prompt"
                >
                  {promptLoading ? "Loading..." : "Get Prompt"}
                </button>
                {promptText && (
                  <button
                    type="button"
                    onClick={copyPromptToClipboard}
                    disabled={!promptText}
                    className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-green-500 bg-green-500 px-3 py-1.5 text-sm text-white hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    title="Copy prompt to clipboard"
                  >
                    Copy
                  </button>
                )}
              </div>
            </div>

            {/* Prompt Feedback Messages */}
            {(promptCopied || promptError) && (
              <div className="mb-3">
                {promptCopied && (
                  <div className="text-sm text-emerald-600 flex items-center gap-1 animate-fade-in">
                    <span>✓</span>
                    <span>Prompt copied to clipboard!</span>
                  </div>
                )}
                {promptError && (
                  <div className="text-sm text-red-600">
                    Error: {promptError}
                  </div>
                )}
              </div>
            )}

            {analysisLoading ? (
              <div className="text-sm text-slate-600">Loading analysis...</div>
            ) : analysisError ? (
              <div className="text-sm text-red-600">Error: {analysisError}</div>
            ) : analysis ? (
              <div>
                {analysisCached && (
                  <div className="mb-2 text-xs text-slate-500 italic">(Cached analysis)</div>
                )}
                <div className="prose prose-sm max-w-none">
                  <MarkdownRenderer content={analysis} />
                </div>
              </div>
            ) : (
              <div className="text-sm text-slate-600">
                Select a consolidation stock and click &quot;Generate&quot; to create a breakout consolidation analysis.
              </div>
            )}
          </div>
        </div>

        {/* Info Section */}
        <div className="grid gap-4 sm:grid-cols-1 mb-8">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <h2 className="text-lg font-semibold mb-3 text-slate-700">About This Analysis</h2>
            <ul className="list-disc pl-5 text-sm text-slate-700 space-y-1">
              <li>
                <b>Pattern:</b> Analyzes stocks in CONSOLIDATION pattern (breakout occurred 2-3 days ago).
              </li>
              <li>
                <b>Data Sources:</b> 60 business days of price history + broker transaction data (buyer/seller flows).
              </li>
              <li>
                <b>Analysis Focus:</b> Validates breakout quality through tape reading, price structure, and smart money absorption patterns.
              </li>
              <li>
                <b>Output:</b> Generates verdict (Strongly Bullish/Bearish/Neutral) with trade plan and invalidation levels.
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
