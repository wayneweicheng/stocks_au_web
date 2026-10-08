"use client";

import { use, useEffect, useMemo, useState } from "react";

import Alert from "../../../components/ui/Alert";
import Button from "../../../components/ui/Button";
import PageHeader from "../../../components/PageHeader";
import { authenticatedFetch } from "../../../utils/authenticatedFetch";

type JsonObject = Record<string, unknown>;
type LevelSide = "support" | "resistance";
type ReferenceSide = LevelSide | "reference";

type StockZone = {
  id: string;
  side: LevelSide;
  rank: number;
  low: number;
  high: number;
  center: number;
  score: number | null;
  confidence: string;
  levelConfidence: string;
};

type MappedStock = {
  label: string;
  orderSymbol: string;
  sourceColumn: string;
  low: number;
  high: number;
  mid: number;
  lastClose: number | null;
  livePrice: number | null;
  clamped: boolean;
};

type StockPrices = {
  last_close?: number | null;
  last_close_source?: string | null;
  last_close_timestamp?: string | null;
  atr_14d?: number | null;
  atr_source?: string | null;
  live_price?: number | null;
  live_price_source?: string | null;
};

type ReferenceLevel = {
  id: string;
  label: string;
  side: ReferenceSide;
  timeframe: string;
  price: number;
  low: number | null;
  high: number | null;
  levelClass: string;
  formula: string;
};

function numberValue(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeStockCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const code = value.trim().toUpperCase();
  if (!code) return null;
  return code.replace(/\.(?:US|AX)$/i, "");
}

function firstStockCode(data: JsonObject, routeStockCode: string): string {
  const metadata = [data.metadata, data.meta, data.parameters]
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"));
  const candidates = [
    routeStockCode,
    data.instrument_code,
    data.stock_code,
    data.ticker,
    data.symbol,
    ...metadata.flatMap((value) => [value.instrument_code, value.stock_code, value.ticker, value.symbol]),
  ];
  return candidates.map(normalizeStockCode).find((value): value is string => Boolean(value)) || "";
}

function observationDateFromData(data: JsonObject): string | null {
  const metadata = [data.metadata, data.meta, data.parameters]
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"));
  const candidates = [
    data.observation_date,
    data.observationDate,
    data.as_of_date,
    data.as_at,
    data.asAt,
    ...metadata.flatMap((value) => [value.observation_date, value.observationDate, value.as_of_date, value.as_at]),
  ];
  for (const candidate of candidates) {
    if (typeof candidate !== "string") continue;
    const match = candidate.match(/\d{4}-\d{2}-\d{2}/);
    if (match) return match[0];
  }
  return null;
}

