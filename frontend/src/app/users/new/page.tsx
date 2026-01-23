"use client";

import { useState } from "react";
import Link from "next/link";
import AuthWrapper from "../../components/AuthWrapper";
import { authenticatedFetch } from "../../utils/authenticatedFetch";

type Payload = {
  email: string;
  display_name?: string;
  is_active: boolean;
  pushover_user_key?: string;
  pushover_enabled: boolean;
  sms_phone_number?: string;
  sms_enabled: boolean;
  discord_webhook?: string;
  discord_enabled: boolean;
  notification_frequency: "immediate" | "batched_5min" | "batched_hourly";
  quiet_hours_start?: string;
  quiet_hours_end?: string;
  timezone: string;
};

export default function NewUserPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [payload, setPayload] = useState<Payload>({
    email: "",
    display_name: "",
    is_active: true,
    pushover_user_key: "",
    pushover_enabled: true,
    sms_phone_number: "",
    sms_enabled: false,
    discord_webhook: "",
    discord_enabled: false,
    notification_frequency: "immediate",
    quiet_hours_start: "",
    quiet_hours_end: "",
    timezone: "Australia/Sydney",
  });
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string>("");
  const [message, setMessage] = useState<string>("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    setMessage("");
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/users`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...payload,
          display_name: payload.display_name || null,
          pushover_user_key: payload.pushover_user_key || null,
          sms_phone_number: payload.sms_phone_number || null,
          discord_webhook: payload.discord_webhook || null,
          quiet_hours_start: payload.quiet_hours_start || null,
          quiet_hours_end: payload.quiet_hours_end || null,
        }),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`HTTP ${res.status}: ${txt}`);
      }
      setMessage("User created");
      window.location.href = "/users";
    } catch (e: any) {
      setError(e?.message || "Failed to create user");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthWrapper>
      <div className="min-h-screen text-slate-800">
        <div className="mx-auto max-w-3xl px-6 py-10">
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-semibold">Add New User</h1>
            <Link href="/users" className="text-blue-600 hover:underline">Back to Users</Link>
          </div>
          {error && (
            <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">
              Error: {error}
            </div>
          )}
          {message && (
            <div className="mb-4 rounded-md border border-green-200 bg-green-50 text-green-700 px-3 py-2 text-sm">
              {message}
            </div>
          )}
          <form onSubmit={handleSubmit} className="grid gap-4">
            <div>
              <label className="block text-sm mb-1 text-slate-600">Email</label>
              <input
                type="email"
                value={payload.email}
                onChange={(e) => setPayload({ ...payload, email: e.target.value })}
                required
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label className="block text-sm mb-1 text-slate-600">Display Name</label>
              <input
                type="text"
                value={payload.display_name}
                onChange={(e) => setPayload({ ...payload, display_name: e.target.value })}
                className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                id="is_active"
                type="checkbox"
                checked={payload.is_active}
                onChange={(e) => setPayload({ ...payload, is_active: e.target.checked })}
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
                    checked={payload.pushover_enabled}
                    onChange={(e) => setPayload({ ...payload, pushover_enabled: e.target.checked })}
                  />
                  <label htmlFor="pushover_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="Pushover User Key"
                  value={payload.pushover_user_key}
                  onChange={(e) => setPayload({ ...payload, pushover_user_key: e.target.value })}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="rounded border border-slate-200 p-3">
                <h3 className="font-medium mb-2">SMS</h3>
                <div className="flex items-center gap-2 mb-2">
                  <input
                    id="sms_enabled"
                    type="checkbox"
                    checked={payload.sms_enabled}
                    onChange={(e) => setPayload({ ...payload, sms_enabled: e.target.checked })}
                  />
                  <label htmlFor="sms_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="+61412345678"
                  value={payload.sms_phone_number}
                  onChange={(e) => setPayload({ ...payload, sms_phone_number: e.target.value })}
                  className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                />
              </div>
              <div className="rounded border border-slate-200 p-3 sm:col-span-2">
                <h3 className="font-medium mb-2">Discord</h3>
                <div className="flex items-center gap-2 mb-2">
                  <input
                    id="discord_enabled"
                    type="checkbox"
                    checked={payload.discord_enabled}
                    onChange={(e) => setPayload({ ...payload, discord_enabled: e.target.checked })}
                  />
                  <label htmlFor="discord_enabled" className="text-sm">Enabled</label>
                </div>
                <input
                  placeholder="Webhook URL"
                  value={payload.discord_webhook}
                  onChange={(e) => setPayload({ ...payload, discord_webhook: e.target.value })}
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
                    value={payload.notification_frequency}
                    onChange={(e) => setPayload({ ...payload, notification_frequency: e.target.value as any })}
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
                    value={payload.quiet_hours_start || ""}
                    onChange={(e) => setPayload({ ...payload, quiet_hours_start: e.target.value })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Quiet Hours End</label>
                  <input
                    type="time"
                    value={payload.quiet_hours_end || ""}
                    onChange={(e) => setPayload({ ...payload, quiet_hours_end: e.target.value })}
                    className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm mb-1 text-slate-600">Timezone</label>
                  <select
                    value={payload.timezone}
                    onChange={(e) => setPayload({ ...payload, timezone: e.target.value })}
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
              <Link href="/users" className="rounded-md bg-gray-200 text-gray-800 px-4 py-2 text-sm">Cancel</Link>
              <button
                type="submit"
                disabled={submitting}
                className="rounded-md bg-blue-600 text-white px-4 py-2 text-sm disabled:opacity-50"
              >
                {submitting ? "Saving..." : "Save User"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </AuthWrapper>
  );
}


