"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import Select from "../components/ui/Select";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { defaultHistoryStart, easternToday, historyRangeError } from "./dateRange";
import {
  AI_SEMICONDUCTOR_COHORT,
  analyzeRelativePerformance,
  DEFAULT_RELATIVE_SYMBOLS,
  rankLivePerformance,
  type LiveQuote,
  type LiveRank,
  type RelativePerformanceAnalysis,
  type RelativeTimeframe,
} from "./relativePerformance";

type BarsResponse = {
  timeframe: RelativeTimeframe;
  lookback_days: number;
  end_date?: string;
  symbols: string[];
  bars_by_symbol: Parameters<typeof analyzeRelativePerformance>[0];
};
type LiveQuotesResponse = { quotes?: Record<string, LiveQuote>; unavailable?: string[]; fetched_at_utc?: string };
type QuoteStatus = "pending" | "available" | "unavailable";
type QuoteProgress = { loading: boolean; pass: number; maxPasses: number; completed: number; total: number };
type PlotlyInstance = {
  react: (element: HTMLDivElement, traces: unknown[], layout: Record<string, unknown>, config: Record<string, unknown>) => Promise<unknown>;
  relayout: (element: HTMLDivElement, update: Record<string, unknown>) => Promise<unknown>;
  purge: (element: HTMLDivElement) => void;
};

const COLORS = ["#0f766e", "#2563eb", "#7c3aed", "#dc2626", "#ea580c", "#0891b2", "#4f46e5", "#a21caf", "#16a34a", "#be123c", "#475569", "#ca8a04", "#9333ea"];
const AI_SYMBOLS = new Set<string>(AI_SEMICONDUCTOR_COHORT);
const QUOTE_BATCH_SIZE = 8;
const QUOTE_RETRY_PASSES = 3;
const quoteKey = (symbol: string) => symbol.trim().toUpperCase();

function parseSymbols(value: string) {
  return [...new Set(value.split(/[\s,;]+/).map((symbol) => symbol.trim().toUpperCase().replace(/\.US$/, "")).filter(Boolean))];
}

function percent(value: number | null) {
  return value === null ? "n/a" : `${value >= 0 ? "+" : ""}${value.toFixed(2)}%`;
}

