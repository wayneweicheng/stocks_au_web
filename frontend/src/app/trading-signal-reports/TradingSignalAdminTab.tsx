"use client";

import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

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

function hasSufficientModelBuilderHistory(signal: AdminSignalDefinition) {
  return signal.historical_performance.instances > 1;
}

function Stats({ stats, title }: { stats: AdminPerformanceStats; title: string }) {
  return (
    <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{title}</p>
      <div className="mt-2 grid grid-cols-2 gap-2 text-sm sm:grid-cols-3 lg:grid-cols-6">
        <div><span className="block text-xs text-slate-500">Instances</span><span className="font-semibold text-slate-900">{stats.instances}</span></div>
        <div><span className="block text-xs text-slate-500">Win rate</span><span className="font-semibold text-slate-900">{formatPct(stats.win_rate_pct)}</span></div>
        <div><span className="block text-xs text-slate-500">Profit factor</span><span className="font-semibold text-slate-900">{stats.profit_factor === null ? "—" : stats.profit_factor.toFixed(2)}</span></div>
        <div><span className="block text-xs text-slate-500">Wins / losses</span><span className="font-semibold text-slate-900">{stats.wins} / {stats.losses}</span></div>
        <div><span className="block text-xs text-slate-500">Avg profit</span><span className="font-semibold text-slate-900">{formatPct(stats.average_return_pct)}</span></div>
        <div><span className="block text-xs text-slate-500">Median profit</span><span className="font-semibold text-slate-900">{formatPct(stats.median_return_pct)}</span></div>
      </div>
      {stats.source === "MODEL_BUILDER_PACKET" ? <p className="mt-2 text-xs text-slate-600">Source: model-builder packet ({stats.source_reference || "historical-performance.json"}).</p> : null}
      {stats.instances === 0 ? <p className="mt-2 text-xs text-amber-700">No finalized historical outcome instances are recorded yet.</p> : null}
    </div>
  );
}

function filterSignalsByHistoricalSupport(signals: AdminSignalDefinition[], enabled: boolean) {
  return enabled ? signals.filter(hasSufficientModelBuilderHistory) : signals;
}

function filterObservedSignalNames(signalNames: string[], signals: AdminSignalDefinition[], enabled: boolean) {
  if (!enabled) return signalNames;
  const supportedSignalCodes = new Set(filterSignalsByHistoricalSupport(signals, enabled).map((signal) => signal.signal_code.toUpperCase()));
  return signalNames.filter((signalName) => supportedSignalCodes.has(signalName.toUpperCase()));
}

function signalDefinitionId(stockCode: string, signalCode: string) {
  return `strategy-signal-${stockCode}-${signalCode}`.replace(/[^a-zA-Z0-9_-]/g, "-");
}

function SignalDefinitions({
  signals,
  filtered,
  stockCode,
  highlightedSignalCode,
}: {
  signals: AdminSignalDefinition[];
  filtered: boolean;
  stockCode: string;
  highlightedSignalCode: string;
}) {
  if (!signals.length) return filtered ? <p className="rounded-md border border-amber-200 bg-amber-50 p-3 text-xs text-amber-800">No signals meet the current filter. Turn off the historical-support filter to show all signal definitions.</p> : null;
  return (
    <div className="space-y-2">
      <h3 className="text-sm font-semibold text-slate-900">Signal definitions</h3>
      <div className="grid gap-3 lg:grid-cols-2">
        {signals.map((signal) => {
          const highlighted = signal.signal_code.toUpperCase() === highlightedSignalCode;
          return <div
            key={signal.signal_code}
            id={signalDefinitionId(stockCode, signal.signal_code)}
            className={`rounded-md border p-3 text-sm ${highlighted ? "border-indigo-400 bg-indigo-50 ring-2 ring-indigo-200" : "border-slate-200"}`}
          >
          <div className="flex flex-wrap items-center gap-2"><span className="font-semibold text-slate-900">{signal.display_name}</span><span className="rounded bg-indigo-50 px-2 py-0.5 text-xs text-indigo-700">{signal.direction}</span><span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">{signal.action}</span></div>
          <p className="mt-2 text-xs text-slate-500">Code: {signal.signal_code} · Confidence: {signal.confidence}{signal.confidence_score === null ? "" : ` (score ${signal.confidence_score.toFixed(2)})`} · Notification: {signal.notification_level}</p>
          <p className="mt-2"><span className="font-medium">Definition:</span> {signal.strategy_definition}</p>
          <p className="mt-1"><span className="font-medium">Trigger:</span> {signal.trigger_condition}</p>
          <p className="mt-1"><span className="font-medium">Entry:</span> {signal.entry_policy}</p>
          <p className="mt-1"><span className="font-medium">Holding:</span> {signal.holding_period}</p>
          <p className="mt-1"><span className="font-medium">Exit:</span> {signal.exit_conditions.map((exit) => exit.horizon ? `${exit.description} (${exit.horizon})` : exit.description).join("; ")}</p>
          <p className="mt-2 text-xs text-slate-600">Model-builder historical: {signal.historical_performance.instances} instances · win rate {formatPct(signal.historical_performance.win_rate_pct)} · profit factor {signal.historical_performance.profit_factor === null ? "—" : signal.historical_performance.profit_factor.toFixed(2)} · avg profit {formatPct(signal.historical_performance.average_return_pct)} · median profit {formatPct(signal.historical_performance.median_return_pct)} · {signal.historical_performance.status}</p>
          </div>;
        })}
      </div>
    </div>
  );
}

