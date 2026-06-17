"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type User = {
  user_id: number;
  email: string;
  display_name?: string;
  is_active: boolean;
  pushover_enabled: boolean;
};

type MarketOption = {
  market_name: string;
  selection_name: string;
  display_name: string;
  proposition_id: string;
  odds: number | null;
  line?: string | number | null;
  is_open: boolean;
};

type Criterion = {
  criterion_id?: number;
  market_name: string;
  selection_name: string;
  proposition_id?: string | null;
  comparison_operator: ">=" | ">" | "<=" | "<" | "=";
  target_odds: number | string;
  latest_odds?: number | null;
  previous_odds?: number | null;
  last_checked_at_utc?: string | null;
  last_alert_at_utc?: string | null;
  alert_count?: number;
  is_currently_matched?: boolean;
};

type Monitor = {
  monitor_id: number;
  name: string;
  source_url: string;
  match_name: string;
  competition_name: string;
  target_user_id: number;
  target_user_name?: string;
  scan_interval_minutes: number;
  expires_at_utc: string;
  alert_once: boolean;
  is_active: boolean;
  last_scan_at_utc?: string | null;
  next_scan_at_utc?: string | null;
  last_success_at_utc?: string | null;
  last_error?: string | null;
  status: "active" | "paused" | "expired" | "error";
  criteria: Criterion[];
};

type Discovery = {
  sport_name: string;
  competition_name: string;
  tournament_name?: string | null;
  match_name: string;
  start_time?: string | null;
  expires_at_sydney?: string | null;
  markets: MarketOption[];
};

const DEFAULT_URL =
  "https://www.tab.com.au/sports/betting/Soccer/competitions/2026%20World%20Cup%20Matches/matches/Netherlands%20v%20Japan";

function parseUtcDate(value: string) {
  const hasTimezone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(value);
  return new Date(hasTimezone ? value : `${value}Z`);
}

