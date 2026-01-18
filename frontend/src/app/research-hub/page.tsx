"use client";

import { useEffect, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

// Types
type Commenter = {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
  is_active: boolean;
};

type CommenterList = {
  items: Commenter[];
  total: number;
};

type StockRating = {
  id: number;
  stock_code: string;
  commenter_id: number;
  commenter_name: string;
  rating: "Bullish" | "Neutral" | "Bearish";
  comment: string | null;
  rating_date: string;
  added_at: string;
  added_by: string | null;
};

type StockSummary = {
  stock_code: string;
  total_ratings: number;
  bullish_count: number;
  neutral_count: number;
  bearish_count: number;
  ratings: StockRating[];
};

type TippedStock = {
  stock_code: string;
  total_ratings: number;
  bullish_count: number;
  bullish_commenters_count: number;
  neutral_count: number;
  bearish_count: number;
  latest_rating_date: string;
};

type TippedStocksList = {
  items: TippedStock[];
  total: number;
  page: number;
  page_size: number;
};

type ResearchLink = {
  id: number;
  stock_code: string;
  url: string;
  added_at: string;
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

function getRatingColor(rating: string): string {
  switch (rating) {
    case "Bullish":
      return "bg-green-100 text-green-800";
    case "Bearish":
      return "bg-red-100 text-red-800";
    default:
      return "bg-gray-100 text-gray-800";
  }
}

export default function ResearchHubPage() {
  // Tab state
  const [activeTab, setActiveTab] = useState<"ratings" | "links" | "commenters" | "lookup">("ratings");

  // Commenter state
  const [commenters, setCommenters] = useState<Commenter[]>([]);
  const [newCommenterName, setNewCommenterName] = useState("");
  const [newCommenterDesc, setNewCommenterDesc] = useState("");
  const [commenterError, setCommenterError] = useState("");
  const [commenterLoading, setCommenterLoading] = useState(false);

  // Stock rating state
  const [ratingStockCode, setRatingStockCode] = useState("");
  const [ratingCommenterId, setRatingCommenterId] = useState<number | "">("");
  const [ratingValue, setRatingValue] = useState<"Bullish" | "Neutral" | "Bearish">("Bullish");
  const [ratingComment, setRatingComment] = useState("");
  const [ratingDate, setRatingDate] = useState(() => new Date().toISOString().split("T")[0]);
  const [ratingError, setRatingError] = useState("");
  const [ratingLoading, setRatingLoading] = useState(false);

  // Stock lookup state
  const [lookupStockCode, setLookupStockCode] = useState("");
  const [stockSummary, setStockSummary] = useState<StockSummary | null>(null);
  const [stockLinks, setStockLinks] = useState<ResearchLink[]>([]);
  const [lookupError, setLookupError] = useState("");
  const [lookupLoading, setLookupLoading] = useState(false);

  // Tipped stocks state
  const [tippedStocks, setTippedStocks] = useState<TippedStock[]>([]);
  const [tippedTotal, setTippedTotal] = useState(0);
  const [tippedPage, setTippedPage] = useState(1);
  const TIPPED_PAGE_SIZE = 30;
  const [tippedSortBy, setTippedSortBy] = useState<"bullish_commenters" | "latest">("bullish_commenters");
  const [tippedSortDir, setTippedSortDir] = useState<"asc" | "desc">("desc");
  const [tippedStocksLoading, setTippedStocksLoading] = useState(false);
  const [deleteTargetCode, setDeleteTargetCode] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");

  // Research links state
  const [links, setLinks] = useState<ResearchLink[]>([]);
  const [linksTotal, setLinksTotal] = useState(0);
  const [linkStockCode, setLinkStockCode] = useState("");
  const [linkUrl, setLinkUrl] = useState("");
  const [linkSearch, setLinkSearch] = useState("");
  const [linkPage, setLinkPage] = useState(1);
  const [linkError, setLinkError] = useState("");
  const [linkLoading, setLinkLoading] = useState(false);
  const [linkDeleteTargetId, setLinkDeleteTargetId] = useState<number | null>(null);
  const [linkDeleting, setLinkDeleting] = useState(false);
  const [linkDeleteError, setLinkDeleteError] = useState("");

  // Fetch commenters
  async function fetchCommenters() {
    setCommenterLoading(true);
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/commenters`
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: CommenterList = await res.json();
      setCommenters(data.items || []);
    } catch (e: any) {
      setCommenterError(e.message || "Failed to load commenters");
    } finally {
      setCommenterLoading(false);
    }
  }

  // Fetch tipped stocks
  async function fetchTippedStocks(nextPage: number, sortBy: "bullish_commenters" | "latest", sortDir: "asc" | "desc") {
    setTippedStocksLoading(true);
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/stock-ratings/tipped-stocks?page=${nextPage}&page_size=${TIPPED_PAGE_SIZE}&sort_by=${encodeURIComponent(
          sortBy
        )}&sort_dir=${encodeURIComponent(sortDir)}`
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: TippedStocksList = await res.json();
      setTippedStocks(data.items || []);
      setTippedTotal(data.total || 0);
    } catch (e: any) {
      console.error("Failed to load tipped stocks:", e);
    } finally {
      setTippedStocksLoading(false);
    }
  }

  // Fetch research links
  async function fetchLinks(nextPage: number, q: string) {
    setLinkLoading(true);
    try {
      const url = `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links?page=${nextPage}&page_size=${ITEMS_PER_PAGE}${q ? `&q=${encodeURIComponent(q)}` : ""}`;
      const res = await authenticatedFetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: ResearchLinkPage = await res.json();
      setLinks(data.items || []);
      setLinksTotal(data.total || 0);
    } catch (e: any) {
      setLinkError(e.message || "Failed to load");
    } finally {
      setLinkLoading(false);
    }
  }

  useEffect(() => {
    fetchCommenters();
  }, []);

  useEffect(() => {
    if (activeTab === "lookup") {
      fetchTippedStocks(tippedPage, tippedSortBy, tippedSortDir);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, tippedPage, tippedSortBy, tippedSortDir]);

  useEffect(() => {
    if (activeTab === "links") {
      fetchLinks(linkPage, linkSearch);
    }
  }, [activeTab, linkPage, linkSearch]);

  // Add commenter
  async function handleAddCommenter(e: React.FormEvent) {
    e.preventDefault();
    setCommenterError("");
    const name = newCommenterName.trim();
    if (!name) {
      setCommenterError("Please enter a name.");
      return;
    }
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/commenters`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            name,
            description: newCommenterDesc.trim() || null,
          }),
        }
      );
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      setNewCommenterName("");
      setNewCommenterDesc("");
      await fetchCommenters();
    } catch (e: any) {
      setCommenterError(e.message || "Failed to add");
    }
  }

  // Add stock rating
  async function handleAddRating(e: React.FormEvent) {
    e.preventDefault();
    setRatingError("");
    const stock = ratingStockCode.trim().toUpperCase();
    if (!stock) {
      setRatingError("Please enter a stock code (e.g., PLS.AX or NVDA.US).");
      return;
    }
    if (!ratingCommenterId) {
      setRatingError("Please select a commenter.");
      return;
    }
    try {
      setRatingLoading(true);
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/stock-ratings`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            stock_code: stock,
            commenter_id: ratingCommenterId,
            rating: ratingValue,
            comment: ratingComment.trim() || null,
            rating_date: ratingDate,
          }),
        }
      );
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      setRatingStockCode("");
      setRatingCommenterId("");
      setRatingComment("");
      setRatingDate(new Date().toISOString().split("T")[0]);
    } catch (e: any) {
      setRatingError(e.message || "Failed to add rating");
    } finally {
      setRatingLoading(false);
    }
  }

  // Add research link
  async function handleAddLink(e: React.FormEvent) {
    e.preventDefault();
    setLinkError("");
    const stock = linkStockCode.trim().toUpperCase();
    const url = linkUrl.trim();
    if (!stock) {
      setLinkError("Please enter a stock code (e.g., PLS.AX).");
      return;
    }
    if (!validateUrl(url)) {
      setLinkError("Please enter a valid http(s) URL.");
      return;
    }
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ stock_code: stock, url }),
        }
      );
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      setLinkStockCode("");
      setLinkUrl("");
      setLinkPage(1);
      await fetchLinks(1, linkSearch);
    } catch (e: any) {
      setLinkError(e.message || "Failed to add");
    }
  }

  // Lookup stock
  async function handleLookupStock(e: React.FormEvent) {
    e.preventDefault();
    await lookupStock(lookupStockCode);
  }

  // Lookup stock by code (can be called from form or by clicking a tipped stock)
  async function lookupStock(code: string) {
    setLookupError("");
    setStockSummary(null);
    setStockLinks([]);
    const stock = code.trim().toUpperCase();
    if (!stock) {
      setLookupError("Please enter a stock code.");
      return;
    }
    setLookupStockCode(stock);
    setLookupLoading(true);
    try {
      // Fetch ratings summary
      const ratingsRes = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/stock-ratings/summary/${encodeURIComponent(stock)}`
      );
      if (!ratingsRes.ok) throw new Error(`HTTP ${ratingsRes.status}`);
      const summary: StockSummary = await ratingsRes.json();
      setStockSummary(summary);

      // Fetch research links for this stock
      const linksRes = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links?q=${encodeURIComponent(stock)}&page_size=100`
      );
      if (linksRes.ok) {
        const linksData: ResearchLinkPage = await linksRes.json();
        setStockLinks(linksData.items || []);
      }
    } catch (e: any) {
      setLookupError(e.message || "Failed to lookup stock");
    } finally {
      setLookupLoading(false);
    }
  }

  const linkTotalPages = Math.max(1, Math.ceil(linksTotal / ITEMS_PER_PAGE));
  const linkCurrentPage = Math.min(linkPage, linkTotalPages);

  const tippedTotalPages = Math.max(1, Math.ceil(tippedTotal / TIPPED_PAGE_SIZE));
  const tippedCurrentPage = Math.min(tippedPage, tippedTotalPages);

  async function handleConfirmDelete() {
    if (!deleteTargetCode) return;
    setDeleting(true);
    setDeleteError("");
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/stock-ratings/tipped-stocks/${encodeURIComponent(deleteTargetCode)}`,
        { method: "DELETE" }
      );
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      setDeleteTargetCode(null);
      // Refresh current page; if becomes empty and not first page, go back one page
      await fetchTippedStocks(tippedPage, tippedSortBy, tippedSortDir);
      if (tippedStocks.length === 1 && tippedPage > 1) {
        setTippedPage(tippedPage - 1);
      }
    } catch (e: any) {
      setDeleteError(e.message || "Failed to delete");
    } finally {
      setDeleting(false);
    }
  }

  async function handleConfirmDeleteLink() {
    if (!linkDeleteTargetId) return;
    setLinkDeleting(true);
    setLinkDeleteError("");
    try {
      const res = await authenticatedFetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL}/api/research-links/${linkDeleteTargetId}`,
        { method: "DELETE" }
      );
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      setLinkDeleteTargetId(null);
      await fetchLinks(linkPage, linkSearch);
      if (links.length === 1 && linkPage > 1) {
        setLinkPage(linkPage - 1);
      }
    } catch (e: any) {
      setLinkDeleteError(e.message || "Failed to delete");
    } finally {
      setLinkDeleting(false);
    }
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-semibold tracking-tight bg-gradient-to-r from-emerald-600 to-green-700 bg-clip-text text-transparent">
          Research Hub
        </h1>
        <p className="mt-2 text-sm text-slate-600">
          Track analyst ratings, manage commenters, and save research links for stocks.
        </p>
      </header>

      {/* Tab Navigation */}
      <div className="mb-6 border-b border-slate-200">
        <nav className="flex gap-6">
          {[
            { key: "ratings", label: "Add Rating" },
            { key: "lookup", label: "Stock Lookup" },
            { key: "links", label: "Research Links" },
            { key: "commenters", label: "Manage Commenters" },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key as any)}
              className={`pb-3 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.key
                  ? "border-emerald-600 text-emerald-700"
                  : "border-transparent text-slate-600 hover:text-slate-900"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* Add Rating Tab */}
      {activeTab === "ratings" && (
        <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-medium mb-4">Add Stock Rating</h2>
          <form onSubmit={handleAddRating} className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Stock Code
                </label>
                <input
                  type="text"
                  value={ratingStockCode}
                  onChange={(e) => setRatingStockCode(e.target.value)}
                  placeholder="PLS.AX or NVDA.US"
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Commenter
                </label>
                <select
                  value={ratingCommenterId}
                  onChange={(e) =>
                    setRatingCommenterId(e.target.value ? parseInt(e.target.value) : "")
                  }
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="">Select commenter...</option>
                  {commenters.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Rating
                </label>
                <select
                  value={ratingValue}
                  onChange={(e) =>
                    setRatingValue(e.target.value as "Bullish" | "Neutral" | "Bearish")
                  }
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="Bullish">Bullish</option>
                  <option value="Neutral">Neutral</option>
                  <option value="Bearish">Bearish</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Rating Date
                </label>
                <input
                  type="date"
                  value={ratingDate}
                  onChange={(e) => setRatingDate(e.target.value)}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1">
                Comment (optional)
              </label>
              <textarea
                value={ratingComment}
                onChange={(e) => setRatingComment(e.target.value)}
                rows={3}
                placeholder="Any notes about this rating..."
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
            <div>
              <button
                type="submit"
                disabled={ratingLoading}
                className="rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-6 py-2 text-sm hover:opacity-90 disabled:opacity-50"
              >
                {ratingLoading ? "Adding..." : "Add Rating"}
              </button>
            </div>
            {ratingError && <div className="text-sm text-red-600">{ratingError}</div>}
          </form>
        </section>
      )}

      {/* Stock Lookup Tab */}
      {activeTab === "lookup" && (
        <section className="space-y-6">
          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-medium mb-4">Lookup Stock</h2>
            <form onSubmit={handleLookupStock} className="flex gap-3">
              <input
                type="text"
                value={lookupStockCode}
                onChange={(e) => setLookupStockCode(e.target.value)}
                placeholder="Enter stock code (e.g., PLS.AX)"
                className="flex-1 rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
              <button
                type="submit"
                disabled={lookupLoading}
                className="rounded-md bg-gradient-to-r from-emerald-600 to-green-600 text-white px-6 py-2 text-sm hover:opacity-90 disabled:opacity-50"
              >
                {lookupLoading ? "Loading..." : "Lookup"}
              </button>
            </form>
            {lookupError && <div className="mt-3 text-sm text-red-600">{lookupError}</div>}
          </div>

          {/* All Tipped Stocks */}
          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-medium mb-4">
              All Tipped Stocks
              {tippedTotal > 0 && (
                <span className="ml-2 text-sm font-normal text-slate-500">
                  ({tippedTotal} stocks)
                </span>
              )}
            </h2>
            {tippedStocksLoading ? (
              <div className="text-center text-slate-500 py-6">Loading...</div>
            ) : tippedStocks.length === 0 ? (
              <div className="text-center text-slate-500 py-6">
                No tipped stocks yet. Add ratings in the &quot;Add Rating&quot; tab.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="min-w-full text-sm">
                  <thead>
                    <tr className="text-left text-slate-600 border-b border-slate-200">
                      <th className="py-2 pr-3 font-medium">Stock</th>
                      <th className="py-2 px-3 font-medium text-center">Total</th>
                      <th className="py-2 px-3 font-medium text-center text-green-700">Bullish</th>
                      <th
                        className="py-2 px-3 font-medium text-center text-green-800 cursor-pointer select-none"
                        onClick={() => {
                          setTippedSortBy("bullish_commenters");
                          setTippedSortDir("desc"); // requirement: descending by number of bullish commenters
                          setTippedPage(1);
                        }}
                        title="Sort by number of distinct bullish commenters (desc)"
                      >
                        Bullish Commenters {tippedSortBy === "bullish_commenters" ? "▼" : ""}
                      </th>
                      <th className="py-2 px-3 font-medium text-center text-gray-600">Neutral</th>
                      <th className="py-2 px-3 font-medium text-center text-red-700">Bearish</th>
                      <th
                        className="py-2 px-3 font-medium cursor-pointer select-none"
                        onClick={() => {
                          setTippedSortBy("latest");
                          setTippedSortDir((d) => (tippedSortBy === "latest" ? (d === "desc" ? "asc" : "desc") : "desc"));
                          setTippedPage(1);
                        }}
                        title="Sort by latest rating date"
                      >
                        Latest {tippedSortBy === "latest" ? (tippedSortDir === "desc" ? "▼" : "▲") : ""}
                      </th>
                      <th className="py-2 px-3 font-medium text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tippedStocks.map((stock) => (
                      <tr
                        key={stock.stock_code}
                        onClick={() => lookupStock(stock.stock_code)}
                        className="border-b last:border-b-0 border-slate-100 cursor-pointer hover:bg-emerald-50 transition-colors"
                      >
                        <td className="py-2 pr-3 font-medium text-emerald-700">
                          {stock.stock_code}
                        </td>
                        <td className="py-2 px-3 text-center">{stock.total_ratings}</td>
                        <td className="py-2 px-3 text-center">
                          {stock.bullish_count > 0 && (
                            <span className="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              {stock.bullish_count}
                            </span>
                          )}
                        </td>
                        <td className="py-2 px-3 text-center">
                          {stock.bullish_commenters_count > 0 && (
                            <span className="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-green-200 text-green-900">
                              {stock.bullish_commenters_count}
                            </span>
                          )}
                        </td>
                        <td className="py-2 px-3 text-center">
                          {stock.neutral_count > 0 && (
                            <span className="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
                              {stock.neutral_count}
                            </span>
                          )}
                        </td>
                        <td className="py-2 px-3 text-center">
                          {stock.bearish_count > 0 && (
                            <span className="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                              {stock.bearish_count}
                            </span>
                          )}
                        </td>
                        <td className="py-2 px-3 text-slate-600 text-xs">
                          {stock.latest_rating_date}
                        </td>
                        <td className="py-2 px-3 text-right">
                          <button
                            className="rounded-md border border-red-300 text-red-700 px-3 py-1 text-xs hover:bg-red-50"
                            onClick={(e) => {
                              e.stopPropagation();
                              setDeleteError("");
                              setDeleteTargetCode(stock.stock_code);
                            }}
                            title="Delete this tipped stock and all associated ratings and research links"
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {/* Pagination for tipped stocks */}
            <div className="mt-4 flex items-center justify-between text-sm">
              <div className="text-slate-600">
                Showing {tippedStocks.length} of {tippedTotal} stock{tippedTotal === 1 ? "" : "s"}
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setTippedPage((p) => Math.max(1, p - 1))}
                  disabled={tippedCurrentPage === 1 || tippedStocksLoading}
                  className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
                >
                  Prev
                </button>
                <span className="px-2">
                  Page {tippedCurrentPage} / {tippedTotalPages}
                </span>
                <button
                  onClick={() => setTippedPage((p) => Math.min(tippedTotalPages, p + 1))}
                  disabled={tippedCurrentPage >= tippedTotalPages || tippedStocksLoading}
                  className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          </div>

          {/* Delete confirmation modal */}
          {deleteTargetCode && (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
              <div className="w-full max-w-md rounded-lg bg-white shadow-lg p-6">
                <h3 className="text-lg font-medium mb-2">Delete Tipped Stock</h3>
                <p className="text-sm text-slate-600">
                  You are about to delete <span className="font-semibold">{deleteTargetCode}</span>. This will permanently
                  remove all associated ratings and research reports for this stock. This action cannot be undone.
                </p>
                {deleteError && <div className="mt-3 text-sm text-red-600">{deleteError}</div>}
                <div className="mt-5 flex items-center justify-end gap-2">
                  <button
                    className="rounded-md border border-slate-300 px-4 py-2 text-sm"
                    onClick={() => (deleting ? null : setDeleteTargetCode(null))}
                    disabled={deleting}
                  >
                    Cancel
                  </button>
                  <button
                    className="rounded-md bg-red-600 text-white px-4 py-2 text-sm hover:opacity-90 disabled:opacity-50"
                    onClick={handleConfirmDelete}
                    disabled={deleting}
                  >
                    {deleting ? "Deleting..." : "Delete"}
                  </button>
                </div>
              </div>
            </div>
          )}

          {stockSummary && (
            <>
              {/* Summary Card */}
              <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
                <h3 className="text-lg font-medium mb-4">
                  {stockSummary.stock_code} - Rating Summary
                </h3>
                <div className="grid grid-cols-4 gap-4 text-center">
                  <div className="p-4 rounded-lg bg-slate-50">
                    <div className="text-2xl font-bold text-slate-800">
                      {stockSummary.total_ratings}
                    </div>
                    <div className="text-xs text-slate-600">Total Ratings</div>
                  </div>
                  <div className="p-4 rounded-lg bg-green-50">
                    <div className="text-2xl font-bold text-green-700">
                      {stockSummary.bullish_count}
                    </div>
                    <div className="text-xs text-green-600">Bullish</div>
                  </div>
                  <div className="p-4 rounded-lg bg-gray-50">
                    <div className="text-2xl font-bold text-gray-700">
                      {stockSummary.neutral_count}
                    </div>
                    <div className="text-xs text-gray-600">Neutral</div>
                  </div>
                  <div className="p-4 rounded-lg bg-red-50">
                    <div className="text-2xl font-bold text-red-700">
                      {stockSummary.bearish_count}
                    </div>
                    <div className="text-xs text-red-600">Bearish</div>
                  </div>
                </div>
              </div>

              {/* Ratings List */}
              {stockSummary.ratings.length > 0 && (
                <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
                  <h3 className="text-lg font-medium mb-4">All Ratings</h3>
                  <div className="space-y-3">
                    {stockSummary.ratings.map((r) => (
                      <div
                        key={r.id}
                        className="flex items-start gap-4 p-4 rounded-lg border border-slate-100 bg-slate-50"
                      >
                        <div
                          className={`px-3 py-1 rounded-full text-xs font-medium ${getRatingColor(r.rating)}`}
                        >
                          {r.rating}
                        </div>
                        <div className="flex-1">
                          <div className="font-medium text-slate-800">
                            {r.commenter_name}
                          </div>
                          {r.comment && (
                            <div className="mt-1 text-sm text-slate-600">{r.comment}</div>
                          )}
                          <div className="mt-1 text-xs text-slate-500">
                            Rated on {r.rating_date}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Research Links for Stock */}
              {stockLinks.length > 0 && (
                <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
                  <h3 className="text-lg font-medium mb-4">Research Links</h3>
                  <div className="space-y-2">
                    {stockLinks.map((link) => (
                      <div key={link.id} className="flex items-center gap-3">
                        <span className="text-xs text-slate-500">
                          {new Date(link.added_at).toLocaleDateString()}
                        </span>
                        <a
                          href={link.url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-emerald-700 hover:underline text-sm break-all"
                        >
                          {link.url}
                        </a>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Placeholder for future LLM rating */}
              <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50 p-6">
                <h3 className="text-lg font-medium mb-2 text-slate-500">
                  AI Analysis (Coming Soon)
                </h3>
                <p className="text-sm text-slate-400">
                  LLM-based rating analysis based on research reports and other data will appear here.
                </p>
              </div>
            </>
          )}
        </section>
      )}

      {/* Research Links Tab */}
      {activeTab === "links" && (
        <section className="space-y-6">
          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-medium mb-4">Add Research Link</h2>
            <form onSubmit={handleAddLink} className="grid gap-4 sm:grid-cols-12">
              <div className="sm:col-span-3">
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Stock Code
                </label>
                <input
                  type="text"
                  value={linkStockCode}
                  onChange={(e) => setLinkStockCode(e.target.value)}
                  placeholder="NVDA.US"
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div className="sm:col-span-7">
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Research Report URL
                </label>
                <input
                  type="url"
                  value={linkUrl}
                  onChange={(e) => setLinkUrl(e.target.value)}
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
            {linkError && <div className="mt-3 text-sm text-red-600">{linkError}</div>}
          </div>

          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
              <h2 className="text-lg font-medium">Saved Links</h2>
              <div className="sm:w-80">
                <input
                  type="text"
                  value={linkSearch}
                  onChange={(e) => {
                    setLinkSearch(e.target.value);
                    setLinkPage(1);
                  }}
                  placeholder="Search by stock code"
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
                    <th className="py-2 px-3 font-medium">Research Link</th>
                    <th className="py-2 px-3 font-medium text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {linkLoading ? (
                    <tr>
                      <td colSpan={4} className="py-6 text-center text-slate-500">
                        Loading...
                      </td>
                    </tr>
                  ) : links.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="py-6 text-center text-slate-500">
                        No links found.
                      </td>
                    </tr>
                  ) : (
                    links.map((r) => (
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
                        <td className="py-2 px-3 align-top text-right">
                          <button
                            className="rounded-md border border-red-300 text-red-700 px-3 py-1 text-xs hover:bg-red-50"
                            onClick={() => {
                              setLinkDeleteError("");
                              setLinkDeleteTargetId(r.id);
                            }}
                            title="Delete this research link"
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            <div className="mt-4 flex items-center justify-between text-sm">
              <div className="text-slate-600">
                Showing {links.length} of {linksTotal} result{linksTotal === 1 ? "" : "s"}
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setLinkPage((p) => Math.max(1, p - 1))}
                  disabled={linkCurrentPage === 1 || linkLoading}
                  className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
                >
                  Prev
                </button>
                <span className="px-2">
                  Page {linkCurrentPage} / {linkTotalPages}
                </span>
                <button
                  onClick={() => setLinkPage((p) => Math.min(linkTotalPages, p + 1))}
                  disabled={linkCurrentPage >= linkTotalPages || linkLoading}
                  className="rounded-md border border-slate-300 px-3 py-1.5 disabled:opacity-50"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
          {/* Delete research link confirmation modal */}
          {linkDeleteTargetId !== null && (
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
              <div className="w-full max-w-md rounded-lg bg-white shadow-lg p-6">
                <h3 className="text-lg font-medium mb-2">Delete Research Link</h3>
                <p className="text-sm text-slate-600">
                  This will permanently remove the selected research link. This action cannot be undone.
                </p>
                {linkDeleteError && <div className="mt-3 text-sm text-red-600">{linkDeleteError}</div>}
                <div className="mt-5 flex items-center justify-end gap-2">
                  <button
                    className="rounded-md border border-slate-300 px-4 py-2 text-sm"
                    onClick={() => (linkDeleting ? null : setLinkDeleteTargetId(null))}
                    disabled={linkDeleting}
                  >
                    Cancel
                  </button>
                  <button
                    className="rounded-md bg-red-600 text-white px-4 py-2 text-sm hover:opacity-90 disabled:opacity-50"
                    onClick={handleConfirmDeleteLink}
                    disabled={linkDeleting}
                  >
                    {linkDeleting ? "Deleting..." : "Delete"}
                  </button>
                </div>
              </div>
            </div>
          )}
        </section>
      )}

      {/* Manage Commenters Tab */}
      {activeTab === "commenters" && (
        <section className="space-y-6">
          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-medium mb-4">Add Commenter</h2>
            <form onSubmit={handleAddCommenter} className="grid gap-4 sm:grid-cols-12">
              <div className="sm:col-span-4">
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Name
                </label>
                <input
                  type="text"
                  value={newCommenterName}
                  onChange={(e) => setNewCommenterName(e.target.value)}
                  placeholder="Analyst name"
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div className="sm:col-span-6">
                <label className="block text-xs font-medium text-slate-600 mb-1">
                  Description (optional)
                </label>
                <input
                  type="text"
                  value={newCommenterDesc}
                  onChange={(e) => setNewCommenterDesc(e.target.value)}
                  placeholder="e.g., Goldman Sachs analyst"
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
            {commenterError && (
              <div className="mt-3 text-sm text-red-600">{commenterError}</div>
            )}
          </div>

          <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-medium mb-4">Existing Commenters</h2>
            {commenterLoading ? (
              <div className="text-center text-slate-500 py-6">Loading...</div>
            ) : commenters.length === 0 ? (
              <div className="text-center text-slate-500 py-6">
                No commenters yet. Add one above.
              </div>
            ) : (
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {commenters.map((c) => (
                  <div
                    key={c.id}
                    className="p-4 rounded-lg border border-slate-100 bg-slate-50"
                  >
                    <div className="font-medium text-slate-800">{c.name}</div>
                    {c.description && (
                      <div className="text-sm text-slate-600 mt-1">{c.description}</div>
                    )}
                    <div className="text-xs text-slate-400 mt-2">
                      Added {new Date(c.created_at).toLocaleDateString()}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>
      )}
    </div>
  );
}
