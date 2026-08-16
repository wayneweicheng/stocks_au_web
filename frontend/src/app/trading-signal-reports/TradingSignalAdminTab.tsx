"use client";

import { useCallback, useEffect, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { AdminDeployment, AdminHistoricalTrade, AdminPerformanceStats, AdminSignalDefinition, AdminStrategyPage } from "../../lib/api/trading-signal-admin";

function formatDateTime(value: string | null | undefined) {
  if (!value) return "—";
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
}

function formatPct(value: number | null) {
  return value === null ? "—" : `${value.toFixed(2)}%`;
}

function formatPrice(value: number | null) {
  return value === null ? "—" : value.toFixed(2);
}

function Stats({ stats, title }: { stats: AdminPerformanceStats; title: string }) {
  return (
    <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{title}</p>
      <div className="mt-2 grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
        <div><span className="block text-xs text-slate-500">Instances</span><span className="font-semibold text-slate-900">{stats.instances}</span></div>
        <div><span className="block text-xs text-slate-500">Win rate</span><span className="font-semibold text-slate-900">{formatPct(stats.win_rate_pct)}</span></div>
        <div><span className="block text-xs text-slate-500">Profit factor</span><span className="font-semibold text-slate-900">{stats.profit_factor === null ? "—" : stats.profit_factor.toFixed(2)}</span></div>
        <div><span className="block text-xs text-slate-500">Wins / losses</span><span className="font-semibold text-slate-900">{stats.wins} / {stats.losses}</span></div>
      </div>
      {stats.source === "MODEL_BUILDER_PACKET" ? <p className="mt-2 text-xs text-slate-600">Source: model-builder packet ({stats.source_reference || "historical-performance.json"}).</p> : null}
      {stats.instances === 0 ? <p className="mt-2 text-xs text-amber-700">No finalized historical outcome instances are recorded yet.</p> : null}
    </div>
  );
}

function SignalDefinitions({ signals }: { signals: AdminSignalDefinition[] }) {
  if (!signals.length) return null;
  return (
    <div className="space-y-2">
      <h3 className="text-sm font-semibold text-slate-900">Signal definitions</h3>
      <div className="grid gap-3 lg:grid-cols-2">
        {signals.map((signal) => <div key={signal.signal_code} className="rounded-md border border-slate-200 p-3 text-sm">
          <div className="flex flex-wrap items-center gap-2"><span className="font-semibold text-slate-900">{signal.display_name}</span><span className="rounded bg-indigo-50 px-2 py-0.5 text-xs text-indigo-700">{signal.direction}</span><span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">{signal.action}</span></div>
          <p className="mt-2 text-xs text-slate-500">Code: {signal.signal_code} · Confidence: {signal.confidence} · Notification: {signal.notification_level}</p>
          <p className="mt-2"><span className="font-medium">Definition:</span> {signal.strategy_definition}</p>
          <p className="mt-1"><span className="font-medium">Trigger:</span> {signal.trigger_condition}</p>
          <p className="mt-1"><span className="font-medium">Entry:</span> {signal.entry_policy}</p>
          <p className="mt-1"><span className="font-medium">Holding:</span> {signal.holding_period}</p>
          <p className="mt-1"><span className="font-medium">Exit:</span> {signal.exit_conditions.map((exit) => exit.horizon ? `${exit.description} (${exit.horizon})` : exit.description).join("; ")}</p>
          <p className="mt-2 text-xs text-slate-600">Model-builder historical: {signal.historical_performance.instances} instances · win rate {formatPct(signal.historical_performance.win_rate_pct)} · profit factor {signal.historical_performance.profit_factor === null ? "—" : signal.historical_performance.profit_factor.toFixed(2)} · {signal.historical_performance.status}</p>
        </div>)}
      </div>
    </div>
  );
}

function HistoricalTradeDetails({ trades }: { trades: AdminHistoricalTrade[] }) {
  return (
    <details className="rounded-md border border-slate-200">
      <summary className="cursor-pointer list-none p-3 text-sm font-semibold text-slate-900">
        Model-builder historical trade detail ({trades.length})
      </summary>
      <div className="border-t border-slate-200 p-3">
        {trades.length ? <div className="overflow-x-auto">
          <table className="min-w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr><th className="px-2 py-2">Date</th><th className="px-2 py-2">Signal</th><th className="px-2 py-2">Direction</th><th className="px-2 py-2">Entry</th><th className="px-2 py-2">Exit</th><th className="px-2 py-2">Return</th><th className="px-2 py-2">MFE / MAE</th><th className="px-2 py-2">Bars</th><th className="px-2 py-2">Exit reason</th><th className="px-2 py-2">Features</th></tr>
            </thead>
            <tbody>{trades.map((trade, index) => <tr key={`${trade.signal_code}-${trade.market_date}-${index}`} className="border-b border-slate-100 last:border-0">
              <td className="whitespace-nowrap px-2 py-2">{trade.market_date}</td>
              <td className="whitespace-nowrap px-2 py-2">{trade.signal_code}</td>
              <td className="px-2 py-2">{trade.direction}</td>
              <td className="whitespace-nowrap px-2 py-2">{trade.entry_timestamp || "—"}<br />{formatPrice(trade.entry_price)}</td>
              <td className="whitespace-nowrap px-2 py-2">{trade.exit_timestamp || "—"}<br />{formatPrice(trade.exit_price)}</td>
              <td className={`whitespace-nowrap px-2 py-2 font-semibold ${(trade.return_pct || 0) >= 0 ? "text-emerald-700" : "text-red-700"}`}>{formatPct(trade.return_pct)}</td>
              <td className="whitespace-nowrap px-2 py-2">{formatPct(trade.mfe_pct)} / {formatPct(trade.mae_pct)}</td>
              <td className="px-2 py-2">{trade.bars_held ?? "—"}</td>
              <td className="px-2 py-2">{trade.exit_reason || "—"}</td>
              <td className="px-2 py-2"><details><summary className="cursor-pointer text-indigo-700">View</summary><pre className="mt-1 max-w-xs overflow-auto rounded bg-slate-900 p-2 text-[10px] text-slate-100">{JSON.stringify(trade.features, null, 2)}</pre></details></td>
            </tr>)}</tbody>
          </table>
        </div> : <p className="text-xs text-slate-500">No model-builder ledger records are available for this strategy version.</p>}
      </div>
    </details>
  );
}

function DeploymentControl({ deployment, onChanged }: { deployment: AdminDeployment; onChanged: (deployment: AdminDeployment) => void }) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const toggle = async () => {
    const nextValue = !deployment.is_enabled;
    if (!window.confirm(`${nextValue ? "Enable" : "Disable"} notifications for ${deployment.deployment_key}? Broker execution remains disabled.`)) return;
    setSaving(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${process.env.NEXT_PUBLIC_BACKEND_URL || ""}/api/trading-signal-reports/admin/deployments/${deployment.strategy_deployment_id}/production-toggle`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ enabled: nextValue }),
      });
      const payload = (await response.json().catch(() => ({}))) as Partial<AdminDeployment> & { detail?: string };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      onChanged({ ...deployment, ...payload, is_enabled: Boolean(payload.is_enabled), notification_enabled: Boolean(payload.notification_enabled), execution_enabled: false, notification_only: true } as AdminDeployment);
    } catch (caught: unknown) {
      setError(caught instanceof Error ? caught.message : "Unable to change production notification state");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="rounded-md border border-slate-200 p-3">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div>
          <p className="font-semibold text-slate-900">{deployment.deployment_key}</p>
          <p className="text-xs text-slate-500">{deployment.environment} · {deployment.notification_enabled ? "Notifications on" : "Notifications off"} · Execution hard-disabled</p>
        </div>
        {deployment.is_production ? <Button type="button" variant={deployment.is_enabled ? "secondary" : "primary"} onClick={() => void toggle()} disabled={saving}>
          {saving ? "Saving..." : deployment.is_enabled ? "Turn off production" : "Turn on production"}
        </Button> : <span className="rounded bg-slate-100 px-3 py-2 text-xs text-slate-600">Read-only non-production deployment</span>}
      </div>
      {error ? <p className="mt-2 text-xs text-red-700">{error}</p> : null}
      <div className="mt-3"><Stats title="Simulated production performance" stats={deployment.production_stats} /></div>
      {deployment.executions.length > 0 ? (
        <div className="mt-3 overflow-x-auto">
          <table className="min-w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500"><tr><th className="px-2 py-2">Signal</th><th className="px-2 py-2">Direction</th><th className="px-2 py-2">Plan</th><th className="px-2 py-2">Outcome</th><th className="px-2 py-2">Simulated entry / exit</th><th className="px-2 py-2">Market return</th></tr></thead>
            <tbody>{deployment.executions.map((execution) => <tr key={`${execution.signal_id}-${execution.outcome_horizon || "pending"}`} className="border-b border-slate-100 last:border-0"><td className="px-2 py-2">{execution.classification || `#${execution.signal_id}`}</td><td className="px-2 py-2">{execution.direction || "—"}</td><td className="px-2 py-2">{execution.trade_plan_id === null ? "—" : `#${execution.trade_plan_id}`}</td><td className="px-2 py-2">{execution.outcome_status}{execution.outcome_horizon ? ` (${execution.outcome_horizon})` : ""}</td><td className="px-2 py-2">{execution.calculated_entry_price ?? "—"} / {execution.calculated_exit_price ?? "—"}</td><td className="px-2 py-2 font-semibold">{formatPct(execution.actual_return_pct)}{execution.outcome_status !== "FINALIZED" ? " (waiting for market data)" : ""}</td></tr>)}</tbody>
          </table>
        </div>
      ) : <p className="mt-3 text-xs text-slate-500">No production signals are recorded for this deployment.</p>}
    </div>
  );
}

