"use client";

import { useEffect, useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import LoginForm from "./LoginForm";

export default function AuthWrapper({ children }: { children: React.ReactNode }) {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const { isAuthenticated, loading } = useAuth();

  if (!mounted || loading) {
    return <div className="flex min-h-screen items-center justify-center bg-slate-50"><div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-200 border-t-indigo-600" /></div>;
  }
  if (!isAuthenticated) return <LoginForm />;
  return <>{children}</>;
}
