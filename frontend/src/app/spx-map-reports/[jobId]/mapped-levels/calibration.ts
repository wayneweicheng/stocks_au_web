// SPY is the bridge between SPX structural levels and the target's observed move.
// All returns are fractions (e.g. -0.01), not percentage points.
export const MOVE_RATIO_THRESHOLD = 0.002; // ratio only when both moves exceed 0.20%

export type LiveRatioAssessment = { ratio: number | null; blockedReason: string | null; riskReason: string | null };

export function assessLiveMoveRatio(
  spyClose: number | null,
  spyLive: number | null,
  targetClose: number | null,
  targetLive: number | null,
  allowInverse = false,
): LiveRatioAssessment {
  const blocked = (blockedReason: string): LiveRatioAssessment => ({ ratio: null, blockedReason, riskReason: null });
  if (spyClose === null || spyLive === null || targetClose === null || targetLive === null ||
      ![spyClose, spyLive, targetClose, targetLive].every((value) => Number.isFinite(value) && value > 0)) {
    return blocked("A positive SPY and target close and IB price are required");
  }
  const spyMove = spyLive / spyClose - 1;
  const targetMove = targetLive / targetClose - 1;
  const change = (move: number) => `${move >= 0 ? "+" : ""}${(move * 100).toFixed(3)}%`;
  // A truly flat SPY denominator cannot produce a meaningful live ratio.
  // The caller uses the ratio only for same-direction SPY and target moves,
  // both strictly beyond 0.20%; otherwise it uses the move difference.
  // The 6x threshold remains informational, not an action-eligibility test.
  if (Math.abs(spyMove) < 0.000001) return blocked(`SPY has not moved from its reference close (${change(spyMove)})`);
  const ratio = targetMove / spyMove;
  if (!Number.isFinite(ratio) || ratio === 0) return blocked(`Target move is flat (${change(targetMove)}); no live ratio`);
  if (!allowInverse && ratio < 0) return blocked(`SPY ${change(spyMove)} and target ${change(targetMove)} moved in opposite directions`);
  const risks = [];
  if (Math.abs(spyMove) <= MOVE_RATIO_THRESHOLD) risks.push("SPY move below 0.20%");
  if (Math.abs(ratio) > 6) risks.push("ratio above 6×");
  return {
    ratio,
    blockedReason: null,
    riskReason: risks.length ? `SPY ${change(spyMove)}, target ${change(targetMove)}: observed ratio ${ratio.toFixed(2)}× (${risks.join("; ")}). High-risk ratio; review before placing orders.` : null,
  };
}

export function liveMoveRatio(
  spyClose: number | null, spyLive: number | null, targetClose: number | null, targetLive: number | null, allowInverse = false,
): number | null {
  return assessLiveMoveRatio(spyClose, spyLive, targetClose, targetLive, allowInverse).ratio;
}

export function shouldUseMoveRatio(spyMove: number, targetMove: number): boolean {
  // Allow a tiny tolerance around exactly 0.20% to avoid an IEEE-754 rounding
  // artifact switching the user-requested boundary into the ratio branch.
  return Number.isFinite(spyMove) && Number.isFinite(targetMove) &&
    Math.abs(spyMove) > MOVE_RATIO_THRESHOLD + 1e-12 &&
    Math.abs(targetMove) > MOVE_RATIO_THRESHOLD + 1e-12 && spyMove * targetMove > 0;
}

export function liveMoveSpread(
  spyClose: number | null, spyLive: number | null, targetClose: number | null, targetLive: number | null,
): number | null {
  if (spyClose === null || spyLive === null || targetClose === null || targetLive === null ||
      ![spyClose, spyLive, targetClose, targetLive].every((value) => Number.isFinite(value)) ||
      spyClose <= 0 || spyLive <= 0 || targetClose <= 0 || targetLive <= 0) return null;
  return (targetLive / targetClose - 1) - (spyLive / spyClose - 1);
}

export function mappedFromSpy(spyMapped: number, spyClose: number, targetClose: number, ratio: number): number {
  return targetClose * (1 + (spyMapped / spyClose - 1) * ratio);
}

export function mappedFromSpySpread(spyMapped: number, spyClose: number, targetClose: number, spread: number): number {
  return targetClose * (1 + (spyMapped / spyClose - 1) + spread);
}

// SPXL follows SPY ×3; TQQQ follows QQQ ×3. This maps each projected
// parent level's move from its selected close onto the leveraged ETF close.
export function mappedFromLeveragedParent(parentMapped: number, parentClose: number, targetClose: number): number {
  return targetClose * (1 + 3 * (parentMapped / parentClose - 1));
}

export function directStockRangeHref(symbol: string, side: "Buy" | "Sell", low: number, high: number): string {
  if (![low, high].every((value) => Number.isFinite(value) && value > 0) || high < low) return "";
  const params = new URLSearchParams({
    stock: symbol, side, start: low.toFixed(2), end: high.toFixed(2),
    num_orders: "5", total_amount: "30000",
  });
  return `/range-orders?${params.toString()}`;
}
