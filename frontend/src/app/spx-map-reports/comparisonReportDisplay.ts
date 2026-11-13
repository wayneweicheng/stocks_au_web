export type ComparisonReportDates = { d1: string | null; d2: string | null };

function validReportDate(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return value.match(/\b(20\d{2}-\d{2}-\d{2})\b/)?.[1] || null;
}

export function spxComparisonReportDates(report: Record<string, any>, content = ""): ComparisonReportDates {
  const metadata = report.metadata && typeof report.metadata === "object" ? report.metadata : {};
  const data = report.data && typeof report.data === "object" ? report.data : {};
  const labelDates = String(report.label || report.title || "").match(/\b20\d{2}-\d{2}-\d{2}\b/g) || [];
  const titleDates = content.match(/^#\s*SPX Map Comparison\s*[—–-]\s*(20\d{2}-\d{2}-\d{2})\s+vs\s+(20\d{2}-\d{2}-\d{2})/im);
  const d1 = validReportDate(report.d1_date || report.d1_trading_date || report.D1?.trading_date || metadata.d1_date || metadata.d1_trading_date || data.d1_date || report.observation_date || labelDates[0] || titleDates?.[1]);
  const d2 = validReportDate(report.d2_date || report.d2_trading_date || report.D2?.trading_date || metadata.d2_date || metadata.d2_trading_date || data.d2_date || labelDates[1] || titleDates?.[2]);
  const findDay = (day: "D1" | "D2") => {
    const match = content.match(new RegExp(`\\b${day}\\b[^\\r\\n]{0,200}?(20\\d{2}-\\d{2}-\\d{2})`, "i"));
    return match?.[1] || null;
  };
  return { d1: d1 || findDay("D1"), d2: d2 || findDay("D2") };
}

export function spxComparisonReportTitle(dates: ComparisonReportDates): string {
  return `D1 ${dates.d1 || "date unavailable"} vs D2 ${dates.d2 || "date unavailable"}`;
}
