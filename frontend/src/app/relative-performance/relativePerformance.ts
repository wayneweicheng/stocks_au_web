export type RelativeTimeframe = "5M" | "30M";
export type RelativeBar = { time: string; open: number; high: number; low: number; close: number; volume: number };
export type RelativeSeries = { symbol: string; points: Array<{ time: string; changePct: number }> };
export type RelativeRow = {
  symbol: string;
  startPrice: number | null;
  lastPrice: number | null;
  changePct: number | null;
  lastBarPct: number | null;
  last30mPct: number | null;
  relativeToQqqPct: number | null;
  latestTime: string | null;
  bars: number;
};
export type DivergenceAlert = {
  kind: "ai_underperformance";
  cohortChange30mPct: number;
  benchmarkChange30mPct: number;
  relativeSpreadPct: number;
  underperformingCount: number;
  cohortCount: number;
  message: string;
};
export type RelativePullbackPeriod = {
  startTime: string;
  endTime: string;
  qqqChangePct: number;
  soxxChangePct: number;
  relativeEdgePct: number;
  windowMinutes: number;
};
export type RelativePerformanceAnalysis = {
  rows: RelativeRow[];
  series: RelativeSeries[];
  relativeSpreadSeries: RelativeSeries;
  divergence: DivergenceAlert | null;
  pullbackPeriods: RelativePullbackPeriod[];
  timeframe: RelativeTimeframe;
};
export type LiveQuote = { price: number; source?: string; fetched_at_utc?: string; price_time?: string | null };
export type LiveRank = { symbol: string; rank: number; livePrice: number; distancePct: number };

export const DEFAULT_RELATIVE_SYMBOLS = ["QQQ", "SOXX"] as const;
export const AI_SEMICONDUCTOR_COHORT = ["MSFT", "AMZN", "AMD", "NVDA", "MU", "SNDK"] as const;

const round = (value: number) => Math.round(value * 10_000) / 10_000;
const percentChange = (start: number, end: number) => start > 0 ? round((end / start - 1) * 100) : null;

function validBars(bars: RelativeBar[]): RelativeBar[] {
  return bars.filter((bar) => typeof bar.close === "number" && Number.isFinite(bar.close) && bar.close > 0 &&
    typeof bar.time === "string" && Number.isFinite(Date.parse(bar.time)))
    .sort((left, right) => Date.parse(left.time) - Date.parse(right.time));
}

export function rankLivePerformance(
  rows: RelativeRow[],
  quotes: Record<string, LiveQuote | null | undefined>,
): LiveRank[] {
  return rows.flatMap((row) => {
    const quote = quotes[row.symbol.toUpperCase()];
    if (!quote || !Number.isFinite(quote.price) || quote.price <= 0 || row.startPrice === null || row.startPrice <= 0) return [];
    const distancePct = percentChange(row.startPrice, quote.price);
    return distancePct === null ? [] : [{ symbol: row.symbol, rank: 0, livePrice: quote.price, distancePct }];
  }).sort((left, right) => right.distancePct - left.distancePct || left.symbol.localeCompare(right.symbol))
    .map((item, index) => ({ ...item, rank: index + 1 }));
}

function findRelativePullbackPeriods(
  barsBySymbol: Record<string, RelativeBar[]>,
  timeframe: RelativeTimeframe,
  windowMinutes: number | "all",
): RelativePullbackPeriod[] {
  const qqq = validBars(barsBySymbol.QQQ || []);
  const soxxByTime = new Map(validBars(barsBySymbol.SOXX || []).map((bar) => [bar.time, bar.close]));
  const intervalMinutes = timeframe === "5M" ? 5 : 30;
  const minQqqDecline = -0.25;
  const minRelativeEdge = 0.2;
  const candidates: RelativePullbackPeriod[] = [];
  const windowLengths = windowMinutes === "all"
    ? Array.from({ length: Math.floor((100 - 30) / intervalMinutes) + 1 }, (_, index) => 30 + index * intervalMinutes)
    : [windowMinutes];

  for (const scanWindowMinutes of windowLengths) {
    const intervals = Math.max(1, Math.round(scanWindowMinutes / intervalMinutes));
    for (let endIndex = intervals; endIndex < qqq.length; endIndex++) {
      const end = qqq[endIndex];
      const start = qqq[endIndex - intervals];
      const soxxStart = soxxByTime.get(start.time);
      const soxxEnd = soxxByTime.get(end.time);
      const elapsedMinutes = (Date.parse(end.time) - Date.parse(start.time)) / 60_000;
      if (soxxStart === undefined || soxxEnd === undefined || Math.abs(elapsedMinutes - scanWindowMinutes) > intervalMinutes) continue;

      const qqqChangePct = percentChange(start.close, end.close);
      const soxxChangePct = percentChange(soxxStart, soxxEnd);
      if (qqqChangePct === null || soxxChangePct === null || qqqChangePct > minQqqDecline || soxxChangePct >= 0) continue;
      const relativeEdgePct = round(soxxChangePct - qqqChangePct);
      if (relativeEdgePct < minRelativeEdge) continue;
      candidates.push({ startTime: start.time, endTime: end.time, qqqChangePct, soxxChangePct, relativeEdgePct, windowMinutes: scanWindowMinutes });
    }
  }

  const strongestFirst = candidates.sort((left, right) => right.relativeEdgePct - left.relativeEdgePct);
  const selected: RelativePullbackPeriod[] = [];
  for (const candidate of strongestFirst) {
    if (selected.some((period) => candidate.startTime < period.endTime && candidate.endTime > period.startTime)) continue;
    selected.push(candidate);
    if (selected.length >= 8) break;
  }
  return selected.sort((left, right) => left.startTime.localeCompare(right.startTime));
}

