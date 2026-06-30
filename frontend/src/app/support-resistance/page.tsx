"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

interface PriceBar {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface PriceRange {
  price: number;
  range_low: number;
  range_high: number;
  touches: number;
  distance_pct: number;
  distance_atr: number;
  strength_rank: number;
  latest_touch: string | null;
  sources: Array<"30m" | "gamma">;
  gamma_wall: {
    strike: number;
    open_interest: number;
    nearest_expiry: string;
  } | null;
}

interface StockLevel {
  stock_code: string;
  database_code: string;
  latest_close: number;
  reference_price: number;
  price_source: string;
  latest_bar_time: string;
  bar_count: number;
  median_bar_range: number;
  atr_daily: number | null;
  atr_period: number;
  implied_volatility: number | null;
  historical_volatility: number | null;
  iv_percentile: number | null;
  iv_rank: number | null;
  iv_history_count: number;
  trailing_pe: number | null;
  forward_pe: number | null;
  iv_source: string | null;
  iv_observation_date: string | null;
  supports: PriceRange[];
  resistances: PriceRange[];
}

interface SupportResistanceResponse {
  observation_date: string;
  latest_available_date: string;
  recent_trading_dates: string[];
  live_price_check: boolean;
  live_price_missing: string[];
  lookback_days: number;
  atr_range: {
    minimum: number;
    maximum: number;
  };
  stock_code: string;
  stock: StockLevel;
  bars: PriceBar[];
}

function LevelActions({
  zone,
  tone,
  stockCode,
}: {
  zone: PriceRange;
  tone: "support" | "resistance";
  stockCode: string;
}) {
  const rangeSide = tone === "support" ? "Buy" : "Sell";
  const optionAction = tone === "support" ? "SELL" : "BUY";
  const midpoint = (zone.range_low + zone.range_high) / 2;
  const rangeParams = new URLSearchParams({
    stock: stockCode,
    side: rangeSide,
    start: zone.range_low.toFixed(2),
    end: zone.range_high.toFixed(2),
  });
  const optionParams = new URLSearchParams({
    symbol: stockCode,
    right: "P",
    action: optionAction,
    target: midpoint.toFixed(2),
    auto: "1",
  });

  return (
    <div className="flex shrink-0 items-center gap-1">
      <a
        href={`/range-orders?${rangeParams.toString()}`}
        target="_blank"
        rel="noopener noreferrer"
        title={`Open ${rangeSide.toLowerCase()} range order`}
        aria-label={`Open ${rangeSide.toLowerCase()} range order for ${stockCode}`}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-indigo-300 hover:bg-indigo-50 hover:text-indigo-700"
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
          <path d="M5 7h14M5 12h14M5 17h14" />
          <path d={tone === "support" ? "m8 10 4-4 4 4" : "m8 14 4 4 4-4"} />
        </svg>
      </a>
      <a
        href={`/option-orders?${optionParams.toString()}`}
        target="_blank"
        rel="noopener noreferrer"
        title={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order and estimate`}
        aria-label={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order for ${stockCode}`}
        className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-violet-300 hover:bg-violet-50 hover:text-violet-700"
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
          <rect x="4" y="4" width="16" height="16" rx="3" />
          <path d="M9 16V8h3.5a2.5 2.5 0 0 1 0 5H9" />
        </svg>
      </a>
    </div>
  );
}

export default function SupportResistancePage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const initialLoadStarted = useRef(false);
  const plotRef = useRef<HTMLDivElement>(null);
  const activeRequest = useRef<AbortController | null>(null);
  const [stockCode, setStockCode] = useState("");
  const [data, setData] = useState<SupportResistanceResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [lookbackDays, setLookbackDays] = useState("10");
  const [minimumAtr, setMinimumAtr] = useState(0.33);
  const [maximumAtr, setMaximumAtr] = useState(3);

