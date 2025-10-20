"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

export default function Home() {
  const [health, setHealth] = useState<string>("Checking backend...");
  const [error, setError] = useState<string>("");

  useEffect(() => {
    const url = `${process.env.NEXT_PUBLIC_BACKEND_URL}/healthz`;
    fetch(url)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        const data = await r.json();
        setHealth(`Backend: ${data.status}`);
      })
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div className="min-h-screen">
      <div className="mx-auto max-w-5xl px-6 py-16">
        <header className="mb-12">
          <h1 className="text-3xl sm:text-5xl font-semibold tracking-tight bg-gradient-to-r from-emerald-600 to-green-700 bg-clip-text text-transparent">Stocks AU Dashboard</h1>
          <p className="mt-3 text-slate-600">Next.js frontend (3100) + FastAPI backend (3101)</p>
        </header>

        <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-medium mb-2">System status</h2>
          <div className="text-sm">
            <div className="mb-1">{health}</div>
            {error && <div className="text-red-600">Error: {error}</div>}
            <div className="text-slate-600">API: {process.env.NEXT_PUBLIC_BACKEND_URL}/healthz</div>
          </div>
        </section>

        <section className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">IB Gateway</h3>
            <p className="text-sm text-slate-600 mb-4">Start, stop and view IB Gateway status and heartbeat.</p>
            <Link href="/ib-gateway" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Order Book & Transactions</h3>
            <p className="text-sm text-slate-600 mb-4">View ASX stock transactions and order book data.</p>
            <Link href="/order-book" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">TA Scan</h3>
            <p className="text-sm text-slate-600 mb-4">Technical analysis scanning tools.</p>
            <Link href="/ta-scan" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Monitor Stocks</h3>
            <p className="text-sm text-slate-600 mb-4">Track and monitor your watchlist stocks.</p>
            <Link href="/monitor-stocks" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Conditional Orders</h3>
            <p className="text-sm text-slate-600 mb-4">Manage automated conditional trading orders.</p>
            <Link href="/conditional-orders" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Pegasus Invest Opportunities</h3>
            <p className="text-sm text-slate-600 mb-4">Discover investment opportunities and analysis.</p>
            <Link href="/pegasus-invest-opportunities" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Pattern Predictions</h3>
            <p className="text-sm text-slate-600 mb-4">Filter predictions by date, codes, and confidence. Open charts.</p>
            <Link href="/pattern-predictions" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">PLLRS Scanner</h3>
            <p className="text-sm text-slate-600 mb-4">View PLLRS results with filters and formatted metrics.</p>
            <Link href="/pllrs-scanner" className="inline-block rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
        </section>
      </div>
    </div>
  );
}
