"use client";

import MarkdownRenderer from "./MarkdownRenderer";

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
              <option value="openai/gpt-5.1">GPT-5.1</option>
              <option value="openai/gpt-4.1-mini">GPT-4.1 Mini</option>
              <option value="google/gemini-2.5-pro">Gemini 2.5 Pro</option>
              <option value="deepseek/deepseek-v3.2">DeepSeek V3.2</option>
              <option value="deepseek/deepseek-r1-0528-qwen3-8b">DeepSeek R1 Qwen3 8B</option>
              <option value="x-ai/grok-4.1-fast">Grok 4.1 Fast</option>
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
                      {promptMetadata.hasOptionTrades && " • Option trades ✓"}
                      {promptMetadata.hasPriceBars && " • 30M bars ✓"}
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
    </div>
  );
}