"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useMemo, useState } from "react";
import { useAuth } from "../contexts/AuthContext";

type NavItem = { href: string; label: string; group: string };

const NAV: NavItem[] = [
  // Trading
  { group: "Trading", href: "/range-orders", label: "Range Orders" },
  { group: "Trading", href: "/conditional-orders", label: "Conditional Orders" },
  { group: "Trading", href: "/strategy-orders", label: "Strategy Orders" },

  // Market
  { group: "Market", href: "/market-flow", label: "Market Flow" },
  { group: "Market", href: "/option-insights", label: "US Option Insights" },
  { group: "Market", href: "/gex-auto-insight", label: "GEX Auto Insight" },

  // Research
  { group: "Research", href: "/research-hub", label: "Research Hub" },
  { group: "Research", href: "/research-reports", label: "Research Reports" },

  // Watchlists
  { group: "Watchlists", href: "/breakout-watchlist", label: "Breakout Watchlist (AU)" },
  { group: "Watchlists", href: "/breakout-watchlist-us", label: "Breakout Watchlist (US)" },
  { group: "Watchlists", href: "/gap-up-watchlist", label: "Gap Up Watchlist" },
  { group: "Watchlists", href: "/monitor-stocks", label: "Monitor Stocks" },

  // System
  { group: "System", href: "/ib-gateway", label: "IB Gateway" },
  { group: "System", href: "/notification-subscriptions", label: "Notifications" },
  { group: "System", href: "/users", label: "Users" },
];

function groupBy(items: NavItem[]) {
  const out: Record<string, NavItem[]> = {};
  for (const it of items) {
    out[it.group] = out[it.group] || [];
    out[it.group].push(it);
  }
  return out;
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { username, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const grouped = useMemo(() => groupBy(NAV), []);

  return (
    <div className="min-h-dvh bg-gradient-to-b from-indigo-50 via-white to-white text-slate-800">
      <div className="flex">
        {/* Sidebar */}
        <aside
          className={
            (sidebarOpen ? "w-64" : "w-16") +
            " sticky top-0 h-dvh border-r border-slate-200 bg-white/80 backdrop-blur supports-[backdrop-filter]:bg-white/60"
          }
        >
          <div className="h-14 flex items-center justify-between px-4 border-b border-slate-200">
            <Link
              href="/"
              className={
                "font-semibold tracking-tight text-slate-900 " +
                (sidebarOpen ? "" : "sr-only")
              }
            >
              Stocks AU
            </Link>
            <button
              className="inline-flex h-9 w-9 items-center justify-center rounded-md hover:bg-slate-100"
              onClick={() => setSidebarOpen((v) => !v)}
              aria-label="Toggle sidebar"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                className="h-5 w-5 text-slate-600"
              >
                <path d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>

          <nav className="px-2 py-3 overflow-y-auto h-[calc(100dvh-3.5rem)]">
            {Object.entries(grouped).map(([group, items]) => (
              <div key={group} className="mb-3">
                <div
                  className={
                    "px-3 py-2 text-xs font-semibold text-slate-500 uppercase tracking-wide " +
                    (sidebarOpen ? "" : "sr-only")
                  }
                >
                  {group}
                </div>
                <div className="space-y-1">
                  {items.map((it) => {
                    const active = pathname === it.href;
                    return (
                      <Link
                        key={it.href}
                        href={it.href}
                        className={
                          "flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors " +
                          (active
                            ? "bg-indigo-50 text-indigo-700"
                            : "text-slate-700 hover:bg-slate-100 hover:text-slate-900")
                        }
                      >
                        <span className={(sidebarOpen ? "" : "sr-only") + " truncate"}>
                          {it.label}
                        </span>
                        {!sidebarOpen ? (
                          <span className="h-2 w-2 rounded-full bg-slate-300" aria-hidden />
                        ) : null}
                      </Link>
                    );
                  })}
                </div>
              </div>
            ))}
          </nav>
        </aside>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <header className="sticky top-0 z-40 h-14 border-b border-slate-200 bg-white/80 backdrop-blur supports-[backdrop-filter]:bg-white/60">
            <div className="mx-auto max-w-7xl h-14 px-6 flex items-center justify-between">
              <div className="text-sm text-slate-600">{pathname === "/" ? "Dashboard" : pathname}</div>
              <div className="flex items-center gap-3">
                <span className="text-xs text-slate-500">Welcome, {username}</span>
                <button
                  onClick={logout}
                  className="text-xs text-slate-500 hover:text-red-600"
                >
                  Logout
                </button>
              </div>
            </div>
          </header>
          <main className="mx-auto max-w-7xl px-6 py-8">{children}</main>
        </div>
      </div>
    </div>
  );
}
