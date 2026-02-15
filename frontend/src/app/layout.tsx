import type { Metadata } from "next";
import { Suspense } from "react";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "./contexts/AuthContext";
import AuthWrapper from "./components/AuthWrapper";
import ClientLayout from "./components/ClientLayout";
import NavigationProgress from "./components/NavigationProgress";
import AppShell from "./components/AppShell";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Stocks AU Dashboard",
  description: "ASX tools – Next.js + FastAPI",
  icons: {
    icon: "/icon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased text-slate-800" suppressHydrationWarning>
        <Suspense fallback={null}>
          <NavigationProgress />
        </Suspense>
        <ClientLayout geistSans={geistSans} geistMono={geistMono}>
          <AuthProvider>
            <AuthWrapper>
              <AppShell>{children}</AppShell>
            </AuthWrapper>
          </AuthProvider>
        </ClientLayout>
      </body>
    </html>
  );
}
