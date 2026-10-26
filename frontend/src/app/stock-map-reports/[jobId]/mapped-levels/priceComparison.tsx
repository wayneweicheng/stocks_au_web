import type { ReactNode } from "react";

export type StockMapPriceQuote = {
  last_close?: number | null;
  last_close_source?: string | null;
  live_price?: number | null;
  live_price_source?: string | null;
};

export function selectedClose(report: Record<string, unknown> | null, quote: StockMapPriceQuote | null) {
  const raw = report?.execution_reference;
  const reference = typeof raw === "number" ? raw : typeof raw === "string" && raw.trim() ? Number(raw) : null;
  if (reference !== null && Number.isFinite(reference) && reference > 0) {
    const type = report?.execution_reference_type;
    return {
      value: reference,
      source: `Report execution reference${typeof type === "string" && type ? ` (${type.replace(/_/g, " ")})` : ""}`,
      isNative30m: type === "completed_30m_bar",
      fromReport: true,
    };
  }
  const fallback = quote?.last_close;
  return {
    value: typeof fallback === "number" && Number.isFinite(fallback) && fallback > 0 ? fallback : null,
    source: quote?.last_close_source || "n/a",
    isNative30m: quote?.last_close_source === "30m_close",
    fromReport: false,
  };
}

function price(value: number | null) {
  return value === null ? "n/a" : value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function percentLabel(value: number, basis: number | null) {
  if (basis === null || basis === 0) return "";
  const change = ((value - basis) / basis) * 100;
  return `(${change >= 0 ? "+" : ""}${change.toFixed(2)}%)`;
}

export function StockZonePriceHeaders({ isNative30m, fromReport }: { isNative30m: boolean; fromReport: boolean }): ReactNode {
  return <>
    <th className="px-3 py-2">Selected close ({isNative30m ? "30M; " : ""}{fromReport ? "report execution reference" : "price endpoint fallback"})</th>
    <th className="px-3 py-2">Live price (IB)</th>
    <th className="px-3 py-2">System zone (vs {isNative30m ? "30M close" : "selected close"})</th>
    <th className="px-3 py-2">System zone (vs Live Price)</th>
  </>;
}

export function StockZonePriceCells({ low, high, close, closeSource, livePrice, livePriceSource }: {
  low: number;
  high: number;
  close: number | null;
  closeSource: string;
  livePrice: number | null;
  livePriceSource: string;
}): ReactNode {
  return <>
    <td className="px-3 py-3 font-mono text-slate-700">
      {price(close)}
      <div className="text-xs font-sans text-slate-400">{closeSource}</div>
    </td>
    <td className="px-3 py-3 font-mono text-slate-700">
      {price(livePrice)}
      <div className="text-xs font-sans text-slate-400">{livePriceSource}</div>
    </td>
    <td className="px-3 py-3 font-mono text-slate-700">
      <div>{price(low)} <span className="text-xs text-slate-500">{percentLabel(low, close)}</span></div>
      <div>{price(high)} <span className="text-xs text-slate-500">{percentLabel(high, close)}</span></div>
    </td>
    <td className="px-3 py-3 font-mono text-slate-700">
      <div>{price(low)} <span className="text-xs text-slate-500">{percentLabel(low, livePrice)}</span></div>
      <div>{price(high)} <span className="text-xs text-slate-500">{percentLabel(high, livePrice)}</span></div>
    </td>
  </>;
}
