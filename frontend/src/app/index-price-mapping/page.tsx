"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import PageHeader from "../components/PageHeader";
import Button from "../components/ui/Button";
import { Card, CardContent, CardHeader, CardTitle } from "../components/ui/Card";
import Input from "../components/ui/Input";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type MappingRow = Record<string, unknown>;
type SortDirection = "asc" | "desc";
type PriceRange = [number, number];

interface MappingResponse {
  rows: MappingRow[];
  columns: string[];
  row_count: number;
  loaded_at: string;
  cached: boolean;
  cache_ttl_seconds: number;
  spx_current_price: number | null;
  spx_price_source: string | null;
}

const PAGE_SIZES = [25, 50, 100, 500];
const DEFAULT_SPX_RANGE_PERCENT = 2;

function humanize(value: string) {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function isDateColumn(column: string) {
  return /(date|time|interval)/i.test(column);
}

function isPercentColumn(column: string) {
  return /(percent|percentage|change|return|ratio|weight)/i.test(column);
}

function normalizeColumnName(column: string) {
  return column.replace(/[^a-z0-9]/gi, "").toLocaleLowerCase();
}

function findSpxPriceColumn(columns: string[]) {
  const scoredColumns = columns
    .map((column) => {
      const normalized = normalizeColumnName(column);
      let score = 0;
      if (normalized === "spxprice") score += 100;
      if (normalized.includes("spx")) score += 40;
      if (normalized.includes("index")) score += 15;
      if (normalized.includes("price")) score += 25;
      if (normalized.includes("change") || normalized.includes("percent")) score -= 50;
      return { column, score };
    })
    .sort((left, right) => right.score - left.score);

  return scoredColumns[0]?.score >= 40 ? scoredColumns[0].column : "";
}

function formatSpxPrice(value: number) {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: Number.isInteger(value) ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(value);
}

function toComparable(value: unknown) {
  if (value === null || value === undefined) return "";
  if (typeof value === "number") return value;
  const numeric = Number(value);
  if (String(value).trim() !== "" && Number.isFinite(numeric)) return numeric;
  const date = Date.parse(String(value));
  if (Number.isFinite(date) && /\d{4}-\d{2}-\d{2}/.test(String(value))) return date;
  return String(value).toLocaleLowerCase();
}

function formatValue(column: string, value: unknown) {
  if (value === null || value === undefined || value === "") return "-";

  if (isDateColumn(column)) {
    const parsed = new Date(String(value));
    if (!Number.isNaN(parsed.getTime())) {
      const hasTime = /time|interval/i.test(column) || /T\d{2}:\d{2}/.test(String(value));
      return new Intl.DateTimeFormat("en-US", {
        month: "short",
        day: "2-digit",
        year: "numeric",
        ...(hasTime ? { hour: "2-digit", minute: "2-digit" } : {}),
      }).format(parsed);
    }
  }

  const numeric = typeof value === "number" ? value : Number(value);
  if (Number.isFinite(numeric) && String(value).trim() !== "") {
    const formatted = new Intl.NumberFormat("en-US", {
      maximumFractionDigits: Math.abs(numeric) < 10 ? 4 : 2,
    }).format(numeric);
    return isPercentColumn(column) ? `${formatted}%` : formatted;
  }

  return String(value);
}

function csvCell(value: unknown) {
  if (value === null || value === undefined) return "";
  return `"${String(value).replace(/"/g, '""')}"`;
}

export default function IndexPriceMappingPage() {
  const [data, setData] = useState<MappingResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [sortColumn, setSortColumn] = useState("");
  const [sortDirection, setSortDirection] = useState<SortDirection>("asc");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [spxRange, setSpxRange] = useState<PriceRange | null>(null);

  const loadData = useCallback(async (forceRefresh = false) => {
    setLoading(true);
    setError("");
    try {
      const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
      const suffix = forceRefresh ? "?refresh=true" : "";
      const response = await authenticatedFetch(
        `${backendUrl}/api/index-stock-price-mapping${suffix}`,
      );
      if (!response.ok) {
        const body = await response.json().catch(() => null);
        throw new Error(body?.detail || `Request failed with HTTP ${response.status}`);
      }
      setData((await response.json()) as MappingResponse);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Unable to load price mapping");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadData();
  }, [loadData]);

  useEffect(() => {
    setPage(1);
  }, [query, pageSize, spxRange]);

  const columns = data?.columns ?? [];
  const spxColumn = useMemo(() => findSpxPriceColumn(columns), [columns]);
  const spxRangeDetails = useMemo(() => {
    if (!spxColumn) return null;

    const prices = (data?.rows ?? [])
      .map((row) => Number(row[spxColumn]))
      .filter(Number.isFinite);
    const currentPrice = Number(data?.spx_current_price);
    if (!prices.length || !Number.isFinite(currentPrice) || currentPrice <= 0) return null;

    const minimum = Math.floor(Math.min(...prices));
    const maximum = Math.ceil(Math.max(...prices));
    const step = maximum - minimum <= 20 ? 0.01 : 1;
    return { minimum, maximum, currentPrice, step };
  }, [data?.rows, data?.spx_current_price, spxColumn]);

  useEffect(() => {
    if (!spxRangeDetails) {
      setSpxRange(null);
      return;
    }

    const offset = spxRangeDetails.currentPrice * (DEFAULT_SPX_RANGE_PERCENT / 100);
    setSpxRange([
      Math.max(spxRangeDetails.minimum, Math.floor(spxRangeDetails.currentPrice - offset)),
      Math.min(spxRangeDetails.maximum, Math.ceil(spxRangeDetails.currentPrice + offset)),
    ]);
  }, [data?.loaded_at, spxRangeDetails]);

  const filteredRows = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase();
    const rows = (data?.rows ?? []).filter((row) => {
      const matchesQuery = normalizedQuery
        ? columns.some((column) =>
            String(row[column] ?? "").toLocaleLowerCase().includes(normalizedQuery),
          )
        : true;
      const spxPrice = Number(row[spxColumn]);
      const matchesSpxRange =
        !spxRange ||
        !spxColumn ||
        (Number.isFinite(spxPrice) && spxPrice >= spxRange[0] && spxPrice <= spxRange[1]);
      return matchesQuery && matchesSpxRange;
    });

    if (!sortColumn) return rows;

    return rows.sort((left, right) => {
      const a = toComparable(left[sortColumn]);
      const b = toComparable(right[sortColumn]);
      const result = a < b ? -1 : a > b ? 1 : 0;
      return sortDirection === "asc" ? result : -result;
    });
  }, [columns, data?.rows, query, sortColumn, sortDirection, spxColumn, spxRange]);

  const pageCount = Math.max(1, Math.ceil(filteredRows.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const pageRows = filteredRows.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const handleSort = (column: string) => {
    if (sortColumn === column) {
      setSortDirection((direction) => (direction === "asc" ? "desc" : "asc"));
    } else {
      setSortColumn(column);
      setSortDirection("asc");
    }
    setPage(1);
  };

  const exportCsv = () => {
    const content = [
      columns.map(csvCell).join(","),
      ...filteredRows.map((row) => columns.map((column) => csvCell(row[column])).join(",")),
    ].join("\r\n");
    const blob = new Blob([content], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `index-price-mapping-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const updatedAt = data?.loaded_at
    ? new Intl.DateTimeFormat("en-US", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(data.loaded_at))
    : "Not loaded";

  return (
    <div className="space-y-6">
      <PageHeader
        title="Index Stock Price Mapping"
        subtitle="Compare index and constituent price movement across synchronized market intervals."
        actions={
          <>
            <Button
              variant="secondary"
              onClick={exportCsv}
              disabled={!filteredRows.length}
            >
              Export CSV
            </Button>
            <Button onClick={() => void loadData(true)} disabled={loading}>
              {loading ? "Refreshing..." : "Refresh data"}
            </Button>
          </>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="overflow-hidden">
          <CardContent className="p-5">
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              Mapping rows
            </div>
            <div className="mt-2 text-3xl font-semibold tracking-tight text-slate-900">
              {(data?.row_count ?? 0).toLocaleString()}
            </div>
            <div className="mt-1 text-xs text-slate-500">Across {columns.length} data fields</div>
          </CardContent>
        </Card>
        <Card className="overflow-hidden">
          <CardContent className="p-5">
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              Visible results
            </div>
            <div className="mt-2 text-3xl font-semibold tracking-tight text-indigo-700">
              {filteredRows.length.toLocaleString()}
            </div>
            <div className="mt-1 text-xs text-slate-500">
              {query ? "Filtered across every column" : "No search filter applied"}
            </div>
          </CardContent>
        </Card>
        <Card className="overflow-hidden">
          <CardContent className="p-5">
            <div className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              Data snapshot
            </div>
            <div className="mt-2 text-sm font-semibold text-slate-900">{updatedAt}</div>
            <div className="mt-2 inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700">
              {data?.cached ? "Served from 90s cache" : "Fresh database result"}
            </div>
          </CardContent>
        </Card>
      </div>

      {error ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          <span className="font-semibold">Could not load mapping data.</span> {error}
        </div>
      ) : null}

      {spxRangeDetails && spxRange ? (
        <Card>
          <CardHeader className="pb-2">
            <div className="flex items-start justify-between gap-4">
              <div>
                <CardTitle>SPX Range Filter</CardTitle>
                <p className="mt-1 text-sm text-slate-500">
                  Select the SPX price range included in the mapping table.
                </p>
              </div>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  const offset =
                    spxRangeDetails.currentPrice * (DEFAULT_SPX_RANGE_PERCENT / 100);
                  setSpxRange([
                    Math.max(
                      spxRangeDetails.minimum,
                      Math.floor(spxRangeDetails.currentPrice - offset),
                    ),
                    Math.min(
                      spxRangeDetails.maximum,
                      Math.ceil(spxRangeDetails.currentPrice + offset),
                    ),
                  ]);
                }}
              >
                Reset to +/-2%
              </Button>
            </div>
          </CardHeader>
          <CardContent className="pt-4">
            <div className="relative mb-1 h-12">
              <div className="absolute left-0 right-0 top-5 h-1 rounded-full bg-slate-200" />
              <div
                className="absolute top-5 h-1 rounded-full bg-indigo-500"
                style={{
                  left: `${
                    ((spxRange[0] - spxRangeDetails.minimum) /
                      Math.max(1, spxRangeDetails.maximum - spxRangeDetails.minimum)) *
                    100
                  }%`,
                  right: `${
                    100 -
                    ((spxRange[1] - spxRangeDetails.minimum) /
                      Math.max(1, spxRangeDetails.maximum - spxRangeDetails.minimum)) *
                      100
                  }%`,
                }}
              />
              <span
                className="absolute top-0 -translate-x-1/2 text-xs font-semibold tabular-nums text-indigo-600"
                style={{
                  left: `${
                    ((spxRange[0] - spxRangeDetails.minimum) /
                      Math.max(1, spxRangeDetails.maximum - spxRangeDetails.minimum)) *
                    100
                  }%`,
                }}
              >
                {formatSpxPrice(spxRange[0])}
              </span>
              <span
                className="absolute top-0 -translate-x-1/2 text-xs font-semibold tabular-nums text-indigo-600"
                style={{
                  left: `${
                    ((spxRange[1] - spxRangeDetails.minimum) /
                      Math.max(1, spxRangeDetails.maximum - spxRangeDetails.minimum)) *
                    100
                  }%`,
                }}
              >
                {formatSpxPrice(spxRange[1])}
              </span>
              <input
                type="range"
                aria-label="Minimum SPX price"
                min={spxRangeDetails.minimum}
                max={spxRangeDetails.maximum}
                step={spxRangeDetails.step}
                value={spxRange[0]}
                onChange={(event) =>
                  setSpxRange([
                    Math.min(Number(event.target.value), spxRange[1]),
                    spxRange[1],
                  ])
                }
                className="spx-range-input absolute left-0 top-3 h-5 w-full appearance-none bg-transparent"
              />
              <input
                type="range"
                aria-label="Maximum SPX price"
                min={spxRangeDetails.minimum}
                max={spxRangeDetails.maximum}
                step={spxRangeDetails.step}
                value={spxRange[1]}
                onChange={(event) =>
                  setSpxRange([
                    spxRange[0],
                    Math.max(Number(event.target.value), spxRange[0]),
                  ])
                }
                className="spx-range-input absolute left-0 top-3 h-5 w-full appearance-none bg-transparent"
              />
            </div>
            <div className="flex justify-between text-xs tabular-nums text-slate-500">
              <span>{formatSpxPrice(spxRangeDetails.minimum)}</span>
              <span>{formatSpxPrice(spxRangeDetails.maximum)}</span>
            </div>
            <div className="mt-4 rounded-lg bg-indigo-50 px-4 py-3 text-sm text-indigo-800">
              Showing {filteredRows.length.toLocaleString()} rows | SPX range:{" "}
              <span className="font-semibold">
                {formatSpxPrice(spxRange[0])} - {formatSpxPrice(spxRange[1])}
              </span>{" "}
              | Current SPX: {formatSpxPrice(spxRangeDetails.currentPrice)}
              {data?.spx_price_source ? ` (${data.spx_price_source.replace(/_/g, " ")})` : ""}
            </div>
          </CardContent>
          <style jsx>{`
            .spx-range-input {
              pointer-events: none;
            }
            .spx-range-input::-webkit-slider-runnable-track {
              background: transparent;
              border: 0;
            }
            .spx-range-input::-webkit-slider-thumb {
              width: 16px;
              height: 16px;
              margin-top: 2px;
              appearance: none;
              border: 2px solid white;
              border-radius: 9999px;
              background: #6366f1;
              box-shadow: 0 1px 3px rgb(15 23 42 / 0.3);
              cursor: grab;
              pointer-events: auto;
            }
            .spx-range-input::-moz-range-track {
              background: transparent;
              border: 0;
            }
            .spx-range-input::-moz-range-thumb {
              width: 16px;
              height: 16px;
              border: 2px solid white;
              border-radius: 9999px;
              background: #6366f1;
              box-shadow: 0 1px 3px rgb(15 23 42 / 0.3);
              cursor: grab;
              pointer-events: auto;
            }
          `}</style>
        </Card>
      ) : null}

      {!loading && data && !spxRangeDetails ? (
        <div className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Current SPX price is unavailable, so the SPX range filter has not been applied.
        </div>
      ) : null}

      <Card className="overflow-hidden">
        <CardHeader className="border-b border-slate-200 bg-slate-50/70">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <CardTitle className="text-base">Price mapping matrix</CardTitle>
              <p className="mt-1 text-sm text-slate-500">
                Click a column heading to sort. Search checks every field.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
              <div className="relative sm:w-80">
                <svg
                  aria-hidden="true"
                  viewBox="0 0 20 20"
                  fill="none"
                  className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                >
                  <path d="m14.5 14.5 3 3m-1.75-8A6.25 6.25 0 1 1 3.25 9.5a6.25 6.25 0 0 1 12.5 0Z" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                <Input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search symbols, intervals, values..."
                  className="pl-9"
                />
              </div>
              <label className="flex items-center gap-2 text-sm text-slate-600">
                Rows
                <select
                  value={pageSize}
                  onChange={(event) => setPageSize(Number(event.target.value))}
                  className="h-10 rounded-md border border-slate-200 bg-white px-3 text-sm text-slate-900 shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  {PAGE_SIZES.map((size) => (
                    <option key={size} value={size}>{size}</option>
                  ))}
                </select>
              </label>
            </div>
          </div>
        </CardHeader>

        <div className="relative">
          {loading ? (
            <div className="absolute inset-0 z-30 flex min-h-64 items-center justify-center bg-white/75 backdrop-blur-[1px]">
              <div className="flex items-center gap-3 text-sm font-medium text-slate-600">
                <span className="h-5 w-5 animate-spin rounded-full border-2 border-indigo-200 border-t-indigo-600" />
                Loading mapping data...
              </div>
            </div>
          ) : null}

          <div className="max-h-[65vh] overflow-auto">
            <table className="min-w-full border-separate border-spacing-0 text-sm">
              <thead className="sticky top-0 z-20">
                <tr>
                  {columns.map((column, index) => (
                    <th
                      key={column}
                      className={[
                        "border-b border-r border-slate-200 bg-slate-100 px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wider text-slate-600",
                        index === 0 ? "sticky left-0 z-30 min-w-44" : "min-w-32",
                      ].join(" ")}
                    >
                      <button
                        type="button"
                        onClick={() => handleSort(column)}
                        className="flex w-full items-center justify-between gap-3 whitespace-nowrap hover:text-indigo-700"
                      >
                        <span>{humanize(column)}</span>
                        <span className={sortColumn === column ? "text-indigo-600" : "text-slate-300"}>
                          {sortColumn === column && sortDirection === "desc" ? "v" : "^"}
                        </span>
                      </button>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {!loading && pageRows.length === 0 ? (
                  <tr>
                    <td colSpan={Math.max(columns.length, 1)} className="px-6 py-16 text-center">
                      <div className="text-sm font-medium text-slate-700">No mapping rows found</div>
                      <div className="mt-1 text-sm text-slate-500">
                        {query ? "Try a broader search term." : "The report returned no data."}
                      </div>
                    </td>
                  </tr>
                ) : (
                  pageRows.map((row, rowIndex) => (
                    <tr key={`${currentPage}-${rowIndex}`} className="group">
                      {columns.map((column, columnIndex) => {
                        const value = row[column];
                        const numeric = Number(value);
                        const color =
                          isPercentColumn(column) && Number.isFinite(numeric)
                            ? numeric > 0
                              ? "text-emerald-700"
                              : numeric < 0
                                ? "text-red-700"
                                : "text-slate-700"
                            : "text-slate-700";
                        return (
                          <td
                            key={column}
                            className={[
                              "border-b border-r border-slate-100 px-4 py-3 tabular-nums whitespace-nowrap group-hover:bg-indigo-50/50",
                              rowIndex % 2 === 1 ? "bg-slate-50/60" : "bg-white",
                              columnIndex === 0 ? "sticky left-0 z-10 font-medium text-slate-900" : color,
                            ].join(" ")}
                            title={String(value ?? "")}
                          >
                            {formatValue(column, value)}
                          </td>
                        );
                      })}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="flex flex-col gap-3 border-t border-slate-200 bg-white px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-slate-500">
            {filteredRows.length
              ? `Showing ${(currentPage - 1) * pageSize + 1}-${Math.min(currentPage * pageSize, filteredRows.length)} of ${filteredRows.length.toLocaleString()}`
              : "Showing 0 results"}
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setPage((value) => Math.max(1, value - 1))}
              disabled={currentPage <= 1}
            >
              Previous
            </Button>
            <span className="min-w-24 text-center text-sm font-medium text-slate-700">
              Page {currentPage} of {pageCount}
            </span>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setPage((value) => Math.min(pageCount, value + 1))}
              disabled={currentPage >= pageCount}
            >
              Next
            </Button>
          </div>
        </div>
      </Card>
    </div>
  );
}
