"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import AuthWrapper from "../../../components/AuthWrapper";
import { authenticatedFetch } from "../../../utils/authenticatedFetch";

type Row = {
  SubscriptionID: number;
  EntityCode: string;
  EventType: string;
  SubscriptionTypeName: string;
  SubscriptionTypeCode: string;
  TriggerValue?: number;
  TriggerValueUnit?: string;
  TriggerOperator?: string;
  TriggerValue2?: number;
  IncludeKeywords?: string; // JSON string
  ExcludeKeywords?: string; // JSON string
  Priority: number;
  NotificationChannel?: string;
  IsActive: boolean;
  LastTriggeredDate?: string;
  TriggerCount: number;
  CreatedDate?: string;
};

export default function UserSubscriptionsPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId: userIdParam } = use(params);
  const userId = Number(userIdParam);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [rows, setRows] = useState<Row[]>([]);
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const load = async () => {
    try {
      setLoading(true);
      setError("");
      const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}/subscriptions`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setRows(json);
    } catch (e: any) {
      setError(e?.message || "Failed to load subscriptions");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleDelete = async (id: number) => {
    if (!confirm("Delete this subscription?")) return;
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/subscriptions/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await load();
    } catch (e: any) {
      setError(e?.message || "Failed to delete subscription");
    }
  };

  const filtered = rows.filter(r => {
    if (!q.trim()) return true;
    const t = q.trim().toUpperCase();
    return (r.EntityCode || "").toUpperCase().includes(t) || (r.SubscriptionTypeName || "").toUpperCase().includes(t);
  });

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-7xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <Link href="/users" className="text-blue-600 hover:underline">Users</Link>
              <span>/</span>
              <span className="text-slate-700">Subscriptions</span>
            </div>
            <Link href={`/users/${userId}/subscriptions/new`} className="rounded-md bg-blue-600 text-white px-3 py-2 text-sm hover:bg-blue-700">
              + Add Subscription
            </Link>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4 mb-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <input
                placeholder="Search by ASX code or type..."
                value={q}
                onChange={(e) => setQ(e.target.value)}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
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
                  <th className="px-3 py-2 text-left">ASX Code</th>
                  <th className="px-3 py-2 text-left">Event Type</th>
                  <th className="px-3 py-2 text-left">Subscription Type</th>
                  <th className="px-3 py-2 text-left">Trigger</th>
                  <th className="px-3 py-2 text-left">Keywords</th>
                  <th className="px-3 py-2 text-left">Priority</th>
                  <th className="px-3 py-2 text-left">Channel</th>
                  <th className="px-3 py-2 text-left">Active</th>
                  <th className="px-3 py-2 text-left">Last</th>
                  <th className="px-3 py-2 text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r, idx) => {
                  let incCount = 0, excCount = 0;
                  try { incCount = (JSON.parse(r.IncludeKeywords || "[]") as any[]).length; } catch {}
                  try { excCount = (JSON.parse(r.ExcludeKeywords || "[]") as any[]).length; } catch {}
                  const trig =
                    r.TriggerOperator === "between" && r.TriggerValue != null && r.TriggerValue2 != null
                      ? `${r.TriggerValue} ~ ${r.TriggerValue2} ${r.TriggerValueUnit || ""}`
                      : r.TriggerValue != null
                        ? `${r.TriggerOperator || "above"} ${r.TriggerValue} ${r.TriggerValueUnit || ""}`
                        : "-";
                  return (
                    <tr key={r.SubscriptionID} className={idx % 2 ? "bg-slate-50" : ""}>
                      <td className="px-3 py-2">{r.EntityCode}</td>
                      <td className="px-3 py-2">{r.EventType}</td>
                      <td className="px-3 py-2">{r.SubscriptionTypeName}</td>
                      <td className="px-3 py-2">{trig}</td>
                      <td className="px-3 py-2">
                        <div className="flex gap-1">
                          {incCount > 0 && <span className="px-2 py-0.5 bg-emerald-100 text-emerald-700 rounded text-xs">Include {incCount}</span>}
                          {excCount > 0 && <span className="px-2 py-0.5 bg-amber-100 text-amber-700 rounded text-xs">Exclude {excCount}</span>}
                        </div>
                      </td>
                      <td className="px-3 py-2">{r.Priority}</td>
                      <td className="px-3 py-2">{r.NotificationChannel || "-"}</td>
                      <td className="px-3 py-2">
                        <span className={`px-2 py-0.5 rounded text-xs ${r.IsActive ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"}`}>
                          {r.IsActive ? "Active" : "Inactive"}
                        </span>
                      </td>
                      <td className="px-3 py-2">{r.LastTriggeredDate ? new Date(r.LastTriggeredDate).toLocaleString() : "-"}</td>
                      <td className="px-3 py-2">
                        <div className="flex gap-2">
                          <Link className="text-blue-600 hover:underline" href={`/users/${userId}/subscriptions/${r.SubscriptionID}/edit`}>Edit</Link>
                          <button className="text-red-600 hover:underline" onClick={() => handleDelete(r.SubscriptionID)}>Delete</button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </AuthWrapper>
  );
}


