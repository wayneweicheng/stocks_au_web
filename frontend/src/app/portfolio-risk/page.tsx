"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type MetricValue = number | null | undefined;

interface CapacityRow {
  target_leverage: number;
  max_gross_exposure: MetricValue;
  room: MetricValue;
  over_by: MetricValue;
}

interface PositionRow {
  symbol: string;
  sec_type: string;
  currency: string;
  exchange: string;
  position: MetricValue;
  market_price: MetricValue;
  market_value: MetricValue;
  average_cost: MetricValue;
  unrealized_pnl: MetricValue;
}

interface OpenOrderRow {
  symbol: string;
  sec_type: string;
  action: string;
  order_type: string;
  status: string;
  quantity: MetricValue;
  limit_price: MetricValue;
  estimated_notional: MetricValue;
  order_id: number | null;
}

interface AccountRiskResponse {
  ok: boolean;
  as_of: string;
  account: string | null;
  currency: string | null;
  metrics: Record<string, MetricValue>;
  capacity: CapacityRow[];
  positions: PositionRow[];
  open_orders: OpenOrderRow[];
}

function formatMoney(value: MetricValue, currency = "USD") {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency || "USD",
    maximumFractionDigits: 0,
  }).format(Number(value));
}

function formatNumber(value: MetricValue, digits = 2) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return Number(value).toLocaleString(undefined, {
    minimumFractionDigits: 0,
    maximumFractionDigits: digits,
  });
}

function formatRatio(value: MetricValue, suffix = "x") {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return `${Number(value).toFixed(2)}${suffix}`;
}

function formatPercent(value: MetricValue) {
  if (value === null || value === undefined || !Number.isFinite(Number(value))) return "n/a";
  return `${(Number(value) * 100).toFixed(1)}%`;
}

function leverageClass(leverage: MetricValue) {
  const value = Number(leverage);
  if (!Number.isFinite(value)) return "text-slate-700";
  if (value < 1) return "text-emerald-700";
  if (value < 1.5) return "text-amber-700";
  return "text-red-700";
}

function StatCard({
  label,
  value,
  hint,
  tone = "default",
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "default" | "good" | "warn" | "danger";
}) {
  const toneClass =
    tone === "good"
      ? "text-emerald-700"
      : tone === "warn"
        ? "text-amber-700"
        : tone === "danger"
          ? "text-red-700"
          : "text-slate-900";

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-xs uppercase tracking-wide text-slate-500">{label}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className={`text-2xl font-semibold ${toneClass}`}>{value}</div>
        {hint ? <div className="mt-1 text-xs text-slate-500">{hint}</div> : null}
      </CardContent>
    </Card>
  );
}

