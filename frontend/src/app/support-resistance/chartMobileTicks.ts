export function chartMobileTicks(bars: { time: string }[]): { tickvals: number[]; ticktext: string[] } {
  if (!bars.length) return { tickvals: [], ticktext: [] };
  const step = Math.max(1, Math.ceil(bars.length / 5));
  const tickvals = Array.from({ length: Math.ceil(bars.length / step) }, (_, index) => index * step);
  if (tickvals[tickvals.length - 1] !== bars.length - 1) tickvals.push(bars.length - 1);
  return { tickvals, ticktext: tickvals.map((index) => {
    const match = bars[index].time.match(/^\d{4}-(\d{2})-(\d{2})T(\d{2}:\d{2})/);
    return match ? `${match[1]}/${match[2]} ${match[3]}` : bars[index].time.slice(0, 16);
  }) };
}
