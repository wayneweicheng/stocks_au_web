import { parseStockMap } from "./stockMapLevels";

type JsonObject = Record<string, unknown>;
const asObject = (value: unknown): JsonObject | null => value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
const positive = (value: unknown): number | null => {
  const number = typeof value === "number" || (typeof value === "string" && value.trim()) ? Number(value) : NaN;
  return Number.isFinite(number) && number > 0 ? number : null;
};

/** SPX Map JSON has no ticker field. Validate its own reference and zone arrays instead. */
export function parseSpxMap(payload: unknown): JsonObject | null {
  const first = parseStockMap(payload);
  const report = first && !Array.isArray(first.primary_supports) && !Array.isArray(first.primary_resistances)
    ? parseStockMap(first) : first;
  if (!report || spxReportReference(report) === null ||
      (!Array.isArray(report.primary_supports) && !Array.isArray(report.primary_resistances))) return null;
  return report;
}

export function spxReportReference(report: JsonObject): number | null {
  return positive(report.execution_reference_spx) ?? positive(report.reference_spx);
}

function validIsoDate(value: unknown): value is string {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`));
}

/** Prefer the report's actual option-snapshot date over its later pre-market map date. */
export function spxOptionObservationDate(report: JsonObject, fallback: string | null): string | null {
  const explicit = report.option_observation_date ?? report.optionObservationDate;
  if (validIsoDate(explicit)) return explicit;
  const expectedMoves = report.expected_moves;
  if (Array.isArray(expectedMoves)) {
    for (const item of expectedMoves) {
      const timestamps = asObject(item)?.data_timestamps;
      if (!Array.isArray(timestamps) || timestamps.length < 2 || !timestamps.every((value) => typeof value === "string")) continue;
      const dates = new Set(timestamps.map((value) => String(value).slice(0, 10)));
      const [date] = dates;
      if (dates.size === 1 && validIsoDate(date)) return date;
    }
  }
  return validIsoDate(fallback) ? fallback : null;
}

export function spxPreviousCompletedClose(report: JsonObject): number | null {
  for (const side of ["primary_supports", "primary_resistances"]) {
    const rows = report[side];
    if (!Array.isArray(rows)) continue;
    for (const row of rows) {
      const close = positive(asObject(row)?.last_close_reference_spx);
      if (close !== null) return close;
    }
  }
  return positive(report.prior_official_spx_close);
}

export type SpxOptionPair = {
  observationDate: string;
  expiry: string;
  strike: number;
  reference: number;
  callPrice: number;
  putPrice: number;
  callSource: string;
  putSource: string;
  premium: number;
  expiryRange: { low: number; high: number };
};

/** Use SPXW's SPX range directly for SPX, or translate both bounds to ES with the matched ES−SPX basis. */
export function spxOptionRangeForInstrument(
  pair: SpxOptionPair,
  instrument: string,
  esSpxBasis: number | null,
): { low: number; high: number } | null {
  const code = instrument.trim().toUpperCase();
  if (code === "SPX") return pair.expiryRange;
  if (code !== "ESMAIN" || esSpxBasis === null || !Number.isFinite(esSpxBasis)) return null;
  const low = pair.expiryRange.low + esSpxBasis;
  const high = pair.expiryRange.high + esSpxBasis;
  return Number.isFinite(low) && Number.isFinite(high) && low > 0 && high >= low ? { low, high } : null;
}

/** Same observed day, underlying, expiry and strike; never blend two option sessions. */
export function spxOptionPair(value: unknown, observationDate: string): SpxOptionPair | null {
  const snapshot = asObject(value);
  if (!snapshot || snapshot.source !== "StockDB_US.StockData.v_OptionDelayedQuote_V2" ||
      snapshot.observation_date !== observationDate || !Array.isArray(snapshot.option_rows) ||
      snapshot.option_rows.length !== 2) return null;
  const reference = positive(snapshot.spot_reference_from_d1);
  const call = asObject(snapshot.option_rows.find((row) => asObject(row)?.right === "C"));
  const put = asObject(snapshot.option_rows.find((row) => asObject(row)?.right === "P"));
  const strike = positive(call?.strike);
  const callPrice = positive(call?.price);
  const putPrice = positive(put?.price);
  const expiry = call?.expiry;
  const valid = (row: JsonObject | null) => row && ["SPXW", "SPXW.US"].includes(String(row.symbol || "").toUpperCase()) &&
    row.observation_date === observationDate && row.expiry === expiry && positive(row.strike) === strike &&
    (row.source === undefined || row.source === snapshot.source);
  if (reference === null || strike === null || callPrice === null || putPrice === null ||
      typeof expiry !== "string" || expiry < observationDate || !valid(call) || !valid(put)) return null;
  const premium = callPrice + putPrice;
  return { observationDate, expiry, strike, reference, callPrice, putPrice, premium,
    callSource: String(call?.price_source || "unknown"), putSource: String(put?.price_source || "unknown"),
    expiryRange: { low: Math.max(0, reference - premium), high: reference + premium } };
}
