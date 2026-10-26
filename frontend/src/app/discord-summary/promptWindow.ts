export function sydneyDate(now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Australia/Sydney", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts(now);
  const value = (part: string) => parts.find((entry) => entry.type === part)?.value || "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

export function overviewPromptUrl(baseUrl: string, observationDate: string): string {
  return `${baseUrl}/api/discord-summary-prompt?${new URLSearchParams({ observation_date: observationDate })}`;
}

export function sydneyWindowLabel(value: string): string {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString("en-AU", {
    timeZone: "Australia/Sydney", dateStyle: "medium", timeStyle: "short",
  });
}
