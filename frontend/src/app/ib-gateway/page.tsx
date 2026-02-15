"use client";

import { useEffect, useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

export default function IBGatewayPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<{ running: boolean; pids: number[]; api_ready?: boolean; open_ports?: number[]; host?: string; db_heartbeat_success?: number | null; db_heartbeat_updated?: string | null; db_heartbeat_ok?: boolean | null } | null>(null);
  const [error, setError] = useState<string>("");

  const fetchStatus = useCallback(() => {
    setError("");
    authenticatedFetch(`${baseUrl}/api/ib-gateway/status`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setStatus)
      .catch((e) => setError(e.message));
  }, [baseUrl]);

  useEffect(() => {
    fetchStatus();
  }, [fetchStatus]);

  const onRestart = async () => {
    setLoading(true);
    setError("");
    try {
      const r = await authenticatedFetch(`${baseUrl}/api/ib-gateway/restart`, {
        method: "POST",
      });
      if (!r.ok) {
        try {
          const body = await r.json();
          throw new Error(body?.detail ? `HTTP ${r.status}: ${body.detail}` : `HTTP ${r.status}`);
        } catch {
          throw new Error(`HTTP ${r.status}`);
        }
      }
      await r.json();
      // Give IBG some time before re-checking
      setTimeout(fetchStatus, 7000);
    } catch (e: any) {
      setError(e.message || String(e));
    } finally {
      setLoading(false);
    }
  };

  const isRunning = status?.running;
  const isCalibrated = (status as any)?.calibrated;
  // Removed active IB connectivity probing; hide connectable indicator

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-3xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-emerald-500 to-green-600 bg-clip-text text-transparent">IB Gateway Control</h1>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">Error: {error}</div>
        )}

        <div className="flex items-center gap-6 mb-6">
          <div className="flex items-center gap-2">
            <span
              className={`inline-block h-3 w-3 rounded-full ${isRunning ? "bg-emerald-500" : "bg-red-500"}`}
              aria-label={isRunning ? "Running" : "Stopped"}
            />
            <span className="text-sm text-slate-700">{isRunning ? "Running" : "Not running"}</span>
          </div>
          {status?.pids && status.pids.length > 0 && (
            <span className="text-xs text-slate-500">PIDs: {status.pids.join(", ")}</span>
          )}
          <span className="text-xs text-slate-500">Calibrated: {isCalibrated ? "Yes" : "No"}</span>
          {(() => {
            const ok = status?.db_heartbeat_ok;
            const text = ok === true ? "OK" : ok === false ? "Fail" : "Unknown";
            const dot = ok === true ? "bg-emerald-500" : ok === false ? "bg-red-500" : "bg-slate-400";
            const color = ok === true ? "text-emerald-600" : ok === false ? "text-red-600" : "text-slate-500";
            return (
              <span className={`inline-flex items-center text-xs ${color}`}>
                <span className={`mr-1 h-2 w-2 rounded-full ${dot}`} />
                IB Heartbeat: {text}
              </span>
            );
          })()}
          <span className="text-xs text-slate-500">Heartbeat Updated: {status?.db_heartbeat_updated ?? "n/a"}</span>
          {/* No ib_error now that active connectivity checks are removed */}
        </div>

        <button
          onClick={onRestart}
          disabled={loading}
          className={`rounded-md px-4 py-2 text-sm font-medium text-white ${loading ? "bg-slate-400" : "bg-emerald-600 hover:bg-emerald-700"}`}
        >
          {loading ? "Restarting..." : "Restart IB Gateway"}
        </button>
      </div>
    </div>
  );
}


