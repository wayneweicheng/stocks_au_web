"use client";

import Link from "next/link";
import { useAuth } from '../contexts/AuthContext';

import { useState } from "react";

export default function NavigationMenu() {
  const { username, logout } = useAuth();
  const [open, setOpen] = useState(false);

  return (
    <div className="flex gap-6 text-sm text-slate-700 items-center">
      <div className="relative">
        <button
          className="hover:text-slate-900 focus:outline-none"
          onClick={() => setOpen((v) => !v)}
          aria-haspopup="menu"
          aria-expanded={open}
        >
          Tools
          <svg className={`w-4 h-4 inline ml-1 transition-transform ${open ? "rotate-180" : ""}`} fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
          </svg>
        </button>
        <div className={`absolute top-full left-0 mt-2 w-64 bg-white border border-slate-200 rounded-md shadow-lg transition-all duration-200 z-50 ${open ? "opacity-100 visible" : "opacity-0 invisible"}`}>
          <div className="py-2" role="menu">
            <Link onClick={() => setOpen(false)} href="/order-book" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Order Book</Link>
            <Link onClick={() => setOpen(false)} href="/ta-scan" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">TA Scan</Link>
            <Link onClick={() => setOpen(false)} href="/pllrs-scanner" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">PLLRS Scanner</Link>
            <Link onClick={() => setOpen(false)} href="/pegasus-invest-opportunities" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Pegasus Invest Opportunities</Link>
            <Link onClick={() => setOpen(false)} href="/research-reports" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Research Reports</Link>
            <Link onClick={() => setOpen(false)} href="/monitor-stocks" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Monitor Stocks</Link>
            <Link onClick={() => setOpen(false)} href="/conditional-orders" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Conditional Orders</Link>
            <Link onClick={() => setOpen(false)} href="/strategy-orders" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Strategy Orders</Link>
            <Link onClick={() => setOpen(false)} href="/pattern-predictions" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Pattern Predictions</Link>
            <Link onClick={() => setOpen(false)} href="/ib-gateway" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">IB Gateway</Link>
            <Link onClick={() => setOpen(false)} href="/range-orders" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Price Range Orders</Link>
          </div>
        </div>
      </div>

      <span className="text-xs text-slate-500">Welcome, {username}</span>

      <button
        onClick={logout}
        className="text-xs text-slate-500 hover:text-red-600 focus:outline-none"
      >
        Logout
      </button>
    </div>
  );
}