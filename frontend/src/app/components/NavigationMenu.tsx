"use client";

import Link from "next/link";
import { useAuth } from '../contexts/AuthContext';

export default function NavigationMenu() {
  const { username, logout } = useAuth();

  return (
    <div className="flex gap-6 text-sm text-slate-700 items-center">
      <div className="relative group">
        <button className="hover:text-slate-900 focus:outline-none">
          Tools
          <svg className="w-4 h-4 inline ml-1 transition-transform group-hover:rotate-180" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
          </svg>
        </button>
        <div className="absolute top-full left-0 mt-2 w-64 bg-white border border-slate-200 rounded-md shadow-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50">
          <div className="py-2">
            <Link href="/order-book" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Order Book</Link>
            <Link href="/ta-scan" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">TA Scan</Link>
            <Link href="/pllrs-scanner" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">PLLRS Scanner</Link>
            <Link href="/pegasus-invest-opportunities" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Pegasus Invest Opportunities</Link>
            <Link href="/monitor-stocks" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Monitor Stocks</Link>
            <Link href="/conditional-orders" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Conditional Orders</Link>
            <Link href="/pattern-predictions" className="block px-4 py-2 text-slate-700 hover:bg-emerald-50 hover:text-slate-900">Pattern Predictions</Link>
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