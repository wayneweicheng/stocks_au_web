export type LevelSort = "quality" | "distance";
export type LevelEntry<T> = { level: T; originalIndex: number };

function compareQuality<T>(a: T, b: T, quality: (level: T) => number | null, higherIsBetter: boolean): number {
  const left = quality(a);
  const right = quality(b);
  if (left === null || !Number.isFinite(left)) return right === null || !Number.isFinite(right) ? 0 : 1;
  if (right === null || !Number.isFinite(right)) return -1;
  return higherIsBetter ? right - left : left - right;
}

/** Select the strongest ceil(percent × count / 100) in each side; restore source order for chart trace identity. */
export function topPercentEntries<T>(
  levels: T[], percent: number, quality: (level: T) => number | null, higherIsBetter = true,
): Array<LevelEntry<T>> {
  const count = Math.ceil(levels.length * Math.max(0, Math.min(100, Number.isFinite(percent) ? percent : 0)) / 100);
  return levels.map((level, originalIndex) => ({ level, originalIndex }))
    .sort((a, b) => compareQuality(a.level, b.level, quality, higherIsBetter) || a.originalIndex - b.originalIndex)
    .slice(0, count)
    .sort((a, b) => a.originalIndex - b.originalIndex);
}

/** Reorder visible cards without changing original chart-to-card identifiers. */
export function sortLevelEntries<T extends { price: number }>(
  entries: Array<LevelEntry<T>>, mode: LevelSort, referencePrice: number | null,
  quality: (level: T) => number | null,
  higherIsBetter = true,
): Array<LevelEntry<T>> {
  const validReference = referencePrice !== null && Number.isFinite(referencePrice);
  const distanceCompare = (a: T, b: T) => validReference
    ? Math.abs(a.price - referencePrice!) - Math.abs(b.price - referencePrice!) : 0;
  return [...entries].sort((a, b) =>
    (mode === "distance" ? distanceCompare(a.level, b.level) || compareQuality(a.level, b.level, quality, higherIsBetter)
      : compareQuality(a.level, b.level, quality, higherIsBetter) || distanceCompare(a.level, b.level)) || a.originalIndex - b.originalIndex);
}

export function sortedLevelEntries<T extends { price: number }>(
  levels: T[], mode: LevelSort, referencePrice: number | null,
  quality: (level: T) => number | null,
  higherIsBetter = true,
): Array<LevelEntry<T>> {
  return sortLevelEntries(levels.map((level, originalIndex) => ({ level, originalIndex })), mode, referencePrice, quality, higherIsBetter);
}
