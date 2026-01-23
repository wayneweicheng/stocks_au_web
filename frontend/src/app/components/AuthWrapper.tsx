"use client";

import { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import LoginForm from './LoginForm';

export default function AuthWrapper({ children }: { children: React.ReactNode }) {
  // Mount guard to ensure identical SSR and initial client markup (prevents hydration mismatch)
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    setMounted(true);
  }, []);

  const { isAuthenticated, loading } = useAuth();

  // During SSR and initial client hydration, render the same static loading shell
  if (!mounted || loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-300 border-t-emerald-500" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <LoginForm />;
  }

  return <>{children}</>;
}