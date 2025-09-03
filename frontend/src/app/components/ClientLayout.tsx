"use client";

import { useEffect } from "react";

interface ClientLayoutProps {
  children: React.ReactNode;
  geistSans: any;
  geistMono: any;
}

export default function ClientLayout({ children, geistSans, geistMono }: ClientLayoutProps) {
  useEffect(() => {
    // Apply font variables on client-side only to prevent hydration mismatch
    document.documentElement.classList.add(geistSans.variable, geistMono.variable);
  }, [geistSans.variable, geistMono.variable]);

  return <>{children}</>;
}