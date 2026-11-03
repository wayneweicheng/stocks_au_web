// FastAPI's validation detail is an array of objects, not a printable string.
// Never render its `input` field: it can contain the entire historical report payload.
export function comparisonApiError(body: unknown, status: number): string {
  const detail = body && typeof body === "object" && "detail" in body ? body.detail : null;
  if (typeof detail === "string" && detail.trim()) return detail;
  const entries = Array.isArray(detail) ? detail : detail && typeof detail === "object" ? [detail] : [];
  const messages = entries.slice(0, 8).map((item: unknown) => {
    if (typeof item === "string") return item.slice(0, 200);
    if (!item || typeof item !== "object") return "";
    const error = item as { loc?: unknown; msg?: unknown };
    const location = Array.isArray(error.loc)
      ? error.loc.filter((part): part is string => typeof part === "string" && part !== "body").join(".").slice(0, 80)
      : "";
    const message = typeof error.msg === "string" ? error.msg.slice(0, 200) : "";
    return location && message ? `${location}: ${message}` : message;
  }).filter(Boolean);
  return messages.length ? messages.join("; ") : `HTTP ${status}`;
}
