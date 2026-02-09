"use client";

import { useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import MarkdownRenderer from "../components/MarkdownRenderer";

export default function DiscordSummaryPage() {
  const [observationDate, setObservationDate] = useState<string>(() => {
    const d = new Date();
    return d.toISOString().slice(0, 10);
  });

  const [summary, setSummary] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [cached, setCached] = useState<boolean>(false);
  const [selectedModel, setSelectedModel] = useState<string>("google/gemini-2.5-flash");

  const [promptText, setPromptText] = useState<string>("");
  const [promptLoading, setPromptLoading] = useState(false);
  const [promptError, setPromptError] = useState<string>("");
  const [promptCopied, setPromptCopied] = useState(false);
  const [promptMetadata, setPromptMetadata] = useState<{
    estimatedTokens: number;
    messageCount: number;
  } | null>(null);

  const [activeTab, setActiveTab] = useState<"overview" | "followers">("overview");

  const [followersModel, setFollowersModel] = useState<string>("google/gemini-2.5-flash");
  const [followersLoading, setFollowersLoading] = useState(false);
  const [followersError, setFollowersError] = useState("");
  const [followersCached, setFollowersCached] = useState(false);
  const [followersSummary, setFollowersSummary] = useState("");
  const [followersPromptLoading, setFollowersPromptLoading] = useState(false);
  const [followersPromptCopied, setFollowersPromptCopied] = useState(false);
  const [followersPromptError, setFollowersPromptError] = useState("");
  const [followersPromptText, setFollowersPromptText] = useState("");
  const [followersPromptMetadata, setFollowersPromptMetadata] = useState<{
    estimatedTokens: number;
    messageCount: number;
  } | null>(null);

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const fetchSummary = useCallback(
    async (forceRegenerate: boolean = false) => {
      if (!observationDate) return;
      setLoading(true);
      setError("");

      const params = new URLSearchParams({
        observation_date: observationDate,
        regenerate: String(forceRegenerate),
        model: selectedModel,
      });

      try {
        const r = await authenticatedFetch(`${baseUrl}/api/discord-summary?${params}`);
        if (!r.ok) {
          const data = await r.json().catch(() => ({}));
          throw new Error(data.detail || `HTTP ${r.status}`);
        }
        const data = await r.json();
        setSummary(data.summary_markdown || "");
        setCached(data.cached || false);
      } catch (e: any) {
        setError(e.message);
      } finally {
        setLoading(false);
      }
    },
    [baseUrl, observationDate, selectedModel]
  );

  const fetchFollowersSummary = useCallback(
    async (forceRegenerate: boolean = false) => {
      if (!observationDate) return;
      setFollowersLoading(true);
      setFollowersError("");

      const params = new URLSearchParams({
        observation_date: observationDate,
        regenerate: String(forceRegenerate),
        model: followersModel,
      });

      try {
        const r = await authenticatedFetch(`${baseUrl}/api/discord-summary-followers?${params}`);
        if (!r.ok) {
          const data = await r.json().catch(() => ({}));
          throw new Error(data.detail || `HTTP ${r.status}`);
        }
        const data = await r.json();
        setFollowersSummary(data.summary_markdown || "");
        setFollowersCached(data.cached || false);
      } catch (e: any) {
        setFollowersError(e.message);
      } finally {
        setFollowersLoading(false);
      }
    },
    [baseUrl, observationDate, followersModel]
  );

  const fetchPrompt = useCallback(async () => {
    if (!observationDate) return;

    setPromptLoading(true);
    setPromptError("");
    setPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/discord-summary-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setPromptText(data.prompt || "");
      setPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
        messageCount: data.message_count || 0,
      });
    } catch (e: any) {
      setPromptError(e.message);
      setPromptText("");
      setPromptMetadata(null);
    } finally {
      setPromptLoading(false);
    }
  }, [baseUrl, observationDate]);

  const fetchFollowersPrompt = useCallback(async () => {
    if (!observationDate) return;

    setFollowersPromptLoading(true);
    setFollowersPromptError("");
    setFollowersPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/discord-summary-followers-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setFollowersPromptText(data.prompt || "");
      setFollowersPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
        messageCount: data.message_count || 0,
      });
    } catch (e: any) {
      setFollowersPromptError(e.message);
      setFollowersPromptText("");
      setFollowersPromptMetadata(null);
    } finally {
      setFollowersPromptLoading(false);
    }
  }, [baseUrl, observationDate]);

  const copyPromptToClipboard = useCallback(() => {
    if (!promptText) return;

    setPromptError("");
    setPromptCopied(false);

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

      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setPromptCopied(true);
      setTimeout(() => setPromptCopied(false), 2000);
    } catch (clipboardError) {
      setPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [promptText]);

  const copyFollowersPromptToClipboard = useCallback(() => {
    if (!followersPromptText) {
      setFollowersPromptError("No prompt available to copy.");
      return;
    }

    setFollowersPromptError("");
    setFollowersPromptCopied(false);

    const textarea = document.createElement("textarea");
    textarea.value = followersPromptText;
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

      setFollowersPromptCopied(true);
      setTimeout(() => setFollowersPromptCopied(false), 2000);
    } catch (clipboardError) {
      setFollowersPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [followersPromptText]);

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-purple-500 to-indigo-600 bg-clip-text text-transparent">
          Discord Channel Summary
        </h1>

        <div className="mb-6 flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => setActiveTab("overview")}
            className={`rounded-md border px-4 py-2 text-sm font-medium ${
              activeTab === "overview"
                ? "border-purple-600 bg-purple-600 text-white"
                : "border-slate-300 bg-white text-slate-700 hover:bg-purple-50"
            }`}
          >
            Overview
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("followers")}
            className={`rounded-md border px-4 py-2 text-sm font-medium ${
              activeTab === "followers"
                ? "border-purple-600 bg-purple-600 text-white"
                : "border-slate-300 bg-white text-slate-700 hover:bg-purple-50"
            }`}
          >
            Follower Messages
          </button>
        </div>

        {/* Date Filter */}
        <div className="mb-6 max-w-md">
          <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
          <div className="flex items-center gap-2">
            <button
              type="button"
              aria-label="Previous day"
              onClick={() => {
                const d = new Date(observationDate);
                d.setDate(d.getDate() - 1);
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
              aria-label="Next day"
              onClick={() => {
                const d = new Date(observationDate);
                d.setDate(d.getDate() + 1);
                setObservationDate(d.toISOString().slice(0, 10));
              }}
              className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-purple-50"
            >
              →
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        {activeTab === "overview" && (
          <div className="mb-8">
            <div className="rounded-lg border border-slate-200 bg-white p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-slate-700">Market Intelligence Summary</h2>
                {cached && (
                  <span className="text-xs bg-blue-50 text-blue-700 px-2 py-1 rounded border border-blue-200">
                    Cached
                  </span>
                )}
              </div>

              <div className="flex flex-wrap items-center gap-3 mb-4">
                <select
                  value={selectedModel}
                  onChange={(e) => setSelectedModel(e.target.value)}
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40"
                >
                  <option value="google/gemini-2.5-flash">Gemini 2.5 Flash</option>
                  <option value="google/gemini-2.0-flash-thinking-exp:free">Gemini 2.0 Flash Thinking</option>
                  <option value="openai/gpt-4o-mini">GPT-4o Mini</option>
                  <option value="qwen/qwen-2.5-72b-instruct">Qwen 2.5 72B</option>
                  <option value="deepseek/deepseek-chat">DeepSeek Chat</option>
                  <option value="x-ai/grok-2-1212">Grok 2</option>
                </select>

                <button
                  onClick={() => fetchSummary(false)}
                  disabled={loading}
                  className="rounded-md bg-purple-600 text-white px-4 py-2 text-sm font-medium hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? "Generating..." : "Generate"}
                </button>

                <button
                  onClick={() => fetchSummary(true)}
                  disabled={loading}
                  className="rounded-md bg-orange-600 text-white px-4 py-2 text-sm font-medium hover:bg-orange-700 disabled:opacity-50"
                >
                  Regenerate
                </button>

                <button
                  onClick={fetchPrompt}
                  disabled={promptLoading}
                  className="rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-medium hover:bg-slate-50 disabled:opacity-50"
                >
                  {promptLoading ? "Loading..." : "Get Prompt"}
                </button>

                {promptText && (
                  <button
                    onClick={copyPromptToClipboard}
                    className="rounded-md border border-emerald-300 bg-emerald-50 text-emerald-700 px-4 py-2 text-sm font-medium hover:bg-emerald-100"
                  >
                    {promptCopied ? "Copied!" : "Copy"}
                  </button>
                )}
              </div>

              {promptMetadata && (
                <div className="mb-4 text-xs text-slate-600 bg-slate-50 px-3 py-2 rounded border border-slate-200">
                  Messages: {promptMetadata.messageCount} | Est. Tokens: {promptMetadata.estimatedTokens.toLocaleString()}
                </div>
              )}

              {promptError && (
                <div className="mb-4 text-sm text-red-600 bg-red-50 px-3 py-2 rounded border border-red-200">
                  {promptError}
                </div>
              )}

              {promptText && (
                <details className="mb-4">
                  <summary className="cursor-pointer text-sm font-medium text-slate-700 hover:text-slate-900">
                    View Prompt
                  </summary>
                  <pre className="mt-2 text-xs bg-slate-50 p-4 rounded border border-slate-200 overflow-x-auto max-h-96">
                    {promptText}
                  </pre>
                </details>
              )}

              {summary ? (
                <div className="prose prose-sm max-w-none">
                  <MarkdownRenderer content={summary} />
                </div>
              ) : (
                !loading && (
                  <div className="text-sm text-slate-500 text-center py-8">
                    Select a date and click Generate to create a Discord channel summary
                  </div>
                )
              )}
            </div>
          </div>
        )}

        {activeTab === "followers" && (
          <div className="mb-8 space-y-6">
            <div className="rounded-lg border border-slate-200 bg-white p-6">
              <div className="flex flex-wrap items-center gap-3">
                <select
                  value={followersModel}
                  onChange={(e) => setFollowersModel(e.target.value)}
                  className="rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-400/40"
                >
                  <option value="google/gemini-2.5-flash">Gemini 2.5 Flash</option>
                  <option value="google/gemini-2.0-flash-thinking-exp:free">Gemini 2.0 Flash Thinking</option>
                  <option value="openai/gpt-4o-mini">GPT-4o Mini</option>
                  <option value="qwen/qwen-2.5-72b-instruct">Qwen 2.5 72B</option>
                  <option value="deepseek/deepseek-chat">DeepSeek Chat</option>
                  <option value="x-ai/grok-2-1212">Grok 2</option>
                </select>

                <button
                  onClick={() => fetchFollowersSummary(false)}
                  disabled={followersLoading}
                  className="rounded-md bg-purple-600 text-white px-4 py-2 text-sm font-medium hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {followersLoading ? "Generating..." : "Generate"}
                </button>

                <button
                  onClick={() => fetchFollowersSummary(true)}
                  disabled={followersLoading}
                  className="rounded-md bg-orange-600 text-white px-4 py-2 text-sm font-medium hover:bg-orange-700 disabled:opacity-50"
                >
                  Regenerate
                </button>

                <button
                  onClick={fetchFollowersPrompt}
                  disabled={followersPromptLoading}
                  className="rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-medium hover:bg-slate-50 disabled:opacity-50"
                >
                  {followersPromptLoading ? "Loading..." : "Get Prompt"}
                </button>

                <button
                  onClick={copyFollowersPromptToClipboard}
                  className="rounded-md border border-emerald-300 bg-emerald-50 text-emerald-700 px-4 py-2 text-sm font-medium hover:bg-emerald-100"
                >
                  {followersPromptCopied ? "Copied!" : "Copy"}
                </button>
              </div>

              {followersPromptError && (
                <div className="mt-4 text-sm text-red-600 bg-red-50 px-3 py-2 rounded border border-red-200">
                  {followersPromptError}
                </div>
              )}
            </div>

            <div className="rounded-lg border border-slate-200 bg-white p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-slate-700">Followers Summary</h2>
                {followersCached && (
                  <span className="text-xs bg-blue-50 text-blue-700 px-2 py-1 rounded border border-blue-200">
                    Cached
                  </span>
                )}
              </div>

              {followersPromptMetadata && (
                <div className="mb-4 text-xs text-slate-600 bg-slate-50 px-3 py-2 rounded border border-slate-200">
                  Messages: {followersPromptMetadata.messageCount} | Est. Tokens:{" "}
                  {followersPromptMetadata.estimatedTokens.toLocaleString()}
                </div>
              )}

              {followersPromptText && (
                <details className="mb-4">
                  <summary className="cursor-pointer text-sm font-medium text-slate-700 hover:text-slate-900">
                    View Prompt
                  </summary>
                  <pre className="mt-2 text-xs bg-slate-50 p-4 rounded border border-slate-200 overflow-x-auto max-h-96">
                    {followersPromptText}
                  </pre>
                </details>
              )}

              {followersSummary ? (
                <div className="prose prose-sm max-w-none">
                  <MarkdownRenderer content={followersSummary} />
                </div>
              ) : (
                !followersLoading && (
                  <div className="text-sm text-slate-500 text-center py-8">
                    Select a date and click Generate to create a followers summary
                  </div>
                )
              )}
            </div>
          </div>
        )}

        {/* Information Section */}
        <div className="rounded-lg border border-slate-200 bg-white p-4">
          <h2 className="text-lg font-semibold mb-3 text-slate-700">About Discord Summaries</h2>
          <div className="text-sm text-slate-700 space-y-2">
            <p>
              Discord Channel Summary analyzes messages from multiple Discord channels to extract market-relevant
              insights, predictions, and overall sentiment.
            </p>
            <p>
              <strong>Key Features:</strong>
            </p>
            <ul className="list-disc pl-5 space-y-1">
              <li>Identifies stock market and financial market news discussed</li>
              <li>Tracks specific stock mentions, price targets, and trading ideas</li>
              <li>Records predictions with attribution (who said what and when)</li>
              <li>Analyzes overall bullish/bearish sentiment across community</li>
              <li>Highlights valuable insights and educational content</li>
              <li>Identifies most active and influential contributors</li>
            </ul>
            <p className="mt-3 text-xs text-slate-500 italic">
              Note: Summaries focus on actionable market intelligence and distinguish between data-driven analysis
              vs. casual speculation.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
