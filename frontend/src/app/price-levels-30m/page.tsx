"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import Select from "../components/ui/Select";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

interface PriceRange {
  price: number;
  range_low: number;
  range_high: number;
  touches: number;
  distance_pct: number;
  distance_atr: number;
  latest_touch: string | null;
  sources: Array<"30m" | "gamma">;
  gamma_wall: {
    strike: number;
    open_interest: number;
    nearest_expiry: string;
  } | null;
}

interface StockLevels {
  stock_code: string;
  database_code: string;
  latest_close: number;
  reference_price: number;
  price_source: "ib_live" | "ib_delayed" | "30m_close";
  latest_bar_time: string;
  bar_count: number;
  median_bar_range: number;
  atr_daily: number | null;
  atr_period: number;
  implied_volatility: number | null;
  historical_volatility: number | null;
  iv_percentile: number | null;
  iv_rank: number | null;
  iv_history_count: number;
  trailing_pe: number | null;
  forward_pe: number | null;
  iv_source: "ib_live" | "ib_delayed" | "database" | null;
  iv_observation_date: string | null;
  supports: PriceRange[];
  resistances: PriceRange[];
}

interface LevelsResponse {
  observation_date: string | null;
  latest_available_date: string | null;
  recent_trading_dates: string[];
  live_price_check: boolean;
  live_price_missing: string[];
  lookback_days: number;
  atr_range: {
    minimum: number;
    maximum: number;
  };
  count: number;
  stocks: StockLevels[];
  group: PriceLevelGroup | null;
}

interface PriceLevelGroup {
  id: number;
  name: string;
  description: string | null;
  is_default: boolean;
  is_active: boolean;
  stock_codes: string[];
  database_codes: string[];
  stock_count: number;
}

interface AvailableStock {
  stock_code: string;
  database_code: string;
  latest_bar_time: string;
}

const ATR_RANGE_MIN = 0;
const ATR_RANGE_MAX = 5;
const ATR_RANGE_STEP = 0.05;

function price(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(value)) return "n/a";
  const digits = Math.abs(value) < 10 ? 3 : 2;
  return value.toLocaleString(undefined, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function percent(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(value)) return "n/a";
  return `${(value * 100).toFixed(1)}%`;
}

