"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

const LOOKBACK_DAY_OPTIONS = ["3", "5", "10", "20", "30"];
const SUPPORT_RESISTANCE_REQUEST_TIMEOUT_MS = 60000;

function formatPrice(value: number | null | undefined) {
  return typeof value === "number" && Number.isFinite(value) ? `$${value.toFixed(4)}` : "n/a";
}

function priceSourceLabel(source: string) {
  if (source === "ib_live") return "IB live";
  if (source === "ib_delayed") return "IB delayed";
  if (source === "as_at_30m_close") return "Closest earlier 30M close";
  return "Latest 30M close";
}

function getHtmlTitle(text: string) {
  const match = text.match(/<title[^>]*>(.*?)<\/title>/is);
  return match?.[1]?.replace(/\s+/g, " ").trim() || "";
}

function summarizeNonJsonResponse(text: string) {
  const title = getHtmlTitle(text);
  const stripped = text
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return title || stripped.slice(0, 180) || "The server returned a non-JSON response.";
}

function normalizeDateTimeLocal(value: string) {
  const trimmed = value.trim();
  if (!trimmed) return "";
  const date = new Date(trimmed);
  if (Number.isNaN(date.getTime())) return trimmed;
  const pad = (part: number) => String(part).padStart(2, "0");
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join("-") + `T${pad(date.getHours())}:${pad(date.getMinutes())}:00`;
}

