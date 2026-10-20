import type { ReactNode } from "react";

type LevelSide = "support" | "resistance";

export type HtmlLevelDetail = {
  key: string;
  level: string;
  areaReference: string;
  distanceToExecution: string;
  distanceToPreviousClose: string;
  executionStrength: string;
  mainBasis: string;
  optionVerification: string;
  behavior: string;
};

function cellText(cell: Element): string {
  return (cell.textContent || "").replace(/\s+/g, " ").trim();
}

function columnIndex(headers: string[], patterns: RegExp[], fallback: number): number {
  const index = headers.findIndex((header) => patterns.some((pattern) => pattern.test(header)));
  return index >= 0 ? index : fallback;
}

export function levelReportKey(side: LevelSide, rank: number): string {
  return `${side === "resistance" ? "R" : "S"}${rank}`;
}

export function parseHtmlLevelDetails(content: string): Record<string, HtmlLevelDetail> {
  if (typeof DOMParser === "undefined" || !content.trim()) return {};

  const document = new DOMParser().parseFromString(content, "text/html");
  const rows = Array.from(document.querySelectorAll("table tr"));
  const headers = rows.filter((row) => {
    const text = cellText(row);
    return /等级/.test(text) && /主要依据/.test(text) && /期权验证/.test(text);
  });
  const details: Record<string, HtmlLevelDetail> = {};
  for (const headerRow of headers) {
    const headerCells = Array.from(headerRow.querySelectorAll("th,td")).map(cellText);
    const indices = {
      level: columnIndex(headerCells, [/等级/], 0),
      areaReference: columnIndex(headerCells, [/区域/, /参考价/], 1),
      distanceToExecution: columnIndex(headerCells, [/距执行参考/], 2),
      distanceToPreviousClose: columnIndex(headerCells, [/距前收/], 3),
      executionStrength: columnIndex(headerCells, [/执行相关/, /原始强度/], 4),
      mainBasis: columnIndex(headerCells, [/主要依据/], 5),
      optionVerification: columnIndex(headerCells, [/期权验证/], 6),
      behavior: columnIndex(headerCells, [/守住/, /失效/, /翻转/], 7),
    };
    const tableRows = Array.from(headerRow.closest("table")?.querySelectorAll("tr") || []);
    const headerIndex = tableRows.indexOf(headerRow);
    for (const row of tableRows.slice(headerIndex + 1)) {
      const cells = Array.from(row.querySelectorAll("td,th")).map(cellText);
      const level = cells[indices.level] || "";
      const match = level.match(/\b([RS]\d+)\b/i);
      if (!match) continue;
      const key = match[1].toUpperCase();
      details[key] = {
        key,
        level,
        areaReference: cells[indices.areaReference] || "",
        distanceToExecution: cells[indices.distanceToExecution] || "",
        distanceToPreviousClose: cells[indices.distanceToPreviousClose] || "",
        executionStrength: cells[indices.executionStrength] || "",
        mainBasis: cells[indices.mainBasis] || "",
        optionVerification: cells[indices.optionVerification] || "",
        behavior: cells[indices.behavior] || "",
      };
    }
  }
  return details;
}

type JsonZone = Record<string, unknown>;

function finiteNumber(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  return value;
}

function levelDetailFromZone(side: LevelSide, rank: number, zone: JsonZone): HtmlLevelDetail {
  const validation = zone.option_validation && typeof zone.option_validation === "object"
    ? zone.option_validation as JsonZone : {};
  const low = finiteNumber(zone.zone_low);
  const high = finiteNumber(zone.zone_high);
  const center = finiteNumber(zone.reference_price) ?? finiteNumber(zone.tradable_center);
  const format = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const optionParts = [typeof validation.label === "string" ? validation.label : "Option verification unavailable in JSON"];
  if (validation.matched === true) {
    const strike = finiteNumber(validation.strike) ?? finiteNumber(validation.spx_price_level);
    if (strike !== null) optionParts.push(`SPX ${format(strike)}`);
    if (typeof validation.expiry_bucket === "string") optionParts.push(validation.expiry_bucket);
    const oi = finiteNumber(validation.oi_contracts);
    if (oi !== null) optionParts.push(`OI ${oi.toLocaleString("en-US")}`);
    const gex = finiteNumber(validation.gex_magnitude);
    if (gex !== null) optionParts.push(`|GEX| ${Math.abs(gex).toLocaleString("en-US", { maximumFractionDigits: 0 })}`);
  }
  const previousClose = finiteNumber(zone.distance_from_last_close_pct);
  const evidence = Array.isArray(zone.main_evidence) ? zone.main_evidence.filter((item): item is string => typeof item === "string") : [];
  const behavior = [zone.hold_condition, zone.failure_or_flip_condition]
    .filter((item): item is string => typeof item === "string" && Boolean(item.trim())).join("；");
  const raw = finiteNumber(zone.raw_confluence_score) ?? finiteNumber(zone.total_score);
  const relevance = finiteNumber(zone.execution_relevance_score);
  return {
    key: levelReportKey(side, rank),
    level: levelReportKey(side, rank),
    areaReference: low !== null && high !== null ? `${format(low)}–${format(high)}${center !== null ? ` · 参考 ${format(center)}` : ""}` : "",
    distanceToExecution: finiteNumber(zone.distance_from_execution_reference)?.toFixed(2) ?? "",
    distanceToPreviousClose: previousClose === null ? "" : `${previousClose >= 0 ? "+" : ""}${previousClose.toFixed(2)}%`,
    executionStrength: `${relevance === null ? "—" : relevance.toFixed(0)} / ${raw === null ? "—" : raw.toFixed(0)}`,
    mainBasis: evidence.join("；"),
    optionVerification: optionParts.filter(Boolean).join(" · "),
    behavior,
  };
}

