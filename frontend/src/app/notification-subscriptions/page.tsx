"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import AuthWrapper from "../components/AuthWrapper";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type UserRow = {
  user_id: number;
  email: string;
  display_name?: string;
  is_active: boolean;
  pushover_enabled: boolean;
  sms_enabled: boolean;
  discord_enabled: boolean;
  subscription_count: number;
  created_date?: string;
};

type UsersPage = {
  items: UserRow[];
  total: number;
  page: number;
  page_size: number;
};

export default function UsersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [data, setData] = useState<UsersPage>({ items: [], total: 0, page: 1, page_size: 20 });
  const [q, setQ] = useState("");
  const [activeFilter, setActiveFilter] = useState<"all" | "active" | "inactive">("all");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const totalPages = useMemo(() => Math.max(1, Math.ceil((data.total || 0) / (data.page_size || 20))), [data.total, data.page_size]);

  const load = async (page: number = 1) => {
    try {
      setLoading(true);
      setError("");
      const params = new URLSearchParams();
      params.set("page", String(page));
      params.set("page_size", String(data.page_size || 20));
      if (q.trim().length > 0) params.set("q", q.trim());
      if (activeFilter !== "all") params.set("active", activeFilter === "active" ? "true" : "false");
      const res = await authenticatedFetch(`${baseUrl}/api/users?${params.toString()}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setData(json);
    } catch (e: any) {
      setError(e?.message || "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleDelete = async (userId: number) => {
    if (!confirm("Delete this user and all their subscriptions?")) return;
    try {
      setLoading(true);
      const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await load(data.page);
    } catch (e: any) {
      setError(e?.message || "Failed to delete user");
    } finally {
      setLoading(false);
    }
  };

  const toggleActive = async (userId: number, current: boolean) => {
    try {
      const params = new URLSearchParams();
      params.set("is_active", String(!current));
      const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}/toggle-active?${params.toString()}`, {
        method: "PATCH",
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await load(data.page);
    } catch (e: any) {
      setError(e?.message || "Failed to toggle active");
    }
  };

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-7xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-3xl sm:text-4xl font-semibold bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
              Notification Subscriptions
            </h1>
            <Link href="/notification-subscriptions/new" className="rounded-md bg-blue-600 text-white px-3 py-2 text-sm hover:bg-blue-700">
              + Add New User
            </Link>
          </div>

          <div className="rounded-lg border border-slate-200 bg-white p-4 mb-4">
            <div className="grid gap-3 sm:grid-cols-3">
              <input
                placeholder="Search by email or name..."
                value={q}
                onChange={(e) => setQ(e.target.value)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40"
              />
              <select
                value={activeFilter}
                onChange={(e) => setActiveFilter(e.target.value as any)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40"
              >
                <option value="all">All</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
              <div className="flex gap-2">
                <button
                  onClick={() => load(1)}
                  className="rounded-md bg-slate-700 text-white px-3 py-2 text-sm hover:bg-slate-800"
                >
                  Search
                </button>
                <button
                  onClick={() => {
                    setQ("");
                    setActiveFilter("all");
                    load(1);
                  }}
                  className="rounded-md bg-gray-200 text-gray-800 px-3 py-2 text-sm hover:bg-gray-300"
                >
                  Reset
                </button>
              </div>
            </div>
          </div>

          {error && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
              Error: {error}
            </div>
          )}

          <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
            {loading && (
              <div className="absolute inset-0 bg-white/60 backdrop-blur-sm flex items-center justify-center z-10">
                <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
              </div>
            )}
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-slate-600 uppercase text-[11px] tracking-wide">
                <tr>
                  <th className="px-3 py-2 text-left">ID</th>
                  <th className="px-3 py-2 text-left">Email</th>
                  <th className="px-3 py-2 text-left">Name</th>
                  <th className="px-3 py-2 text-left">Active</th>
                  <th className="px-3 py-2 text-left">Channels</th>
                  <th className="px-3 py-2 text-left">Subs</th>
                  <th className="px-3 py-2 text-left">Created</th>
                  <th className="px-3 py-2 text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((u, idx) => (
                  <tr key={u.user_id} className={idx % 2 ? "bg-slate-50" : ""}>
                    <td className="px-3 py-2">{u.user_id}</td>
                    <td className="px-3 py-2">{u.email}</td>
                    <td className="px-3 py-2">{u.display_name || "-"}</td>
                    <td className="px-3 py-2">
                      <button
                        onClick={() => toggleActive(u.user_id, u.is_active)}
                        className={`px-2 py-1 rounded text-xs ${
                          u.is_active ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"
                        }`}
                      >
                        {u.is_active ? "Active" : "Inactive"}
                      </button>
                    </td>
                    <td className="px-3 py-2">
                      <div className="flex gap-1">
                        {u.pushover_enabled && <span className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-xs">Pushover</span>}
                        {u.sms_enabled && <span className="px-2 py-0.5 bg-emerald-100 text-emerald-700 rounded text-xs">SMS</span>}
                        {u.discord_enabled && <span className="px-2 py-0.5 bg-indigo-100 text-indigo-700 rounded text-xs">Discord</span>}
                      </div>
                    </td>
                    <td className="px-3 py-2">{u.subscription_count}</td>
                    <td className="px-3 py-2">
                      {u.created_date ? new Date(u.created_date).toLocaleDateString() : "-"}
                    </td>
                    <td className="px-3 py-2">
                      <div className="flex gap-2">
                        <Link className="text-blue-600 hover:underline" href={`/notification-subscriptions/${u.user_id}`}>View</Link>
                        <Link className="text-blue-600 hover:underline" href={`/notification-subscriptions/${u.user_id}/edit`}>Edit</Link>
                        <Link className="text-blue-600 hover:underline" href={`/notification-subscriptions/${u.user_id}/subscriptions`}>Subscriptions</Link>
                        <button className="text-red-600 hover:underline" onClick={() => handleDelete(u.user_id)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="flex items-center justify-between mt-4">
            <button
              disabled={data.page <= 1}
              onClick={() => load(data.page - 1)}
              className="rounded-md bg-gray-200 text-gray-800 px-3 py-2 text-sm disabled:opacity-50"
            >
              &lt; Previous
            </button>
            <div className="text-sm">
              Page {data.page} of {totalPages}
            </div>
            <button
              disabled={data.page >= totalPages}
              onClick={() => load(data.page + 1)}
              className="rounded-md bg-gray-200 text-gray-800 px-3 py-2 text-sm disabled:opacity-50"
            >
              Next &gt;
            </button>
          </div>
        </div>
      </div>
    </AuthWrapper>
  );
}


