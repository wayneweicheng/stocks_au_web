"use client";

import { use, useEffect, useMemo, useState } from "react";

import Alert from "../../../components/ui/Alert";
import Button from "../../../components/ui/Button";
import PageHeader from "../../../components/PageHeader";
import MappedLevelReportDetails, {
  levelReportKey,
  parseHtmlLevelDetails,
  type HtmlLevelDetail,
} from "../../../components/MappedLevelReportDetails";
import { authenticatedFetch } from "../../../utils/authenticatedFetch";

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
  price_differences?: Record<string, number>;
  live_prices?: Record<string, number>;
  live_prices_status?: string;
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
};

const INSTRUMENTS: Instrument[] = [
  { label: "SPY", mappingKeys: ["SPY"], orderSymbol: "SPY" },
  { label: "QQQ", mappingKeys: ["QQQ"], orderSymbol: "QQQ" },
  { label: "SPXL", mappingKeys: ["SPXL"], orderSymbol: "SPXL" },
  { label: "TQQQ", mappingKeys: ["TQQQ"], orderSymbol: "TQQQ" },
  { label: "ESMain", mappingKeys: ["ESMain", "ESMAIN", "ES", "MES"], orderSymbol: "MES" },
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
        rank: numberValue(row.rank) ?? index + 1,
        low: Math.min(low, high),
        high: Math.max(low, high),
        center: numberValue(row.tradable_center) ?? numberValue(row.mathematical_center) ?? (low + high) / 2,
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
): MappedInstrument {
  const historicalClose = (keys: string[]) => keys
    .map((key) => numberValue(historicalCloses[key]))
    .find((value): value is number => value !== null) ?? null;
  const lastClose = historicalClose([instrument.label, ...instrument.mappingKeys]);
  const livePrice = numberValue(livePrices[instrument.label]);
  const noMapping = { ...instrument, sourceColumn: null, low: null, high: null, mid: null, lastClose, livePrice, clamped: false };
  const spxClose = numberValue(historicalCloses.SPX);

  if (instrument.label === "ESMain") {
    if (spxClose === null || lastClose === null) return noMapping;
    const difference = numberValue(priceDifferences.ESMain) ?? lastClose - spxClose;
    return {
      ...instrument,
      sourceColumn: `SPX difference (${difference >= 0 ? "+" : ""}${difference.toFixed(2)})`,
      low: zone.low + difference,
      high: zone.high + difference,
      mid: zone.center + difference,
      lastClose,
      livePrice,
      clamped: false,
    };
  }

  if (spxClose === null || lastClose === null || spxClose === 0) return noMapping;
  const factor = instrument.label === "SPXL" || instrument.label === "TQQQ" ? 3 : 1;
  const sourceLabel = factor === 3 ? "SPX % change × 3" : "SPX % change";
  const mapPrice = (value: number) => lastClose * (1 + (((value - spxClose) / spxClose) * factor));
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

function percentChange(value: number | null, lastClose: number | null) {
  if (value === null || lastClose === null || lastClose === 0) return null;
  return ((value - lastClose) / lastClose) * 100;
}

function percentLabel(value: number | null, lastClose: number | null) {
  const change = percentChange(value, lastClose);
  return change === null ? "" : `(${change >= 0 ? "+" : ""}${change.toFixed(2)}%)`;
}

function structureLabel(zone: SpxZone) {
  const parts = [`SPX ${price(zone.center)}`];
  if (zone.structure.label) parts.push(zone.structure.label);
  if (zone.structure.openInterest !== null) parts.push(`OI ${zone.structure.openInterest.toLocaleString()}`);
  if (zone.structure.gex !== null) parts.push(`|GEX| ${Math.abs(zone.structure.gex).toLocaleString()}`);
  return parts.join(" · ");
}

function orderHref(
  mapped: MappedInstrument,
  zone: SpxZone,
  side: "Buy" | "Sell" = zone.side === "support" ? "Buy" : "Sell",
  spyRange?: { low: number; high: number } | null,
) {
  const usesSpyProxy = mapped.label === "QQQ" || mapped.label === "TQQQ";
  const range = usesSpyProxy ? spyRange : mapped.low !== null && mapped.high !== null
    ? { low: mapped.low, high: mapped.high }
    : null;
  if (!range || range.low <= 0 || range.high < range.low) return "";
  const triggerLow = range.low;
  const triggerHigh = range.high;
  const params = new URLSearchParams({
    stock: mapped.orderSymbol,
    side,
    start: triggerLow.toFixed(2),
    end: triggerHigh.toFixed(2),
    num_orders: "5",
    total_amount: "30000",
  });
  if (usesSpyProxy) {
    params.set("proxy", "SPY");
    params.set("bracket", "1");
  }
  return `/range-orders?${params.toString()}`;
}

function optionHref(mapped: MappedInstrument, zone: SpxZone) {
  if (mapped.mid === null) return "";
  const params = new URLSearchParams({
    symbol: mapped.orderSymbol,
    right: "P",
    action: zone.side === "support" ? "SELL" : "BUY",
    target: mapped.mid.toFixed(2),
    auto: "1",
  });
  return `/option-orders?${params.toString()}`;
}

export default function SpxMappedLevelsPage({ params }: { params: Promise<{ jobId: string }> }) {
  const { jobId } = use(params);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [mapData, setMapData] = useState<JsonObject | null>(null);
  const [mapping, setMapping] = useState<MappingResponse | null>(null);
  const [htmlLevelDetails, setHtmlLevelDetails] = useState<Record<string, HtmlLevelDetail>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

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
        if (observationDate && queryDate !== observationDate) {
          const url = new URL(window.location.href);
          url.searchParams.set("observation_date", observationDate);
          window.history.replaceState(null, "", url.toString());
        }
        const pricesUrl = new URL(`${baseUrl}/api/spx-map-prices`, window.location.origin);
        if (observationDate) pricesUrl.searchParams.set("observation_date", observationDate);
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

  const zones = useMemo(() => (mapData ? extractZones(mapData) : []), [mapData]);
  const historicalCloses = mapping?.historical_closes || {};
  const priceDifferences = mapping?.price_differences || {};
  const livePrices = mapping?.live_prices || {};

  return (
    <div className="space-y-6">
      <PageHeader
        title="SPX Mapped Levels and Orders"
        subtitle={`Job ${jobId}. Mapped prices use the selected Daily SPX close. QQQ and TQQQ Buy/Sell range actions use their row's target stock with the SPY mapped range as the Pegasus proxy trigger; other instruments keep their mapped ranges.`}
      />
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {mapping?.live_prices_status === "not_requested_for_historical_mapping" ? (
        <Alert variant="info">Mapped ranges use historical closes. Current IB quotes are not requested for dated reports, so Live price shows n/a rather than delaying the map.</Alert>
      ) : null}
      {loading ? <div className="rounded-lg border border-slate-200 bg-white p-6 text-sm text-slate-500">Loading SPX JSON and mapped prices...</div> : null}
      {!loading && !error && zones.length === 0 ? <Alert variant="warning">No primary SPX support or resistance zones were found in the JSON report.</Alert> : null}

      <div className="space-y-5">
        {zones.map((zone) => {
          const mapped = INSTRUMENTS.map((instrument) => mapZone(
            zone,
            instrument,
            historicalCloses,
            priceDifferences,
            livePrices,
          ));
          const spyMapping = mapped.find((item) => item.label === "SPY");
          const spyRange = spyMapping?.low != null && spyMapping.high != null
            ? { low: spyMapping.low, high: spyMapping.high }
            : null;
          return (
            <section key={zone.id} className="rounded-lg border border-slate-200 bg-white shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-3 border-b border-slate-200 bg-slate-50 px-5 py-4">
                <div>
                  <div className={`text-xs font-semibold uppercase tracking-wide ${zone.side === "support" ? "text-emerald-700" : "text-red-700"}`}>
                    {zone.side === "support" ? "Support" : "Resistance"} #{zone.rank}
                  </div>
                  <h2 className="mt-1 text-lg font-semibold text-slate-900">{structureLabel(zone)}</h2>
                  <div className="text-xs text-slate-500">Range {price(zone.low)} – {price(zone.high)}</div>
                  <MappedLevelReportDetails
                    side={zone.side}
                    detail={htmlLevelDetails[levelReportKey(zone.side, zone.rank)]}
                    rank={zone.rank}
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
                      <th className="px-3 py-2">Live price</th>
                      <th className="px-3 py-2">Mapped range (% vs close)</th>
                      <th className="px-3 py-2">Mid (% vs close)</th>
                      <th className="px-3 py-2">Source</th>
                      <th className="px-3 py-2">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {mapped.map((item) => (
                      <tr key={item.label} className="border-b border-slate-100">
                        <td className="px-3 py-3 font-semibold text-slate-800">{item.label}</td>
                        <td className="px-3 py-3 font-mono text-slate-700">{price(item.lastClose)}</td>
                        <td className="px-3 py-3 font-mono text-slate-700">{price(item.livePrice)}</td>
                        <td className="px-3 py-3 font-mono text-slate-700">
                          {item.low === null || item.high === null ? "n/a" : (
                            <>
                              <div>{price(item.low)} <span className="text-xs text-slate-500">{percentLabel(item.low, item.lastClose)}</span></div>
                              <div>{price(item.high)} <span className="text-xs text-slate-500">{percentLabel(item.high, item.lastClose)}</span></div>
                            </>
                          )}
                        </td>
                        <td className="px-3 py-3 font-mono text-slate-700">
                          {price(item.mid)} <span className="text-xs text-slate-500">{percentLabel(item.mid, item.lastClose)}</span>
                        </td>
                        <td className="px-3 py-3 text-xs text-slate-500">{item.sourceColumn || "Unavailable"}{item.clamped ? " (clamped)" : ""}</td>
                        <td className="px-3 py-3">
                          <div className="flex flex-wrap gap-2">
                            {orderHref(item, zone, "Buy", spyRange) ? <a href={orderHref(item, zone, "Buy", spyRange)} target="_blank" rel="noopener noreferrer" title={item.label === "QQQ" || item.label === "TQQQ" ? `Open ${item.orderSymbol} Pegasus order with SPY ${price(spyRange?.low)}–${price(spyRange?.high)} as the trigger range` : undefined} className="rounded border border-indigo-200 bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100">Buy range</a> : null}
                            {orderHref(item, zone, "Sell", spyRange) ? <a href={orderHref(item, zone, "Sell", spyRange)} target="_blank" rel="noopener noreferrer" title={item.label === "QQQ" || item.label === "TQQQ" ? `Open ${item.orderSymbol} Pegasus order with SPY ${price(spyRange?.low)}–${price(spyRange?.high)} as the trigger range` : undefined} className="rounded border border-amber-200 bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700 hover:bg-amber-100">Sell range</a> : null}
                            {optionHref(item, zone) ? <a href={optionHref(item, zone)} target="_blank" rel="noopener noreferrer" className="rounded border border-violet-200 bg-violet-50 px-2 py-1 text-xs font-medium text-violet-700 hover:bg-violet-100">{zone.side === "support" ? "Sell put" : "Buy put"}</a> : null}
                          </div>
                        </td>
                      </tr>
                    ))}
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
