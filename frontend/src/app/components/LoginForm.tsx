"use client";

import { useState } from "react";
import { useAuth } from "../contexts/AuthContext";

export default function LoginForm() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setError("");
    const success = await login(username, password);
    if (!success) setError("Invalid username or password");
    setLoading(false);
  };

  return (
    <main className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top_right,_rgba(224,231,255,0.9),_transparent_30rem),#f8fafc] px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-indigo-600 text-sm font-bold tracking-tight text-white shadow-lg shadow-indigo-600/20">SA</div>
          <h1 className="mt-4 text-2xl font-bold tracking-tight text-slate-950">Stocks AU</h1>
          <p className="mt-1 text-sm text-slate-500">Your market analysis workspace</p>
        </div>

        <form onSubmit={handleSubmit} className="rounded-2xl border border-slate-200 bg-white p-6 shadow-xl shadow-slate-200/50 sm:p-8" suppressHydrationWarning>
          <div className="mb-6">
            <h2 className="text-lg font-bold text-slate-950">Welcome back</h2>
            <p className="mt-1 text-sm text-slate-500">Sign in to access your dashboard.</p>
          </div>

          <div className="space-y-4">
            <div>
              <label htmlFor="username" className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-slate-600">Username</label>
              <input id="username" type="text" value={username} onChange={(event) => setUsername(event.target.value)} required autoComplete="username" className="h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm shadow-sm placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20" placeholder="Enter your username" suppressHydrationWarning />
            </div>
            <div>
              <label htmlFor="password" className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-slate-600">Password</label>
              <div className="relative">
                <input id="password" type={showPassword ? "text" : "password"} value={password} onChange={(event) => setPassword(event.target.value)} required autoComplete="current-password" className="h-11 w-full rounded-lg border border-slate-300 bg-white px-3 pr-20 text-sm shadow-sm placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20" placeholder="Enter your password" suppressHydrationWarning />
                <button type="button" onClick={() => setShowPassword((value) => !value)} className="absolute inset-y-0 right-0 px-3 text-xs font-semibold text-slate-500 hover:text-indigo-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500" aria-label={showPassword ? "Hide password" : "Show password"}>{showPassword ? "Hide" : "Show"}</button>
              </div>
            </div>
          </div>

          {error ? <div role="alert" className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-700">{error}</div> : null}
          <button type="submit" disabled={loading} className="mt-6 flex h-11 w-full items-center justify-center rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-indigo-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50">{loading ? "Signing in..." : "Sign in"}</button>
        </form>
        <p className="mt-5 text-center text-xs text-slate-400">Secure access to your market tools and research.</p>
      </div>
    </main>
  );
}
