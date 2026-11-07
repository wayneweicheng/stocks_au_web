// Interpret date inputs as calendar dates, not browser-local timestamps.
export function easternToday(now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(now);
  const part = (name: string) => parts.find((item) => item.type === name)?.value || "";
  return `${part("year")}-${part("month")}-${part("day")}`;
}

export function defaultHistoryStart(endDate: string): string {
  const day = new Date(`${endDate}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() - 4);
  return day.toISOString().slice(0, 10);
}

export function historyRangeError(startDate: string, endDate: string): string | null {
  const parse = (value: string) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return NaN;
    const parsed = Date.parse(`${value}T00:00:00Z`);
    return Number.isFinite(parsed) && new Date(parsed).toISOString().slice(0, 10) === value ? parsed : NaN;
  };
  const start = parse(startDate);
  const end = parse(endDate);
  if (!Number.isFinite(start) || !Number.isFinite(end)) return "Select both start and end dates.";
  if (end < start) return "End date must be on or after start date.";
  if ((end - start) / 86_400_000 >= 30) return "Select at most 30 calendar days.";
  return null;
}
