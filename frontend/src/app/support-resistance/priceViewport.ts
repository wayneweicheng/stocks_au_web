type Candle = { high: number; low: number; close: number };
type Zone = { price: number; range_low: number; range_high: number };

export type PriceWindow = {
  minimum: number;
  maximum: number;
  span: number;
  bottom: number;
  trackHeight: number;
  contentHeight: number;
  initialScrollTop: number;
};

const TRACK_HEIGHT = 520;
const clamp = (value: number, minimum: number, maximum: number) => Math.max(minimum, Math.min(value, maximum));

/** Zoom the price subplot around the latest candle; retain older extremes in a scrollable price domain. */
export function priceWindowForBars(bars: Candle[], zones: Zone[]): PriceWindow | null {
  const latest = bars[bars.length - 1]?.close;
  if (!Number.isFinite(latest)) return null;
  const values = [...bars.flatMap((bar) => [bar.low, bar.high]), ...zones.flatMap((zone) => [zone.range_low, zone.range_high, zone.price])]
    .filter(Number.isFinite);
  if (!values.length) return null;
  const minimumRaw = Math.min(...values);
  const maximumRaw = Math.max(...values);
  const padding = Math.max((maximumRaw - minimumRaw) * 0.03, Math.abs(latest) * 0.001, 0.0001);
  const minimum = minimumRaw - padding;
  const maximum = maximumRaw + padding;
  const fullSpan = maximum - minimum;
  const recent = bars.slice(-30).flatMap((bar) => [bar.low, bar.high]).filter(Number.isFinite);
  const recentSpan = recent.length ? Math.max(...recent) - Math.min(...recent) : 0;
  const span = Math.min(fullSpan, Math.max(fullSpan * 0.42, Math.abs(latest) * 0.035, recentSpan * 1.5));
  const bottom = clamp(latest - span * 0.44, minimum, maximum - span);
  const contentHeight = Math.min(7000, Math.ceil(TRACK_HEIGHT * fullSpan / span));
  const initialScrollTop = scrollTopForPrice({ minimum, maximum, span, trackHeight: TRACK_HEIGHT, contentHeight }, bottom);
  return { minimum, maximum, span, bottom, trackHeight: TRACK_HEIGHT, contentHeight, initialScrollTop };
}

export function scrollTopForPrice(window: Pick<PriceWindow, "minimum" | "maximum" | "span" | "trackHeight" | "contentHeight">, bottom: number): number {
  const scrollRange = window.contentHeight - window.trackHeight;
  const priceRange = window.maximum - window.minimum - window.span;
  return scrollRange <= 0 || priceRange <= 0 ? 0 : clamp((window.maximum - window.span - bottom) / priceRange, 0, 1) * scrollRange;
}

/** Scrollbar top = highest prices; scrollbar bottom = lowest prices. */
export function priceBottomForScroll(window: PriceWindow, scrollTop: number): number {
  const scrollRange = window.contentHeight - window.trackHeight;
  const fraction = scrollRange > 0 ? clamp(scrollTop / scrollRange, 0, 1) : 0;
  return window.maximum - window.span - fraction * (window.maximum - window.minimum - window.span);
}
