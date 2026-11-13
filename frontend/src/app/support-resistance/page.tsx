"use client";

import { useCallback, useEffect, useMemo, useRef, useState, type UIEvent } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import MappedLevelReportDetails from "../components/MappedLevelReportDetails";
import { classifyMapZones, mapLineColor, mapLineWidth, mapAsOfTime, mapNextSessionStraddle, mapObservationDate, mapStockCode, mapZones, parseStockMap, reportAsAtClose, reportMatchesStock, reportTimeCategoryPosition, sortSpxMapReports, type MapZone, type NextSessionStraddle, type ReportAsOfTime, type StockMapReport } from "./stockMapLevels";
import { parseSpxMap, spxOptionObservationDate, spxOptionPair, spxOptionRangeForInstrument, spxPreviousCompletedClose, spxReportReference, type SpxOptionPair } from "./spxMapLevels";
import { matchedEsBasis } from "../spx-map-reports/[jobId]/mapped-levels/esBasis";
import { deriveSpxZones, effectivePriceForSpxInstrument, spxInstrumentForCode } from "./spxDerivedLevels";
import { clickedLevelPanelId, levelPanelId, type LevelTab } from "./chartLevelNavigation";
import { sortLevelEntries, topPercentEntries, type LevelSort } from "./levelSorting";
import { CHART_RANGE_OPTIONS, DEFAULT_CHART_DAYS, chartRangeParams, type ChartTimeframe } from "./chartRange";
import { chartLevelColor, chartMinimumWidth, spxExpiryRangeShape, straddleZoneShape } from "./chartLayout";
import { scoreYPosition } from "./chartScoreLabels";
import { chartMobileTicks } from "./chartMobileTicks";
import { priceBottomForScroll, priceWindowForBars } from "./priceViewport";

const LOOKBACK_DAY_OPTIONS = ["3", "5", "10", "20", "30"];
const SUPPORT_RESISTANCE_REQUEST_TIMEOUT_MS = 60000;

function formatPrice(value: number | null | undefined) {
  return typeof value === "number" && Number.isFinite(value) ? `$${value.toFixed(4)}` : "n/a";
}