function field(label: string, value: string): ReactNode {
  if (!value) return null;
  return (
    <div>
      <dt className="font-medium text-slate-600">{label}</dt>
      <dd className="mt-0.5 whitespace-pre-line text-slate-800">{value}</dd>
    </div>
  );
}

export default function MappedLevelReportDetails({
  side,
  detail,
  rank,
  zone,
}: {
  side: LevelSide;
  detail: HtmlLevelDetail | undefined;
  rank?: number;
  zone?: JsonZone;
}) {
  const fromJson = !detail && Boolean(zone && rank);
  const resolved = detail ?? (zone && rank ? levelDetailFromZone(side, rank, zone) : undefined);
  if (!resolved) return null;
  const components = zone?.score_components && typeof zone.score_components === "object"
    ? Object.entries(zone.score_components as JsonZone).filter((entry): entry is [string, number] => finiteNumber(entry[1]) !== null)
    : [];
  const rawScore = finiteNumber(zone?.raw_confluence_score) ?? finiteNumber(zone?.total_score);
  const relevanceScore = finiteNumber(zone?.execution_relevance_score);
  const validation = zone?.option_validation && typeof zone.option_validation === "object"
    ? zone.option_validation as JsonZone : null;
  const significance = finiteNumber(validation?.significance_score);
  const sideLabel = side === "resistance" ? "压力" : "支撑";
  const compactParts = [sideLabel, resolved.optionVerification, resolved.distanceToPreviousClose
    ? `前收 ${resolved.distanceToPreviousClose}`
    : ""]
    .filter(Boolean);

  return (
    <div className="mt-2 max-w-4xl text-sm">
      <div className={`font-medium ${side === "resistance" ? "text-red-700" : "text-emerald-700"}`}>
        {compactParts.join(" · ")}
      </div>
      <details className="mt-2 rounded-md border border-slate-200 bg-white/70 px-3 py-2">
        <summary className="cursor-pointer text-xs font-semibold text-slate-600">
          {fromJson ? "Level details (JSON; not in compact HTML table)" : "HTML report level details"}
        </summary>
        <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2">
          {field("等级", resolved.level)}
          {field("区域 / 参考价", resolved.areaReference)}
          {field("距执行参考", resolved.distanceToExecution)}
          {field("距前收", resolved.distanceToPreviousClose)}
          {field("执行相关 / 原始强度", resolved.executionStrength)}
          {field("主要依据", resolved.mainBasis)}
          {field("期权验证", resolved.optionVerification)}
          <div className="sm:col-span-2">{field("守住、失效或翻转", resolved.behavior)}</div>
        </dl>
        {zone && (rawScore !== null || relevanceScore !== null || components.length > 0) ? (
          <div className="mt-3 border-t border-slate-200 pt-2 text-xs text-slate-600">
            <div className="font-semibold">Score breakdown (heuristic, not a probability)</div>
            <div>Raw confluence: {rawScore === null ? "n/a" : rawScore.toFixed(1)} / 100; execution relevance: {relevanceScore === null ? "n/a" : relevanceScore.toFixed(1)}</div>
            {components.length > 0 ? <div>{components.map(([name, value]) => `${name.replace(/_/g, " ")}: ${value.toFixed(1)}`).join(" · ")}</div> : null}
            {significance !== null ? <div>Option-wall significance: {significance.toFixed(1)}/100 (relative OI/GEX bar thickness, not the zone score)</div> : null}
            <div>Raw confluence is the capped sum of source-family scores. Execution relevance discounts it for distance, time horizon, freshness and reachability. VIX affects scenario confidence, not this level score.</div>
          </div>
        ) : null}
      </details>
    </div>
  );
}
