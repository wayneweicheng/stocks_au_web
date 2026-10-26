export type LevelSide = "support" | "resistance";
export type LevelTab = "calculated" | "stock-map" | "database";

/** Index, not price or report rank: distinct/reclassified zones can share an anchor. */
export function levelPanelId(tab: LevelTab, side: LevelSide, index: number): string {
  return `level-${tab}-${side}-${index}`;
}

export function clickedLevelPanelId(
  event: { points?: Array<{ curveNumber?: number }> },
  traceTargets: Array<string | null>,
): string | null {
  const curve = event.points?.[0]?.curveNumber;
  return typeof curve === "number" && Number.isInteger(curve) && curve >= 0
    ? traceTargets[curve] ?? null : null;
}