interface PriceBar {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface PriceRange {
  price: number;
  range_low: number;
  range_high: number;
  touches: number;
  distance_pct: number;
  distance_atr: number;
  strength_rank: number;
  latest_touch: string | null;
  sources: Array<"30m" | "gamma">;
  gamma_wall: {
    strike: number;
    open_interest: number;
    nearest_expiry: string;
  } | null;
}

interface StockLevel {
  stock_code: string;
  database_code: string;
  latest_close: number;
  reference_price: number;
  distance_reference_price?: number;
  price_source: string;
  latest_bar_time: string;
  bar_count: number;
  median_bar_range: number;
  atr_daily: number | null;
  atr_period: number;
  implied_volatility: number | null;
  historical_volatility: number | null;
  iv_percentile: number | null;
  iv_rank: number | null;
  iv_history_count: number;
  trailing_pe: number | null;
  forward_pe: number | null;
  iv_source: string | null;
  iv_observation_date: string | null;
  supports: PriceRange[];
  resistances: PriceRange[];
}

interface SupportResistanceResponse {
  observation_date: string;
  observation_datetime: string | null;
  latest_available_date: string;
  recent_trading_dates: string[];
  live_price_check: boolean;
  live_price_missing: string[];
  lookback_days: number;
  atr_range: {
    minimum: number;
    maximum: number;
  };
  stock_code: string;
  stock: StockLevel;
  bars: PriceBar[];
}

interface SavedSupportResistanceResponse {
  stock_code: string;
  requested_stock_code: string;
  found: boolean;
  as_at: string | null;
  matched_hour_utc: string | null;
  map_generated_at_utc: string | null;
  map_as_of_at_utc: string | null;
  observation_date: string | null;
  bars: PriceBar[];
  method_version?: string | null;
  source_system?: string | null;
  stock: {
    stock_code: string;
    database_code: string | null;
    latest_close: number | null;
    reference_price: number | null;
    supports: PriceRange[];
    resistances: PriceRange[];
  };
}

interface RecordedHoursResponse {
  stock_code: string;
  hours: string[];
}

function LevelActions({
  zone,
  tone,
  stockCode,
}: {
  zone: PriceRange;
  tone: "support" | "resistance";
  stockCode: string;
}) {
  const rangeSide = tone === "support" ? "Buy" : "Sell";
  const optionAction = tone === "support" ? "SELL" : "BUY";
  const midpoint = (zone.range_low + zone.range_high) / 2;
  const rangeParams = new URLSearchParams({
    stock: stockCode,
    side: rangeSide,
    start: zone.range_low.toFixed(2),
    end: zone.range_high.toFixed(2),
  });
  const optionParams = new URLSearchParams({
    symbol: stockCode,
    right: "P",
    action: optionAction,
    target: midpoint.toFixed(2),
    auto: "1",
  });
  const shortDteOptionParams = new URLSearchParams({
    symbol: stockCode,
    right: "P",
    action: "SELL",
    target: midpoint.toFixed(2),
    auto: "1",
    min_dte: "5",
    max_dte: "7",
    bracket_exit_pct: "70",
  });

  return (
    <div className="flex shrink-0 items-center gap-1">
      <a
        href={`/range-orders?${rangeParams.toString()}`}
        target="_blank"
        rel="noopener noreferrer"
        title={`Open ${rangeSide.toLowerCase()} range order`}
        aria-label={`Open ${rangeSide.toLowerCase()} range order for ${stockCode}`}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-indigo-300 hover:bg-indigo-50 hover:text-indigo-700"
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
          <path d="M5 7h14M5 12h14M5 17h14" />
          <path d={tone === "support" ? "m8 10 4-4 4 4" : "m8 14 4 4 4-4"} />
        </svg>
      </a>
      <a
        href={`/option-orders?${optionParams.toString()}`}
        target="_blank"
        rel="noopener noreferrer"
        title={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order and estimate`}
        aria-label={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order for ${stockCode}`}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-violet-300 hover:bg-violet-50 hover:text-violet-700"
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
          <rect x="4" y="4" width="16" height="16" rx="3" />
          <path d="M9 16V8h3.5a2.5 2.5 0 0 1 0 5H9" />
        </svg>
      </a>
      {tone === "support" ? <a
        href={`/option-orders?${shortDteOptionParams.toString()}`}
        target="_blank"
        rel="noopener noreferrer"
        title={`Open short-dated sell put order for ${stockCode} (5–7 DTE, 70% bracket exit)`}
        aria-label={`Open short-dated sell put order for ${stockCode}, 5 to 7 DTE, 70 percent below entry bracket exit`}
        className="inline-flex h-7 min-w-8 items-center justify-center rounded border border-amber-200 bg-amber-50 px-1 text-[10px] font-bold leading-none text-amber-800 hover:border-amber-300 hover:bg-amber-100"
      >
        P<span className="ml-0.5 text-[8px]">5–7</span>
      </a> : null}
    </div>
  );
}

function LevelPanels({
  stock,
  stockCode,
}: {
  stock: {
    supports: PriceRange[];
    resistances: PriceRange[];
  };
  stockCode: string;
}) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <Card>
        <CardHeader>
          <CardTitle className="text-emerald-700">Support Levels</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {stock.supports.length > 0 ? (
              stock.supports.map((zone, idx) => (
                <div key={idx} className="p-3 bg-emerald-50 rounded border border-emerald-200">
                  <div className="flex items-start justify-between gap-3">
                    <div className="font-semibold text-emerald-900">
                      ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                    </div>
                    <LevelActions zone={zone} tone="support" stockCode={stockCode} />
                  </div>
                  <div className="text-xs text-emerald-700 mt-1">
                    Rank {zone.strength_rank || idx + 1} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                    {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                  </div>
                  <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                </div>
              ))
            ) : (
              <div className="text-slate-500">No support levels found</div>
            )}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-red-700">Resistance Levels</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {stock.resistances.length > 0 ? (
              stock.resistances.map((zone, idx) => (
                <div key={idx} className="p-3 bg-red-50 rounded border border-red-200">
                  <div className="flex items-start justify-between gap-3">
                    <div className="font-semibold text-red-900">
                      ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                    </div>
                    <LevelActions zone={zone} tone="resistance" stockCode={stockCode} />
                  </div>
                  <div className="text-xs text-red-700 mt-1">
                    Rank {zone.strength_rank || idx + 1} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                    {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                  </div>
                  <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                </div>
              ))
            ) : (
              <div className="text-slate-500">No resistance levels found</div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function SupportResistancePage() {
  const baseUrl = (process.env.NEXT_PUBLIC_BACKEND_URL || "");
  const initialLoadStarted = useRef(false);
  const plotRef = useRef<HTMLDivElement>(null);
  const activeRequest = useRef<AbortController | null>(null);
  const requestSequence = useRef(0);
  const [stockCode, setStockCode] = useState("");
  const [data, setData] = useState<SupportResistanceResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [lookbackDays, setLookbackDays] = useState("10");
  const [minimumAtr, setMinimumAtr] = useState("0.1");
  const [maximumAtr, setMaximumAtr] = useState("3");
  const [observationDateTime, setObservationDateTime] = useState("");
  const [activeTab, setActiveTab] = useState<"calculated" | "database">(() => {
    if (typeof window === "undefined") return "calculated";
    return new URLSearchParams(window.location.search).get("tab") === "database"
      ? "database"
      : "calculated";
  });
  const [databaseData, setDatabaseData] = useState<SavedSupportResistanceResponse | null>(null);
  const [recordedHours, setRecordedHours] = useState<string[]>([]);
  const [selectedRecordedHour, setSelectedRecordedHour] = useState("");
  const [databaseLoading, setDatabaseLoading] = useState(false);
  const [databaseError, setDatabaseError] = useState("");

  const loadData = useCallback(
    async (code: string, asAtDateTime = observationDateTime) => {
      if (!code.trim()) {
        setError("Stock code is required");
        return;
      }
      setLoading(true);
      setError("");
      activeRequest.current?.abort();
      const requestId = requestSequence.current + 1;
      requestSequence.current = requestId;
      const controller = new AbortController();
      activeRequest.current = controller;
      const timeoutId = window.setTimeout(() => controller.abort(), SUPPORT_RESISTANCE_REQUEST_TIMEOUT_MS);
      try {
        const minAtr = Number(minimumAtr);
        const maxAtr = Number(maximumAtr);
        const params = new URLSearchParams({
          stock_code: code.trim().toUpperCase(),
          lookback_days: String(Math.max(3, Math.min(30, Number(lookbackDays) || 10))),
          minimum_distance_atr: (Number.isFinite(minAtr) ? minAtr : 0.1).toFixed(2),
          maximum_distance_atr: (Number.isFinite(maxAtr) ? maxAtr : 3).toFixed(2),
          max_levels: "5",
          enable_live_prices: "true",
        });
        const normalizedAsAtDateTime = normalizeDateTimeLocal(asAtDateTime);
        if (normalizedAsAtDateTime) {
          params.set("observation_datetime", normalizedAsAtDateTime);
          params.set("enable_live_prices", "false");
        }
        const response = await authenticatedFetch(`${baseUrl}/api/support-resistance?${params}`, {
          cache: "no-store",
          signal: controller.signal,
        });
        const responseText = await response.text();
        const contentType = response.headers.get("content-type") || "";
        let body: any = null;
        if (responseText && contentType.toLowerCase().includes("application/json")) {
          body = JSON.parse(responseText);
        } else if (responseText) {
          try {
            body = JSON.parse(responseText);
          } catch {
            const summary = summarizeNonJsonResponse(responseText);
            throw new Error(`HTTP ${response.status} returned HTML instead of JSON: ${summary}`);
          }
        }
        if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
        if (requestSequence.current !== requestId) return;
        setData(body);
        setStockCode(body.stock_code);
      } catch (exc: any) {
        if (requestSequence.current !== requestId) return;
        if (exc?.name === "AbortError") {
          setError("Request timed out after 60 seconds. The support/resistance service is taking too long.");
        } else {
          setError(exc?.message || String(exc));
        }
        setData(null);
      } finally {
        window.clearTimeout(timeoutId);
        if (activeRequest.current === controller) {
          activeRequest.current = null;
          setLoading(false);
        }
      }
    },
    [baseUrl, lookbackDays, minimumAtr, maximumAtr, observationDateTime]
  );

  const loadDatabaseData = useCallback(
    async (code: string, recordedHour = selectedRecordedHour) => {
      if (!code.trim()) {
        setDatabaseError("Stock code is required");
        return;
      }
      setDatabaseLoading(true);
      setDatabaseError("");
      try {
        const params = new URLSearchParams({ stock_code: code.trim().toUpperCase() });
        if (recordedHour) params.set("recorded_hour", recordedHour);
        const response = await authenticatedFetch(`${baseUrl}/api/support-resistance/database?${params}`, {
          cache: "no-store",
        });
        const body = await response.json();
        if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
        setDatabaseData(body);
        setStockCode(body.stock_code || code.trim().toUpperCase());
      } catch (exc: any) {
        setDatabaseError(exc?.message || String(exc));
        setDatabaseData(null);
      } finally {
        setDatabaseLoading(false);
      }
    },
    [baseUrl, selectedRecordedHour]
  );

  const loadRecordedHours = useCallback(
    async (code: string) => {
      if (!code.trim()) {
        setDatabaseError("Stock code is required");
        return;
      }
      setDatabaseLoading(true);
      setDatabaseError("");
      try {
        const params = new URLSearchParams({ stock_code: code.trim().toUpperCase() });
        const response = await authenticatedFetch(`${baseUrl}/api/support-resistance/database-hours?${params}`, {
          cache: "no-store",
        });
        const body: RecordedHoursResponse = await response.json();
        if (!response.ok) throw new Error((body as any)?.detail || `HTTP ${response.status}`);
        setRecordedHours(body.hours || []);
        const firstHour = body.hours?.[0] || "";
        setSelectedRecordedHour(firstHour);
        if (firstHour) {
          await loadDatabaseData(code, firstHour);
        } else {
          setDatabaseData(null);
        }
      } catch (exc: any) {
        setDatabaseError(exc?.message || String(exc));
        setRecordedHours([]);
        setSelectedRecordedHour("");
        setDatabaseData(null);
      } finally {
        setDatabaseLoading(false);
      }
    },
    [baseUrl, loadDatabaseData]
  );

  useEffect(() => {
    if (!initialLoadStarted.current) {
      initialLoadStarted.current = true;
      const params = new URLSearchParams(window.location.search);
      const initialCode = params.get("stock") || "QQQ";
      const initialDateTime = params.get("observation_datetime") || params.get("as_at") || "";
      setObservationDateTime(initialDateTime);
      setStockCode(initialCode);
      if (activeTab === "database") {
        void loadRecordedHours(initialCode);
      } else {
        loadData(initialCode, initialDateTime);
      }
    }
  }, [activeTab, loadData, loadRecordedHours]);

  useEffect(() => {
    return () => activeRequest.current?.abort();
  }, []);

  useEffect(() => {
    const chartData = activeTab === "calculated"
      ? data
      : databaseData?.found
        ? databaseData
        : null;
    const plotElement = plotRef.current;
    if (!chartData?.bars || chartData.bars.length === 0 || !plotElement) return;

    let cancelled = false;

    void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
      if (cancelled || !plotElement) return;
      const Plotly = (plotlyModule as any).default || plotlyModule;
      const bars = chartData.bars;
      const stock = chartData.stock;
      const supports = stock.supports || [];
      const resistances = stock.resistances || [];
      const supportColors = ["#065f46", "#047857", "#10b981", "#34d399", "#6ee7b7"];
      const resistanceColors = ["#991b1b", "#b91c1c", "#ef4444", "#f87171", "#fca5a5"];

      const traces: any[] = [
        // Candlestick trace
        {
          x: bars.map((b) => b.time),
          open: bars.map((b) => b.open),
          high: bars.map((b) => b.high),
          low: bars.map((b) => b.low),
          close: bars.map((b) => b.close),
          type: "candlestick",
          name: "Price",
          yaxis: "y",
        },
        // Volume trace
        {
          x: bars.map((b) => b.time),
          y: bars.map((b) => b.volume),
          type: "bar",
          name: "Volume",
          yaxis: "y2",
          marker: { color: "rgba(100, 100, 100, 0.3)" },
        },
      ];

      // Support zones
      for (const [index, zone] of supports.entries()) {
        const lineColor = supportColors[Math.min(index, supportColors.length - 1)];
        const supportHover = `<b>Support Zone</b><br>Mid: ${zone.price.toFixed(4)}<br>Range Start: ${zone.range_low.toFixed(4)}<br>Range End: ${zone.range_high.toFixed(4)}<br>Strength Rank: ${zone.strength_rank || index + 1}<br>Touches: ${zone.touches}<br>Change From Reference Price: ${zone.distance_pct > 0 ? "+" : ""}${zone.distance_pct.toFixed(2)}%<br>ATR Distance: ${zone.distance_atr.toFixed(2)}<extra></extra>`;
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time],
          y: [zone.price, zone.price],
          type: "scatter",
          mode: "lines",
          name: `Support ${zone.price.toFixed(2)}`,
          text: [supportHover, supportHover],
          line: {
            color: lineColor,
            width: Math.max(2, 5 - index),
          },
          hoverinfo: "text",
          yaxis: "y",
        });

        // Range fill
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time, bars[bars.length - 1].time, bars[0].time],
          y: [zone.range_low, zone.range_low, zone.range_high, zone.range_high],
          type: "scatter",
          name: "",
          text: [supportHover, supportHover, supportHover, supportHover],
          fill: "toself",
          fillcolor: "rgba(34, 197, 94, 0.1)",
          line: { color: "rgba(34, 197, 94, 0)" },
          showlegend: false,
          hoveron: "fills",
          hoverinfo: "text",
          yaxis: "y",
        });
      }

      // Resistance zones
      for (const [index, zone] of resistances.entries()) {
        const lineColor = resistanceColors[Math.min(index, resistanceColors.length - 1)];
        const resistanceHover = `<b>Resistance Zone</b><br>Mid: ${zone.price.toFixed(4)}<br>Range Start: ${zone.range_low.toFixed(4)}<br>Range End: ${zone.range_high.toFixed(4)}<br>Strength Rank: ${zone.strength_rank || index + 1}<br>Touches: ${zone.touches}<br>Change From Reference Price: ${zone.distance_pct > 0 ? "+" : ""}${zone.distance_pct.toFixed(2)}%<br>ATR Distance: ${zone.distance_atr.toFixed(2)}<extra></extra>`;
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time],
          y: [zone.price, zone.price],
          type: "scatter",
          mode: "lines",
          name: `Resistance ${zone.price.toFixed(2)}`,
          text: [resistanceHover, resistanceHover],
          line: {
            color: lineColor,
            width: Math.max(2, 5 - index),
          },
          hoverinfo: "text",
          yaxis: "y",
        });

        // Range fill
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time, bars[bars.length - 1].time, bars[0].time],
          y: [zone.range_low, zone.range_low, zone.range_high, zone.range_high],
          type: "scatter",
          name: "",
          text: [resistanceHover, resistanceHover, resistanceHover, resistanceHover],
          fill: "toself",
          fillcolor: "rgba(239, 68, 68, 0.1)",
          line: { color: "rgba(239, 68, 68, 0)" },
          showlegend: false,
          hoveron: "fills",
          hoverinfo: "text",
          yaxis: "y",
        });
      }

      const layout = {
        title: `${chartData.stock_code || "Loading..."} - Support/Resistance (30m)`,
        xaxis: {
          title: "Time",
          type: "category",
          rangeslider: { visible: false },
        },
        yaxis: {
          title: "Price (USD)",
          side: "left",
          domain: [0.22, 1],
          fixedrange: false,
        },
        yaxis2: {
          title: "Volume",
          domain: [0, 0.14],
          side: "right",
          rangemode: "tozero",
          showgrid: false,
          tickformat: "~s",
        },
        legend: {
          x: 1.02,
          xanchor: "left",
          y: 1,
          yanchor: "top",
          bgcolor: "rgba(255,255,255,0.85)",
          bordercolor: "rgba(148,163,184,0.35)",
          borderwidth: 1,
          font: { size: 11 },
        },
        hovermode: "closest",
        template: "plotly_white",
        height: 860,
        margin: { l: 64, r: 190, t: 64, b: 64 },
      };

      Plotly.newPlot(plotElement, traces, layout, { responsive: true });
    }).catch((exc) => {
      setError(exc?.message || "Failed to load Plotly charting library");
    });

    return () => {
      cancelled = true;
      if (plotElement) {
        void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
          const Plotly = (plotlyModule as any).default || plotlyModule;
          Plotly.purge(plotElement);
        }).catch(() => undefined);
      }
    };
  }, [data, databaseData, activeTab]);

  return (
    <div className="space-y-6">
      <PageHeader title="Support / Resistance" subtitle="Interactive 30-minute candlestick chart and saved database support/resistance levels" />

      <div role="tablist" aria-label="Support and resistance sources" className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "calculated"}
          onClick={() => {
            setActiveTab("calculated");
            window.history.replaceState(null, "", "?stock=" + encodeURIComponent(stockCode) + (observationDateTime ? "&observation_datetime=" + encodeURIComponent(observationDateTime) : ""));
            if (stockCode.trim()) void loadData(stockCode);
          }}
          className={`rounded-md px-4 py-2 text-sm font-medium ${activeTab === "calculated" ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-50"}`}
        >
          Calculated 30M
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "database"}
          onClick={() => {
            setActiveTab("database");
            window.history.replaceState(null, "", `?stock=${encodeURIComponent(stockCode)}&tab=database`);
            void loadRecordedHours(stockCode);
          }}
          className={`rounded-md px-4 py-2 text-sm font-medium ${activeTab === "database" ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-50"}`}
        >
          Saved Database Levels
        </button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Stock Selection</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex gap-3">
              <Input
                placeholder="Enter stock code (e.g., QQQ, SPY, NVDA)"
                value={stockCode}
                onChange={(e) => setStockCode(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === "Enter") {
                    if (activeTab === "database") void loadRecordedHours(stockCode);
                    else void loadData(stockCode);
                  }
                }}
                className="flex-1"
              />
              <Button
                onClick={() => {
                  if (activeTab === "database") void loadRecordedHours(stockCode);
                  else void loadData(stockCode);
                }}
                disabled={loading || databaseLoading || !stockCode.trim()}
              >
                {loading || databaseLoading ? "Loading..." : "Load"}
              </Button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              {activeTab === "database" ? (
                <div className="md:col-span-2">
                  <label className="text-sm font-medium text-slate-700">Recorded Hour (UTC)</label>
                  <select
                    value={selectedRecordedHour}
                    onChange={(e) => {
                      setSelectedRecordedHour(e.target.value);
                      void loadDatabaseData(stockCode, e.target.value);
                    }}
                    disabled={databaseLoading || recordedHours.length === 0}
                    className="mt-1 flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                  >
                    {!recordedHours.length ? <option value="">No recorded hours</option> : null}
                    {recordedHours.map((hour) => (
                      <option key={hour} value={hour}>{new Date(`${hour}Z`).toLocaleString()}</option>
                    ))}
                  </select>
                </div>
              ) : (
                <div>
                  <label className="text-sm font-medium text-slate-700">As At</label>
                  <div className="mt-1 flex gap-2">
                    <Input
                      type="datetime-local"
                      value={observationDateTime}
                      onChange={(e) => setObservationDateTime(e.target.value)}
                    />
                    {observationDateTime ? (
                      <Button type="button" variant="secondary" onClick={() => setObservationDateTime("")}>
                        Clear
                      </Button>
                    ) : null}
                  </div>
                </div>
              )}
              {activeTab === "calculated" ? <>
              <div>
                <label className="text-sm font-medium text-slate-700">Lookback Days</label>
                <select
                  value={lookbackDays}
                  onChange={(e) => setLookbackDays(e.target.value)}
                  className="mt-1 flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
                >
                  {LOOKBACK_DAY_OPTIONS.map((days) => (
                    <option key={days} value={days}>{days}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Min ATR Distance</label>
                <Input
                  type="number"
                  step="0.05"
                  min="0"
                  max="10"
                  value={minimumAtr}
                  onChange={(e) => setMinimumAtr(e.target.value)}
                  className="mt-1"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Max ATR Distance</label>
                <Input
                  type="number"
                  step="0.05"
                  min="0"
                  max="10"
                  value={maximumAtr}
                  onChange={(e) => setMaximumAtr(e.target.value)}
                  className="mt-1"
                />
              </div>
              </> : null}
            </div>

            {activeTab === "database" && databaseError ? <Alert variant="danger">Error: {databaseError}</Alert> : null}
            {activeTab === "calculated" && error ? <Alert variant="danger">Error: {error}</Alert> : null}
            {data?.live_price_check && data.live_price_missing?.length ? (
              <Alert variant="warning">
                IB did not return a current price; using the latest 30-minute close as the reference price.
              </Alert>
            ) : null}
          </div>
        </CardContent>
      </Card>

      {activeTab === "calculated" && data && (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Chart Data</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                <div>
                  <div className="text-slate-500">Reference Price</div>
                  <div className="font-semibold">{formatPrice(data.stock.reference_price)}</div>
                  <div className="text-xs text-slate-500">{priceSourceLabel(data.stock.price_source)}</div>
                </div>
                <div>
                  <div className="text-slate-500">Latest 30M Close</div>
                  <div className="font-semibold">{formatPrice(data.stock.latest_close)}</div>
                  <div className="text-xs text-slate-500">{new Date(data.stock.latest_bar_time).toLocaleString()}</div>
                </div>
                <div>
                  <div className="text-slate-500">Bar Count</div>
                  <div className="font-semibold">{data.stock.bar_count}</div>
                </div>
                <div>
                  <div className="text-slate-500">ATR (Daily)</div>
                  <div className="font-semibold">{data.stock.atr_daily?.toFixed(4) || "n/a"}</div>
                </div>
                <div>
                  <div className="text-slate-500">Observation Date</div>
                  <div className="font-semibold text-xs">
                    {data.observation_datetime ? new Date(data.observation_datetime).toLocaleString() : data.observation_date}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Interactive Chart</CardTitle>
            </CardHeader>
            <CardContent>
              <div ref={plotRef} style={{ width: "100%", height: "860px" }} />
            </CardContent>
          </Card>

          <LevelPanels stock={data.stock} stockCode={data.stock_code} />
        </>
      )}

      {activeTab === "database" && databaseData && databaseData.found ? (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Saved Database Map</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4 text-sm">
                <div>
                  <div className="text-slate-500">Recorded Hour (UTC)</div>
                  <div className="font-semibold text-xs">
                    {databaseData.matched_hour_utc ? new Date(`${databaseData.matched_hour_utc}Z`).toLocaleString() : "n/a"}
                  </div>
                </div>
                <div>
                  <div className="text-slate-500">Map Generated</div>
                  <div className="font-semibold text-xs">
                    {databaseData.map_generated_at_utc ? new Date(`${databaseData.map_generated_at_utc}Z`).toLocaleString() : "n/a"}
                  </div>
                </div>
                <div>
                  <div className="text-slate-500">Map As Of</div>
                  <div className="font-semibold text-xs">
                    {databaseData.map_as_of_at_utc ? new Date(`${databaseData.map_as_of_at_utc}Z`).toLocaleString() : "n/a"}
                  </div>
                </div>
                <div>
                  <div className="text-slate-500">Reference Price</div>
                  <div className="font-semibold">{formatPrice(databaseData.stock.reference_price)}</div>
                </div>
                <div>
                  <div className="text-slate-500">Latest Close</div>
                  <div className="font-semibold">{formatPrice(databaseData.stock.latest_close)}</div>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Interactive Chart</CardTitle>
            </CardHeader>
            <CardContent>
              {databaseData.bars.length > 0 ? (
                <div ref={plotRef} style={{ width: "100%", height: "860px" }} />
              ) : (
                <div className="py-8 text-center text-slate-500">No chart data</div>
              )}
            </CardContent>
          </Card>
          <LevelPanels stock={databaseData.stock} stockCode={databaseData.stock_code} />
        </>
      ) : null}
      {activeTab === "database" && !databaseLoading && (!databaseData || !databaseData.found) ? (
        <Card>
          <CardContent>
            <div className="py-8 text-center text-slate-500">No data</div>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}