export default function PortfolioRiskPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [data, setData] = useState<AccountRiskResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const currency = data?.currency || "USD";
  const metrics = data?.metrics || {};
  const leverage = metrics.current_leverage;

  const leverageTone = useMemo(() => {
    const value = Number(leverage);
    if (!Number.isFinite(value)) return "default";
    if (value < 1) return "good";
    if (value < 1.5) return "warn";
    return "danger";
  }, [leverage]);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/ib/account-risk`, {
        cache: "no-store",
      });
      if (!response.ok) {
        let detail = `HTTP ${response.status}`;
        try {
          const body = await response.json();
          detail = body?.detail || detail;
        } catch {
          // keep status fallback
        }
        throw new Error(detail);
      }
      setData(await response.json());
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setLoading(false);
    }
  }, [baseUrl]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Portfolio Risk"
        subtitle="Read-only IB account view for leverage, cash, margin buffer, and capacity."
        actions={
          <Button onClick={refresh} disabled={loading}>
            {loading ? "Refreshing..." : "Refresh"}
          </Button>
        }
      />

      {error ? (
        <div className="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          Failed to load IB account risk: {error}
        </div>
      ) : null}

      <div className="rounded-lg border border-slate-200 bg-white px-4 py-3 text-sm text-slate-600">
        <span className="font-medium text-slate-900">Account:</span> {data?.account || "n/a"}
        <span className="mx-3 text-slate-300">|</span>
        <span className="font-medium text-slate-900">Currency:</span> {currency}
        <span className="mx-3 text-slate-300">|</span>
        <span className="font-medium text-slate-900">Last refreshed:</span>{" "}
        {data?.as_of ? new Date(data.as_of).toLocaleString() : "n/a"}
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Net Liquidation"
          value={formatMoney(metrics.net_liquidation, currency)}
          hint="Your IB account equity."
        />
        <StatCard
          label="Gross Exposure"
          value={formatMoney(metrics.gross_position_value, currency)}
          hint="Total absolute market value of current positions."
        />
        <StatCard
          label="Current Leverage"
          value={formatRatio(metrics.current_leverage)}
          hint="Gross exposure divided by net liquidation."
          tone={leverageTone}
        />
        <StatCard
          label="Cash"
          value={formatMoney(metrics.cash, currency)}
          hint="IB TotalCashValue."
        />
        <StatCard
          label="Available Funds"
          value={formatMoney(metrics.available_funds, currency)}
          hint="Before initial margin constraint."
        />
        <StatCard
          label="Excess Liquidity"
          value={formatMoney(metrics.excess_liquidity, currency)}
          hint={`Buffer ratio: ${formatPercent(metrics.excess_liquidity_ratio)}`}
          tone={Number(metrics.excess_liquidity_ratio) > 0.25 ? "good" : "warn"}
        />
        <StatCard
          label="Buying Power"
          value={formatMoney(metrics.buying_power, currency)}
          hint="IB-reported buying power, not a personal risk limit."
        />
        <StatCard
          label="Margin Used"
          value={formatPercent(metrics.init_margin_ratio)}
          hint={`Maint margin: ${formatPercent(metrics.maint_margin_ratio)}`}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Room Before Target Leverage</CardTitle>
          <p className="mt-1 text-sm text-slate-600">
            This uses current gross exposure. A zero room value means you are already at or above that target.
          </p>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                  <th className="py-2 pr-4">Target</th>
                  <th className="py-2 pr-4">Max Gross Exposure</th>
                  <th className="py-2 pr-4">Room Left</th>
                  <th className="py-2 pr-4">Over By</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {(data?.capacity || []).map((row) => (
                  <tr key={row.target_leverage}>
                    <td className="py-3 pr-4 font-medium">{formatRatio(row.target_leverage)}</td>
                    <td className="py-3 pr-4">{formatMoney(row.max_gross_exposure, currency)}</td>
                    <td className="py-3 pr-4 text-emerald-700">{formatMoney(row.room, currency)}</td>
                    <td className="py-3 pr-4 text-red-700">{formatMoney(row.over_by, currency)}</td>
                  </tr>
                ))}
                {!data?.capacity?.length ? (
                  <tr>
                    <td className="py-4 text-slate-500" colSpan={4}>
                      No capacity data available yet.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Open Orders</CardTitle>
          <p className="mt-1 text-sm text-slate-600">
            Pending buy order notional: {formatMoney(metrics.open_buy_order_notional, currency)}
          </p>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                  <th className="py-2 pr-4">Symbol</th>
                  <th className="py-2 pr-4">Action</th>
                  <th className="py-2 pr-4">Type</th>
                  <th className="py-2 pr-4">Status</th>
                  <th className="py-2 pr-4 text-right">Qty</th>
                  <th className="py-2 pr-4 text-right">Limit</th>
                  <th className="py-2 pr-4 text-right">Notional</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {(data?.open_orders || []).map((row) => (
                  <tr key={`${row.order_id}-${row.symbol}`}>
                    <td className="py-3 pr-4 font-medium">{row.symbol}</td>
                    <td className="py-3 pr-4">{row.action}</td>
                    <td className="py-3 pr-4">{row.order_type}</td>
                    <td className="py-3 pr-4">{row.status}</td>
                    <td className="py-3 pr-4 text-right">{formatNumber(row.quantity, 0)}</td>
                    <td className="py-3 pr-4 text-right">{formatMoney(row.limit_price, currency)}</td>
                    <td className="py-3 pr-4 text-right">{formatMoney(row.estimated_notional, currency)}</td>
                  </tr>
                ))}
                {!data?.open_orders?.length ? (
                  <tr>
                    <td className="py-4 text-slate-500" colSpan={7}>
                      No open orders reported by IB.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Positions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wide text-slate-500">
                  <th className="py-2 pr-4">Symbol</th>
                  <th className="py-2 pr-4">Type</th>
                  <th className="py-2 pr-4 text-right">Position</th>
                  <th className="py-2 pr-4 text-right">Market Price</th>
                  <th className="py-2 pr-4 text-right">Market Value</th>
                  <th className="py-2 pr-4 text-right">Avg Cost</th>
                  <th className="py-2 pr-4 text-right">Unrealized P/L</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {(data?.positions || []).map((row) => (
                  <tr key={`${row.symbol}-${row.sec_type}-${row.exchange}`}>
                    <td className="py-3 pr-4 font-medium">{row.symbol}</td>
                    <td className="py-3 pr-4 text-slate-600">{row.sec_type}</td>
                    <td className="py-3 pr-4 text-right">{formatNumber(row.position, 2)}</td>
                    <td className="py-3 pr-4 text-right">{formatMoney(row.market_price, row.currency || currency)}</td>
                    <td className="py-3 pr-4 text-right">{formatMoney(row.market_value, row.currency || currency)}</td>
                    <td className="py-3 pr-4 text-right">{formatMoney(row.average_cost, row.currency || currency)}</td>
                    <td
                      className={`py-3 pr-4 text-right ${
                        Number(row.unrealized_pnl) >= 0 ? "text-emerald-700" : "text-red-700"
                      }`}
                    >
                      {formatMoney(row.unrealized_pnl, row.currency || currency)}
                    </td>
                  </tr>
                ))}
                {!data?.positions?.length ? (
                  <tr>
                    <td className="py-4 text-slate-500" colSpan={7}>
                      No positions reported by IB.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        This page is read-only and informational. Treat IB buying power as a broker constraint, not a personal risk
        target; the leverage targets above are the safer guide.
      </div>
    </div>
  );
}
