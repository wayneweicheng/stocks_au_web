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

/** Keep the indicative option range behind candles and on the price axis, not volume. */
export function straddleZoneShape(range: { low: number; high: number }) {
  return {
    type: "rect" as const, xref: "paper" as const, yref: "y" as const,
    x0: 0, x1: 1, y0: range.low, y1: range.high,
    fillcolor: "rgba(250, 204, 21, 0.18)",
    line: { color: "rgba(202, 138, 4, 0.45)", width: 1 },
    layer: "below" as const,
  };
}

/** Observation-date SPXW expiry proxy, visually separate from next-session estimates. */
export function spxExpiryRangeShape(range: { low: number; high: number }) {
  return {
    type: "rect" as const, xref: "paper" as const, yref: "y" as const,
    x0: 0, x1: 1, y0: range.low, y1: range.high,
    fillcolor: "rgba(249, 115, 22, 0.14)",
    line: { color: "rgba(194, 65, 12, 0.55)", width: 1, dash: "dot" as const },
    layer: "below" as const,
  };
}
