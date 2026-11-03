"use client";

import { useCallback, useEffect, useMemo, useRef, useState, type UIEvent } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type ChannelDayCounts = {
  channel_id: string;
  channel_name: string;
  is_active: boolean;
  daily_counts: Record<string, number>;
};
type ExtractIndex = {
  timezone: string;
  window_definition: string;
  dates: string[];
  channels: ChannelDayCounts[];
  earliest_observation_date: string | null;
  has_earlier: boolean;
};
type SelectedDay = { channelId: string; date: string };
type PromptData = {
  prompt: string;
  channel_name: string;
  observation_dates: string[];
  windows: Array<{ observation_date: string; window_start: string; window_end: string }>;
  window_start: string;
  window_end: string;
  message_count: number;
  estimated_tokens: number;
};

const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
const PAGE_DAYS = 14;

function displayDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { timeZone: "Australia/Sydney", month: "short", day: "numeric" }).format(new Date(`${value}T12:00:00Z`));
}

function previousDate(value: string) {
  const date = new Date(`${value}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

export default function DiscordMessageExtractorTab() {
  const [index, setIndex] = useState<ExtractIndex | null>(null);
  const indexRef = useRef<ExtractIndex | null>(null);
  const gridRef = useRef<HTMLDivElement | null>(null);
  const loadingOlderRef = useRef(false);
  const [loading, setLoading] = useState(true);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState<SelectedDay[]>([]);
  const [promptData, setPromptData] = useState<PromptData | null>(null);
  const [promptLoading, setPromptLoading] = useState(false);
  const [promptError, setPromptError] = useState("");
  const [copied, setCopied] = useState(false);

  useEffect(() => { indexRef.current = index; }, [index]);

  const loadIndex = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/discord-message-extract/index?days=${PAGE_DAYS}`, { cache: "no-store" });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      setIndex(payload as ExtractIndex);
      setSelected([]);
      setPromptData(null);
      setPromptError("");
      setCopied(false);
    } catch (exc) {
      setError(exc instanceof Error ? exc.message : String(exc));
    } finally {
      setLoading(false);
    }
  }, []);

  const loadEarlier = useCallback(async () => {
    const current = indexRef.current;
    if (!current?.has_earlier || !current.dates.length || loadingOlderRef.current) return;
    loadingOlderRef.current = true;
    setLoadingOlder(true);
    setError("");
    try {
      const endDate = previousDate(current.dates[0]);
      const query = new URLSearchParams({ days: String(PAGE_DAYS), end_observation_date: endDate });
      const response = await authenticatedFetch(`${baseUrl}/api/discord-message-extract/index?${query}`, { cache: "no-store" });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      const older = payload as ExtractIndex;
      setIndex((existing) => {
        if (!existing) return older;
        const olderById = new Map(older.channels.map((channel) => [channel.channel_id, channel]));
        const mergedChannels = existing.channels.map((channel) => {
          const oldChannel = olderById.get(channel.channel_id);
          if (!oldChannel) return channel;
          olderById.delete(channel.channel_id);
          return { ...oldChannel, ...channel, daily_counts: { ...oldChannel.daily_counts, ...channel.daily_counts } };
        });
        mergedChannels.push(...olderById.values());
        return {
          ...existing,
          dates: [...new Set([...older.dates, ...existing.dates])].sort(),
          channels: mergedChannels,
          earliest_observation_date: older.earliest_observation_date,
          has_earlier: older.has_earlier,
        };
      });
    } catch (exc) {
      setError(exc instanceof Error ? exc.message : String(exc));
    } finally {
      loadingOlderRef.current = false;
      setLoadingOlder(false);
    }
  }, []);

  useEffect(() => { void loadIndex(); }, [loadIndex]);

  const selectedChannelId = selected[0]?.channelId || null;
  const selectedChannel = useMemo(
    () => index?.channels.find((channel) => channel.channel_id === selectedChannelId) || null,
    [index, selectedChannelId],
  );
  const selectedCount = selected.reduce((total, item) => {
    const channel = index?.channels.find((candidate) => candidate.channel_id === item.channelId);
    return total + (channel?.daily_counts[item.date] || 0);
  }, 0);
  const selectedDates = useMemo(() => selected.map((item) => item.date).sort(), [selected]);
  const visibleDates = useMemo(() => index?.dates.slice().reverse() || [], [index]);

  const choose = (channelId: string, date: string, count: number) => {
    if (count <= 0) return;
    setSelected((current) => {
      if (current[0]?.channelId !== channelId) return [{ channelId, date }];
      const alreadySelected = current.some((item) => item.date === date);
      return alreadySelected ? current.filter((item) => item.date !== date) : [...current, { channelId, date }].sort((a, b) => a.date.localeCompare(b.date));
    });
    setPromptData(null);
    setPromptError("");
    setCopied(false);
  };

  const onGridScroll = (event: UIEvent<HTMLDivElement>) => {
    const element = event.currentTarget;
    const atOlderEdge = element.scrollLeft + element.clientWidth >= element.scrollWidth - 100;
    if (atOlderEdge) void loadEarlier();
  };

  const getPrompt = async () => {
    if (!selectedChannelId || selectedDates.length === 0 || selectedCount < 1) return;
    setPromptLoading(true);
    setPromptError("");
    setCopied(false);
    try {
      const query = new URLSearchParams({ channel_id: selectedChannelId });
      selectedDates.forEach((date) => query.append("observation_dates", date));
      const response = await authenticatedFetch(`${baseUrl}/api/discord-message-extract/prompt?${query}`, { cache: "no-store" });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      setPromptData(payload as PromptData);
    } catch (exc) {
      setPromptError(exc instanceof Error ? exc.message : String(exc));
      setPromptData(null);
    } finally {
      setPromptLoading(false);
    }
  };

  const copyPrompt = async () => {
    if (!promptData?.prompt) return;
    try {
      await navigator.clipboard.writeText(promptData.prompt);
    } catch {
      const textarea = document.createElement("textarea");
      textarea.value = promptData.prompt;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.focus();
      textarea.select();
      const success = document.execCommand("copy");
      document.body.removeChild(textarea);
      if (!success) {
        setPromptError("Copy failed. Select the prompt text and copy it manually.");
        return;
      }
    }
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section className="space-y-4 rounded-lg border border-slate-200 bg-white p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-800">Channel Message Extractor</h2>
          <p className="mt-1 text-sm text-slate-600">Select one or more dates in the same channel to build a copyable ChatGPT prompt with the raw messages.</p>
          <p className="mt-1 text-xs text-slate-500">{index?.window_definition || "Counts are grouped into Sydney 16:00-to-16:00 observation days."} Use the horizontal scrollbar to load earlier dates and the vertical scrollbar to browse channels.</p>
        </div>
        <button type="button" onClick={() => void loadIndex()} disabled={loading} className="rounded-md border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50 disabled:opacity-50">
          {loading ? "Refreshing…" : "Refresh channels"}
        </button>
      </div>

      {error ? <div role="alert" className="rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div> : null}
      {loading && !index ? <p className="text-sm text-slate-500">Loading channels and daily message counts…</p> : null}

      {index ? <div ref={gridRef} onScroll={onGridScroll} className="max-h-[65vh] overflow-auto rounded border border-slate-200">
        <table className="min-w-full border-collapse text-left text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-600">
            <tr>
              <th className="sticky left-0 top-0 z-30 min-w-52 bg-slate-50 px-3 py-2">Channel</th>
              {visibleDates.map((date) => <th key={date} className="sticky top-0 z-20 min-w-20 bg-slate-50 px-2 py-2 text-center">{displayDate(date)}</th>)}
            </tr>
          </thead>
          <tbody>
            {index.channels.map((channel) => <tr key={channel.channel_id} className="border-t border-slate-100">
              <th scope="row" className="sticky left-0 z-10 bg-white px-3 py-2 font-medium text-slate-800">
                <span>{channel.channel_name}</span>{!channel.is_active ? <span className="ml-2 text-[10px] text-slate-400">inactive</span> : null}
              </th>
              {visibleDates.map((date) => {
                const count = channel.daily_counts[date] || 0;
                const isSelected = selectedChannelId === channel.channel_id && selected.some((item) => item.date === date);
                return <td key={`${channel.channel_id}-${date}`} className="px-1 py-1 text-center">
                  <button type="button" disabled={count === 0} aria-label={`${channel.channel_name}, ${date}: ${count} messages`}
                    aria-pressed={isSelected} onClick={() => choose(channel.channel_id, date, count)}
                    className={`min-w-12 rounded px-2 py-1 text-xs ${isSelected ? "bg-indigo-600 font-semibold text-white" : count ? "bg-indigo-50 text-indigo-800 hover:bg-indigo-100" : "text-slate-300"} disabled:cursor-default`}>
                    {count.toLocaleString()}
                  </button>
                </td>;
              })}
            </tr>)}
            {!index.channels.length ? <tr><td colSpan={visibleDates.length + 1} className="px-3 py-6 text-center text-slate-500">No Discord channels found.</td></tr> : null}
          </tbody>
        </table>
      </div> : null}
      {loadingOlder ? <p className="text-xs text-slate-500">Loading earlier dates…</p> : null}
      {index && !index.has_earlier ? <p className="text-xs text-slate-500">You have reached the earliest available message date{index.earliest_observation_date ? ` (${index.earliest_observation_date})` : ""}.</p> : null}

      {selected.length > 0 ? <div className="space-y-3 rounded border border-indigo-100 bg-indigo-50 p-3 text-sm">
        <div className="flex flex-wrap items-center gap-3">
          <span className="text-slate-700">Selected: <strong>{selectedChannel?.channel_name || selectedChannelId}</strong> · {selected.length} dates · {selectedCount.toLocaleString()} messages</span>
          <button type="button" onClick={() => void getPrompt()} disabled={promptLoading || selectedCount === 0 || selected.length > 90} className="rounded-md bg-indigo-600 px-4 py-2 font-medium text-white hover:bg-indigo-700 disabled:opacity-50">
            {promptLoading ? "Getting prompt…" : "Get prompt"}
          </button>
          <button type="button" onClick={() => { setSelected([]); setPromptData(null); }} className="rounded-md border border-slate-300 bg-white px-3 py-2 text-slate-700 hover:bg-slate-50">Clear selection</button>
          {promptData ? <button type="button" onClick={() => void copyPrompt()} className="rounded-md border border-emerald-300 bg-emerald-50 px-4 py-2 font-medium text-emerald-800 hover:bg-emerald-100">{copied ? "Copied" : "Copy prompt"}</button> : null}
        </div>
        <div className="flex flex-wrap gap-2" aria-label="Selected dates">
          {selectedDates.map((date) => <span key={date} className="rounded-full border border-indigo-200 bg-white px-2 py-1 text-xs text-indigo-800">{date}</span>)}
        </div>
        {selected.length > 90 ? <p className="text-xs text-amber-800">Select 90 or fewer dates per prompt.</p> : null}
      </div> : <p className="text-sm text-slate-500">Select one or more non-zero date cells in a channel. Selecting a different channel starts a new selection.</p>}

      {promptError ? <div role="alert" className="rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{promptError}</div> : null}
      {promptData ? <div className="space-y-2">
        <p className="text-xs text-slate-600">{promptData.message_count.toLocaleString()} messages across {promptData.observation_dates.length} dates · approximately {promptData.estimated_tokens.toLocaleString()} tokens</p>
        <textarea aria-label="Discord channel messages prompt" readOnly value={promptData.prompt} rows={18} className="w-full rounded border border-slate-300 bg-slate-50 p-3 font-mono text-xs" />
      </div> : null}
    </section>
  );
}
