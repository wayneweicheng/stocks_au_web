"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { useAuth } from "../contexts/AuthContext";

type NavItem = { href: string; label: string };
type NavGroup = { label: string; items: NavItem[] };

const NAV: NavGroup[] = [
  {
    label: "Analysis",
    items: [{ href: "/support-resistance", label: "Support / Resistance" }],
  },
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
      { href: "/find-bullish-call-opportunities", label: "Bullish Call Opportunities" },
      { href: "/find-cash-secured-put-opportunities", label: "Cash-Secured Put Opportunities" },
      { href: "/option-flow-analysis-reports", label: "Option Flow Analysis" },
      { href: "/trading-signal-reports", label: "Trading Signal Reports" },
      { href: "/find-index-bottoms-reports", label: "Find Index Bottoms" },
      { href: "/shiso-leaf-stock-hunter-reports", label: "Shiso Leaf Hunter" },
      { href: "/stock-social-sentiment-reports", label: "Social Sentiment" },
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

function NavIcon({ group }: { group: string }) {
  const paths: Record<string, string> = {
    Analysis: "M4 19V5m0 14h16M8 16l3-4 3 2 4-6",
    Trading: "M4 7h16M4 12h16M4 17h16",
    Market: "M4 18V9m5 9V5m5 13v-7m5 7V3",
    Research: "M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3V4Zm0 0v13a3 3 0 0 0 3 3",
    Watchlists: "m4 7 2-2h4l2 2h8v11H4V7Zm4 5h8m-8 3h5",
    System: "M12 3a2 2 0 0 1 2 2v1.1a7 7 0 0 1 1.5.9l1-.6a2 2 0 1 1 2 3.4l-1 .6c.1.5.2 1 .2 1.6s-.1 1.1-.2 1.6l1 .6a2 2 0 1 1-2 3.4l-1-.6a7 7 0 0 1-1.5.9V19a2 2 0 1 1-4 0v-1.1a7 7 0 0 1-1.5-.9l-1 .6a2 2 0 1 1-2-3.4l1-.6A7 7 0 0 1 6.3 12c0-.6.1-1.1.2-1.6l-1-.6a2 2 0 1 1 2-3.4l1 .6A7 7 0 0 1 10 6.1V5a2 2 0 0 1 2-2Z",
  };

  return (
    <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="h-4 w-4 shrink-0">
      <path strokeLinecap="round" strokeLinejoin="round" d={paths[group] || paths.Market} />
      {group === "System" ? <circle cx="12" cy="12" r="2.2" /> : null}
    </svg>
  );
}

function Chevron({ open }: { open: boolean }) {
  return (
    <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className={`h-4 w-4 transition-transform ${open ? "rotate-180" : ""}`}>
      <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.938a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06Z" clipRule="evenodd" />
    </svg>
  );
}

function initials(username?: string | null) {
  return (username || "U")
    .split(/[ ._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() || "/";
  const { username, logout } = useAuth();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const activeGroup = NAV.find((group) => group.items.some((item) => isActive(pathname, item.href)))?.label;
  const [openGroups, setOpenGroups] = useState<Set<string>>(() => new Set([activeGroup || "Market"]));

  const flat = useMemo(() => NAV.flatMap((group) => group.items), []);
  const activeLabel = flat.find((item) => isActive(pathname, item.href))?.label;

  useEffect(() => {
    setMobileOpen(false);
    if (activeGroup) {
      setOpenGroups((current) => new Set(current).add(activeGroup));
    }
  }, [activeGroup, pathname]);

  useEffect(() => {
    if (!mobileOpen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [mobileOpen]);

  const toggleGroup = (label: string) => {
    setOpenGroups((current) => {
      const next = new Set(current);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  };

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_right,_rgba(224,231,255,0.8),_transparent_32rem),linear-gradient(180deg,#f8faff_0%,#f8fafc_42%,#f8fafc_100%)] text-slate-800">
      {mobileOpen ? (
        <button type="button" className="fixed inset-0 z-40 bg-slate-950/40 backdrop-blur-[1px] md:hidden" aria-label="Close navigation" onClick={() => setMobileOpen(false)} />
      ) : null}

      <div className="flex min-w-0">
        <aside
          className={[
            "fixed left-0 top-0 z-50 flex h-dvh w-[min(22rem,calc(100vw-1rem))] flex-col overflow-hidden border-r border-slate-200/90 bg-white/95 shadow-2xl backdrop-blur transition-[width,transform] duration-200 ease-out",
            "md:sticky md:z-30 md:h-screen md:shrink-0 md:bg-white/90 md:shadow-none",
            mobileOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0",
            collapsed ? "md:w-[76px]" : "md:w-[288px]",
          ].join(" ")}
        >
          <div className="flex h-16 shrink-0 items-center justify-between border-b border-slate-200/90 px-4">
            <Link href="/" className="flex min-w-0 items-center gap-3" aria-label="Stocks AU home">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-indigo-600 text-xs font-bold tracking-tight text-white shadow-sm">SA</span>
              <span className={collapsed ? "md:hidden" : ""}>
                <span className="block text-sm font-bold tracking-tight text-slate-900">Stocks AU</span>
                <span className="block text-[10px] font-medium uppercase tracking-[0.16em] text-slate-400">Market workspace</span>
              </span>
            </Link>
            <button type="button" onClick={() => setCollapsed((value) => !value)} className="hidden rounded-md p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700 md:inline-flex" aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}>
              <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4"><path fillRule="evenodd" d={collapsed ? "M7.21 14.77a.75.75 0 0 1 .02-1.06L10.94 10 7.23 6.29a.75.75 0 0 1 1.06-1.06l4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.75.75 0 0 1-1.06-.02Z" : "M12.79 5.23a.75.75 0 0 1-.02 1.06L9.06 10l3.71 3.71a.75.75 0 1 1-1.06 1.06l-4.25-4.25a.75.75 0 0 1 0-1.06l4.25-4.25a.75.75 0 0 1 1.06.02Z"} clipRule="evenodd" /></svg>
            </button>
            <button type="button" onClick={() => setMobileOpen(false)} className="rounded-md px-2 py-1.5 text-xs font-medium text-slate-500 hover:bg-slate-100 hover:text-slate-900 md:hidden" aria-label="Close navigation">Close</button>
          </div>

          <nav id="primary-navigation" className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-5 text-sm">
            {NAV.map((group) => {
              const open = openGroups.has(group.label);
              const active = group.items.some((item) => isActive(pathname, item.href));
              return (
                <div key={group.label} className="mb-3">
                  <button
                    type="button"
                    onClick={() => toggleGroup(group.label)}
                    className={["flex w-full items-center gap-2 rounded-lg px-2 py-2 text-[11px] font-bold uppercase tracking-[0.12em] transition-colors", active ? "text-indigo-700" : "text-slate-400 hover:bg-slate-50 hover:text-slate-700", collapsed ? "md:justify-center" : ""].join(" ")}
                    aria-expanded={open}
                    aria-label={`${open ? "Collapse" : "Expand"} ${group.label}`}
                    title={group.label}
                  >
                    <NavIcon group={group.label} />
                    <span className={collapsed ? "md:hidden" : ""}>{group.label}</span>
                    <span className={collapsed ? "md:hidden" : "ml-auto"}><Chevron open={open} /></span>
                  </button>
                  {open ? (
                    <div className="mt-1 space-y-0.5">
                      {group.items.map((item) => {
                        const itemActive = isActive(pathname, item.href);
                        return (
                          <Link
                            key={item.href}
                            href={item.href}
                            aria-current={itemActive ? "page" : undefined}
                            className={["group relative flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-[13px] transition-colors", collapsed ? "md:justify-center md:px-0" : "", itemActive ? "bg-indigo-50 font-semibold text-indigo-700" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"].join(" ")}
                            title={item.label}
                          >
                            <span className={["h-1.5 w-1.5 shrink-0 rounded-full transition-colors", itemActive ? "bg-indigo-600" : "bg-slate-300 group-hover:bg-slate-500", collapsed ? "md:hidden" : ""].join(" ")} />
                            <span className={collapsed ? "md:hidden" : "truncate"}>{item.label}</span>
                            {collapsed ? <span className="hidden text-[10px] font-semibold text-slate-500 md:inline">{item.label.slice(0, 2).toUpperCase()}</span> : null}
                          </Link>
                        );
                      })}
                    </div>
                  ) : null}
                </div>
              );
            })}
          </nav>

          <div className={`border-t border-slate-200/90 p-3 ${collapsed ? "md:flex md:justify-center" : ""}`}>
            <div className={`flex items-center gap-2 rounded-lg bg-slate-50 px-2.5 py-2 ${collapsed ? "md:bg-transparent md:px-0" : ""}`}>
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-slate-200 text-[10px] font-bold text-slate-600">{initials(username)}</span>
              <span className={collapsed ? "md:hidden" : "min-w-0"}><span className="block truncate text-xs font-semibold text-slate-700">{username || "Signed in"}</span><span className="block text-[10px] text-slate-400">Authenticated</span></span>
            </div>
          </div>
        </aside>

        <div className="min-w-0 flex-1">
          <header className="sticky top-0 z-40 h-16 border-b border-slate-200/90 bg-white/85 backdrop-blur-xl">
            <div className="mx-auto flex h-16 max-w-[1600px] items-center justify-between gap-3 px-4 sm:px-6 lg:px-8">
              <div className="flex min-w-0 items-center gap-3">
                <button type="button" onClick={() => setMobileOpen(true)} className="inline-flex shrink-0 items-center justify-center rounded-lg border border-slate-200 bg-white p-2 text-slate-600 shadow-sm hover:bg-slate-50 md:hidden" aria-label="Open navigation" aria-controls="primary-navigation" aria-expanded={mobileOpen}>
                  <svg aria-hidden="true" viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4"><path fillRule="evenodd" d="M3 5.25A.75.75 0 0 1 3.75 4.5h12.5a.75.75 0 0 1 0 1.5H3.75A.75.75 0 0 1 3 5.25Zm0 4.75a.75.75 0 0 1 .75-.75h12.5a.75.75 0 0 1 0 1.5H3.75A.75.75 0 0 1 3 10Zm0 4.75a.75.75 0 0 1 .75-.75h12.5a.75.75 0 0 1 0 1.5H3.75a.75.75 0 0 1-.75-.75Z" clipRule="evenodd" /></svg>
                </button>
                <div className="flex min-w-0 items-center gap-2 text-sm">
                  <span className="hidden font-semibold text-slate-400 sm:inline">Workspace</span>
                  <span className="hidden text-slate-300 sm:inline">/</span>
                  <span className="truncate font-semibold text-slate-900">{activeLabel || "Stocks AU"}</span>
                </div>
              </div>
              <div className="flex shrink-0 items-center gap-3">
                <span className="hidden items-center gap-1.5 rounded-full border border-emerald-100 bg-emerald-50 px-2.5 py-1 text-[11px] font-medium text-emerald-700 sm:inline-flex"><span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />Workspace ready</span>
                <button type="button" onClick={logout} className="rounded-lg px-2.5 py-1.5 text-xs font-medium text-slate-500 hover:bg-red-50 hover:text-red-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500" title="Sign out">Logout</button>
              </div>
            </div>
          </header>

          <main className="mx-auto max-w-[1600px] px-4 py-6 sm:px-6 sm:py-8 lg:px-8">{children}</main>
        </div>
      </div>
    </div>
  );
}
