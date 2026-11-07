import Link from "next/link";
import { symbolDestinations } from "./workspaceNavigation";

export default function SymbolQuickLinks({ symbol, market = "US" }: { symbol: string; market?: "US" | "ASX" }) {
  const links = symbolDestinations(symbol, market);
  if (!links) return null;
  return <nav aria-label={`${symbol} tools`} className="flex flex-wrap gap-2 text-xs">
    <Link href={links.chart} className="rounded border border-slate-200 bg-white px-2 py-1 text-indigo-700 hover:bg-indigo-50">Chart</Link>
    {links.map && <Link href={links.map} className="rounded border border-slate-200 bg-white px-2 py-1 text-indigo-700 hover:bg-indigo-50">Map</Link>}
    {links.rangeOrder && <Link href={links.rangeOrder} className="rounded border border-slate-200 bg-white px-2 py-1 text-indigo-700 hover:bg-indigo-50">Prepare range order</Link>}
  </nav>;
}
