"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type BrokerCode = { BrokerCode?: string; BrokerName?: string } & Record<string, any>;
type BrokerAnalysis = Record<string, any>;

export default function BrokerAnalysisPage() {
  const router = useRouter();
  const [brokerCodes, setBrokerCodes] = useState<BrokerCode[]>([]);
  const [selectedBroker, setSelectedBroker] = useState<string>("Macquarie Securities");
  const [sortBy, setSortBy] = useState<string>("NetValuevsMC");
  const [numPrevDay, setNumPrevDay] = useState<number>(0);
  const [data, setData] = useState<BrokerAnalysis[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;

  // Fetch broker codes on mount
  useEffect(() => {
    fetch(`${baseUrl}/api/broker-analysis/broker-codes`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then((codes) => {
        setBrokerCodes(codes);
        // Set default to Macquarie Securities if available
        const macquarie = codes.find((c: BrokerCode) =>
          c.BrokerCode === "Macquarie Securities" || c.BrokerName === "Macquarie Securities"
        );
        if (macquarie) {
          setSelectedBroker(macquarie.BrokerCode || "Macquarie Securities");
        } else if (codes.length > 0) {
          setSelectedBroker(codes[0].BrokerCode || "");
        }
      })
      .catch((e) => setError(`Failed to load broker codes: ${e.message}`));
  }, [baseUrl]);

  // Fetch analysis data when filters change
  useEffect(() => {
    if (!selectedBroker) return;

    setLoading(true);
    setError("");

    const params = new URLSearchParams({
      sort_by: sortBy,
      num_prev_day: numPrevDay.toString(),
      broker_code: selectedBroker,
    });

    fetch(`${baseUrl}/api/broker-analysis/analysis?${params}`)
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(setData)
      .catch((e) => setError(`Failed to load analysis: ${e.message}`))
      .finally(() => setLoading(false));
  }, [baseUrl, selectedBroker, sortBy, numPrevDay]);

  const handleRowClick = (row: BrokerAnalysis) => {
    // Navigate to broker-report page with stock code and observation date
    const stockCode = row.ASXCode || row.asxcode || "";
    const dateEnd = row.DateEnd || row.dateend || "";

    if (stockCode && dateEnd) {
      // Format date to yyyy-MM-dd if needed
      let observationDate = dateEnd;
      if (dateEnd instanceof Date) {
        observationDate = dateEnd.toISOString().split('T')[0];
      } else if (typeof dateEnd === 'string') {
        // If it's already a string, try to parse and format it
        const parsed = new Date(dateEnd);
        if (!isNaN(parsed.getTime())) {
          observationDate = parsed.toISOString().split('T')[0];
        }
      }

      router.push(`/broker-report?StockCode=${stockCode}&ObservationDate=${observationDate}`);
    }
  };

  const formatValue = (value: any): string => {
    if (value == null) return "";
    if (typeof value === "number") {
      return value.toLocaleString(undefined, { maximumFractionDigits: 2 });
    }
    return String(value);
  };

  const columns = data.length > 0 ? Object.keys(data[0]) : [];

  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-7xl px-6 py-10">
        <h1 className="text-3xl sm:text-4xl font-semibold mb-6 bg-gradient-to-r from-blue-500 to-indigo-600 bg-clip-text text-transparent">
          Broker Analysis
        </h1>

        {/* Filters */}
        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Order By</label>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
            >
              <option value="NetValuevsMC">Net Value vs MC</option>
              <option value="NetVolumevsTradeVolume">Net Volume vs Trade Volume</option>
              <option value="MarketCap">Market Cap</option>
              <option value="NetValue">Net Value</option>
              <option value="ASXCode">ASX Code</option>
            </select>
          </div>

          <div>
            <label className="block text-sm mb-1 text-slate-600">Broker Code</label>
            <select
              value={selectedBroker}
              onChange={(e) => setSelectedBroker(e.target.value)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
            >
              {brokerCodes.map((broker) => (
                <option key={broker.BrokerCode} value={broker.BrokerCode || ""}>
                  {broker.BrokerName || broker.BrokerCode || ""}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm mb-1 text-slate-600">
              Number of Previous Days from Today
            </label>
            <input
              type="number"
              min="0"
              value={numPrevDay}
              onChange={(e) => setNumPrevDay(parseInt(e.target.value) || 0)}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400/40 focus:border-blue-400/40"
            />
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-300 bg-red-50 text-red-700 px-3 py-2 text-sm">
            Error: {error}
          </div>
        )}

        {/* Data Table */}
        <div className="rounded-lg border border-slate-200 bg-white overflow-x-auto relative">
          {loading && (
            <div className="absolute inset-0 bg-slate-900/30 backdrop-blur-sm flex items-center justify-center z-10">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-300/40 border-t-blue-500" />
            </div>
          )}
          <table className="min-w-full text-sm">
            <thead className="sticky top-0 z-10 bg-slate-50 text-slate-700 text-xs tracking-wide border-b border-slate-200">
              <tr>
                {columns.map((col) => (
                  <th
                    key={col}
                    className="px-3 py-3 text-left font-semibold whitespace-nowrap"
                  >
                    {col}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td className="px-3 py-3 text-center" colSpan={columns.length || 1}>
                    Loading...
                  </td>
                </tr>
              ) : data.length === 0 ? (
                <tr>
                  <td className="px-3 py-3 text-center" colSpan={columns.length || 1}>
                    No data found.
                  </td>
                </tr>
              ) : (
                data.map((row, i) => (
                  <tr
                    key={i}
                    onClick={() => handleRowClick(row)}
                    className="cursor-pointer hover:bg-blue-50 transition-colors border-b border-slate-100"
                    title="Click to view broker report details"
                  >
                    {columns.map((col) => (
                      <td key={col} className="px-3 py-2 whitespace-nowrap">
                        {formatValue(row[col])}
                      </td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination info */}
        {data.length > 0 && (
          <div className="mt-4 text-sm text-slate-600">
            Showing {data.length} result{data.length !== 1 ? 's' : ''}
          </div>
        )}
      </div>
    </div>
  );
}