"use client";

import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import PageHeader from "./PageHeader";
import Badge from "./ui/Badge";
import Button from "./ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/Card";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type Market = "ASX" | "US";

interface RegimeComponent {
  name: string;
  score: number | null;
  available: boolean;
  detail: string;
  source: string;
  as_of: string | null;
  diagnostics?: BreadthDiagnostics | null;
}

interface BreadthDiagnostics {
  state?: string | null;
  explanation?: string | null;
  equal_weight_change?: number | null;
  spx_change?: number | null;
  leadership_gap?: number | null;
  advancers?: number | null;
  decliners?: number | null;
  advance_percentage?: number | null;
  percentage_above_sma50?: number | null;
  percentage_above_sma200?: number | null;
  trend_as_of?: string | null;
}

interface Regime {
  market: Market;
  as_of: string | null;
  label: "BULLISH" | "BEARISH" | "NEUTRAL";
  score: number;
  confidence: number;
  components: RegimeComponent[];
  supporting_factors: string[];
  conflicting_factors: string[];
  trading_implication: string;
  gex_regime?: string | null;
}

interface OptionStrategy {
  strategy: string;
  suitability_score: number;
  summary: string;
  reasons: string[];
  risks: string[];
  requires_chain_validation: boolean;
}

interface Evidence {
  source: string;
  direction: string;
  strength: number;
  observed_at: string | null;
  reasons: string[];
  risks: string[];
  horizon: string;
}

interface Opportunity {
  symbol: string;
  market: Market;
  score: number;
  direction: string;
  horizon: string;
  source_count: number;
  sources: string[];
  regime_fit: string;
  reasons: string[];
  risks: string[];
  evidence: Evidence[];
  option_strategies: OptionStrategy[];
}

interface SummaryResponse {
  requested_date: string;
  generated_at: string;
  sentiment?: SentimentInsight | null;
  fear_greed?: FearGreedInsight | null;
  market_intelligence?: MarketIntelligenceInsight | null;
  regimes: Partial<Record<Market, Regime>>;
  opportunities: Partial<Record<Market, Opportunity[]>>;
}

interface MarketIntelligenceWatchItem {
  symbol: string;
  bias?: string;
  reason?: string;
}

interface MarketIntelligenceTipItem {
  symbol: string;
  source?: string;
  bias?: string;
  reason?: string;
  level?: string;
  timeframe?: string;
  shared_at?: string | null;
}

interface MarketIntelligenceContributorView {
  source: string;
  stance?: string;
  view: string;
  shared_at?: string | null;
  shared_at_et?: string | null;
}

interface MarketIntelligenceInsight {
  available: boolean;
  market: "US";
  summary_date: string | null;
  window_start?: string | null;
  window_end?: string | null;
  message_count?: number | null;
  stance?: string;
  stance_score?: number;
  confidence?: string;
  headline?: string;
  dominant_narrative?: string;
  catalysts?: string[];
  risks?: string[];
  consensus?: string[];
  contributor_views?: MarketIntelligenceContributorView[];
  contributors_analyzed?: number | null;
  watchlist?: Array<MarketIntelligenceWatchItem | string>;
  stock_tips?: MarketIntelligenceTipItem[];
  index_tips?: MarketIntelligenceTipItem[];
  what_changed?: string;
  source: string;
  source_status?: string;
}

interface SentimentPrediction {
  horizon_weeks: number;
  predicted_return: number;
  interval_10: number;
  interval_90: number;
  probability_positive: number;
  method: string;
}

interface SentimentInsight {
  available: boolean;
  score: number;
  reading_date: string | null;
  bullish: number;
  neutral: number;
  bearish: number;
  bull_bear_spread: number;
  historical_percentile: number;
  regime: string;
  insight: string;
  predictions: SentimentPrediction[];
  source_url: string;
  source_status: string;
  live_reading_date?: string | null;
  fetch_error?: string | null;
  warning: string;
}

interface FearGreedPrediction {
  horizon_trading_days: number;
  predicted_return: number;
  interval_10: number;
  interval_90: number;
  probability_positive: number;
  method: string;
}

