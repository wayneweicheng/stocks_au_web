export type OrderDistribution = "Pyramid" | "Even";

export function orderWeights(count: number, distribution: OrderDistribution, ratio: number): number[] {
  if (!Number.isInteger(count) || count < 1) return [];
  if (distribution === "Even") return Array.from({ length: count }, () => 1 / count);
  const raw = Array.from({ length: count }, (_, index) => Math.pow(ratio, count - 1 - index));
  const total = raw.reduce((sum, value) => sum + value, 0);
  return total > 0 ? raw.map((value) => value / total) : raw.map(() => 0);
}

export function buyOrderVolumes(totalAmount: number, orderPrices: number[], weights: number[]): number[] {
  if (!Number.isFinite(totalAmount) || totalAmount <= 0 || weights.length === 0 || orderPrices.length !== weights.length) return [];
  if (orderPrices.some((price) => !Number.isFinite(price) || price <= 0)) return [];
  return weights.map((weight, index) => Math.max(1, Math.ceil((Math.round(totalAmount * weight * 100) / 100) / orderPrices[index])));
}

export function sellOrderVolumes(totalVolume: number, weights: number[]): number[] {
  if (!Number.isInteger(totalVolume) || totalVolume < weights.length || weights.length === 0) return [];
  const raw = weights.map((weight) => totalVolume * weight);
  const volumes = raw.map((value) => Math.max(1, Math.floor(value)));
  let difference = totalVolume - volumes.reduce((sum, value) => sum + value, 0);
  const order = raw
    .map((value, index) => ({ index, fraction: value - Math.floor(value) }))
    .sort((left, right) => right.fraction - left.fraction || left.index - right.index);
  for (let cursor = 0; difference > 0; cursor++, difference--) volumes[order[cursor % order.length].index]++;
  if (difference < 0) {
    const removeOrder = [...order].reverse();
    for (let cursor = 0; difference < 0 && cursor < removeOrder.length; cursor++) {
      const index = removeOrder[cursor].index;
      const reduction = Math.min(volumes[index] - 1, -difference);
      volumes[index] -= reduction;
      difference += reduction;
    }
  }
  return difference === 0 ? volumes : [];
}