function price(value: number | null) {
  return value === null ? "n/a" : value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
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

function matchingZoneMetadata(data: JsonObject, side: LevelSide, reference: number): JsonObject | null {
  const candidates = data[`zone_primary_${side}s`];
  if (!Array.isArray(candidates)) return null;
  const matches = candidates
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"))
    .map((candidate) => ({
      candidate,
      distance: Math.abs(
        (numberValue(candidate.tradable_center) ?? numberValue(candidate.mathematical_center) ?? reference) - reference,
      ),
    }))
    .sort((left, right) => left.distance - right.distance);
  const closest = matches[0];
  // The six-level ladder and the consolidated zones are generated from the same
  // daily levels. Avoid borrowing a score from an unrelated zone in sparse maps.
  return closest && closest.distance <= Math.max(0.25, Math.abs(reference) * 0.002)
    ? closest.candidate
    : null;
}

function displayText(value: unknown): string {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ");
}

function timeframeLabel(value: unknown): string {
  const text = displayText(value);
  if (!text) return "";
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function referenceSide(value: unknown): ReferenceSide {
  const side = String(value || "").trim().toLowerCase();
  if (side.includes("support")) return "support";
  if (side.includes("resistance")) return "resistance";
  return "reference";
}

function referenceRows(data: JsonObject): JsonObject[] {
  const nearTerm = data.near_term_raw_levels;
  if (Array.isArray(nearTerm) && nearTerm.length > 0) {
    return nearTerm.filter((value): value is JsonObject => Boolean(value && typeof value === "object"));
  }

  const rawLevels = data.raw_levels;
  const technicalLevels = data.technical_levels;
  const technicalRows = technicalLevels && typeof technicalLevels === "object"
    ? (technicalLevels as JsonObject).levels
    : null;
  const fallback = [
    ...(Array.isArray(rawLevels) ? rawLevels : []),
    ...(Array.isArray(technicalRows) ? technicalRows : []),
  ];
  return fallback
    .filter((value): value is JsonObject => Boolean(value && typeof value === "object"))
    .filter((row) => {
      const timeframe = String(row.timeframe || "").toLowerCase();
      const levelClass = String(row.level_class || "").toLowerCase();
      const id = String(row.id || "").toLowerCase();
      return timeframe === "daily" || levelClass === "technical" || id.startsWith("daily:");
    });
}

function extractReferenceLevels(data: JsonObject): ReferenceLevel[] {
  const levels: ReferenceLevel[] = [];
  const seen = new Set<string>();

  referenceRows(data).forEach((row, index) => {
    const exact = numberValue(row.exact_value) ?? numberValue(row.price) ?? numberValue(row.value);
    if (exact === null) return;

    const timeframe = timeframeLabel(row.timeframe) || "Reference";
    const levelType = displayText(row.level_type || row.name || row.label) || `Level ${index + 1}`;
    const id = String(row.id || `${timeframe}-${levelType}-${exact}`);
    if (seen.has(id)) return;
    seen.add(id);

    const interval = Array.isArray(row.interval)
      ? row.interval.map(numberValue).filter((value): value is number => value !== null)
      : [];
    const low = interval.length >= 2 ? Math.min(...interval) : numberValue(row.low);
    const high = interval.length >= 2 ? Math.max(...interval) : numberValue(row.high);
    levels.push({
      id,
      label: `${timeframe} ${levelType}`,
      side: referenceSide(row.polarity),
      timeframe,
      price: exact,
      low,
      high,
      levelClass: displayText(row.level_class) || "reference",
      formula: displayText(row.formula),
    });
  });

  const executionReference = numberValue(data.execution_reference);
  if (executionReference !== null) {
    const existing = levels.find((level) => Math.abs(level.price - executionReference) < 0.000001);
    if (existing) {
      existing.label = `Execution reference · ${existing.label}`;
    } else {
      levels.push({
        id: "execution-reference",
        label: "Execution reference",
        side: "reference",
        timeframe: "Current",
        price: executionReference,
        low: null,
        high: null,
        levelClass: displayText(data.execution_reference_type) || "reference",
        formula: "",
      });
    }
  }

  return levels.sort((left, right) => right.price - left.price);
}

function extractZones(data: JsonObject): StockZone[] {
  const zones: StockZone[] = [];
  for (const side of ["support", "resistance"] as const) {
    const rawLevels = data[side === "support" ? "primary_supports" : "primary_resistances"];
    if (!Array.isArray(rawLevels)) continue;
    rawLevels.forEach((raw, index) => {
      if (!raw || typeof raw !== "object") return;
      const row = raw as JsonObject;
      const low = numberValue(row.zone_low);
      const high = numberValue(row.zone_high);
      if (low === null || high === null) return;
      const center = numberValue(row.tradable_center) ?? numberValue(row.mathematical_center) ?? (low + high) / 2;
      const metadata = matchingZoneMetadata(data, side, center);
      zones.push({
        id: `${side}-${index}-${low}-${high}`,
        side,
        rank: numberValue(row.rank) ?? index + 1,
        low: Math.min(low, high),
        high: Math.max(low, high),
        center,
        score: numberValue(row.total_score) ?? numberValue(metadata?.total_score),
        confidence: String(row.confidence || metadata?.confidence || "unknown"),
        levelConfidence: String(row.level_confidence || metadata?.level_confidence || ""),
      });
    });
  }
  return zones.sort((left, right) => left.side.localeCompare(right.side) || left.rank - right.rank);
}

function percentChange(value: number | null, lastClose: number | null) {
  if (value === null || lastClose === null || lastClose === 0) return null;
  return ((value - lastClose) / lastClose) * 100;
}

function percentLabel(value: number | null, lastClose: number | null) {
  const change = percentChange(value, lastClose);
  return change === null ? "" : `(${change >= 0 ? "+" : ""}${change.toFixed(2)}%)`;
}

function wholeMapRange(zones: StockZone[], atr14d: number | null) {
  if (!zones.length) return null;
  const lowestLevel = Math.min(...zones.map((zone) => zone.center));
  const highestLevel = Math.max(...zones.map((zone) => zone.center));
  const observedWidth = highestLevel - lowestLevel;
  const targetWidth = atr14d !== null && atr14d > 0 ? atr14d * 4 : observedWidth;
  const width = Math.max(observedWidth, targetWidth);
  const midpoint = (lowestLevel + highestLevel) / 2;
  return {
    lowestLevel,
    highestLevel,
    low: midpoint - width / 2,
    high: midpoint + width / 2,
    width,
    targetWidth,
    atrApplied: atr14d !== null && atr14d > 0,
  };
}

function orderHref(mapped: MappedStock, side: "Buy" | "Sell") {
  const params = new URLSearchParams({
    stock: mapped.orderSymbol,
    side,
    start: mapped.low.toFixed(2),
    end: mapped.high.toFixed(2),
    num_orders: "5",
    total_amount: "30000",
  });
  return `/range-orders?${params.toString()}`;
}

function referenceOrderHref(stockCode: string, level: ReferenceLevel, side: "Buy" | "Sell") {
  const params = new URLSearchParams({
    stock: stockCode,
    side,
    start: (level.low ?? level.price).toFixed(2),
    end: (level.high ?? level.price).toFixed(2),
    num_orders: "5",
    total_amount: "30000",
  });
  return `/range-orders?${params.toString()}`;
}

function optionHref(mapped: MappedStock, zone: StockZone) {
  const params = new URLSearchParams({
    symbol: mapped.orderSymbol,
    right: "P",
    action: zone.side === "support" ? "SELL" : "BUY",
    target: mapped.mid.toFixed(2),
    auto: "1",
  });
  return `/option-orders?${params.toString()}`;
}

export default function StockMappedLevelsPage({ params }: { params: Promise<{ jobId: string }> }) {
  const { jobId } = use(params);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [mapData, setMapData] = useState<JsonObject | null>(null);
  const [stockPrices, setStockPrices] = useState<StockPrices | null>(null);
  const [routeStockCode, setRouteStockCode] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const queryParams = new URLSearchParams(window.location.search);
        const queryStockCode = queryParams.get("stock_code") || "";
        const queryObservationDate = queryParams.get("observation_date") || "";
        setRouteStockCode(queryStockCode);
        const mapResponse = await authenticatedFetch(
          `${baseUrl}/api/stock-map-reports/${encodeURIComponent(jobId)}/json`,
          { cache: "no-store" },
        );
        const mapPayload = await mapResponse.json().catch(() => ({}));
        if (!mapResponse.ok) throw new Error(mapPayload.detail || `Stock Map JSON request failed: HTTP ${mapResponse.status}`);
        const parsedMap = parseMapData(mapPayload.data ?? mapPayload);
        if (!parsedMap) throw new Error("The Stock Map JSON artifact was not returned in a readable format.");

        const stockCode = firstStockCode(parsedMap, queryStockCode);
        if (!stockCode) throw new Error("The Stock Map JSON did not identify the stock.");
        const pricesUrl = new URL(`${baseUrl}/api/stock-map-prices`, window.location.origin);
        pricesUrl.searchParams.set("stock_code", stockCode);
        const observationDate = queryObservationDate || observationDateFromData(parsedMap);
        if (observationDate) pricesUrl.searchParams.set("observation_date", observationDate);
        const pricesResponse = await authenticatedFetch(pricesUrl.toString(), { cache: "no-store" });
        const pricesPayload = await pricesResponse.json().catch(() => ({}));
        if (!pricesResponse.ok) throw new Error(pricesPayload.detail || `Stock mapped prices request failed: HTTP ${pricesResponse.status}`);

        setMapData(parsedMap);
        setStockPrices(pricesPayload as StockPrices);
      } catch (loadError) {
        setError(loadError instanceof Error ? loadError.message : "Unable to load mapped stock levels.");
      } finally {
        setLoading(false);
      }
    };
    void load();
  }, [baseUrl, jobId]);

  const zones = useMemo(() => (mapData ? extractZones(mapData) : []), [mapData]);
  const stockCode = mapData ? firstStockCode(mapData, routeStockCode) : (normalizeStockCode(routeStockCode) || "Mapped stock");
  const stockLastClose = stockPrices?.last_close ?? null;
  const stockLivePrice = stockPrices?.live_price ?? null;
  const atr14d = stockPrices?.atr_14d ?? null;
  const overallRange = useMemo(() => wholeMapRange(zones, atr14d), [zones, atr14d]);
  const referenceLevels = useMemo(() => (mapData ? extractReferenceLevels(mapData) : []), [mapData]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={`${stockCode} Mapped Levels and Orders`}
        subtitle={`Job ${jobId}. Each price level shows mapped prices and actions for ${stockCode} only.`}
      />
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {loading ? <div className="rounded-lg border border-slate-200 bg-white p-6 text-sm text-slate-500">Loading Stock Map JSON...</div> : null}
      {!loading && !error && zones.length === 0 ? <Alert variant="warning">No primary stock support or resistance zones were found in the JSON report.</Alert> : null}
      {!loading && !error && overallRange ? (
        <section className="rounded-lg border border-indigo-200 bg-indigo-50 p-5 shadow-sm">
          <h2 className="text-lg font-semibold text-indigo-950">Overall six-level price range</h2>
          <p className="mt-1 text-sm text-indigo-800">
            Lowest support {price(overallRange.lowestLevel)} to highest resistance {price(overallRange.highestLevel)}.
          </p>
          <div className="mt-3 flex flex-wrap gap-x-8 gap-y-2 text-sm text-indigo-900">
            <span>Applied range: <strong>{price(overallRange.low)} – {price(overallRange.high)}</strong></span>
            <span>Full width: <strong>{price(overallRange.width)}</strong></span>
            {overallRange.atrApplied ? <span>Target: <strong>4 × ATR(14D) = {price(overallRange.targetWidth)}</strong></span> : null}
          </div>
        </section>
      ) : null}

      {!loading && !error && referenceLevels.length > 0 ? (
        <section className="rounded-lg border border-slate-300 bg-slate-50 shadow-sm">
          <div className="border-b border-slate-200 px-5 py-4">
            <h2 className="text-lg font-semibold text-slate-900">Reference price levels</h2>
            <p className="mt-1 text-sm text-slate-600">
              Daily pivot, CPR, midpoint, prior-price, and technical reference levels from the Stock Map. These references are shown separately from the primary actionable zones.
            </p>
          </div>
          <div className="overflow-x-auto p-5">
            <table className="min-w-[900px] w-full text-sm">
              <thead>
                <tr className="border-b border-slate-200 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">
                  <th className="px-3 py-2">Reference</th>
                  <th className="px-3 py-2">Price (% vs close)</th>
                  <th className="px-3 py-2">Side</th>
                  <th className="px-3 py-2">Timeframe</th>
                  <th className="px-3 py-2">Reference band</th>
                  <th className="px-3 py-2">Source</th>
                  <th className="px-3 py-2">Actions</th>
                </tr>
              </thead>
              <tbody>
                {referenceLevels.map((level) => {
                  const sideLabel = level.side === "support" ? "Support" : level.side === "resistance" ? "Resistance" : "Reference";
                  const sideClass = level.side === "support" ? "text-emerald-700" : level.side === "resistance" ? "text-red-700" : "text-slate-600";
                  const hasBand = level.low !== null && level.high !== null && Math.abs(level.high - level.low) > 0.000001;
                  return (
                    <tr key={level.id} className="border-b border-slate-100 last:border-b-0">
                      <td className="px-3 py-3 font-semibold text-slate-800">{level.label}</td>
                      <td className="px-3 py-3 font-mono text-slate-700">
                        {price(level.price)} <span className="text-xs text-slate-500">{percentLabel(level.price, stockLastClose)}</span>
                      </td>
                      <td className={`px-3 py-3 text-xs font-semibold uppercase tracking-wide ${sideClass}`}>{sideLabel}</td>
                      <td className="px-3 py-3 text-slate-600">{level.timeframe}</td>
                      <td className="px-3 py-3 font-mono text-slate-600">
                        {hasBand ? `${price(level.low)} – ${price(level.high)}` : "—"}
                      </td>
                      <td className="px-3 py-3 text-xs text-slate-500">
                        <div>{level.levelClass}</div>
                        {level.formula ? <div className="mt-1 max-w-[360px]">{level.formula}</div> : null}
                      </td>
                      <td className="px-3 py-3">
                        <div className="flex flex-wrap gap-2">
                          <a
                            href={referenceOrderHref(stockCode, level, "Buy")}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="rounded border border-indigo-200 bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100"
                          >
                            Buy range
                          </a>
                          <a
                            href={referenceOrderHref(stockCode, level, "Sell")}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="rounded border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 hover:bg-amber-100"
                          >
                            Sell range
                          </a>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      <div className="space-y-5">
        {zones.map((zone) => {
          const mapped: MappedStock = {
            label: stockCode,
            orderSymbol: stockCode,
            sourceColumn: "Stock Map",
            low: zone.low,
            high: zone.high,
            mid: zone.center,
            lastClose: stockLastClose,
            livePrice: stockLivePrice,
            clamped: false,
          };
          return (
            <section key={zone.id} className="rounded-lg border border-slate-200 bg-white shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-200 bg-slate-50 px-5 py-4">
                <div>
                  <div className={`text-xs font-semibold uppercase tracking-wide ${zone.side === "support" ? "text-emerald-700" : "text-red-700"}`}>
                    {zone.side === "support" ? "Support" : "Resistance"} #{zone.rank}
                  </div>
                  <h2 className="mt-1 text-lg font-semibold text-slate-900">{stockCode} {price(mapped.low)} – {price(mapped.high)}</h2>
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
                      <th className="px-3 py-2">Stock</th>
                      <th className="px-3 py-2">Last close (30M)</th>
                      <th className="px-3 py-2">Live price (IB)</th>
                      <th className="px-3 py-2">ATR range (% vs close)</th>
                      <th className="px-3 py-2">Mid (% vs close)</th>
                      <th className="px-3 py-2">Source</th>
                      <th className="px-3 py-2">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-slate-100">
                      <td className="px-3 py-3 font-semibold text-slate-800">{mapped.label}</td>
                      <td className="px-3 py-3 font-mono text-slate-700">
                        {price(mapped.lastClose)}
                        <div className="text-xs font-sans text-slate-400">{stockPrices?.last_close_source || "n/a"}</div>
                      </td>
                      <td className="px-3 py-3 font-mono text-slate-700">
                        {price(mapped.livePrice)}
                        <div className="text-xs font-sans text-slate-400">{stockPrices?.live_price_source || "n/a"}</div>
                      </td>
                      <td className="px-3 py-3 font-mono text-slate-700">
                        <div>{price(mapped.low)} <span className="text-xs text-slate-500">{percentLabel(mapped.low, mapped.lastClose)}</span></div>
                        <div>{price(mapped.high)} <span className="text-xs text-slate-500">{percentLabel(mapped.high, mapped.lastClose)}</span></div>
                      </td>
                      <td className="px-3 py-3 font-mono text-slate-700">
                        {price(mapped.mid)} <span className="text-xs text-slate-500">{percentLabel(mapped.mid, mapped.lastClose)}</span>
                      </td>
                      <td className="px-3 py-3 text-xs text-slate-500">{mapped.sourceColumn}</td>
                      <td className="px-3 py-3">
                        <div className="flex flex-wrap gap-2">
                          <a href={orderHref(mapped, "Buy")} target="_blank" rel="noopener noreferrer" className="rounded border border-indigo-200 bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100">Buy range</a>
                          <a href={orderHref(mapped, "Sell")} target="_blank" rel="noopener noreferrer" className="rounded border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 hover:bg-amber-100">Sell range</a>
                          <a href={optionHref(mapped, zone)} target="_blank" rel="noopener noreferrer" className="rounded border border-violet-200 bg-violet-50 px-2 py-1 text-xs font-medium text-violet-700 hover:bg-violet-100">{zone.side === "support" ? "Sell put" : "Buy put"}</a>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          );
        })}
      </div>
      <Button type="button" variant="secondary" onClick={() => window.close()}>Close tab</Button>
    </div>
  );
}
