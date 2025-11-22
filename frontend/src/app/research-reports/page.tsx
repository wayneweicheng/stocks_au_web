"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type ResearchLink = {
  id: number;
  stock_code: string;
  url: string;
  added_at: string; // ISO string
  added_by?: string | null;
};

type ResearchLinkPage = {
  items: ResearchLink[];
  total: number;
  page: number;
  page_size: number;
};

const ITEMS_PER_PAGE = 10;

function validateUrl(urlStr: string): boolean {
  try {
    const u = new URL(urlStr);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
}

export default function ResearchReportsPage() {
  const [items, setItems] = useState<ResearchLink[]>([]);
  const [total, setTotal] = useState(0);
  const [stockCodeInput, setStockCodeInput] = useState("");
  const [urlInput, setUrlInput] = useState("");
  const [error, setError] = useState<string>("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);

  async function fetchPage(nextPage: number, q: string) {
    setLoading(true);
    try {
      const url = `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links?page=${nextPage}&page_size=${ITEMS_PER_PAGE}${q ? `&q=${encodeURIComponent(q)}` : ""}`;
      const res = await authenticatedFetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: ResearchLinkPage = await res.json();
      setItems(data.items || []);
      setTotal(data.total || 0);
    } catch (e: any) {
      setError(e.message || "Failed to load");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchPage(page, search);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, search]);

  const totalPages = Math.max(1, Math.ceil(total / ITEMS_PER_PAGE));
  const currentPage = Math.min(page, totalPages);

  function resetForm() {
    setStockCodeInput("");
    setUrlInput("");
    setError("");
  }

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    const stock = stockCodeInput.trim().toUpperCase();
    const url = urlInput.trim();
    if (!stock) {
      setError("Please enter a stock code (e.g., LLM.IN).");
      return;
    }
    if (!validateUrl(url)) {
      setError("Please enter a valid http(s) URL.");
      return;
    }
    try {
      const res = await authenticatedFetch(`${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ stock_code: stock, url }),
      });
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      resetForm();
      setPage(1);
      await fetchPage(1, search);
    } catch (e: any) {
      setError(e.message || "Failed to add");
    }
  }

  return (
    <div className="mx-auto max-w-5xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-semibold tracking-tight bg-gradient-to-r from-emerald-600 to-green-700 bg-clip-text text-transparent">
          Stock Research Reports
        </h1>
        <p className="mt-2 text-sm text-slate-600">
          Add a stock code (e.g., LLM.IN) and a link to a published research
          report. Entries are saved on the server and listed below.
        </p>
      </header>

      <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-medium mb-4">Add research link</h2>
        <form onSubmit={handleAdd} className="grid gap-4 sm:grid-cols-12">
          <div className="sm:col-span-3">
            <label htmlFor="stock" className="block text-xs font-medium text-slate-600 mb-1">
              Stock code
            </label>
            <input
              id="stock"
              type="text"
              value={stockCodeInput}
              onChange={(e) => setStockCodeInput(e.target.value)}
              placeholder="NVDA.US"
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
          </div>
          <div className="sm:col-span-7">
            <label htmlFor="url" className="block text-xs font-medium text-slate-600 mb-1">
              Research report URL
            </label>
            <input
              id="url"
              type="url"
              value={urlInput}
              onChange={(e) => setUrlInput(e.target.value)}
              placeholder="https://example.com/your-report"
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
          </div>
          <div className="sm:col-span-2 flex items-end">
            <button
              type="submit"
              className="w-full rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-4 py-2 text-sm hover:opacity-90"
            >
              Add
            </button>
          </div>
        </form>
        {error && <div className="mt-3 text-sm text-red-600">{error}</div>}
      </section>

      <section className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
          <h2 className="text-lg font-medium">Saved reports</h2>
          <div className="sm:w-80">
            <input
              type="text"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              placeholder="Search by stock code (e.g., LLM)"
              className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left text-slate-600 border-b border-slate-200">
                <th className="py-2 pr-3 font-medium">Added</th>
                <th className="py-2 px-3 font-medium">Stock</th>
                <th className="py-2 px-3 font-medium">Research link</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-slate-500">
                    Loading...
                  </td>
                </tr>
              ) : items.length === 0 ? (
                <tr>
                  <td colSpan={3} className="py-6 text-center text-slate-500">
                    No reports found.
                  </td>
                </tr>
              ) : (
                items.map((r) => (
                  <tr key={r.id} className="border-b last:border-b-0 border-slate-100">
                    <td className="py-2 pr-3 align-top text-slate-700">
                      {new Date(r.added_at).toLocaleString()}
                    </td>
                    <td className="py-2 px-3 align-top font-medium">{r.stock_code}</td>
                    <td className="py-2 px-3 align-top">
                      <a
                        href={r.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-emerald-700 hover:underline break-all"
                      >
                        {r.url}
                      </a>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex items-center justify-between text-sm">
          <div className="text-slate-600">
            Showing {items.length} of {total} result{total === 1 ? "" : "s"}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1 || loading}
              className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
            >
              Prev
            </button>
            <span className="px-2">
              Page {currentPage} / {totalPages}
            </span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage >= totalPages || loading}
              className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}


