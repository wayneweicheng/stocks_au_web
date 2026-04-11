"use client";

import MarkdownRenderer from "./MarkdownRenderer";

type SignalStrengthItem = {
  stock_code: string;
  signal_strength_level: string;
  buy_dip_range?: string | null;
  sell_rip_range?: string | null;
};

type InsightTabProps = {
  title: string;
  prediction: string;
  predictionLoading: boolean;
  predictionError: string;
  predictionCached: boolean;
  predictionWarning: string;
  selectedModel: string;
  onModelChange: (model: string) => void;
  onGenerate: () => void;
  onRegenerate: () => void;
  onGetPrompt: () => void;
  onCopyPrompt: () => void;
  promptText: string;
  promptLoading: boolean;
  promptError: string;
  promptCopied: boolean;
  promptMetadata: {
    estimatedTokens: number;
    hasOptionTrades?: boolean;
    hasPriceBars?: boolean;
  } | null;
  disabled?: boolean;
  signalStrengths?: SignalStrengthItem[];
  signalStrengthsLoading?: boolean;
  observationDate?: string;
  signalStrengthMatrixTitle?: string;
};

export default function InsightTab({
  title,
  prediction,
  predictionLoading,
  predictionError,
  predictionCached,
  predictionWarning,
  selectedModel,
  onModelChange,
  onGenerate,
  onRegenerate,
  onGetPrompt,
  onCopyPrompt,
  promptText,
  promptLoading,
  promptError,
  promptCopied,
  promptMetadata,
  disabled = false,
  signalStrengths,
  signalStrengthsLoading = false,
  observationDate,
  signalStrengthMatrixTitle = "Signal Strength Matrix",
}: InsightTabProps) {
  return (
    <div className="mb-8">
      <div className="rounded-lg border border-slate-200 bg-white p-4">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
          <h2 className="text-lg font-semibold text-slate-700">{title}</h2>

          <div className="flex flex-wrap items-center gap-2">
            <select
              value={selectedModel}
              onChange={(e) => onModelChange(e.target.value)}
              className="w-full sm:w-auto rounded-md border border-slate-300 px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="google/gemini-2.5-flash">Gemini 2.5 Flash</option>
              <option value="openai/gpt-5-mini">GPT-5 Mini</option>
              <option value="qwen/qwen3-30b-a3b">Qwen3 30B</option>
              <option value="qwen/qwen3.5-flash-02-23">Qwen3.5 Flash</option>
              <option value="qwen/qwen3.6-plus">Qwen3.6 Plus</option>
              <option value="openai/gpt-5.1">GPT-5.1</option>
              <option value="openai/gpt-4.1-mini">GPT-4.1 Mini</option>
              <option value="openai/gpt-4o-mini">GPT-4o Mini</option>
              <option value="google/gemini-2.5-pro">Gemini 2.5 Pro</option>
              <option value="google/gemma-4-26b-a4b-it:free">Gemma 4 26B (Free)</option>
              <option value="google/gemma-4-31b-it:free">Gemma 4 31B (Free)</option>
              <option value="google/gemma-4-26b-a4b-it">Gemma 4 26B</option>
              <option value="deepseek/deepseek-v3.2">DeepSeek V3.2</option>
              <option value="deepseek/deepseek-r1-distill-qwen-32b">DeepSeek R1 Qwen3 32B</option>
              <option value="x-ai/grok-4.1-fast">Grok 4.1 Fast</option>
              <option value="bytedance-seed/seed-1.6-flash">Seed 1.6 Flash</option>
              <option value="moonshotai/kimi-k2-thinking">Kimi K2 Thinking</option>
              <option value="z-ai/glm-4.7-flash">GLM-4.7 Flash</option>
            </select>
            <button
              type="button"
              onClick={onGenerate}
              disabled={predictionLoading || disabled}
              className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-blue-500 bg-blue-500 px-3 py-1.5 text-sm text-white hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {predictionLoading && !prediction ? "Generating..." : "Generate"}
            </button>
            <button
              type="button"
              onClick={onRegenerate}
              disabled={predictionLoading || disabled}
              className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-emerald-500 bg-white px-3 py-1.5 text-sm text-emerald-600 hover:bg-emerald-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {predictionLoading && prediction ? "Regenerating..." : "Regenerate"}
            </button>
            <button
              type="button"
              onClick={onGetPrompt}
              disabled={promptLoading || disabled}
              className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-slate-400 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              title="Fetch LLM prompt"
            >
              {promptLoading ? "Loading..." : "Get Prompt"}
            </button>
            {promptText && (
              <button
                type="button"
                onClick={onCopyPrompt}
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
              <div className="text-sm text-emerald-600 flex items-center gap-2 animate-fade-in">
                <span>✓</span>
                <span>
                  Prompt copied!
                  {promptMetadata && (
                    <>
                      {" "}~{promptMetadata.estimatedTokens.toLocaleString()} tokens
                      {promptMetadata.hasOptionTrades !== undefined && (
                        promptMetadata.hasOptionTrades
                          ? " • Option trades ✓"
                          : <span className="text-red-600"> • Option trades ✗</span>
                      )}
                      {promptMetadata.hasPriceBars !== undefined && (
                        promptMetadata.hasPriceBars
                          ? " • 30M bars ✓"
                          : <span className="text-red-600"> • 30M bars ✗</span>
                      )}
                    </>
                  )}
                </span>
              </div>
            )}
            {promptError && (
              <div className="text-sm text-red-600">
                Error: {promptError}
              </div>
            )}
          </div>
        )}

        {predictionLoading ? (
          <div className="text-sm text-slate-600">Loading prediction...</div>
        ) : predictionError ? (
          <div className="text-sm text-red-600">Error: {predictionError}</div>
        ) : prediction ? (
          <div>
            {predictionCached && (
              <div className="mb-2 text-xs text-slate-500 italic">(Cached prediction)</div>
            )}
            {predictionWarning && (
              <div className="mb-3 rounded-md border border-yellow-200 bg-yellow-50 text-yellow-800 px-3 py-2 text-sm">
                ⚠️ {predictionWarning}
              </div>
            )}
            <div className="prose prose-sm max-w-none">
              <MarkdownRenderer content={prediction} />
            </div>
          </div>
        ) : (
          <div className="text-sm text-slate-600">
            Click &quot;Generate&quot; to create a prediction for this stock and date.
          </div>
        )}
      </div>

      {/* Signal Strength Matrix */}
      {signalStrengths !== undefined && (
        <div className="rounded-lg border border-slate-200 bg-white p-6 mt-4">
          <h2 className="text-lg font-semibold mb-4 text-slate-700">{signalStrengthMatrixTitle}</h2>

          {signalStrengthsLoading ? (
            <div className="text-sm text-slate-600">Loading signal strengths...</div>
          ) : signalStrengths.length === 0 ? (
            <div className="text-sm text-slate-600">
              No signal strength data available{observationDate ? ` for ${observationDate}` : ""}. Generate a prediction to populate this matrix.
            </div>
          ) : (
            <div>
              {/* Desktop/Tablet matrix */}
              <div className="hidden sm:block overflow-x-auto">
                <div className="inline-block min-w-full">
                  <div className="grid grid-cols-8 gap-2 mb-3 pb-2 border-b border-slate-200">
                    <div className="text-xs font-semibold text-slate-600 uppercase">Stock</div>
                    <div className="text-xs font-semibold text-center text-indigo-700">Strongly Bullish</div>
                    <div className="text-xs font-semibold text-center text-emerald-500">Mildly Bullish</div>
                    <div className="text-xs font-semibold text-center text-amber-600">Neutral</div>
                    <div className="text-xs font-semibold text-center text-orange-500">Mildly Bearish</div>
                    <div className="text-xs font-semibold text-center text-red-600">Strongly Bearish</div>
                    <div className="text-xs font-semibold text-center text-slate-600">Buy the Dip Range</div>
                    <div className="text-xs font-semibold text-center text-slate-600">Sell the Rip Range</div>
                  </div>
                  {signalStrengths.map((item) => {
                    const level = item.signal_strength_level;
                    return (
                      <div key={item.stock_code} className="grid grid-cols-8 gap-2 py-2 border-b border-slate-100 hover:bg-slate-50">
                        <div className="text-sm font-medium text-slate-700">{item.stock_code}</div>
                        <div className="flex justify-center items-center">
                          {level === "STRONGLY_BULLISH" && <div className="w-6 h-6 rounded-full bg-indigo-600" title="Strongly Bullish" />}
                        </div>
                        <div className="flex justify-center items-center">
                          {level === "MILDLY_BULLISH" && <div className="w-6 h-6 rounded-full bg-emerald-300" title="Mildly Bullish" />}
                        </div>
                        <div className="flex justify-center items-center">
                          {level === "NEUTRAL" && <div className="w-6 h-6 rounded-full bg-amber-400" title="Neutral" />}
                        </div>
                        <div className="flex justify-center items-center">
                          {level === "MILDLY_BEARISH" && <div className="w-6 h-6 rounded-full bg-orange-400" title="Mildly Bearish" />}
                        </div>
                        <div className="flex justify-center items-center">
                          {level === "STRONGLY_BEARISH" && <div className="w-6 h-6 rounded-full bg-red-600" title="Strongly Bearish" />}
                        </div>
                        <div className="flex justify-center items-center text-xs text-slate-700">
                          {item.buy_dip_range || "-"}
                        </div>
                        <div className="flex justify-center items-center text-xs text-slate-700">
                          {item.sell_rip_range || "-"}
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
                    level === "STRONGLY_BULLISH" ? "bg-indigo-600" :
                    level === "MILDLY_BULLISH" ? "bg-emerald-300" :
                    level === "NEUTRAL" ? "bg-amber-400" :
                    level === "MILDLY_BEARISH" ? "bg-orange-400" :
                    level === "STRONGLY_BEARISH" ? "bg-red-600" : "bg-slate-300";
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
                          <div>{item.buy_dip_range || "-"}</div>
                        </div>
                        <div className="text-xs text-slate-600">
                          <div className="font-medium text-slate-700">Sell Rip</div>
                          <div>{item.sell_rip_range || "-"}</div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}