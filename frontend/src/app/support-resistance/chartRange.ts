export type ChartTimeframe = "30m" | "5m";
export type ChartSource = "calculated" | "stock-map" | "database";
export const CHART_RANGE_OPTIONS = [3, 5, 8, 10, 20, 30, 60] as const;
export const DEFAULT_CHART_DAYS: Record<ChartTimeframe, number> = { "30m": 20, "5m": 5 };

/** Display candles only; never change the level calculation or report as-at cutoff. */
export function chartRangeParams({ stockCode, timeframe, days, source, observationDatetime, observationDate, mapAsOfUtc }: {
  stockCode: string;
  timeframe: ChartTimeframe;
  days: number;
  source: ChartSource;
  observationDatetime?: string | null;
  observationDate?: string | null;
  mapAsOfUtc?: string | null;
}): URLSearchParams | null {
  if (!CHART_RANGE_OPTIONS.some((option) => option === days)) return null;
  const params = new URLSearchParams({ stock_code: stockCode, timeframe: timeframe === "30m" ? "30M" : "5M", lookback_days: String(days) });
  if (source === "calculated") {
    if (observationDatetime) params.set("observation_datetime", observationDatetime);
    else if (observationDate) params.set("observation_date", observationDate);
  } else if (source === "database") {
    if (mapAsOfUtc) {
      params.set("observation_datetime", mapAsOfUtc);
      params.set("end_inclusive", "true");
    } else if (observationDate) params.set("observation_date", observationDate);
    else return null;
  }
  return params;
}