function LevelCell({
  level,
  tone,
  stockCode,
}: {
  level?: PriceRange;
  tone: "support" | "resistance";
  stockCode: string;
}) {
  if (!level) return <span className="text-slate-400">n/a</span>;
  const color = tone === "support" ? "text-emerald-700" : "text-red-700";
  const rangeSide = tone === "support" ? "Buy" : "Sell";
  const optionAction = tone === "support" ? "SELL" : "BUY";
  const midpoint = (level.range_low + level.range_high) / 2;
  const rangeParams = new URLSearchParams({
    stock: stockCode,
    side: rangeSide,
    start: level.range_low.toFixed(2),
    end: level.range_high.toFixed(2),
  });
  const optionParams = new URLSearchParams({
    symbol: stockCode,
    right: "P",
    action: optionAction,
    target: midpoint.toFixed(2),
    auto: "1",
  });
  const source = level.sources.includes("gamma")
    ? (level.sources.includes("30m") ? "30M + Gamma" : "Gamma wall")
    : "30M structure";
  return (
    <div className="min-w-[180px]">
      <div className="flex items-center gap-2">
        <div className={`font-semibold ${color}`}>
          {price(level.range_low)} - {price(level.range_high)}
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <a
            href={`/range-orders?${rangeParams.toString()}`}
            target="_blank"
            rel="noopener noreferrer"
            title={`Open ${rangeSide.toLowerCase()} range order`}
            aria-label={`Open ${rangeSide.toLowerCase()} range order for ${stockCode}`}
            className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-indigo-300 hover:bg-indigo-50 hover:text-indigo-700"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
              <path d="M5 7h14M5 12h14M5 17h14" />
              <path d={tone === "support" ? "m8 10 4-4 4 4" : "m8 14 4 4 4-4"} />
            </svg>
          </a>
          <a
            href={`/option-orders?${optionParams.toString()}`}
            target="_blank"
            rel="noopener noreferrer"
            title={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order and estimate`}
            aria-label={`Open ${optionAction === "SELL" ? "sell" : "buy"} put order for ${stockCode}`}
            className="inline-flex h-7 w-7 items-center justify-center rounded border border-slate-200 bg-white text-slate-600 hover:border-violet-300 hover:bg-violet-50 hover:text-violet-700"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="1.8">
              <rect x="4" y="4" width="16" height="16" rx="3" />
              <path d="M9 16V8h3.5a2.5 2.5 0 0 1 0 5H9" />
            </svg>
          </a>
        </div>
      </div>
      <div className="mt-1 text-xs text-slate-500">
        {level.distance_pct > 0 ? "+" : ""}{level.distance_pct.toFixed(2)}%, {level.distance_atr.toFixed(2)} ATR
        {level.touches > 0 ? `, ${level.touches} touch${level.touches === 1 ? "" : "es"}` : ""}
      </div>
      <div className="mt-1 text-[11px] text-slate-400">Distance from last close</div>
      <div className="mt-1 text-xs font-medium text-indigo-600">{source}</div>
      {level.gamma_wall ? (
        <div className="mt-1 text-xs text-slate-500">
          Wall {price(level.gamma_wall.strike)}, OI {level.gamma_wall.open_interest.toLocaleString()}
        </div>
      ) : null}
    </div>
  );
}

export default function PriceLevels30mPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const initialLoadStarted = useRef(false);
  const [data, setData] = useState<LevelsResponse | null>(null);
  const [activeView, setActiveView] = useState<"levels" | "admin">("levels");
  const [groups, setGroups] = useState<PriceLevelGroup[]>([]);
  const [availableStocks, setAvailableStocks] = useState<AvailableStock[]>([]);
  const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null);
  const [observationDate, setObservationDate] = useState("");
  const [lookbackDays, setLookbackDays] = useState("10");
  const [minimumAtr, setMinimumAtr] = useState(0.33);
  const [maximumAtr, setMaximumAtr] = useState(3);
  const [search, setSearch] = useState("");
  const [editingGroupId, setEditingGroupId] = useState<number | null>(null);
  const [groupName, setGroupName] = useState("");
  const [groupDescription, setGroupDescription] = useState("");
  const [groupIsDefault, setGroupIsDefault] = useState(false);
  const [groupStocksText, setGroupStocksText] = useState("");
  const [loading, setLoading] = useState(false);
  const [groupsLoading, setGroupsLoading] = useState(false);
  const [savingGroup, setSavingGroup] = useState(false);
  const [error, setError] = useState("");
  const [adminMessage, setAdminMessage] = useState("");

  const loadGroups = useCallback(async () => {
    if (!baseUrl) return [];
    setGroupsLoading(true);
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/price-levels-30m/groups`, {
        cache: "no-store",
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      const nextGroups = body.groups || [];
      setGroups(nextGroups);
      return nextGroups as PriceLevelGroup[];
    } finally {
      setGroupsLoading(false);
    }
  }, [baseUrl]);

  const loadAvailableStocks = useCallback(async () => {
    if (!baseUrl) return;
    const response = await authenticatedFetch(`${baseUrl}/api/price-levels-30m/available-stocks`, {
      cache: "no-store",
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
    setAvailableStocks(body.stocks || []);
  }, [baseUrl]);

  const loadLevels = useCallback(async (groupId = selectedGroupId) => {
    if (!baseUrl) return;
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({
        lookback_days: String(Math.max(3, Math.min(30, Number(lookbackDays) || 10))),
        minimum_distance_atr: minimumAtr.toFixed(2),
        maximum_distance_atr: maximumAtr.toFixed(2),
      });
      if (observationDate) params.set("observation_date", observationDate);
      if (groupId) params.set("group_id", String(groupId));
      const response = await authenticatedFetch(`${baseUrl}/api/price-levels-30m?${params}`, {
        cache: "no-store",
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      setData(body);
      setSelectedGroupId(body.group?.id ?? null);
      if (!observationDate && body.observation_date) setObservationDate(body.observation_date);
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setLoading(false);
    }
  }, [baseUrl, lookbackDays, maximumAtr, minimumAtr, observationDate, selectedGroupId]);

  useEffect(() => {
    if (initialLoadStarted.current) return;
    initialLoadStarted.current = true;

    async function loadInitial() {
      try {
        const nextGroups = await loadGroups();
        const defaultGroup = nextGroups.find((group) => group.is_default) || nextGroups[0];
        await loadLevels(defaultGroup?.id ?? null);
        await loadAvailableStocks();
      } catch (exc: any) {
        setError(exc?.message || String(exc));
      }
    }

    void loadInitial();
  }, [loadAvailableStocks, loadGroups, loadLevels]);

  const visibleStocks = useMemo(() => {
    const query = search.trim().toUpperCase();
    return (data?.stocks || []).filter((stock) => !query || stock.stock_code.toUpperCase().includes(query));
  }, [data, search]);

  const selectedGroup = groups.find((group) => group.id === selectedGroupId) || data?.group || null;

  function parseStockCodes(value: string) {
    return value
      .split(/[\s,;]+/)
      .map((item) => item.trim().toUpperCase().replace(/\.US$/, ""))
      .filter(Boolean);
  }

  function resetGroupForm() {
    setEditingGroupId(null);
    setGroupName("");
    setGroupDescription("");
    setGroupIsDefault(false);
    setGroupStocksText("");
  }

  function editGroup(group: PriceLevelGroup) {
    setActiveView("admin");
    setEditingGroupId(group.id);
    setGroupName(group.name);
    setGroupDescription(group.description || "");
    setGroupIsDefault(group.is_default);
    setGroupStocksText(group.stock_codes.join(", "));
    setAdminMessage("");
  }

  async function selectGroup(group: PriceLevelGroup) {
    setSelectedGroupId(group.id);
    setSearch("");
    await loadLevels(group.id);
  }

  async function saveGroup() {
    if (!baseUrl) return;
    setSavingGroup(true);
    setError("");
    setAdminMessage("");
    try {
      const payload = {
        name: groupName,
        description: groupDescription || null,
        is_default: groupIsDefault,
        stock_codes: parseStockCodes(groupStocksText),
      };
      const url = editingGroupId
        ? `${baseUrl}/api/price-levels-30m/groups/${editingGroupId}`
        : `${baseUrl}/api/price-levels-30m/groups`;
      const response = await authenticatedFetch(url, {
        method: editingGroupId ? "PUT" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body?.detail || `HTTP ${response.status}`);
      const nextGroups = await loadGroups();
      const savedGroup = body.group as PriceLevelGroup;
      setSelectedGroupId(savedGroup.id);
      resetGroupForm();
      setAdminMessage(`Saved ${savedGroup.name}`);
      await loadLevels(savedGroup.id);
      if (!nextGroups.length) await loadGroups();
    } catch (exc: any) {
      setError(exc?.message || String(exc));
    } finally {
      setSavingGroup(false);
    }
  }

  async function deleteGroup(group: PriceLevelGroup) {
    if (!baseUrl || !window.confirm(`Delete ${group.name}?`)) return;
    setError("");
    setAdminMessage("");
    const response = await authenticatedFetch(`${baseUrl}/api/price-levels-30m/groups/${group.id}`, {
      method: "DELETE",
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      setError(body?.detail || `HTTP ${response.status}`);
      return;
    }
    const nextGroups = await loadGroups();
    const defaultGroup = nextGroups.find((item) => item.is_default) || nextGroups[0];
    setSelectedGroupId(defaultGroup?.id ?? null);
    setAdminMessage(`Deleted ${group.name}`);
    await loadLevels(defaultGroup?.id ?? null);
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="30-Minute Support & Resistance"
        subtitle="Price ranges calculated from the same 30-minute bars used by the Market Flow prompt."
        actions={<Button onClick={() => loadLevels()} disabled={loading}>{loading ? "Refreshing..." : "Refresh"}</Button>}
      />

      {error ? <Alert variant="danger">Error: {error}</Alert> : null}
      {adminMessage ? <Alert variant="success">{adminMessage}</Alert> : null}
      {data?.live_price_check && data.live_price_missing?.length ? (
        <Alert variant="warning">
          IB did not return a current price for {data.live_price_missing.length} symbol
          {data.live_price_missing.length === 1 ? "" : "s"}; the page used the latest 30-minute close and stored
          volatility where available.
        </Alert>
      ) : null}

      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          variant={activeView === "levels" ? "primary" : "secondary"}
          onClick={() => setActiveView("levels")}
        >
          Levels
        </Button>
        <Button
          type="button"
          variant={activeView === "admin" ? "primary" : "secondary"}
          onClick={() => setActiveView("admin")}
        >
          Admin
        </Button>
      </div>

      {activeView === "levels" ? (
        <>
      <Card>
        <CardHeader>
          <CardTitle>Groups</CardTitle>
          <p className="mt-1 text-sm text-slate-600">
            {selectedGroup
              ? `${selectedGroup.name} limits this scan to ${selectedGroup.stock_count} stocks.`
              : "No group is selected, so the scan uses every stock with 30-minute data."}
          </p>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-2">
            {groups.map((group) => (
              <button
                key={group.id}
                type="button"
                onClick={() => void selectGroup(group)}
                className={[
                  "rounded-md border px-3 py-2 text-left text-sm transition-colors",
                  selectedGroupId === group.id
                    ? "border-indigo-500 bg-indigo-50 text-indigo-800"
                    : "border-slate-200 bg-white text-slate-700 hover:border-indigo-300 hover:bg-slate-50",
                ].join(" ")}
              >
                <span className="font-semibold">{group.name}</span>
                <span className="ml-2 text-xs text-slate-500">{group.stock_count} stocks</span>
                {group.is_default ? <span className="ml-2 text-xs font-medium text-emerald-700">Default</span> : null}
              </button>
            ))}
            {!groups.length ? (
              <div className="text-sm text-slate-500">
                {groupsLoading ? "Loading groups..." : "No groups yet. Use Admin to create the first stock bucket."}
              </div>
            ) : null}
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Observation Date</span>
              <Input type="date" value={observationDate} onChange={(event) => setObservationDate(event.target.value)} />
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Lookback</span>
              <Select value={lookbackDays} onChange={(event) => setLookbackDays(event.target.value)}>
                <option value="5">5 days</option>
                <option value="10">10 days</option>
                <option value="15">15 days</option>
                <option value="20">20 days</option>
                <option value="30">30 days</option>
              </Select>
            </label>
            <label className="text-sm">
              <span className="mb-1 block text-slate-600">Quick Filter</span>
              <Input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Filter loaded stocks..."
              />
              <span className="mt-1 block text-xs text-slate-500">
                Refresh calculates the selected group before this local filter is applied.
              </span>
            </label>
            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3 xl:col-span-1">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-sm font-medium text-slate-700">ATR Distance Range</div>
                  <div className="mt-0.5 text-xs text-slate-500">Applied when Refresh is clicked</div>
                </div>
                <div className="whitespace-nowrap rounded-full bg-indigo-100 px-2.5 py-1 text-xs font-semibold text-indigo-700">
                  {minimumAtr.toFixed(2)} - {maximumAtr.toFixed(2)} ATR
                </div>
              </div>
              <div className="mt-3 grid grid-cols-2 gap-4">
                <label className="text-xs text-slate-500">
                  <span className="mb-1 flex justify-between">
                    <span>Minimum</span>
                    <span>{minimumAtr.toFixed(2)}</span>
                  </span>
                  <input
                    type="range"
                    min={ATR_RANGE_MIN}
                    max={ATR_RANGE_MAX}
                    step={ATR_RANGE_STEP}
                    value={minimumAtr}
                    onChange={(event) => {
                      const value = Number(event.target.value);
                      setMinimumAtr(Math.min(value, maximumAtr));
                    }}
                    className="h-2 w-full cursor-pointer accent-indigo-600"
                  />
                </label>
                <label className="text-xs text-slate-500">
                  <span className="mb-1 flex justify-between">
                    <span>Maximum</span>
                    <span>{maximumAtr.toFixed(2)}</span>
                  </span>
                  <input
                    type="range"
                    min={ATR_RANGE_MIN}
                    max={ATR_RANGE_MAX}
                    step={ATR_RANGE_STEP}
                    value={maximumAtr}
                    onChange={(event) => {
                      const value = Number(event.target.value);
                      setMaximumAtr(Math.max(value, minimumAtr));
                    }}
                    className="h-2 w-full cursor-pointer accent-indigo-600"
                  />
                </label>
              </div>
            </div>
            <div className="rounded-md border border-slate-200 bg-slate-50 px-4 py-3">
              <div className="text-xs uppercase tracking-wide text-slate-500">Stocks</div>
              <div className="mt-1 text-2xl font-semibold text-slate-900">
                {visibleStocks.length.toLocaleString()}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Price Levels</CardTitle>
          <p className="mt-1 text-sm text-slate-600">
            Live price determines direction: supports must be below it and resistances above it. Last close is the
            baseline for the displayed percentage and ATR distance. The table currently shows the best two levels
            between{" "}
            {(data?.atr_range.minimum ?? minimumAtr).toFixed(2)} and{" "}
            {(data?.atr_range.maximum ?? maximumAtr).toFixed(2)} times the 14-day daily ATR from last close.
            Eligible zones are ranked by 30M-plus-gamma confluence, touch count, gamma open interest, and recency;
            distance is only a final tie-breaker.
          </p>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto rounded-md border border-slate-200">
            <table className="min-w-full text-sm">
              <thead className="sticky top-0 bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-3 py-3">Stock</th>
                  <th className="px-3 py-3 text-right">Reference Price</th>
                  <th className="px-3 py-3 text-right">Daily ATR(14)</th>
                  <th className="px-3 py-3 text-right">IV Percentile / Rank</th>
                  <th className="px-3 py-3 text-right">Volatility</th>
                  <th className="px-3 py-3 text-right">P/E</th>
                  <th className="px-3 py-3">Support Zone 1</th>
                  <th className="px-3 py-3">Support Zone 2</th>
                  <th className="px-3 py-3">Resistance Zone 1</th>
                  <th className="px-3 py-3">Resistance Zone 2</th>
                  <th className="px-3 py-3 text-right">30M Bars</th>
                  <th className="px-3 py-3">Latest Bar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {visibleStocks.map((stock) => (
                  <tr key={stock.database_code} className="align-top hover:bg-slate-50">
                    <td className="px-3 py-3 font-semibold text-slate-900">{stock.stock_code}</td>
                    <td className="px-3 py-3 text-right font-medium">
                      <div>Last Close {price(stock.latest_close)}</div>
                      <div className="mt-1 text-xs font-normal text-slate-500">
                        {stock.price_source === "ib_live"
                          ? `IB Live ${price(stock.reference_price)}`
                          : stock.price_source === "ib_delayed"
                            ? `IB Delayed ${price(stock.reference_price)}`
                            : `30M Close ${price(stock.reference_price)}`}
                      </div>
                    </td>
                    <td className="px-3 py-3 text-right text-slate-600">{price(stock.atr_daily)}</td>
                    <td className="px-3 py-3 text-right">
                      <div>{stock.iv_percentile === null ? "n/a" : `${stock.iv_percentile.toFixed(1)}%`}</div>
                      <div className="mt-1 text-xs font-normal text-slate-500">
                        Rank {stock.iv_rank === null ? "n/a" : `${stock.iv_rank.toFixed(1)}%`}
                        {stock.iv_history_count ? `, ${stock.iv_history_count} days` : ""}
                      </div>
                    </td>
                    <td className="px-3 py-3 text-right">
                      <div>IV {percent(stock.implied_volatility)}</div>
                      <div className="mt-1 text-xs font-normal text-slate-500">
                        Historical IV {percent(stock.historical_volatility)}
                      </div>
                      <div className="mt-1 text-[11px] font-normal text-slate-400">
                        {stock.iv_observation_date ? `Stored ${stock.iv_observation_date}` : "Stored snapshot"}
                      </div>
                    </td>
                    <td className="px-3 py-3 text-right">
                      <div>Trailing {price(stock.trailing_pe)}</div>
                      <div className="mt-1 text-xs font-normal text-slate-500">
                        Forward {price(stock.forward_pe)}
                      </div>
                    </td>
                    <td className="px-3 py-3"><LevelCell level={stock.supports[0]} tone="support" stockCode={stock.stock_code} /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.supports[1]} tone="support" stockCode={stock.stock_code} /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.resistances[0]} tone="resistance" stockCode={stock.stock_code} /></td>
                    <td className="px-3 py-3"><LevelCell level={stock.resistances[1]} tone="resistance" stockCode={stock.stock_code} /></td>
                    <td className="px-3 py-3 text-right">{stock.bar_count}</td>
                    <td className="whitespace-nowrap px-3 py-3 text-xs text-slate-500">
                      {new Date(stock.latest_bar_time).toLocaleString()}
                    </td>
                  </tr>
                ))}
                {!visibleStocks.length ? (
                  <tr>
                    <td className="px-3 py-8 text-center text-slate-500" colSpan={12}>
                      {loading ? "Loading 30-minute levels..." : "No 30-minute price data found."}
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
        </>
      ) : (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_420px]">
          <Card>
            <CardHeader>
              <CardTitle>Stock Groups</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto rounded-md border border-slate-200">
                <table className="min-w-full text-sm">
                  <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
                    <tr>
                      <th className="px-3 py-3">Group</th>
                      <th className="px-3 py-3">Description</th>
                      <th className="px-3 py-3 text-right">Stocks</th>
                      <th className="px-3 py-3 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {groups.map((group) => (
                      <tr key={group.id} className="align-top">
                        <td className="px-3 py-3">
                          <div className="font-semibold text-slate-900">{group.name}</div>
                          {group.is_default ? <div className="mt-1 text-xs font-medium text-emerald-700">Default group</div> : null}
                          <div className="mt-2 max-w-md text-xs text-slate-500">{group.stock_codes.join(", ") || "No stocks"}</div>
                        </td>
                        <td className="px-3 py-3 text-slate-600">{group.description || "n/a"}</td>
                        <td className="px-3 py-3 text-right">{group.stock_count}</td>
                        <td className="px-3 py-3">
                          <div className="flex justify-end gap-2">
                            <Button type="button" size="sm" variant="secondary" onClick={() => editGroup(group)}>
                              Edit
                            </Button>
                            <Button type="button" size="sm" variant="danger" onClick={() => void deleteGroup(group)}>
                              Delete
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))}
                    {!groups.length ? (
                      <tr>
                        <td className="px-3 py-8 text-center text-slate-500" colSpan={4}>
                          {groupsLoading ? "Loading groups..." : "No groups created yet."}
                        </td>
                      </tr>
                    ) : null}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>{editingGroupId ? "Edit Group" : "Create Group"}</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <label className="block text-sm">
                  <span className="mb-1 block text-slate-600">Name</span>
                  <Input value={groupName} onChange={(event) => setGroupName(event.target.value)} placeholder="Core indexes" />
                </label>
                <label className="block text-sm">
                  <span className="mb-1 block text-slate-600">Description</span>
                  <Input
                    value={groupDescription}
                    onChange={(event) => setGroupDescription(event.target.value)}
                    placeholder="High-priority tickers for the 30M scan"
                  />
                </label>
                <label className="flex items-center gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    checked={groupIsDefault}
                    onChange={(event) => setGroupIsDefault(event.target.checked)}
                    className="h-4 w-4 rounded border-slate-300 accent-indigo-600"
                  />
                  Default group
                </label>
                <label className="block text-sm">
                  <span className="mb-1 block text-slate-600">Stocks</span>
                  <textarea
                    value={groupStocksText}
                    onChange={(event) => setGroupStocksText(event.target.value)}
                    placeholder="SPY, QQQ, IWM, AAPL"
                    rows={7}
                    className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                  <span className="mt-1 block text-xs text-slate-500">
                    Separate tickers with commas, spaces, or new lines. .US is optional.
                  </span>
                </label>
                <div className="flex flex-wrap gap-2">
                  <Button type="button" onClick={() => void saveGroup()} disabled={savingGroup || !groupName.trim()}>
                    {savingGroup ? "Saving..." : "Save Group"}
                  </Button>
                  <Button type="button" variant="secondary" onClick={resetGroupForm}>
                    New
                  </Button>
                </div>
                <div className="rounded-md border border-slate-200 bg-slate-50 p-3">
                  <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">Available 30M Stocks</div>
                  <div className="mt-2 flex max-h-44 flex-wrap gap-1 overflow-y-auto">
                    {availableStocks.map((stock) => (
                      <button
                        key={stock.database_code}
                        type="button"
                        onClick={() => {
                          const existing = new Set(parseStockCodes(groupStocksText));
                          existing.add(stock.stock_code);
                          setGroupStocksText(Array.from(existing).sort().join(", "));
                        }}
                        className="rounded border border-slate-200 bg-white px-2 py-1 text-xs text-slate-700 hover:border-indigo-300 hover:text-indigo-700"
                      >
                        {stock.stock_code}
                      </button>
                    ))}
                    {!availableStocks.length ? <span className="text-xs text-slate-500">No available stock list loaded.</span> : null}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
