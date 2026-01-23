"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import AuthWrapper from "../../components/AuthWrapper";
import { authenticatedFetch } from "../../utils/authenticatedFetch";

type UserOut = {
  user_id: number;
  email: string;
  display_name?: string;
  is_active: boolean;
  pushover_enabled: boolean;
  sms_enabled: boolean;
  discord_enabled: boolean;
  notification_frequency: string;
  quiet_hours_start?: string;
  quiet_hours_end?: string;
  timezone: string;
  subscription_count: number;
  last_notification_date?: string;
  created_date?: string;
  updated_date?: string;
};

export default function UserDetailPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId: userIdParam } = use(params);
  const userId = Number(userIdParam);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [user, setUser] = useState<UserOut | null>(null);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    const load = async () => {
      try {
        const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        setUser(json);
      } catch (e: any) {
        setError(e?.message || "Failed to load user");
      }
    };
    load();
  }, [baseUrl, userId]);

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-5xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-semibold">User Details</h1>
            <div className="flex gap-3">
              <Link href="/users" className="text-blue-600 hover:underline">Back to Users</Link>
              <Link href={`/users/${userId}/edit`} className="text-blue-600 hover:underline">Edit</Link>
              <Link href={`/users/${userId}/subscriptions`} className="text-blue-600 hover:underline">View Subscriptions</Link>
            </div>
          </div>
          {error && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
              Error: {error}
            </div>
          )}
          {!user ? (
            <div>Loading...</div>
          ) : (
            <div className="grid gap-4">
              <div className="rounded-lg border border-slate-200 bg-white p-4">
                <h3 className="font-medium mb-2">User Info</h3>
                <div className="grid sm:grid-cols-2 gap-2 text-sm">
                  <div><span className="text-slate-500">Email:</span> {user.email}</div>
                  <div><span className="text-slate-500">Display Name:</span> {user.display_name || "-"}</div>
                  <div><span className="text-slate-500">Active:</span> {user.is_active ? "Yes" : "No"}</div>
                  <div><span className="text-slate-500">Created:</span> {user.created_date ? new Date(user.created_date).toLocaleString() : "-"}</div>
                  <div><span className="text-slate-500">Updated:</span> {user.updated_date ? new Date(user.updated_date).toLocaleString() : "-"}</div>
                </div>
              </div>
              <div className="rounded-lg border border-slate-200 bg-white p-4">
                <h3 className="font-medium mb-2">Notification Channels</h3>
                <div className="flex gap-2 text-sm">
                  {user.pushover_enabled && <span className="px-2 py-0.5 bg-blue-100 text-blue-700 rounded">Pushover</span>}
                  {user.sms_enabled && <span className="px-2 py-0.5 bg-emerald-100 text-emerald-700 rounded">SMS</span>}
                  {user.discord_enabled && <span className="px-2 py-0.5 bg-indigo-100 text-indigo-700 rounded">Discord</span>}
                  {!user.pushover_enabled && !user.sms_enabled && !user.discord_enabled && <span className="text-slate-500">No channels enabled</span>}
                </div>
              </div>
              <div className="rounded-lg border border-slate-200 bg-white p-4">
                <h3 className="font-medium mb-2">Global Preferences</h3>
                <div className="grid sm:grid-cols-2 gap-2 text-sm">
                  <div><span className="text-slate-500">Frequency:</span> {user.notification_frequency}</div>
                  <div><span className="text-slate-500">Quiet Hours:</span> {(user.quiet_hours_start || "-") + " ~ " + (user.quiet_hours_end || "-")}</div>
                  <div><span className="text-slate-500">Timezone:</span> {user.timezone}</div>
                </div>
              </div>
              <div className="rounded-lg border border-slate-200 bg-white p-4">
                <h3 className="font-medium mb-2">Active Subscriptions</h3>
                <div className="text-sm">
                  Count: {user.subscription_count}
                </div>
                <div className="text-sm">
                  Last Notification: {user.last_notification_date ? new Date(user.last_notification_date).toLocaleString() : "-"}
                </div>
                <div className="mt-3">
                  <Link href={`/users/${userId}/subscriptions`} className="rounded-md bg-blue-600 text-white px-3 py-2 text-sm">Manage Subscriptions</Link>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </AuthWrapper>
  );
}