function HistoricalTradeDetails({ trades }: { trades: AdminHistoricalTrade[] }) {
  const groups = useMemo(() => {
    const sorted = [...trades].sort((left, right) =>
      left.signal_code.localeCompare(right.signal_code)
      || (left.entry_date || left.market_date).localeCompare(right.entry_date || right.market_date)
      || (left.exit_date || "").localeCompare(right.exit_date || "")
      || left.market_date.localeCompare(right.market_date),
    );
    const grouped = new Map<string, { key: string; signalCode: string; entryDate: string; exitDate: string; trades: AdminHistoricalTrade[] }>();
    sorted.forEach((trade) => {
      const key = trade.deduplication_group_id || `${trade.signal_code}|${trade.entry_date || trade.market_date}|${trade.exit_date || trade.entry_date || trade.market_date}`;
      const existing = grouped.get(key);
      if (existing) {
        existing.trades.push(trade);
      } else {
        grouped.set(key, {
          key,
          signalCode: trade.signal_code,
          entryDate: trade.entry_date || trade.market_date,
          exitDate: trade.exit_date || trade.entry_date || trade.market_date,
          trades: [trade],
        });
      }
    });
    return Array.from(grouped.values()).sort((left, right) =>
      left.signalCode.localeCompare(right.signalCode) || left.entryDate.localeCompare(right.entryDate) || left.exitDate.localeCompare(right.exitDate),
    );
  }, [trades]);

  return (
    <details className="rounded-md border border-slate-200">
      <summary className="cursor-pointer list-none p-3 text-sm font-semibold text-slate-900">
        Model-builder historical trade detail ({trades.length} trades · {groups.length} overlap groups)
      </summary>
      <div className="border-t border-slate-200 p-3">
        {trades.length ? <div className="overflow-x-auto">
          <table className="min-w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr><th className="px-2 py-2">Date</th><th className="px-2 py-2">Signal</th><th className="px-2 py-2">Direction</th><th className="px-2 py-2">Entry</th><th className="px-2 py-2">Exit</th><th className="px-2 py-2">Return</th><th className="px-2 py-2">MFE / MAE</th><th className="px-2 py-2">Bars</th><th className="px-2 py-2">Exit reason</th><th className="px-2 py-2">Features</th></tr>
            </thead>
            <tbody>{groups.map((group, groupIndex) => <Fragment key={group.key}>
              <tr className={groupIndex % 2 === 0 ? "bg-indigo-50" : "bg-amber-50"}>
                <td colSpan={10} className="border-y border-slate-200 px-2 py-2 font-semibold text-slate-700">
                  Group {groupIndex + 1} · {group.signalCode} · {group.entryDate} → {group.exitDate} · {group.trades.length} trade{group.trades.length === 1 ? "" : "s"}
                </td>
              </tr>
              {group.trades.map((trade, index) => <tr key={`${group.key}-${trade.market_date}-${index}`} className={`${groupIndex % 2 === 0 ? "bg-indigo-50/40" : "bg-amber-50/40"} border-b border-slate-100 last:border-0`}>
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
              </tr>)}
            </Fragment>)}</tbody>
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
          {deployment.evaluation_schedule ? <p className="mt-1 text-xs font-medium text-indigo-700">Evaluation: {deployment.evaluation_schedule.local_time || "—"} {deployment.evaluation_schedule.timezone_name || ""} · every {deployment.evaluation_schedule.interval_minutes ?? (deployment.evaluation_schedule.cadence_seconds ? Math.round(deployment.evaluation_schedule.cadence_seconds / 60) : "—")} minutes{deployment.evaluation_schedule.window_end ? ` until ${deployment.evaluation_schedule.window_end}` : ""}</p> : null}
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
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const requestedStock = (searchParams.get("stock_code") || searchParams.get("stock") || "").trim().toUpperCase();
  const requestedSignalCode = (searchParams.get("signal_code") || searchParams.get("signal") || "").trim().toUpperCase();
  const [data, setData] = useState<AdminStrategyPage | null>(null);
  const [selectedStock, setSelectedStock] = useState(() => requestedStock || "SPX");
  const [productionOnlyFilterEnabled, setProductionOnlyFilterEnabled] = useState(true);
  const [historicalSignalFilterEnabled, setHistoricalSignalFilterEnabled] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const query = new URLSearchParams();
      if (requestedStock) query.set("stock_code", requestedStock);
      if (requestedSignalCode) query.set("signal_code", requestedSignalCode);
      const queryString = query.toString();
      const response = await authenticatedFetch(`${baseUrl}/api/trading-signal-reports/admin/strategies${queryString ? `?${queryString}` : ""}`);
      const payload = (await response.json().catch(() => ({}))) as AdminStrategyPage & { detail?: string };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      setData(payload);
    } catch (caught: unknown) {
      setError(caught instanceof Error ? caught.message : "Unable to load strategy administration data");
    } finally {
      setLoading(false);
    }
  }, [baseUrl, requestedSignalCode, requestedStock]);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    if (!data?.stocks.length) return;
    setSelectedStock((current) => {
      if (data.stocks.some((stock) => stock.stock_code === current)) return current;
      const deepLinkedStock = requestedStock && data.stocks.some((stock) => stock.stock_code === requestedStock) ? requestedStock : "";
      return deepLinkedStock || (data.stocks.some((stock) => stock.stock_code === "SPX") ? "SPX" : data.stocks[0].stock_code);
    });
  }, [data, requestedStock]);

  const selectStock = (stockCode: string) => {
    const normalized = stockCode.trim().toUpperCase();
    setSelectedStock(normalized);
    const nextParams = new URLSearchParams(searchParams.toString());
    nextParams.set("tab", "admin");
    nextParams.set("stock_code", normalized);
    nextParams.delete("stock");
    router.replace(`${pathname}?${nextParams.toString()}`, { scroll: false });
  };

  const updateDeployment = (updated: AdminDeployment) => {
    setData((current) => current ? { ...current, stocks: current.stocks.map((stock) => ({ ...stock, strategies: stock.strategies.map((strategy) => ({ ...strategy, deployments: strategy.deployments.map((deployment) => deployment.strategy_deployment_id === updated.strategy_deployment_id ? { ...deployment, is_enabled: updated.is_enabled, notification_enabled: updated.notification_enabled, execution_enabled: false, notification_only: true } : deployment) })) })) } : current);
  };

  const visibleStock = data?.stocks.find((stock) => stock.stock_code === selectedStock) || data?.stocks[0];
  const visibleStrategies = (visibleStock?.strategies || []).filter((strategy) => (
    !productionOnlyFilterEnabled || strategy.deployments.some((deployment) => deployment.is_production && deployment.is_enabled)
  ));
  const visibleProductionDeployments = visibleStrategies.flatMap((strategy) => strategy.deployments).filter((deployment) => deployment.is_production);

  useEffect(() => {
    if (!requestedSignalCode || !visibleStock) return;
    document.getElementById(signalDefinitionId(visibleStock.stock_code, requestedSignalCode))?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [requestedSignalCode, visibleStock]);

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
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs uppercase tracking-wide text-slate-500">Visible strategy versions</p><p className="mt-1 text-2xl font-semibold text-slate-900">{visibleStrategies.length}</p></div>
        <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs uppercase tracking-wide text-slate-500">Enabled production</p><p className="mt-1 text-2xl font-semibold text-slate-900">{visibleProductionDeployments.filter((deployment) => deployment.is_enabled).length} / {visibleProductionDeployments.length}</p></div>
      </div>
      <section className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
        <div className="mb-3 flex flex-wrap justify-end gap-x-6 gap-y-3">
          <label className="flex items-center gap-2 text-xs text-slate-700">
            <button
              type="button"
              role="switch"
              aria-checked={productionOnlyFilterEnabled}
              onClick={() => setProductionOnlyFilterEnabled((enabled) => !enabled)}
              className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition ${productionOnlyFilterEnabled ? "bg-indigo-600" : "bg-slate-300"}`}
            >
              <span className={`inline-block h-4 w-4 rounded-full bg-white transition-transform ${productionOnlyFilterEnabled ? "translate-x-6" : "translate-x-1"}`} />
            </button>
            <span>Only show strategies turned on in production</span>
          </label>
          <label className="flex items-center gap-2 text-xs text-slate-700">
            <button
              type="button"
              role="switch"
              aria-checked={historicalSignalFilterEnabled}
              onClick={() => setHistoricalSignalFilterEnabled((enabled) => !enabled)}
              className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition ${historicalSignalFilterEnabled ? "bg-indigo-600" : "bg-slate-300"}`}
            >
              <span className={`inline-block h-4 w-4 rounded-full bg-white transition-transform ${historicalSignalFilterEnabled ? "translate-x-6" : "translate-x-1"}`} />
            </button>
            <span>Only show signals with more than 1 model-builder historical instance</span>
          </label>
        </div>
        <div className="mb-3 flex items-center justify-between"><div><h2 className="text-sm font-semibold text-slate-900">Filter by stock</h2><p className="mt-1 text-xs text-slate-500">Select one stock. Choosing another stock replaces the current selection.</p></div><span className="text-xs text-slate-500">Selected: {visibleStock?.stock_code || "—"}</span></div>
        <div className="grid gap-3 sm:grid-cols-3" role="radiogroup" aria-label="Filter strategies by stock">
          {data.stocks.map((stock) => {
            const selected = stock.stock_code === selectedStock;
            const productionStrategyCount = stock.strategies.filter((strategy) => strategy.deployments.some((deployment) => deployment.is_production && deployment.is_enabled)).length;
            const displayedStrategyCount = productionOnlyFilterEnabled ? productionStrategyCount : stock.strategies.length;
            return <button key={stock.stock_code} type="button" role="radio" aria-checked={selected} onClick={() => selectStock(stock.stock_code)} className={`rounded-lg border p-4 text-left transition ${selected ? "border-indigo-500 bg-indigo-50 ring-2 ring-indigo-200" : "border-slate-200 bg-white hover:border-indigo-300 hover:bg-slate-50"}`}>
              <div className="flex items-center justify-between"><span className="font-semibold text-slate-900">{stock.stock_code}</span><span className={`rounded px-2 py-1 text-xs ${selected ? "bg-indigo-600 text-white" : "bg-slate-100 text-slate-600"}`}>{selected ? "Selected" : "Select"}</span></div>
              <p className="mt-2 text-xs text-slate-500">{displayedStrategyCount} {productionOnlyFilterEnabled ? "turned-on production " : ""}strategy version{displayedStrategyCount === 1 ? "" : "s"}</p>
            </button>;
          })}
        </div>
      </section>
      {visibleStock ? (
        <section key={visibleStock.stock_code} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="mb-3 flex items-center justify-between"><h2 className="text-xl font-semibold text-slate-900">{visibleStock.stock_code}</h2><span className="text-xs text-slate-500">{visibleStrategies.length} visible strategy version{visibleStrategies.length === 1 ? "" : "s"}</span></div>
          <div className="space-y-3">
            {visibleStrategies.length ? visibleStrategies.map((strategy) => (
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
                  <SignalDefinitions
                    signals={filterSignalsByHistoricalSupport(strategy.signals, historicalSignalFilterEnabled)}
                    filtered={historicalSignalFilterEnabled && strategy.signals.length > 0}
                    stockCode={visibleStock.stock_code}
                    highlightedSignalCode={requestedSignalCode}
                  />
                  <p className="text-xs text-slate-600">Observed signal names: {filterObservedSignalNames(strategy.signal_names, strategy.signals, historicalSignalFilterEnabled).length ? filterObservedSignalNames(strategy.signal_names, strategy.signals, historicalSignalFilterEnabled).join(", ") : "Not recorded"}</p>
                  <Stats title="Model-builder historical signal performance" stats={strategy.historical_stats} />
                  <HistoricalTradeDetails trades={strategy.historical_trades} />
                  {strategy.deployments.length ? <div><h3 className="mb-2 text-sm font-semibold text-slate-900">Deployments and production executions</h3><div className="space-y-3">{strategy.deployments.map((deployment) => <DeploymentControl key={deployment.strategy_deployment_id} deployment={deployment} onChanged={updateDeployment} />)}</div></div> : <p className="text-sm text-slate-500">No deployment is registered for this strategy version.</p>}
                  <details><summary className="cursor-pointer text-xs font-semibold text-slate-600">Configuration metadata</summary><pre className="mt-2 max-h-64 overflow-auto rounded-md bg-slate-900 p-3 text-xs text-slate-100">{JSON.stringify(strategy.configuration, null, 2)}</pre></details>
                </div>
              </details>
            )) : <p className="rounded-md border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">No strategies are currently turned on in production for this stock. Turn off the production filter to show all strategies.</p>}
          </div>
        </section>
      ) : null}
      <p className="text-xs text-slate-500">Data refreshed {formatDateTime(data.generated_utc)}. Historical and production performance use finalized 30-minute market outcomes; manual TradePlan prices are intentionally ignored.</p>
    </div>
  );
}
