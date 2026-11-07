export type EsSide = "Buy" | "Sell";

/** ES quotes trade in quarter points. Snap inner levels toward the later trigger. */
export function generateEsTriggerPrices(a: number, b: number, count: number, side: EsSide): number[] {
  const lowTicks = Math.ceil(Math.min(a, b) * 4 - 1e-8);
  const highTicks = Math.floor(Math.max(a, b) * 4 + 1e-8);
  if (count < 1 || highTicks - lowTicks + 1 < count) return [];
  return Array.from({ length: count }, (_, index) => {
    const exact = count === 1 ? (side === "Buy" ? Math.max(a, b) : Math.min(a, b))
      : side === "Buy" ? Math.max(a, b) - (Math.abs(b - a) * index) / (count - 1)
        : Math.min(a, b) + (Math.abs(b - a) * index) / (count - 1);
    return (side === "Buy" ? Math.floor(exact * 4 + 1e-8) : Math.ceil(exact * 4 - 1e-8)) / 4;
  });
}

function normalize(weights: number[]): number[] {
  const sum = weights.reduce((acc, weight) => acc + weight, 0);
  return sum > 0 ? weights.map((weight) => weight / sum) : weights.map(() => 0);
}

/** For both sides the larger pyramid allocation goes to the last ES tier. */
export function proxyPyramidWeights(count: number, ratio: number, distribution: "Even" | "Pyramid"): number[] {
  if (count < 1) return [];
  if (distribution === "Even") return Array.from({ length: count }, () => 1 / count);
  return normalize(Array.from({ length: count }, (_, index) => Math.pow(ratio, index)));
}

export function allocateIntegerVolumes(totalVolume: number, weights: number[]): number[] {
  if (!Number.isInteger(totalVolume) || totalVolume < weights.length || weights.length === 0) return [];
  const volumes = weights.map(() => 1);
  const remaining = totalVolume - weights.length;
  if (remaining === 0) return volumes;
  const rawExtras = normalize(weights).map((weight) => weight * remaining);
  const extraShares = rawExtras.map(Math.floor);
  let unallocated = remaining - extraShares.reduce((sum, shares) => sum + shares, 0);
  const remainderOrder = rawExtras
    .map((shares, index) => ({ index, remainder: shares - Math.floor(shares) }))
    .sort((left, right) => right.remainder - left.remainder || left.index - right.index);
  for (let i = 0; i < remainderOrder.length && unallocated > 0; i++, unallocated--) {
    extraShares[remainderOrder[i].index]++;
  }
  return volumes.map((volume, index) => volume + extraShares[index]);
}