interface FearGreedInsight {
  available: boolean;
  reading_date: string | null;
  score: number;
  rating: string;
  contrarian_score: number;
  historical_percentile: number;
  previous_close?: number | null;
  previous_1_week?: number | null;
  previous_1_month?: number | null;
  insight: string;
  predictions: FearGreedPrediction[];
  source_url: string;
  source_status: string;
  warning: string;
}

function localIsoDate() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function badgeVariant(value: string) {
  const normalized = value.toUpperCase();
  if (normalized.includes("BULLISH") || normalized === "STRONG") return "success" as const;
  if (normalized.includes("BEARISH") || normalized === "CONFLICTING") return "danger" as const;
  if (normalized.includes("NEUTRAL")) return "warning" as const;
  return "default" as const;
}

function scoreTone(score: number) {
  if (score >= 62) return "text-emerald-700";
  if (score <= 38) return "text-red-700";
  return "text-amber-700";
}

function formatStrategy(value: string) {
  return value
    .toLowerCase()
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function signedPercent(value?: number | null) {
  if (value === null || value === undefined) return "Unavailable";
  return `${value >= 0 ? "+" : ""}${value.toFixed(2)}%`;
}

function returnPercent(value: number) {
  return `${value >= 0 ? "+" : ""}${(value * 100).toFixed(1)}%`;
}

function MarketIntelligenceCard({ insight }: { insight: MarketIntelligenceInsight }) {
  if (!insight.available) {
    return (
      <Card>
        <CardHeader><CardTitle className="text-lg">Market Intelligence Brief</CardTitle></CardHeader>
        <CardContent>
          <p className="text-sm text-slate-600">{insight.source_status}</p>
        </CardContent>
      </Card>
    );
  }

  const stance = insight.stance || "NEUTRAL";
  const watchlist = insight.watchlist || [];
  const stockTips = insight.stock_tips || [];
  const indexTips = insight.index_tips || [];

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-lg">Market Intelligence Brief</CardTitle>
            <p className="mt-1 text-xs text-slate-500">
              Selected follower views for the rolling 24 hours through {insight.summary_date}
              {insight.message_count ? ` | ${insight.message_count} messages` : ""}
              {insight.contributors_analyzed ? ` | ${insight.contributors_analyzed} contributors` : ""}
            </p>
          </div>
          <div className="text-right">
            <Badge variant={badgeVariant(stance)}>{stance.replaceAll("_", " ")}</Badge>
            <div className="mt-1 text-xs text-slate-500">
              {insight.confidence || "MEDIUM"} confidence
              {insight.stance_score !== undefined ? ` | ${insight.stance_score}/100` : ""}
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {insight.headline ? <h3 className="font-semibold text-slate-900">{insight.headline}</h3> : null}
        <p className="mt-2 text-sm leading-6 text-slate-700">{insight.dominant_narrative}</p>

        {insight.what_changed ? (
          <div className="mt-4 rounded-md border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">
            <span className="font-semibold">What changed:</span> {insight.what_changed}
          </div>
        ) : null}

        {insight.consensus?.length ? (
          <div className="mt-4 rounded-md border border-slate-200 bg-slate-50 p-3">
            <div className="text-xs font-semibold uppercase tracking-wide text-slate-600">Shared View</div>
            <ul className="mt-2 space-y-1 text-xs leading-5 text-slate-700">
              {insight.consensus.map((item) => <li key={item}>+ {item}</li>)}
            </ul>
          </div>
        ) : null}

        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <div>
            <div className="text-xs font-semibold uppercase tracking-wide text-emerald-700">
              Bullish / Catalyst Views
            </div>
            <ul className="mt-2 space-y-2 text-xs leading-5 text-slate-700">
              {(insight.catalysts || []).map((item) => <li key={item}>+ {item}</li>)}
              {!insight.catalysts?.length ? <li className="text-slate-400">No clear catalyst extracted.</li> : null}
            </ul>
          </div>
          <div>
            <div className="text-xs font-semibold uppercase tracking-wide text-red-700">
              Risk / Bearish Views
            </div>
            <ul className="mt-2 space-y-2 text-xs leading-5 text-slate-700">
              {(insight.risks || []).map((item) => <li key={item}>- {item}</li>)}
              {!insight.risks?.length ? <li className="text-slate-400">No clear risk extracted.</li> : null}
            </ul>
          </div>
        </div>

        {stockTips.length || indexTips.length ? (
          <div className="mt-4 grid gap-4 border-t border-slate-100 pt-4 md:grid-cols-2">
            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-emerald-700">
                Stock Tips
              </div>
              <div className="mt-2 space-y-2">
                {stockTips.map((item, index) => (
                  <div key={`${item.symbol}-${item.source || "stock"}-${index}`} className="rounded-md border border-emerald-100 bg-emerald-50/50 p-3">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="text-xs font-semibold text-slate-900">{item.symbol}</span>
                      {item.bias ? <Badge variant={badgeVariant(item.bias)}>{item.bias.replaceAll("_", " ")}</Badge> : null}
                      {item.source ? <span className="text-[11px] text-slate-500">{item.source}</span> : null}
                    </div>
                    {item.reason ? <p className="mt-1 text-xs leading-5 text-slate-700">{item.reason}</p> : null}
                    <div className="mt-1 text-[11px] text-slate-500">
                      {[item.timeframe, item.shared_at].filter(Boolean).join(" | ")}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-indigo-700">
                Index Calls
              </div>
              <div className="mt-2 space-y-2">
                {indexTips.map((item, index) => (
                  <div key={`${item.symbol}-${item.source || "index"}-${index}`} className="rounded-md border border-indigo-100 bg-indigo-50/50 p-3">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="text-xs font-semibold text-slate-900">{item.symbol}</span>
                      {item.bias ? <Badge variant={badgeVariant(item.bias)}>{item.bias.replaceAll("_", " ")}</Badge> : null}
                      {item.source ? <span className="text-[11px] text-slate-500">{item.source}</span> : null}
                    </div>
                    {item.reason ? <p className="mt-1 text-xs leading-5 text-slate-700">{item.reason}</p> : null}
                    <div className="mt-1 text-[11px] text-slate-500">
                      {[item.level, item.timeframe, item.shared_at].filter(Boolean).join(" | ")}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        ) : null}

        {insight.contributor_views?.length ? (
          <div className="mt-4 border-t border-slate-100 pt-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-indigo-700">
              Follower Opinions
            </div>
            <div className="mt-2 grid gap-2 md:grid-cols-2">
              {insight.contributor_views.map((item, index) => (
                <div
                  key={`${item.source}-${index}`}
                  className="rounded-md border border-indigo-100 bg-indigo-50/60 p-3"
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xs font-semibold text-slate-800">{item.source}</span>
                    {item.stance ? (
                      <Badge variant={badgeVariant(item.stance)}>{item.stance.replaceAll("_", " ")}</Badge>
                    ) : null}
                  </div>
                  <p className="mt-2 text-xs leading-5 text-slate-700">{item.view}</p>
                  <div className="mt-2 text-[11px] leading-4 text-slate-500">
                    {item.shared_at ? (
                      <>
                        Shared: {item.shared_at} Sydney
                        {item.shared_at_et ? ` | ${item.shared_at_et} US Eastern` : ""}
                      </>
                    ) : (
                      "Shared time unavailable for this cached opinion"
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : null}

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-4">
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-medium text-slate-500">Watchlist</span>
            {watchlist.map((item) => {
              const value = typeof item === "string" ? { symbol: item } : item;
              return (
                <Badge key={value.symbol} variant={value.bias ? badgeVariant(value.bias) : "default"}>
                  {value.symbol}{value.bias && value.bias !== "MIXED" ? ` ${value.bias}` : ""}
                </Badge>
              );
            })}
            {!watchlist.length ? <span className="text-xs text-slate-400">No concentrated ticker focus.</span> : null}
          </div>
          <Link href="/discord-summary" className="text-xs font-medium text-indigo-700 hover:underline">
            Open full market intelligence
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}

function SentimentCard({ sentiment }: { sentiment: SentimentInsight }) {
  if (!sentiment.available) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">AAII Sentiment and SPX Outlook</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-slate-600">{sentiment.source_status}</p>
          <p className="mt-2 text-xs text-slate-500">{sentiment.warning}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-lg">AAII Sentiment and SPX Outlook</CardTitle>
            <p className="mt-1 text-xs text-slate-500">
              Reading: {sentiment.reading_date} | {sentiment.source_status}
            </p>
          </div>
          <div className="text-right">
            <Badge variant={sentiment.score >= 62 ? "success" : sentiment.score <= 38 ? "danger" : "warning"}>
              {sentiment.regime}
            </Badge>
            <div className={`mt-1 text-2xl font-semibold ${scoreTone(sentiment.score)}`}>
              {sentiment.score.toFixed(0)}
              <span className="text-sm font-normal text-slate-400">/100 contrarian</span>
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="grid gap-3 sm:grid-cols-4">
          <div className="rounded-md bg-emerald-50 p-3">
            <div className="text-xs text-emerald-700">Bullish</div>
            <div className="mt-1 text-xl font-semibold text-emerald-800">{sentiment.bullish.toFixed(1)}%</div>
          </div>
          <div className="rounded-md bg-slate-50 p-3">
            <div className="text-xs text-slate-500">Neutral</div>
            <div className="mt-1 text-xl font-semibold text-slate-700">{sentiment.neutral.toFixed(1)}%</div>
          </div>
          <div className="rounded-md bg-red-50 p-3">
            <div className="text-xs text-red-700">Bearish</div>
            <div className="mt-1 text-xl font-semibold text-red-800">{sentiment.bearish.toFixed(1)}%</div>
          </div>
          <div className="rounded-md bg-amber-50 p-3">
            <div className="text-xs text-amber-700">Bull - bear spread</div>
            <div className="mt-1 text-xl font-semibold text-amber-800">
              {signedPercent(sentiment.bull_bear_spread)}
            </div>
            <div className="text-[11px] text-amber-700">
              {sentiment.historical_percentile.toFixed(0)}th percentile
            </div>
          </div>
        </div>

        <p className="mt-4 text-sm text-slate-700">{sentiment.insight}</p>

        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="pb-2 font-medium">SPX horizon</th>
                <th className="pb-2 font-medium">Expected</th>
                <th className="pb-2 font-medium">10-90% range</th>
                <th className="pb-2 font-medium">Probability up</th>
              </tr>
            </thead>
            <tbody>
              {sentiment.predictions.map((prediction) => (
                <tr key={prediction.horizon_weeks} className="border-b border-slate-100">
                  <td className="py-2">{prediction.horizon_weeks} week{prediction.horizon_weeks === 1 ? "" : "s"}</td>
                  <td className="py-2 font-medium">{returnPercent(prediction.predicted_return)}</td>
                  <td className="py-2">
                    {returnPercent(prediction.interval_10)} to {returnPercent(prediction.interval_90)}
                  </td>
                  <td className="py-2">{(prediction.probability_positive * 100).toFixed(0)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-3 flex flex-wrap justify-between gap-2 text-[11px] text-slate-500">
          <span>{sentiment.warning}</span>
          <a
            href={sentiment.source_url}
            target="_blank"
            rel="noreferrer"
            className="whitespace-nowrap text-blue-700 hover:underline"
          >
            AAII source
          </a>
        </div>
      </CardContent>
    </Card>
  );
}

function FearGreedCard({ fearGreed }: { fearGreed: FearGreedInsight }) {
  if (!fearGreed.available) {
    return (
      <Card>
        <CardHeader><CardTitle className="text-lg">CNN Fear & Greed and SPX Outlook</CardTitle></CardHeader>
        <CardContent>
          <p className="text-sm text-slate-600">{fearGreed.source_status}</p>
          <p className="mt-2 text-xs text-slate-500">{fearGreed.warning}</p>
        </CardContent>
      </Card>
    );
  }

  const changeFromClose =
    fearGreed.previous_close === null || fearGreed.previous_close === undefined
      ? null
      : fearGreed.score - fearGreed.previous_close;
  const changeFromWeek =
    fearGreed.previous_1_week === null || fearGreed.previous_1_week === undefined
      ? null
      : fearGreed.score - fearGreed.previous_1_week;

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-lg">CNN Fear & Greed and SPX Outlook</CardTitle>
            <p className="mt-1 text-xs text-slate-500">
              Reading: {fearGreed.reading_date} | {fearGreed.source_status}
            </p>
          </div>
          <div className="text-right">
            <Badge variant={fearGreed.score < 45 ? "danger" : fearGreed.score > 55 ? "success" : "warning"}>
              {fearGreed.rating.toUpperCase()}
            </Badge>
            <div className="mt-1 text-3xl font-semibold text-slate-900">
              {fearGreed.score.toFixed(0)}
              <span className="text-sm font-normal text-slate-400">/100 index</span>
            </div>
            <div className={`text-xs ${scoreTone(fearGreed.contrarian_score)}`}>
              Contrarian context {fearGreed.contrarian_score.toFixed(0)}/100
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="grid gap-3 sm:grid-cols-4">
          <div className="rounded-md bg-slate-50 p-3">
            <div className="text-xs text-slate-500">Historical percentile</div>
            <div className="mt-1 text-xl font-semibold text-slate-800">
              {fearGreed.historical_percentile.toFixed(0)}th
            </div>
          </div>
          <div className="rounded-md bg-slate-50 p-3">
            <div className="text-xs text-slate-500">From prior close</div>
            <div className="mt-1 text-xl font-semibold text-slate-800">
              {changeFromClose === null ? "N/A" : `${changeFromClose >= 0 ? "+" : ""}${changeFromClose.toFixed(1)}`}
            </div>
          </div>
          <div className="rounded-md bg-slate-50 p-3">
            <div className="text-xs text-slate-500">From one week</div>
            <div className="mt-1 text-xl font-semibold text-slate-800">
              {changeFromWeek === null ? "N/A" : `${changeFromWeek >= 0 ? "+" : ""}${changeFromWeek.toFixed(1)}`}
            </div>
          </div>
          <div className="rounded-md bg-slate-50 p-3">
            <div className="text-xs text-slate-500">One month ago</div>
            <div className="mt-1 text-xl font-semibold text-slate-800">
              {fearGreed.previous_1_month?.toFixed(1) ?? "N/A"}
            </div>
          </div>
        </div>

        <p className="mt-4 text-sm text-slate-700">{fearGreed.insight}</p>

        <div className="mt-4 overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="pb-2 font-medium">SPX horizon</th>
                <th className="pb-2 font-medium">Expected</th>
                <th className="pb-2 font-medium">10-90% range</th>
                <th className="pb-2 font-medium">Probability up</th>
              </tr>
            </thead>
            <tbody>
              {fearGreed.predictions.map((prediction) => (
                <tr key={prediction.horizon_trading_days} className="border-b border-slate-100">
                  <td className="py-2">{prediction.horizon_trading_days} trading days</td>
                  <td className="py-2 font-medium">{returnPercent(prediction.predicted_return)}</td>
                  <td className="py-2">
                    {returnPercent(prediction.interval_10)} to {returnPercent(prediction.interval_90)}
                  </td>
                  <td className="py-2">{(prediction.probability_positive * 100).toFixed(0)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="mt-3 flex flex-wrap justify-between gap-2 text-[11px] text-slate-500">
          <span>{fearGreed.warning}</span>
          <a href={fearGreed.source_url} target="_blank" rel="noreferrer" className="text-blue-700 hover:underline">
            CNN source
          </a>
        </div>
      </CardContent>
    </Card>
  );
}

function RegimeCard({ regime }: { regime: Regime }) {
  const available = regime.components.filter((component) => component.available);

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-lg">{regime.market} Market Regime</CardTitle>
            <p className="mt-1 text-xs text-slate-500">
              Effective date: {regime.as_of || "No data"} · Confidence {regime.confidence.toFixed(0)}%
            </p>
          </div>
          <div className="text-right">
            <Badge variant={badgeVariant(regime.label)}>{regime.label}</Badge>
            <div className={`mt-1 text-3xl font-semibold ${scoreTone(regime.score)}`}>
              {regime.score.toFixed(0)}
              <span className="text-sm font-normal text-slate-400">/100</span>
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="mb-4 rounded-lg bg-slate-50 px-4 py-3 text-sm text-slate-700">
          {regime.trading_implication}
        </div>

        <div className="space-y-3">
          {regime.components.map((component) => (
            <div key={component.name}>
              <div className="mb-1 flex items-center justify-between gap-3 text-xs">
                <span className="font-medium text-slate-700">{component.name}</span>
                <span className={component.available ? scoreTone(component.score || 50) : "text-slate-400"}>
                  {component.available ? component.score?.toFixed(0) : "Unavailable"}
                </span>
              </div>
              <div className="h-2 overflow-hidden rounded-full bg-slate-100">
                <div
                  className={
                    !component.available
                      ? "h-full bg-slate-200"
                      : (component.score || 50) >= 62
                        ? "h-full bg-emerald-500"
                        : (component.score || 50) <= 38
                          ? "h-full bg-red-500"
                          : "h-full bg-amber-400"
                  }
                  style={{ width: `${component.available ? component.score : 0}%` }}
                />
              </div>
              <div className="mt-1 flex justify-between gap-3 text-[11px] text-slate-500">
                <span>{component.detail}</span>
                {component.as_of ? <span className="whitespace-nowrap">{component.as_of}</span> : null}
              </div>
              {component.name === "Breadth" && component.diagnostics ? (
                <div className="mt-2 grid grid-cols-2 gap-2 rounded-md border border-slate-200 bg-slate-50 p-2 text-[11px] sm:grid-cols-3">
                  <div>
                    <div className="text-slate-400">Advancing</div>
                    <div className="font-medium text-slate-700">
                      {component.diagnostics.advance_percentage === null ||
                      component.diagnostics.advance_percentage === undefined
                        ? "Unavailable"
                        : `${component.diagnostics.advance_percentage.toFixed(1)}%`}
                    </div>
                  </div>
                  <div>
                    <div className="text-slate-400">Average stock</div>
                    <div className="font-medium text-slate-700">
                      {signedPercent(component.diagnostics.equal_weight_change)}
                    </div>
                  </div>
                  <div>
                    <div className="text-slate-400">SPX</div>
                    <div className="font-medium text-slate-700">
                      {signedPercent(component.diagnostics.spx_change)}
                    </div>
                  </div>
                  <div>
                    <div className="text-slate-400">Breadth gap</div>
                    <div
                      className={
                        (component.diagnostics.leadership_gap ?? 0) < -0.5
                          ? "font-medium text-red-700"
                          : "font-medium text-slate-700"
                      }
                    >
                      {signedPercent(component.diagnostics.leadership_gap)}
                    </div>
                  </div>
                  <div>
                    <div className="text-slate-400">Above SMA50</div>
                    <div className="font-medium text-slate-700">
                      {component.diagnostics.percentage_above_sma50 === null ||
                      component.diagnostics.percentage_above_sma50 === undefined
                        ? "Unavailable"
                        : `${component.diagnostics.percentage_above_sma50.toFixed(1)}%`}
                    </div>
                  </div>
                  <div>
                    <div className="text-slate-400">Above SMA200</div>
                    <div className="font-medium text-slate-700">
                      {component.diagnostics.percentage_above_sma200 === null ||
                      component.diagnostics.percentage_above_sma200 === undefined
                        ? "Unavailable"
                        : `${component.diagnostics.percentage_above_sma200.toFixed(1)}%`}
                    </div>
                  </div>
                  {component.diagnostics.advancers !== null &&
                  component.diagnostics.advancers !== undefined &&
                  component.diagnostics.decliners !== null &&
                  component.diagnostics.decliners !== undefined ? (
                    <div className="col-span-2 text-slate-500 sm:col-span-3">
                      {component.diagnostics.advancers} advancers / {component.diagnostics.decliners} decliners
                      {component.diagnostics.trend_as_of
                        ? ` | SMA participation as of ${component.diagnostics.trend_as_of}`
                        : ""}
                    </div>
                  ) : null}
                </div>
              ) : null}
            </div>
          ))}
        </div>

        {available.length === 0 ? (
          <p className="mt-4 text-sm text-red-600">No regime data was available for the requested date.</p>
        ) : null}
      </CardContent>
    </Card>
  );
}

function OpportunityDetails({ item }: { item: Opportunity }) {
  return (
    <div className="grid gap-5 border-t border-slate-100 bg-slate-50/70 p-5 lg:grid-cols-2">
      <div>
        <h4 className="text-sm font-semibold text-slate-900">Evidence</h4>
        <div className="mt-3 space-y-3">
          {item.evidence.map((evidence, index) => (
            <div key={`${evidence.source}-${index}`} className="rounded-lg border border-slate-200 bg-white p-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <Badge>{evidence.source}</Badge>
                  <Badge variant={badgeVariant(evidence.direction)}>{evidence.direction}</Badge>
                </div>
                <span className="text-xs text-slate-500">
                  Strength {evidence.strength.toFixed(0)} · {evidence.observed_at || "Unknown date"}
                </span>
              </div>
              <ul className="mt-2 space-y-1 text-xs text-slate-600">
                {evidence.reasons.map((reason) => <li key={reason}>+ {reason}</li>)}
                {evidence.risks.map((risk) => <li key={risk} className="text-amber-700">Risk: {risk}</li>)}
              </ul>
            </div>
          ))}
        </div>
      </div>

      <div>
        <h4 className="text-sm font-semibold text-slate-900">Options Strategy Fit</h4>
        {item.market !== "US" ? (
          <div className="mt-3 rounded-lg border border-slate-200 bg-white p-4 text-sm text-slate-600">
            Options strategy selection is currently limited to US-listed options.
          </div>
        ) : item.option_strategies.length === 0 ? (
          <div className="mt-3 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
            No suitable strategy passed the initial rules.
          </div>
        ) : (
          <div className="mt-3 space-y-3">
            {item.option_strategies.map((strategy, index) => (
              <div key={strategy.strategy} className="rounded-lg border border-slate-200 bg-white p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-xs font-medium uppercase tracking-wide text-slate-400">
                      {index === 0 ? "Primary" : `Alternative ${index}`}
                    </div>
                    <div className="mt-0.5 font-semibold text-slate-900">{formatStrategy(strategy.strategy)}</div>
                  </div>
                  <div className="text-lg font-semibold text-indigo-700">{strategy.suitability_score.toFixed(0)}</div>
                </div>
                <p className="mt-2 text-xs text-slate-600">{strategy.summary}</p>
                <div className="mt-3 text-xs text-slate-600">
                  {strategy.reasons.slice(0, 2).map((reason) => <div key={reason}>+ {reason}</div>)}
                  {strategy.risks.slice(0, 2).map((risk) => <div key={risk} className="text-amber-700">Risk: {risk}</div>)}
                </div>
              </div>
            ))}
            <p className="text-[11px] text-slate-500">
              Strategy-level guidance only. Exact expiry, strikes, payoff and liquidity require option-chain validation.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export default function MarketCommandCenter({ market }: { market: Market }) {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [selectedDate, setSelectedDate] = useState(localIsoDate);
  const [data, setData] = useState<SummaryResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [expanded, setExpanded] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const response = await authenticatedFetch(
        `${baseUrl}/api/market-command/summary?observation_date=${encodeURIComponent(selectedDate)}&limit=30&market=${market}`,
        { cache: "no-store" },
      );
      if (!response.ok) {
        let message = `HTTP ${response.status}`;
        try {
          const body = await response.json();
          message = body?.detail || message;
        } catch {
          // Retain HTTP fallback.
        }
        throw new Error(message);
      }
      setData(await response.json());
    } catch (exc) {
      setError(exc instanceof Error ? exc.message : "Failed to load market command data");
    } finally {
      setLoading(false);
    }
  }, [baseUrl, market, selectedDate]);

  useEffect(() => {
    load();
  }, [load]);

  const opportunities = useMemo(() => data?.opportunities?.[market] || [], [data, market]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={`${market} Market Command Center`}
        subtitle={
          market === "US"
            ? "US regime, breadth, sentiment, SPX outlook and options-aware opportunity ranking."
            : "ASX regime and cross-source opportunity ranking."
        }
        actions={
          <div className="flex items-center gap-2">
            <input
              type="date"
              value={selectedDate}
              onChange={(event) => setSelectedDate(event.target.value)}
              className="h-10 rounded-md border border-slate-300 bg-white px-3 text-sm"
            />
            <Button onClick={load} disabled={loading}>{loading ? "Refreshing..." : "Refresh"}</Button>
          </div>
        }
      />

      {error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          Failed to load command center: {error}
        </div>
      ) : null}

      {data?.regimes?.[market] ? (
        <RegimeCard regime={data.regimes[market] as Regime} />
      ) : (
        <Card className="h-80 animate-pulse bg-slate-50" />
      )}

      {market === "US" && data?.market_intelligence ? (
        <MarketIntelligenceCard insight={data.market_intelligence} />
      ) : null}
      {market === "US" && data?.sentiment ? <SentimentCard sentiment={data.sentiment} /> : null}
      {market === "US" && data?.fear_greed ? <FearGreedCard fearGreed={data.fear_greed} /> : null}

      <Card>
        <CardHeader className="pb-3">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <CardTitle className="text-lg">Top Opportunities</CardTitle>
              <p className="mt-1 text-sm text-slate-500">
                Ranked from independent scanner, signal and research evidence. Click a row for details.
              </p>
            </div>
            <Badge>{market}</Badge>
          </div>
        </CardHeader>

        <CardContent className="px-0 pb-0">
          {loading && !data ? (
            <div className="p-8 text-center text-sm text-slate-500">Loading opportunities...</div>
          ) : opportunities.length === 0 ? (
            <div className="p-8 text-center text-sm text-slate-500">
              No opportunity evidence was available on or before {selectedDate}.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full text-sm">
                <thead className="border-y border-slate-200 bg-slate-50 text-left text-[11px] uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-5 py-3">Rank</th>
                    <th className="px-3 py-3">Symbol</th>
                    <th className="px-3 py-3">Score</th>
                    <th className="px-3 py-3">Direction</th>
                    <th className="px-3 py-3">Horizon</th>
                    <th className="px-3 py-3">Sources</th>
                    <th className="px-3 py-3">Regime Fit</th>
                    <th className="px-3 py-3">Options</th>
                    <th className="px-5 py-3" />
                  </tr>
                </thead>
                <tbody>
                  {opportunities.map((item, index) => {
                    const key = `${item.market}-${item.symbol}`;
                    const isExpanded = expanded === key;
                    const primaryStrategy = item.option_strategies[0];
                    return (
                      <Fragment key={key}>
                        <tr
                          className="cursor-pointer border-b border-slate-100 hover:bg-indigo-50/40"
                          onClick={() => setExpanded(isExpanded ? null : key)}
                        >
                          <td className="px-5 py-3 text-slate-500">{index + 1}</td>
                          <td className="px-3 py-3 font-semibold text-slate-900">
                            <Link
                              href={`/integrated-charts?symbol=${encodeURIComponent(item.symbol)}&market=${item.market}`}
                              onClick={(event) => event.stopPropagation()}
                              className="hover:text-indigo-700 hover:underline"
                            >
                              {item.symbol}
                            </Link>
                          </td>
                          <td className={`px-3 py-3 text-lg font-semibold ${scoreTone(item.score)}`}>
                            {item.score.toFixed(0)}
                          </td>
                          <td className="px-3 py-3"><Badge variant={badgeVariant(item.direction)}>{item.direction}</Badge></td>
                          <td className="px-3 py-3 text-slate-600">{item.horizon}</td>
                          <td className="px-3 py-3">
                            <div className="flex max-w-xs flex-wrap gap-1">
                              {item.sources.slice(0, 4).map((source) => <Badge key={source}>{source}</Badge>)}
                            </div>
                          </td>
                          <td className="px-3 py-3"><Badge variant={badgeVariant(item.regime_fit)}>{item.regime_fit}</Badge></td>
                          <td className="px-3 py-3 text-xs text-slate-700">
                            {primaryStrategy ? formatStrategy(primaryStrategy.strategy) : item.market === "US" ? "No fit" : "US only"}
                          </td>
                          <td className="px-5 py-3 text-right text-slate-400">{isExpanded ? "Hide" : "Details"}</td>
                        </tr>
                        {isExpanded ? (
                          <tr>
                            <td colSpan={9} className="p-0"><OpportunityDetails item={item} /></td>
                          </tr>
                        ) : null}
                      </Fragment>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-xs text-amber-900">
        Scores are decision support, not automatic trade instructions. Options suggestions require current chain,
        event, liquidity, buying-power and payoff validation before order placement.
      </div>
    </div>
  );
}
