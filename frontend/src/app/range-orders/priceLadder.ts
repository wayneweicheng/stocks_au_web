export type RangeOrderSide = "Buy" | "Sell";

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

export function generateLinearPricesInclusive(start: number, end: number, count: number, side: RangeOrderSide): number[] {
  if (!Number.isFinite(start) || !Number.isFinite(end) || !Number.isInteger(count) || count < 1) return [];
  const low = Math.min(start, end);
  const high = Math.max(start, end);
  if (count === 1) return [round2(side === "Buy" ? low : high)];
  const step = (high - low) / (count - 1);
  return Array.from({ length: count }, (_, index) => round2(low + step * index));
}
