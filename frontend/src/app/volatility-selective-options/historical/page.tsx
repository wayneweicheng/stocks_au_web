"use client";

import { FormEvent, useState } from "react";
import Button from "../../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/Card";
import Input from "../../components/ui/Input";
import PageHeader from "../../components/PageHeader";
import { authenticatedFetch } from "../../utils/authenticatedFetch";

export default function HistoricalDatasetBacktestPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [values, setValues] = useState({ symbols: "SPY,QQQ,IWM", start_date: "", end_date: "", account_equity: "100000", event_clear_symbols: "SPY,QQQ,IWM", top_n: "3" });
  const [result, setResult] = useState<any>(null);
  const [error, setError] = useState("");
  async function submit(event: FormEvent) {
    event.preventDefault();
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/volatility-options/historical-dataset-backtest`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...values, account_equity: Number(values.account_equity), top_n: Number(values.top_n) }),
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      setResult(body);
    } catch (exc: any) { setError(exc?.message || String(exc)); }
  }
  return <div className="space-y-6">
    <PageHeader title="Historical Dataset Backtest" subtitle="Build a reproducible dataset from StockDB_US historical prices and option quotes, then run the deterministic walk-forward and Monte Carlo backtest. No live orders are involved." />
    {error ? <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div> : null}
    <Card><CardHeader><CardTitle>Dataset range</CardTitle></CardHeader><CardContent><form onSubmit={submit} className="grid gap-4 md:grid-cols-2">{(["symbols", "start_date", "end_date", "account_equity", "event_clear_symbols", "top_n"] as const).map((key) => <label key={key} className="text-xs font-medium text-slate-600">{key.replaceAll("_", " ")}<Input type={key.includes("date") ? "date" : "text"} value={values[key]} onChange={(event) => setValues((current) => ({ ...current, [key]: event.target.value }))} required={key !== "event_clear_symbols"} /></label>)}<Button type="submit">Build Dataset and Start Backtest</Button></form><p className="mt-4 text-xs text-slate-500">Stock symbols must have exact-date underlying closes and historical option quotes. Single-stock event status is fail-closed unless supplied in Event Clear Symbols or the event reference table.</p></CardContent></Card>
    {result ? <Card><CardHeader><CardTitle>Backtest job submitted</CardTitle></CardHeader><CardContent><pre className="overflow-auto rounded bg-slate-950 p-4 text-xs text-slate-100">{JSON.stringify(result, null, 2)}</pre><p className="mt-3 text-sm text-slate-600">Open the Volatility Backtest report page after the job completes.</p></CardContent></Card> : null}
  </div>;
}
