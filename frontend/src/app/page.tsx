"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import PageHeader from "./components/PageHeader";
import { Card, CardContent, CardHeader, CardTitle } from "./components/ui/Card";
import Button from "./components/ui/Button";

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

  const quickLinks = [
    {
      title: "Range Orders",
      desc: "Build and place laddered orders with preview, quotes, brackets and cancel tools.",
      href: "/range-orders",
    },
    { title: "Market Flow", desc: "Composite signals from GEX/VIX/Dark Pool + swing regimes.", href: "/market-flow" },
    { title: "Research Hub", desc: "Ratings, research links, commenters, announcements & lookup.", href: "/research-hub" },
    { title: "IB Gateway", desc: "Start/stop and check IB Gateway heartbeat.", href: "/ib-gateway" },
  ];

  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard"
        subtitle="Next.js frontend (3100) + FastAPI backend (3101)"
      />

      <Card>
        <CardHeader>
          <CardTitle>System status</CardTitle>
        </CardHeader>
        <CardContent className="text-sm">
          <div className="mb-1">{health}</div>
          {error && <div className="text-red-600">Error: {error}</div>}
          <div className="text-slate-600">API: {process.env.NEXT_PUBLIC_BACKEND_URL}/healthz</div>
        </CardContent>
      </Card>

      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {quickLinks.map((x) => (
          <Card key={x.href} className="hover:shadow-md transition-shadow">
            <CardHeader>
              <CardTitle className="text-base">{x.title}</CardTitle>
              <p className="mt-1 text-sm text-slate-600">{x.desc}</p>
            </CardHeader>
            <CardContent>
              <Link href={x.href}>
                <Button>Open</Button>
              </Link>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All tools</CardTitle>
          <p className="mt-1 text-sm text-slate-600">Use the left sidebar to navigate by category.</p>
        </CardHeader>
        <CardContent />
      </Card>
    </div>
  );
}