export function analyzeRelativePerformance(
  barsBySymbol: Record<string, RelativeBar[]>,
  timeframe: RelativeTimeframe,
  pullbackWindowMinutes: number | "all" = "all",
): RelativePerformanceAnalysis {
  const intervalCountFor30m = timeframe === "5M" ? 6 : 1;
  const rows: RelativeRow[] = [];
  const series: RelativeSeries[] = [];

  for (const [rawSymbol, rawBars] of Object.entries(barsBySymbol)) {
    const symbol = rawSymbol.trim().toUpperCase() === "ESMAIN" ? "ESMain" : rawSymbol.trim().toUpperCase();
    const bars = validBars(Array.isArray(rawBars) ? rawBars : []);
    const first = bars[0];
    const last = bars[bars.length - 1];
    const startPrice = first?.close ?? null;
    const lastPrice = last?.close ?? null;
    const changePct = startPrice !== null && lastPrice !== null ? percentChange(startPrice, lastPrice) : null;
    const previousBar = bars.length > 1 ? bars[bars.length - 2] : null;
    const comparisonBar = bars.length > intervalCountFor30m ? bars[bars.length - 1 - intervalCountFor30m] : null;
    const lastBarPct = previousBar && last ? percentChange(previousBar.close, last.close) : null;
    const last30mPct = comparisonBar && last ? percentChange(comparisonBar.close, last.close) : null;
    rows.push({ symbol, startPrice, lastPrice, changePct, lastBarPct, last30mPct, relativeToQqqPct: null,
      latestTime: last?.time ?? null, bars: bars.length });
    series.push({ symbol, points: startPrice === null ? [] : bars.map((bar) => ({
      time: bar.time, changePct: percentChange(startPrice, bar.close) ?? 0,
    })) });
  }

  const bySymbol = new Map(rows.map((row) => [row.symbol.toUpperCase(), row]));
  const qqqChange = bySymbol.get("QQQ")?.changePct ?? null;
  for (const row of rows) {
    row.relativeToQqqPct = row.changePct !== null && qqqChange !== null ? round(row.changePct - qqqChange) : null;
  }

  const availableCohort = AI_SEMICONDUCTOR_COHORT
    .map((symbol) => bySymbol.get(symbol))
    .filter((row): row is RelativeRow => row !== undefined && row.last30mPct !== null);
  const qqq30m = bySymbol.get("QQQ")?.last30mPct ?? null;
  const soxx30m = bySymbol.get("SOXX")?.last30mPct ?? null;
  const broadRows = ["ESMAIN", "SPY", "DJI"]
    .map((symbol) => bySymbol.get(symbol)?.last30mPct)
    .filter((value): value is number => value !== null && value !== undefined);
  let divergence: DivergenceAlert | null = null;

  if (availableCohort.length >= 4 && qqq30m !== null && soxx30m !== null && broadRows.length >= 2) {
    const lastTimes = [...availableCohort.map((row) => row.latestTime), bySymbol.get("QQQ")?.latestTime, bySymbol.get("SOXX")?.latestTime]
      .filter((value): value is string => value !== null && value !== undefined)
      .map(Date.parse);
    const timeframeMs = timeframe === "5M" ? 5 * 60_000 : 30 * 60_000;
    const timestampsAligned = lastTimes.length > 0 && Math.max(...lastTimes) - Math.min(...lastTimes) <= timeframeMs * 2;
    const cohortChange30mPct = round(availableCohort.reduce((sum, row) => sum + row.last30mPct!, 0) / availableCohort.length);
    const benchmarkChange30mPct = round((qqq30m + soxx30m) / 2);
    const relativeSpreadPct = round(cohortChange30mPct - benchmarkChange30mPct);
    const underperformingCount = availableCohort.filter((row) => row.last30mPct! < qqq30m && row.last30mPct! < soxx30m).length;
    const broadAverage = broadRows.reduce((sum, value) => sum + value, 0) / broadRows.length;
    const weakBreadth = underperformingCount >= Math.ceil(availableCohort.length * 2 / 3);
    if (timestampsAligned && weakBreadth && relativeSpreadPct <= -0.25 && broadAverage >= -0.1) {
      divergence = {
        kind: "ai_underperformance", cohortChange30mPct, benchmarkChange30mPct, relativeSpreadPct,
        underperformingCount, cohortCount: availableCohort.length,
        message: "AI/semiconductor names are showing broad short-term relative weakness while the broader-market proxies are not materially lower. This is a divergence alert, not a forecast.",
      };
    }
  }

  const qqqPoints = series.find((item) => item.symbol.toUpperCase() === "QQQ")?.points || [];
  const soxxPoints = new Map((series.find((item) => item.symbol.toUpperCase() === "SOXX")?.points || [])
    .map((point) => [point.time, point.changePct]));
  const relativeSpreadSeries: RelativeSeries = {
    symbol: "SOXX − QQQ delta",
    points: qqqPoints.flatMap((point) => {
      const soxxChange = soxxPoints.get(point.time);
      return soxxChange === undefined ? [] : [{ time: point.time, changePct: round(soxxChange - point.changePct) }];
    }),
  };
  const pullbackPeriods = findRelativePullbackPeriods(barsBySymbol, timeframe, pullbackWindowMinutes);
  return { rows, series, relativeSpreadSeries, divergence, pullbackPeriods, timeframe };
}