function price(value: number | null) {
  return value === null ? "n/a" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

function timeLabel(value: string | null) {
  if (!value) return "n/a";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export default function RelativePerformancePage() {
  const [symbolsInput, setSymbolsInput] = useState(DEFAULT_RELATIVE_SYMBOLS.join(", "));
  const [timeframe, setTimeframe] = useState<RelativeTimeframe>("5M");
  const [pullbackWindowMinutes, setPullbackWindowMinutes] = useState<number | "all">("all");
  const [endDate, setEndDate] = useState(() => easternToday());
  const [startDate, setStartDate] = useState(() => defaultHistoryStart(easternToday()));
  const [barsResponse, setBarsResponse] = useState<BarsResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [liveQuotes, setLiveQuotes] = useState<Record<string, LiveQuote>>({});
  const [quoteStatuses, setQuoteStatuses] = useState<Record<string, QuoteStatus>>({});
  const [quoteProgress, setQuoteProgress] = useState<QuoteProgress>({ loading: false, pass: 0, maxPasses: QUOTE_RETRY_PASSES, completed: 0, total: 0 });
  const [ranked, setRanked] = useState<LiveRank[] | null>(null);
  const [rankedAt, setRankedAt] = useState<string | null>(null);
  const plotRef = useRef<HTMLDivElement>(null);
  const plotViewportRef = useRef<HTMLDivElement>(null);
  const plotlyRef = useRef<PlotlyInstance | null>(null);
  const scrollFrameRef = useRef<number | null>(null);
  const initialLoad = useRef(false);
  const quoteRunId = useRef(0);
  const quoteAbort = useRef<AbortController | null>(null);
  const symbols = useMemo(() => parseSymbols(symbolsInput), [symbolsInput]);
  const analysis: RelativePerformanceAnalysis | null = useMemo(() => barsResponse
    ? analyzeRelativePerformance(barsResponse.bars_by_symbol, barsResponse.timeframe, pullbackWindowMinutes) : null,
  [barsResponse, pullbackWindowMinutes]);
  const chartPointCount = analysis?.series.reduce((count, item) => Math.max(count, item.points.length), 0) ?? 0;
  const chartWidth = Math.max(1100, Math.min(18000, 720 + chartPointCount * 4));

  const handleChartScroll = () => {
    if (scrollFrameRef.current !== null) cancelAnimationFrame(scrollFrameRef.current);
    scrollFrameRef.current = requestAnimationFrame(() => {
      scrollFrameRef.current = null;
      const viewport = plotViewportRef.current;
      const element = plotRef.current;
      if (!viewport || !element || !analysis || !plotlyRef.current) return;
      const plotLeft = viewport.scrollLeft + 72;
      const plotRight = viewport.scrollLeft + viewport.clientWidth - 24;
      const innerWidth = Math.max(1, chartWidth - 96);
      const points = analysis.series.flatMap((item) => item.points)
        .map((point) => ({ ...point, timestamp: Date.parse(point.time) }))
        .filter((point) => Number.isFinite(point.timestamp));
      if (!points.length) return;
      let firstTimestamp = Number.POSITIVE_INFINITY;
      let lastTimestamp = Number.NEGATIVE_INFINITY;
      for (const point of points) {
        firstTimestamp = Math.min(firstTimestamp, point.timestamp);
        lastTimestamp = Math.max(lastTimestamp, point.timestamp);
      }
      const visibleStart = firstTimestamp + Math.max(0, Math.min(1, (plotLeft - 72) / innerWidth)) * (lastTimestamp - firstTimestamp);
      const visibleEnd = firstTimestamp + Math.max(0, Math.min(1, (plotRight - 72) / innerWidth)) * (lastTimestamp - firstTimestamp);
      let minimum = Number.POSITIVE_INFINITY;
      let maximum = Number.NEGATIVE_INFINITY;
      for (const point of points) {
        if (point.timestamp >= visibleStart && point.timestamp <= visibleEnd) {
          minimum = Math.min(minimum, point.changePct);
          maximum = Math.max(maximum, point.changePct);
        }
      }
      if (!Number.isFinite(minimum) || !Number.isFinite(maximum)) return;
      const padding = Math.max((maximum - minimum) * 0.12, 0.2);
      let spreadMinimum = Number.POSITIVE_INFINITY;
      let spreadMaximum = Number.NEGATIVE_INFINITY;
      for (const point of analysis.relativeSpreadSeries.points) {
        const timestamp = Date.parse(point.time);
        if (timestamp >= visibleStart && timestamp <= visibleEnd) {
          spreadMinimum = Math.min(spreadMinimum, point.changePct);
          spreadMaximum = Math.max(spreadMaximum, point.changePct);
        }
      }
      const update: Record<string, unknown> = {
        "yaxis.autorange": false,
        "yaxis.range": [minimum - padding, maximum + padding],
      };
      if (Number.isFinite(spreadMinimum) && Number.isFinite(spreadMaximum)) {
        const spreadPadding = Math.max((spreadMaximum - spreadMinimum) * 0.12, 0.1);
        update["yaxis2.autorange"] = false;
        update["yaxis2.range"] = [spreadMinimum - spreadPadding, spreadMaximum + spreadPadding];
      }
      void plotlyRef.current.relayout(element, update);
    });
  };

  const loadLiveQuotes = useCallback((requestedSymbols: string[]) => {
    quoteAbort.current?.abort();
    const controller = new AbortController();
    quoteAbort.current = controller;
    const runId = ++quoteRunId.current;
    const normalized = [...new Set(requestedSymbols.map(quoteKey))];
    setLiveQuotes({});
    setRanked(null);
    setRankedAt(null);
    setQuoteStatuses(Object.fromEntries(normalized.map((symbol) => [symbol, "pending" as const])));
    setQuoteProgress({ loading: true, pass: 1, maxPasses: QUOTE_RETRY_PASSES, completed: 0, total: normalized.length });

    void (async () => {
      let pending = normalized;
      try {
        for (let pass = 1; pass <= QUOTE_RETRY_PASSES && pending.length > 0; pass++) {
          if (controller.signal.aborted || runId !== quoteRunId.current) return;
          setQuoteProgress({ loading: true, pass, maxPasses: QUOTE_RETRY_PASSES, completed: 0, total: pending.length });
          const retrySymbols: string[] = [];
          let completed = 0;
          for (let offset = 0; offset < pending.length; offset += QUOTE_BATCH_SIZE) {
            if (controller.signal.aborted || runId !== quoteRunId.current) return;
            const batch = pending.slice(offset, offset + QUOTE_BATCH_SIZE);
            try {
              const response = await authenticatedFetch("/relative-performance-live-quotes", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ symbols: batch }),
                signal: controller.signal,
              });
              const payload = await response.json().catch(() => ({})) as LiveQuotesResponse & { detail?: string };
              if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
              const quotesByKey = new Map(Object.entries(payload.quotes || {}).map(([symbol, quote]) => [quoteKey(symbol), quote]));
              const received: Record<string, LiveQuote> = {};
              const statuses: Record<string, QuoteStatus> = {};
              for (const requested of batch) {
                const key = quoteKey(requested);
                const quote = quotesByKey.get(key);
                if (quote && Number.isFinite(quote.price) && quote.price > 0) {
                  received[key] = { ...quote, fetched_at_utc: quote.fetched_at_utc || payload.fetched_at_utc };
                  statuses[key] = "available";
                } else {
                  retrySymbols.push(requested);
                  statuses[key] = "pending";
                }
              }
              if (runId === quoteRunId.current) {
                setLiveQuotes((current) => ({ ...current, ...received }));
                setQuoteStatuses((current) => ({ ...current, ...statuses }));
              }
            } catch (exc) {
              if (controller.signal.aborted || runId !== quoteRunId.current) return;
              retrySymbols.push(...batch);
            }
            completed += batch.length;
            setQuoteProgress({ loading: true, pass, maxPasses: QUOTE_RETRY_PASSES, completed, total: pending.length });
          }
          pending = [...new Set(retrySymbols)];
          if (pending.length > 0 && pass < QUOTE_RETRY_PASSES) await delay(1500);
        }
        if (runId === quoteRunId.current) {
          setQuoteStatuses((current) => ({ ...current, ...Object.fromEntries(pending.map((symbol) => [quoteKey(symbol), "unavailable" as const])) }));
          setQuoteProgress((current) => ({ ...current, loading: false }));
        }
      } finally {
        if (runId === quoteRunId.current && quoteAbort.current === controller) quoteAbort.current = null;
      }
    })();
  }, []);

  const loadPerformance = useCallback(async () => {
    const rangeError = historyRangeError(startDate, endDate);
    if (rangeError) {
      setError(rangeError);
      return;
    }
    if (!symbols.length) {
      setError("Enter at least one symbol to compare.");
      return;
    }
    if (symbols.length > 40) {
      setError("Compare up to 40 symbols at a time.");
      return;
    }
    quoteRunId.current++;
    quoteAbort.current?.abort();
    setQuoteProgress((current) => ({ ...current, loading: false }));
    setLoading(true);
    setError("");
    setBarsResponse(null);
    try {
      const params = new URLSearchParams({ timeframe, start_date: startDate, end_date: endDate });
      symbols.forEach((symbol) => params.append("symbols", symbol));
      const response = await authenticatedFetch(`/api/support-resistance/relative-performance?${params}`, { cache: "no-store" });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload?.detail || `HTTP ${response.status}`);
      const result = payload as BarsResponse;
      setBarsResponse({ ...result, end_date: endDate });
      setLoading(false);
      loadLiveQuotes(result.symbols || symbols);
    } catch (exc) {
      setBarsResponse(null);
      setError(exc instanceof Error ? exc.message : "Unable to load relative-performance data.");
      setLoading(false);
    }
  }, [symbols, timeframe, startDate, endDate, loadLiveQuotes]);

  useEffect(() => {
    if (initialLoad.current) return;
    initialLoad.current = true;
    void loadPerformance();
  }, [loadPerformance]);

  useEffect(() => () => {
    quoteAbort.current?.abort();
    quoteRunId.current++;
    if (scrollFrameRef.current !== null) cancelAnimationFrame(scrollFrameRef.current);
    if (plotRef.current && plotlyRef.current) plotlyRef.current.purge(plotRef.current);
  }, []);

  const rows = analysis?.rows ?? [];
  const displayRows = useMemo(() => rows.map((row) => {
    const key = quoteKey(row.symbol);
    const quote = liveQuotes[key];
    const liveDistancePct = quote && row.startPrice !== null && row.startPrice > 0
      ? Math.round((quote.price / row.startPrice - 1) * 1_000_000) / 10_000 : null;
    return { ...row, key, livePrice: quote?.price ?? null, liveDistancePct, quoteSource: quote?.source ?? null,
      quoteTime: quote?.price_time ?? null, quoteStatus: quoteStatuses[key] || "pending" as QuoteStatus };
  }), [rows, liveQuotes, quoteStatuses]);
  const rankBySymbol = useMemo(() => new Map((ranked || []).map((item) => [quoteKey(item.symbol), item.rank])), [ranked]);
  const rankedRows = useMemo(() => rankedAt
    ? [...displayRows].sort((left, right) => (rankBySymbol.get(left.key) ?? Number.MAX_SAFE_INTEGER) - (rankBySymbol.get(right.key) ?? Number.MAX_SAFE_INTEGER))
    : displayRows, [displayRows, rankedAt, rankBySymbol]);
  const availableQuoteCount = Object.keys(liveQuotes).length;
  const marketNames = new Set(["ESMAIN", "SPY", "QQQ", "DJI", "SOXX"]);

  const rankQuotes = () => {
    if (!analysis) return;
    setRanked(rankLivePerformance(analysis.rows, liveQuotes));
    setRankedAt(new Date().toISOString());
  };

  useEffect(() => {
    const element = plotRef.current;
    if (!element || !analysis) return;
    let cancelled = false;
    void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
      if (cancelled) return;
      const plotly = ((plotlyModule as any).default || plotlyModule) as PlotlyInstance;
      plotlyRef.current = plotly;
      const traces = analysis.series.map((item, index) => {
        return {
          x: item.points.map((point) => point.time),
          y: item.points.map((point) => point.changePct),
          name: item.symbol,
          type: "scatter",
          mode: "lines",
          connectgaps: false,
          line: { color: COLORS[index % COLORS.length], width: 2 },
          hovertemplate: `%{y:+.2f}%<extra>${item.symbol}</extra>`,
        };
      });
      const spreadTrace = {
        x: analysis.relativeSpreadSeries.points.map((point) => point.time),
        y: analysis.relativeSpreadSeries.points.map((point) => point.changePct),
        name: "SOXX − QQQ delta",
        type: "scatter",
        mode: "lines",
        connectgaps: false,
        yaxis: "y2",
        line: { color: "#c026d3", width: 2.5, dash: "dash" },
        hovertemplate: "%{y:+.2f} pp<extra>SOXX − QQQ delta</extra>",
      };
      // Do not draw a line from a historical date range to today's price.
      const currentDay = barsResponse?.end_date === easternToday();
      const liveMarkers = currentDay ? analysis.rows.flatMap((row, index) => {
        const quote = liveQuotes[quoteKey(row.symbol)];
        if (!row.startPrice || !quote || quote.price <= 0 || quote.source?.startsWith("database_30m")) return [];
        return [{
          x: [quote.fetched_at_utc || new Date().toISOString()],
          y: [(quote.price / row.startPrice - 1) * 100],
          name: `${row.symbol} selected price`, type: "scatter", mode: "markers",
          marker: { color: COLORS[index % COLORS.length], size: 9, symbol: "diamond" },
          showlegend: false,
          hovertemplate: `%{y:+.2f}%<extra>${row.symbol} · ${quote.source || "selected price"}</extra>`,
        }];
      }) : [];
      const layout = {
        title: `Relative performance · ${barsResponse?.timeframe === "5M" ? "5-minute" : "30-minute"} bars · rebased to 0%`,
        xaxis: { title: "Time", type: "date", rangeslider: { visible: false }, showgrid: true },
        yaxis: { title: "Price change from each symbol’s first bar (%)", ticksuffix: "%", zeroline: true, zerolinecolor: "#64748b", gridcolor: "#e2e8f0" },
        yaxis2: { title: "SOXX − QQQ (pp)", ticksuffix: " pp", overlaying: "y", side: "right", showgrid: false, zeroline: true, zerolinecolor: "#c026d3", autorange: true },
        hovermode: "x unified",
        legend: { orientation: "h", y: -0.2 },
        template: "plotly_white",
        autosize: false,
        width: chartWidth,
        height: 540,
        margin: { l: 72, r: 24, t: 64, b: 100 },
        shapes: analysis.pullbackPeriods.map((period) => ({
          type: "rect", xref: "x", yref: "paper", x0: period.startTime, x1: period.endTime, y0: 0, y1: 1,
          fillcolor: "rgba(245, 158, 11, 0.17)", line: { color: "rgba(217, 119, 6, 0.75)", width: 1 }, layer: "below",
        })),
      };
      void plotly.react(element, [...traces, spreadTrace, ...liveMarkers], layout, { responsive: true, displayModeBar: true, displaylogo: false, scrollZoom: true });
    }).catch((exc) => {
      if (!cancelled) setError(exc instanceof Error ? exc.message : "Unable to render the comparison chart.");
    });
    return () => {
      cancelled = true;
      if (plotRef.current && plotlyRef.current) plotlyRef.current.purge(plotRef.current);
      plotlyRef.current = null;
    };
  }, [analysis, barsResponse?.timeframe, barsResponse?.end_date, liveQuotes, chartWidth]);

  const rankedNames = ranked?.length ?? 0;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Relative Performance"
        subtitle="Compare intraday price changes across market, sector, and selected stocks to spot relative-strength divergence. This is a monitoring signal, not a prediction."
      />

      <section className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <div className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-[minmax(250px,1fr)_140px_150px_150px_auto_auto] 2xl:items-end">
          <div>
            <label htmlFor="relative-symbols" className="mb-1 block text-sm font-medium text-slate-700">Symbols (comma- or space-separated)</label>
            <Input id="relative-symbols" value={symbolsInput} onChange={(event) => setSymbolsInput(event.target.value.toUpperCase())} />
            <p className="mt-1 text-xs text-slate-500">Defaults: {DEFAULT_RELATIVE_SYMBOLS.join(", ")}. Compare up to 40 symbols.</p>
          </div>
          <div>
            <label htmlFor="relative-timeframe" className="mb-1 block text-sm font-medium text-slate-700">Bar timeframe</label>
            <Select id="relative-timeframe" value={timeframe} onChange={(event) => setTimeframe(event.target.value as RelativeTimeframe)}>
              <option value="5M">5 minutes</option>
              <option value="30M">30 minutes</option>
            </Select>
          </div>
          <div>
            <label htmlFor="relative-start-date" className="mb-1 block text-sm font-medium text-slate-700">History from</label>
            <Input id="relative-start-date" type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} max={endDate || undefined} />
          </div>
          <div>
            <label htmlFor="relative-end-date" className="mb-1 block text-sm font-medium text-slate-700">History through</label>
            <Input id="relative-end-date" type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} min={startDate || undefined} />
          </div>
          <Button type="button" onClick={() => void loadPerformance()} disabled={loading || symbols.length === 0 || symbols.length > 40 || !!historyRangeError(startDate, endDate)}>
            {loading ? "Loading bars…" : "Compare"}
          </Button>
          <Button type="button" variant="secondary" onClick={() => loadLiveQuotes(barsResponse?.symbols || symbols)} disabled={quoteProgress.loading || !barsResponse}>
            {quoteProgress.loading ? `Prices ${availableQuoteCount}/${quoteProgress.total} · pass ${quoteProgress.pass}/${quoteProgress.maxPasses}` : "Refresh prices"}
          </Button>
        </div>
        {historyRangeError(startDate, endDate) ? <p className="mt-3 text-xs text-amber-700" role="alert">{historyRangeError(startDate, endDate)}</p> : null}
        {quoteProgress.loading ? <p className="mt-3 text-xs text-slate-600">Fetching current session-aware prices in small batches; the table updates as each batch arrives. Pass {quoteProgress.pass}/{quoteProgress.maxPasses}: {quoteProgress.completed}/{quoteProgress.total} checked. Missing prices stay n/a.</p> : null}
        <p className="mt-2 text-xs text-slate-500">Dates are inclusive US market calendar dates (up to 30 days). Prices use the shared session-aware stock policy; index and futures quotes retain their specialized sources.</p>
      </section>

      {error ? <Alert variant="danger">{error}</Alert> : null}
      {analysis?.divergence ? (
        <Alert variant="warning">
          <strong>Relative-weakness alert:</strong> {analysis.divergence.message} Over the latest 30 minutes, the AI/semiconductor cohort averaged {percent(analysis.divergence.cohortChange30mPct)} versus {percent(analysis.divergence.benchmarkChange30mPct)} for QQQ/SOXX ({percent(analysis.divergence.relativeSpreadPct)} relative spread); {analysis.divergence.underperformingCount}/{analysis.divergence.cohortCount} cohort names lagged both.
        </Alert>
      ) : null}

      <section className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-lg font-semibold text-slate-900">Normalized price changes</h2>
            <label className="flex items-center gap-2 text-xs font-medium text-slate-600">Pullback scan
              <Select value={String(pullbackWindowMinutes)} onChange={(event) => setPullbackWindowMinutes(event.target.value === "all" ? "all" : Number(event.target.value))}>
                <option value="all">All 30–100 min</option><option value="30">30 minutes</option><option value="60">1 hour</option><option value="120">2 hours</option>
              </Select>
            </label>
          </div>
          <span className="text-xs text-slate-500">Each line starts at 0% from its first available bar; last bar {timeLabel(rows.map((row) => row.latestTime).filter((value): value is string => !!value).sort().at(-1) || null)}. Current quotes appear as markers only when the selected window ends today; weekend database closes remain in the table.</span>
        </div>
        <p className="mb-2 text-xs text-fuchsia-800">Dashed magenta line, right axis: SOXX change minus QQQ change (percentage points). A rising/positive spread means SOXX is outperforming QQQ; falling means it is losing relative strength.</p>
        {loading && !analysis ? <div className="flex h-[540px] items-center justify-center text-sm text-slate-500">Loading historical bars…</div>
          : rows.every((row) => row.bars === 0) ? <div className="flex h-72 items-center justify-center text-sm text-slate-500">No historical bars returned for these symbols.</div>
            : <div ref={plotViewportRef} className="overflow-x-auto overscroll-x-contain" onScroll={handleChartScroll} aria-label="Scrollable relative performance chart"><div ref={plotRef} style={{ width: `${chartWidth}px`, height: "540px" }} aria-label="Relative performance line chart" /></div>}
      </section>

      <section className="rounded-lg border border-amber-200 bg-amber-50/60 p-4 shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-base font-semibold text-slate-900">QQQ / SOXX relative-strength pullbacks</h2>
          <span className="inline-flex items-center gap-2 text-xs text-amber-900"><span className="h-3 w-3 rounded-sm border border-amber-600 bg-amber-300/60" /> Shaded chart windows</span>
        </div>
        <p className="mt-1 text-xs text-slate-600">Highlights non-overlapping {pullbackWindowMinutes === "all" ? "30–100-minute" : `${pullbackWindowMinutes}-minute`} windows where both ETFs fell, QQQ fell at least 0.25%, and SOXX’s decline was at least 0.20 percentage points smaller. Times are US Eastern. This flags historical relative strength, not a forecast.</p>
        {analysis?.pullbackPeriods.length ? <div className="mt-3 overflow-x-auto"><table className="min-w-full text-left text-sm"><thead className="text-xs uppercase tracking-wide text-slate-500"><tr><th className="py-2 pr-4">Period (ET)</th><th className="py-2 pr-4">Window</th><th className="py-2 pr-4">QQQ change</th><th className="py-2 pr-4">SOXX change</th><th className="py-2">SOXX relative edge</th></tr></thead><tbody className="divide-y divide-amber-200">{analysis.pullbackPeriods.map((period) => <tr key={`${period.startTime}-${period.endTime}`}><td className="whitespace-nowrap py-2 pr-4">{period.startTime.slice(5, 10)} {period.startTime.slice(11, 16)}–{period.endTime.slice(11, 16)}</td><td className="whitespace-nowrap py-2 pr-4">{period.windowMinutes} min</td><td className="py-2 pr-4 tabular-nums text-red-700">{percent(period.qqqChangePct)}</td><td className="py-2 pr-4 tabular-nums text-red-700">{percent(period.soxxChangePct)}</td><td className="py-2 tabular-nums font-semibold text-emerald-700">+{period.relativeEdgePct.toFixed(2)} pp</td></tr>)}</tbody></table></div> : <p className="mt-3 text-sm text-slate-600">No qualifying pullback windows found in this date range.</p>}
      </section>

      <section className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-200 px-4 py-3">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">Performance comparison</h2>
            <p className="text-xs text-slate-500">Current price distance is measured from each symbol’s first bar in the selected history window; unavailable prices show n/a. Weekend stock prices may be the last database 30-minute close.</p>
          </div>
          <div className="flex items-center gap-3">
            {rankedAt ? <span className="text-xs text-slate-500">Rank snapshot {timeLabel(rankedAt)} · {rankedNames} priced</span> : null}
            <Button type="button" variant="secondary" onClick={rankQuotes} disabled={!analysis || availableQuoteCount === 0}>Rank loaded prices</Button>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
              <tr><th className="px-4 py-3">Rank</th><th className="px-4 py-3">Symbol</th><th className="px-4 py-3">Group</th><th className="px-4 py-3">Selected price</th><th className="px-4 py-3">Current distance</th><th className="px-4 py-3">Price source</th><th className="px-4 py-3">Historical change</th><th className="px-4 py-3">Last 30 min</th><th className="px-4 py-3">Vs QQQ</th><th className="px-4 py-3">Latest bar time</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {rankedRows.map((row) => <tr key={row.symbol}>
                <td className="whitespace-nowrap px-4 py-3 font-semibold tabular-nums">{rankBySymbol.get(row.key) ?? "n/a"}</td>
                <td className="whitespace-nowrap px-4 py-3 font-semibold text-slate-900">{row.symbol}{row.symbol.toUpperCase() === "DJI" ? <span className="mt-0.5 block text-[10px] font-normal text-slate-500">DIA ETF proxy</span> : null}{row.bars === 0 ? <span className="mt-0.5 block text-[10px] font-normal text-amber-700">No intraday baseline</span> : null}</td>
                <td className="whitespace-nowrap px-4 py-3 text-slate-600">{AI_SYMBOLS.has(row.symbol) ? "AI / semis" : marketNames.has(row.symbol.toUpperCase()) ? "Benchmark" : "Other"}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums">{price(row.livePrice)}</td>
                <td className={`whitespace-nowrap px-4 py-3 tabular-nums ${row.liveDistancePct !== null && row.liveDistancePct >= 0 ? "text-emerald-700" : "text-red-700"}`}>{percent(row.liveDistancePct)}</td>
                <td className="whitespace-nowrap px-4 py-3 text-xs text-slate-500">{row.livePrice !== null ? <>{row.quoteSource || "available"}{row.quoteTime ? <span className="block text-[10px]">Recorded {row.quoteTime.replace("T", " ")}</span> : null}</> : quoteStatuses[row.key] === "pending" ? "pending" : "n/a"}</td>
                <td className={`whitespace-nowrap px-4 py-3 tabular-nums ${row.changePct !== null && row.changePct >= 0 ? "text-emerald-700" : "text-red-700"}`}>{percent(row.changePct)}</td>
                <td className="whitespace-nowrap px-4 py-3 tabular-nums">{percent(row.last30mPct)}</td>
                <td className={`whitespace-nowrap px-4 py-3 tabular-nums ${row.relativeToQqqPct !== null && row.relativeToQqqPct >= 0 ? "text-emerald-700" : "text-red-700"}`}>{percent(row.relativeToQqqPct)}</td>
                <td className="whitespace-nowrap px-4 py-3 text-xs text-slate-500">{timeLabel(row.latestTime)}</td>
              </tr>)}
            </tbody>
          </table>
        </div>
      </section>
      <p className="text-xs text-slate-500">Rank is a snapshot taken when you click “Rank loaded prices”; newly arrived prices update without a page refresh and can be ranked again. Current-price distance and rank need both a selected price and a historical starting bar. DJI is represented by DIA where direct Dow intraday bars are unavailable; symbols without intraday history show the selected price but remain unranked. Relative-weakness alerts show observed divergence only, not a future price direction.</p>
    </div>
  );
}
