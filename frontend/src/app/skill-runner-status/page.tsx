"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import { formatAge, formatBytes, formatTime, snapshotAgeSeconds, usagePercent } from "./format";

const REFRESH_MS = 30_000;
const REQUEST_TIMEOUT_MS = 18_000;

type RunnerJob = {
  job_id: string;
  name?: string | null;
  job_type?: string | null;
  label?: string | null;
  stock_code?: string | null;
  status?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

type RunnerStatus = {
  as_of: string;
  source?: "compatibility";
  skill_runner: {
    running: number;
    queued: number;
    outstanding: number;
    max_outstanding: number;
    max_concurrent: number;
    by_job_type: Record<string, { running: number; queued: number }>;
    running_jobs: RunnerJob[];
    queued_jobs: RunnerJob[];
  };
  memory?: {
    process_rss_bytes?: number | null;
    system_total_bytes?: number | null;
    system_available_bytes?: number | null;
    system_used_bytes?: number | null;
    swap_total_bytes?: number | null;
    swap_used_bytes?: number | null;
  } | null;
};

function isRunnerStatus(value: unknown): value is RunnerStatus {
  if (!value || typeof value !== "object") return false;
  const snapshot = value as Partial<RunnerStatus>;
  const runner = snapshot.skill_runner;
  return typeof snapshot.as_of === "string" && !!runner &&
    [runner.running, runner.queued, runner.outstanding, runner.max_outstanding, runner.max_concurrent]
      .every((number) => typeof number === "number" && Number.isFinite(number)) &&
    !!runner.by_job_type && typeof runner.by_job_type === "object" && !Array.isArray(runner.by_job_type) &&
    Object.values(runner.by_job_type).every((counts) => counts && typeof counts.running === "number" && typeof counts.queued === "number") &&
    Array.isArray(runner.running_jobs) && Array.isArray(runner.queued_jobs) &&
    [...runner.running_jobs, ...runner.queued_jobs].every((job) => job && typeof job === "object");
}

function Metric({ label, value, detail, tone = "slate" }: { label: string; value: number; detail?: string; tone?: "slate" | "emerald" | "amber" }) {
  const colors = { slate: "text-slate-900", emerald: "text-emerald-700", amber: "text-amber-700" };
  return <Card><CardContent className="pt-5">
    <div className="text-sm text-slate-500">{label}</div>
    <div className={`mt-1 text-3xl font-semibold tabular-nums ${colors[tone]}`}>{value.toLocaleString()}</div>
    {detail ? <div className="mt-1 text-xs text-slate-500">{detail}</div> : null}
  </CardContent></Card>;
}

function Capacity({ label, used, total }: { label: string; used: number; total: number }) {
  const percent = usagePercent(used, total);
  return <div>
    <div className="flex justify-between gap-3 text-sm"><span>{label}</span><span className="font-medium tabular-nums">{used} / {total}</span></div>
    <div className="mt-2 h-2 overflow-hidden rounded-full bg-slate-100" role="progressbar" aria-label={label} aria-valuenow={used} aria-valuemin={0} aria-valuemax={total}>
      <div className={`h-full rounded-full ${percent !== null && percent >= 90 ? "bg-amber-500" : "bg-indigo-500"}`} style={{ width: `${percent ?? 0}%` }} />
    </div>
  </div>;
}

function JobsTable({ title, jobs }: { title: string; jobs: RunnerJob[] }) {
  return <Card>
    <CardHeader><CardTitle>{title} ({jobs.length})</CardTitle></CardHeader>
    <CardContent>
      {jobs.length === 0 ? <p className="text-sm text-slate-500">No {title.toLowerCase()}.</p> :
        <div className="overflow-x-auto"><table className="w-full min-w-[850px] text-left text-sm">
          <thead><tr className="border-b border-slate-200 text-xs uppercase tracking-wide text-slate-500">
            <th className="py-2 pr-4">Job ID</th><th className="py-2 pr-4">Name / stock</th><th className="py-2 pr-4">Job type</th>
            <th className="py-2 pr-4">Status</th><th className="py-2 pr-4">Created</th><th className="py-2">Updated</th>
          </tr></thead>
          <tbody>{jobs.map((job, index) => <tr key={`${job.job_id}-${index}`} className="border-b border-slate-100 last:border-0">
            <td className="py-3 pr-4 font-mono text-xs text-slate-700">{job.job_id || "n/a"}</td>
            <td className="py-3 pr-4 font-medium text-slate-900">{job.label || job.name || job.stock_code || "n/a"}{job.stock_code && job.stock_code !== (job.label || job.name) ? <span className="ml-1 text-xs text-slate-500">({job.stock_code})</span> : null}</td>
            <td className="py-3 pr-4 text-slate-700">{job.job_type || "n/a"}</td>
            <td className="py-3 pr-4 text-slate-700">{job.status || "n/a"}</td>
            <td className="py-3 pr-4 whitespace-nowrap text-slate-600">{formatTime(job.created_at)}</td>
            <td className="py-3 whitespace-nowrap text-slate-600">{formatTime(job.updated_at)}</td>
          </tr>)}</tbody>
        </table></div>}
    </CardContent>
  </Card>;
}

export default function SkillRunnerStatusPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [status, setStatus] = useState<RunnerStatus | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const controllerRef = useRef<AbortController | null>(null);
  const sequence = useRef(0);

  const refresh = useCallback(async () => {
    controllerRef.current?.abort();
    const requestId = ++sequence.current;
    const controller = new AbortController();
    controllerRef.current = controller;
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    setLoading(true);
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/skill-runner/system-status`, { cache: "no-store", signal: controller.signal });
      const payload: unknown = await response.json().catch(() => null);
      if (!response.ok) {
        const detail = payload && typeof payload === "object" && "detail" in payload ? String(payload.detail) : `HTTP ${response.status}`;
        throw new Error(detail);
      }
      if (!isRunnerStatus(payload)) throw new Error("Skill runner returned an invalid status response.");
      if (sequence.current !== requestId) return;
      setStatus(payload);
      setError("");
    } catch (exc) {
      if (sequence.current !== requestId) return;
      setError(controller.signal.aborted ? "Status request timed out. The skill runner may be unavailable." : exc instanceof Error ? exc.message : "Unable to load skill runner status.");
    } finally {
      window.clearTimeout(timeout);
      if (sequence.current === requestId) {
        controllerRef.current = null;
        setNow(Date.now());
        setLoading(false);
      }
    }
  }, [baseUrl]);

  useEffect(() => {
    void refresh();
    const interval = window.setInterval(() => { void refresh(); }, REFRESH_MS);
    return () => {
      window.clearInterval(interval);
      sequence.current++;
      controllerRef.current?.abort();
    };
  }, [refresh]);

  const runner = status?.skill_runner;
  const memory = status?.memory;
  const age = status ? snapshotAgeSeconds(status.as_of, now) : null;
  const stale = status && (age === null || age > 60);
  const health = error ? "Unavailable" : !status ? "Checking" : stale ? "Stale snapshot" : status.source === "compatibility" ? "Connected (compatibility)" : "Connected";
  const healthColor = error ? "border-red-200 bg-red-50 text-red-700" : !status ? "border-slate-200 bg-slate-50 text-slate-700" : stale ? "border-amber-200 bg-amber-50 text-amber-700" : "border-emerald-200 bg-emerald-50 text-emerald-700";
  const types = runner ? Object.entries(runner.by_job_type).sort(([a], [b]) => a.localeCompare(b)) : [];
  const systemPercent = usagePercent(memory?.system_used_bytes, memory?.system_total_bytes);
  const swapPercent = usagePercent(memory?.swap_used_bytes, memory?.swap_total_bytes);

  return <div className="space-y-6">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <PageHeader title="Skill Runner Status" subtitle="Service health, job capacity, active work and memory from the skill runner." />
      <div className="flex items-center gap-3">
        <span className={`rounded-full border px-3 py-1.5 text-xs font-semibold ${healthColor}`} role="status">{health}</span>
        <Button type="button" onClick={() => void refresh()} disabled={loading}>{loading ? "Refreshing..." : "Refresh now"}</Button>
      </div>
    </div>
    <p className="text-sm text-slate-500">Refreshes every 30 seconds. {status?.source === "compatibility" ? "Snapshot assembled" : "Runner snapshot"}: {formatTime(status?.as_of)} ({formatAge(age)}).{error && status ? " Showing last successful snapshot." : ""}</p>
    {status?.source === "compatibility" ? <Alert variant="warning">This runner does not expose /api/system/status yet. Showing capacity and active jobs from /health and /api/jobs; remote memory metrics are unavailable until the new endpoint is deployed.</Alert> : null}
    {error ? <Alert variant="danger">Skill runner status unavailable: {error}</Alert> : null}
    {!status ? (loading ? <Card><CardContent className="pt-5 text-sm text-slate-500">Checking the skill runner...</CardContent></Card> : null) : <>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
        <Metric label="Running" value={runner!.running} detail={`Limit: ${runner!.max_concurrent}`} tone="emerald" />
        <Metric label="Queued" value={runner!.queued} tone="amber" />
        <Metric label="Outstanding" value={runner!.outstanding} detail={`Limit: ${runner!.max_outstanding}`} />
        <Metric label="Max concurrent" value={runner!.max_concurrent} />
        <Metric label="Max outstanding" value={runner!.max_outstanding} />
      </div>
      <Card><CardHeader><CardTitle>Capacity</CardTitle></CardHeader><CardContent className="grid gap-5 md:grid-cols-2">
        <Capacity label="Running slots" used={runner!.running} total={runner!.max_concurrent} />
        <Capacity label="Outstanding jobs" used={runner!.outstanding} total={runner!.max_outstanding} />
      </CardContent></Card>
      <div className="grid gap-6 lg:grid-cols-2">
        <Card><CardHeader><CardTitle>Jobs by type</CardTitle></CardHeader><CardContent>
          {types.length ? <div className="overflow-x-auto"><table className="w-full text-left text-sm"><thead><tr className="border-b border-slate-200 text-slate-500"><th className="py-2">Job type</th><th className="py-2 text-right">Running</th><th className="py-2 text-right">Queued</th></tr></thead>
            <tbody>{types.map(([type, counts]) => <tr key={type} className="border-b border-slate-100 last:border-0"><td className="py-2 font-medium">{type}</td><td className="py-2 text-right tabular-nums">{counts.running}</td><td className="py-2 text-right tabular-nums">{counts.queued}</td></tr>)}</tbody></table></div> : <p className="text-sm text-slate-500">No jobs by type.</p>}
        </CardContent></Card>
        <Card><CardHeader><CardTitle>Memory</CardTitle></CardHeader><CardContent className="space-y-4 text-sm">
          <div className="flex justify-between gap-3"><span>Runner process RSS</span><strong>{formatBytes(memory?.process_rss_bytes)}</strong></div>
          <div className="flex justify-between gap-3"><span>System used / total</span><strong>{formatBytes(memory?.system_used_bytes)} / {formatBytes(memory?.system_total_bytes)}</strong></div>
          {systemPercent !== null ? <div className="h-2 overflow-hidden rounded-full bg-slate-100"><div className="h-full rounded-full bg-indigo-500" style={{ width: `${systemPercent}%` }} /></div> : null}
          <div className="flex justify-between gap-3"><span>System available</span><strong>{formatBytes(memory?.system_available_bytes)}</strong></div>
          <div className="flex justify-between gap-3"><span>Swap used / total</span><strong>{formatBytes(memory?.swap_used_bytes)} / {formatBytes(memory?.swap_total_bytes)}</strong></div>
          {swapPercent !== null ? <div className="h-2 overflow-hidden rounded-full bg-slate-100"><div className="h-full rounded-full bg-amber-500" style={{ width: `${swapPercent}%` }} /></div> : null}
        </CardContent></Card>
      </div>
      <JobsTable title="Running jobs" jobs={runner!.running_jobs} />
      <JobsTable title="Queued jobs" jobs={runner!.queued_jobs} />
    </>}
  </div>;
}
