export function ibLivePriceFromResponse(payload: unknown, symbol: string): number | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const quote = payload as Record<string, unknown>;
  const expected = symbol.trim().toUpperCase().replace(/\.US$/, "");
  const actual = typeof quote.stock_code === "string" ? quote.stock_code.trim().toUpperCase().replace(/\.US$/, "") : "";
  const price = quote.live_price;
  // This endpoint may return delayed IB data or an ES-derived SPX proxy. Neither is a live stock quote.
  return actual === expected && quote.source === "ib_live" && typeof price === "number" && Number.isFinite(price) && price > 0
    ? price : null;
}
