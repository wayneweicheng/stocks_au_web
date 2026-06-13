"use client";

import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import PageHeader from "./components/PageHeader";
import Badge from "./components/ui/Badge";
import Button from "./components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "./components/ui/Card";
import { authenticatedFetch } from "./utils/authenticatedFetch";

type Market = "ASX" | "US";

interface RegimeComponent {
  name: string;
  score: number | null;
  available: boolean;
  detail: string;
  source: string;
  as_of: string | null;
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
  regimes: Record<Market, Regime>;
  opportunities: Record<Market, Opportunity[]>;
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

export default function Home() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [selectedDate, setSelectedDate] = useState(localIsoDate);
  const [market, setMarket] = useState<Market>("ASX");
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
        `${baseUrl}/api/market-command/summary?observation_date=${encodeURIComponent(selectedDate)}&limit=30`,
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
  }, [baseUrl, selectedDate]);

  useEffect(() => {
    load();
  }, [load]);

  const opportunities = useMemo(() => data?.opportunities?.[market] || [], [data, market]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Market Command Center"
        subtitle="Market regime, cross-source opportunity ranking, and regime-aware options strategy guidance."
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

      <div className="grid gap-5 lg:grid-cols-2">
        {data?.regimes?.ASX ? <RegimeCard regime={data.regimes.ASX} /> : <Card className="h-80 animate-pulse bg-slate-50" />}
        {data?.regimes?.US ? <RegimeCard regime={data.regimes.US} /> : <Card className="h-80 animate-pulse bg-slate-50" />}
      </div>

      <Card>
        <CardHeader className="pb-3">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <CardTitle className="text-lg">Top Opportunities</CardTitle>
              <p className="mt-1 text-sm text-slate-500">
                Ranked from independent scanner, signal and research evidence. Click a row for details.
              </p>
            </div>
            <div className="flex rounded-lg border border-slate-200 bg-slate-50 p-1">
              {(["ASX", "US"] as Market[]).map((value) => (
                <button
                  key={value}
                  onClick={() => {
                    setMarket(value);
                    setExpanded(null);
                  }}
                  className={`rounded-md px-4 py-2 text-sm font-medium ${
                    market === value ? "bg-white text-indigo-700 shadow-sm" : "text-slate-600"
                  }`}
                >
                  {value}
                </button>
              ))}
            </div>
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
