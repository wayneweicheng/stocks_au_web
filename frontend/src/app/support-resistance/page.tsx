"use client";

import { useCallback, useEffect, useMemo, useRef, useState, type UIEvent } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import MappedLevelReportDetails from "../components/MappedLevelReportDetails";
import { classifyMapZones, mapLineColor, mapLineWidth, mapAsOfTime, mapObservationDate, mapStockCode, mapZones, parseStockMap, reportAsAtClose, reportMatchesStock, reportTimeCategoryPosition, type MapZone, type ReportAsOfTime, type StockMapReport } from "./stockMapLevels";
import { clickedLevelPanelId, levelPanelId, type LevelTab } from "./chartLevelNavigation";
import { sortLevelEntries, topPercentEntries, type LevelSort } from "./levelSorting";
import { CHART_RANGE_OPTIONS, DEFAULT_CHART_DAYS, chartRangeParams, type ChartTimeframe } from "./chartRange";
import { chartLevelColor, chartMinimumWidth } from "./chartLayout";
import { priceBottomForScroll, priceWindowForBars } from "./priceViewport";

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
  const match = text.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
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

interface StockMapSelection {
  jobId: string;
  stockCode: string;
  stock_code: string;
  observationDate: string | null;
  asOfTime: ReportAsOfTime | null;
  generatedAtSydney: string | null;
  executionReference: number | null;
  executionReferenceType: string | null;
  asAtClose: { price: number; barTime: string } | null;
  bars: PriceBar[];
  supports: MapZone[];
  resistances: MapZone[];
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
  zone: Pick<PriceRange, "range_low" | "range_high">;
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

function ChartZoomHelp() {
  return <p className="mb-3 text-xs text-slate-500">Scroll left/right to see more candles. Zoom with the mouse wheel, drag a box over the chart, or use the + / − toolbar buttons. Double-click to reset. Click a colored level line or band to jump to its order links.</p>;
}

function focusLevelPanel(id: string) {
  const panel = document.getElementById(id);
  if (!panel) return;
  panel.scrollIntoView({ behavior: "smooth", block: "center" });
  panel.focus({ preventScroll: true });
}

function LevelSortControls({ mode, onChange, qualityLabel, distanceLabel, canSortByDistance }: {
  mode: LevelSort;
  onChange: (mode: LevelSort) => void;
  qualityLabel: string;
  distanceLabel: string;
  canSortByDistance: boolean;
}) {
  return <div role="group" aria-label="Sort levels" className="flex flex-wrap items-center gap-1 text-xs">
    <span className="mr-1 text-slate-500">Sort by</span>
    {(["quality", "distance"] as const).map((choice) => <button key={choice} type="button"
      aria-pressed={mode === choice} disabled={choice === "distance" && !canSortByDistance}
      onClick={() => onChange(choice)}
      className={`rounded border px-2 py-1 disabled:opacity-50 ${mode === choice ? "border-indigo-600 bg-indigo-600 text-white" : "border-slate-300 text-slate-600 hover:bg-indigo-50"}`}>
      {choice === "quality" ? qualityLabel : `Distance · ${distanceLabel}`}
    </button>)}
  </div>;
}

type LevelPercent = Record<"support" | "resistance", number>;

function StockMapPanels({ stock, percentBySide }: { stock: StockMapSelection; percentBySide: LevelPercent }) {
  const [sortBySide, setSortBySide] = useState<Record<"support" | "resistance", LevelSort>>({ support: "quality", resistance: "quality" });
  const latestClose = stock.bars.length ? stock.bars[stock.bars.length - 1].close : null;
  const distanceReference = latestClose !== null && Number.isFinite(latestClose) ? latestClose : null;
  return (
    <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
      {(["support", "resistance"] as const).map((side) => (
        <Card key={side}>
          <CardHeader className="flex flex-wrap items-center justify-between gap-2">
            <CardTitle className={side === "support" ? "text-emerald-700" : "text-red-700"}>{side === "support" ? "Support" : "Resistance"} Levels</CardTitle>
            <LevelSortControls mode={sortBySide[side]} onChange={(mode) => setSortBySide((current) => ({ ...current, [side]: mode }))}
              qualityLabel="Score · highest first" distanceLabel={distanceReference === null ? "unavailable" : `latest chart 30M close ${formatPrice(distanceReference)}`}
              canSortByDistance={distanceReference !== null} />
          </CardHeader>
          <CardContent className="space-y-3">
            {sortLevelEntries(topPercentEntries(side === "support" ? stock.supports : stock.resistances, percentBySide[side], (zone) => zone.score),
              sortBySide[side], distanceReference, (zone) => zone.score).map(({ level: zone, originalIndex }) => (
              <div key={`${side}-${zone.rank}-${originalIndex}`} id={levelPanelId("stock-map", side, originalIndex)} tabIndex={-1} className={`scroll-mt-24 rounded border p-3 focus:outline-none focus:ring-2 focus:ring-indigo-500 ${side === "support" ? "border-emerald-200 bg-emerald-50" : "border-red-200 bg-red-50"}`}>
                <div className="flex items-start justify-between gap-3">
                  <div className="font-semibold">${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}</div>
                  {stock.asAtClose ? <LevelActions zone={zone} tone={side} stockCode={stock.stockCode} /> : null}
                </div>
                <div className="mt-1 text-xs text-slate-700">Stock Map {zone.sourceSide === "support" ? "S" : "R"}{zone.rank}{zone.sourceSide !== side ? ` · Now ${side} vs as-at close` : ""} &bull; Score {zone.score === null ? "n/a" : zone.score.toFixed(1)} &bull; Strength {zone.strength}{zone.levelConfidence ? ` · ${zone.levelConfidence}` : ""}</div>
                {Array.isArray(zone.details.main_evidence) ? <div className="mt-1 text-xs text-slate-600">Matches: {zone.details.main_evidence.filter((item): item is string => typeof item === "string").join(" · ")}</div> : null}
                {zone.sourceSide !== side ? <div className="mt-1 text-xs text-slate-500">Details below retain the report&apos;s original {zone.sourceSide} terminology.</div> : null}
                <MappedLevelReportDetails side={zone.sourceSide} detail={undefined} rank={zone.rank} zone={zone.details} instrument="stock" />
              </div>
            ))}
            {(side === "support" ? stock.supports : stock.resistances).length === 0
              ? <div className="text-slate-500">No {side} levels {stock.asAtClose ? "relative to the as-at close" : "in this report"}</div>
              : percentBySide[side] === 0 ? <div className="text-slate-500">No {side} levels shown at 0%. Increase the {side} slider to see levels.</div> : null}
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

function LevelPanels({
  stock,
  stockCode,
  tab,
  referencePrice,
  referenceLabel,
  percentBySide,
}: {
  stock: {
    supports: PriceRange[];
    resistances: PriceRange[];
  };
  stockCode: string;
  tab: "calculated" | "database";
  referencePrice: number | null;
  referenceLabel: string;
  percentBySide: LevelPercent;
}) {
  const [sortBySide, setSortBySide] = useState<Record<"support" | "resistance", LevelSort>>({ support: "quality", resistance: "quality" });
  const distanceReference = referencePrice !== null && Number.isFinite(referencePrice) ? referencePrice : null;
  const ordered = (side: "support" | "resistance") => sortLevelEntries(
    topPercentEntries(stock[side === "support" ? "supports" : "resistances"], percentBySide[side],
      (zone) => zone.strength_rank > 0 ? zone.strength_rank : null, false),
    sortBySide[side], distanceReference, (zone) => zone.strength_rank > 0 ? zone.strength_rank : null, false);
  const controls = (side: "support" | "resistance") => <LevelSortControls mode={sortBySide[side]}
    onChange={(mode) => setSortBySide((current) => ({ ...current, [side]: mode }))}
    qualityLabel="Strength rank · best first" distanceLabel={distanceReference === null ? "unavailable" : `${referenceLabel} ${formatPrice(distanceReference)}`}
    canSortByDistance={distanceReference !== null} />;
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <Card>
        <CardHeader className="flex flex-wrap items-center justify-between gap-2">
          <CardTitle className="text-emerald-700">Support Levels</CardTitle>
          {controls("support")}
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {stock.supports.length > 0 ? (
              ordered("support").map(({ level: zone, originalIndex }) => (
                <div key={originalIndex} id={levelPanelId(tab, "support", originalIndex)} tabIndex={-1} className="scroll-mt-24 p-3 bg-emerald-50 rounded border border-emerald-200 focus:outline-none focus:ring-2 focus:ring-indigo-500">
                  <div className="flex items-start justify-between gap-3">
                    <div className="font-semibold text-emerald-900">
                      ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                    </div>
                    <LevelActions zone={zone} tone="support" stockCode={stockCode} />
                  </div>
                  <div className="text-xs text-emerald-700 mt-1">
                    Rank {zone.strength_rank || "n/a"} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                    {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                  </div>
                  <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                </div>
              ))
            ) : (
              <div className="text-slate-500">No support levels found</div>
            )}
            {stock.supports.length > 0 && percentBySide.support === 0 ? <div className="text-slate-500">No supports shown at 0%. Increase the support slider.</div> : null}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-wrap items-center justify-between gap-2">
          <CardTitle className="text-red-700">Resistance Levels</CardTitle>
          {controls("resistance")}
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {stock.resistances.length > 0 ? (
              ordered("resistance").map(({ level: zone, originalIndex }) => (
                <div key={originalIndex} id={levelPanelId(tab, "resistance", originalIndex)} tabIndex={-1} className="scroll-mt-24 p-3 bg-red-50 rounded border border-red-200 focus:outline-none focus:ring-2 focus:ring-indigo-500">
                  <div className="flex items-start justify-between gap-3">
                    <div className="font-semibold text-red-900">
                      ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                    </div>
                    <LevelActions zone={zone} tone="resistance" stockCode={stockCode} />
                  </div>
                  <div className="text-xs text-red-700 mt-1">
                    Rank {zone.strength_rank || "n/a"} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                    {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                  </div>
                  <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                </div>
              ))
            ) : (
              <div className="text-slate-500">No resistance levels found</div>
            )}
            {stock.resistances.length > 0 && percentBySide.resistance === 0 ? <div className="text-slate-500">No resistances shown at 0%. Increase the resistance slider.</div> : null}
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
  const chartScrollRef = useRef<HTMLDivElement>(null);
  const priceScrollRef = useRef<HTMLDivElement>(null);
  const plotlyRef = useRef<{ relayout: (element: HTMLDivElement, update: Record<string, unknown>) => Promise<unknown> } | null>(null);
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
  const [activeTab, setActiveTab] = useState<"calculated" | "stock-map" | "database">(() => {
    if (typeof window === "undefined") return "calculated";
    const tab = new URLSearchParams(window.location.search).get("tab");
    return tab === "database" || tab === "stock-map" ? tab : "calculated";
  });
  const [databaseData, setDatabaseData] = useState<SavedSupportResistanceResponse | null>(null);
  const [recordedHours, setRecordedHours] = useState<string[]>([]);
  const [selectedRecordedHour, setSelectedRecordedHour] = useState("");
  const [databaseLoading, setDatabaseLoading] = useState(false);
  const [databaseError, setDatabaseError] = useState("");
  const [mapReports, setMapReports] = useState<StockMapReport[]>([]);
  const [selectedMapJob, setSelectedMapJob] = useState("");
  const [mapData, setMapData] = useState<StockMapSelection | null>(null);
  const [mapLoading, setMapLoading] = useState(false);
  const [mapError, setMapError] = useState("");
  const mapRequest = useRef(0);
  // Changing this view must not recalculate levels or the Stock Map as-at 30M close.
  const [chartTimeframe, setChartTimeframe] = useState<ChartTimeframe>("30m");
  const [chartDays, setChartDays] = useState<Record<ChartTimeframe, number>>({ ...DEFAULT_CHART_DAYS });
  const [levelPercent, setLevelPercent] = useState<LevelPercent>({ support: 100, resistance: 100 });
  const [fetchedChartBars, setFetchedChartBars] = useState<{ source: object; timeframe: ChartTimeframe; days: number; bars: PriceBar[] } | null>(null);
  const [chartLoading, setChartLoading] = useState(false);
  const [chartError, setChartError] = useState("");
  const [priceReadout, setPriceReadout] = useState<{ bottom: number; top: number } | null>(null);

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

  const loadMapReport = useCallback(async (report: StockMapReport, code: string, requestId: number) => {
    setSelectedMapJob(report.job_id);
    setMapData(null);
    setMapLoading(true);
    setMapError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/stock-map-reports/${encodeURIComponent(report.job_id)}/json`, { cache: "no-store" });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload?.detail || `HTTP ${response.status}`);
      const map = parseStockMap(payload.data ?? payload);
      if (!map) throw new Error("The Stock Map JSON artifact was not returned in a readable format.");
      const reportedCode = mapStockCode(map);
      const requestedCode = code.trim().toUpperCase().replace(/\.(US|AX)$/i, "");
      if (!reportedCode || reportedCode !== requestedCode) throw new Error(`Report stock ${reportedCode || "unknown"} does not match ${requestedCode}.`);
      const asOfTime = mapAsOfTime(map, report);
      // PriceHistoryTimeFrame stores New York wall time, so use the ET as-of date.
      const observationDate = asOfTime?.easternWallTime.slice(0, 10) || mapObservationDate(map);
      const params = new URLSearchParams({ stock_code: requestedCode });
      if (observationDate) params.set("observation_date", observationDate);
      const barsResponse = await authenticatedFetch(`${baseUrl}/api/support-resistance/stock-map-bars?${params}`, { cache: "no-store" });
      const barsPayload = await barsResponse.json();
      if (!barsResponse.ok) throw new Error(barsPayload?.detail || `HTTP ${barsResponse.status}`);
      if (mapRequest.current !== requestId) return;
      const historicalBars: PriceBar[] = barsPayload.bars || [];
      const asAtClose = asOfTime ? reportAsAtClose(historicalBars, asOfTime.easternWallTime) : null;
      // The historical cutoff is for as-at classification only. Fetch chart
      // candles independently so later sessions are visible on a saved map.
      const chartParams = new URLSearchParams({ stock_code: requestedCode, timeframe: "30M", lookback_days: String(DEFAULT_CHART_DAYS["30m"]) });
      const chartResponse = await authenticatedFetch(`${baseUrl}/api/support-resistance/chart-bars?${chartParams}`, { cache: "no-store" });
      const chartPayload = await chartResponse.json();
      if (!chartResponse.ok) throw new Error(chartPayload?.detail || `HTTP ${chartResponse.status}`);
      if (mapRequest.current !== requestId) return;
      const bars: PriceBar[] = chartPayload.bars?.length ? chartPayload.bars : historicalBars;
      const reportSupports = mapZones(map, "support");
      const reportResistances = mapZones(map, "resistance");
      const zones = asAtClose ? classifyMapZones(reportSupports, reportResistances, asAtClose.price)
        : { supports: reportSupports, resistances: reportResistances };
      setMapData({ jobId: report.job_id, stockCode: requestedCode, stock_code: requestedCode, observationDate,
        asOfTime, asAtClose, bars, ...zones,
        generatedAtSydney: typeof map.generated_at_sydney === "string" ? map.generated_at_sydney : null,
        executionReference: typeof map.execution_reference === "number" && Number.isFinite(map.execution_reference) ? map.execution_reference : null,
        executionReferenceType: typeof map.execution_reference_type === "string" ? map.execution_reference_type : null,
      });
    } catch (exc) {
      if (mapRequest.current !== requestId) return;
      setMapError(exc instanceof Error ? exc.message : String(exc));
      setMapData(null);
    } finally {
      if (mapRequest.current === requestId) setMapLoading(false);
    }
  }, [baseUrl]);

  const loadMapReports = useCallback(async (code: string) => {
    const requestId = ++mapRequest.current;
    setMapReports([]);
    setSelectedMapJob("");
    setMapData(null);
    if (!code.trim()) { setMapError("Stock code is required"); return; }
    setMapLoading(true);
    setMapError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/stock-map-reports`, { cache: "no-store" });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload?.detail || `HTTP ${response.status}`);
      if (mapRequest.current !== requestId) return;
      const reports = ((payload.items || []) as StockMapReport[]).filter((item) => reportMatchesStock(item, code));
      setMapReports(reports);
      if (reports.length) await loadMapReport(reports[0], code, requestId);
      else setMapLoading(false);
    } catch (exc) {
      if (mapRequest.current !== requestId) return;
      setMapError(exc instanceof Error ? exc.message : String(exc));
      setMapLoading(false);
    }
  }, [baseUrl, loadMapReport]);

  useEffect(() => {
    if (!initialLoadStarted.current) {
      initialLoadStarted.current = true;
      const params = new URLSearchParams(window.location.search);
      const initialCode = params.get("stock") || "QQQ";
      const initialDateTime = params.get("observation_datetime") || params.get("as_at") || "";
      setObservationDateTime(initialDateTime);
      setStockCode(initialCode);
      if (activeTab === "database") void loadRecordedHours(initialCode);
      else if (activeTab === "stock-map") void loadMapReports(initialCode);
      else void loadData(initialCode, initialDateTime);
    }
  }, [activeTab, loadData, loadRecordedHours, loadMapReports]);

  useEffect(() => {
    return () => { activeRequest.current?.abort(); mapRequest.current++; };
  }, []);

  const chartData = activeTab === "calculated" ? data : activeTab === "database"
    ? databaseData?.found ? databaseData : null : mapData;
  const selectedDays = chartDays[chartTimeframe];
  const visibleBars = fetchedChartBars?.source === chartData && fetchedChartBars.timeframe === chartTimeframe && fetchedChartBars.days === selectedDays
    ? fetchedChartBars.bars
    : chartTimeframe === "30m" && activeTab === "stock-map" && selectedDays === DEFAULT_CHART_DAYS["30m"]
      ? chartData?.bars ?? null : null;
  const visibleChartLevels = useMemo(() => {
    if (!chartData) return null;
    const map = activeTab === "stock-map" ? mapData : null;
    const supports = map ? map.supports : "stock" in chartData ? chartData.stock.supports : [];
    const resistances = map ? map.resistances : "stock" in chartData ? chartData.stock.resistances : [];
    const quality = (zone: MapZone | PriceRange) => "score" in zone ? zone.score : zone.strength_rank > 0 ? zone.strength_rank : null;
    return {
      supports: topPercentEntries<MapZone | PriceRange>(supports, levelPercent.support, quality, Boolean(map)),
      resistances: topPercentEntries<MapZone | PriceRange>(resistances, levelPercent.resistance, quality, Boolean(map)),
    };
  }, [chartData, activeTab, mapData, levelPercent.support, levelPercent.resistance]);
  const priceWindow = useMemo(() => visibleBars?.length && visibleChartLevels
    ? priceWindowForBars(visibleBars, [...visibleChartLevels.supports, ...visibleChartLevels.resistances].map(({ level }) => level)) : null,
  [visibleBars, visibleChartLevels]);

  useEffect(() => {
    if (!chartData) return;
    // The Stock Map loader already fetched its default 20-day display window,
    // separately from the historical bars used for report as-at classification.
    if (activeTab === "stock-map" && chartTimeframe === "30m" && selectedDays === DEFAULT_CHART_DAYS["30m"]) {
      setChartLoading(false);
      setChartError("");
      return;
    }
    const params = chartRangeParams({ stockCode: chartData.stock_code, timeframe: chartTimeframe, days: selectedDays,
      source: activeTab, observationDatetime: activeTab === "calculated" ? data?.observation_datetime : null,
      observationDate: activeTab === "calculated" ? data?.observation_date : activeTab === "database" ? databaseData?.observation_date : null,
      mapAsOfUtc: activeTab === "database" ? databaseData?.map_as_of_at_utc : null });
    if (!params) {
      setFetchedChartBars(null);
      setChartLoading(false);
      setChartError("This saved map has no as-at date for a historical chart.");
      return;
    }
    const controller = new AbortController();
    setFetchedChartBars(null);
    setChartError("");
    setChartLoading(true);
    void authenticatedFetch(`${baseUrl}/api/support-resistance/chart-bars?${params}`, { cache: "no-store", signal: controller.signal })
      .then(async (response) => {
        const body = await response.json();
        if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
        return body as { bars: PriceBar[] };
      })
      .then((body) => { if (!controller.signal.aborted) setFetchedChartBars({ source: chartData, timeframe: chartTimeframe, days: selectedDays, bars: body.bars || [] }); })
      .catch((exc) => { if (!controller.signal.aborted) setChartError(exc instanceof Error ? exc.message : String(exc)); })
      .finally(() => { if (!controller.signal.aborted) setChartLoading(false); });
    return () => controller.abort();
  }, [chartTimeframe, selectedDays, chartData, activeTab, data, databaseData, baseUrl]);

  useEffect(() => {
    const viewport = chartScrollRef.current;
    if (viewport && visibleBars?.length) viewport.scrollLeft = viewport.scrollWidth; // start at the latest candles
  }, [visibleBars, chartTimeframe, activeTab]);

  useEffect(() => {
    plotlyRef.current = null; // wait for the new chart before applying a scroll event
    setPriceReadout(priceWindow ? { bottom: priceWindow.bottom, top: priceWindow.bottom + priceWindow.span } : null);
    if (priceWindow && priceScrollRef.current) priceScrollRef.current.scrollTop = priceWindow.initialScrollTop;
  }, [priceWindow]);

  const handlePriceScroll = (event: UIEvent<HTMLDivElement>) => {
    if (!priceWindow || !plotRef.current || !plotlyRef.current) return;
    const bottom = priceBottomForScroll(priceWindow, event.currentTarget.scrollTop);
    setPriceReadout({ bottom, top: bottom + priceWindow.span });
    void plotlyRef.current.relayout(plotRef.current, { "yaxis.range": [bottom, bottom + priceWindow.span] }).catch(() => undefined);
  };

  useEffect(() => {
    const isMap = activeTab === "stock-map";
    const mapChart = isMap ? mapData : null;
    const plotElement = plotRef.current;
    if (!chartData || !visibleBars?.length || !plotElement) return;

    let cancelled = false;
    let clickCleanup: (() => void) | undefined;

    void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
      if (cancelled || !plotElement) return;
      const Plotly = (plotlyModule as any).default || plotlyModule;
      const bars = visibleBars;
      const supports = visibleChartLevels?.supports || [];
      const resistances = visibleChartLevels?.resistances || [];
      const tab: LevelTab = isMap ? "stock-map" : activeTab === "database" ? "database" : "calculated";
      // Plotly click events identify the trace, not the price. Keep line and band
      // targets together so equal-price levels and reclassified Stock Map ranks work.
      const traceTargets: Array<string | null> = [null, null];
      const jumpToLevel = (event: { points?: Array<{ curveNumber?: number }> }) => {
        const id = clickedLevelPanelId(event, traceTargets);
        if (id) focusLevelPanel(id);
      };

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

      const escapeHover = (value: string) => value.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char] || char);
      const zoneHover = (zone: PriceRange | MapZone, side: string, index: number) => {
        const hint = `<br><b>Click to view level${mapChart && !mapChart.asAtClose ? " details" : " and order links"}</b>`;
        if ("score" in zone) return `<b>${side} Zone</b><br>Stock Map ${zone.sourceSide === "support" ? "S" : "R"}${zone.rank}${zone.sourceSide.toLowerCase() !== side.toLowerCase() ? ` (reclassified as ${side.toLowerCase()})` : ""}<br>Anchor: ${zone.price.toFixed(4)}<br>Range: ${zone.range_low.toFixed(4)} – ${zone.range_high.toFixed(4)}<br>Rank: ${zone.rank}<br>Score: ${zone.score === null ? "n/a" : zone.score.toFixed(1)}<br>Strength: ${escapeHover(zone.strength)}<br>${escapeHover(zone.levelConfidence)}<br>${escapeHover(Array.isArray(zone.details.main_evidence) ? zone.details.main_evidence.filter((item): item is string => typeof item === "string").join("; ") : "")}${hint}<extra></extra>`;
        return `<b>${side} Zone</b><br>Mid: ${zone.price.toFixed(4)}<br>Range Start: ${zone.range_low.toFixed(4)}<br>Range End: ${zone.range_high.toFixed(4)}<br>Strength Rank: ${zone.strength_rank || index + 1}<br>Touches: ${zone.touches}<br>Change From Reference Price: ${zone.distance_pct > 0 ? "+" : ""}${zone.distance_pct.toFixed(2)}%<br>ATR Distance: ${zone.distance_atr.toFixed(2)}${hint}<extra></extra>`;
      };

      // Support zones
      for (const { level: zone, originalIndex: index } of supports) {
        const lineColor = "score" in zone ? mapLineColor("support", zone.score) : chartLevelColor("support", index);
        const supportHover = zoneHover(zone, "Support", index);
        const target = levelPanelId(tab, "support", index);
        traceTargets.push(target, target);
        traces.push({
          x: bars.map((bar) => bar.time),
          y: bars.map(() => zone.price),
          type: "scatter",
          mode: "lines",
          name: `Support ${zone.price.toFixed(2)}`,
          text: bars.map(() => supportHover),
          line: {
            color: lineColor,
            width: "score" in zone ? mapLineWidth(zone.score) : Math.max(2, 5 - index),
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
      for (const { level: zone, originalIndex: index } of resistances) {
        const lineColor = "score" in zone ? mapLineColor("resistance", zone.score) : chartLevelColor("resistance", index);
        const resistanceHover = zoneHover(zone, "Resistance", index);
        const target = levelPanelId(tab, "resistance", index);
        traceTargets.push(target, target);
        traces.push({
          x: bars.map((bar) => bar.time),
          y: bars.map(() => zone.price),
          type: "scatter",
          mode: "lines",
          name: `Resistance ${zone.price.toFixed(2)}`,
          text: bars.map(() => resistanceHover),
          line: {
            color: lineColor,
            width: "score" in zone ? mapLineWidth(zone.score) : Math.max(2, 5 - index),
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

      const asOfPosition = mapChart?.asOfTime
        ? reportTimeCategoryPosition(bars, mapChart.asOfTime.easternWallTime) : null;
      const asOfLabel = mapChart?.asOfTime?.label;
      const markerPosition = asOfPosition !== null && asOfPosition >= 0 ? asOfPosition : null;
      const layout = {
        title: `${isMap ? mapChart?.stockCode : chartData.stock_code} - Support/Resistance (${chartTimeframe})`,
        xaxis: {
          title: "Time",
          type: "category",
          rangeslider: { visible: false },
          ...(markerPosition !== null && markerPosition >= bars.length
            ? { range: [-0.5, bars.length + 0.5] } : {}),
        },
        shapes: markerPosition === null ? [] : [{
          type: "line", xref: "x", yref: "paper",
          x0: markerPosition, x1: markerPosition, y0: 0, y1: 1,
          line: { color: "#7c3aed", width: 2, dash: "dash" },
        }],
        annotations: markerPosition === null ? [] : [{
          x: markerPosition, xref: "x", y: 1, yref: "paper", yanchor: "top",
          xanchor: markerPosition >= bars.length - 1 ? "right" : "left",
          text: `Map as-at<br>${asOfLabel}`,
          showarrow: false, bgcolor: "rgba(255,255,255,0.9)", bordercolor: "#7c3aed",
          borderpad: 4, font: { color: "#6d28d9", size: 11 },
        }],
        yaxis: {
          title: "Price (USD)",
          side: "left",
          domain: [0.22, 1],
          ...(priceWindow ? { range: [priceWindow.bottom, priceWindow.bottom + priceWindow.span] } : {}),
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
        showlegend: false, // The responsive legend is rendered below the scrollable plot.
        hovermode: "closest",
        dragmode: "zoom",
        template: "plotly_white",
        height: 860,
        margin: { l: 64, r: 90, t: 64, b: 120 },
      };

      void Plotly.newPlot(plotElement, traces, layout, {
        responsive: true,
        displayModeBar: true,
        displaylogo: false,
        scrollZoom: true,
        doubleClick: "reset",
      }).then(() => {
        if (!cancelled) {
          plotlyRef.current = Plotly;
          const graph = plotElement as HTMLDivElement & {
            on: (name: string, handler: (event: any) => void) => void;
            removeListener?: (name: string, handler: (event: any) => void) => void;
            _fullLayout?: { yaxis?: { range?: number[] } };
          };
          const updatePriceReadout = () => {
            const [bottom, top] = graph._fullLayout?.yaxis?.range || [];
            if (Number.isFinite(bottom) && Number.isFinite(top)) setPriceReadout((current) =>
              current?.bottom === bottom && current.top === top ? current : { bottom, top });
          };
          graph.on("plotly_click", jumpToLevel);
          graph.on("plotly_relayout", updatePriceReadout);
          clickCleanup = () => {
            graph.removeListener?.("plotly_click", jumpToLevel);
            graph.removeListener?.("plotly_relayout", updatePriceReadout);
          };
          updatePriceReadout();
        }
      }).catch((exc: unknown) => {
        if (!cancelled) {
          if (isMap) setMapError(exc instanceof Error ? exc.message : "Failed to render chart");
          else setError(exc instanceof Error ? exc.message : "Failed to render chart");
        }
      });
    }).catch((exc) => {
      if (isMap) setMapError(exc?.message || "Failed to load Plotly charting library");
      else setError(exc?.message || "Failed to load Plotly charting library");
    });

    return () => {
      cancelled = true;
      plotlyRef.current = null;
      clickCleanup?.();
      if (plotElement) {
        void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
          const Plotly = (plotlyModule as any).default || plotlyModule;
          Plotly.purge(plotElement);
        }).catch(() => undefined);
      }
    };
  }, [chartData, visibleBars, mapData, activeTab, chartTimeframe, visibleChartLevels, priceWindow]);

  const renderChart = (source: SupportResistanceResponse | SavedSupportResistanceResponse | StockMapSelection) => {
    const bars = chartData === source ? visibleBars : null;
    const mapOutsideWindow = activeTab === "stock-map" && mapData?.asOfTime && bars?.length
      ? (reportTimeCategoryPosition(bars, mapData.asOfTime.easternWallTime) ?? -1) < 0 : false;
    const levels = activeTab === "stock-map" && "jobId" in source ? source
      : "stock" in source ? source.stock : null;
    const visibleSide = (side: "support" | "resistance") => visibleChartLevels?.[side === "support" ? "supports" : "resistances"] || [];
    return <>
      <div className="mb-3 flex flex-wrap items-center gap-2" role="group" aria-label="Candlestick timeframe">
        <span className="mr-1 text-sm font-medium text-slate-700">Candles:</span>
        {(["30m", "5m"] as const).map((frame) => <button
          key={frame} type="button" aria-pressed={chartTimeframe === frame}
          onClick={() => setChartTimeframe(frame)}
          className={`rounded-md border px-3 py-1.5 text-sm font-medium ${chartTimeframe === frame ? "border-indigo-600 bg-indigo-600 text-white" : "border-slate-300 bg-white text-slate-600 hover:bg-slate-50"}`}
        >{frame === "30m" ? "30 min" : "5 min"}</button>)}
        <label className="ml-2 flex items-center gap-2 text-sm text-slate-700">Chart range
          <select aria-label="Chart range in calendar days" value={selectedDays}
            onChange={(event) => setChartDays((current) => ({ ...current, [chartTimeframe]: Number(event.target.value) }))}
            className="rounded border border-slate-300 bg-white px-2 py-1 text-sm">
            {CHART_RANGE_OPTIONS.map((days) => <option key={days} value={days}>{days} days</option>)}
          </select>
        </label>
        <span className="text-xs text-slate-500">Chart days are separate from level calculations and saved map as-at times.</span>
      </div>
      {levels ? <div className="mb-3 grid gap-3 rounded-md border border-slate-200 bg-slate-50 p-3 text-sm sm:grid-cols-2" role="group" aria-label="Filter chart and level cards by top percentage">
        {(["support", "resistance"] as const).map((side) => {
          const total = levels[side === "support" ? "supports" : "resistances"].length;
          const shown = visibleSide(side).length;
          const label = side === "support" ? "Supports" : "Resistances";
          return <label key={side} className="flex flex-col gap-1 text-slate-700">
            <span>{label}: top <strong>{levelPercent[side]}%</strong> by {activeTab === "stock-map" ? "score" : "strength rank"} · {shown} of {total}</span>
            <input type="range" min={0} max={100} step={1} value={levelPercent[side]}
              aria-label={`${label} top percentage`} onChange={(event) => setLevelPercent((current) => ({ ...current, [side]: Number(event.target.value) }))}
              className="w-full accent-indigo-600" />
          </label>;
        })}
        <p className="text-xs text-slate-500 sm:col-span-2">0% hides all levels; 100% shows all. Partial percentages round up to a whole level. Candles, level calculations and map as-at remain unchanged.</p>
      </div> : null}
      {activeTab === "stock-map" ? <p className="mb-2 text-xs text-slate-500">Candles show the latest {selectedDays} calendar days; the selected report’s as-at price and level classification remain historical.</p> : null}
      {mapOutsideWindow ? <Alert variant="info">Map as-at is outside the chart’s recent candle window. The historical as-at close is still used for level classification; the purple marker is not drawn in this window.</Alert> : null}
      {levels ? <details className="mb-3 text-sm text-slate-700">
        <summary className="cursor-pointer text-indigo-700">Jump to a level and its order links (keyboard accessible)</summary>
        <div className="mt-2 flex flex-wrap gap-2">
          {(["support", "resistance"] as const).flatMap((side) => visibleSide(side).map(({ level: zone, originalIndex }) => (
            <a key={`${side}-${originalIndex}`} href={`#${levelPanelId(activeTab as LevelTab, side, originalIndex)}`}
              className="rounded border border-slate-300 px-2 py-1 text-indigo-700 hover:bg-indigo-50">
              {side === "support" ? "Support" : "Resistance"} {zone.price.toFixed(2)}
            </a>
          )))}
        </div>
      </details> : null}
      {chartError ? <Alert variant="danger">Unable to load chart candles: {chartError}</Alert> : null}
      {bars === null ? (!chartError ? <div className="py-8 text-center text-slate-500">{chartLoading ? `Loading ${chartTimeframe} candles for ${selectedDays} days...` : "Waiting for chart data..."}</div> : null)
        : bars.length ? <>
          <ChartZoomHelp />
          {priceWindow && priceWindow.contentHeight > priceWindow.trackHeight ? <p className="mb-2 text-xs text-slate-600">Visible price: {formatPrice(priceReadout?.bottom ?? priceWindow.bottom)}–{formatPrice(priceReadout?.top ?? priceWindow.bottom + priceWindow.span)}. Use the right-hand vertical scrollbar to reveal older highs or lower supports.</p> : null}
          {activeTab === "stock-map" ? <p className="mb-2 text-xs text-slate-500">Stock Map: darker, thicker green/red lines indicate higher scores.</p> : null}
          <div className="flex min-w-0 items-start gap-2">
            <div ref={chartScrollRef} className="min-w-0 flex-1 overflow-x-auto rounded border border-slate-200" role="region" aria-label="Horizontally scrollable price chart" tabIndex={0}>
              <div key={`${activeTab}-${chartTimeframe}`} ref={plotRef}
                style={{ width: `max(100%, ${chartMinimumWidth(bars.length, chartTimeframe)}px)`, height: "860px" }} />
            </div>
            {priceWindow && priceWindow.contentHeight > priceWindow.trackHeight ? (
              <div className="flex w-7 shrink-0 flex-col items-center pt-16 text-xs text-slate-600" title="Scroll up for earlier higher prices; down for lower prices">
                <span aria-hidden="true">↑</span>
                <div ref={priceScrollRef} role="region" aria-label="Scroll price scale: up for higher prices" tabIndex={0}
                  onScroll={handlePriceScroll} className="w-5 overflow-y-scroll rounded border border-slate-300 bg-slate-50"
                  style={{ height: priceWindow.trackHeight }}>
                  <div style={{ height: priceWindow.contentHeight, width: 1 }} />
                </div>
                <span aria-hidden="true">↓</span>
              </div>
            ) : null}
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-slate-200 pt-3 text-xs text-slate-700" aria-label="Chart legend">
            <span className="inline-flex items-center gap-1"><span className="h-3 w-3 border border-emerald-600 bg-emerald-200" />Price candles</span>
            <span className="inline-flex items-center gap-1"><span className="h-3 w-3 bg-slate-400" />Volume</span>
            {levels ? (["support", "resistance"] as const).flatMap((side) => visibleSide(side).map(({ level: zone, originalIndex }) => (
              <button key={`${side}-${originalIndex}`} type="button" onClick={() => focusLevelPanel(levelPanelId(activeTab as LevelTab, side, originalIndex))}
                title={`Jump to ${side} ${zone.price.toFixed(2)}${"score" in zone ? ` · Score ${zone.score ?? "n/a"}` : ` · Rank ${zone.strength_rank || "n/a"}`}`}
                className="inline-flex items-center gap-1 rounded px-1 py-0.5 hover:bg-indigo-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-600">
                <span className="w-6 border-t-2" style={{ borderColor: "score" in zone ? mapLineColor(side, zone.score) : chartLevelColor(side, originalIndex) }} />
                {side === "support" ? "Support" : "Resistance"} {zone.price.toFixed(2)}
              </button>
            ))) : null}
          </div>
        </>
        : <div className="py-8 text-center text-slate-500">No {chartTimeframe === "5m" ? "5-minute" : "30-minute"} candles for this period</div>}
    </>;
  };

  return (
    <div className="space-y-6">
      <PageHeader title="Support / Resistance" subtitle="Interactive 30-minute candlestick chart and saved database support/resistance levels" />

      <div role="tablist" aria-label="Support and resistance sources" className="flex gap-1 rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "calculated"}
          onClick={() => {
            mapRequest.current++;
            setMapLoading(false);
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
          aria-selected={activeTab === "stock-map"}
          onClick={() => {
            setActiveTab("stock-map");
            window.history.replaceState(null, "", `?stock=${encodeURIComponent(stockCode)}&tab=stock-map`);
            void loadMapReports(stockCode);
          }}
          className={`rounded-md px-4 py-2 text-sm font-medium ${activeTab === "stock-map" ? "bg-indigo-600 text-white" : "text-slate-600 hover:bg-slate-50"}`}
        >
          Stock Map Levels
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "database"}
          onClick={() => {
            mapRequest.current++;
            setMapLoading(false);
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
                    else if (activeTab === "stock-map") void loadMapReports(stockCode);
                    else void loadData(stockCode);
                  }
                }}
                className="flex-1"
              />
              <Button
                onClick={() => {
                  if (activeTab === "database") void loadRecordedHours(stockCode);
                  else if (activeTab === "stock-map") void loadMapReports(stockCode);
                  else void loadData(stockCode);
                }}
                disabled={loading || databaseLoading || mapLoading || !stockCode.trim()}
              >
                {loading || databaseLoading || mapLoading ? "Loading..." : "Load"}
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
              ) : activeTab === "stock-map" ? (
                <div className="md:col-span-4">
                  <label className="text-sm font-medium text-slate-700">Stock Map Report</label>
                  <select
                    value={selectedMapJob}
                    onChange={(e) => {
                      const report = mapReports.find((item) => item.job_id === e.target.value);
                      if (report) void loadMapReport(report, stockCode, ++mapRequest.current);
                    }}
                    disabled={mapLoading || !mapReports.length}
                    className="mt-1 flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
                  >
                    {!mapReports.length ? <option value="">No reports for this stock</option> : null}
                    {mapReports.map((report) => <option key={report.job_id} value={report.job_id}>{report.title || report.file_name || report.job_id}{report.file_name && report.file_name !== report.title ? ` (${report.file_name})` : ""}</option>)}
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
                <label className="text-sm font-medium text-slate-700">Level calculation lookback days</label>
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

            {activeTab === "stock-map" && mapError ? <Alert variant="danger">Error: {mapError}</Alert> : null}
            {activeTab === "database" && databaseError ? <Alert variant="danger">Error: {databaseError}</Alert> : null}
            {activeTab === "calculated" && error ? <Alert variant="danger">Error: {error}</Alert> : null}
            {activeTab === "calculated" && data?.live_price_check && data.live_price_missing?.length ? (
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
            <CardContent>{renderChart(data)}</CardContent>
          </Card>

          <LevelPanels key={`${data.stock_code}-${data.observation_datetime || data.observation_date}`} stock={data.stock} stockCode={data.stock_code} tab="calculated" referencePrice={data.stock.reference_price} referenceLabel={priceSourceLabel(data.stock.price_source)} percentBySide={levelPercent} />
        </>
      )}

      {activeTab === "stock-map" && mapData ? (
        <>
          <Card>
            <CardHeader><CardTitle>Stock Map Report</CardTitle></CardHeader>
            <CardContent className="text-sm text-slate-700">
              <div>Report: {mapReports.find((report) => report.job_id === mapData.jobId)?.title || mapData.jobId}</div>
              <div>Observation date: {mapData.observationDate || "not specified"} · Chart: 30-minute candles</div>
              <div>Map as-at: {mapData.asOfTime?.label || "Timestamp unavailable in report"}{mapData.asOfTime ? " · Purple dashed line when inside the recent candle window (New York bar time)" : ""}</div>
              {mapData.generatedAtSydney ? <div>Report actually generated: {mapData.generatedAtSydney} (Sydney)</div> : null}
              {mapData.executionReference !== null ? <div>Report execution reference: {formatPrice(mapData.executionReference)} ({mapData.executionReferenceType?.replace(/_/g, " ") || "report reference"}{mapData.executionReferenceType === "completed_30m_bar" ? "; latest completed 30M bar at map as-at" : "; not the as-at market price"})</div> : null}
              {mapData.asAtClose ? (
                <div>As-at 30M close: {formatPrice(mapData.asAtClose.price)} (bar starting {mapData.asAtClose.barTime} New York). Levels below this price are supports; above are resistances. Matching anchors retain their report side.</div>
              ) : <div className="text-amber-700">No completed 30M bar at the report time. Showing original report sides; order links are unavailable.</div>}
              {mapData.asAtClose && mapData.resistances.length > 0 && mapData.resistances.every((zone) => zone.price > mapData.asAtClose!.price) && mapData.supports.length === 0 ? (
                <Alert variant="warning">The as-at 30M close is below every mapped anchor. Under the selected price-relative rule, all mapped levels are resistance, even those labelled support in the original report. {mapData.executionReferenceType === "prior_session_close" ? "The report uses the prior-session close as its execution reference, not the as-at market price." : mapData.executionReferenceType === "completed_30m_bar" ? "This report also uses a completed 30M bar as its execution reference." : "The report execution reference is not substituted for the as-at 30M close."}</Alert>
              ) : null}
              <a className="text-indigo-700 underline" href={`/stock-map-reports/${encodeURIComponent(mapData.jobId)}/mapped-levels?stock_code=${encodeURIComponent(mapData.stockCode)}`} target="_blank" rel="noopener noreferrer">Open full Stock Map details</a>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle>Interactive Chart</CardTitle></CardHeader>
            <CardContent>{renderChart(mapData)}</CardContent>
          </Card>
          <StockMapPanels key={mapData.jobId} stock={mapData} percentBySide={levelPercent} />
        </>
      ) : null}
      {activeTab === "stock-map" && !mapLoading && !mapError && !mapData ? <Card><CardContent><div className="py-8 text-center text-slate-500">No Stock Map reports for this stock</div></CardContent></Card> : null}

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
            <CardContent>{renderChart(databaseData)}</CardContent>
          </Card>
          <LevelPanels key={`${databaseData.stock_code}-${databaseData.matched_hour_utc}`} stock={databaseData.stock} stockCode={databaseData.stock_code} tab="database" referencePrice={databaseData.stock.reference_price} referenceLabel="saved reference" percentBySide={levelPercent} />
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

