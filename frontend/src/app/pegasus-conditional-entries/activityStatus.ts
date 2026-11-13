type ReversalActivity = {
  Status: string;
  Side: "B" | "S";
  TargetPriceActivationMode?: string | null;
  TargetPriceThreshold?: number | null;
  TargetPriceTickSize?: number | null;
  TargetCursorRegion?: string | null;
  TargetTouchPrice?: number | null;
  TriggerPriceActivationMode?: string | null;
  TriggerPriceThreshold?: number | null;
  TriggerPriceTickSize?: number | null;
  TriggerCursorRegion?: string | null;
  TriggerTouchPrice?: number | null;
  TriggerStockCode?: string | null;
};

const SYDNEY_TIME_ZONE = "Australia/Sydney";
const US_MARKET_TIME_ZONE = "America/New_York";
const DATE_TIME_OPTIONS: Intl.DateTimeFormatOptions = {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
};

function timeZoneAbbreviation(date: Date, timeZone: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { timeZone, timeZoneName: "short" })
    .formatToParts(date)
    .find((part) => part.type === "timeZoneName")?.value ?? timeZone;
}

export function formatActivityTimestamp(value: string | Date | null | undefined): string {
  if (value == null) return "Unknown time";
  const date = value instanceof Date
    ? value
    : new Date(/(?:Z|[+-]\d{2}:?\d{2})$/i.test(value.trim()) ? value : `${value.trim()}Z`);
  if (!Number.isFinite(date.getTime())) return "Unknown time";

  const sydney = new Intl.DateTimeFormat("en-AU", {
    ...DATE_TIME_OPTIONS,
    timeZone: SYDNEY_TIME_ZONE,
  }).format(date);
  const usMarket = new Intl.DateTimeFormat("en-AU", {
    ...DATE_TIME_OPTIONS,
    timeZone: US_MARKET_TIME_ZONE,
  }).format(date);
  const sydneyZone = timeZoneAbbreviation(date, SYDNEY_TIME_ZONE, "en-AU");
  const usMarketZone = timeZoneAbbreviation(date, US_MARKET_TIME_ZONE, "en-US");
  return `Sydney: ${sydney} ${sydneyZone} (US market: ${usMarket} ${usMarketZone})`;
}

export type ActivityFilters = {
  attemptStatus: string;
  outboxMode: string;
};

type FilterableActivity = {
  AttemptState?: string | null;
  EvaluatorMode?: string | null;
};

export function matchesActivityFilters(row: FilterableActivity, filters: ActivityFilters): boolean {
  const matches = (selected: string, value?: string | null) => {
    const normalized = value?.trim().toUpperCase() ?? "";
    return selected === "ALL" || (selected === "NONE" ? normalized === "" : normalized === selected);
  };
  return matches(filters.attemptStatus, row.AttemptState)
    && matches(filters.outboxMode, row.EvaluatorMode);
}

export function waitingForReversalMessage(row: ReversalActivity): string | null {
  if (row.Status !== "PENDING") return null;
  const targetWaiting = row.TargetPriceActivationMode === "TOUCH_THEN_RETRACE"
    && row.TargetCursorRegion === "WAITING_FOR_REVERSAL";
  const triggerWaiting = row.TriggerPriceActivationMode === "TOUCH_THEN_RETRACE"
    && row.TriggerCursorRegion === "WAITING_FOR_REVERSAL";
  if (!targetWaiting && !triggerWaiting) return null;
  const targetSource = targetWaiting;
  const rawThreshold = targetSource ? row.TargetPriceThreshold : row.TriggerPriceThreshold;
  const rawTick = targetSource ? row.TargetPriceTickSize : row.TriggerPriceTickSize;
  const rawTouch = targetSource ? row.TargetTouchPrice : row.TriggerTouchPrice;
  const threshold = Number(rawThreshold);
  const tick = Number(rawTick);
  const touch = Number(rawTouch);
  if (rawThreshold == null || rawTick == null || rawTouch == null
      || !Number.isFinite(threshold) || !Number.isFinite(tick) || tick <= 0
      || !Number.isFinite(touch) || touch <= 0) return null;
  const confirmation = Math.round((threshold + (row.Side === "B" ? tick : -tick)) * 100) / 100;
  const sourceLabel = targetSource ? "Target" : (row.TriggerStockCode || "Reference stock");
  return `${sourceLabel} price touched at $${touch.toFixed(2)}; waiting for a fresh last-trade price of $${confirmation.toFixed(2)} or ${row.Side === "B" ? "higher" : "lower"} to confirm reversal. No claim yet.`;
}
