"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { symbolDestinations } from "./workspaceNavigation";

type AccountSnapshot = { ok?: boolean; as_of?: string; metrics?: { excess_liquidity?: number | null }; open_orders?: unknown[] };
type QueueItem = { key: string; title: string; detail: string; href: string; tone: "warning" | "info" };

export default function AttentionQueue({ market, selectedDate, regime, opportunities }: {
  market: "US" | "ASX";
  selectedDate: string;
  regime?: { as_of: string | null; components: { available: boolean }[] } | null;
  opportunities: { symbol: string; risks: string[] }[];
}) {
  const [account, setAccount] = useState<AccountSnapshot | null>(null);
  const [accountStatus, setAccountStatus] = useState<"loading" | "available" | "unavailable">("loading");
  useEffect(() => {
    if (market !== "US") return;
    const controller = new AbortController();
    const timeout = setTimeout(() => { setAccountStatus("unavailable"); controller.abort(); }, 10000);
    void (async () => {
      setAccountStatus("loading"); setAccount(null);
      try {
        const response = await authenticatedFetch(`${process.env.NEXT_PUBLIC_BACKEND_URL || ""}/api/ib/account-risk`, { signal: controller.signal, cache: "no-store" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const result = await response.json() as AccountSnapshot;
        if (!controller.signal.aborted && result.ok) { setAccount(result); setAccountStatus("available"); }
        else if (!controller.signal.aborted) setAccountStatus("unavailable");
      } catch {
        if (!controller.signal.aborted) setAccountStatus("unavailable");
      } finally { clearTimeout(timeout); }
    })();
    return () => { clearTimeout(timeout); controller.abort(); };
  }, [market, selectedDate]);

  const items: QueueItem[] = [];
  if (!regime) items.push({ key: "regime", title: "Regime unavailable", detail: `No ${market} regime loaded for ${selectedDate}. Do not treat missing data as a neutral signal.`, href: market === "US" ? "/market-flow" : "/asx-command-center", tone: "warning" });
  else {
    const missing = regime.components.filter((component) => !component.available).length;
    if (missing) items.push({ key: "evidence", title: `${missing} regime input${missing === 1 ? "" : "s"} unavailable`, detail: `Selected ${market} date ${selectedDate} · regime as-of ${regime.as_of || "unknown"}.`, href: market === "US" ? "/market-flow" : "/asx-command-center", tone: "warning" });
    if (regime.as_of && regime.as_of.slice(0, 10) !== selectedDate) items.push({ key: "date", title: "Regime date differs from selection", detail: `Selected ${selectedDate}; supplied as-of ${regime.as_of}. Review before using this snapshot.`, href: market === "US" ? "/market-flow" : "/asx-command-center", tone: "warning" });
  }
  if (market === "US") {
    if (accountStatus === "unavailable") items.push({ key: "ib", title: "IB account status unavailable", detail: "Positions and open orders could not be checked; this is not an all-clear.", href: "/ib-gateway", tone: "warning" });
    if (accountStatus === "available" && account) {
      const excess = account.metrics?.excess_liquidity;
      if (typeof excess === "number" && Number.isFinite(excess) && excess <= 0) items.push({ key: "margin", title: "Review IB excess liquidity", detail: `IB reports ${excess.toLocaleString()} excess liquidity as of ${account.as_of || "unknown"}.`, href: "/portfolio-risk", tone: "warning" });
      if (account.open_orders?.length) items.push({ key: "orders", title: `${account.open_orders.length} open IB order${account.open_orders.length === 1 ? "" : "s"} to review`, detail: `Current account snapshot ${account.as_of || "time unavailable"}; informational, not an order alert.`, href: "/portfolio-risk", tone: "info" });
    }
  }
  for (const item of opportunities.filter((opportunity) => opportunity.risks?.length).slice(0, 3)) {
    items.push({ key: `risk-${item.symbol}`, title: `${item.symbol}: review contrary evidence`, detail: `${item.risks[0]} · ${selectedDate} opportunity snapshot`, href: symbolDestinations(item.symbol, market)?.chart || (market === "US" ? "/" : "/asx-command-center"), tone: "info" });
  }
  return <section aria-label="Attention queue" className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm sm:p-5">
    <div className="flex flex-wrap items-center justify-between gap-2"><h2 className="text-lg font-semibold text-slate-900">Needs review</h2><span className="text-xs text-slate-500">Selected market data: {selectedDate} · {market === "US" ? "IB account: current snapshot" : "ASX evidence"}</span></div>
    <p className="mt-1 text-xs text-slate-500">Read-only evidence queue, not trade signals or an all-clear. Items link to the source for human review.</p>
    <div className="mt-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-3">{items.length ? items.map((item) => <Link key={item.key} href={item.href} className={`rounded-lg border p-3 hover:shadow-sm ${item.tone === "warning" ? "border-amber-200 bg-amber-50" : "border-slate-200 bg-slate-50"}`}>
      <strong className="block text-sm text-slate-900">{item.title}</strong><span className="mt-1 block text-xs text-slate-600">{item.detail}</span>
    </Link>) : <p className="text-sm text-slate-500">{accountStatus === "loading" && market === "US" ? "Checking current IB account…" : "No review items from the available sources. Check the underlying pages before trading."}</p>}</div>
  </section>;
}
