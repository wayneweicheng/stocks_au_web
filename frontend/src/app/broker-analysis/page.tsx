"use client";

import { useEffect, useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type TabKey = "buySuggestion" | "buySellPerc";
type BrokerCode = { BrokerCode?: string; BrokerName?: string };
type Row = Record<string, unknown> & {
  ASXCode?: string;
  DateStart?: string;
  DateEnd?: string;
  NetValue?: number | string;
  NetValuevsMC?: number | string;
  SalePerc?: number | string;
};

const suggestionSortOptions = [
  ["NetValuevsMC", "Net value vs market cap"],
  ["NetVolumevsTradeVolume", "Net volume vs traded volume"],
  ["MarketCap", "Market cap"],
  ["NetValue", "Net value"],
  ["ASXCode", "ASX code"],
];

const percSortOptions = [
  ["Buy Perc Desc", "Buy percentage"],
  ["Sell Perc Desc", "Sell percentage"],
];

const suggestionColumns = [
  "ASXCode",
  "NetValuevsMC",
  "NetValue",
  "NetVolumevsTradeVolume",
  "NetVolume",
  "MC",
  "CashPosition",
  "MedianTradeValue",
  "TopBuyBroker",
  "TopSellBroker",
  "TrendMovingAverage60d",
  "TrendMovingAverage200d",
  "Nature",
  "Poster",
  "DateStart",
  "DateEnd",
];

const percColumns = [
  "DateStart",
  "DateEnd",
  "ASXCode",
  "BrokerCode",
  "NetValue",
  "NetVolume",
  "SalePerc",
  "MedianTradeValue",
  "CleansedMarketCap",
  "MedianPriceChangePerc",
];

const labels: Record<string, string> = {
  ASXCode: "Code",
  NetValuevsMC: "Net value / MC",
  NetVolumevsTradeVolume: "Net volume / traded",
  MedianTradeValue: "Median trade",
  TopBuyBroker: "Top buy brokers",
  TopSellBroker: "Top sell brokers",
  TrendMovingAverage60d: "60d trend",
  TrendMovingAverage200d: "200d trend",
  DateStart: "Start",
  DateEnd: "End",
  SalePerc: "Sale %",
  CleansedMarketCap: "Market cap",
  MedianPriceChangePerc: "Median price %",
};

function inputDate(date: Date) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 10);
}

function previousWeekday(value: string) {
  const date = new Date(`${value}T12:00:00`);
  date.setDate(date.getDate() - 1);
  while (date.getDay() === 0 || date.getDay() === 6) date.setDate(date.getDate() - 1);
  return inputDate(date);
}

function weekdaySpan(startDate: string, endDate: string) {
  if (!startDate || !endDate) return null;
  const start = new Date(`${startDate}T12:00:00`);
  const end = new Date(`${endDate}T12:00:00`);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) return null;

  let days = 0;
  const current = new Date(end);
  while (current > start) {
    current.setDate(current.getDate() - 1);
    if (current.getDay() !== 0 && current.getDay() !== 6) days += 1;
  }
  return days;
}

function numeric(value: unknown) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string") return null;
  const parsed = Number(value.replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : null;
}

