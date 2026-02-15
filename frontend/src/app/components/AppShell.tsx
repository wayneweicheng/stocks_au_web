"use client";

import React, { useMemo, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { useAuth } from "../contexts/AuthContext";

type NavItem = { href: string; label: string };
type NavGroup = { label: string; items: NavItem[] };

const NAV: NavGroup[] = [
  {
    label: "Trading",
    items: [
      { href: "/range-orders", label: "Range Orders" },
      { href: "/conditional-orders", label: "Conditional Orders" },
      { href: "/strategy-orders", label: "Strategy Orders" },
    ],
  },
  {
    label: "Market",
    items: [
      { href: "/market-flow", label: "Market Flow" },
      { href: "/gex-auto-insight", label: "GEX Auto Insight" },
      { href: "/option-insights", label: "US Option Insights" },
    ],
  },
  {
    label: "Research",
    items: [
      { href: "/research-hub", label: "Research Hub" },
      { href: "/research-reports", label: "Research Reports" },
      { href: "/discord-summary", label: "Discord Summary" },
    ],
  },
  {
    label: "Watchlists",
    items: [
      { href: "/breakout-watchlist", label: "Breakout Watchlist" },
      { href: "/gap-up-watchlist", label: "Gap Up Watchlist" },
      { href: "/monitor-stocks", label: "Monitor Stocks" },
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

  const flat = useMemo(() => NAV.flatMap((g) => g.items), []);
  const activeLabel = flat.find((i) => isActive(pathname, i.href))?.label;

  return (
    <div className="min-h-[calc(100vh-0px)] bg-gradient-to-b from-indigo-50 via-white to-white text-slate-800">
      <div className="flex">
        {/* Sidebar */}
        <aside
          className={[
            "sticky top-0 h-screen border-r border-slate-200 bg-white/80 backdrop-blur",
            collapsed ? "w-[72px]" : "w-[260px]",
          ].join(" ")}
        >
          <div className="h-14 px-4 flex items-center justify-between border-b border-slate-200">
            <Link
              href="/"
              className={[
                "font-semibold tracking-tight",
                "bg-gradient-to-r from-indigo-600 to-blue-600 bg-clip-text text-transparent",
                collapsed ? "text-lg" : "text-base",
              ].join(" ")}
            >
              {collapsed ? "SA" : "Stocks AU"}
            </Link>
            <button
              onClick={() => setCollapsed((v) => !v)}
              className="text-slate-500 hover:text-slate-900 text-sm"
              aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            >
              {collapsed ? ">" : "<"}
            </button>
          </div>

          <nav className="px-3 py-4 text-sm">
            {NAV.map((group) => (
              <div key={group.label} className="mb-5">
                {!collapsed ? (
                  <div className="px-2 text-xs font-semibold uppercase tracking-wide text-slate-500">
                    {group.label}
                  </div>
                ) : null}
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
                        <span className={collapsed ? "text-xs" : "text-sm"}>
                          {collapsed ? item.label.slice(0, 2).toUpperCase() : item.label}
                        </span>
                      </Link>
                    );
                  })}
                </div>
              </div>
            ))}
          </nav>
        </aside>

        {/* Main */}
        <div className="flex-1">
          <header className="sticky top-0 z-40 h-14 border-b border-slate-200 bg-white/80 backdrop-blur">
            <div className="mx-auto max-w-7xl px-6 h-14 flex items-center justify-between">
              <div className="text-sm text-slate-600">
                {activeLabel ? (
                  <span className="font-medium text-slate-900">{activeLabel}</span>
                ) : (
                  <span className="font-medium text-slate-900">Stocks AU</span>
                )}
              </div>
              <div className="flex items-center gap-3">
                <span className="text-xs text-slate-500">{username}</span>
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
