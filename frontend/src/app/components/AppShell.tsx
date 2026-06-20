"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { useAuth } from "../contexts/AuthContext";

type NavItem = { href: string; label: string };
type NavGroup = { label: string; items: NavItem[] };

const NAV: NavGroup[] = [
  {
    label: "Trading",
    items: [
      { href: "/portfolio-risk", label: "Portfolio Risk" },
      { href: "/option-orders", label: "Option Orders" },
      { href: "/option-recommendations", label: "Option Recommendations" },
      { href: "/range-orders", label: "Range Orders" },
      { href: "/conditional-orders", label: "Conditional Orders" },
      { href: "/strategy-orders", label: "Strategy Orders" },
      { href: "/trading-orders", label: "Pegasus Trading Orders" },
    ],
  },
  {
    label: "Market",
    items: [
      { href: "/", label: "US Command Center" },
      { href: "/asx-command-center", label: "ASX Command Center" },
      { href: "/market-flow", label: "Market Flow" },
      { href: "/calculated-gex", label: "Calculated GEX" },
      { href: "/gamma-wall", label: "Gamma Wall" },
      { href: "/market-clv-trend", label: "Market CLV Trend" },
      { href: "/net-gex-vs-close", label: "Net GEX vs Close" },
      { href: "/net-gex-vs-price-change", label: "Net GEX vs Price Change" },
      { href: "/option-gex-delta-capital-type", label: "Option GEX Delta" },
      { href: "/index-price-mapping", label: "Index Price Mapping" },
      { href: "/price-levels-30m", label: "30M Price Levels" },
      { href: "/broker-analysis", label: "Broker Analysis" },
    ],
  },
  {
    label: "Research",
    items: [
      { href: "/research-hub", label: "Research Hub" },
      { href: "/research-reports", label: "Research Reports" },
      { href: "/market-theme-reports", label: "Market Theme Reports" },
      { href: "/us-equity-analysis-reports", label: "US Equity Analysis" },
      { href: "/discord-summary", label: "Discord Summary" },
    ],
  },
  {
    label: "Watchlists",
    items: [
      { href: "/breakout-watchlist", label: "Breakout Watchlist" },
      { href: "/gap-up-watchlist", label: "Gap Up Watchlist" },
      { href: "/monitor-stocks", label: "Monitor Stocks" },
      { href: "/bet-odds-monitors", label: "Bet Odds Monitor" },
    ],
  },
  {
    label: "System",
    items: [
      { href: "/ib-gateway", label: "IB Gateway" },
      { href: "/notification-subscriptions", label: "Notification Subscriptions" },
      { href: "/users", label: "Users" },
    ],
  },
];

function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname === href || pathname.startsWith(href + "/");
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() || "/";
  const { username, logout } = useAuth();

  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  const flat = useMemo(() => NAV.flatMap((g) => g.items), []);
  const activeLabel = flat.find((i) => isActive(pathname, i.href))?.label;

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-indigo-50 via-white to-white text-slate-800">
      {mobileOpen ? (
        <button
          type="button"
          className="fixed inset-0 z-40 bg-slate-900/35 md:hidden"
          aria-label="Close navigation"
          onClick={() => setMobileOpen(false)}
        />
      ) : null}

      <div className="flex min-w-0">
        {/* Sidebar */}
        <aside
          className={[
            "fixed left-0 top-0 z-50 flex h-dvh w-[min(22rem,calc(100vw-1rem))] flex-col overflow-hidden border-r border-slate-200 bg-white/95 shadow-xl backdrop-blur transition-transform duration-200 ease-out",
            "md:sticky md:z-30 md:h-screen md:shrink-0 md:bg-white/80 md:shadow-none",
            mobileOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0",
            collapsed ? "md:w-[72px]" : "md:w-[280px]",
          ].join(" ")}
        >
          <div className="flex h-14 shrink-0 items-center justify-between border-b border-slate-200 px-4">
            <Link
              href="/"
              className={[
                "font-semibold tracking-tight",
                "bg-gradient-to-r from-indigo-600 to-blue-600 bg-clip-text text-transparent",
                collapsed ? "text-lg" : "text-base",
              ].join(" ")}
            >
              <span className={collapsed ? "md:hidden" : ""}>Stocks AU</span>
              {collapsed ? <span className="hidden md:inline">SA</span> : null}
            </Link>
            <button
              type="button"
              onClick={() => setCollapsed((v) => !v)}
              className="hidden text-sm text-slate-500 hover:text-slate-900 md:inline"
              aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            >
              {collapsed ? ">" : "<"}
            </button>
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              className="text-sm text-slate-500 hover:text-slate-900 md:hidden"
              aria-label="Close navigation"
            >
              Close
            </button>
          </div>

          <nav
            id="primary-navigation"
            className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-4 text-sm"
          >
            {NAV.map((group) => (
              <div key={group.label} className="mb-5">
                <div
                  className={[
                    "px-2 text-xs font-semibold uppercase tracking-wide text-slate-500",
                    collapsed ? "md:hidden" : "",
                  ].join(" ")}
                >
                  {group.label}
                </div>
                <div className="mt-2 space-y-1">
                  {group.items.map((item) => {
                    const active = isActive(pathname, item.href);
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        className={[
                          "flex items-center rounded-md px-2 py-2",
                          active
                            ? "bg-indigo-50 text-indigo-700"
                            : "text-slate-700 hover:bg-slate-100 hover:text-slate-900",
                        ].join(" ")}
                        title={item.label}
                      >
                        <span className={collapsed ? "text-sm md:hidden" : "text-sm"}>
                          {item.label}
                        </span>
                        {collapsed ? (
                          <span className="hidden text-xs md:inline">
                            {item.label.slice(0, 2).toUpperCase()}
                          </span>
                        ) : null}
                      </Link>
                    );
                  })}
                </div>
              </div>
            ))}
          </nav>
        </aside>

        {/* Main */}
        <div className="min-w-0 flex-1">
          <header className="sticky top-0 z-40 h-14 border-b border-slate-200 bg-white/80 backdrop-blur">
            <div className="mx-auto flex h-14 max-w-7xl items-center justify-between gap-3 px-4 sm:px-6">
              <div className="flex min-w-0 items-center gap-3 text-sm text-slate-600">
                <button
                  type="button"
                  onClick={() => setMobileOpen(true)}
                  className="shrink-0 rounded-md border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50 md:hidden"
                  aria-label="Open navigation"
                  aria-controls="primary-navigation"
                  aria-expanded={mobileOpen}
                >
                  Menu
                </button>
                {activeLabel ? (
                  <span className="truncate font-medium text-slate-900">{activeLabel}</span>
                ) : (
                  <span className="truncate font-medium text-slate-900">Stocks AU</span>
                )}
              </div>
              <div className="flex shrink-0 items-center gap-3">
                <span className="hidden text-xs text-slate-500 sm:inline">{username}</span>
                <button
                  type="button"
                  onClick={logout}
                  className="text-xs text-slate-500 hover:text-red-600"
                >
                  Logout
                </button>
              </div>
            </div>
          </header>

          <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-8">{children}</main>
        </div>
      </div>
    </div>
  );
}
