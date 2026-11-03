"use client";

import { use, useEffect, useMemo, useRef, useState } from "react";

import Alert from "../../../components/ui/Alert";
import Button from "../../../components/ui/Button";
import PageHeader from "../../../components/PageHeader";
import MappedLevelReportDetails, {
  levelReportKey,
  parseHtmlLevelDetails,
  type HtmlLevelDetail,
} from "../../../components/MappedLevelReportDetails";
import { authenticatedFetch } from "../../../utils/authenticatedFetch";
import { assessLiveMoveRatio, directStockRangeHref, liveMoveSpread, mappedFromLeveragedParent, mappedFromSpy, mappedFromSpySpread, MOVE_RATIO_THRESHOLD, shouldUseMoveRatio } from "./calibration";
import { matchedEsBasis, spxEsLevel } from "./esBasis";

type JsonObject = Record<string, unknown>;
type LevelSide = "support" | "resistance";

type LevelStructure = {
  label: string | null;
  openInterest: number | null;
  gex: number | null;
};

type SpxZone = {
  id: string;
  side: LevelSide;
  reportSide: LevelSide;
  reportRank: number;
  rank: number;
  low: number;
  high: number;
  center: number;
  score: number | null;
  confidence: string;
  levelConfidence: string;
  relevanceScore: number | null;
  polarity: string;
  structure: LevelStructure;
  reportZone: JsonObject;
};

type MappingResponse = {
  historical_closes?: Record<string, number>;
  historical_close_date?: string | null;
  historical_close_dates?: Record<string, string>;
  price_differences?: Record<string, number>;
  calibration_eligible?: boolean;
  report_as_of_et?: string | null;
  effective_prices?: Record<string, number | null>;
  effective_price_source?: string | null;
  effective_price_timestamp?: string | null;
  effective_price_timestamps?: Record<string, string | null>;
  effective_price_bar_start?: string | null;
  effective_price_basis?: number | null;
  effective_price_fallback?: boolean;
};

type LivePricesResponse = {
  live_prices?: Record<string, number>;
  status?: "available" | "partial" | "unavailable";
};

type Instrument = {
  label: string;
  mappingKeys: string[];
  orderSymbol: string;
};

type MappedInstrument = Instrument & {
  sourceColumn: string | null;
  low: number | null;
  high: number | null;
  mid: number | null;
  lastClose: number | null;
  livePrice: number | null;
  clamped: boolean;
  mappingNote?: string;
  riskNote?: string;
};

const EXTRA_STOCK_SYMBOLS = [
  "NVDA", "MSFT", "META", "AMZN", "AAPL", "GOOG", "TSM", "SPCX",
  "SQQQ", "MU", "SKHY", "SOXX", "AMD", "AVGO",
];
const EXTRA_INSTRUMENTS: Instrument[] = EXTRA_STOCK_SYMBOLS.map((label) => ({ label, mappingKeys: [label], orderSymbol: label }));
const LIVE_CALIBRATION_REQUIRED = new Set(["QQQ", "SPXL", "TQQQ", "NQMain", ...EXTRA_STOCK_SYMBOLS]);

const INSTRUMENTS: Instrument[] = [
  { label: "SPY", mappingKeys: ["SPY"], orderSymbol: "SPY" },
  { label: "QQQ", mappingKeys: ["QQQ"], orderSymbol: "QQQ" },
  { label: "SPXL", mappingKeys: ["SPXL"], orderSymbol: "SPXL" },
  { label: "TQQQ", mappingKeys: ["TQQQ"], orderSymbol: "TQQQ" },
  { label: "ESMain", mappingKeys: ["ESMain", "ESMAIN", "ES", "MES"], orderSymbol: "MES" },
  { label: "NQMain", mappingKeys: ["NQMain", "NQMAIN", "NQ", "MNQ"], orderSymbol: "MNQ" },
];