  const loadData = useCallback(
    async (code: string) => {
      if (!code.trim()) {
        setError("Stock code is required");
        return;
      }
      if (!baseUrl) {
        setError("NEXT_PUBLIC_BACKEND_URL is not configured.");
        return;
      }
      setLoading(true);
      setError("");
      activeRequest.current?.abort();
      const controller = new AbortController();
      activeRequest.current = controller;
      const timeoutId = window.setTimeout(() => controller.abort(), 20000);
      try {
        const params = new URLSearchParams({
          stock_code: code.trim().toUpperCase(),
          lookback_days: String(Math.max(3, Math.min(30, Number(lookbackDays) || 10))),
          minimum_distance_atr: minimumAtr.toFixed(2),
          maximum_distance_atr: maximumAtr.toFixed(2),
          max_levels: "5",
          enable_live_prices: "false",
        });
        const response = await authenticatedFetch(`${baseUrl}/api/support-resistance?${params}`, {
          cache: "no-store",
          signal: controller.signal,
        });
        const body = await response.json();
        if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
        setData(body);
        setStockCode(body.stock_code);
      } catch (exc: any) {
        if (exc?.name === "AbortError") {
          setError("Request timed out after 20 seconds. The support/resistance service is taking too long.");
        } else {
          setError(exc?.message || String(exc));
        }
        setData(null);
      } finally {
        window.clearTimeout(timeoutId);
        if (activeRequest.current === controller) {
          activeRequest.current = null;
        }
        setLoading(false);
      }
    },
    [baseUrl, lookbackDays, minimumAtr, maximumAtr]
  );

  useEffect(() => {
    if (!initialLoadStarted.current && baseUrl) {
      initialLoadStarted.current = true;
      const params = new URLSearchParams(window.location.search);
      const initialCode = params.get("stock") || "QQQ";
      setStockCode(initialCode);
      loadData(initialCode);
    }
  }, [baseUrl, loadData]);

  useEffect(() => {
    return () => activeRequest.current?.abort();
  }, []);

  useEffect(() => {
    if (!data?.bars || data.bars.length === 0 || !plotRef.current) return;

    let cancelled = false;

    void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
      if (cancelled || !plotRef.current) return;
      const Plotly = (plotlyModule as any).default || plotlyModule;
      const bars = data.bars;
      const stock = data.stock;
      const supports = stock.supports || [];
      const resistances = stock.resistances || [];
      const supportColors = ["#065f46", "#047857", "#10b981", "#34d399", "#6ee7b7"];
      const resistanceColors = ["#991b1b", "#b91c1c", "#ef4444", "#f87171", "#fca5a5"];

      const traces: any[] = [
        // Candlestick trace
        {
          x: bars.map((b) => b.time),
          open: bars.map((b) => b.open),
          high: bars.map((b) => b.high),
          low: bars.map((b) => b.low),
          close: bars.map((b) => b.close),
          type: "candlestick",
          name: "Price",
          yaxis: "y",
        },
        // Volume trace
        {
          x: bars.map((b) => b.time),
          y: bars.map((b) => b.volume),
          type: "bar",
          name: "Volume",
          yaxis: "y2",
          marker: { color: "rgba(100, 100, 100, 0.3)" },
        },
      ];

      // Support zones
      for (const [index, zone] of supports.entries()) {
        const lineColor = supportColors[Math.min(index, supportColors.length - 1)];
        const supportHover = `<b>Support Zone</b><br>Mid: ${zone.price.toFixed(4)}<br>Range Start: ${zone.range_low.toFixed(4)}<br>Range End: ${zone.range_high.toFixed(4)}<br>Strength Rank: ${zone.strength_rank || index + 1}<br>Touches: ${zone.touches}<br>ATR Distance: ${zone.distance_atr.toFixed(2)}<extra></extra>`;
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time],
          y: [zone.price, zone.price],
          type: "scatter",
          mode: "lines",
          name: `Support ${zone.price.toFixed(2)}`,
          text: [supportHover, supportHover],
          line: {
            color: lineColor,
            width: Math.max(2, 5 - index),
          },
          hoverinfo: "text",
          yaxis: "y",
        });

