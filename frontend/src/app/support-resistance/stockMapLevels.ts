export type MapZone = {
  sourceSide: "support" | "resistance";
  price: number;
  range_low: number;
  range_high: number;
  rank: number;
  score: number | null;
  strength: string;
  levelConfidence: string;
  details: Record<string, unknown>;
};

type ObjectValue = Record<string, unknown>;
const object = (value: unknown): ObjectValue | null => value !== null && typeof value === "object" && !Array.isArray(value) ? value as ObjectValue : null;
const number = (value: unknown): number | null => {
  if (value === null || value === undefined || value === "") return null;
  const result = typeof value === "string" || typeof value === "number" ? Number(value) : NaN;
  return Number.isFinite(result) ? result : null;
};

export function parseStockMap(payload: unknown): ObjectValue | null {
  const wrapper = object(payload);
  if (!wrapper) return null;
  const content = wrapper.content ?? wrapper.json ?? wrapper.data ?? payload;
  if (typeof content === "string") {
    try { return object(JSON.parse(content)); } catch { return null; }
  }
  return object(content);
}

export function mapStockCode(data: ObjectValue): string {
  const metadata = object(data.metadata) || object(data.meta) || object(data.parameters) || {};
  const candidate = data.instrument_code ?? data.stock_code ?? data.ticker ?? data.symbol ??
    metadata.instrument_code ?? metadata.stock_code ?? metadata.ticker ?? metadata.symbol;
  return typeof candidate === "string" ? candidate.trim().toUpperCase().replace(/\.(US|AX)$/i, "") : "";
}

export function mapObservationDate(data: ObjectValue): string | null {
  const metadata = object(data.metadata) || object(data.meta) || object(data.parameters) || {};
  for (const value of [data.as_of_et, metadata.as_of_et, data.as_at, data.asAt, metadata.as_at,
    data.as_of_date, metadata.as_of_date, data.observation_date, data.observationDate,
    metadata.observation_date, metadata.observationDate, data.as_of_sydney, metadata.as_of_sydney]) {
    if (typeof value === "string") {
      const match = value.match(/\d{4}-\d{2}-\d{2}/);
      if (match) return match[0];
    }
  }
  return null;
}

export type NextSessionStraddle = {
  quoteDate: string;
  nextSession: string;
  expiry: string;
  tradingSessionsToExpiry: number;
  spot: number;
  strike: number;
  callPrice: number;
  putPrice: number;
  premium: number;
  quoteSource: string;
  expiryRange: { low: number; high: number };
  nextSessionMove: number;
  nextSessionRange: { low: number; high: number };
};

function utcDate(value: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value ? date : null;
}

function nextWeekday(date: Date): Date {
  const next = new Date(date);
  do { next.setUTCDate(next.getUTCDate() + 1); } while ([0, 6].includes(next.getUTCDay()));
  return next;
}

/** The report's ATM call+put is an expiry-horizon straddle, not a one-day forecast.
 * Square-root-of-time scaling is only an indicative next-session volatility proxy.
 */
export function mapNextSessionStraddle(data: ObjectValue): NextSessionStraddle | null {
  if (!Array.isArray(data.expected_moves)) return null;
  const asOfDate = typeof data.as_of_et === "string" ? data.as_of_et.slice(0, 10) : null;
  const asOfWallTime = typeof data.as_of_et === "string" ? data.as_of_et.match(/^\d{4}-\d{2}-\d{2}T(\d{2}:\d{2})/)?.[1] : null;
  const candidates = data.expected_moves.flatMap((value) => {
    const row = object(value);
    if (!row || !Array.isArray(row.data_timestamps) || row.data_timestamps.length < 2) return [];
    const quoteDate = typeof row.data_timestamps[0] === "string" ? row.data_timestamps[0].slice(0, 10) : "";
    const putDate = typeof row.data_timestamps[1] === "string" ? row.data_timestamps[1].slice(0, 10) : "";
    const expiry = typeof row.expiry === "string" ? row.expiry : "";
    const start = utcDate(quoteDate);
    const end = utcDate(expiry);
    const spot = number(row.spot_at_quote);
    const strike = number(row.atm_strike);
    const callPrice = number(row.call_price);
    const putPrice = number(row.put_price);
    if (!start || !end || quoteDate !== putDate || (asOfDate && quoteDate > asOfDate) ||
      spot === null || spot <= 0 || strike === null || strike <= 0 ||
      callPrice === null || callPrice <= 0 || putPrice === null || putPrice <= 0) return [];
    const nextSession = nextWeekday(start);
    const nextSessionDate = nextSession.toISOString().slice(0, 10);
    // Do not label a stale historical quote as a future next-session forecast.
    if (asOfDate && (nextSessionDate < asOfDate ||
      (nextSessionDate === asOfDate && asOfWallTime !== null && asOfWallTime !== undefined && asOfWallTime >= "09:30"))) return [];
    let sessions = 0;
    for (let cursor = nextSession; cursor <= end; cursor = nextWeekday(cursor)) sessions++;
    if (!sessions) return [];
    const premium = callPrice + putPrice;
    // E[|X|] ≈ 0.8 sigma for a near-ATM straddle under a diffusion model.
    const nextSessionMove = premium / 0.8 / Math.sqrt(sessions);
    return [{ quoteDate, nextSession: nextSessionDate, expiry,
      tradingSessionsToExpiry: sessions, spot, strike, callPrice, putPrice, premium,
      quoteSource: typeof row.quote_source === "string" ? row.quote_source : "not specified",
      expiryRange: { low: spot - premium, high: spot + premium }, nextSessionMove,
      nextSessionRange: { low: Math.max(0, spot - nextSessionMove), high: spot + nextSessionMove },
    }];
  });
  return candidates.sort((a, b) => a.expiry.localeCompare(b.expiry))[0] ?? null;
}

