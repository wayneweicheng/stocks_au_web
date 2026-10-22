// SPY is the bridge between SPX structural levels and the target's observed move.
// All returns are fractions (e.g. -0.01), not percentage points.
export function liveMoveRatio(
  spyClose: number | null,
  spyLive: number | null,
  targetClose: number | null,
  targetLive: number | null,
  allowInverse = false,
): number | null {
  if (spyClose === null || spyLive === null || targetClose === null || targetLive === null ||
      ![spyClose, spyLive, targetClose, targetLive].every((value) => Number.isFinite(value) && value > 0)) return null;
  const spyMove = spyLive / spyClose - 1;
  const targetMove = targetLive / targetClose - 1;
  // Close to flat, the ratio is dominated by quote noise. Diverging assets or
  // extreme ratios should not turn into executable target prices.
  if (Math.abs(spyMove) < 0.002) return null;
  const ratio = targetMove / spyMove;
  return Number.isFinite(ratio) && ratio !== 0 && Math.abs(ratio) <= 6 && (allowInverse || ratio > 0) ? ratio : null;
}

export function mappedFromSpy(spyMapped: number, spyClose: number, targetClose: number, ratio: number): number {
  return targetClose * (1 + (spyMapped / spyClose - 1) * ratio);
}

export function directStockRangeHref(symbol: string, side: "Buy" | "Sell", low: number, high: number): string {
  if (![low, high].every((value) => Number.isFinite(value) && value > 0) || high < low) return "";
  const params = new URLSearchParams({
    stock: symbol, side, start: low.toFixed(2), end: high.toFixed(2),
    num_orders: "5", total_amount: "30000",
  });
  return `/range-orders?${params.toString()}`;
}
