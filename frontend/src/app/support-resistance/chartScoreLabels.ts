/** Plotly's price axis occupies domain [0.22, 1] of the plot height.
 * Convert a price into a pixel position in the fixed-height chart viewport.
 * This is independent of horizontal candle scrolling.
 */
export function scoreYPosition(price: number, bottom: number, top: number, mobile: boolean): number | null {
  if (![price, bottom, top].every(Number.isFinite) || top <= bottom || price < bottom || price > top) return null;
  const height = mobile ? 560 : 860;
  const marginTop = mobile ? 62 : 64;
  const marginBottom = mobile ? 90 : 120;
  return marginTop + (top - price) / (top - bottom) * (height - marginTop - marginBottom) * 0.78;
}
