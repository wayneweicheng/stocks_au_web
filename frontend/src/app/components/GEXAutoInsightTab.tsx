"use client";

import { useEffect, useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type StockConfig = {
  StockCode: string;
  DisplayName: string | null;
  IsActive: boolean;
  Priority: number;
  LLMModel: string | null;
  CreatedDate: string;
  UpdatedDate: string;
};

type StockStatus = {
  stock_code: string;
  display_name: string | null;
  priority: number;
  has_gex_data: boolean;
  has_signal_strength: boolean;
  status: "no_data" | "pending" | "processed";
  signal_strength?: string;
};

type ProcessingStatus = {
  target_date: string;
  total_configured: number;
  available_count: number;
  processed_count: number;
  pending_count: number;
  stocks: StockStatus[];
};

type SchedulerJob = {
  id: string;
  name: string;
  trigger: string;
  next_run_time: string | null;
  pending: boolean;
};

type SchedulerStatus = {
  running: boolean;
  jobs: SchedulerJob[];
};

export default function GEXAutoInsightTab() {
  const [stocks, setStocks] = useState<StockConfig[]>([]);
  const [status, setStatus] = useState<ProcessingStatus | null>(null);
  const [schedulerStatus, setSchedulerStatus] = useState<SchedulerStatus | null>(null);
  const [loading, setLoading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string>("");
  const [info, setInfo] = useState<string>("");

  // Add form
  const [newCode, setNewCode] = useState("");
  const [newDisplayName, setNewDisplayName] = useState("");
  const [newPriority, setNewPriority] = useState("50");

  // Edit state
  const [editingCode, setEditingCode] = useState<string | null>(null);
  const [editDisplayName, setEditDisplayName] = useState("");
  const [editPriority, setEditPriority] = useState("");
  const [editActive, setEditActive] = useState(true);

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  const fetchStocks = useCallback(async () => {
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/gex-auto-insight/stocks?active_only=false`);
      if (res.ok) {
        const data = await res.json();
        setStocks(data.stocks || []);
      }
    } catch (e) {
      setError(`Failed to fetch stocks: ${e}`);
    }
  }, [baseUrl]);

  const fetchStatus = useCallback(async () => {
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/gex-auto-insight/status`);
      if (res.ok) {
        const data = await res.json();
        setStatus(data);
      }
    } catch (e) {
      setError(`Failed to fetch status: ${e}`);
    }
  }, [baseUrl]);

  const fetchSchedulerStatus = useCallback(async () => {
    try {
      const res = await authenticatedFetch(`${baseUrl}/api/scheduler/status`);
      if (res.ok) {
        const data = await res.json();
        setSchedulerStatus(data);
      }
    } catch (e) {
      console.error("Failed to fetch scheduler status:", e);
    }
  }, [baseUrl]);

  const refreshAll = useCallback(async () => {
    setLoading(true);
    setError("");
    await Promise.all([fetchStocks(), fetchStatus(), fetchSchedulerStatus()]);
    setLoading(false);
  }, [fetchStocks, fetchStatus, fetchSchedulerStatus]);

  useEffect(() => {
    refreshAll();
    const interval = setInterval(refreshAll, 30000);
    return () => clearInterval(interval);
  }, [refreshAll]);

  const addStock = async () => {
    setError("");
    setInfo("");
    if (!newCode.trim()) return;

    try {
      const res = await authenticatedFetch(`${baseUrl}/api/gex-auto-insight/stocks`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          stock_code: newCode.trim().toUpperCase(),
          display_name: newDisplayName.trim() || null,
          priority: parseInt(newPriority) || 50,
          is_active: true,
        }),
      });

      if (!res.ok) {
        const msg = await res.text().catch(() => "");
        setError(`Add failed: ${msg || res.statusText}`);
        return;
      }

      setInfo(`Added ${newCode.toUpperCase()} to auto-insight configuration`);
      setNewCode("");
      setNewDisplayName("");
      setNewPriority("50");
      refreshAll();
    } catch (e) {
      setError(`Add failed: ${e}`);
    }
  };

  const startEdit = (stock: StockConfig) => {
    setEditingCode(stock.StockCode);
    setEditDisplayName(stock.DisplayName || "");
    setEditPriority(String(stock.Priority));
    setEditActive(stock.IsActive);
  };

  const saveEdit = async () => {
    if (!editingCode) return;
    setError("");

    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/gex-auto-insight/stocks/${encodeURIComponent(editingCode)}`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            display_name: editDisplayName.trim() || null,
            priority: parseInt(editPriority) || 0,
            is_active: editActive,
          }),
        }
      );

      if (!res.ok) {
        const msg = await res.text().catch(() => "");
        setError(`Update failed: ${msg || res.statusText}`);
        return;
      }

      setInfo(`Updated ${editingCode}`);
      setEditingCode(null);
      refreshAll();
    } catch (e) {
      setError(`Update failed: ${e}`);
    }
  };

  const deleteStock = async (code: string) => {
    if (!window.confirm(`Remove ${code} from auto-insight configuration?`)) return;
    setError("");

    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/gex-auto-insight/stocks/${encodeURIComponent(code)}`,
        { method: "DELETE" }
      );

      if (!res.ok) {
        const msg = await res.text().catch(() => "");
        setError(`Delete failed: ${msg || res.statusText}`);
        return;
      }

      setInfo(`Removed ${code} from configuration`);
      refreshAll();
    } catch (e) {
      setError(`Delete failed: ${e}`);
    }
  };

  const processAllPending = async () => {
    setProcessing(true);
    setError("");
    setInfo("");

    try {
      const res = await authenticatedFetch(`${baseUrl}/api/gex-auto-insight/process`, {
        method: "POST",
      });

      if (!res.ok) {
        const msg = await res.text().catch(() => "");
        setError(`Processing failed: ${msg || res.statusText}`);
        return;
      }

      const data = await res.json();
      const processed = data.processed?.length || 0;
      const failed = data.failed?.length || 0;
      setInfo(`Processing complete: ${processed} succeeded, ${failed} failed`);
      refreshAll();
    } catch (e) {
      setError(`Processing failed: ${e}`);
    } finally {
      setProcessing(false);
    }
  };

  const processSingleStock = async (code: string) => {
    setProcessing(true);
    setError("");

    try {
      const res = await authenticatedFetch(
        `${baseUrl}/api/gex-auto-insight/process/${encodeURIComponent(code)}`,
        { method: "POST" }
      );

      if (!res.ok) {
        const msg = await res.text().catch(() => "");
        setError(`Processing ${code} failed: ${msg || res.statusText}`);
        return;
      }

      const data = await res.json();
      setInfo(`${code}: ${data.signal_strength || "processed"}`);
      refreshAll();
    } catch (e) {
      setError(`Processing ${code} failed: ${e}`);
    } finally {
      setProcessing(false);
    }
  };

  const getStatusBadge = (stockStatus: StockStatus) => {
    if (stockStatus.status === "processed") {
      const signal = stockStatus.signal_strength || "";
      const color = signal.includes("BULLISH")
        ? "bg-emerald-100 text-emerald-800"
        : signal.includes("BEARISH")
        ? "bg-red-100 text-red-800"
        : "bg-slate-100 text-slate-800";
      return <span className={`px-2 py-1 rounded text-xs font-medium ${color}`}>{signal.replace(/_/g, " ")}</span>;
    }
    if (stockStatus.status === "pending") {
      return <span className="px-2 py-1 rounded text-xs font-medium bg-amber-100 text-amber-800">Pending</span>;
    }
    return <span className="px-2 py-1 rounded text-xs font-medium bg-slate-100 text-slate-500">No Data</span>;
  };

  return (
    <div className="space-y-6">
      {error && (
        <div className="flex items-start gap-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          <svg viewBox="0 0 24 24" className="mt-[2px] h-5 w-5 fill-red-500">
            <path d="M12 2c5.52 0 10 4.48 10 10s-4.48 10-10 10S2 17.52 2 12 6.48 2 12 2Zm1 14v2h-2v-2h2Zm0-10v8h-2V6h2Z" />
          </svg>
          <div>{error}</div>
        </div>
      )}

      {info && (
        <div className="flex items-start gap-2 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          <svg viewBox="0 0 24 24" className="mt-[2px] h-5 w-5 fill-emerald-600">
            <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-1 14-4-4 1.41-1.41L11 12.17l4.59-4.58L17 9l-6 7Z" />
          </svg>
          <div>{info}</div>
        </div>
      )}

      {/* Scheduler Status */}
      <div className="p-4 rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-base font-medium">Scheduler Status</h3>
          <button onClick={refreshAll} disabled={loading} className="text-sm text-emerald-600 hover:text-emerald-700">
            {loading ? "Refreshing..." : "Refresh"}
          </button>
        </div>
        {schedulerStatus ? (
          <div className="text-sm">
            <p>
              Status:{" "}
              <span className={schedulerStatus.running ? "text-emerald-600 font-medium" : "text-red-600 font-medium"}>
                {schedulerStatus.running ? "Running" : "Stopped"}
              </span>
            </p>
            {schedulerStatus.jobs.map((job) => (
              <p key={job.id} className="text-slate-600">
                {job.name}: Next run at {job.next_run_time ? new Date(job.next_run_time).toLocaleString() : "N/A"}
              </p>
            ))}
          </div>
        ) : (
          <p className="text-sm text-slate-500">Loading scheduler status...</p>
        )}
      </div>

      {/* Processing Status */}
      <div className="p-4 rounded-lg border border-slate-200 bg-white">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-base font-medium">
            Processing Status {status && <span className="text-sm font-normal text-slate-500">({status.target_date})</span>}
          </h3>
          <button
            onClick={processAllPending}
            disabled={processing || !status?.pending_count}
            className="px-4 py-2 rounded-md bg-emerald-600 text-white text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {processing ? "Processing..." : `Process ${status?.pending_count || 0} Pending`}
          </button>
        </div>

        {status && (
          <div className="grid grid-cols-4 gap-4 mb-4">
            <div className="text-center p-3 rounded-lg bg-slate-50">
              <p className="text-2xl font-semibold">{status.total_configured}</p>
              <p className="text-xs text-slate-500">Configured</p>
            </div>
            <div className="text-center p-3 rounded-lg bg-blue-50">
              <p className="text-2xl font-semibold text-blue-600">{status.available_count}</p>
              <p className="text-xs text-slate-500">Data Available</p>
            </div>
            <div className="text-center p-3 rounded-lg bg-emerald-50">
              <p className="text-2xl font-semibold text-emerald-600">{status.processed_count}</p>
              <p className="text-xs text-slate-500">Processed</p>
            </div>
            <div className="text-center p-3 rounded-lg bg-amber-50">
              <p className="text-2xl font-semibold text-amber-600">{status.pending_count}</p>
              <p className="text-xs text-slate-500">Pending</p>
            </div>
          </div>
        )}

        {/* Status Table */}
        {status && status.stocks.length > 0 && (
          <div className="rounded-lg border border-slate-200 overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="bg-slate-50 text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
                <tr>
                  <th className="px-3 py-2 text-left">Stock</th>
                  <th className="px-3 py-2 text-left">Name</th>
                  <th className="px-3 py-2 text-center">Priority</th>
                  <th className="px-3 py-2 text-center">GEX Data</th>
                  <th className="px-3 py-2 text-center">Status</th>
                  <th className="px-3 py-2 text-center">Action</th>
                </tr>
              </thead>
              <tbody>
                {status.stocks.map((s, i) => (
                  <tr key={s.stock_code} className={i % 2 ? "bg-slate-50" : ""}>
                    <td className="px-3 py-2 font-medium">{s.stock_code}</td>
                    <td className="px-3 py-2 text-slate-600">{s.display_name || "-"}</td>
                    <td className="px-3 py-2 text-center">{s.priority}</td>
                    <td className="px-3 py-2 text-center">
                      {s.has_gex_data ? <span className="text-emerald-600">✓</span> : <span className="text-slate-400">-</span>}
                    </td>
                    <td className="px-3 py-2 text-center">{getStatusBadge(s)}</td>
                    <td className="px-3 py-2 text-center">
                      {s.status === "pending" && (
                        <button
                          onClick={() => processSingleStock(s.stock_code)}
                          disabled={processing}
                          className="text-xs text-emerald-600 hover:text-emerald-700 disabled:opacity-50"
                        >
                          Process
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Configuration Section */}
      <div className="p-4 rounded-lg border border-slate-200 bg-white">
        <h3 className="text-base font-medium mb-4">Stock Configuration</h3>

        {/* Add Form */}
        <div className="mb-4 flex flex-wrap items-end gap-3">
          <div>
            <label className="block text-xs mb-1 text-slate-500">Stock Code</label>
            <input
              value={newCode}
              onChange={(e) => setNewCode(e.target.value)}
              placeholder="e.g. AAPL"
              className="w-28 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label className="block text-xs mb-1 text-slate-500">Display Name</label>
            <input
              value={newDisplayName}
              onChange={(e) => setNewDisplayName(e.target.value)}
              placeholder="e.g. Apple Inc"
              className="w-40 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label className="block text-xs mb-1 text-slate-500">Priority</label>
            <input
              type="number"
              value={newPriority}
              onChange={(e) => setNewPriority(e.target.value)}
              className="w-20 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm"
            />
          </div>
          <button onClick={addStock} className="h-9 px-4 rounded-md bg-emerald-600 text-white text-sm">
            Add Stock
          </button>
        </div>

        {/* Config Table */}
        <div className="rounded-lg border border-slate-200 overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-slate-600 uppercase text-[11px] tracking-wide border-b border-slate-200">
              <tr>
                <th className="px-3 py-2 text-left">Stock</th>
                <th className="px-3 py-2 text-left">Display Name</th>
                <th className="px-3 py-2 text-center">Priority</th>
                <th className="px-3 py-2 text-center">Active</th>
                <th className="px-3 py-2 text-center">LLM Model</th>
                <th className="px-3 py-2 text-center">Actions</th>
              </tr>
            </thead>
            <tbody>
              {stocks.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-3 py-4 text-center text-slate-500">
                    No stocks configured
                  </td>
                </tr>
              ) : (
                stocks.map((stock, i) => (
                  <tr key={stock.StockCode} className={i % 2 ? "bg-slate-50" : ""}>
                    {editingCode === stock.StockCode ? (
                      <>
                        <td className="px-3 py-2 font-medium">{stock.StockCode}</td>
                        <td className="px-3 py-2">
                          <input
                            value={editDisplayName}
                            onChange={(e) => setEditDisplayName(e.target.value)}
                            className="w-full rounded border border-slate-300 px-2 py-1 text-sm"
                          />
                        </td>
                        <td className="px-3 py-2 text-center">
                          <input
                            type="number"
                            value={editPriority}
                            onChange={(e) => setEditPriority(e.target.value)}
                            className="w-16 rounded border border-slate-300 px-2 py-1 text-sm text-center"
                          />
                        </td>
                        <td className="px-3 py-2 text-center">
                          <input
                            type="checkbox"
                            checked={editActive}
                            onChange={(e) => setEditActive(e.target.checked)}
                            className="h-4 w-4"
                          />
                        </td>
                        <td className="px-3 py-2 text-center text-slate-500">-</td>
                        <td className="px-3 py-2 text-center">
                          <button onClick={saveEdit} className="mr-2 text-xs text-emerald-600 hover:text-emerald-700">
                            Save
                          </button>
                          <button onClick={() => setEditingCode(null)} className="text-xs text-slate-500 hover:text-slate-700">
                            Cancel
                          </button>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="px-3 py-2 font-medium">{stock.StockCode}</td>
                        <td className="px-3 py-2 text-slate-600">{stock.DisplayName || "-"}</td>
                        <td className="px-3 py-2 text-center">{stock.Priority}</td>
                        <td className="px-3 py-2 text-center">
                          {stock.IsActive ? <span className="text-emerald-600">✓</span> : <span className="text-slate-400">✗</span>}
                        </td>
                        <td className="px-3 py-2 text-center text-slate-500 text-xs">{stock.LLMModel || "default"}</td>
                        <td className="px-3 py-2 text-center">
                          <button onClick={() => startEdit(stock)} className="mr-2 text-xs text-slate-600 hover:text-slate-800">
                            Edit
                          </button>
                          <button onClick={() => deleteStock(stock.StockCode)} className="text-xs text-red-600 hover:text-red-700">
                            Delete
                          </button>
                        </td>
                      </>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
