type CloseSnapshot = {
  historical_closes?: Record<string, number>;
  historical_close_dates?: Record<string, string>;
};

// The two instruments' database timestamps differ by one hour. Their 30M
// 14:30 SPXW and 15:30 ESMain bars are the respective cash-close anchors.
// Never combine closes from different observation dates or infer a live basis.
export function matchedEsBasis(snapshot: CloseSnapshot | null): number | null {
  const spxDate = snapshot?.historical_close_dates?.SPX;
  if (!spxDate || snapshot?.historical_close_dates?.ESMain !== spxDate) return null;
  const spx = snapshot?.historical_closes?.SPX;
  const es = snapshot?.historical_closes?.ESMain;
  if (typeof spx !== "number" || typeof es !== "number" || !Number.isFinite(spx) || !Number.isFinite(es) || spx <= 0 || es <= 0) return null;
  return Math.round((es - spx) * 10000) / 10000;
}

const points = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export function spxEsLevel(value: number | null, basis: number | null): string {
  if (value === null || !Number.isFinite(value)) return "SPX n/a · ES n/a";
  if (basis === null || !Number.isFinite(basis)) return `SPX ${points(value)} · ES n/a`;
  return `SPX ${points(value)} · ES ${points(value + basis)} (ES−SPX ${basis >= 0 ? "+" : ""}${points(basis)})`;
}
