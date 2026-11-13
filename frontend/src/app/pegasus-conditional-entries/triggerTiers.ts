export type TriggerSide = "B" | "S";

export function targetPriceTiers(start: number, end: number, count: number, side: TriggerSide): number[] {
  if (!Number.isFinite(start) || !Number.isFinite(end) || start <= 0 || end <= 0 || !Number.isInteger(count) || count < 1) return [];
  const low = Math.min(start, end);
  const high = Math.max(start, end);
  if (count === 1) return [side === "B" ? high : low];
  return Array.from({ length: count }, (_, index) => {
    const fraction = index / (count - 1);
    const price = side === "B" ? high - (high - low) * fraction : low + (high - low) * fraction;
    return Math.round(price * 10000) / 10000;
  });
}

export function referencePriceTiers(start: number, end: number, count: number, side: TriggerSide): number[] {
  if (!Number.isFinite(start) || !Number.isFinite(end) || start <= 0 || end <= 0 || !Number.isInteger(count) || count < 1) return [];
  const low = Math.min(start, end);
  const high = Math.max(start, end);
  const lowTicks = Math.ceil(low * 4 - 1e-8);
  const highTicks = Math.floor(high * 4 + 1e-8);
  if (highTicks - lowTicks + 1 < count) return [];
  const usableLow = lowTicks / 4;
  const usableHigh = highTicks / 4;
  return Array.from({ length: count }, (_, index) => {
    const exact = count === 1
      ? side === "B" ? usableHigh : usableLow
      : side === "B" ? usableHigh - ((usableHigh - usableLow) * index) / (count - 1)
        : usableLow + ((usableHigh - usableLow) * index) / (count - 1);
    return (side === "B" ? Math.floor(exact * 4 + 1e-8) : Math.ceil(exact * 4 - 1e-8)) / 4;
  });
}
