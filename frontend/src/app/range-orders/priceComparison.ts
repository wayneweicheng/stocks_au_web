export function priceComparison(price: number | null, reference: number | null): { abs: number; pct: number } | null {
  if (price === null || reference === null || !Number.isFinite(price) || !Number.isFinite(reference) || price <= 0 || reference <= 0) return null;
  return {
    abs: Math.round((price - reference) * 100) / 100,
    pct: Math.round(((price - reference) / reference) * 10000) / 100,
  };
}