function utcToSydneyInput(value: string) {
  const parts = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Australia/Sydney",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(parseUtcDate(value));
  const get = (type: string) => parts.find((part) => part.type === type)?.value || "";
  return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}`;
}

function formatSydney(value?: string | null) {
  if (!value) return "Not yet";
  return new Intl.DateTimeFormat("en-AU", {
    timeZone: "Australia/Sydney",
    dateStyle: "medium",
    timeStyle: "short",
  }).format(parseUtcDate(value));
}

function statusClasses(status: Monitor["status"]) {
  if (status === "active") return "bg-emerald-100 text-emerald-800";
  if (status === "expired") return "bg-slate-200 text-slate-700";
  if (status === "error") return "bg-red-100 text-red-800";
  return "bg-amber-100 text-amber-800";
}

async function responseError(response: Response) {
  try {
    const data = await response.json();
    return data.detail || `HTTP ${response.status}`;
  } catch {
    return `HTTP ${response.status}`;
  }
}

export default function BetOddsMonitorsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [monitors, setMonitors] = useState<Monitor[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [discovery, setDiscovery] = useState<Discovery | null>(null);
  const [selectedOption, setSelectedOption] = useState("");
  const [optionSearch, setOptionSearch] = useState("");
  const [criteria, setCriteria] = useState<Criterion[]>([]);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [discovering, setDiscovering] = useState(false);
  const [saving, setSaving] = useState(false);
  const [scanningId, setScanningId] = useState<number | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [form, setForm] = useState({
    name: "Netherlands v Japan",
    source_url: DEFAULT_URL,
    target_user_id: 0,
    scan_interval_minutes: 10,
    expires_at_sydney: "",
    alert_once: true,
    is_active: true,
  });

  const loadData = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [monitorResponse, userResponse] = await Promise.all([
        authenticatedFetch(`${baseUrl}/api/bet-odds-monitors`),
        authenticatedFetch(`${baseUrl}/api/users?active=true&page_size=100`),
      ]);
      if (!monitorResponse.ok) throw new Error(await responseError(monitorResponse));
      if (!userResponse.ok) throw new Error(await responseError(userResponse));
      const monitorData = await monitorResponse.json();
      const userData = await userResponse.json();
      const pushoverUsers = (userData.items || []).filter(
        (user: User) => user.is_active && user.pushover_enabled,
      );
      setMonitors(monitorData || []);
      setUsers(pushoverUsers);
      setForm((current) => ({
        ...current,
        target_user_id: current.target_user_id || pushoverUsers[0]?.user_id || 0,
      }));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Failed to load monitors");
    } finally {
      setLoading(false);
    }
  }, [baseUrl]);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  const groupedMarkets = useMemo(() => {
    const groups = new Map<string, MarketOption[]>();
    const search = optionSearch.trim().toLocaleLowerCase();
    for (const option of discovery?.markets || []) {
      const searchText =
        `${option.market_name} ${option.display_name}`.toLocaleLowerCase();
      if (search && !searchText.includes(search)) continue;
      const entries = groups.get(option.market_name) || [];
      entries.push(option);
      groups.set(option.market_name, entries);
    }
    return Array.from(groups.entries());
  }, [discovery, optionSearch]);

  const selectedMarketOption = useMemo(
    () =>
      discovery?.markets.find(
        (option, index) => `${option.proposition_id}:${index}` === selectedOption,
      ),
    [discovery, selectedOption],
  );

  const discover = async () => {
    setDiscovering(true);
    setError("");
    setMessage("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/bet-odds-monitors/discover`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ source_url: form.source_url }),
      });
      if (!response.ok) throw new Error(await responseError(response));
      const data: Discovery = await response.json();
      setDiscovery(data);
      setSelectedOption("");
      setOptionSearch("");
      setForm((current) => ({
        ...current,
        name: editingId ? current.name : data.match_name,
        expires_at_sydney: data.expires_at_sydney
          ? utcToSydneyInput(data.expires_at_sydney)
          : "",
      }));
      setMessage(`Loaded ${data.markets.length} selections for ${data.match_name}.`);
    } catch (caught) {
      setDiscovery(null);
      setError(caught instanceof Error ? caught.message : "Could not load TAB markets");
    } finally {
      setDiscovering(false);
    }
  };

  const addCriterion = () => {
    if (!selectedMarketOption) {
      setError("Choose a betting selection first.");
      return;
    }
    if (
      criteria.some(
        (criterion) =>
          criterion.proposition_id === selectedMarketOption.proposition_id &&
          criterion.market_name === selectedMarketOption.market_name,
      )
    ) {
      setError("That selection is already in this monitor.");
      return;
    }
    setCriteria((current) => [
      ...current,
      {
        market_name: selectedMarketOption.market_name,
        selection_name: selectedMarketOption.selection_name,
        proposition_id: selectedMarketOption.proposition_id,
        comparison_operator: ">=",
        target_odds: selectedMarketOption.odds ?? 2.02,
      },
    ]);
    setSelectedOption("");
    setError("");
  };

  const resetForm = () => {
    setEditingId(null);
    setDiscovery(null);
    setSelectedOption("");
    setOptionSearch("");
    setCriteria([]);
    setForm({
      name: "Netherlands v Japan",
      source_url: DEFAULT_URL,
      target_user_id: users[0]?.user_id || 0,
      scan_interval_minutes: 10,
      expires_at_sydney: "",
      alert_once: true,
      is_active: true,
    });
  };

  const saveMonitor = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setMessage("");
    if (!form.target_user_id) {
      setError("Choose a Pushover recipient.");
      return;
    }
    if (!criteria.length) {
      setError("Add at least one odds criterion.");
      return;
    }
    if (!form.expires_at_sydney) {
      setError("Load the TAB betting items to calculate the automatic expiry.");
      return;
    }
    const normalizedCriteria = criteria.map((criterion) => ({
      ...criterion,
      target_odds: Number(criterion.target_odds),
    }));
    if (
      normalizedCriteria.some(
        (criterion) =>
          !Number.isFinite(criterion.target_odds) || criterion.target_odds <= 0,
      )
    ) {
      setError("Each trigger value must be a number greater than 0.");
      return;
    }
    setSaving(true);
    try {
      const response = await authenticatedFetch(
        `${baseUrl}/api/bet-odds-monitors${editingId ? `/${editingId}` : ""}`,
        {
          method: editingId ? "PUT" : "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ ...form, criteria: normalizedCriteria }),
        },
      );
      if (!response.ok) throw new Error(await responseError(response));
      setMessage(editingId ? "Monitor updated." : "Monitor created and queued for its first scan.");
      if (editingId) {
        resetForm();
      } else {
        setEditingId(null);
        setSelectedOption("");
        setCriteria([]);
        setForm((current) => ({
          ...current,
          name: discovery?.match_name || current.name,
          is_active: true,
        }));
      }
      await loadData();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Failed to save monitor");
    } finally {
      setSaving(false);
    }
  };

  const editMonitor = (monitor: Monitor) => {
    setEditingId(monitor.monitor_id);
    setDiscovery(null);
    setCriteria(monitor.criteria);
    setForm({
      name: monitor.name,
      source_url: monitor.source_url,
      target_user_id: monitor.target_user_id,
      scan_interval_minutes: monitor.scan_interval_minutes,
      expires_at_sydney: utcToSydneyInput(monitor.expires_at_utc),
      alert_once: monitor.alert_once,
      is_active: monitor.is_active,
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const scanNow = async (monitorId: number) => {
    setScanningId(monitorId);
    setError("");
    setMessage("");
    try {
      const response = await authenticatedFetch(
        `${baseUrl}/api/bet-odds-monitors/${monitorId}/scan`,
        { method: "POST" },
      );
      if (!response.ok) throw new Error(await responseError(response));
      setMessage("Scan completed.");
      await loadData();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Scan failed");
      await loadData();
    } finally {
      setScanningId(null);
    }
  };

  const toggleMonitor = async (monitor: Monitor) => {
    setError("");
    try {
      const response = await authenticatedFetch(
        `${baseUrl}/api/bet-odds-monitors/${monitor.monitor_id}`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            name: monitor.name,
            source_url: monitor.source_url,
            target_user_id: monitor.target_user_id,
            scan_interval_minutes: monitor.scan_interval_minutes,
            expires_at_sydney: utcToSydneyInput(monitor.expires_at_utc),
            alert_once: monitor.alert_once,
            is_active: !monitor.is_active,
            criteria: monitor.criteria,
          }),
        },
      );
      if (!response.ok) throw new Error(await responseError(response));
      await loadData();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not update monitor");
    }
  };

  const deleteMonitor = async (monitor: Monitor) => {
    if (!window.confirm(`Delete "${monitor.name}" and its scan history?`)) return;
    setError("");
    try {
      const response = await authenticatedFetch(
        `${baseUrl}/api/bet-odds-monitors/${monitor.monitor_id}`,
        { method: "DELETE" },
      );
      if (!response.ok) throw new Error(await responseError(response));
      if (editingId === monitor.monitor_id) resetForm();
      await loadData();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not delete monitor");
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <main className="mx-auto max-w-7xl px-5 py-8 sm:px-8">
        <div className="mb-8 flex flex-col gap-2">
          <div className="text-xs font-semibold uppercase tracking-[0.2em] text-emerald-700">
            World Cup odds
          </div>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Bet Odds Monitor
          </h1>
          <p className="max-w-3xl text-sm leading-6 text-slate-600">
            Track TAB selections on a schedule and send a Pushover message when a price
            reaches your target. Expiry times are interpreted in Australia/Sydney.
          </p>
        </div>

        {error && (
          <div className="mb-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
            {error}
          </div>
        )}
        {message && (
          <div className="mb-5 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
            {message}
          </div>
        )}

        <form
          onSubmit={saveMonitor}
          className="mb-10 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7"
        >
          <div className="mb-6 flex items-center justify-between gap-4">
            <div>
              <h2 className="text-xl font-semibold">
                {editingId ? "Edit monitor" : "Create monitor"}
              </h2>
              <p className="mt-1 text-sm text-slate-500">
                Load the TAB link first, then choose one or more returned selections.
              </p>
            </div>
            {editingId && (
              <button
                type="button"
                onClick={resetForm}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50"
              >
                Cancel edit
              </button>
            )}
          </div>

          <div className="grid gap-5 lg:grid-cols-[1fr_auto]">
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium">TAB match URL</span>
              <input
                required
                type="url"
                value={form.source_url}
                onChange={(event) => {
                  setDiscovery(null);
                  setCriteria([]);
                  setSelectedOption("");
                  setOptionSearch("");
                  setForm((current) => ({
                    ...current,
                    source_url: event.target.value,
                    expires_at_sydney: "",
                  }));
                }}
                className="w-full rounded-lg border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
              />
            </label>
            <button
              type="button"
              disabled={discovering || !form.source_url}
              onClick={discover}
              className="self-end rounded-lg bg-slate-900 px-5 py-2.5 text-sm font-medium text-white disabled:opacity-50"
            >
              {discovering ? "Loading markets..." : "Load betting items"}
            </button>
          </div>

          {discovery && (
            <div className="mt-5 rounded-xl border border-emerald-200 bg-emerald-50/60 p-4">
              <div className="mb-3 text-sm">
                <span className="font-semibold">{discovery.match_name}</span>
                <span className="text-slate-600"> · {discovery.competition_name}</span>
              </div>
              {discovery.start_time && (
                <div className="mb-3 grid gap-2 text-xs text-slate-600 sm:grid-cols-2">
                  <div>
                    Match starts:{" "}
                    <span className="font-semibold text-slate-800">
                      {formatSydney(discovery.start_time)}
                    </span>
                  </div>
                  <div>
                    Monitoring expires:{" "}
                    <span className="font-semibold text-slate-800">
                      {discovery.expires_at_sydney
                        ? formatSydney(discovery.expires_at_sydney)
                        : "Unavailable"}
                    </span>
                  </div>
                </div>
              )}
              <div className="mb-3">
                <input
                  value={optionSearch}
                  onChange={(event) => {
                    setOptionSearch(event.target.value);
                    setSelectedOption("");
                  }}
                  placeholder="Filter selections, e.g. Japan +0.5 or Nethld Under 1.5"
                  className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm"
                />
              </div>
              <div className="flex flex-col gap-3 lg:flex-row">
                <select
                  value={selectedOption}
                  onChange={(event) => setSelectedOption(event.target.value)}
                  className="min-w-0 flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm"
                >
                  <option value="">Choose market and selection</option>
                  {groupedMarkets.map(([marketName, options]) => (
                    <optgroup key={marketName} label={marketName}>
                      {options.map((option) => {
                        const index = discovery.markets.indexOf(option);
                        return (
                          <option
                            key={`${option.proposition_id}:${index}`}
                            value={`${option.proposition_id}:${index}`}
                          >
                            {option.display_name}
                            {option.odds !== null ? ` — ${option.odds.toFixed(2)}` : " — unavailable"}
                          </option>
                        );
                      })}
                    </optgroup>
                  ))}
                </select>
                <button
                  type="button"
                  onClick={addCriterion}
                  disabled={!selectedOption}
                  className="rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-medium text-white disabled:opacity-50"
                >
                  Add criterion
                </button>
              </div>
              <div className="mt-2 text-xs text-slate-500">
                Showing {groupedMarkets.reduce((count, [, options]) => count + options.length, 0)} of{" "}
                {discovery.markets.length} selections.
              </div>
            </div>
          )}

          <div className="mt-6 space-y-3">
            <div className="text-sm font-medium">Trigger criteria</div>
            {!criteria.length && (
              <div className="rounded-lg border border-dashed border-slate-300 px-4 py-5 text-sm text-slate-500">
                No criteria added yet.
              </div>
            )}
            {criteria.map((criterion, index) => (
              <div
                key={`${criterion.proposition_id}:${index}`}
                className="grid gap-3 rounded-xl border border-slate-200 bg-slate-50 p-4 md:grid-cols-[1fr_100px_130px_auto]"
              >
                <div>
                  <div className="font-medium">{criterion.selection_name}</div>
                  <div className="text-xs text-slate-500">{criterion.market_name}</div>
                </div>
                <select
                  value={criterion.comparison_operator}
                  onChange={(event) =>
                    setCriteria((current) =>
                      current.map((item, itemIndex) =>
                        itemIndex === index
                          ? {
                              ...item,
                              comparison_operator: event.target
                                .value as Criterion["comparison_operator"],
                            }
                          : item,
                      ),
                    )
                  }
                  className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
                >
                  {["≥", ">", "≤", "<", "="].map((label, operatorIndex) => {
                    const value = [">=", ">", "<=", "<", "="][operatorIndex];
                    return (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    );
                  })}
                </select>
                <input
                  type="text"
                  inputMode="decimal"
                  required
                  value={criterion.target_odds}
                  onChange={(event) =>
                    setCriteria((current) =>
                      current.map((item, itemIndex) =>
                        itemIndex === index
                          ? { ...item, target_odds: event.target.value }
                          : item,
                      ),
                    )
                  }
                  className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
                />
                <button
                  type="button"
                  onClick={() =>
                    setCriteria((current) =>
                      current.filter((_, itemIndex) => itemIndex !== index),
                    )
                  }
                  className="rounded-lg border border-red-200 px-3 py-2 text-sm text-red-700 hover:bg-red-50"
                >
                  Remove
                </button>
              </div>
            ))}
          </div>

          <div className="mt-6 grid gap-5 md:grid-cols-2 lg:grid-cols-4">
            <label>
              <span className="mb-1.5 block text-sm font-medium">Monitor name</span>
              <input
                required
                value={form.name}
                onChange={(event) =>
                  setForm((current) => ({ ...current, name: event.target.value }))
                }
                className="w-full rounded-lg border border-slate-300 px-3 py-2.5 text-sm"
              />
            </label>
            <label>
              <span className="mb-1.5 block text-sm font-medium">Pushover recipient</span>
              <select
                required
                value={form.target_user_id}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    target_user_id: Number(event.target.value),
                  }))
                }
                className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm"
              >
                <option value={0}>Choose user</option>
                {users.map((user) => (
                  <option key={user.user_id} value={user.user_id}>
                    {user.display_name || user.email}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span className="mb-1.5 block text-sm font-medium">Scan every</span>
              <div className="relative">
                <input
                  type="number"
                  min="1"
                  max="1440"
                  required
                  value={form.scan_interval_minutes}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      scan_interval_minutes: Number(event.target.value),
                    }))
                  }
                  className="w-full rounded-lg border border-slate-300 px-3 py-2.5 pr-20 text-sm"
                />
                <span className="pointer-events-none absolute right-3 top-2.5 text-sm text-slate-500">
                  minutes
                </span>
              </div>
            </label>
            <label>
              <span className="mb-1.5 block text-sm font-medium">
                Automatic expiry (Sydney)
              </span>
              <input
                type="datetime-local"
                required
                readOnly
                value={form.expires_at_sydney}
                className="w-full cursor-not-allowed rounded-lg border border-slate-300 bg-slate-100 px-3 py-2.5 text-sm text-slate-700"
              />
              <span className="mt-1 block text-xs text-slate-500">
                Set to 30 minutes before the TAB match start.
              </span>
            </label>
          </div>

          <div className="mt-6 flex flex-col justify-between gap-4 border-t border-slate-200 pt-5 sm:flex-row sm:items-center">
            <div className="flex flex-wrap gap-5">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={form.alert_once}
                  onChange={(event) =>
                    setForm((current) => ({ ...current, alert_once: event.target.checked }))
                  }
                  className="h-4 w-4 accent-emerald-600"
                />
                Alert once only
              </label>
              {editingId && (
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(event) =>
                      setForm((current) => ({ ...current, is_active: event.target.checked }))
                    }
                    className="h-4 w-4 accent-emerald-600"
                  />
                  Monitor active
                </label>
              )}
            </div>
            <button
              type="submit"
              disabled={saving}
              className="rounded-lg bg-emerald-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700 disabled:opacity-50"
            >
              {saving ? "Saving..." : editingId ? "Update monitor" : "Create monitor"}
            </button>
          </div>
        </form>

        <section>
          <div className="mb-4 flex items-end justify-between">
            <div>
              <h2 className="text-2xl font-semibold">Your monitors</h2>
              <p className="mt-1 text-sm text-slate-500">
                These scans continue in the backend when this page is closed.
              </p>
            </div>
            <button
              type="button"
              onClick={() => void loadData()}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm hover:bg-slate-50"
            >
              Refresh
            </button>
          </div>

          {loading ? (
            <div className="rounded-xl border border-slate-200 bg-white p-8 text-sm text-slate-500">
              Loading monitors...
            </div>
          ) : !monitors.length ? (
            <div className="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
              No odds monitors yet.
            </div>
          ) : (
            <div className="grid gap-5 xl:grid-cols-2">
              {monitors.map((monitor) => (
                <article
                  key={monitor.monitor_id}
                  className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0">
                      <h3 className="truncate text-lg font-semibold">{monitor.name}</h3>
                      <p className="mt-1 text-sm text-slate-500">{monitor.competition_name}</p>
                    </div>
                    <span
                      className={`rounded-full px-2.5 py-1 text-xs font-semibold capitalize ${statusClasses(
                        monitor.status,
                      )}`}
                    >
                      {monitor.status}
                    </span>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
                    <div className="rounded-lg bg-slate-50 p-3">
                      <div className="text-xs text-slate-500">Last scan</div>
                      <div className="mt-1 font-medium">{formatSydney(monitor.last_scan_at_utc)}</div>
                    </div>
                    <div className="rounded-lg bg-slate-50 p-3">
                      <div className="text-xs text-slate-500">
                        {monitor.status === "expired" ? "Expired" : "Next scan"}
                      </div>
                      <div className="mt-1 font-medium">
                        {formatSydney(
                          monitor.status === "expired"
                            ? monitor.expires_at_utc
                            : monitor.next_scan_at_utc,
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 space-y-2">
                    {monitor.criteria.map((criterion) => (
                      <div
                        key={criterion.criterion_id}
                        className="flex items-center justify-between gap-4 rounded-lg border border-slate-200 px-3 py-3 text-sm"
                      >
                        <div className="min-w-0">
                          <div className="truncate font-medium">{criterion.selection_name}</div>
                          <div className="truncate text-xs text-slate-500">
                            {criterion.market_name} · target {criterion.comparison_operator}{" "}
                            {Number(criterion.target_odds).toFixed(2)}
                          </div>
                        </div>
                        <div className="text-right">
                          <div
                            className={`font-semibold ${
                              criterion.is_currently_matched
                                ? "text-emerald-700"
                                : "text-slate-800"
                            }`}
                          >
                            {criterion.latest_odds == null
                              ? "Unavailable"
                              : Number(criterion.latest_odds).toFixed(2)}
                          </div>
                          <div className="text-xs text-slate-500">
                            {criterion.alert_count || 0} alert
                            {(criterion.alert_count || 0) === 1 ? "" : "s"}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>

                  {monitor.last_error && (
                    <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
                      {monitor.last_error}
                    </div>
                  )}

                  <div className="mt-5 flex flex-wrap gap-2 border-t border-slate-200 pt-4">
                    <button
                      type="button"
                      disabled={scanningId === monitor.monitor_id || monitor.status === "expired"}
                      onClick={() => void scanNow(monitor.monitor_id)}
                      className="rounded-lg bg-slate-900 px-3 py-2 text-xs font-medium text-white disabled:opacity-40"
                    >
                      {scanningId === monitor.monitor_id ? "Scanning..." : "Scan now"}
                    </button>
                    <button
                      type="button"
                      disabled={monitor.status === "expired"}
                      onClick={() => void toggleMonitor(monitor)}
                      className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-medium"
                    >
                      {monitor.is_active ? "Pause" : "Resume"}
                    </button>
                    <button
                      type="button"
                      onClick={() => editMonitor(monitor)}
                      className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-medium"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => void deleteMonitor(monitor)}
                      className="ml-auto rounded-lg border border-red-200 px-3 py-2 text-xs font-medium text-red-700"
                    >
                      Delete
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
