"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import Alert from "../components/ui/Alert";
import Button from "../components/ui/Button";
import Input from "../components/ui/Input";
import PageHeader from "../components/PageHeader";
import { authenticatedFetch } from "../utils/authenticatedFetch";

type SPXGEXReport = {
  report_id: string;
  report_date: string;
  as_of_date: string;
  observation_date?: string | null;
  file_name: string;
  report_kind: string;
  strategy_version: string;
  environment_type: string;
  generated_at: string;
  url: string;
};

type ReportListResponse = {
  items: SPXGEXReport[];
};

function formatDateTime(value: string) {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
}

export default function SPXGEXReportsPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "";
  const [reports, setReports] = useState<SPXGEXReport[]>([]);
  const [selectedReportId, setSelectedReportId] = useState("");
  const [html, setHtml] = useState("");
  const [search, setSearch] = useState("");
  const [loadingList, setLoadingList] = useState(false);
  const [loadingReport, setLoadingReport] = useState(false);
  const [error, setError] = useState("");

  const selectedReport = useMemo(
    () => reports.find((report) => report.report_id === selectedReportId) || null,
    [reports, selectedReportId]
  );

  const filteredReports = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return reports;
    return reports.filter((report) =>
      [
        report.report_date,
        report.observation_date,
        report.file_name,
        report.report_kind,
        report.strategy_version,
        report.environment_type,
        report.report_id,
      ]
        .join(" ")
        .toLowerCase()
        .includes(query)
    );
  }, [reports, search]);

  const loadReports = useCallback(async () => {
    setLoadingList(true);
    setError("");
    try {
      const response = await authenticatedFetch(`${baseUrl}/api/spx-gex/reports?limit=500`);
      const payload = (await response.json().catch(() => ({}))) as Partial<ReportListResponse> & {
        detail?: string;
      };
      if (!response.ok) throw new Error(payload.detail || `HTTP ${response.status}`);
      const items = payload.items || [];
      setReports(items);
      setSelectedReportId((current) =>
        current && items.some((report) => report.report_id === current)
          ? current
          : items[0]?.report_id || ""
      );
    } catch (caught: unknown) {
      setReports([]);
      setSelectedReportId("");
      setHtml("");
      setError(caught instanceof Error ? caught.message : "Failed to load SPX GEX reports");
    } finally {
      setLoadingList(false);
    }
  }, [baseUrl]);

  useEffect(() => {
    void loadReports();
  }, [loadReports]);

  useEffect(() => {
    if (!selectedReport) {
      setHtml("");
      return;
    }

    let cancelled = false;
    const loadSelectedReport = async () => {
      setLoadingReport(true);
      setError("");
      try {
        const response = await authenticatedFetch(`${baseUrl}${selectedReport.url}`);
        const content = await response.text();
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        if (!cancelled) setHtml(content);
      } catch (caught: unknown) {
        if (!cancelled) {
          setHtml("");
          setError(caught instanceof Error ? caught.message : "Failed to load the selected report");
        }
      } finally {
        if (!cancelled) setLoadingReport(false);
      }
    };

    void loadSelectedReport();
    return () => {
      cancelled = true;
    };
  }, [baseUrl, selectedReport]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="SPX GEX Reports"
        subtitle="View the latest SPXW GEX signal report and every retained historical HTML snapshot."
        actions={
          <div className="flex flex-wrap gap-2">
            <a
              href={`${baseUrl}/api/spx-gex/report.html`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center rounded-md border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50"
            >
              Open latest report
            </a>
            <Button type="button" variant="secondary" onClick={() => void loadReports()} disabled={loadingList}>
              {loadingList ? "Refreshing..." : "Refresh Reports"}
            </Button>
          </div>
        }
      />

      <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1 shadow-sm">
        <span className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm">
          HTML Reports
        </span>
      </div>

      {error ? <Alert variant="danger">{error}</Alert> : null}

      <div className="grid gap-4 lg:grid-cols-[320px_minmax(0,1fr)]">
        <aside className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
          <div className="border-b border-slate-200 p-3">
            <Input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search date, version, or report ID"
              aria-label="Search SPX GEX reports"
            />
          </div>
          <div className="max-h-[calc(100vh-300px)] min-h-[520px] overflow-y-auto p-2">
            {loadingList && reports.length === 0 ? (
              <div className="px-3 py-8 text-center text-sm text-slate-500">Loading reports...</div>
            ) : filteredReports.length === 0 ? (
              <div className="px-3 py-8 text-center text-sm text-slate-500">No SPX GEX reports found.</div>
            ) : (
              <div className="space-y-1">
                {filteredReports.map((report) => (
                  <button
                    key={report.report_id}
                    type="button"
                    onClick={() => setSelectedReportId(report.report_id)}
                    className={[
                      "w-full rounded-md px-3 py-3 text-left text-sm transition-colors",
                      report.report_id === selectedReportId
                        ? "bg-indigo-50 text-indigo-800"
                        : "text-slate-700 hover:bg-slate-50 hover:text-slate-900",
                    ].join(" ")}
                  >
                    <span className="block font-semibold">As of {report.as_of_date || report.report_date}</span>
                    {report.observation_date ? (
                      <span className="mt-1 block text-xs text-slate-500">Observation {report.observation_date}</span>
                    ) : null}
                    <span className="mt-1 block text-xs text-slate-500">{formatDateTime(report.generated_at)}</span>
                    <span className="mt-2 flex flex-wrap gap-2 text-xs text-slate-400">
                      <span>{report.strategy_version}</span>
                      <span>{report.environment_type.replaceAll("_", " ")}</span>
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>
        </aside>

        <section className="min-w-0 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
          <div className="border-b border-slate-200 p-4">
            {selectedReport ? (
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <h2 className="text-lg font-semibold text-slate-900">
                    SPX GEX Signal Report - as of {selectedReport.as_of_date || selectedReport.report_date}
                  </h2>
                  <div className="mt-1 break-all text-xs text-slate-500">
                    Observation {selectedReport.observation_date || "n/a"} | Generated {formatDateTime(selectedReport.generated_at)} | {selectedReport.strategy_version}
                  </div>
                  <div className="mt-1 break-all text-xs text-slate-400">
                    {selectedReport.file_name}
                  </div>
                </div>
                <a
                  href={`${baseUrl}${selectedReport.url}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex shrink-0 items-center justify-center rounded-md border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 shadow-sm transition-colors hover:bg-slate-50"
                >
                  Open full HTML in new tab
                </a>
              </div>
            ) : (
              <h2 className="text-lg font-semibold text-slate-900">SPX GEX Signal Report</h2>
            )}
          </div>
          <div className="min-h-[620px] p-5">
            {loadingReport ? (
              <div className="flex min-h-[520px] items-center justify-center text-sm text-slate-500">
                Loading report...
              </div>
            ) : html ? (
              <iframe
                title={selectedReport ? `SPX GEX report ${selectedReport.as_of_date || selectedReport.report_date}` : "SPX GEX report"}
                srcDoc={html}
                sandbox="allow-forms allow-modals allow-popups allow-scripts"
                className="h-[calc(100vh-300px)] min-h-[620px] w-full rounded-md border border-slate-200 bg-white"
              />
            ) : (
              <div className="flex min-h-[520px] items-center justify-center text-sm text-slate-500">
                Select a report to view it.
              </div>
            )}
          </div>
        </section>
      </div>

      <p className="text-xs text-slate-500">
        Reports are append-only. If a historical date is regenerated, both the original and corrected snapshots remain available.
      </p>
    </div>
  );
}
