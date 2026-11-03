import { assessLiveMoveRatio, liveMoveSpread, mappedFromLeveragedParent, mappedFromSpy, mappedFromSpySpread, shouldUseMoveRatio } from "../spx-map-reports/[jobId]/mapped-levels/calibration";
import { matchedEsBasis } from "../spx-map-reports/[jobId]/mapped-levels/esBasis";
import type { MapZone } from "./stockMapLevels";

export type SpxMapCode = "SPX" | "ESMain" | "SPY_D" | "QQQ_D" | "SPXL_D" | "TQQQ_D" | "SOXL_D" | "SOXX_D";
const mappedCodes: Record<string, SpxMapCode> = {
  SPX: "SPX", ESMAIN: "ESMain", SPY_D: "SPY_D", QQQ_D: "QQQ_D", SPXL_D: "SPXL_D", TQQQ_D: "TQQQ_D",
  SOXL_D: "SOXL_D", SOXX_D: "SOXX_D",
};
export function spxInstrumentForCode(value: string): SpxMapCode | null {
  return mappedCodes[value.trim().toUpperCase().replace(/\.US$/, "")] || null;
}

export type SpxMappingSnapshot = {
  historical_closes?: Record<string, number>;
  historical_close_dates?: Record<string, string>;
  effective_prices?: Record<string, number | null>;
  effective_price_source?: string | null;
  effective_price_timestamp?: string | null;
  effective_price_timestamps?: Record<string, string | null>;
  calibration_eligible?: boolean;
};
export type SpxDerivedZones = { zones: MapZone[]; source: string };
export function effectivePriceForSpxInstrument(code: SpxMapCode, effectivePrices: Record<string, number | null | undefined> | undefined): number | null {
  const key = code === "SPX" ? "SPX" : code === "ESMain" ? "ESMain" : code.replace(/_D$/, "");
  const value = effectivePrices?.[key];
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : null;
}
const positive = (value: unknown): value is number => typeof value === "number" && Number.isFinite(value) && value > 0;

/** Map report SPX zones using selected-report closes and each instrument's report-time effective prices. */
export function deriveSpxZones(zones: MapZone[], code: SpxMapCode, snapshot: SpxMappingSnapshot, live: Record<string, number>): SpxDerivedZones | null {
  if (code === "SPX") return { zones, source: "Original SPX report zones" };
  const closes = snapshot.historical_closes || {};
  const dates = snapshot.historical_close_dates || {};
  const spxClose = closes.SPX;
  const sessionDate = dates.SPX;
  const hasMatchedCloses = (...symbols: string[]) => Boolean(sessionDate) && symbols.every((symbol) =>
    positive(closes[symbol]) && dates[symbol] === sessionDate);

  let source = "";
  let project: (value: number) => number;
  if (code === "ESMain") {
    const basis = matchedEsBasis(snapshot);
    if (basis === null) return null;
    source = `ES = SPX + matched ${sessionDate} cash-close ES−SPX basis ${basis >= 0 ? "+" : ""}${basis.toFixed(2)}`;
    project = (value) => value + basis;
  } else {
    if (!hasMatchedCloses("SPX", "SPY") || !positive(spxClose)) return null;
    const spyClose = closes.SPY;
    const spyProject = (value: number) => spyClose * (1 + (value - spxClose) / spxClose);
    if (code === "SPY_D") {
      source = `SPY close (${sessionDate}) × (1 + SPX level change from matched SPX close)`;
      project = spyProject;
    } else if (code === "SPXL_D") {
      if (!hasMatchedCloses("SPXL")) return null;
      source = `SPXL derived from mapped SPY move ×3 (${sessionDate} matched closes)`;
      project = (value) => mappedFromLeveragedParent(spyProject(value), spyClose, closes.SPXL);
    } else {
      const semiconductor = code === "SOXL_D" || code === "SOXX_D";
      // SOXL and SOXX follow different semiconductor benchmarks. Calibrate
      // each from its own observed IB move against SPY, never assume SOXL is
      // SOXX ×3 or infer an old report's move from today's IB quotes.
      const target = semiconductor ? code.replace(/_D$/, "") : "QQQ";
      if (!hasMatchedCloses(target) || !positive(live.SPY) || !positive(live[target])) return null;
      const targetClose = closes[target];
      const spyMove = live.SPY / spyClose - 1;
      const targetMove = live[target] / targetClose - 1;
      const ratioMode = shouldUseMoveRatio(spyMove, targetMove);
      const ratio = ratioMode ? assessLiveMoveRatio(spyClose, live.SPY, targetClose, live[target]).ratio : null;
      const spread = ratioMode ? null : liveMoveSpread(spyClose, live.SPY, targetClose, live[target]);
      if (ratio === null && spread === null) return null;
      const targetProject = (value: number) => ratio !== null
        ? mappedFromSpy(spyProject(value), spyClose, targetClose, ratio)
        : mappedFromSpySpread(spyProject(value), spyClose, targetClose, spread!);
      source = ratio !== null
        ? `${target} from report-time SPY mapped move × observed ${target}/SPY move ratio ${ratio.toFixed(2)}× (${sessionDate} matched closes)`
        : `${target} from report-time SPY mapped move + observed ${target}−SPY move spread ${((spread || 0) * 100).toFixed(3)}pp (${sessionDate} matched closes)`;
      if (code === "TQQQ_D") {
        if (!hasMatchedCloses("TQQQ")) return null;
        source += "; TQQQ from mapped QQQ move ×3";
        project = (value) => mappedFromLeveragedParent(targetProject(value), targetClose, closes.TQQQ);
      } else {
        project = targetProject;
      }
    }
  }
  const closeSymbol = code === "ESMain" ? "ESMain" : code.replace(/_D$/, "");
  const selectedClose = closes[closeSymbol];
  const selectedCloseDate = dates[closeSymbol];
  if (!positive(selectedClose) || selectedCloseDate !== sessionDate) return null;
  const mapped = zones.flatMap((zone) => {
    const low = project(zone.range_low);
    const high = project(zone.range_high);
    const anchor = project(zone.price);
    if (![low, high, anchor].every(positive)) return [];
    return [{ ...zone, range_low: Math.min(low, high), range_high: Math.max(low, high), price: anchor,
      details: { ...zone.details, derived_instrument: code,
        mapped_zone_low: Math.min(low, high), mapped_zone_high: Math.max(low, high), mapped_anchor: anchor,
        mapping_selected_close: selectedClose, mapping_selected_close_date: selectedCloseDate,
        mapped_anchor_vs_selected_close_pct: (anchor / selectedClose - 1) * 100,
        source_spx_range: [zone.range_low, zone.range_high], source_spx_anchor: zone.price,
        mapping_source: source } }];
  });
  return { zones: mapped, source };
}