export function mapZones(data: ObjectValue, side: "support" | "resistance"): MapZone[] {
  const rows = data[side === "support" ? "primary_supports" : "primary_resistances"];
  const metadata = data[`zone_primary_${side}s`];
  if (!Array.isArray(rows)) return [];
  return rows.flatMap((value, index) => {
    const row = object(value);
    const low = number(row?.zone_low);
    const high = number(row?.zone_high);
    if (!row || low === null || high === null) return [];
    const center = number(row.core_anchor_price) ?? number(row.reference_price) ??
      number(row.tradable_center) ?? number(row.mathematical_center) ?? (low + high) / 2;
    // Sparse ladder maps can have separate consolidated zone metadata. Only borrow
    // its score/evidence when the anchor really matches this primary zone.
    const match = Array.isArray(metadata) ? metadata.map(object).filter((item): item is ObjectValue => item !== null)
      .map((item) => ({ item, distance: Math.abs((number(item.core_anchor_price) ?? number(item.reference_price) ??
        number(item.tradable_center) ?? number(item.mathematical_center) ?? Infinity) - center) }))
      .sort((a, b) => a.distance - b.distance)[0] : undefined;
    const related = match && match.distance <= Math.max(0.25, Math.abs(center) * 0.002) ? match.item : {};
    const details = { ...related, ...row };
    return [{
      sourceSide: side,
      price: center, range_low: Math.min(low, high), range_high: Math.max(low, high),
      rank: number(row.rank) ?? index + 1,
      score: number(row.total_score) ?? number(related.total_score),
      strength: String(row.confidence || related.confidence || "unknown"),
      levelConfidence: String(row.level_confidence || related.level_confidence || ""),
      details,
    }];
  }).sort((a, b) => a.rank - b.rank);
}

function scoreFraction(score: number | null): number {
  return score === null || !Number.isFinite(score) ? 0 : Math.max(0, Math.min(100, score)) / 100;
}

/** Higher Stock Map scores produce darker lines on either side of the as-at price. */
export function mapLineColor(side: "support" | "resistance", score: number | null): string {
  const [light, dark] = side === "support"
    ? [[110, 231, 183], [6, 95, 70]]
    : [[252, 165, 165], [153, 27, 27]];
  const fraction = scoreFraction(score);
  return `#${light.map((channel, index) => Math.round(channel + (dark[index] - channel) * fraction).toString(16).padStart(2, "0")).join("")}`;
}

export function mapLineWidth(score: number | null): number {
  return score === null || !Number.isFinite(score) ? 2 : 2 + 6 * scoreFraction(score);
}

export type StockMapReport = {
  job_id: string;
  title: string;
  stock_code?: string | null;
  status?: string | null;
  created_at?: string | null;
  file_name?: string | null;
  raw?: Record<string, unknown>;
};

export type ReportAsOfTime = { label: string; easternWallTime: string };

