import type { Metadata } from "next";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

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
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased bg-gradient-to-b from-sky-50 via-white to-white text-slate-800`}>
        <header className="fixed inset-x-0 top-0 z-50 bg-white/80 backdrop-blur border-b border-slate-200 shadow-sm">
          <nav className="mx-auto max-w-7xl px-6 h-14 flex items-center justify-between">
            <Link href="/" className="font-semibold tracking-tight bg-gradient-to-r from-sky-600 to-blue-600 bg-clip-text text-transparent">
              Stocks AU
            </Link>
            <div className="flex gap-6 text-sm text-slate-700">
              <Link href="/order-book" className="hover:text-slate-900">Order Book</Link>
              <Link href="/ta-scan" className="hover:text-slate-900">TA Scan</Link>
            </div>
          </nav>
        </header>
        <main className="pt-16">{children}</main>
      </body>
    </html>
  );
}