function formatDate(value: unknown) {
  if (!value) return "";
  const text = String(value).slice(0, 10);
  const parsed = new Date(`${text}T12:00:00`);
  if (Number.isNaN(parsed.getTime())) return String(value);
  return parsed.toLocaleDateString("en-AU", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function formatCell(column: string, value: unknown) {
  if (value == null) return "";
  if (column === "DateStart" || column === "DateEnd") return formatDate(value);
  const parsed = numeric(value);
  if (parsed === null) return String(value);
  const lower = column.toLowerCase();
  const maximumFractionDigits =
    lower.includes("perc") ||
    column === "NetValuevsMC" ||
    column === "NetVolumevsTradeVolume"
      ? 4
      : 0;
  return parsed.toLocaleString("en-AU", { maximumFractionDigits });
}

function columnsFor(rows: Row[], preferred: string[]) {
  if (!rows[0]) return preferred;
  const available = new Set(Object.keys(rows[0]));
  return [
    ...preferred.filter((column) => available.has(column)),
    ...Object.keys(rows[0]).filter((column) => !preferred.includes(column)),
  ];
}

function asxSymbol(value: unknown) {
  return String(value ?? "")
    .replace(/\.AX$/i, "")
    .replace(/\.AU$/i, "")
    .trim()
    .toUpperCase();
}

function DataTable({
  rows,
  columns,
  loading,
  emptyText,
}: {
  rows: Row[];
  columns: string[];
  loading: boolean;
  emptyText: string;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full border-separate border-spacing-0 text-sm">
        <thead className="bg-slate-100 text-xs text-slate-600">
          <tr>
            {columns.map((column) => (
              <th
                key={column}
                className="border-b border-slate-200 bg-slate-100 px-3 py-3 text-left font-semibold"
              >
                {labels[column] || column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {!loading && rows.length === 0 ? (
            <tr>
              <td className="px-4 py-10 text-center text-slate-500" colSpan={columns.length}>
                {emptyText}
              </td>
            </tr>
          ) : null}
          {rows.map((row, index) => (
            <tr
              key={`${row.ASXCode || "row"}-${index}`}
              className="border-b border-slate-100 transition hover:bg-emerald-50/70"
            >
              {columns.map((column) => {
                const value = row[column];
                const isCode = column === "ASXCode" && value;
                const amount = numeric(value);
                const color =
                  amount !== null && amount < 0
                    ? "text-red-700"
                    : amount !== null && amount > 0 && ["NetValue", "NetVolume", "SalePerc"].includes(column)
                      ? "text-emerald-700"
                      : "text-slate-700";

                return (
                  <td
                    key={column}
                    className={`border-b border-slate-100 px-3 py-3 align-top ${column === "ASXCode" ? "font-semibold text-slate-950" : color}`}
                  >
                    {isCode ? (
                      <button
                        type="button"
                        onClick={() => {
                          const symbol = asxSymbol(value);
                          window.open(
                            `/integrated-charts?symbol=${encodeURIComponent(symbol)}&market=ASX`,
                            "_blank",
                          );
                        }}
                        className="text-emerald-700 hover:text-emerald-900 hover:underline"
                      >
                        {String(value)}
                      </button>
                    ) : (
                      formatCell(column, value)
                    )}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function BrokerAnalysisPage() {
  const today = useMemo(() => new Date(), []);
  const defaultEndDate = useMemo(() => inputDate(today), [today]);
  const defaultStartDate = useMemo(() => {
    const date = new Date(today);
    date.setDate(date.getDate() - 7);
    return inputDate(date);
  }, [today]);

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [activeTab, setActiveTab] = useState<TabKey>("buySuggestion");
  const [brokerCodes, setBrokerCodes] = useState<BrokerCode[]>([]);
  const [brokerCode, setBrokerCode] = useState("BelPot");
  const [error, setError] = useState("");

  const [suggestionSort, setSuggestionSort] = useState("NetValuevsMC");
  const [suggestionStartDate, setSuggestionStartDate] = useState(defaultStartDate);
  const [suggestionEndDate, setSuggestionEndDate] = useState(defaultEndDate);
  const [suggestionRows, setSuggestionRows] = useState<Row[]>([]);
  const [suggestionLoading, setSuggestionLoading] = useState(false);

  const [percSort, setPercSort] = useState("Buy Perc Desc");
  const [percStartDate, setPercStartDate] = useState("");
  const [percEndDate, setPercEndDate] = useState("");
  const [percPreviousDays, setPercPreviousDays] = useState(0);
  const [percRows, setPercRows] = useState<Row[]>([]);
  const [percLoading, setPercLoading] = useState(false);

  useEffect(() => {
    if (!baseUrl) return;
    authenticatedFetch(`${baseUrl}/api/broker-analysis/broker-codes`)
      .then(async (response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      })
      .then((data: BrokerCode[]) => {
        setBrokerCodes(data || []);
        const defaultBroker =
          data?.find((item) => item.BrokerCode?.toLowerCase() === "belpot") ||
          data?.find((item) => item.BrokerCode !== "All") ||
          data?.[0];
        if (defaultBroker?.BrokerCode) setBrokerCode(defaultBroker.BrokerCode);
      })
      .catch((e) => setError(e.message || "Failed to load broker codes"));
  }, [baseUrl]);

  useEffect(() => {
    if (!baseUrl || !brokerCode || !suggestionStartDate || !suggestionEndDate) return;
    setSuggestionLoading(true);
    setError("");
    const params = new URLSearchParams({
      sort_by: suggestionSort,
      broker_code: brokerCode,
      start_date: suggestionStartDate,
      end_date: suggestionEndDate,
    });
    authenticatedFetch(`${baseUrl}/api/broker-analysis/analysis?${params}`)
      .then(async (response) => {
        if (!response.ok) throw new Error(await response.text());
        return response.json();
      })
      .then((data: Row[]) => setSuggestionRows(data || []))
      .catch((e) => setError(e.message || "Failed to load broker analysis"))
      .finally(() => setSuggestionLoading(false));
  }, [baseUrl, brokerCode, suggestionSort, suggestionStartDate, suggestionEndDate]);

  useEffect(() => {
    if (!baseUrl || !brokerCode) return;
    if (percStartDate && !percEndDate) return;

    const controller = new AbortController();
    const effectivePreviousDays = weekdaySpan(percStartDate, percEndDate) ?? percPreviousDays;

    setPercLoading(true);
    setError("");
    const params = new URLSearchParams({
      sort_by: percSort,
      broker_code: brokerCode,
      num_prev_day: String(effectivePreviousDays),
    });
    if (percEndDate) params.set("observation_end_date", percEndDate);
    if (percStartDate && percEndDate) params.set("observation_start_date", percStartDate);
    authenticatedFetch(`${baseUrl}/api/broker-analysis/buy-sell-percentage?${params}`, {
      signal: controller.signal,
    })
      .then(async (response) => {
        if (!response.ok) throw new Error(await response.text());
        return response.json();
      })
      .then((data: Row[]) => {
        setPercRows(data || []);
        setError("");
      })
      .catch((e) => {
        if (e.name !== "AbortError") {
          setError(e.message || "Failed to load broker buy/sell percentage");
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) setPercLoading(false);
      });

    return () => controller.abort();
  }, [baseUrl, brokerCode, percSort, percStartDate, percEndDate, percPreviousDays]);

  const currentRows = activeTab === "buySuggestion" ? suggestionRows : percRows;
  const currentLoading = activeTab === "buySuggestion" ? suggestionLoading : percLoading;
  const suggestionTableColumns = useMemo(
    () => columnsFor(suggestionRows, suggestionColumns),
    [suggestionRows],
  );
  const percTableColumns = useMemo(() => columnsFor(percRows, percColumns), [percRows]);

  const summary = useMemo(() => {
    const totalNetValue = currentRows.reduce((sum, row) => sum + (numeric(row.NetValue) || 0), 0);
    const firstWindow = currentRows.find((row) => row.DateStart || row.DateEnd);
    return {
      rows: currentRows.length,
      topCode: currentRows[0]?.ASXCode || "-",
      totalNetValue,
      window:
        firstWindow?.DateStart && firstWindow?.DateEnd
          ? `${formatDate(firstWindow.DateStart)} to ${formatDate(firstWindow.DateEnd)}`
          : "-",
    };
  }, [currentRows]);

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto max-w-[1500px] px-4 py-6 sm:px-6 lg:px-8">
        <div className="mb-6 flex flex-col gap-4 border-b border-slate-200 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-sm font-medium text-emerald-700">Broker reports</p>
            <h1 className="mt-1 text-3xl font-semibold text-slate-950">Broker Analysis</h1>
            <p className="mt-2 max-w-3xl text-sm text-slate-600">
              Migrated broker reports from the legacy StockInfoReport pages, grouped into tabs.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
            {[
              ["Results", summary.rows],
              ["Top code", summary.topCode],
              ["Net value", formatCell("NetValue", summary.totalNetValue)],
              ["Window", summary.window],
            ].map(([label, value]) => (
              <div key={label} className="rounded-md border border-slate-200 bg-white px-4 py-3 shadow-sm">
                <div className="text-xs font-medium text-slate-500">{label}</div>
                <div className="mt-1 text-lg font-semibold text-slate-950">{value}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="mb-5 flex flex-wrap gap-2">
          {[
            ["buySuggestion", "Broker Buy Suggestion", "BrokerAnalysis.aspx"],
            ["buySellPerc", "Buy/Sell Percentage", "BrokerBuySellPerc.aspx"],
          ].map(([key, title, source]) => (
            <button
              key={key}
              type="button"
              onClick={() => setActiveTab(key as TabKey)}
              className={`rounded-md border px-4 py-2 text-sm font-medium shadow-sm ${
                activeTab === key
                  ? "border-emerald-600 bg-emerald-600 text-white"
                  : "border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
              }`}
            >
              {title}
              <span className={`ml-2 text-xs ${activeTab === key ? "text-emerald-100" : "text-slate-400"}`}>
                {source}
              </span>
            </button>
          ))}
        </div>

        <section className="mb-5 rounded-md border border-slate-200 bg-white p-4 shadow-sm">
          <div className="grid gap-3 md:grid-cols-6">
            <label className="text-sm font-medium text-slate-700 md:col-span-2">
              Broker
              <select
                value={brokerCode}
                onChange={(e) => setBrokerCode(e.target.value)}
                className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
              >
                {brokerCodes.length === 0 ? (
                  <option value={brokerCode}>{brokerCode}</option>
                ) : (
                  brokerCodes.map((broker) => (
                    <option key={broker.BrokerCode || broker.BrokerName} value={broker.BrokerCode || ""}>
                      {broker.BrokerName || broker.BrokerCode || ""}
                    </option>
                  ))
                )}
              </select>
            </label>

            {activeTab === "buySuggestion" ? (
              <>
                <label className="text-sm font-medium text-slate-700">
                  Order by
                  <select
                    value={suggestionSort}
                    onChange={(e) => setSuggestionSort(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  >
                    {suggestionSortOptions.map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="text-sm font-medium text-slate-700">
                  Start date
                  <input
                    type="date"
                    value={suggestionStartDate}
                    max={suggestionEndDate}
                    onChange={(e) => setSuggestionStartDate(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  />
                </label>
                <label className="text-sm font-medium text-slate-700">
                  End date
                  <input
                    type="date"
                    value={suggestionEndDate}
                    min={suggestionStartDate}
                    onChange={(e) => setSuggestionEndDate(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  />
                </label>
              </>
            ) : (
              <>
                <label className="text-sm font-medium text-slate-700">
                  Order by
                  <select
                    value={percSort}
                    onChange={(e) => setPercSort(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  >
                    {percSortOptions.map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="text-sm font-medium text-slate-700">
                  Observation start
                  <input
                    type="date"
                    value={percStartDate}
                    max={percEndDate || undefined}
                    onChange={(e) => setPercStartDate(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  />
                </label>
                <label className="text-sm font-medium text-slate-700">
                  Observation end
                  <input
                    type="date"
                    value={percEndDate}
                    min={percStartDate || undefined}
                    onChange={(e) => setPercEndDate(e.target.value)}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  />
                </label>
                <label className="text-sm font-medium text-slate-700">
                  Previous days
                  <input
                    type="number"
                    min={0}
                    max={260}
                    value={percPreviousDays}
                    onChange={(e) => setPercPreviousDays(Math.max(0, Number(e.target.value) || 0))}
                    className="mt-1 h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                  />
                </label>
                <div className="flex items-end">
                  <button
                    type="button"
                    onClick={() => {
                      const end = percEndDate || defaultEndDate;
                      setPercEndDate(end);
                      setPercStartDate(previousWeekday(end));
                      setPercPreviousDays(1);
                    }}
                    className="h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm font-medium text-slate-700 shadow-sm hover:bg-slate-50"
                  >
                    1D Window
                  </button>
                </div>
              </>
            )}
          </div>
        </section>

        {error ? (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error}
          </div>
        ) : null}

        <section className="overflow-hidden rounded-md border border-slate-200 bg-white shadow-sm">
          <div className="flex min-h-12 items-center justify-between border-b border-slate-200 px-4 py-3">
            <div>
              <h2 className="text-base font-semibold text-slate-950">
                {activeTab === "buySuggestion" ? "Broker buy suggestion" : "Broker buy/sell percentage"}
              </h2>
              <p className="text-xs text-slate-500">
                {activeTab === "buySuggestion"
                  ? "Uses Report.usp_Get_BrokerBuySuggestion"
                  : "Uses Report.usp_GetBrokerBuySellPerc"}
              </p>
            </div>
            {currentLoading ? <div className="text-sm font-medium text-emerald-700">Loading...</div> : null}
          </div>

          {activeTab === "buySuggestion" ? (
            <DataTable
              rows={suggestionRows}
              columns={suggestionTableColumns}
              loading={suggestionLoading}
              emptyText="No broker buy suggestion rows found for this window."
            />
          ) : (
            <DataTable
              rows={percRows}
              columns={percTableColumns}
              loading={percLoading}
              emptyText="No broker buy/sell percentage rows found for this window."
            />
          )}
        </section>
      </div>
    </main>
  );
}
