"use client";

import { useState, useCallback, useEffect } from "react";
import { useSearchParams } from "next/navigation";

type Market = "ASX" | "US";

interface ChartConfig {
  id: string;
  label: string;
  interval: string;  // TradingView interval
  range: string;     // Display range description
}

const CHART_CONFIGS: ChartConfig[] = [
  { id: "hourly", label: "Hourly", interval: "60", range: "10 days" },
  { id: "daily", label: "Daily", interval: "D", range: "6 months" },
  { id: "weekly", label: "Weekly", interval: "W", range: "1 year" },
  { id: "monthly", label: "Monthly", interval: "M", range: "5 years" },
];

// Format symbol for TradingView based on market
function formatSymbol(stockCode: string, market: Market): string {
  const code = stockCode.toUpperCase();
  if (market === "ASX") {
    return `ASX:${code}`;
  }
  // US stocks - most are on NYSE or NASDAQ, TradingView auto-resolves
  return code;
}

// Get TradingView URL path for market
function getTradingViewUrl(stockCode: string, market: Market): string {
  const code = stockCode.toUpperCase();
  if (market === "ASX") {
    return `https://www.tradingview.com/symbols/ASX-${code}/`;
  }
  return `https://www.tradingview.com/symbols/${code}/`;
}

// Simple iframe-based TradingView chart
function TradingViewIframe({
  stockCode,
  market,
  config,
  expanded = false
}: {
  stockCode: string;
  market: Market;
  config: ChartConfig;
  expanded?: boolean;
}) {
  const symbol = formatSymbol(stockCode, market);
  const height = expanded ? 700 : 450;
  const timezone = market === "ASX" ? "Australia/Sydney" : "America/New_York";

  // TradingView Widget URL
  const widgetUrl = `https://www.tradingview.com/widgetembed/?frameElementId=tradingview_${config.id}&symbol=${encodeURIComponent(symbol)}&interval=${config.interval}&hidesidetoolbar=0&symboledit=1&saveimage=1&toolbarbg=f1f3f6&studies=MASimple%40tv-basicstudies&theme=light&style=1&timezone=${encodeURIComponent(timezone)}&studies_overrides=%7B%7D&overrides=%7B%7D&enabled_features=%5B%5D&disabled_features=%5B%5D&locale=en&utm_source=localhost&utm_medium=widget_new&utm_campaign=chart&utm_term=${encodeURIComponent(symbol)}`;

  return (
    <iframe
      src={widgetUrl}
      style={{ width: "100%", height: `${height}px`, border: "none" }}
      allowFullScreen
    />
  );
}

