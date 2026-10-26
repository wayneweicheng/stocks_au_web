import type { ChartTimeframe } from "./chartRange";

export type ChartSide = "support" | "resistance";

const SUPPORT_COLORS = ["#065f46", "#047857", "#10b981", "#34d399", "#6ee7b7"];
const RESISTANCE_COLORS = ["#991b1b", "#b91c1c", "#ef4444", "#f87171", "#fca5a5"];

/** Calculated/saved maps have no numeric score; retain their original rank palette. */
export function chartLevelColor(side: ChartSide, originalIndex: number): string {
  const colors = side === "support" ? SUPPORT_COLORS : RESISTANCE_COLORS;
  return colors[Math.min(Math.max(originalIndex, 0), colors.length - 1)];
}

/** Plotly reads the CSS pixel width of its container. Keep individual candles legible. */
export function chartMinimumWidth(barCount: number, timeframe: ChartTimeframe): number {
  return Math.max(0, Math.ceil(barCount)) * (timeframe === "30m" ? 10 : 6) + 160;
}