function formatMapPrice(value: number | null | undefined, reportType: StockMapSelection["reportType"], instrument = "SPX") {
  if (reportType !== "spx-map") return formatPrice(value);
  if (instrument !== "SPX" && instrument !== "ESMain") return formatPrice(value);
  const label = instrument === "ESMain" ? "ES" : "SPX";
  return typeof value === "number" && Number.isFinite(value)
    ? `${label} ${value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : `${label} n/a`;
}

function formatSpxPriceWithEs(value: number, basis: number | null, includeSpxLabel = true) {
  const spx = includeSpxLabel ? formatMapPrice(value, "spx-map", "SPX")
    : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const es = basis !== null && Number.isFinite(basis) && Number.isFinite(value + basis) && value + basis > 0
    ? (value + basis).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    : null;
  return `${spx} (ES ${es ?? "n/a"})`;
}

function formatSpxPriceForDate(value: number, basis: number | null, basisDate: string | null, valueDate: string) {
  return formatSpxPriceWithEs(value, basisDate && basisDate === valueDate ? basis : null);
}

function formatSpxEvidenceWithEs(value: string, basis: number | null, basisDate: string | null, optionDate: string | null) {
  return value.replace(/\b((?:Daily|Weekly|Monthly) (?:CPR|PriorClose)|SPXW|SPY→SPX)\s+([\d,]+(?:\.\d+)?)/gi,
    (_match, label: string, rawPrice: string) => {
      const optionBasis = /^SPXW$/i.test(label) && (!optionDate || optionDate.slice(0, 10) !== basisDate) ? null : basis;
      return `${label} ${formatSpxPriceWithEs(Number(rawPrice.replace(/,/g, "")), optionBasis, !/^(?:SPXW|SPY→SPX)$/i.test(label))}`;
    });
}

function mappedAnchorPercent(value: unknown) {
  return typeof value === "number" && Number.isFinite(value)
    ? `(${value >= 0 ? "+" : ""}${value.toFixed(2)}%)` : "(n/a)";
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
  reportType: "stock-map" | "spx-map";
  stockCode: string;
  stock_code: string;
  observationDate: string | null;
  asOfTime: ReportAsOfTime | null;
  generatedAtSydney: string | null;
  executionReference: number | null;
  executionReferenceType: string | null;
  asAtClose: { price: number; barTime: string } | null;
  effectivePrice: number | null;
  livePrice: number | null;
  livePriceLoading: boolean;
  livePriceSource: string | null;
  livePriceFetchedAt: string | null;
  effectivePriceSource: string | null;
  effectivePriceTimestamp: string | null;
  spxEsMainPrice: number | null;
  spxEsBasis: number | null;
  spxEsBasisDate: string | null;
  nextSessionStraddle: NextSessionStraddle | null;
  spxOptions: SpxOptionPair | null;
  spxOptionObservationDate: string | null;
  spxEtfOrderLevels: Partial<Record<"SPY" | "SPXL" | "QQQ" | "TQQQ", MapZone[]>>;
  spxOptionLoading: boolean;
  spxOptionError: string | null;
  spxPreviousClose: number | null;
  sourceSpxReference: number | null;
  mappingSource: string | null;
  mappingError: string | null;
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

function SpxEtfLevelActions({ zone, tone, levels }: {
  zone: MapZone;
  tone: "support" | "resistance";
  levels: StockMapSelection["spxEtfOrderLevels"];
}) {
  const side = tone === "support" ? "Buy" : "Sell";
  const tickers = ["SPY", "SPXL", "QQQ", "TQQQ"] as const;
  return <div className="mt-2 flex flex-wrap items-center gap-1" aria-label={`${side} mapped ETF levels`}>
    {tickers.map((ticker) => {
      const mapped = levels[ticker]?.find((candidate) => candidate.rank === zone.rank && candidate.sourceSide === zone.sourceSide);
      if (!mapped) return <span key={ticker} title={`${ticker} mapped level unavailable`} className="rounded border border-slate-200 px-2 py-1 text-[10px] text-slate-400">{ticker} n/a</span>;
      const params = new URLSearchParams({ stock: ticker, side, start: mapped.range_low.toFixed(2), end: mapped.range_high.toFixed(2) });
      return <a key={ticker} href={`/range-orders?${params.toString()}`} target="_blank" rel="noopener noreferrer"
        aria-label={`Open ${side.toLowerCase()} ${ticker} range order, ${formatPrice(mapped.range_low)} to ${formatPrice(mapped.range_high)}`}
        title={`${side} ${ticker}: ${formatPrice(mapped.range_low)}–${formatPrice(mapped.range_high)}`}
        className={`rounded border px-2 py-1 text-[10px] font-semibold ${tone === "support" ? "border-emerald-200 bg-white text-emerald-800 hover:bg-emerald-50" : "border-red-200 bg-white text-red-800 hover:bg-red-50"}`}>
        {ticker} {side} · {formatPrice(mapped.range_low)}–{formatPrice(mapped.range_high)}
      </a>;
    })}
  </div>;
}

function ChartZoomHelp({ indexLevels = false, mobile = false }: { indexLevels?: boolean; mobile?: boolean }) {
  return <p className="mb-3 text-xs text-slate-500">{mobile ? "Pinch to zoom; use the toolbar to reset. The chart starts with a shorter range for readability." : "Scroll left/right to see more candles. Zoom with the mouse wheel, drag a box over the chart, or use the + / − toolbar buttons. Double-click to reset."} Click a colored level line or band to jump to its {indexLevels ? "SPX report details" : "order links"}.</p>;
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
                  <div className="font-semibold">{stock.reportType === "spx-map"
                  ? stock.stockCode === "SPX"
                    ? `${formatSpxPriceWithEs(zone.price, stock.spxEsBasis)} · zone ${formatSpxPriceWithEs(zone.range_low, stock.spxEsBasis)}–${formatSpxPriceWithEs(zone.range_high, stock.spxEsBasis)}`
                    : `${formatMapPrice(zone.price, stock.reportType, stock.stockCode)} · zone ${formatMapPrice(zone.range_low, stock.reportType, stock.stockCode)}–${formatMapPrice(zone.range_high, stock.reportType, stock.stockCode)}`
                  : `$${zone.price.toFixed(4)} - $${zone.range_low.toFixed(4)} to $${zone.range_high.toFixed(4)}`}</div>
                  {stock.asAtClose && stock.reportType === "stock-map" ? <LevelActions zone={zone} tone={side} stockCode={stock.stockCode} /> : null}
                </div>
                <div className="mt-1 text-xs text-slate-700">{stock.reportType === "spx-map" ? "SPX Map" : "Stock Map"} {zone.sourceSide === "support" ? "S" : "R"}{zone.rank}{zone.sourceSide !== side ? ` · Now ${side} vs as-at close` : ""} &bull; Score {zone.score === null ? "n/a" : zone.score.toFixed(1)} &bull; Strength {zone.strength}{zone.levelConfidence ? ` · ${zone.levelConfidence}` : ""}</div>
                {stock.reportType === "spx-map" && stock.stockCode !== "SPX" ? <>
                  <div className="mt-1 text-xs text-indigo-900">Mapped reference anchor (vs selected close): {formatMapPrice(zone.price, stock.reportType, stock.stockCode)} {mappedAnchorPercent(zone.details.mapped_anchor_vs_selected_close_pct)} vs selected 30M close {formatMapPrice(typeof zone.details.mapping_selected_close === "number" ? zone.details.mapping_selected_close : null, stock.reportType, stock.stockCode)} ({String(zone.details.mapping_selected_close_date || "date n/a")}).</div>
                  <div className="mt-1 text-xs text-indigo-900">Source SPX {typeof zone.details.source_spx_anchor === "number" ? zone.details.source_spx_anchor.toFixed(2) : "n/a"} · SPX zone {Array.isArray(zone.details.source_spx_range) ? zone.details.source_spx_range.map((value) => typeof value === "number" ? value.toFixed(2) : "n/a").join("–") : "n/a"}. {stock.mappingSource} Original SPX score/evidence; not target-instrument option positioning.</div>
                </> : null}
                {Array.isArray(zone.details.main_evidence) ? <div className="mt-1 text-xs text-slate-600">Matches: {zone.details.main_evidence.filter((item): item is string => typeof item === "string").map((item) => {
                  const optionValidation = zone.details.option_validation && typeof zone.details.option_validation === "object" && !Array.isArray(zone.details.option_validation)
                    ? zone.details.option_validation as Record<string, unknown> : null;
                  const optionDate = typeof optionValidation?.observation_date === "string" ? optionValidation.observation_date : null;
                  return stock.stockCode === "SPX" ? formatSpxEvidenceWithEs(item, stock.spxEsBasis, stock.spxEsBasisDate, optionDate) : item;
                }).join(" · ")}</div> : null}
                {zone.sourceSide !== side ? <div className="mt-1 text-xs text-slate-500">Details below retain the report&apos;s original {zone.sourceSide} terminology.</div> : null}
                {stock.reportType === "spx-map" && (stock.stockCode === "SPX" || stock.stockCode === "ESMain") ? <SpxEtfLevelActions zone={zone} tone={side} levels={stock.spxEtfOrderLevels} /> : null}
                <MappedLevelReportDetails side={zone.sourceSide} detail={undefined} rank={zone.rank} zone={zone.details} instrument={stock.reportType === "spx-map" ? "spx" : "stock"} spxLastClose={stock.spxPreviousClose} spxEsBasis={stock.stockCode === "SPX" ? stock.spxEsBasis : undefined} spxEsBasisDate={stock.stockCode === "SPX" ? stock.spxEsBasisDate : undefined} />
              </div>
            ))}
            {(side === "support" ? stock.supports : stock.resistances).length === 0
              ? <div className="text-slate-500">No {side} levels {stock.reportType === "spx-map" && stock.stockCode !== "SPX" ? "in the SPX source map" : stock.effectivePrice !== null ? "relative to the report as-of price" : "in this report"}</div>
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
    if (typeof window === "undefined") return "stock-map";
    const tab = new URLSearchParams(window.location.search).get("tab");
    return tab === "database" || tab === "calculated" ? tab : "stock-map";
  });
  const [databaseData, setDatabaseData] = useState<SavedSupportResistanceResponse | null>(null);
  const [recordedHours, setRecordedHours] = useState<string[]>([]);
  const [selectedRecordedHour, setSelectedRecordedHour] = useState("");
  const [databaseLoading, setDatabaseLoading] = useState(false);
  const [databaseError, setDatabaseError] = useState("");
  const [mapReports, setMapReports] = useState<StockMapReport[]>([]);
  const [todayReportStocks, setTodayReportStocks] = useState<string[]>([]);
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
  const [isMobileViewport, setIsMobileViewport] = useState(false);
  const mobileChartDefaultsApplied = useRef(false);

  useEffect(() => {
    const media = window.matchMedia("(max-width: 767px)");
    const updateViewport = () => {
      setIsMobileViewport(media.matches);
      if (media.matches && !mobileChartDefaultsApplied.current) {
        mobileChartDefaultsApplied.current = true;
        setChartDays((current) => ({ ...current, "30m": 5 }));
      }
    };
    updateViewport();
    media.addEventListener("change", updateViewport);
    return () => media.removeEventListener("change", updateViewport);
  }, []);

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
      const requestedCode = code.trim().toUpperCase().replace(/\.(US|AX)$/i, "");
      const spxInstrument = spxInstrumentForCode(requestedCode);
      const isSpx = spxInstrument !== null;
      const displayCode = spxInstrument || requestedCode;
      const reportType = isSpx ? "spx-map" : "stock-map";
      const livePriceParams = new URLSearchParams({ stock_code: displayCode });
      const livePriceRequest = authenticatedFetch(`${baseUrl}/api/stock-map-live-price?${livePriceParams}`, { cache: "no-store" })
        .then(async (liveResponse) => {
          const livePayload = await liveResponse.json();
          if (!liveResponse.ok) throw new Error(livePayload?.detail || `HTTP ${liveResponse.status}`);
          return livePayload as { live_price?: unknown; source?: unknown; price_time?: unknown; fetched_at_utc?: unknown };
        })
        .catch(() => null);
      const response = await authenticatedFetch(`${baseUrl}/api/${reportType}-reports/${encodeURIComponent(report.job_id)}/json`, { cache: "no-store" });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload?.detail || `HTTP ${response.status}`);
      const map = isSpx ? parseSpxMap(payload.data ?? payload) : parseStockMap(payload.data ?? payload);
      if (!map) throw new Error(`The ${isSpx ? "SPX Map" : "Stock Map"} JSON artifact was not returned in a readable format.`);
      if (!isSpx) {
        const reportedCode = mapStockCode(map);
        if (!reportedCode || reportedCode !== requestedCode) throw new Error(`Report stock ${reportedCode || "unknown"} does not match ${requestedCode}.`);
      }
      const asOfTime = mapAsOfTime(map, report);
      // PriceHistoryTimeFrame stores New York wall time, so use the ET as-of date.
      const observationDate = asOfTime?.easternWallTime.slice(0, 10) || mapObservationDate(map);
      const optionObservationDate = isSpx ? spxOptionObservationDate(map, observationDate) : null;
      const params = new URLSearchParams({ stock_code: displayCode });
      if (observationDate) params.set("observation_date", observationDate);
      // These reads are independent: as-at classification uses historicalBars,
      // while the chart can include later sessions. Fetch both concurrently.
      const chartParams = new URLSearchParams({ stock_code: displayCode, timeframe: "30M", lookback_days: String(DEFAULT_CHART_DAYS["30m"]) });
      const [barsResponse, chartResponse] = await Promise.all([
        authenticatedFetch(`${baseUrl}/api/support-resistance/stock-map-bars?${params}`, { cache: "no-store" }),
        authenticatedFetch(`${baseUrl}/api/support-resistance/chart-bars?${chartParams}`, { cache: "no-store" }),
      ]);
      const [barsPayload, chartPayload] = await Promise.all([barsResponse.json(), chartResponse.json()]);
      if (!barsResponse.ok) throw new Error(barsPayload?.detail || `HTTP ${barsResponse.status}`);
      if (!chartResponse.ok) throw new Error(chartPayload?.detail || `HTTP ${chartResponse.status}`);
      if (mapRequest.current !== requestId) return;
      const historicalBars: PriceBar[] = barsPayload.bars || [];
      const asAtClose = asOfTime ? reportAsAtClose(historicalBars, asOfTime.easternWallTime) : null;
      const bars: PriceBar[] = chartPayload.bars?.length ? chartPayload.bars : historicalBars;
      let reportSupports = mapZones(map, "support");
      let reportResistances = mapZones(map, "resistance");
      let mappingSource: string | null = null;
      let mappingError: string | null = null;
      const spxEtfOrderLevels: StockMapSelection["spxEtfOrderLevels"] = {};
      let effectivePrice = asAtClose?.price ?? null;
      let effectivePriceSource: string | null = asAtClose ? "Latest fully completed selected-instrument 30M bar at report as-of" : null;
      let effectivePriceTimestamp: string | null = asAtClose?.barTime ?? null;
      let spxEsMainPrice: number | null = null;
      let spxEsBasis: number | null = null;
      let spxEsBasisDate: string | null = null;
      let spxOptionReference: number | null = null;
      if (spxInstrument) {
        // All SPX/derived instruments use the same as-of history snapshot as
        // SPX Mapped Levels; never substitute current IB quotes for D-levels.
        if (!observationDate || !asOfTime) {
          mappingError = "Report as-of timestamp unavailable; effective price and reclassification cannot be calculated.";
          effectivePrice = null;
          if (spxInstrument !== "SPX") { reportSupports = []; reportResistances = []; }
        } else {
          try {
            const mappingParams = new URLSearchParams({ observation_date: observationDate, as_of_et: asOfTime.easternWallTime });
            const mappingResponse = await authenticatedFetch(`${baseUrl}/api/spx-map-prices?${mappingParams}`, { cache: "no-store" });
            const snapshot = await mappingResponse.json();
            if (!mappingResponse.ok) throw new Error(typeof snapshot?.detail === "string" ? snapshot.detail : `HTTP ${mappingResponse.status}`);
            effectivePrice = effectivePriceForSpxInstrument(spxInstrument, snapshot.effective_prices);
            const reportMatchedEsBasis = matchedEsBasis(snapshot);
            if ((spxInstrument === "SPX" || spxInstrument === "ESMain") && reportMatchedEsBasis !== null) {
              spxEsBasis = reportMatchedEsBasis;
              spxEsBasisDate = snapshot.historical_close_dates?.SPX || null;
              if (spxInstrument === "ESMain") spxEsMainPrice = effectivePrice;
              else if (effectivePrice !== null) spxEsMainPrice = effectivePrice + reportMatchedEsBasis;
            }
            const spxEffectivePrice = snapshot.effective_prices?.SPX;
            spxOptionReference = spxInstrument === "SPX" ? effectivePrice
              : spxInstrument === "ESMain" && typeof spxEffectivePrice === "number" && Number.isFinite(spxEffectivePrice) && spxEffectivePrice > 0
                ? spxEffectivePrice : null;
            if (spxInstrument) {
              const sourceZones = [...mapZones(map, "support"), ...mapZones(map, "resistance")];
              const prices = snapshot.effective_prices || {};
              for (const [ticker, instrument] of [["SPY", "SPY_D"], ["SPXL", "SPXL_D"], ["QQQ", "QQQ_D"], ["TQQQ", "TQQQ_D"]] as const) {
                const mapped = deriveSpxZones(sourceZones, instrument, snapshot, prices);
                if (mapped) spxEtfOrderLevels[ticker] = mapped.zones;
              }
            }
            const effectiveKey = spxInstrument === "SPX" ? "SPX" : spxInstrument === "ESMain" ? "ESMain" : spxInstrument.replace(/_D$/, "");
            effectivePriceSource = snapshot.effective_price_sources?.[effectiveKey] || snapshot.effective_price_source || null;
            effectivePriceTimestamp = snapshot.effective_price_timestamps?.[effectiveKey] || snapshot.effective_price_timestamp || null;
            if (effectivePrice === null) mappingError = `Effective ${effectiveKey} price unavailable at report as-of; no current quote substituted.`;
            if (spxInstrument !== "SPX") {
              // A failed projection must never leave original SPX prices on a
              // target axis. Preserve source zones only for report details.
              reportSupports = [];
              reportResistances = [];
              if (effectivePrice === null) {
                mappingError = `Effective ${effectiveKey} price unavailable at report as-of; no derived levels are shown.`;
              } else {
                const semiconductor = spxInstrument === "SOXL_D" || spxInstrument === "SOXX_D";
                if (semiconductor) {
                  const selectedDate = snapshot.historical_close_date;
                  if (typeof selectedDate !== "string" || !selectedDate) throw new Error("Selected SPX close date unavailable for semiconductor mapping.");
                  const extraParams = new URLSearchParams({ observation_date: selectedDate });
                  const extraResponse = await authenticatedFetch(`${baseUrl}/api/spx-map-extra-prices?${extraParams}`, { cache: "no-store" });
                  const extra = await extraResponse.json();
                  if (!extraResponse.ok) throw new Error(typeof extra?.detail === "string" ? extra.detail : `HTTP ${extraResponse.status}`);
                  if (extra.historical_close_source !== "30m_regular_session" || extra.historical_close_date !== selectedDate) throw new Error("Semiconductor 30M close source or selected date unavailable.");
                  snapshot.historical_closes = { ...snapshot.historical_closes, ...extra.historical_closes };
                  snapshot.historical_close_dates = { ...snapshot.historical_close_dates, ...extra.historical_close_dates };
                }
                const sourceZones = [...mapZones(map, "support"), ...mapZones(map, "resistance")];
                const projected = deriveSpxZones(sourceZones, spxInstrument, snapshot, snapshot.effective_prices || {});
                if (projected) {
                  reportSupports = projected.zones.filter((zone) => zone.sourceSide === "support");
                  reportResistances = projected.zones.filter((zone) => zone.sourceSide === "resistance");
                  mappingSource = projected.source;
                } else {
                  mappingError = `Matched report-date close anchors and effective ${effectiveKey}/SPY prices unavailable. No SPX price is plotted as a derived instrument price.`;
                }
              }
            }
          } catch (exc) {
            effectivePrice = null;
            spxEsMainPrice = null;
            spxEsBasis = null;
            spxEsBasisDate = null;
            spxOptionReference = null;
            mappingError = exc instanceof Error ? exc.message : String(exc);
            if (spxInstrument !== "SPX") { reportSupports = []; reportResistances = []; }
          }
        }
        if (mapRequest.current !== requestId) return;
      }
      // Every map is reclassified against the instrument's effective price at
      // its own report timestamp. A missing as-of price leaves source sides.
      const classificationPrice = spxInstrument ? effectivePrice : asAtClose?.price ?? null;
      const zones = classificationPrice !== null
        ? classifyMapZones(reportSupports, reportResistances, classificationPrice)
        : { supports: reportSupports, resistances: reportResistances };
      const spxReference = isSpx ? spxReportReference(map) : null;
      const needsSpxAtmOptions = spxInstrument === "SPX" || spxInstrument === "ESMain";
      const fetchSpxOptions = needsSpxAtmOptions && !!optionObservationDate && spxOptionReference !== null;
      setMapData({ jobId: report.job_id, reportType, stockCode: displayCode, stock_code: displayCode, observationDate,
        asOfTime, asAtClose, nextSessionStraddle: isSpx ? null : mapNextSessionStraddle(map), bars, ...zones,
        effectivePrice, livePrice: null, livePriceLoading: true, livePriceSource: null, livePriceFetchedAt: null,
        effectivePriceSource, effectivePriceTimestamp, spxEsMainPrice, spxEsBasis, spxEsBasisDate,
        spxOptions: null, spxOptionObservationDate: optionObservationDate, spxEtfOrderLevels, spxOptionLoading: fetchSpxOptions,
        spxOptionError: needsSpxAtmOptions && !fetchSpxOptions ? "SPX report as-of date or effective SPX reference unavailable; cannot select SPXW options." : null,
        spxPreviousClose: isSpx ? spxPreviousCompletedClose(map) : null,
        sourceSpxReference: spxReference, mappingSource, mappingError,
        generatedAtSydney: typeof map.generated_at_sydney === "string" ? map.generated_at_sydney : null,
        executionReference: isSpx ? spxInstrument === "SPX" ? spxReference : null : typeof map.execution_reference === "number" && Number.isFinite(map.execution_reference) ? map.execution_reference : null,
        executionReferenceType: typeof map.execution_reference_type === "string" ? map.execution_reference_type : null,
      });
      void livePriceRequest.then((livePayload) => {
        if (mapRequest.current !== requestId) return;
        const rawPrice = livePayload?.live_price;
        const livePrice = typeof rawPrice === "number" && Number.isFinite(rawPrice) && rawPrice > 0 ? rawPrice : null;
        setMapData((current) => {
          if (current?.jobId !== report.job_id) return current;
          const reclassified = livePrice === null ? { supports: current.supports, resistances: current.resistances }
            : classifyMapZones([...current.supports, ...current.resistances], [], livePrice);
          return {
            ...current,
            ...reclassified,
            livePrice,
            livePriceLoading: false,
            livePriceSource: typeof livePayload?.source === "string" ? livePayload.source : livePrice === null ? "Live quote unavailable" : null,
            livePriceFetchedAt: typeof livePayload?.price_time === "string" ? livePayload.price_time : typeof livePayload?.fetched_at_utc === "string" ? livePayload.fetched_at_utc : null,
          };
        });
      });
      // SPXW evidence is optional and can be unavailable pre-market. Do not
      // block an otherwise valid SPX chart or substitute an earlier SQL date.
      if (fetchSpxOptions) void (async () => {
        try {
          const optionParams = new URLSearchParams({ observation_date: optionObservationDate!, reference_price: String(spxOptionReference) });
          const optionResponse = await authenticatedFetch(`${baseUrl}/api/support-resistance/spx-map-options?${optionParams}`, { cache: "no-store" });
          const optionPayload = await optionResponse.json();
          if (!optionResponse.ok) throw new Error(typeof optionPayload?.detail === "string" ? optionPayload.detail : `HTTP ${optionResponse.status}`);
          const pair = spxOptionPair(optionPayload, optionObservationDate!);
          if (mapRequest.current === requestId) setMapData((current) => current?.jobId === report.job_id ? {
            ...current, spxOptions: pair, spxOptionLoading: false,
            spxOptionError: !pair && optionPayload.status === "available_historical_d1" ? "The SPXW call/put pair did not pass date, strike and expiry validation." : null,
          } : current);
        } catch (exc) {
          if (mapRequest.current === requestId) setMapData((current) => current?.jobId === report.job_id ? {
            ...current, spxOptionLoading: false, spxOptionError: exc instanceof Error ? exc.message : String(exc),
          } : current);
        }
      })();
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
      const isSpx = spxInstrumentForCode(code) !== null;
      const response = await authenticatedFetch(`${baseUrl}/api/${isSpx ? "spx-map" : "stock-map"}-reports`, { cache: "no-store" });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload?.detail || `HTTP ${response.status}`);
      if (mapRequest.current !== requestId) return;
      const allReports = (payload.items || []) as StockMapReport[];
      const sydneyDate = new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Sydney", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
      const todaysReports = allReports.flatMap((item) => {
        if (item.status !== "succeeded" || !item.created_at) return [];
        const availableAt = new Date(item.created_at);
        if (Number.isNaN(availableAt.getTime()) || new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Sydney", year: "numeric", month: "2-digit", day: "2-digit" }).format(availableAt) !== sydneyDate) return [];
        const raw = item.raw || {};
        const codeFromMetadata = [item.stock_code, raw.stock_code, raw.instrument_code, raw.ticker, raw.symbol].find((value) => typeof value === "string" && value.trim());
        const reportCode = (typeof codeFromMetadata === "string" ? codeFromMetadata : [item.title, item.file_name].find((value) => typeof value === "string")?.match(/^[A-Z0-9.^-]+(?=[:\\s_])/i)?.[0] || "").trim().toUpperCase().replace(/\\.(US|AX)$/i, "");
        return reportCode ? [{ reportCode, availableAt: availableAt.getTime() }] : [];
      }).sort((a, b) => a.availableAt - b.availableAt);
      setTodayReportStocks([...new Set(todaysReports.map((item) => item.reportCode))].slice(0, 10));
      const reports = allReports.filter((item) => isSpx
        ? item.status === "succeeded" : reportMatchesStock(item, code));
      const orderedReports = isSpx ? sortSpxMapReports(reports) : reports;
      setMapReports(orderedReports);
      if (orderedReports.length) await loadMapReport(orderedReports[0], code, requestId);
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
      const initialCode = params.get("stock") || "ESMain";
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
  const mapAtmRange = useMemo(() => activeTab === "stock-map" && mapData?.spxOptions
    ? spxOptionRangeForInstrument(mapData.spxOptions, mapData.stockCode, mapData.spxEsBasis) : null,
  [activeTab, mapData?.spxOptions, mapData?.stockCode, mapData?.spxEsBasis]);
  const priceWindow = useMemo(() => {
    if (!visibleBars?.length || !visibleChartLevels) return null;
    const zones: Array<{ price: number; range_low: number; range_high: number }> =
      [...visibleChartLevels.supports, ...visibleChartLevels.resistances].map(({ level }) => level);
    const range = activeTab === "stock-map" ? mapData?.nextSessionStraddle?.nextSessionRange : null;
    const spxExpiryRange = mapAtmRange;
    if (range) zones.push({ price: (range.low + range.high) / 2, range_low: range.low, range_high: range.high });
    if (spxExpiryRange) zones.push({ price: (spxExpiryRange.low + spxExpiryRange.high) / 2, range_low: spxExpiryRange.low, range_high: spxExpiryRange.high });
    if (activeTab === "stock-map" && typeof mapData?.livePrice === "number" && Number.isFinite(mapData.livePrice) && mapData.livePrice > 0) {
      zones.push({ price: mapData.livePrice, range_low: mapData.livePrice, range_high: mapData.livePrice });
    }
    return priceWindowForBars(visibleBars, zones);
  }, [visibleBars, visibleChartLevels, activeTab, mapData]);

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
      const formatLevelPrice = (price: number) => mapChart?.reportType === "spx-map" && mapChart.stockCode === "SPX"
        ? formatSpxPriceWithEs(price, mapChart.spxEsBasis) : price.toFixed(4);
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
      if (mapChart && typeof mapChart.livePrice === "number" && Number.isFinite(mapChart.livePrice) && mapChart.livePrice > 0) {
        const livePriceText = `<b>Selected price</b><br>${formatMapPrice(mapChart.livePrice, mapChart.reportType, mapChart.stockCode)}${mapChart.livePriceSource ? `<br>${escapeHover(mapChart.livePriceSource)}` : ""}${mapChart.livePriceFetchedAt ? `<br>${escapeHover(mapChart.livePriceFetchedAt)}` : ""}<extra></extra>`;
        traces.push({
          x: bars.map((bar) => bar.time),
          y: bars.map(() => mapChart.livePrice),
          type: "scatter",
          mode: "lines",
          name: "Live price",
          text: bars.map(() => livePriceText),
          line: { color: "#2563eb", width: 2.5, dash: "dot" },
          hoverinfo: "text",
          yaxis: "y",
        });
      }

      const zoneHover = (zone: PriceRange | MapZone, side: string, index: number) => {
        const hint = `<br><b>Click to view level${mapChart?.reportType === "spx-map" || (mapChart && !mapChart.asAtClose) ? " details" : " and order links"}</b>`;
        if (isMobileViewport) return `<b>${escapeHover(side)} zone</b><br>Anchor ${formatLevelPrice(zone.price)} · range ${formatLevelPrice(zone.range_low)}–${formatLevelPrice(zone.range_high)}${"score" in zone && zone.score !== null ? `<br>Score ${zone.score.toFixed(1)}` : ""}${hint}<extra></extra>`;
        if ("score" in zone) {
          const sourceRange = zone.details.source_spx_range;
          const sourceAnchor = zone.details.source_spx_anchor;
          const origin = mapChart?.reportType === "spx-map" && mapChart.stockCode !== "SPX" &&
            Array.isArray(sourceRange) && sourceRange.length === 2 && typeof sourceAnchor === "number"
            ? `<br>Source SPX: ${sourceAnchor.toFixed(2)} · zone ${Number(sourceRange[0]).toFixed(2)}–${Number(sourceRange[1]).toFixed(2)} (SPX score/evidence)` : "";
          const selectedClose = zone.details.mapping_selected_close;
          const closeDate = zone.details.mapping_selected_close_date;
          const mappedReference = mapChart?.reportType === "spx-map" && mapChart.stockCode !== "SPX" &&
            typeof selectedClose === "number" && Number.isFinite(selectedClose) && selectedClose > 0
            ? `<br>Mapped reference anchor (vs selected close): ${zone.price.toFixed(2)} ${mappedAnchorPercent(zone.details.mapped_anchor_vs_selected_close_pct)} vs ${selectedClose.toFixed(2)} (selected 30M close ${typeof closeDate === "string" ? escapeHover(closeDate) : "date n/a"})` : "";
          const validation = zone.details.option_validation;
          const option = validation && typeof validation === "object" && !Array.isArray(validation)
            ? validation as Record<string, unknown> : null;
          const oi = typeof option?.oi_contracts === "number" && Number.isFinite(option.oi_contracts) ? ` · OI ${option.oi_contracts.toLocaleString()}` : "";
          const wall = typeof option?.wall_type === "string" ? ` ${escapeHover(option.wall_type)}` : "";
          const expiries = Array.isArray(option?.expiry_dates) ? ` · Expiries ${escapeHover(option.expiry_dates.filter((date): date is string => typeof date === "string").join(", "))}` : "";
          const observed = typeof option?.observation_date === "string" ? ` · Observed ${escapeHover(option.observation_date)}` : "";
          const gex = typeof option?.absolute_gex_at_strike === "number" && Number.isFinite(option.absolute_gex_at_strike)
            ? ` · |GEX| ${Math.abs(option.absolute_gex_at_strike).toLocaleString()} (size only)` : "";
          const optionText = mapChart?.reportType === "spx-map" && option && (oi || wall) ? `<br>SPXW source${wall}${oi}${gex}${expiries}${observed}` : "";
          return `<b>${side} Zone</b><br>${mapChart?.reportType === "spx-map" ? "SPX Map" : "Stock Map"} ${zone.sourceSide === "support" ? "S" : "R"}${zone.rank}${zone.sourceSide.toLowerCase() !== side.toLowerCase() ? ` (reclassified as ${side.toLowerCase()})` : ""}<br>Anchor: ${formatLevelPrice(zone.price)}<br>Range: ${formatLevelPrice(zone.range_low)} – ${formatLevelPrice(zone.range_high)}<br>Rank: ${zone.rank}<br>Score: ${zone.score === null ? "n/a" : zone.score.toFixed(1)}<br>Strength: ${escapeHover(zone.strength)}<br>${escapeHover(zone.levelConfidence)}<br>${escapeHover(Array.isArray(zone.details.main_evidence) ? zone.details.main_evidence.filter((item): item is string => typeof item === "string").slice(0, 2).join("; ").slice(0, 160) : "")}${mappedReference}${origin}${optionText}${hint}<extra></extra>`;
        }
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
          name: `Support ${formatLevelPrice(zone.price)}`,
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
          name: `Resistance ${formatLevelPrice(zone.price)}`,
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

      const spxAtmRange = mapChart?.spxOptions
        ? spxOptionRangeForInstrument(mapChart.spxOptions, mapChart.stockCode, mapChart.spxEsBasis) : null;
      const asOfPosition = mapChart?.asOfTime
        ? reportTimeCategoryPosition(bars, mapChart.asOfTime.easternWallTime) : null;
      const asOfLabel = mapChart?.asOfTime?.label;
      const markerPosition = asOfPosition !== null && asOfPosition >= 0 ? asOfPosition : null;
      const layout = {
        title: isMobileViewport
          ? `${isMap ? mapChart?.stockCode : chartData.stock_code} · S/R · ${chartTimeframe}`
          : `${isMap ? mapChart?.stockCode : chartData.stock_code} - Support/Resistance (${chartTimeframe})`,
        xaxis: {
          title: "Time",
          type: "category",
          rangeslider: { visible: false },
          ...chartMobileTicks(bars, isMobileViewport ? 5 : 8),
          ...(isMobileViewport ? { tickangle: 0, tickfont: { size: 10 } } : {}),
          // Plotly's category autorange can reserve a large empty region after
          // the last candle. Bound it to the loaded bars (or one extra slot
          // when the saved map's as-at marker lies beyond the last bar).
          ...(markerPosition !== null && markerPosition >= bars.length
            ? { range: [-0.5, bars.length + 0.5] }
            : { range: [-0.5, bars.length - 0.5] }),
        },
        shapes: [
          ...(mapChart?.nextSessionStraddle ? [straddleZoneShape(mapChart.nextSessionStraddle.nextSessionRange)] : []),
          ...(spxAtmRange ? [spxExpiryRangeShape(spxAtmRange)] : []),
          ...(markerPosition === null ? [] : [{
            type: "line", xref: "x", yref: "paper",
            x0: markerPosition, x1: markerPosition, y0: 0, y1: 1,
            line: { color: "#7c3aed", width: 2, dash: "dash" },
          }]),
        ],
        annotations: [
          ...(markerPosition === null ? [] : [{
            x: markerPosition, xref: "x", y: 1, yref: "paper", yanchor: "top",
            xanchor: markerPosition >= bars.length - 1 ? "right" : "left",
            text: `Map as-at<br>${asOfLabel}`,
            showarrow: false, bgcolor: "rgba(255,255,255,0.9)", bordercolor: "#7c3aed",
            borderpad: 4, font: { color: "#6d28d9", size: 11 },
          }]),
        ],
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
        height: isMobileViewport ? 560 : 860,
        margin: isMobileViewport ? { l: 48, r: 46, t: 62, b: 90 } : { l: 64, r: 56, t: 64, b: 120 },
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
  }, [chartData, visibleBars, mapData, activeTab, chartTimeframe, visibleChartLevels, priceWindow, isMobileViewport]);

  const renderChart = (source: SupportResistanceResponse | SavedSupportResistanceResponse | StockMapSelection) => {
    const bars = chartData === source ? visibleBars : null;
    const mapOutsideWindow = activeTab === "stock-map" && mapData?.asOfTime && bars?.length
      ? (reportTimeCategoryPosition(bars, mapData.asOfTime.easternWallTime) ?? -1) < 0 : false;
    const levels = activeTab === "stock-map" && "jobId" in source ? source
      : "stock" in source ? source.stock : null;
    const visibleSide = (side: "support" | "resistance") => visibleChartLevels?.[side === "support" ? "supports" : "resistances"] || [];
    const formatChartLevelPrice = (price: number) => activeTab === "stock-map" && mapData?.stockCode === "SPX"
      ? formatSpxPriceWithEs(price, mapData.spxEsBasis) : price.toFixed(2);
    const mappedLegendValues = (zone: MapZone | PriceRange) => {
      if (activeTab !== "stock-map" || mapData?.reportType !== "spx-map" || !("score" in zone)) return "";
      const sourceSpxPrice = mapData.stockCode === "SPX" ? zone.price : zone.details.source_spx_anchor;
      const formatMapped = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? value.toFixed(2) : "n/a";
      const mappedPrice = (ticker: "SPY" | "SPXL") => mapData.spxEtfOrderLevels[ticker]
        ?.find((candidate) => candidate.rank === zone.rank && candidate.sourceSide === zone.sourceSide)?.price;
      return ` (SPX ${formatMapped(sourceSpxPrice)} SPY ${formatMapped(mappedPrice("SPY"))} SPXL ${formatMapped(mappedPrice("SPXL"))})`;
    };
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
      {activeTab === "stock-map" ? <p className="mb-2 text-xs text-slate-500">Candles show the latest {selectedDays} calendar days. The dotted blue selected-price line uses the session-aware source (weekend 30-minute database close, overnight IB OVERNIGHT, otherwise IB SMART) and reclassifies levels below it as support and levels above it as resistance; original report-side labels remain in the details. Weekend database reads use NOLOCK and can briefly observe an in-progress update.</p> : null}
      {mapOutsideWindow ? <Alert variant="info">Map as-at is outside the chart’s recent candle window. The historical as-at close is still used for level classification; the purple marker is not drawn in this window.</Alert> : null}
      {levels ? <details className="mb-3 text-sm text-slate-700">
        <summary className="cursor-pointer text-indigo-700">Jump to a level{activeTab === "stock-map" && mapData?.reportType === "spx-map" ? " and its SPX source details" : " and its order links"} (keyboard accessible)</summary>
        <div className="mt-2 flex flex-wrap gap-2">
          {(["support", "resistance"] as const).flatMap((side) => visibleSide(side).map(({ level: zone, originalIndex }) => (
            <a key={`${side}-${originalIndex}`} href={`#${levelPanelId(activeTab as LevelTab, side, originalIndex)}`}
              className="rounded border border-slate-300 px-2 py-1 text-indigo-700 hover:bg-indigo-50">
              {side === "support" ? "Support" : "Resistance"} {formatChartLevelPrice(zone.price)}
            </a>
          )))}
        </div>
      </details> : null}
      {chartError ? <Alert variant="danger">Unable to load chart candles: {chartError}</Alert> : null}
      {bars === null ? (!chartError ? <div className="py-8 text-center text-slate-500">{chartLoading ? `Loading ${chartTimeframe} candles for ${selectedDays} days...` : "Waiting for chart data..."}</div> : null)
        : bars.length ? <>
          <ChartZoomHelp indexLevels={activeTab === "stock-map" && mapData?.reportType === "spx-map"} mobile={isMobileViewport} />
          {priceWindow && priceWindow.contentHeight > priceWindow.trackHeight ? <p className="mb-2 text-xs text-slate-600">Visible price: {activeTab === "stock-map" && mapData ? formatMapPrice(priceReadout?.bottom ?? priceWindow.bottom, mapData.reportType, mapData.stockCode) : formatPrice(priceReadout?.bottom ?? priceWindow.bottom)}–{activeTab === "stock-map" && mapData ? formatMapPrice(priceReadout?.top ?? priceWindow.bottom + priceWindow.span, mapData.reportType, mapData.stockCode) : formatPrice(priceReadout?.top ?? priceWindow.bottom + priceWindow.span)}. Use the right-hand vertical scrollbar to reveal older highs or lower supports.</p> : null}
          {activeTab === "stock-map" ? <p className="mb-2 text-xs text-slate-500">{mapData?.reportType === "spx-map" ? "SPX Map" : "Stock Map"}: darker, thicker green/red lines indicate higher scores.</p> : null}
          <div className="flex min-w-0 items-start gap-2">
            <div className="relative min-w-0 flex-1">
              <div ref={chartScrollRef} className="min-w-0 overflow-x-auto rounded border border-slate-200" role="region" aria-label="Horizontally scrollable price chart" tabIndex={0}>
                <div key={`${activeTab}-${chartTimeframe}`} ref={plotRef}
                  style={{ width: isMobileViewport ? "100%" : `max(100%, ${chartMinimumWidth(bars.length, chartTimeframe)}px)`, height: isMobileViewport ? "560px" : "860px" }} />
              </div>
              <div aria-label="Visible level scores" className="pointer-events-none absolute inset-y-0 left-1 z-10 w-8">
                {activeTab === "stock-map" && (priceReadout || priceWindow) && visibleChartLevels
                  ? [...visibleChartLevels.supports, ...visibleChartLevels.resistances].map(({ level }) => {
                    if (!("score" in level) || level.score === null || !Number.isFinite(level.score)) return null;
                    const bottom = priceReadout?.bottom ?? priceWindow!.bottom;
                    const top = priceReadout?.top ?? priceWindow!.bottom + priceWindow!.span;
                    const y = scoreYPosition(level.price, bottom, top, isMobileViewport);
                    if (y === null) return null;
                    const color = mapLineColor(level.sourceSide, level.score);
                    return <span key={`${level.sourceSide}-${level.rank}-${level.price}`} className="absolute left-0 rounded border bg-white/95 px-1 text-[10px] leading-4 shadow-sm"
                      style={{ top: y, transform: "translateY(-50%)", borderColor: color, color }}
                      title={`${level.sourceSide} ${level.price.toFixed(2)} · score ${Math.round(level.score)}`}>{Math.round(level.score)}</span>;
                  }) : null}
              </div>
            </div>
            {priceWindow && priceWindow.contentHeight > priceWindow.trackHeight ? (
              <div className={`flex w-7 shrink-0 flex-col items-center ${isMobileViewport ? "pt-12" : "pt-16"} text-xs text-slate-600`} title="Scroll up for earlier higher prices; down for lower prices">
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
          <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 border-t border-slate-200 pt-3 text-[11px] text-slate-700 sm:gap-x-4 sm:text-xs" aria-label="Chart legend">
            <span className="inline-flex items-center gap-1"><span className="h-3 w-3 border border-emerald-600 bg-emerald-200" />Price candles</span>
            <span className="inline-flex items-center gap-1"><span className="h-3 w-3 bg-slate-400" />Volume</span>
            {activeTab === "stock-map" && mapData ? <span className="inline-flex items-center gap-1" title={mapData.livePriceSource || "Selected price unavailable"}><span className="w-6 border-t-2 border-dotted border-blue-600" />Selected price {mapData.livePriceLoading ? "loading…" : formatMapPrice(mapData.livePrice, mapData.reportType, mapData.stockCode)}</span> : null}
            {activeTab === "stock-map" && mapData?.nextSessionStraddle ? <span className="inline-flex items-center gap-1" title={`Indicative next-session range for ${mapData.nextSessionStraddle.nextSession}, derived from ${mapData.nextSessionStraddle.quoteDate} quotes; not support or resistance`}><span className="h-3 w-3 border border-amber-500 bg-yellow-200" />ATM {mapData.nextSessionStraddle.quoteDate}: {formatPrice(mapData.nextSessionStraddle.strike)} call {formatPrice(mapData.nextSessionStraddle.callPrice)} + put {formatPrice(mapData.nextSessionStraddle.putPrice)} · next-session range {formatPrice(mapData.nextSessionStraddle.nextSessionRange.low)}–{formatPrice(mapData.nextSessionStraddle.nextSessionRange.high)}</span> : null}
            {activeTab === "stock-map" && mapData?.spxOptions && mapAtmRange ? <span className="inline-flex items-center gap-1" title={`Illustrative SPXW observation-date call+put premium range to ${mapData.spxOptions.expiry}; ESMain range is translated with matched ES−SPX basis ${mapData.spxEsBasisDate || "unavailable"}; not support/resistance`}><span className="h-3 w-3 border border-orange-700 bg-orange-200" />{mapData.stockCode === "ESMain" ? "ESMain ATM range" : "SPXW expiry proxy"} {mapData.stockCode === "ESMain" ? `${formatMapPrice(mapAtmRange.low, mapData.reportType, mapData.stockCode)}–${formatMapPrice(mapAtmRange.high, mapData.reportType, mapData.stockCode)}` : `${formatSpxPriceForDate(mapData.spxOptions.expiryRange.low, mapData.spxEsBasis, mapData.spxEsBasisDate, mapData.spxOptions.observationDate)}–${formatSpxPriceForDate(mapData.spxOptions.expiryRange.high, mapData.spxEsBasis, mapData.spxEsBasisDate, mapData.spxOptions.observationDate)}`}</span> : null}
            {levels ? (["support", "resistance"] as const).flatMap((side) => visibleSide(side).map(({ level: zone, originalIndex }) => (
              <button key={`${side}-${originalIndex}`} type="button" onClick={() => focusLevelPanel(levelPanelId(activeTab as LevelTab, side, originalIndex))}
                title={`Jump to ${side} ${formatChartLevelPrice(zone.price)}${"score" in zone ? ` · Score ${zone.score ?? "n/a"}` : ` · Rank ${zone.strength_rank || "n/a"}`}`}
                className="inline-flex max-w-full flex-wrap items-center gap-1 rounded px-1 py-0.5 text-left hover:bg-indigo-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-600">
                <span className="w-6 shrink-0 border-t-2" style={{ borderColor: "score" in zone ? mapLineColor(side, zone.score) : chartLevelColor(side, originalIndex) }} />
                {side === "support" ? "Support" : "Resistance"} {activeTab === "stock-map" && mapData?.stockCode === "SPX" ? zone.price.toFixed(2) : formatChartLevelPrice(zone.price)}{mappedLegendValues(zone)}
                <span className="font-semibold text-slate-600">{"score" in zone
                  ? `· Score ${zone.score === null ? "n/a" : Math.round(zone.score)}`
                  : `· Rank ${zone.strength_rank || "n/a"}`}</span>
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
            {activeTab === "stock-map" && todayReportStocks.length > 0 ? <div>
              <p className="mb-2 text-sm font-medium text-slate-700">Today’s reports available (earliest first, up to 10)</p>
              <div className="flex flex-wrap gap-2">{todayReportStocks.map((code) => <button key={code} type="button" onClick={() => { setStockCode(code); void loadMapReports(code); }} className="rounded-md border border-indigo-200 bg-indigo-50 px-3 py-1.5 text-sm font-medium text-indigo-700 hover:bg-indigo-100">{code}</button>)}</div>
            </div> : null}
            <div className="flex gap-3">
              <Input
                placeholder="SPX, ESMain, SPY_D, QQQ_D, SPXL_D, TQQQ_D, SOXL_D, SOXX_D or a stock"
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
                  <label className="text-sm font-medium text-slate-700">{spxInstrumentForCode(stockCode) ? "SPX Map Report" : "Stock Map Report"}</label>
                  <select
                    value={selectedMapJob}
                    onChange={(e) => {
                      const report = mapReports.find((item) => item.job_id === e.target.value);
                      if (report) void loadMapReport(report, stockCode, ++mapRequest.current);
                    }}
                    disabled={mapLoading || !mapReports.length}
                    className="mt-1 flex h-10 w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
                  >
                    {!mapReports.length ? <option value="">No {spxInstrumentForCode(stockCode) ? "SPX Map" : "Stock Map"} reports</option> : null}
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
            <CardHeader><CardTitle>{mapData.reportType === "spx-map" ? "SPX Map Report" : "Stock Map Report"}</CardTitle></CardHeader>
            <CardContent className="text-sm text-slate-700">
              <div>Report: {mapReports.find((report) => report.job_id === mapData.jobId)?.title || mapData.jobId}</div>
              <div>Observation date: {mapData.observationDate || "not specified"} · Chart: 30-minute {mapData.stockCode === "SPX" ? "SPXW.US index" : mapData.stockCode === "ESMain" ? "ESMain.US futures" : "stock"} candles</div>
              <div>Map as-at: {mapData.asOfTime?.label || "Timestamp unavailable in report"}{mapData.asOfTime ? " · Purple dashed line when inside the recent candle window (New York bar time)" : ""}</div>
              {mapData.generatedAtSydney ? <div>Report actually generated: {mapData.generatedAtSydney} (Sydney)</div> : null}
              {mapData.sourceSpxReference !== null && mapData.stockCode !== "SPX" ? <div>Source SPX report reference: {formatMapPrice(mapData.sourceSpxReference, "spx-map")} (not a {mapData.stockCode} quote).</div> : null}
              {mapData.executionReference !== null ? <div>Report execution reference: {mapData.stockCode === "SPX" ? formatSpxPriceWithEs(mapData.executionReference, mapData.spxEsBasis) : formatMapPrice(mapData.executionReference, mapData.reportType, mapData.stockCode)} ({mapData.executionReferenceType?.replace(/_/g, " ") || "report reference"}{mapData.executionReferenceType === "completed_30m_bar" ? "; latest completed 30M bar at map as-at" : "; not the as-at market price"})</div> : null}
              {mapData.effectivePrice !== null ? (
                <div>Effective price at report as-of: {formatMapPrice(mapData.effectivePrice, mapData.reportType, mapData.stockCode)}{mapData.stockCode === "SPX" ? mapData.spxEsMainPrice !== null && mapData.spxEsBasis !== null
                  ? <> · ESMain {mapData.spxEsMainPrice.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} (SPX + matched cash-close ES−SPX basis {mapData.spxEsBasis >= 0 ? "+" : ""}{mapData.spxEsBasis.toFixed(2)})</>
                  : <> · ESMain n/a (matched ES−SPX basis unavailable)</> : null}{mapData.effectivePriceTimestamp ? ` (completed bar ${mapData.effectivePriceTimestamp} New York)` : ""}. Levels below this price are supports; above are resistances. {mapData.effectivePriceSource || "Selected-instrument completed historical bar."}</div>
              ) : <div className="text-amber-700">No effective price at the report as-of is available. Source report sides are retained; no current quote is substituted.</div>}
              {mapData.asAtClose && mapData.stockCode !== "SPX" ? <div className="text-xs">Direct selected-instrument 30M bar: {formatMapPrice(mapData.asAtClose.price, mapData.reportType, mapData.stockCode)} (bar starting {mapData.asAtClose.barTime} New York).</div> : null}
              {mapData.reportType === "spx-map" ? <p className="mt-2 text-xs text-amber-800">{mapData.stockCode === "SPX" ? "SPX ranges are index points, not ETF prices. SPY, SPXL and QQQ links use separately mapped ETF price ranges; support levels open Buy range orders and resistance levels open Sell range orders." : `${mapData.stockCode} ranges are derived from SPX zones, not direct ${mapData.stockCode} report levels.`} These links open prefilled order forms; they do not submit orders. The original SPX scores and option evidence do not establish target-instrument option positioning.</p> : null}
              {mapData.mappingSource ? <div className="mt-1 text-xs">Derived mapping: {mapData.mappingSource}. These instrument levels use matched report-date closes and report-time effective prices; current IB quotes are not used.</div> : null}
              {mapData.mappingError ? <Alert variant="warning">{mapData.mappingError} No current quote is substituted. Where an effective price is unavailable, levels retain their original report sides or derived levels are omitted.</Alert> : null}
              {mapData.effectivePrice !== null && mapData.resistances.length > 0 && mapData.resistances.every((zone) => zone.price > mapData.effectivePrice!) && mapData.supports.length === 0 ? (
                <Alert variant="warning">The effective report-as-of price is below every mapped anchor. Under the selected price-relative rule, all mapped levels are resistance, even those labelled support in the original report. {mapData.executionReferenceType === "prior_session_close" ? "The report uses the prior-session close as its execution reference, not the as-at market price." : mapData.executionReferenceType === "completed_30m_bar" ? "This report also uses a completed 30M bar as its execution reference." : "The report execution reference is not substituted for the as-at 30M close."}</Alert>
              ) : null}
              <a className="text-indigo-700 underline" href={`/${mapData.reportType}-reports/${encodeURIComponent(mapData.jobId)}/mapped-levels${mapData.reportType === "spx-map" ? "" : `?stock_code=${encodeURIComponent(mapData.stockCode)}`}`} target="_blank" rel="noopener noreferrer">Open full {mapData.reportType === "spx-map" ? "SPX Map" : "Stock Map"} details</a>
            </CardContent>
          </Card>
          {mapData.reportType === "spx-map" && mapData.stockCode !== "SPX" ? <Card>
            <CardHeader><CardTitle>SPX Source Evidence · {mapData.stockCode} Derived Ranges</CardTitle></CardHeader>
            <CardContent className="text-sm text-slate-700">Each derived level lists its source SPX anchor and SPX zone. SPXW options in the source map are SPX evidence, not a same-day ATM quote for {mapData.stockCode}. No target option premium is inferred.</CardContent>
          </Card> : mapData.reportType === "spx-map" ? <Card>
            <CardHeader><CardTitle>{mapData.stockCode === "ESMain" ? "ESMain ATM Range · SPXW Call + Put" : "SPXW ATM Proxy · Observation-Date Call + Put"}</CardTitle></CardHeader>
            <CardContent className="space-y-2 text-sm text-slate-700">
              {mapData.spxOptionLoading ? <p>Loading SPXW option evidence…</p> : mapData.spxOptionError
                ? <Alert variant="warning">SPXW option evidence unavailable: {mapData.spxOptionError}. The SPX levels remain visible.</Alert>
                : mapData.spxOptions ? <>
                  <div>SPXW observation date: {mapData.spxOptions.observationDate} · Expiry: {mapData.spxOptions.expiry} · Same strike: {formatSpxPriceForDate(mapData.spxOptions.strike, mapData.spxEsBasis, mapData.spxEsBasisDate, mapData.spxOptions.observationDate)} (nearest to effective SPX {formatSpxPriceForDate(mapData.spxOptions.reference, mapData.spxEsBasis, mapData.spxEsBasisDate, mapData.spxOptions.observationDate)})</div>
                  <div>Call {formatPrice(mapData.spxOptions.callPrice)} ({mapData.spxOptions.callSource}) + put {formatPrice(mapData.spxOptions.putPrice)} ({mapData.spxOptions.putSource}) = {formatPrice(mapData.spxOptions.premium)} premium.</div>
                  <div>Illustrative SPX ± call/put premium to expiry: {formatMapPrice(mapData.spxOptions.expiryRange.low, "spx-map", "SPX")} – {formatMapPrice(mapData.spxOptions.expiryRange.high, "spx-map", "SPX")}.</div>
                  {mapData.stockCode === "ESMain" ? mapAtmRange ? <div>ESMain translated range: {formatMapPrice(mapAtmRange.low, "spx-map", "ESMain")} – {formatMapPrice(mapAtmRange.high, "spx-map", "ESMain")} = SPX range + matched ES−SPX basis {mapData.spxEsBasis! >= 0 ? "+" : ""}{mapData.spxEsBasis!.toFixed(2)} ({mapData.spxEsBasisDate}).</div> : <Alert variant="warning">ESMain ATM range unavailable: matched ES−SPX basis is missing; SPX range is not plotted on the ESMain chart.</Alert> : null}
                  <p className="text-xs text-amber-800">These SQL rows were selected by ObservationDate only. Their quote times are unverified and they may postdate the report as-at; this is not a live ATM quote, next-session range, support/resistance, or executable price.</p>
                </> : <p className="text-amber-800">No valid same-strike, same-expiry SPXW call/put pair for option observation date {mapData.spxOptionObservationDate || "unavailable"}. No premium is inferred from another day.</p>}
            </CardContent>
          </Card> : <Card>
            <CardHeader><CardTitle>ATM Straddle · Indicative Next-Session Move</CardTitle></CardHeader>
            <CardContent className="space-y-2 text-sm text-slate-700">
              {mapData.nextSessionStraddle ? <>
                <div className="text-lg font-semibold text-indigo-800">
                  {formatPrice(mapData.nextSessionStraddle.nextSessionRange.low)} – {formatPrice(mapData.nextSessionStraddle.nextSessionRange.high)}
                  <span className="ml-2 text-sm font-normal text-slate-600">for {mapData.nextSessionStraddle.nextSession} (approx. ±{formatPrice(mapData.nextSessionStraddle.nextSessionMove)})</span>
                </div>
                <div>Quote date: {mapData.nextSessionStraddle.quoteDate} · Underlying at quote: {formatPrice(mapData.nextSessionStraddle.spot)} · ATM strike: {formatPrice(mapData.nextSessionStraddle.strike)}</div>
                <div>Call: {formatPrice(mapData.nextSessionStraddle.callPrice)} + put: {formatPrice(mapData.nextSessionStraddle.putPrice)} = straddle: {formatPrice(mapData.nextSessionStraddle.premium)} · {mapData.nextSessionStraddle.quoteSource}</div>
                <div>Actual option expiry: {mapData.nextSessionStraddle.expiry} ({mapData.nextSessionStraddle.tradingSessionsToExpiry} weekdays after the quote). The unscaled expiry-horizon premium band is {formatPrice(mapData.nextSessionStraddle.expiryRange.low)} – {formatPrice(mapData.nextSessionStraddle.expiryRange.high)}.</div>
                <p className="text-xs text-amber-800">Next-session range is an approximate one-sigma volatility proxy: (ATM call + put premium) ÷ 0.8 ÷ √weekdays to expiry. It assumes stable volatility and ignores market holidays and event jumps. The expiry band is not a next-day range or a guaranteed trading boundary; neither range is a support/resistance level.</p>
              </> : <p className="text-amber-800">No complete, same-date ATM call/put straddle with valid premiums and a future expiry is available in this report. No next-session range is estimated.</p>}
            </CardContent>
          </Card>}
          <Card>
            <CardHeader><CardTitle>Interactive Chart</CardTitle></CardHeader>
            <CardContent>{renderChart(mapData)}</CardContent>
          </Card>
          <StockMapPanels key={mapData.jobId} stock={mapData} percentBySide={levelPercent} />
        </>
      ) : null}
      {activeTab === "stock-map" && !mapLoading && !mapError && !mapData ? <Card><CardContent><div className="py-8 text-center text-slate-500">No {spxInstrumentForCode(stockCode) ? "SPX Map" : "Stock Map"} reports for this symbol</div></CardContent></Card> : null}

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