/** Historical report labels denote the requested as-at, not when the artifact was built. */
export function reportGeneratedTime(report: StockMapReport): ReportAsOfTime | null {
  for (const name of [report.title, report.file_name]) {
    const match = name?.match(/(?:^|\s)(?:[A-Z0-9.^-]+):(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::\d{2})?\s+Australia\/Sydney\b/i);
    if (!match) continue;
    const wall = `${match[1]} ${match[2]}`;
    const approximate = new Date(`${match[1]}T${match[2]}:00Z`);
    if (Number.isNaN(approximate.getTime())) continue;
    const offsetFormatter = new Intl.DateTimeFormat("en-US", { timeZone: "Australia/Sydney", timeZoneName: "shortOffset" });
    const offsetAt = (instant: Date) => {
      const offset = offsetFormatter.formatToParts(instant).find((part) => part.type === "timeZoneName")?.value || "";
      const parts = offset.match(/^GMT([+-])(\d{1,2})(?::(\d{2}))?$/);
      return parts ? (parts[1] === "+" ? 1 : -1) * (Number(parts[2]) * 60 + Number(parts[3] || 0)) : null;
    };
    const initialOffset = offsetAt(approximate);
    if (initialOffset === null) continue;
    let instant = new Date(approximate.getTime() - initialOffset * 60000);
    const actualOffset = offsetAt(instant);
    if (actualOffset === null) continue;
    instant = new Date(approximate.getTime() - actualOffset * 60000);
    // Reject malformed / nonexistent local times around the Sydney DST change.
    const sydneyParts = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Australia/Sydney", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(instant);
    const part = (type: string) => sydneyParts.find((item) => item.type === type)?.value;
    if (`${part("year")}-${part("month")}-${part("day")} ${part("hour")}:${part("minute")}` !== wall) continue;
    const easternParts = new Intl.DateTimeFormat("en-GB", {
      timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(instant);
    const eastern = (type: string) => easternParts.find((item) => item.type === type)?.value;
    return { label: `${wall} Australia/Sydney`, easternWallTime: `${eastern("year")}-${eastern("month")}-${eastern("day")}T${eastern("hour")}:${eastern("minute")}:00` };
  }
  return null;
}

/** Prefer the report's authoritative as-of timestamp over the label. */
export function mapAsOfTime(data: Record<string, unknown>, report: StockMapReport): ReportAsOfTime | null {
  for (const value of [data.as_of_et, data.as_of_sydney]) {
    if (typeof value !== "string" || !/(?:Z|[+-]\d{2}:\d{2})$/i.test(value)) continue;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) continue;
    const partsIn = (timeZone: string) => {
      const parts = new Intl.DateTimeFormat("en-GB", {
        timeZone, year: "numeric", month: "2-digit", day: "2-digit",
        hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
      }).formatToParts(date);
      const part = (type: string) => parts.find((item) => item.type === type)?.value;
      return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}:${part("second")}`;
    };
    const sydney = partsIn("Australia/Sydney");
    return { label: `${sydney.slice(0, 16).replace("T", " ")} Australia/Sydney`, easternWallTime: partsIn("America/New_York") };
  }
  return reportGeneratedTime(report);
}

// StockDB_US 30M TimeIntervalStart is New York wall time (without an offset).
// Compare wall clocks in the same time zone, independently of the viewer's locale.
function wallMillis(value: string): number {
  const match = value.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::(\d{2}))?/);
  return match ? Date.parse(`${match[1]}T${match[2]}:${match[3] || "00"}Z`) : NaN;
}

/** Select the last *completed* 30M candle at report as-of, not a future close. */
export function reportAsAtClose(bars: { time: string; close: number }[], easternWallTime: string): { price: number; barTime: string } | null {
  const cutoff = wallMillis(easternWallTime) - 30 * 60 * 1000;
  if (!Number.isFinite(cutoff)) return null;
  const eligible = bars.filter((bar) => wallMillis(bar.time) <= cutoff && Number.isFinite(bar.close));
  if (!eligible.length) return null;
  const last = eligible.reduce((a, b) => wallMillis(a.time) > wallMillis(b.time) ? a : b);
  return { price: last.close, barTime: last.time };
}

/** Change the actionable side based on the level's anchor vs the as-at 30M close. */
export function classifyMapZones(supports: MapZone[], resistances: MapZone[], asAtPrice: number): { supports: MapZone[]; resistances: MapZone[] } {
  const all = [...supports, ...resistances];
  return {
    supports: all.filter((zone) => zone.price < asAtPrice || (zone.price === asAtPrice && zone.sourceSide === "support"))
      .sort((a, b) => b.price - a.price),
    resistances: all.filter((zone) => zone.price > asAtPrice || (zone.price === asAtPrice && zone.sourceSide === "resistance"))
      .sort((a, b) => a.price - b.price),
  };
}

/** Plotly's category x-axis places candles at integer indexes; locate a time between them. */
export function reportTimeCategoryPosition(bars: { time: string }[], easternWallTime: string): number | null {
  const time = wallMillis(easternWallTime);
  const candles = bars.map((bar) => wallMillis(bar.time));
  if (!candles.length || !Number.isFinite(time) || candles.some((value) => !Number.isFinite(value))) return null;
  if (time <= candles[0]) return time === candles[0] ? 0 : -0.5;
  for (let index = 1; index < candles.length; index++) {
    if (time <= candles[index]) {
      if (candles[index] <= candles[index - 1]) return null;
      return index - 1 + (time - candles[index - 1]) / (candles[index] - candles[index - 1]);
    }
  }
  return candles.length; // A report after the last candle is shown just to its right.
}

export function reportMatchesStock(report: StockMapReport, code: string): boolean {
  const requested = code.trim().toUpperCase().replace(/\.(US|AX)$/i, "");
  const raw = report.raw || {};
  const metadata = [report.stock_code, raw.stock_code, raw.instrument_code, raw.ticker, raw.symbol]
    .filter((value): value is string => typeof value === "string" && !!value.trim());
  if (metadata.length) return metadata.some((value) => value.trim().toUpperCase().replace(/\.(US|AX)$/i, "") === requested);
  // Report titles generated by Stock Map start with the ticker followed by ':' or a space.
  // Never match an incidental ticker inside a timestamp or another symbol.
  return [report.title, report.file_name].some((value) => typeof value === "string" &&
    value.trim().toUpperCase().match(/^[A-Z0-9.^-]+(?=[:\s_])/)?.[0]?.replace(/\.(US|AX)$/i, "") === requested);
}
