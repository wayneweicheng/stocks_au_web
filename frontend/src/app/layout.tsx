import type { Metadata } from "next";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "./contexts/AuthContext";
import AuthWrapper from "./components/AuthWrapper";
import NavigationMenu from "./components/NavigationMenu";
import ClientLayout from "./components/ClientLayout";

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
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased bg-gradient-to-b from-emerald-50 via-white to-white text-slate-800" suppressHydrationWarning>
        <ClientLayout geistSans={geistSans} geistMono={geistMono}>
          <AuthProvider>
            <AuthWrapper>
              <header className="fixed inset-x-0 top-0 z-50 bg-white/80 backdrop-blur border-b border-slate-200 shadow-sm">
                <nav className="mx-auto max-w-7xl px-6 h-14 flex items-center justify-between">
                  <Link href="/" className="font-semibold tracking-tight bg-gradient-to-r from-emerald-600 to-green-600 bg-clip-text text-transparent">
                    Stocks AU
                  </Link>
                  <NavigationMenu />
                </nav>
              </header>
              <main className="pt-16">{children}</main>
            </AuthWrapper>
          </AuthProvider>
        </ClientLayout>
      </body>
    </html>
  );
}
