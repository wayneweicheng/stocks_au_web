"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

interface PredictionRow {
  [key: string]: any;
}

export default function PatternPredictionsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL as string;

  const [rows, setRows] = useState<PredictionRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const [minConfidence, setMinConfidence] = useState<string>("0.85");
  const [codesInput, setCodesInput] = useState<string>("");
  const [predictionDate, setPredictionDate] = useState<string>("");
  const [limit, setLimit] = useState<number>(50);

  const columns = useMemo(() => {
    if (rows.length === 0) return [] as string[];
    return Object.keys(rows[0]);
  }, [rows]);

  const truncate = (text: string | undefined, max: number) => {
    if (!text) return "";
    return text.length > max ? text.slice(0, max) + "…" : text;
  };

  const load = async () => {
    try {
      setLoading(true);
      setError("");

      const params = new URLSearchParams();
      if (minConfidence) params.set("min_confidence", minConfidence);
      if (codesInput) params.set("codes", codesInput);
      if (predictionDate) params.set("prediction_date", predictionDate);
      params.set("limit", String(limit));

      const url = `${baseUrl}/api/pattern-predictions?${params.toString()}`;
      const res = await authenticatedFetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setRows(data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Initial load with defaults
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Suggested field names; these may differ based on actual schema
  const FIELD = {
    date: "CreateDate", // or PredictionDate if present
    code: "ASXCode",
    confidence: "ConfidenceScore",
    effectiveConfidence: "EffectiveConfidence", // unknown; will display if exists
    dailyPattern: "DailyPattern",
    weeklyPattern: "WeeklyPattern",
    chartPath: "ChartPath",
  } as const;

  const visibleColumns = columns.filter((c) => [
    FIELD.date,
    FIELD.code,
    FIELD.confidence,
    FIELD.effectiveConfidence,
    FIELD.dailyPattern,
    FIELD.weeklyPattern,
    FIELD.chartPath,
  ].includes(c));

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          Pattern Predictions
        </h1>

        <div className="rounded-lg border border-slate-200 bg-white p-6 mb-6">
          <h2 className="text-lg font-semibold mb-4">Filters</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Prediction Date</label>
              <input
                type="date"
                value={predictionDate}
                onChange={(e) => setPredictionDate(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <div className="flex items-center justify-between">
                <label className="block text-sm mb-1 text-slate-600">ASX Codes</label>
                <span className="text-xs text-slate-500">Tip: comma-separated (e.g., LRV,BOB)</span>
              </div>
              <input
                type="text"
                value={codesInput}
                onChange={(e) => setCodesInput(e.target.value)}
                placeholder="e.g., LRV,BOB"
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Min Confidence (0–1)</label>
              <input
                type="number"
                step="0.01"
                min={0}
                max={1}
                value={minConfidence}
                onChange={(e) => setMinConfidence(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>

            <div>
              <label className="block text-sm mb-1 text-slate-600">Limit</label>
              <input
                type="number"
                min={1}
                max={2000}
                value={limit}
                onChange={(e) => setLimit(parseInt(e.target.value || "50"))}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
              />
            </div>
          </div>

          <div className="mt-4 flex gap-2">
            <button
              onClick={load}
              disabled={loading}
              className="rounded-md bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-400/40 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Loading..." : "Apply Filters"}
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          <div className="flex items-center justify-between p-4 pb-0">
            <h2 className="text-lg font-semibold">Results</h2>
            <div className="text-sm text-slate-600">{rows.length} rows</div>
          </div>

          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}

          {rows.length === 0 ? (
            <div className="p-6 text-center text-slate-500">No results.</div>
          ) : (
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 z-10 bg-white text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Prediction Date</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">ASX Code</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Confidence</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Effective Confidence</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Daily Pattern</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Weekly Pattern</th>
                  <th className="px-3 py-3 text-left font-medium whitespace-nowrap">Chart</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const dateVal = r[FIELD.date] || r["PredictionDate"] || "";
                  const asxCode = r[FIELD.code] || r["Ticker"] || r["Code"] || "";
                  const conf = r[FIELD.confidence];
                  const effConf = r[FIELD.effectiveConfidence];
                  const daily = r[FIELD.dailyPattern];
                  const weekly = r[FIELD.weeklyPattern];
                  const chartPath = r[FIELD.chartPath];

                  return (
                    <tr key={i} className={`transition-colors ${i % 2 ? "bg-slate-50" : ""} hover:bg-blue-50/40`}>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{dateVal ? new Date(dateVal).toLocaleString() : "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium">{asxCode || "-"}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{typeof conf === "number" ? conf.toFixed(3) : (conf ?? "-")}</td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">{typeof effConf === "number" ? effConf.toFixed(3) : (effConf ?? "-")}</td>
                      <td className="px-3 py-2 border-b border-slate-100 align-top">
                        <div className="whitespace-pre-wrap text-slate-700">{truncate(String(daily || ""), 200)}</div>
                      </td>
                      <td className="px-3 py-2 border-b border-slate-100 align-top">
                        <div className="whitespace-pre-wrap text-slate-700">{truncate(String(weekly || ""), 200)}</div>
                      </td>
                      <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100">
                        {chartPath ? (
                          <a
                            href="#"
                            onClick={(e) => {
                              e.preventDefault();
                              const href = `${baseUrl}/charts?path=${encodeURIComponent(String(chartPath))}`;
                              window.open(href, "_blank");
                            }}
                            className="inline-flex items-center gap-2 rounded-md border border-slate-300 px-3 py-1 text-xs hover:bg-slate-50"
                            title="Open chart in new tab"
                          >
                            <span>Open</span>
                          </a>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                    </tr>
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


