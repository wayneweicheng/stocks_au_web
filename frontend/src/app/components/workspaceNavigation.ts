export function normalizeSymbol(value: string): string | null {
  const symbol = value.trim().toUpperCase().replace(/\.(US|AX)$/, "");
  return /^[A-Z][A-Z0-9.^-]{0,14}$/.test(symbol) ? symbol : null;
}

/** Never pass user-supplied URLs through the navigation history. */
export function knownHrefs(values: unknown, allowed: string[]): string[] {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.filter((value): value is string => typeof value === "string" && allowed.includes(value)))];
}

export function recentHrefs(previous: string[], pathname: string, allowed: string[]): string[] {
  return knownHrefs([pathname, ...previous], allowed).slice(0, 6);
}

export function symbolDestinations(symbol: string, market: "US" | "ASX" = "US") {
  const code = normalizeSymbol(symbol);
  if (!code) return null;
  return {
    chart: `/integrated-charts?symbol=${encodeURIComponent(code)}&market=${market}`,
    map: market === "US" ? `/support-resistance?stock=${encodeURIComponent(code)}&tab=stock-map` : null,
    rangeOrder: market === "US" ? `/range-orders?stock=${encodeURIComponent(code)}` : null,
  };
}