export default function TradingSignalAdminTab({ baseUrl }: { baseUrl: string }) {
  const [data, setData] = useState<AdminStrategyPage | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/trading-signal-reports/admin/strategies`);
      const payload = (await response.json().catch(() => ({}))) as AdminStrategyPage & { detail?: string };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      setData(payload);
    } catch (caught: unknown) {
      setError(caught instanceof Error ? caught.message : "Unable to load strategy administration data");
    } finally {
      setLoading(false);
    }
  }, [baseUrl]);

  useEffect(() => { void load(); }, [load]);

  const updateDeployment = (updated: AdminDeployment) => {
    setData((current) => current ? { ...current, stocks: current.stocks.map((stock) => ({ ...stock, strategies: stock.strategies.map((strategy) => ({ ...strategy, deployments: strategy.deployments.map((deployment) => deployment.strategy_deployment_id === updated.strategy_deployment_id ? { ...deployment, is_enabled: updated.is_enabled, notification_enabled: updated.notification_enabled, execution_enabled: false, notification_only: true } : deployment) })) })) } : current);
  };

  if (loading && !data) return <div className="rounded-lg border border-slate-200 bg-white p-8 text-center text-sm text-slate-500">Loading strategy administration...</div>;
  if (error && !data) return <Alert variant="danger">{error}</Alert>;
  if (!data) return null;

  return (
    <div className="space-y-4">
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div className="flex justify-end"><Button type="button" variant="secondary" onClick={() => void load()} disabled={loading}>{loading ? "Refreshing..." : "Refresh strategy data"}</Button></div>
      <section className="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
        <p className="font-semibold">Notification-only production controls</p>
        <p className="mt-1">These switches control strategy discovery and notifications. Broker execution is permanently hard-disabled in this view; trades are placed and recorded manually by a human.</p>
      </section>
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs uppercase tracking-wide text-slate-500">Stocks</p><p className="mt-1 text-2xl font-semibold text-slate-900">{data.stocks.length}</p></div>
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs uppercase tracking-wide text-slate-500">Strategy versions</p><p className="mt-1 text-2xl font-semibold text-slate-900">{data.strategy_count}</p></div>
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs uppercase tracking-wide text-slate-500">Enabled production</p><p className="mt-1 text-2xl font-semibold text-slate-900">{data.enabled_production_deployment_count} / {data.production_deployment_count}</p></div>
      </div>
      {data.stocks.map((stock) => (
        <section key={stock.stock_code} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-3 flex items-center justify-between"><h2 className="text-xl font-semibold text-slate-900">{stock.stock_code}</h2><span className="text-xs text-slate-500">{stock.strategies.length} strategy version{stock.strategies.length === 1 ? "" : "s"}</span></div>
          <div className="space-y-3">
            {stock.strategies.map((strategy) => (
              <details key={strategy.strategy_version_id} className="rounded-md border border-slate-200" open>
                <summary className="cursor-pointer list-none p-4">
                  <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                    <div><p className="font-semibold text-slate-900">{strategy.display_name} - {strategy.version_code}</p><p className="text-xs text-slate-500">{strategy.strategy_code} - {strategy.status} - {strategy.implementation_key || "Implementation key not recorded"}</p></div>
                    <div className="flex flex-wrap gap-2 text-xs"><span className="rounded bg-indigo-50 px-2 py-1 text-indigo-700">{strategy.directions.join(" / ")}</span><span className="rounded bg-slate-100 px-2 py-1 text-slate-700">Created {formatDateTime(strategy.created_utc)}</span></div>
                  </div>
                </summary>
                <div className="space-y-4 border-t border-slate-200 p-4">
                  <div className="grid gap-3 lg:grid-cols-3">
                    <div><p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Strategy definition</p><p className="mt-1 text-sm text-slate-800">{strategy.strategy_definition || "Not recorded in strategy metadata"}</p></div>
                    <div><p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Trigger condition</p>{strategy.trigger_conditions.length ? <ul className="mt-1 list-disc pl-5 text-sm text-slate-800">{strategy.trigger_conditions.map((item) => <li key={item}>{item}</li>)}</ul> : <p className="mt-1 text-sm text-slate-500">Not recorded in strategy metadata</p>}</div>
                    <div><p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Exit condition</p>{strategy.exit_conditions.length ? <ul className="mt-1 list-disc pl-5 text-sm text-slate-800">{strategy.exit_conditions.map((item) => <li key={item}>{item}</li>)}</ul> : <p className="mt-1 text-sm text-slate-500">Not recorded in strategy metadata</p>}</div>
                  </div>
                  <SignalDefinitions signals={strategy.signals} />
                  <p className="text-xs text-slate-600">Observed signal names: {strategy.signal_names.length ? strategy.signal_names.join(", ") : "Not recorded"}</p>
                  <Stats title="Model-builder historical signal performance" stats={strategy.historical_stats} />
                  <HistoricalTradeDetails trades={strategy.historical_trades} />
                  {strategy.deployments.length ? <div><h3 className="mb-2 text-sm font-semibold text-slate-900">Deployments and production executions</h3><div className="space-y-3">{strategy.deployments.map((deployment) => <DeploymentControl key={deployment.strategy_deployment_id} deployment={deployment} onChanged={updateDeployment} />)}</div></div> : <p className="text-sm text-slate-500">No deployment is registered for this strategy version.</p>}
                  <details><summary className="cursor-pointer text-xs font-semibold text-slate-600">Configuration metadata</summary><pre className="mt-2 max-h-64 overflow-auto rounded-md bg-slate-900 p-3 text-xs text-slate-100">{JSON.stringify(strategy.configuration, null, 2)}</pre></details>
                </div>
              </details>
            ))}
          </div>
        </section>
      ))}
      <p className="text-xs text-slate-500">Data refreshed {formatDateTime(data.generated_utc)}. Historical and production performance use finalized 30-minute market outcomes; manual TradePlan prices are intentionally ignored.</p>
    </div>
  );
}
