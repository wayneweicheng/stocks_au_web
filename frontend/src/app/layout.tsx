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
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased bg-[radial-gradient(125%_125%_at_50%_10%,#0b1220_40%,#111827_70%,#0b1220_100%)] text-slate-100`}>
        <header className="fixed inset-x-0 top-0 z-50 backdrop-blur supports-[backdrop-filter]:bg-white/5 border-b border-white/10">
          <nav className="mx-auto max-w-7xl px-6 h-14 flex items-center justify-between">
            <Link href="/" className="font-semibold tracking-tight text-white">
              Stocks AU
            </Link>
            <div className="flex gap-6 text-sm text-slate-200">
              <Link href="/order-book" className="hover:text-white">Order Book</Link>
              <Link href="/ta-scan" className="hover:text-white">TA Scan</Link>
            </div>
          </nav>
        </header>
        <main className="pt-16">{children}</main>
      </body>
    </html>
  );
}
