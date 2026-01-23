"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import AuthWrapper from "../../../components/AuthWrapper";
import { authenticatedFetch } from "../../../utils/authenticatedFetch";

type UserOut = {
  user_id: number;
  email: string;
  display_name?: string;
  is_active: boolean;
  pushover_enabled: boolean;
  sms_enabled: boolean;
  discord_enabled: boolean;
  notification_frequency: "immediate" | "batched_5min" | "batched_hourly";
  quiet_hours_start?: string;
  quiet_hours_end?: string;
  timezone: string;
  pushover_user_key?: string;
  sms_phone_number?: string;
  discord_webhook?: string;
};

export default function EditUserPage({ params }: { params: Promise<{ userId: string }> }) {
  const { userId: userIdParam } = use(params);
  const userId = Number(userIdParam);
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [form, setForm] = useState<UserOut | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string>("");

  useEffect(() => {
    const load = async () => {
      try {
        const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const u = await res.json();
        setForm({
          ...u,
          pushover_user_key: "",
          sms_phone_number: "",
          discord_webhook: "",
        });
      } catch (e: any) {
        setError(e?.message || "Failed to load user");
      }
    };
    load();
  }, [baseUrl, userId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form) return;
    try {
      setSubmitting(true);
      const res = await authenticatedFetch(`${baseUrl}/api/users/${userId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: form.email,
          display_name: form.display_name || null,
          is_active: form.is_active,
          pushover_enabled: form.pushover_enabled,
          pushover_user_key: form.pushover_user_key || null,
          sms_enabled: form.sms_enabled,
          sms_phone_number: form.sms_phone_number || null,
          discord_enabled: form.discord_enabled,
          discord_webhook: form.discord_webhook || null,
          notification_frequency: form.notification_frequency,
          quiet_hours_start: form.quiet_hours_start || null,
          quiet_hours_end: form.quiet_hours_end || null,
          timezone: form.timezone,
        }),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`HTTP ${res.status}: ${txt}`);
      }
      window.location.href = `/notification-subscriptions`;
    } catch (e: any) {
      setError(e?.message || "Failed to update user");
    } finally {
      setSubmitting(false);
    }
  };

  if (!form) {
    return (
      <AuthWrapper>
        <div className="p-6">Loading...</div>
      </AuthWrapper>
    );
  }

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-3xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-semibold">Edit User #{userId}</h1>
            <Link href="/notification-subscriptions" className="text-blue-600 hover:underline">Back to Users</Link>
          </div>
          {error && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
              Error: {error}
            </div>
          )}
          <form onSubmit={handleSubmit} className="grid gap-4">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Email</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                required
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Display Name</label>
              <input
                type="text"
                value={form.display_name || ""}
                onChange={(e) => setForm({ ...form, display_name: e.target.value })}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                id="is_active"
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
              />
              <label htmlFor="is_active" className="text-sm text-slate-700">Is Active</label>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded border border-slate-200 p-3">
                <h3 className="font-medium mb-2">Pushover</h3>
                <div className="flex items-center gap-2 mb-2">
                  <input
                    id="pushover_enabled"
                    type="checkbox"
                    checked={form.pushover_enabled}
                    onChange={(e) => setForm({ ...form, pushover_enabled: e.target.checked })}
                  />
                  <label htmlFor="pushover_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="Pushover User Key"
                  value={form.pushover_user_key || ""}
                  onChange={(e) => setForm({ ...form, pushover_user_key: e.target.value })}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="rounded border border-slate-200 p-3">
                <h3 className="font-medium mb-2">SMS</h3>
                <div className="flex items-center gap-2 mb-2">
                  <input
                    id="sms_enabled"
                    type="checkbox"
                    checked={form.sms_enabled}
                    onChange={(e) => setForm({ ...form, sms_enabled: e.target.checked })}
                  />
                  <label htmlFor="sms_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="+61412345678"
                  value={form.sms_phone_number || ""}
                  onChange={(e) => setForm({ ...form, sms_phone_number: e.target.value })}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="rounded border border-slate-200 p-3 sm:col-span-2">
                <h3 className="font-medium mb-2">Discord</h3>
                <div className="flex items-center gap-2 mb-2">
                  <input
                    id="discord_enabled"
                    type="checkbox"
                    checked={form.discord_enabled}
                    onChange={(e) => setForm({ ...form, discord_enabled: e.target.checked })}
                  />
                  <label htmlFor="discord_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="Webhook URL"
                  value={form.discord_webhook || ""}
                  onChange={(e) => setForm({ ...form, discord_webhook: e.target.value })}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
            </div>

            <div className="rounded border border-slate-200 p-3">
              <h3 className="font-medium mb-2">Preferences</h3>
              <div className="grid gap-3 sm:grid-cols-3">
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Notification Frequency</label>
                  <select
                    value={form.notification_frequency}
                    onChange={(e) => setForm({ ...form, notification_frequency: e.target.value as any })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  >
                    <option value="immediate">Immediate</option>
                    <option value="batched_5min">Batched 5 min</option>
                    <option value="batched_hourly">Batched Hourly</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Quiet Hours Start</label>
                  <input
                    type="time"
                    value={form.quiet_hours_start || ""}
                    onChange={(e) => setForm({ ...form, quiet_hours_start: e.target.value })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Quiet Hours End</label>
                  <input
                    type="time"
                    value={form.quiet_hours_end || ""}
                    onChange={(e) => setForm({ ...form, quiet_hours_end: e.target.value })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Timezone</label>
                  <select
                    value={form.timezone}
                    onChange={(e) => setForm({ ...form, timezone: e.target.value })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  >
                    <option>Australia/Sydney</option>
                    <option>Australia/Melbourne</option>
                    <option>Australia/Brisbane</option>
                    <option>Australia/Perth</option>
                    <option>UTC</option>
                  </select>
                </div>
              </div>
            </div>

            <div className="flex gap-2">
              <Link href="/notification-subscriptions" className="rounded-md bg-gray-200 text-gray-800 px-4 py-2 text-sm">Cancel</Link>
              <button
                type="submit"
                disabled={submitting}
                className="rounded-md bg-blue-600 text-white px-4 py-2 text-sm disabled:opacity-50"
              >
                {submitting ? "Saving..." : "Save Changes"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </AuthWrapper>
  );
}