        // Range fill
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time, bars[bars.length - 1].time, bars[0].time],
          y: [zone.range_low, zone.range_low, zone.range_high, zone.range_high],
          type: "scatter",
          name: "",
          text: [supportHover, supportHover, supportHover, supportHover],
          fill: "toself",
          fillcolor: "rgba(34, 197, 94, 0.1)",
          line: { color: "rgba(34, 197, 94, 0)" },
          showlegend: false,
          hoveron: "fills",
          hoverinfo: "text",
          yaxis: "y",
        });
      }

      // Resistance zones
      for (const [index, zone] of resistances.entries()) {
        const lineColor = resistanceColors[Math.min(index, resistanceColors.length - 1)];
        const resistanceHover = `<b>Resistance Zone</b><br>Mid: ${zone.price.toFixed(4)}<br>Range Start: ${zone.range_low.toFixed(4)}<br>Range End: ${zone.range_high.toFixed(4)}<br>Strength Rank: ${zone.strength_rank || index + 1}<br>Touches: ${zone.touches}<br>ATR Distance: ${zone.distance_atr.toFixed(2)}<extra></extra>`;
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time],
          y: [zone.price, zone.price],
          type: "scatter",
          mode: "lines",
          name: `Resistance ${zone.price.toFixed(2)}`,
          text: [resistanceHover, resistanceHover],
          line: {
            color: lineColor,
            width: Math.max(2, 5 - index),
          },
          hoverinfo: "text",
          yaxis: "y",
        });

        // Range fill
        traces.push({
          x: [bars[0].time, bars[bars.length - 1].time, bars[bars.length - 1].time, bars[0].time],
          y: [zone.range_low, zone.range_low, zone.range_high, zone.range_high],
          type: "scatter",
          name: "",
          text: [resistanceHover, resistanceHover, resistanceHover, resistanceHover],
          fill: "toself",
          fillcolor: "rgba(239, 68, 68, 0.1)",
          line: { color: "rgba(239, 68, 68, 0)" },
          showlegend: false,
          hoveron: "fills",
          hoverinfo: "text",
          yaxis: "y",
        });
      }

      const layout = {
        title: `${data.stock_code || "Loading..."} - Support/Resistance (30m)`,
        xaxis: {
          title: "Time",
          type: "category",
          rangeslider: { visible: false },
        },
        yaxis: { title: "Price (USD)", side: "left" },
        yaxis2: {
          title: "Volume",
          overlaying: "y",
          side: "right",
        },
        hovermode: "closest",
        template: "plotly_white",
        height: 860,
        margin: { l: 56, r: 56, t: 64, b: 56 },
      };

      Plotly.newPlot(plotRef.current, traces, layout, { responsive: true });
    }).catch((exc) => {
      setError(exc?.message || "Failed to load Plotly charting library");
    });

    return () => {
      cancelled = true;
      if (plotRef.current) {
        void import("plotly.js/dist/plotly-finance.min.js").then((plotlyModule) => {
          const Plotly = (plotlyModule as any).default || plotlyModule;
          Plotly.purge(plotRef.current);
        }).catch(() => undefined);
      }
    };
  }, [data]);

  return (
    <div className="space-y-6">
      <PageHeader title="Support / Resistance" description="Interactive 30-minute candlestick chart with support/resistance zones" />

      <Card>
        <CardHeader>
          <CardTitle>Stock Selection</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex gap-3">
              <Input
                placeholder="Enter stock code (e.g., QQQ, SPY, NVDA)"
                value={stockCode}
                onChange={(e) => setStockCode(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === "Enter") loadData(stockCode);
                }}
                className="flex-1"
              />
              <Button onClick={() => loadData(stockCode)} disabled={loading || !stockCode.trim()}>
                {loading ? "Loading..." : "Load"}
              </Button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="text-sm font-medium text-slate-700">Lookback Days</label>
                <Input
                  type="number"
                  min="3"
                  max="30"
                  value={lookbackDays}
                  onChange={(e) => setLookbackDays(e.target.value)}
                  className="mt-1"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Min ATR Distance</label>
                <Input
                  type="number"
                  step="0.05"
                  min="0"
                  max="10"
                  value={minimumAtr}
                  onChange={(e) => setMinimumAtr(parseFloat(e.target.value) || 0.33)}
                  className="mt-1"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Max ATR Distance</label>
                <Input
                  type="number"
                  step="0.05"
                  min="0"
                  max="10"
                  value={maximumAtr}
                  onChange={(e) => setMaximumAtr(parseFloat(e.target.value) || 3)}
                  className="mt-1"
                />
              </div>
            </div>

            {error ? <Alert variant="danger">Error: {error}</Alert> : null}
          </div>
        </CardContent>
      </Card>

      {data && (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Chart Data</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div>
                  <div className="text-slate-500">Latest Close</div>
                  <div className="font-semibold">${data.stock.latest_close.toFixed(4)}</div>
                </div>
                <div>
                  <div className="text-slate-500">Bar Count</div>
                  <div className="font-semibold">{data.stock.bar_count}</div>
                </div>
                <div>
                  <div className="text-slate-500">ATR (Daily)</div>
                  <div className="font-semibold">{data.stock.atr_daily?.toFixed(4) || "n/a"}</div>
                </div>
                <div>
                  <div className="text-slate-500">Observation Date</div>
                  <div className="font-semibold text-xs">{data.observation_date}</div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Interactive Chart</CardTitle>
            </CardHeader>
            <CardContent>
              <div ref={plotRef} style={{ width: "100%", height: "860px" }} />
            </CardContent>
          </Card>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle className="text-emerald-700">Support Levels</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {data.stock.supports.length > 0 ? (
                    data.stock.supports.map((zone, idx) => (
                      <div key={idx} className="p-3 bg-emerald-50 rounded border border-emerald-200">
                        <div className="flex items-start justify-between gap-3">
                          <div className="font-semibold text-emerald-900">
                            ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                          </div>
                          <LevelActions zone={zone} tone="support" stockCode={data.stock_code} />
                        </div>
                        <div className="text-xs text-emerald-700 mt-1">
                          Rank {zone.strength_rank || idx + 1} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                          {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                        </div>
                        <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                      </div>
                    ))
                  ) : (
                    <div className="text-slate-500">No support levels found</div>
                  )}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-red-700">Resistance Levels</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {data.stock.resistances.length > 0 ? (
                    data.stock.resistances.map((zone, idx) => (
                      <div key={idx} className="p-3 bg-red-50 rounded border border-red-200">
                        <div className="flex items-start justify-between gap-3">
                          <div className="font-semibold text-red-900">
                            ${zone.price.toFixed(4)} - ${zone.range_low.toFixed(4)} to ${zone.range_high.toFixed(4)}
                          </div>
                          <LevelActions zone={zone} tone="resistance" stockCode={data.stock_code} />
                        </div>
                        <div className="text-xs text-red-700 mt-1">
                          Rank {zone.strength_rank || idx + 1} &bull; {zone.distance_pct > 0 ? "+" : ""}{zone.distance_pct.toFixed(2)}% &bull; {zone.distance_atr.toFixed(2)} ATR
                          {zone.touches > 0 ? ` | ${zone.touches} touch${zone.touches === 1 ? "" : "es"}` : ""}
                        </div>
                        <div className="text-xs text-slate-600 mt-1">{zone.sources.join(" + ")}</div>
                      </div>
                    ))
                  ) : (
                    <div className="text-slate-500">No resistance levels found</div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </>
      )}
    </div>
  );
}
