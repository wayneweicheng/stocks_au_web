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
          <h1 className="text-3xl sm:text-5xl font-semibold tracking-tight bg-gradient-to-r from-sky-600 to-blue-700 bg-clip-text text-transparent">Stocks AU Dashboard</h1>
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

        <section className="mt-10 grid gap-6 sm:grid-cols-2">
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">Order Book & Transactions</h3>
            <p className="text-sm text-slate-600 mb-4">Migrated page.</p>
            <Link href="/order-book" className="inline-block rounded-md bg-gradient-to-r from-sky-600 to-blue-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h3 className="font-medium text-lg mb-1">TA Scan</h3>
            <p className="text-sm text-slate-600 mb-4">Migrated page.</p>
            <Link href="/ta-scan" className="inline-block rounded-md bg-gradient-to-r from-sky-600 to-blue-600 text-white px-4 py-2 text-sm hover:opacity-90">Open page</Link>
          </div>
          <div className="rounded-lg border border-slate-200 dark:border-slate-800 p-6">
            <h3 className="font-medium text-lg mb-1">Authentication</h3>
            <p className="text-sm text-slate-600 dark:text-slate-300 mb-4">Google sign-in will be added later.</p>
            <div className="text-xs text-slate-500">No auth required for this page.</div>
          </div>
        </section>
      </div>
    </div>
  );
}