function numberValue(value: unknown): number | null {
  if (value == null || (typeof value === "string" && !value.trim())) return null;
  if (typeof value !== "string" && typeof value !== "number") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeKey(value: string) {
  return value.replace(/[^a-z0-9]/gi, "").toLowerCase();
}

function price(value: number | null | undefined) {
  return value == null ? "n/a" : value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function quoteErrorMessage(error: unknown): string {
  if (!(error instanceof Error)) return "IB quote request failed";
  if (/HTTP (401|403)/.test(error.message) || error.message === "No authentication data") {
    return "Quote API authentication failed. Sign out and sign in again.";
  }
  if (error.name === "AbortError") return "Quote request timed out; the backend or IB API may be slow.";
  return error.message;
}

function parseMapData(value: unknown): JsonObject | null {
  if (!value || typeof value !== "object") return null;
  const wrapper = value as JsonObject;
  const content = wrapper.content ?? wrapper.json ?? wrapper.data ?? value;
  if (typeof content === "string") {
    try {
      const parsed = JSON.parse(content);
      return parsed && typeof parsed === "object" ? parsed as JsonObject : null;
    } catch {
      return null;
    }
  }
  return content && typeof content === "object" ? content as JsonObject : null;
}

function structureFromRow(row: JsonObject, side: LevelSide): LevelStructure {
  const nested = [row.structure, row.option_structure, row.option_context, row.execution_structure, row.market_structure, row.wall]
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"))
    .flatMap((value) => [value]);
  const sources = [row, ...nested];
  const wallKeys = side === "resistance"
    ? ["call_wall", "callWall", "call_wall_label", "call_wall_type", "resistance_type"]
    : ["put_wall", "putWall", "put_wall_label", "put_wall_type", "support_type"];
  const labelKeys = [...wallKeys, "structure_label", "wall_label", "zone_role", "level_role", "option_role", "structure", "wall_type", "level_type", "type"];
  let label: string | null = null;
  for (const source of sources) {
    for (const key of labelKeys) {
      const value = source[key];
      if (typeof value === "string" && value.trim()) {
        label = value.trim();
        break;
      }
      if (value && typeof value === "object") {
        const nestedValue = value as JsonObject;
        const nestedLabel = nestedValue.label ?? nestedValue.type ?? nestedValue.name ?? nestedValue.kind;
        if (typeof nestedLabel === "string" && nestedLabel.trim()) {
          label = nestedLabel.trim();
          break;
        }
      }
    }
    if (label) break;
  }
  const oiKeys = side === "resistance"
    ? ["call_wall_oi", "call_wall_open_interest", "call_oi", "wall_oi", "option_oi", "open_interest", "openInterest", "oi"]
    : ["put_wall_oi", "put_wall_open_interest", "put_oi", "wall_oi", "option_oi", "open_interest", "openInterest", "oi"];
  const gexKeys = side === "resistance"
    ? ["call_wall_gex", "call_gex", "wall_gex", "gex", "GEX", "abs_gex", "gex_abs", "absolute_gex"]
    : ["put_wall_gex", "put_gex", "wall_gex", "gex", "GEX", "abs_gex", "gex_abs", "absolute_gex"];
  const findNumber = (keys: string[]) => {
    for (const source of sources) {
      for (const key of keys) {
        const value = numberValue(source[key]);
        if (value !== null) return value;
      }
    }
    return null;
  };
  return { label, openInterest: findNumber(oiKeys), gex: findNumber(gexKeys) };
}

function dailyDateFromReport(content: string): string | null {
  const text = content
    .replace(/<[^>]*>/g, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&rarr;|&#8594;|&#x2192;/gi, "→");
  const auditStart = text.search(/Structure\s*&\s*Audit/i);
  if (auditStart < 0) return null;
  const dailyPeriod = text
    .slice(auditStart)
    .match(/\bDaily\s+(\d{4}-\d{2}-\d{2})\s*(?:→|->)\s*\d{4}-\d{2}-\d{2}/i);
  return dailyPeriod?.[1] || null;
}

function mapAsOfEt(data: JsonObject): string | null {
  const nested = [data.metadata, data.meta, data.parameters]
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"));
  const candidates = [data.as_of_et, data.asOfEt, data.as_at, data.asAt, data.report_as_of, data.report_timestamp,
    ...nested.flatMap((value) => [value.as_of_et, value.asOfEt, value.as_at, value.asAt, value.report_timestamp])];
  for (const candidate of candidates) {
    if (typeof candidate !== "string") continue;
    const match = candidate.match(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?/);
    if (match) return match[0].replace(" ", "T");
  }
  return null;
}

function mapObservationDate(data: JsonObject): string | null {
  const nested = [data.metadata, data.meta, data.parameters]
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"));
  const candidates = [
    data.observation_date,
    data.observationDate,
    data.as_of_date,
    data.as_of_et,
    data.as_of_sydney,
    data.report_date,
    data.date,
    data.as_at,
    data.asAt,
    data.asOfEt,
    data.asOfSydney,
    ...nested.flatMap((value) => [
      value.observation_date,
      value.observationDate,
      value.as_of_date,
      value.as_of_et,
      value.as_of_sydney,
      value.date,
      value.as_at,
    ]),
  ];
  for (const candidate of candidates) {
    if (typeof candidate !== "string") continue;
    const match = candidate.match(/\d{4}-\d{2}-\d{2}/);
    if (match) return match[0];
  }
  return null;
}

function downsidePath(data: JsonObject): JsonObject[] {
  return Array.isArray(data.downside_support_path)
    ? data.downside_support_path.filter((item): item is JsonObject => Boolean(item && typeof item === "object"))
      .sort((a, b) => (numberValue(b.price) ?? numberValue(b.price_level) ?? numberValue(b.reference_price) ?? numberValue(b.zone_high) ?? -Infinity) -
        (numberValue(a.price) ?? numberValue(a.price_level) ?? numberValue(a.reference_price) ?? numberValue(a.zone_high) ?? -Infinity))
    : [];
}

function extractZones(data: JsonObject): SpxZone[] {
  const zones: SpxZone[] = [];
  for (const side of ["support", "resistance"] as const) {
    const rawLevels = data[side === "support" ? "primary_supports" : "primary_resistances"];
    if (!Array.isArray(rawLevels)) continue;
    rawLevels.forEach((raw, index) => {
      if (!raw || typeof raw !== "object") return;
      const row = raw as JsonObject;
      const low = numberValue(row.zone_low);
      const high = numberValue(row.zone_high);
      if (low === null || high === null) return;
      zones.push({
        id: `${side}-${index}-${low}-${high}`,
        side,
        reportSide: side,
        reportRank: numberValue(row.rank) ?? index + 1,
        rank: numberValue(row.rank) ?? index + 1,
        low: Math.min(low, high),
        high: Math.max(low, high),
        center: numberValue(row.core_anchor_price) ?? numberValue(row.reference_price) ?? numberValue(row.tradable_center) ?? numberValue(row.mathematical_center) ?? (low + high) / 2,
        score: numberValue(row.total_score),
        confidence: String(row.confidence || "unknown"),
        levelConfidence: String(row.level_confidence || ""),
        relevanceScore: numberValue(row.execution_relevance_score),
        polarity: String(row.polarity || side),
        structure: structureFromRow(row, side),
        reportZone: row,
      });
    });
  }
  return zones.sort((left, right) => left.side.localeCompare(right.side) || left.rank - right.rank);
}

function mapZone(
  zone: SpxZone,
  instrument: Instrument,
  historicalCloses: Record<string, number>,
  priceDifferences: Record<string, number>,
  livePrices: Record<string, number>,
  spyMapped?: MappedInstrument,
  liveRatio?: number | null,
  liveSpread?: number | null,
): MappedInstrument {
  const historicalClose = (keys: string[]) => keys
    .map((key) => numberValue(historicalCloses[key]))
    .find((value): value is number => value !== null) ?? null;
  const lastClose = historicalClose([instrument.label, ...instrument.mappingKeys]);
  const livePrice = numberValue(livePrices[instrument.label]);
  const noMapping = { ...instrument, sourceColumn: null, low: null, high: null, mid: null, lastClose, livePrice, clamped: false };
  // These must go through their mapped parent, never an independent IB ratio
  // or a historical SPX-percentage fallback.
  if (instrument.label === "SPXL" || instrument.label === "TQQQ") return noMapping;
  const spxClose = numberValue(historicalCloses.SPX);

  if (spyMapped && (liveRatio != null || liveSpread != null) && lastClose !== null &&
      spyMapped.lastClose !== null && spyMapped.lastClose > 0 &&
      spyMapped.low !== null && spyMapped.high !== null && spyMapped.mid !== null) {
    const mapped = [spyMapped.low, spyMapped.high, spyMapped.mid]
      .map((value) => liveSpread != null
        ? mappedFromSpySpread(value, spyMapped.lastClose!, lastClose, liveSpread)
        : mappedFromSpy(value, spyMapped.lastClose!, lastClose, liveRatio!));
    if (mapped.every((value) => Number.isFinite(value) && value > 0)) {
      const spreadLabel = liveSpread == null ? "" : `${liveSpread >= 0 ? "+" : ""}${(liveSpread * 100).toFixed(3)}pp`;
      return { ...instrument, sourceColumn: liveSpread != null
        ? `SPY % move + observed ${instrument.label}-SPY move spread (${spreadLabel})`
        : `SPY % move × observed ${instrument.label}/SPY ratio (${liveRatio!.toFixed(2)}×)`,
        low: Math.min(mapped[0], mapped[1]), high: Math.max(mapped[0], mapped[1]),
        mid: mapped[2], lastClose, livePrice, clamped: false };
    }
  }

  // QQQ/TQQQ/NQ and extra-stock ranges need observed SPY and target quotes:
  // same-direction moves with both magnitudes > 0.20% use a ratio;
  // otherwise use the live target-minus-SPY percentage-point difference.
  if (LIVE_CALIBRATION_REQUIRED.has(instrument.label)) return noMapping;

  if (instrument.label === "ESMain") {
    const difference = numberValue(priceDifferences.ESMain);
    if (spxClose === null || lastClose === null || difference === null) return noMapping;
    return {
      ...instrument,
      sourceColumn: `Matched cash-close ES−SPX difference (${difference >= 0 ? "+" : ""}${difference.toFixed(2)})`,
      low: zone.low + difference,
      high: zone.high + difference,
      mid: zone.center + difference,
      lastClose,
      livePrice,
      clamped: false,
    };
  }

  if (spxClose === null || lastClose === null || spxClose === 0) return noMapping;
  const sourceLabel = "Fallback: SPX % change";
  const mapPrice = (value: number) => lastClose * (1 + ((value - spxClose) / spxClose));
  return {
    ...instrument,
    sourceColumn: sourceLabel,
    low: mapPrice(zone.low),
    high: mapPrice(zone.high),
    mid: mapPrice(zone.center),
    lastClose,
    livePrice,
    clamped: false,
  };
}

function mapLeveragedInstrument(
  instrument: Instrument, parent: MappedInstrument,
  historicalCloses: Record<string, number>, livePrices: Record<string, number>,
): MappedInstrument {
  const lastClose = numberValue(historicalCloses[instrument.label]);
  const livePrice = numberValue(livePrices[instrument.label]);
  const unavailable: MappedInstrument = {
    ...instrument, sourceColumn: null, low: null, high: null, mid: null,
    lastClose, livePrice, clamped: false,
    mappingNote: `${parent.label} mapped range unavailable${parent.mappingNote ? `: ${parent.mappingNote}` : ""}`,
  };
  if (lastClose === null || lastClose <= 0) {
    return { ...unavailable, mappingNote: `${instrument.label} selected close unavailable` };
  }
  if (parent.lastClose === null || parent.lastClose <= 0 ||
      parent.low === null || parent.high === null || parent.mid === null) return unavailable;
  const [low, high, mid] = [parent.low, parent.high, parent.mid]
    .map((value) => mappedFromLeveragedParent(value, parent.lastClose!, lastClose));
  if (![low, high, mid].every((value) => Number.isFinite(value) && value > 0)) {
    return { ...unavailable, mappingNote: `Three times ${parent.label}'s projected move would produce a nonpositive ${instrument.label} price` };
  }
  return {
    ...instrument, sourceColumn: `${parent.label} mapped % move × 3`,
    low: Math.min(low, high), high: Math.max(low, high), mid,
    lastClose, livePrice, clamped: false,
    mappingNote: parent.mappingNote ? `Derived from ${parent.label}: ${parent.mappingNote}` : undefined,
    riskNote: parent.riskNote ? `Derived from ${parent.label}: ${parent.riskNote}` : undefined,
  };
}

function percentChange(value: number | null, lastClose: number | null) {
  if (value === null || lastClose === null || lastClose === 0) return null;
  return ((value - lastClose) / lastClose) * 100;
}

function percentLabel(value: number | null, lastClose: number | null) {
  const change = percentChange(value, lastClose);
  return change === null ? "" : `(${change >= 0 ? "+" : ""}${change.toFixed(2)}%)`;
}

function structureLabel(zone: SpxZone, esBasis: number | null) {
  const parts = [spxEsLevel(zone.center, esBasis)];
  if (zone.structure.label) parts.push(zone.structure.label);
  if (zone.structure.openInterest !== null) parts.push(`OI ${zone.structure.openInterest.toLocaleString()}`);
  if (zone.structure.gex !== null) parts.push(`|GEX| ${Math.abs(zone.structure.gex).toLocaleString()} (size only)`);
  return parts.join(" · ");
}

function orderHref(
  mapped: MappedInstrument,
  zone: SpxZone,
  side: "Buy" | "Sell" = zone.side === "support" ? "Buy" : "Sell",
) {
  // The range-orders page submits US stock intents; it cannot trade CME futures.
  if (mapped.label === "ESMain" || mapped.label === "NQMain") return "";
  const range = mapped.low !== null && mapped.high !== null
    ? { low: mapped.low, high: mapped.high }
    : null;
  return range ? directStockRangeHref(mapped.orderSymbol, side, range.low, range.high) : "";
}

function optionHref(mapped: MappedInstrument, zone: SpxZone, action: "SELL" | "BUY" = zone.side === "support" ? "SELL" : "BUY") {
  if (mapped.mid === null || mapped.label === "ESMain" || mapped.label === "NQMain") return "";
  const params = new URLSearchParams({
    symbol: mapped.orderSymbol,
    right: "P",
    action,
    target: mapped.mid.toFixed(2),
    auto: "1",
  });
  return `/option-orders?${params.toString()}`;
}

function LiveQuoteCell({ item, refreshing, disabled, error, onRefresh, allowRefresh = true }: {
  item: MappedInstrument;
  refreshing: boolean;
  disabled: boolean;
  error?: string;
  onRefresh: (symbol: string) => void;
  allowRefresh?: boolean;
}) {
  return (
    <td className="px-3 py-3 font-mono text-slate-700">
      <div className="flex items-center gap-2">
        <span>{price(item.livePrice)}</span>
        {allowRefresh ? <button type="button" onClick={() => onRefresh(item.label)} disabled={disabled || refreshing}
          aria-label={`Refresh ${item.label} live price`} title={`Refresh ${item.label} from IB`}
          className="rounded border border-slate-300 px-1.5 py-0.5 text-xs text-indigo-700 hover:bg-indigo-50 disabled:opacity-50">
          {refreshing ? "…" : "↻"}
        </button> : null}
      </div>
      {error && <span className="block max-w-48 text-xs text-amber-800">{error}</span>}
    </td>
  );
}

function displayValue(value: unknown): string {
  if (value == null) return "Unavailable";
  if (typeof value === "number") return Number.isFinite(value) ? value.toLocaleString() : "Unavailable";
  if (typeof value === "string") return value || "Unavailable";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return Array.isArray(value) ? `${value.length} entries` : "Details available";
}

function PositioningIntelligence({ data, zones }: { data: JsonObject; zones: SpxZone[] }) {
  const raw = data.positioning_intelligence;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const intelligence = raw as JsonObject;
  const wallEntries = Array.isArray(intelligence.wall_qualification)
    ? intelligence.wall_qualification.filter((item): item is JsonObject => Boolean(item && typeof item === "object")) : [];
  const advisoryOrders = ([...(Array.isArray(intelligence.long_orders) ? intelligence.long_orders : []),
    ...(Array.isArray(intelligence.short_orders) ? intelligence.short_orders : [])])
    .filter((item): item is JsonObject => Boolean(item && typeof item === "object"));
  const summaryKeys = ["underlying_price", "reference_price_source", "absolute_gex", "convention_signed_gex", "signal_strength"];
  return <section className="rounded-lg border border-violet-200 bg-white p-5 shadow-sm">
    <h2 className="text-lg font-semibold text-violet-950">Positioning intelligence</h2>
    <p className="mt-1 text-xs text-slate-600">Schema: {displayValue(intelligence.schema_version)}. Optional audit data; missing or null values are unavailable, not zero.</p>
    <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{summaryKeys.map((key) => <div key={key} className="rounded bg-violet-50 p-3 text-sm">
      <div className="text-xs font-medium uppercase text-slate-500">{key.replaceAll("_", " ")}</div>
      <div className="mt-1 font-semibold text-slate-900">{displayValue(intelligence[key])}</div>
      {key === "convention_signed_gex" ? <div className="mt-1 text-xs text-amber-800">Modelled/convention-based, not observed dealer positioning.</div> : null}
    </div>)}</div>
    {intelligence.gamma_flip && typeof intelligence.gamma_flip === "object" ? <p className="mt-3 text-sm">Gamma flip: <strong>{displayValue((intelligence.gamma_flip as JsonObject).price)}</strong> · {displayValue((intelligence.gamma_flip as JsonObject).status)} <span className="text-xs text-amber-800">(modelled/convention-based, not observed dealer positioning)</span></p> : null}
    {wallEntries.length ? <div className="mt-4 overflow-x-auto"><h3 className="mb-2 font-semibold">Wall qualification (joins map levels by level_id)</h3><table className="min-w-[600px] w-full text-sm"><thead><tr className="text-left text-xs uppercase text-slate-500"><th className="p-2">Map level</th><th className="p-2">Classification</th><th className="p-2">Qualification</th><th className="p-2">Price confirmation</th></tr></thead><tbody>{wallEntries.map((entry, index) => {
      const levelId = typeof entry.level_id === "string" ? entry.level_id : "";
      const matched = zones.find((zone) => zone.reportZone.level_id === levelId || zone.reportZone.id === levelId);
      const confirmation = entry.price_confirmation && typeof entry.price_confirmation === "object" ? entry.price_confirmation as JsonObject : {};
      return <tr key={`${levelId}-${index}`} className="border-t"><td className="p-2">{matched ? `${matched.side} #${matched.rank}` : (levelId || "Unmatched")}</td><td className="p-2">{displayValue(entry.classification)}</td><td className="p-2">{displayValue(entry.qualification_status)}</td><td className="p-2">{displayValue(confirmation.state)}</td></tr>;
    })}</tbody></table></div> : null}
    {advisoryOrders.length ? <div className="mt-4"><h3 className="font-semibold">Advisory order ideas — not executable</h3><p className="text-xs text-amber-800">These ideas must not be routed to order execution. Flow data does not establish customer/dealer identity or opening/closing activity.</p><ul className="mt-2 list-inside list-disc text-sm">{advisoryOrders.map((order, index) => <li key={index}>{displayValue(order.setup)} · {displayValue(order.level_id)} · {displayValue(order.qualification_status)} · active: {displayValue(order.active_order)} · execution enabled: {displayValue(order.execution_enabled)}</li>)}</ul></div> : null}
    <details className="mt-4"><summary className="cursor-pointer text-sm font-medium text-violet-800">Full positioning audit object</summary><pre className="mt-2 max-h-96 overflow-auto rounded bg-slate-50 p-3 text-xs">{JSON.stringify(intelligence, null, 2)}</pre></details>
  </section>;
}

export default function SpxMappedLevelsPage({ params }: { params: Promise<{ jobId: string }> }) {
  const { jobId } = use(params);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [mapData, setMapData] = useState<JsonObject | null>(null);
  const [mapping, setMapping] = useState<MappingResponse | null>(null);
  const [livePrices, setLivePrices] = useState<Record<string, number>>({});
  const [liveStatus, setLiveStatus] = useState<"loading" | "available" | "partial" | "unavailable">("loading");
  const [futuresStatus, setFuturesStatus] = useState<"loading" | "available" | "unavailable">("loading");
  const [htmlLevelDetails, setHtmlLevelDetails] = useState<Record<string, HtmlLevelDetail>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [extraExpanded, setExtraExpanded] = useState(false);
  const [extraSnapshot, setExtraSnapshot] = useState<{ date: string; closes: Record<string, number>; closeDates: Record<string, string> } | null>(null);
  const [extraLivePrices, setExtraLivePrices] = useState<Record<string, number>>({});
  const [extraClosesStatus, setExtraClosesStatus] = useState<"loading" | "available" | "unavailable">("loading");
  const [stockQuoteError, setStockQuoteError] = useState<string | null>(null);
  const [futuresQuoteError, setFuturesQuoteError] = useState<string | null>(null);
  const [manualQuoteLoading, setManualQuoteLoading] = useState<Record<string, boolean>>({});
  const [manualQuoteErrors, setManualQuoteErrors] = useState<Record<string, string>>({});
  const manualQuoteControllers = useRef<Map<string, AbortController>>(new Map());

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const [mapResponse, reportResponse] = await Promise.all([
          authenticatedFetch(
            `${baseUrl}/api/spx-map-reports/${encodeURIComponent(jobId)}/json`,
            { cache: "no-store" },
          ),
          authenticatedFetch(
            `${baseUrl}/api/spx-map-reports/${encodeURIComponent(jobId)}`,
            { cache: "no-store" },
          ),
        ]);
        const mapPayload = await mapResponse.json().catch(() => ({}));
        const reportPayload = await reportResponse.json().catch(() => ({}));
        if (!mapResponse.ok) throw new Error(mapPayload.detail || `SPX JSON request failed: HTTP ${mapResponse.status}`);
        const parsedMap = parseMapData(mapPayload.data ?? mapPayload);
        if (!parsedMap) throw new Error("The SPX Map JSON artifact was not returned in a readable format.");
        const queryDate = new URLSearchParams(window.location.search).get("observation_date");
        const observationDate = queryDate || dailyDateFromReport(String(reportPayload.content || "")) || mapObservationDate(parsedMap);
        const asOfEt = mapAsOfEt(parsedMap);
        if (observationDate && queryDate !== observationDate) {
          const url = new URL(window.location.href);
          url.searchParams.set("observation_date", observationDate);
          window.history.replaceState(null, "", url.toString());
        }
        const pricesUrl = new URL(`${baseUrl}/api/spx-map-prices`, window.location.origin);
        if (observationDate) pricesUrl.searchParams.set("observation_date", observationDate);
        if (asOfEt) pricesUrl.searchParams.set("as_of_et", asOfEt);
        const pricesResponse = await authenticatedFetch(pricesUrl.toString(), { cache: "no-store" });
        const pricesPayload = await pricesResponse.json().catch(() => ({}));
        if (!pricesResponse.ok) throw new Error(pricesPayload.detail || `SPX mapped prices request failed: HTTP ${pricesResponse.status}`);
        const resolvedObservationDate = observationDate || (typeof pricesPayload.historical_close_date === "string" ? pricesPayload.historical_close_date : null);
        if (resolvedObservationDate && queryDate !== resolvedObservationDate) {
          const url = new URL(window.location.href);
          url.searchParams.set("observation_date", resolvedObservationDate);
          window.history.replaceState(null, "", url.toString());
        }
        setMapData(parsedMap);
        setHtmlLevelDetails(parseHtmlLevelDetails(String(reportPayload.content || "")));
        setMapping(pricesPayload as MappingResponse);
      } catch (loadError) {
        setError(loadError instanceof Error ? loadError.message : "Unable to load mapped SPX levels.");
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [baseUrl, jobId]);

  // One initial IB batch; subsequent quote requests are user-initiated per row.
  useEffect(() => {
    let active = true;
    const controller = new AbortController();
    setLiveStatus("loading");
    setLivePrices({});
    setStockQuoteError(null);
    const clearStocks = () => {
      setLivePrices((current) => { const { SPY, QQQ, SPXL, TQQQ, ...rest } = current; void SPY; void QQQ; void SPXL; void TQQQ; return rest; });
    };
    const loadLivePrices = async () => {
      const request = controller;
      const timeout = window.setTimeout(() => request.abort(), 15000);
      try {
        const response = await authenticatedFetch(`${baseUrl}/api/spx-map-live-prices`, { cache: "no-store", signal: request.signal });
        if (!response.ok) throw new Error(`IB quote request failed: HTTP ${response.status}`);
        const payload = await response.json() as LivePricesResponse;
        if (!active || request.signal.aborted) return;
        clearStocks();
        setLivePrices((current) => ({ ...current, ...payload.live_prices }));
        setLiveStatus(payload.status === "available" || payload.status === "partial" ? payload.status : "unavailable");
        setStockQuoteError(payload.status === "unavailable" ? "IB returned no stock quotes for this request." : null);
      } catch (quoteError) {
        if (active) {
          clearStocks();
          setLiveStatus("unavailable");
          setStockQuoteError(quoteErrorMessage(quoteError));
        }
      } finally {
        window.clearTimeout(timeout);
      }
    };
    void loadLivePrices();
    return () => { active = false; controller.abort(); };
  }, [baseUrl, jobId]);

  // One independent initial ES/NQ batch; no automatic future polling.
  useEffect(() => {
    let active = true;
    const controller = new AbortController();
    setFuturesStatus("loading");
    setFuturesQuoteError(null);
    const clearFutures = () => {
      setLivePrices((current) => { const { ESMain, NQMain, ...rest } = current; void ESMain; void NQMain; return rest; });
    };
    const loadFutures = async () => {
      const request = controller;
      const timeout = window.setTimeout(() => request.abort(), 15000);
      try {
        const response = await authenticatedFetch(`${baseUrl}/api/spx-map-live-futures`, { cache: "no-store", signal: request.signal });
        if (!response.ok) throw new Error(`Futures quote request failed: HTTP ${response.status}`);
        const payload = await response.json() as LivePricesResponse;
        if (!active || request.signal.aborted) return;
        clearFutures();
        setLivePrices((current) => ({ ...current, ...payload.live_prices }));
        setFuturesStatus(payload.status === "available" ? "available" : "unavailable");
        setFuturesQuoteError(payload.status === "unavailable" ? "IB returned no ES/NQ futures quotes for this request." : null);
      } catch (quoteError) {
        if (active) {
          clearFutures();
          setFuturesStatus("unavailable");
          setFuturesQuoteError(quoteErrorMessage(quoteError));
        }
      } finally {
        window.clearTimeout(timeout);
      }
    };
    void loadFutures();
    return () => { active = false; controller.abort(); };
  }, [baseUrl, jobId]);

  // Nothing is fetched for the extra stocks until a pane is opened.
  useEffect(() => {
    if (!extraExpanded || !mapping?.historical_close_date) return;
    const controller = new AbortController();
    const loadCloses = async () => {
      setExtraSnapshot(null);
      setExtraClosesStatus("loading");
      try {
        const date = encodeURIComponent(mapping.historical_close_date!);
        const response = await authenticatedFetch(`${baseUrl}/api/spx-map-extra-prices?observation_date=${date}`, {
          cache: "no-store", signal: controller.signal,
        });
        if (!response.ok) throw new Error(`Extra stock closes: HTTP ${response.status}`);
        const payload = await response.json() as {
          historical_closes?: Record<string, number>;
          historical_close_dates?: Record<string, string>;
          historical_close_source?: string;
        };
        if (payload.historical_close_source !== "30m_regular_session") throw new Error("30-minute close source unavailable");
        if (!controller.signal.aborted) {
          setExtraSnapshot({
            date: mapping.historical_close_date!,
            closes: payload.historical_closes || {},
            closeDates: payload.historical_close_dates || {},
          });
          setExtraClosesStatus("available");
        }
      } catch {
        if (!controller.signal.aborted) {
          setExtraSnapshot(null);
          setExtraClosesStatus("unavailable");
        }
      }
    };
    void loadCloses();
    return () => controller.abort();
  }, [baseUrl, extraExpanded, mapping?.historical_close_date]);

  useEffect(() => {
    setExtraLivePrices({});
    setManualQuoteLoading({});
    setManualQuoteErrors({});
    return () => {
      for (const controller of manualQuoteControllers.current.values()) controller.abort();
      manualQuoteControllers.current.clear();
    };
  }, [jobId]);

  const refreshQuote = async (symbol: string) => {
    if (manualQuoteControllers.current.has(symbol)) return;
    const isExtra = EXTRA_STOCK_SYMBOLS.includes(symbol);
    const isFuture = symbol === "ESMain" || symbol === "NQMain";
    const endpoint = isExtra ? "spx-map-live-extra-prices" : isFuture ? "spx-map-live-futures" : "spx-map-live-prices";
    const controller = new AbortController();
    manualQuoteControllers.current.set(symbol, controller);
    setManualQuoteLoading((current) => ({ ...current, [symbol]: true }));
    setManualQuoteErrors((current) => { const next = { ...current }; delete next[symbol]; return next; });
    const timeout = window.setTimeout(() => controller.abort(), 15000);
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/${endpoint}?symbol=${encodeURIComponent(symbol)}`, {
        cache: "no-store", signal: controller.signal,
      });
      if (!response.ok) throw new Error(`IB quote request failed: HTTP ${response.status}`);
      const payload = await response.json() as LivePricesResponse;
      const value = numberValue(payload.live_prices?.[symbol]);
      if (value === null || value <= 0) throw new Error(`IB returned no ${symbol} price`);
      if (!controller.signal.aborted) {
        if (isExtra) setExtraLivePrices((current) => ({ ...current, [symbol]: value }));
        else setLivePrices((current) => ({ ...current, [symbol]: value }));
        if (isFuture) setFuturesQuoteError(null);
        else if (!isExtra) setStockQuoteError(null);
      }
    } catch (quoteError) {
      if (isExtra) setExtraLivePrices((current) => { const next = { ...current }; delete next[symbol]; return next; });
      else setLivePrices((current) => { const next = { ...current }; delete next[symbol]; return next; });
      setManualQuoteErrors((current) => ({ ...current, [symbol]: quoteErrorMessage(quoteError) }));
    } finally {
      window.clearTimeout(timeout);
      manualQuoteControllers.current.delete(symbol);
      setManualQuoteLoading((current) => ({ ...current, [symbol]: false }));
    }
  };

  const effectiveSpxPrice = numberValue(mapping?.effective_prices?.SPX);
  const zones = useMemo(() => {
    const reportZones = mapData ? extractZones(mapData) : [];
    if (effectiveSpxPrice === null) return reportZones;
    const classified = reportZones.map((zone) => ({
      ...zone,
      side: zone.center <= effectiveSpxPrice ? "support" as const : "resistance" as const,
    })).sort((left, right) => left.side.localeCompare(right.side) ||
      (left.side === "support" ? right.center - left.center : left.center - right.center) ||
      left.reportRank - right.reportRank);
    const sideRanks: Record<LevelSide, number> = { support: 0, resistance: 0 };
    return classified.map((zone) => ({ ...zone, rank: ++sideRanks[zone.side] }));
  }, [mapData, effectiveSpxPrice]);
  const supports = useMemo(() => (mapData ? downsidePath(mapData) : []), [mapData]);
  const historicalCloses = {
    ...(mapping?.historical_closes || {}),
    ...(extraSnapshot && mapping?.historical_close_date && extraSnapshot.date === mapping.historical_close_date ? extraSnapshot.closes : {}),
  };
  // Do not cache mapped ranges: each quote update recomputes the live ratio or
  // target-minus-SPY move spread, displayed range, and order URL on render.
  const reportTimePrices: Record<string, number> = { ...livePrices };
  // Never use current IB SPY/ES quotes as a substitute for this report's as-of proxy.
  delete reportTimePrices.SPY;
  delete reportTimePrices.ESMain;
  delete reportTimePrices.QQQ;
  delete reportTimePrices.TQQQ;
  delete reportTimePrices.SPXL;
  delete reportTimePrices.NQMain;
  const allLivePrices: Record<string, number> = {
    ...reportTimePrices,
    ...extraLivePrices,
    ...(numberValue(mapping?.effective_prices?.SPY) !== null ? { SPY: numberValue(mapping?.effective_prices?.SPY)! } : {}),
    ...(numberValue(mapping?.effective_prices?.ESMain) !== null ? { ESMain: numberValue(mapping?.effective_prices?.ESMain)! } : {}),
    ...(numberValue(mapping?.effective_prices?.QQQ) !== null ? { QQQ: numberValue(mapping?.effective_prices?.QQQ)! } : {}),
    ...(numberValue(mapping?.effective_prices?.TQQQ) !== null ? { TQQQ: numberValue(mapping?.effective_prices?.TQQQ)! } : {}),
    ...(numberValue(mapping?.effective_prices?.SPXL) !== null ? { SPXL: numberValue(mapping?.effective_prices?.SPXL)! } : {}),
    ...(numberValue(mapping?.effective_prices?.NQMain) !== null ? { NQMain: numberValue(mapping?.effective_prices?.NQMain)! } : {}),
  };
  const stockCount = ["QQQ", "SPXL", "TQQQ"].filter((symbol) => (numberValue(allLivePrices[symbol]) ?? 0) > 0).length;
  const futuresCount = ["NQMain"].filter((symbol) => (numberValue(allLivePrices[symbol]) ?? 0) > 0).length;
  const currentStockStatus = liveStatus === "loading" ? "loading" : stockCount === 3 ? "available" : stockCount ? "partial" : "unavailable";
  const currentFuturesStatus = futuresStatus === "loading" ? "loading" : futuresCount === 1 ? "available" : "unavailable";
  const esBasis = matchedEsBasis(mapping);
  const priceDifferences = { ...(mapping?.price_differences || {}) };
  delete priceDifferences.ESMain;
  if (esBasis !== null) priceDifferences.ESMain = esBasis;
  // Historical bars and current IB quotes use different fields. Compare each
  // selected report's as-of prices against that report's own historical closes.
  const calibrationBlockReason = (target: string): string | null => {
    if ((numberValue(allLivePrices.SPY) ?? 0) <= 0 || (numberValue(allLivePrices[target]) ?? 0) <= 0) {
      return "SPY or target report-time price unavailable";
    }
    if ((numberValue(historicalCloses.SPY) ?? 0) <= 0 || (numberValue(historicalCloses[target]) ?? 0) <= 0) {
      return "SPY or target close unavailable";
    }
    return null;
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="SPX Mapped Levels and Orders"
        subtitle={`Job ${jobId}. SPX levels map to SPY first. QQQ targets use report-time SPY/QQQ prices when available; SPXL follows SPY ×3 and TQQQ follows the mapped QQQ move ×3.`}
      />
      {mapping ? <section className="rounded-lg border border-indigo-200 bg-indigo-50 p-4 text-sm">
        <h2 className="font-semibold text-indigo-950">Effective prices at the report as-of time</h2>
        <div className="mt-2 flex flex-wrap gap-x-8 gap-y-2 font-mono text-indigo-950">
          <span>SPX equivalent: <strong>{price(numberValue(mapping.effective_prices?.SPX))}</strong></span>
          <span>SPY equivalent: <strong>{price(numberValue(mapping.effective_prices?.SPY))}</strong></span>
          <span>QQQ: <strong>{price(numberValue(mapping.effective_prices?.QQQ))}</strong></span>
          <span>TQQQ: <strong>{price(numberValue(mapping.effective_prices?.TQQQ))}</strong></span>
          <span>SPXL: <strong>{price(numberValue(mapping.effective_prices?.SPXL))}</strong></span>
          <span>ESMain: <strong>{price(numberValue(mapping.effective_prices?.ESMain))}</strong></span>
          <span>NQMain: <strong>{price(numberValue(mapping.effective_prices?.NQMain))}</strong></span>
        </div>
        <p className="mt-2 text-xs text-indigo-900">Report as-of: {mapping.report_as_of_et || "unavailable"} · {mapping.effective_price_source || "As-of proxy unavailable"}{mapping.effective_price_timestamp ? ` · completed bar ${String(mapping.effective_price_timestamp)}` : ""}{mapping.effective_price_basis != null ? ` · selected-report ES−SPX basis ${mapping.effective_price_basis >= 0 ? "+" : ""}${price(mapping.effective_price_basis)}` : ""}</p>
        <p className="mt-1 text-xs text-indigo-900">Completed QQQ bar: {mapping.effective_price_timestamps?.QQQ || "unavailable"} · Completed TQQQ bar: {mapping.effective_price_timestamps?.TQQQ || "unavailable"} · Completed SPXL bar: {mapping.effective_price_timestamps?.SPXL || "unavailable"} · Completed ESMain bar: {mapping.effective_price_timestamps?.ESMain || "unavailable"} · Completed NQMain bar: {mapping.effective_price_timestamps?.NQMain || "unavailable"}</p>
        {effectiveSpxPrice === null ? <p className="mt-1 text-xs font-semibold text-amber-800">SPX effective price unavailable; zone sides remain as specified by the report.</p> : <p className="mt-1 text-xs text-indigo-900">Zone side is classified relative to effective SPX: centers at/below it are support; centers above it are resistance. SPX, SPY and ESMain are translated proxies, not simultaneous observed cash prices.</p>}
      </section> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {mapping && !mapping.calibration_eligible ? <Alert variant="info">The report-time proxy uses the selected report's timestamp and historical close anchors; it does not use current IB quotes for SPX, SPY, or ESMain.</Alert> : null}
      {mapping ? esBasis === null
        ? <Alert variant="warning">ES equivalents unavailable: SPXW 14:30 and ESMain 15:30 30-minute cash-close bars must both exist on the same observation date. No previous-day or live ES value is substituted.</Alert>
        : <Alert variant="info">Cash-close basis ({mapping.historical_close_dates?.SPX}): SPXW 30M 14:30 {price(numberValue(mapping.historical_closes?.SPX))} · ESMain 30M 15:30 {price(numberValue(mapping.historical_closes?.ESMain))} · ES−SPX {esBasis >= 0 ? "+" : ""}{price(esBasis)} points. Each displayed ES level equals its SPX level plus this fixed basis; it is not a live ES forecast.</Alert> : null}
      <Alert variant="info">SPX, SPY, QQQ, TQQQ, SPXL, ESMain and NQMain use the nearest available completed history bars at or before the report timestamp; these report-time prices are not refreshed from IB. Remaining IB quotes are requested once on page load, with no automatic polling. Valid mapped stock ranges remain actionable; ESMain and NQMain are display-only.</Alert>
      {currentStockStatus === "loading" || currentFuturesStatus === "loading" ? (
        <Alert variant="info">Checking initial IB stock and futures quotes. Report-time QQQ/TQQQ prices are populated independently from the selected report's completed history bars.</Alert>
      ) : null}
      {currentStockStatus === "unavailable" || currentStockStatus === "partial" || currentFuturesStatus === "unavailable" ? (
        <Alert variant="warning">Stock quotes: {currentStockStatus}{stockQuoteError ? ` — ${stockQuoteError}` : ""}. Futures quotes: {currentFuturesStatus}{futuresQuoteError ? ` — ${futuresQuoteError}` : ""}. Use ↻ to retry only a missing quote.</Alert>
      ) : null}
      {currentStockStatus === "available" && currentFuturesStatus === "available" ? (
        <Alert variant="info">SPX, SPY, QQQ, TQQQ and ESMain display report-time completed-bar prices where available. Other live quotes come from the IB API. Observed moves and differences are indicative, not guaranteed future correlations.</Alert>
      ) : null}
      {loading ? <div className="rounded-lg border border-slate-200 bg-white p-6 text-sm text-slate-500">Loading SPX JSON and mapped prices...</div> : null}
      {!loading && !error && zones.length === 0 ? <Alert variant="warning">No major primary SPX zones were found. Weaker references or a downside support path may still exist.</Alert> : null}
      {!loading && mapData ? <PositioningIntelligence data={mapData} zones={zones} /> : null}

      {!loading && !error && supports.length > 0 ? <section className="rounded-lg border border-slate-200 bg-white p-5 text-sm">
        <h2 className="font-semibold">Downside support path (descending price)</h2>
        <p className="mt-1 text-slate-600">Includes weaker references even when no major zone qualifies.</p>
        <ol className="mt-2 list-inside list-decimal space-y-1">{supports.map((item, index) => <li key={index}>
          {String(item.label ?? item.name ?? item.id ?? `Reference ${index + 1}`)} · {spxEsLevel(numberValue(item.price) ?? numberValue(item.price_level) ?? numberValue(item.reference_price) ?? numberValue(item.zone_high), esBasis)}
          {item.evidence || item.main_evidence ? ` · ${Array.isArray(item.main_evidence) ? item.main_evidence.join("; ") : String(item.evidence ?? "")}` : ""}
        </li>)}</ol>
      </section> : null}
      <div className="space-y-5">
        {zones.map((zone) => {
          const spyMapping = mapZone(zone, INSTRUMENTS[0], historicalCloses, priceDifferences, allLivePrices);
          const spyMove = spyMapping.lastClose && spyMapping.livePrice !== null
            ? spyMapping.livePrice / spyMapping.lastClose - 1 : null;
          const mapInstrument = (instrument: Instrument): MappedInstrument => {
            const targetClose = numberValue(historicalCloses[instrument.label]);
            const targetLive = numberValue(allLivePrices[instrument.label]);
            const blocked = calibrationBlockReason(instrument.label);
            const targetMove = targetClose !== null && targetClose > 0 && targetLive !== null && targetLive > 0
              ? targetLive / targetClose - 1 : null;
            const useRatio = blocked === null && spyMove !== null && targetMove !== null
              && shouldUseMoveRatio(spyMove, targetMove);
            const spread = blocked === null && !useRatio
              ? liveMoveSpread(spyMapping.lastClose, spyMapping.livePrice, targetClose, targetLive) : null;
            const assessment = blocked === null && useRatio
              ? assessLiveMoveRatio(spyMapping.lastClose, spyMapping.livePrice, targetClose, targetLive)
              : { ratio: null, blockedReason: blocked, riskReason: null };
            const row = mapZone(zone, instrument, historicalCloses, priceDifferences, allLivePrices,
              spyMapping, assessment.ratio, spread);
            const change = (move: number) => `${move >= 0 ? "+" : ""}${(move * 100).toFixed(3)}%`;
            return { ...row,
              riskNote: row.low !== null ? assessment.riskReason || undefined : undefined,
              mappingNote: row.low !== null && spread !== null && spyMove !== null && targetMove !== null
                ? `SPY ${change(spyMove)}, ${instrument.label} ${change(targetMove)}: live target-minus-SPY move difference used (${spyMove * targetMove <= 0 ? "opposite or flat moves" : Math.abs(spyMove) <= MOVE_RATIO_THRESHOLD + 1e-12 ? "|SPY move| ≤ 0.20%" : "|target move| ≤ 0.20%"}).`
                : row.low === null && LIVE_CALIBRATION_REQUIRED.has(instrument.label)
                  ? assessment.blockedReason || "SPY mapped range unavailable"
                  : assessment.ratio === null ? assessment.blockedReason || undefined : undefined,
            };
          };
          const qqqMapping = mapInstrument(INSTRUMENTS[1]);
          const mapped = [
            spyMapping,
            qqqMapping,
            mapLeveragedInstrument(INSTRUMENTS[2], spyMapping, historicalCloses, allLivePrices),
            mapLeveragedInstrument(INSTRUMENTS[3], qqqMapping, historicalCloses, allLivePrices),
            ...INSTRUMENTS.slice(4).map(mapInstrument),
          ];
          const extraMapped = extraExpanded ? EXTRA_INSTRUMENTS.map(mapInstrument) : [];
          return (
            <section key={zone.id} className="rounded-lg border border-slate-200 bg-white shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-200 bg-slate-50 px-5 py-4">
                <div>
                  <div className={`text-xs font-semibold uppercase tracking-wide ${zone.side === "support" ? "text-emerald-700" : "text-red-700"}`}>
                    {zone.side === "support" ? "Support" : "Resistance"} #{zone.rank}
                  </div>
                  <h2 className="mt-1 text-lg font-semibold text-slate-900">{structureLabel(zone, esBasis)}</h2>
                  <div className="text-xs text-slate-500">System zone low {spxEsLevel(zone.low, esBasis)} · high {spxEsLevel(zone.high, esBasis)} · reference anchor {spxEsLevel(zone.center, esBasis)}</div>
                  <MappedLevelReportDetails
                    side={zone.side}
                    detail={htmlLevelDetails[levelReportKey(zone.reportSide, zone.reportRank)]}
                    rank={zone.reportRank}
                    zone={zone.reportZone}
                  />
                </div>
                <div className="text-right text-sm text-slate-600">
                  <div>Score: <strong>{zone.score === null ? "n/a" : zone.score.toFixed(1)}</strong></div>
                  <div>Strength: <strong>{zone.confidence}</strong></div>
                  {zone.levelConfidence ? <div>Evidence: {zone.levelConfidence}</div> : null}
                </div>
              </div>
              <div className="overflow-x-auto p-5">
                <table className="min-w-[900px] w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-200 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                      <th className="px-3 py-2">Instrument</th>
                      <th className="px-3 py-2">Last close</th>
                      <th className="px-3 py-2">As-of / live price</th>
                      <th className="px-3 py-2">Mapped range (% vs close)</th>
                      <th className="px-3 py-2">Mapped reference anchor (vs selected close)</th>
                      <th className="px-3 py-2">Source</th>
                      <th className="px-3 py-2">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {mapped.map((item) => (
                      <tr key={item.label} className={`border-b border-slate-100 ${LIVE_CALIBRATION_REQUIRED.has(item.label) && (item.low === null || item.riskNote) ? "bg-amber-100 ring-1 ring-inset ring-amber-300" : ""}`}>
                        <td className="px-3 py-3 font-semibold text-slate-800">{item.label}</td>
                        <td className="px-3 py-3 font-mono text-slate-700">{price(item.lastClose)}</td>
                        <LiveQuoteCell item={item} refreshing={Boolean(manualQuoteLoading[item.label])}
                          disabled={item.label === "ESMain" || item.label === "NQMain" ? futuresStatus === "loading" : liveStatus === "loading"}
                          allowRefresh={!(["SPY", "ESMain", "QQQ", "TQQQ", "SPXL", "NQMain"].includes(item.label))}
                          error={manualQuoteErrors[item.label]} onRefresh={(symbol) => { void refreshQuote(symbol); }} />
                        <td className="px-3 py-3 font-mono text-slate-700">
                          {item.low === null || item.high === null ? (LIVE_CALIBRATION_REQUIRED.has(item.label) ? <strong className="text-amber-900">Unavailable — live SPY/target mapping</strong> : "n/a") : (
                            <>
                              <div>{price(item.low)} <span className="text-xs text-slate-500">{percentLabel(item.low, item.lastClose)}</span></div>
                              <div>{price(item.high)} <span className="text-xs text-slate-500">{percentLabel(item.high, item.lastClose)}</span></div>
                            </>
                          )}
                        </td>
                        <td className="px-3 py-3 font-mono text-slate-700">
                          {price(item.mid)} <span className="text-xs text-slate-500">{percentLabel(item.mid, item.lastClose)}</span>
                        </td>
                        <td className="px-3 py-3 text-xs text-slate-500">{item.sourceColumn || (LIVE_CALIBRATION_REQUIRED.has(item.label) ? "Live SPY/target mapping unavailable" : "Unavailable")}{item.clamped ? " (clamped)" : ""}{item.mappingNote ? <span className="block font-semibold text-amber-900">{item.mappingNote}</span> : null}{item.riskNote ? <span className="block font-semibold text-amber-900">{item.riskNote}</span> : null}</td>
                        <td className="px-3 py-3">
                          <div className="flex flex-wrap gap-2">
                            {orderHref(item, zone, "Buy") ? <a href={orderHref(item, zone, "Buy")} target="_blank" rel="noopener noreferrer" className="rounded border border-indigo-200 bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100">Buy range</a> : null}
                            {orderHref(item, zone, "Sell") ? <a href={orderHref(item, zone, "Sell")} target="_blank" rel="noopener noreferrer" className="rounded border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 hover:bg-amber-100">Sell range</a> : null}
                            {(item.label === "ESMain" || item.label === "NQMain") && <span className="text-xs text-slate-500">Futures orders not supported</span>}
                            {optionHref(item, zone) ? <a href={optionHref(item, zone)} target="_blank" rel="noopener noreferrer" className="rounded border border-violet-200 bg-violet-50 px-2 py-1 text-xs font-medium text-violet-700 hover:bg-violet-100">{zone.side === "support" ? "Sell put" : "Buy put"}</a> : null}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <details className="border-t border-slate-200 px-5 py-4" onToggle={(event) => {
                if (event.currentTarget.open) setExtraExpanded(true);
              }}>
                <summary className="cursor-pointer font-semibold text-indigo-700">More stocks ({EXTRA_STOCK_SYMBOLS.length}) — show mapped levels and orders</summary>
                {extraExpanded ? (
                  <div className="mt-4 overflow-x-auto">
                    {!mapping?.historical_close_date && <p className="mb-2 text-sm text-amber-800">Selected report date unavailable; 30-minute closes cannot be loaded.</p>}
                    {mapping?.historical_close_date && extraClosesStatus === "loading" && <p className="mb-2 text-sm text-slate-600">Loading 30-minute stock closes...</p>}
                    {extraClosesStatus === "unavailable" && <p className="mb-2 text-sm text-amber-800">30-minute stock closes unavailable. Check the mapped-prices API or backend deployment.</p>}
                    <p className="mb-2 text-sm text-slate-600">More stocks do not request IB quotes automatically. Click ↻ next to an individual stock to fetch its live price.</p>
                    <table className="min-w-[900px] w-full text-sm">
                      <thead><tr className="border-b border-slate-200 text-left text-xs uppercase text-slate-500">
                        <th className="px-3 py-2">Instrument</th><th className="px-3 py-2">Last close</th>
                        <th className="px-3 py-2">Live price</th><th className="px-3 py-2">Mapped range (% vs close)</th>
                        <th className="px-3 py-2">Mapped reference anchor (vs selected close)</th><th className="px-3 py-2">Source</th>
                        <th className="px-3 py-2">Actions</th>
                      </tr></thead>
                      <tbody>{extraMapped.map((item) => (
                        <tr key={item.label} className={`border-b border-slate-100 ${item.low === null || item.riskNote ? "bg-amber-100 ring-1 ring-inset ring-amber-300" : ""}`}>
                          <td className="px-3 py-3 font-semibold text-slate-800">{item.label}</td>
                          <td className="px-3 py-3 font-mono">{price(item.lastClose)}{item.lastClose !== null && <span className="block text-xs text-slate-500">30M · {extraSnapshot?.closeDates[item.label] || "date n/a"}</span>}</td>
                          <LiveQuoteCell item={item} refreshing={Boolean(manualQuoteLoading[item.label])}
                            disabled={false} error={manualQuoteErrors[item.label]} onRefresh={(symbol) => { void refreshQuote(symbol); }} />
                          <td className="px-3 py-3 font-mono">{item.low === null || item.high === null ? <strong className="text-amber-900">Unavailable — live SPY/target mapping</strong> : <>
                            <div>{price(item.low)} <span className="text-xs text-slate-500">{percentLabel(item.low, item.lastClose)}</span></div>
                            <div>{price(item.high)} <span className="text-xs text-slate-500">{percentLabel(item.high, item.lastClose)}</span></div>
                          </>}</td>
                          <td className="px-3 py-3 font-mono">{price(item.mid)} <span className="text-xs text-slate-500">{percentLabel(item.mid, item.lastClose)}</span></td>
                          <td className="px-3 py-3 text-xs text-slate-500">{item.sourceColumn || "Live SPY/target mapping unavailable"}{item.mappingNote && <span className="block font-semibold text-amber-900">{item.mappingNote}</span>}{item.riskNote && <span className="block font-semibold text-amber-900">{item.riskNote}</span>}</td>
                          <td className="px-3 py-3"><div className="flex flex-wrap gap-2">
                            {item.low === null || item.high === null || item.mid === null ? (
                              <span className="text-xs font-medium text-amber-900">Buy range · Sell range · Sell put unavailable</span>
                            ) : <>
                              <a href={orderHref(item, zone, "Buy")} target="_blank" rel="noopener noreferrer" className="rounded border border-indigo-200 bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700">Buy range</a>
                              <a href={orderHref(item, zone, "Sell")} target="_blank" rel="noopener noreferrer" className="rounded border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700">Sell range</a>
                              <a href={optionHref(item, zone, "SELL")} target="_blank" rel="noopener noreferrer" className="rounded border border-violet-200 bg-violet-50 px-2 py-1 text-xs font-medium text-violet-700">Sell put</a>
                            </>}
                          </div></td>
                        </tr>
                      ))}</tbody>
                    </table>
                  </div>
                ) : null}
              </details>
            </section>
          );
        })}
      </div>
      <Button type="button" variant="secondary" onClick={() => window.close()}>Close tab</Button>
    </div>
  );
}