export default function IntegratedChartsPage() {
  const searchParams = useSearchParams();
  const [stockCode, setStockCode] = useState("");
  const [submittedCode, setSubmittedCode] = useState("");
  const [market, setMarket] = useState<Market>("ASX");
  const [submittedMarket, setSubmittedMarket] = useState<Market>("ASX");
  const [selectedChart, setSelectedChart] = useState<string>("all");

  // Read URL query parameters on mount
  useEffect(() => {
    const symbolParam = searchParams.get("symbol");
    const marketParam = searchParams.get("market");

    if (symbolParam) {
      const symbol = symbolParam.toUpperCase();
      setStockCode(symbol);
      setSubmittedCode(symbol);
    }

    if (marketParam === "ASX" || marketParam === "US") {
      setMarket(marketParam);
      setSubmittedMarket(marketParam);
    }
  }, [searchParams]);

  const handleSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault();
    if (stockCode.trim()) {
      setSubmittedCode(stockCode.trim().toUpperCase());
      setSubmittedMarket(market);
    }
  }, [stockCode, market]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      e.preventDefault();
      if (stockCode.trim()) {
        setSubmittedCode(stockCode.trim().toUpperCase());
        setSubmittedMarket(market);
      }
    }
  }, [stockCode, market]);

  const chartsToShow = selectedChart === "all"
    ? CHART_CONFIGS
    : CHART_CONFIGS.filter(c => c.id === selectedChart);

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="mx-auto max-w-7xl px-6 py-8">
        <header className="mb-8">
          <h1 className="text-3xl font-semibold tracking-tight text-slate-900">
            {submittedCode ? `${submittedCode} Charts` : "Integrated Charts"}
          </h1>
          <p className="mt-2 text-slate-600">
            View ASX and US stock charts across multiple timeframes (powered by TradingView)
          </p>
        </header>

        {/* Stock Code Input */}
        <section className="mb-6 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <form onSubmit={handleSubmit} className="flex flex-wrap items-end gap-4">
            <div className="flex-1 min-w-[200px]">
              <label htmlFor="stockCode" className="block text-sm font-medium text-slate-700 mb-1">
                Stock Code
              </label>
              <input
                id="stockCode"
                type="text"
                value={stockCode}
                onChange={(e) => setStockCode(e.target.value.toUpperCase())}
                onKeyDown={handleKeyDown}
                placeholder={market === "ASX" ? "e.g. BHP, CBA, WES" : "e.g. AAPL, MSFT, GOOGL"}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
              />
            </div>

            {/* Market Selection */}
            <div className="min-w-[140px]">
              <label className="block text-sm font-medium text-slate-700 mb-1">
                Market
              </label>
              <div className="flex rounded-md border border-slate-300 overflow-hidden">
                <button
                  type="button"
                  onClick={() => setMarket("ASX")}
                  className={`flex-1 px-4 py-2 text-sm font-medium transition-colors ${
                    market === "ASX"
                      ? "bg-emerald-600 text-white"
                      : "bg-white text-slate-700 hover:bg-slate-50"
                  }`}
                >
                  ASX
                </button>
                <button
                  type="button"
                  onClick={() => setMarket("US")}
                  className={`flex-1 px-4 py-2 text-sm font-medium transition-colors border-l border-slate-300 ${
                    market === "US"
                      ? "bg-emerald-600 text-white"
                      : "bg-white text-slate-700 hover:bg-slate-50"
                  }`}
                >
                  US
                </button>
              </div>
            </div>

            <div className="min-w-[180px]">
              <label htmlFor="chartSelect" className="block text-sm font-medium text-slate-700 mb-1">
                Timeframe
              </label>
              <select
                id="chartSelect"
                value={selectedChart}
                onChange={(e) => setSelectedChart(e.target.value)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
              >
                <option value="all">All Charts</option>
                {CHART_CONFIGS.map((config) => (
                  <option key={config.id} value={config.id}>
                    {config.label}
                  </option>
                ))}
              </select>
            </div>
            <button
              type="submit"
              className="rounded-md bg-gradient-to-r from-emerald-600 to-green-600 px-6 py-2 text-sm font-medium text-white hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
            >
              Load Charts
            </button>
          </form>
        </section>

        {/* Charts Display */}
        {submittedCode ? (
          <section className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-medium text-slate-900">
                Charts for{" "}
                <span className="text-emerald-600">{submittedCode}</span>
                <span className="ml-2 text-sm font-normal text-slate-500">
                  ({submittedMarket === "ASX" ? "ASX" : "US Market"})
                </span>
              </h2>
              <div className="flex items-center gap-4">
                <a
                  href={getTradingViewUrl(submittedCode, submittedMarket)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-sm text-emerald-600 hover:text-emerald-700"
                >
                  Open in TradingView
                </a>
                <span className="text-sm text-slate-500">
                  Showing {chartsToShow.length} chart{chartsToShow.length !== 1 ? "s" : ""}
                </span>
              </div>
            </div>

            <div className={`grid gap-6 ${selectedChart === "all" ? "lg:grid-cols-2" : "lg:grid-cols-1"}`}>
              {chartsToShow.map((config) => (
                <div
                  key={config.id}
                  className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm"
                >
                  <div className="mb-3 flex items-center justify-between">
                    <div>
                      <h3 className="font-medium text-slate-900">{config.label}</h3>
                      <p className="text-xs text-slate-500">Default view: {config.range}</p>
                    </div>
                    <button
                      onClick={() => setSelectedChart(config.id === selectedChart ? "all" : config.id)}
                      className="text-xs text-emerald-600 hover:text-emerald-700"
                    >
                      {config.id === selectedChart ? "Show All" : "Expand"}
                    </button>
                  </div>
                  <div className="overflow-hidden rounded-lg bg-slate-100">
                    <TradingViewIframe
                      stockCode={submittedCode}
                      market={submittedMarket}
                      config={config}
                      expanded={config.id === selectedChart}
                    />
                  </div>
                </div>
              ))}
            </div>
          </section>
        ) : (
          <section className="rounded-xl border border-slate-200 bg-white p-12 text-center shadow-sm">
            <div className="mx-auto max-w-md">
              <svg
                className="mx-auto h-12 w-12 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1.5}
                  d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z"
                />
              </svg>
              <h3 className="mt-4 text-lg font-medium text-slate-900">No Stock Selected</h3>
              <p className="mt-2 text-sm text-slate-600">
                Enter a stock code above and select your market (ASX or US) to view charts across different timeframes.
              </p>
            </div>
          </section>
        )}

        {/* Chart Legend */}
        <section className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <h3 className="text-sm font-medium text-slate-900 mb-3">Available Timeframes</h3>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {CHART_CONFIGS.map((config) => (
              <div key={config.id} className="flex items-center gap-2 text-sm">
                <span className="h-2 w-2 rounded-full bg-emerald-500"></span>
                <span className="font-medium text-slate-700">{config.label}</span>
                <span className="text-slate-500">- {config.range}</span>
              </div>
            ))}
          </div>
          <div className="mt-4 flex flex-wrap gap-4 text-xs text-slate-500">
            <span>
              <strong>ASX:</strong> Australian Securities Exchange (Sydney timezone)
            </span>
            <span>
              <strong>US:</strong> NYSE/NASDAQ (New York timezone)
            </span>
          </div>
          <p className="mt-3 text-xs text-slate-500">
            Charts powered by{" "}
            <a
              href="https://www.tradingview.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-emerald-600 hover:text-emerald-700"
            >
              TradingView
            </a>
            . You can interact with charts directly - zoom, pan, and add indicators.
          </p>
        </section>
      </div>
    </div>
  );
}

// TypeScript declaration for TradingView global
declare global {
  interface Window {
    TradingView: {
      widget: new (config: Record<string, unknown>) => void;
    };
  }
}
