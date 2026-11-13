import { classifyMapZones, mapZones, type MapZone } from "../support-resistance/stockMapLevels";

export type RankedLevel = { zone: MapZone; distancePct: number | null };

export function levelMidpoint(zone: Pick<MapZone, "range_low" | "range_high">): number {
  return (zone.range_low + zone.range_high) / 2;
}

export function rangeOrderHref(symbol: string, side: SortSide, low: number, high: number): string {
  const params = new URLSearchParams({
    stock: symbol,
    side: side === "support" ? "Buy" : "Sell",
    start: low.toFixed(2),
    end: high.toFixed(2),
  });
  return `/range-orders?${params.toString()}`;
}

/** Reclassify report zones against the IB quote, then rank by report strength. */
export function topLevels(data: Record<string, unknown>, price: number | null): { supports: RankedLevel[]; resistances: RankedLevel[] } {
  const validPrice = price !== null && Number.isFinite(price) && price > 0 ? price : null;
  const reportSupports = mapZones(data, "support");
  const reportResistances = mapZones(data, "resistance");
  // Without an IB quote, retain report-side labels but do not invent a distance.
  const zones = validPrice === null
    ? { supports: reportSupports, resistances: reportResistances }
    : classifyMapZones(reportSupports, reportResistances, validPrice);
  const select = (levels: MapZone[]) => levels.map((zone) => ({
    zone,
    distancePct: validPrice === null ? null : Math.max(0, zone.range_low - validPrice, validPrice - zone.range_high) / validPrice * 100,
  })).sort((a, b) => (b.zone.score ?? -Infinity) - (a.zone.score ?? -Infinity) ||
    a.zone.rank - b.zone.rank || (a.distancePct ?? Infinity) - (b.distancePct ?? Infinity)).slice(0, 2);
  return { supports: select(zones.supports), resistances: select(zones.resistances) };
}

export function reportSymbol(report: { stock_code?: string | null; title?: string; file_name?: string | null; raw?: Record<string, unknown> }): string {
  const raw = report.raw || {};
  const value = [report.stock_code, raw.stock_code, raw.instrument_code, raw.ticker, raw.symbol]
    .find((candidate) => typeof candidate === "string" && candidate.trim());
  const fromTitle = [report.title, report.file_name].map((text) => text?.trim().match(/^([A-Z0-9.^-]+)(?=[:\s_])/i)?.[1]).find(Boolean);
  const code = String(value || fromTitle || "").trim().toUpperCase().replace(/\.(US|AX)$/, "");
  return code !== "STOCK" && /^[A-Z][A-Z0-9.-]{0,14}$/.test(code) ? code : "";
}

export type SortSide = "support" | "resistance";
export type SortChoice = { side: SortSide; direction: "asc" | "desc" } | null;

/** Sort across all reported stocks using only the strongest two zones on the chosen side. */
export function sortByZoneDistance<T extends { symbol: string; supports: RankedLevel[]; resistances: RankedLevel[] }>(rows: T[], sort: SortChoice): T[] {
  return [...rows].sort((a, b) => {
    if (!sort) return a.symbol.localeCompare(b.symbol);
    const distance = (row: T) => {
      const levels = sort.side === "support" ? row.supports : row.resistances;
      const distances = levels.map((level) => level.distancePct).filter((value): value is number => value !== null);
      return distances.length ? Math.min(...distances) : null;
    };
    const left = distance(a);
    const right = distance(b);
    if (left === null || right === null) return (left === null ? 1 : 0) - (right === null ? 1 : 0) || a.symbol.localeCompare(b.symbol);
    return (sort.direction === "asc" ? left - right : right - left) || a.symbol.localeCompare(b.symbol);
  });
}
