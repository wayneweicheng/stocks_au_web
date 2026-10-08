"use client";

import { FormEvent, useEffect, useState } from "react";
import Button from "../../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/Card";
import Input from "../../components/ui/Input";
import PageHeader from "../../components/PageHeader";
import { authenticatedFetch } from "../../utils/authenticatedFetch";

type Row = Record<string, any>;

export default function VolatilityManualMonitorPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [positions, setPositions] = useState<Row[]>([]);
  const [alerts, setAlerts] = useState<Row[]>([]);
  const [risk, setRisk] = useState<Row>({});
  const [safety, setSafety] = useState<Row>({ KillSwitchActive: false });
  const [schedule, setSchedule] = useState<Row>({
    Enabled: false,
    Symbols: "SPY,QQQ,IWM",
    EventClearSymbols: "SPY,QQQ,IWM",
    AccountEquity: 100000,
    AssignmentExposure: 0,
    TopN: 10,
    DteMin: 30,
    DteMax: 55,
    MinimumVolatilityEdge: 0.02,
    RiskBudgetPct: 0.02,
    MaxAssignmentExposurePct: 0.75,
    Timezone: "America/New_York",
  });
  const [form, setForm] = useState({ symbol: "QQQ", strategy: "short_put", short_option: "", expiration: "", short_strike: "", long_option: "", long_strike: "", quantity: "1", entry_credit: "", entry_spot: "" });
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);

  async function request(path: string, init?: RequestInit) {
    const response = await authenticatedFetch(`${baseUrl}${path}`, { cache: "no-store", ...init });
    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      throw new Error(body?.detail || `HTTP ${response.status}`);
    }
    return response.json();
  }

  async function refresh() {
    setLoading(true);
    try {
      const [positionData, alertData, scheduleData, riskData, safetyData] = await Promise.all([
        request("/api/volatility-options/positions"),
        request("/api/volatility-options/alerts"),
        request("/api/volatility-options/schedule"),
        request("/api/volatility-options/risk"),
        request("/api/volatility-options/safety"),
      ]);
      setPositions(positionData.items || []);
      setAlerts(alertData.items || []);
      setRisk(riskData || {});
      setSafety(safetyData || {});
      if (scheduleData.AccountEquity !== null) setSchedule(scheduleData);
      setStatus("");
    } catch (error: any) {
      setStatus(error?.message || String(error));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { refresh(); }, []);

  async function addPosition(event: FormEvent) {
    event.preventDefault();
    try {
      await request("/api/volatility-options/positions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...form,
          short_strike: Number(form.short_strike),
          long_strike: form.long_strike ? Number(form.long_strike) : undefined,
          quantity: Number(form.quantity),
          entry_credit: Number(form.entry_credit),
          entry_spot: form.entry_spot ? Number(form.entry_spot) : undefined,
          long_option: form.long_option || undefined,
        }),
      });
      setStatus("Manual position recorded. No broker order was submitted.");
      await refresh();
    } catch (error: any) { setStatus(error?.message || String(error)); }
  }

  async function monitor() {
    try {
      const result = await request("/api/volatility-options/monitor", { method: "POST" });
      setStatus(`Monitored ${result.count || 0} positions; ${result.failed_count || 0} failed.`);
      await refresh();
    } catch (error: any) { setStatus(error?.message || String(error)); }
  }

  async function toggleKillSwitch() {
    try {
      const active = !Boolean(safety.KillSwitchActive);
      const result = await request("/api/volatility-options/safety/kill-switch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ active, reason: active ? "Operator activated manual safety kill switch" : "Operator cleared manual safety kill switch" }),
      });
      setSafety(result);
      setStatus(active ? "Kill switch activated. Scheduled scans will stop." : "Kill switch cleared.");
    } catch (error: any) { setStatus(error?.message || String(error)); }
  }

  async function saveSchedule(event: FormEvent) {
    event.preventDefault();
    try {
      await request("/api/volatility-options/schedule", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          enabled: Boolean(schedule.Enabled),
          symbols: schedule.Symbols,
          event_clear_symbols: schedule.EventClearSymbols || "",
          account_equity: Number(schedule.AccountEquity),
          assignment_exposure: Number(schedule.AssignmentExposure || 0),
          top_n: Number(schedule.TopN || 10),
          dte_min: Number(schedule.DteMin || 30),
          dte_max: Number(schedule.DteMax || 55),
          min_vol_edge: Number(schedule.MinimumVolatilityEdge || 0.02),
          risk_budget_pct: Number(schedule.RiskBudgetPct || 0.02),
          max_assignment_exposure_pct: Number(schedule.MaxAssignmentExposurePct || 0.75),
          timezone: schedule.Timezone || "America/New_York",
        }),
      });
      setStatus("Schedule saved. It performs scans and alerts only; it cannot trade.");
    } catch (error: any) { setStatus(error?.message || String(error)); }
  }

  return <div className="space-y-6">
    <PageHeader title="Volatility Manual Monitor" subtitle="Record manually entered positions, monitor deterministic exit recommendations, configure scheduled research scans, and review alerts. This page has no broker order capability." actions={<div className="flex gap-2"><Button onClick={toggleKillSwitch} className={safety.KillSwitchActive ? "bg-emerald-600" : "bg-red-600"}>{safety.KillSwitchActive ? "Clear Kill Switch" : "Activate Kill Switch"}</Button><Button onClick={monitor} disabled={loading}>Monitor Now</Button></div>} />
    {status ? <div className="rounded-md border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{status}</div> : null}
    <div className="grid gap-4 md:grid-cols-4"><Card><CardHeader><CardTitle>Open positions</CardTitle></CardHeader><CardContent><div className="text-2xl font-semibold">{risk.open_positions || 0}</div></CardContent></Card><Card><CardHeader><CardTitle>Assignment exposure</CardTitle></CardHeader><CardContent><div className="text-2xl font-semibold">${Number(risk.assignment_exposure || 0).toLocaleString()}</div></CardContent></Card><Card><CardHeader><CardTitle>Stress loss</CardTitle></CardHeader><CardContent><div className="text-2xl font-semibold">${Number(risk.aggregate_stress_loss || 0).toLocaleString()}</div></CardContent></Card><Card><CardHeader><CardTitle>Risk state</CardTitle></CardHeader><CardContent><div className={risk.breaches?.length ? "font-semibold text-red-700" : "font-semibold text-emerald-700"}>{risk.breaches?.length ? "Review required" : "Within limits"}</div></CardContent></Card></div>
    <Card><CardHeader><CardTitle>Open manual positions</CardTitle></CardHeader><CardContent><div className="overflow-x-auto"><table className="min-w-full divide-y divide-slate-200 text-sm"><thead><tr className="text-left text-xs uppercase text-slate-500"><th className="py-2 pr-4">Symbol</th><th className="py-2 pr-4">Strategy</th><th className="py-2 pr-4">Expiry</th><th className="py-2 pr-4">Entry credit</th><th className="py-2 pr-4">Current P/L</th><th className="py-2 pr-4">Recommendation</th></tr></thead><tbody className="divide-y divide-slate-100">{positions.map((row) => <tr key={row.PositionId}><td className="py-3 pr-4 font-medium">{row.Symbol}</td><td className="py-3 pr-4">{row.Strategy}</td><td className="py-3 pr-4">{String(row.Expiration).slice(0, 10)}</td><td className="py-3 pr-4">${Number(row.EntryCredit || 0).toFixed(2)}</td><td className={Number(row.UnrealizedPnL) >= 0 ? "py-3 pr-4 text-emerald-700" : "py-3 pr-4 text-red-700"}>{row.UnrealizedPnL == null ? "n/a" : `$${Number(row.UnrealizedPnL).toFixed(2)}`}</td><td className="py-3 pr-4 font-semibold">{row.ExitRecommendation || "Not monitored"}</td></tr>)}{!positions.length ? <tr><td colSpan={6} className="py-4 text-slate-500">No open manual positions.</td></tr> : null}</tbody></table></div></CardContent></Card>
    <div className="grid gap-6 xl:grid-cols-2">
      <Card><CardHeader><CardTitle>Record a manually entered position</CardTitle></CardHeader><CardContent><form onSubmit={addPosition} className="grid gap-3 sm:grid-cols-2">{(["symbol", "strategy", "short_option", "expiration", "short_strike", "long_option", "long_strike", "quantity", "entry_credit", "entry_spot"] as const).map((key) => <label key={key} className="text-xs font-medium text-slate-600">{key.replaceAll("_", " ")}<Input value={form[key]} onChange={(event) => setForm((current) => ({ ...current, [key]: event.target.value }))} required={key !== "long_option" && key !== "long_strike" && key !== "entry_spot"} /></label>)}<Button type="submit">Record Manual Position</Button></form></CardContent></Card>
      <Card><CardHeader><CardTitle>Scheduled research scan</CardTitle></CardHeader><CardContent><form onSubmit={saveSchedule} className="grid gap-3 sm:grid-cols-2">{(["Symbols", "EventClearSymbols", "AccountEquity", "AssignmentExposure", "TopN", "DteMin", "DteMax", "MinimumVolatilityEdge", "RiskBudgetPct", "MaxAssignmentExposurePct", "Timezone"] as const).map((key) => <label key={key} className="text-xs font-medium text-slate-600">{key}<Input value={schedule[key] ?? ""} onChange={(event) => setSchedule((current) => ({ ...current, [key]: event.target.value }))} /></label>)}<label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={Boolean(schedule.Enabled)} onChange={(event) => setSchedule((current) => ({ ...current, Enabled: event.target.checked }))} /> Enable scheduled scans</label><Button type="submit">Save Schedule</Button></form><p className="mt-3 text-xs text-slate-500">The scheduler runs during the US session, persists reports, and sends idempotent alerts. It never submits orders.</p></CardContent></Card>
    </div>
    <Card><CardHeader><CardTitle>Recent alerts</CardTitle></CardHeader><CardContent><div className="space-y-2">{alerts.slice(0, 20).map((alert) => <div key={alert.AlertId} className="rounded border border-slate-200 p-3 text-sm"><div className="font-semibold">{alert.Title} <span className="ml-2 text-xs text-slate-500">{alert.Status}</span></div><div className="whitespace-pre-wrap text-slate-600">{alert.Message}</div></div>)}{!alerts.length ? <p className="text-sm text-slate-500">No alerts recorded.</p> : null}</div></CardContent></Card>
  </div>;
}
