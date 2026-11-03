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
  const rows = Array.from(document.querySelectorAll<HTMLTableRowElement>("table tr"));
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

function text(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "boolean") return value ? "yes" : "no";
  if (Array.isArray(value)) return value.map(text).filter(Boolean).join(", ");
  if (value && typeof value === "object") return Object.entries(value as JsonZone)
    .map(([key, item]) => `${key.replace(/_/g, " ")}: ${text(item)}`).filter(Boolean).join("; ");
  return "";
}

function formatPrice(value: number): string {
  return value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function interval(low: unknown, high: unknown): string {
  const a = finiteNumber(low);
  const b = finiteNumber(high);
  return a === null || b === null ? "" : `${formatPrice(Math.min(a, b))}–${formatPrice(Math.max(a, b))}`;
}

function percent(value: unknown): string {
  const amount = finiteNumber(value);
  return amount === null ? "" : `${amount >= 0 ? "+" : ""}${amount.toFixed(2)}%`;
}

function optionEvidence(validation: JsonZone, instrument: "stock" | "spx"): string {
  const parts: string[] = [];
  const symbol = instrument === "spx" ? "SPX" : text(validation.option_underlying_symbol);
  const strike = instrument === "spx"
    ? finiteNumber(validation.spx_price_level) ?? finiteNumber(validation.strike)
    : finiteNumber(validation.option_price_level);
  const label = text(validation.label);
  const wall = text(validation.wall_type) || text(validation.option_type) ||
    (instrument === "stock" && symbol && strike !== null
      ? label.match(/\b(?:put|call) wall\b/i)?.[0]?.toLowerCase() || ""
      : label);
  if (symbol && strike !== null) parts.push(`${symbol} ${formatPrice(strike)}${wall ? ` ${wall}` : ""}`);
  else if (wall && (instrument === "spx" || !/\bSPX\b/i.test(wall))) parts.push(wall);
  const expiries = text(validation.expiry_dates);
  if (expiries) parts.push(`Expiries ${expiries}`);
  if (text(validation.expiry_bucket)) parts.push(`Bucket ${text(validation.expiry_bucket)}`);
  if (text(validation.observation_date)) parts.push(`Observed ${text(validation.observation_date)}`);
  const stale = validation.stale ?? validation.stale_status ?? validation.is_stale;
  if (stale !== undefined && stale !== null) parts.push(`Stale: ${text(stale)}`);
  const oi = finiteNumber(validation.oi_contracts);
  if (oi !== null) parts.push(`OI ${oi.toLocaleString("en-US")}`);
  const gex = finiteNumber(validation.gex_magnitude);
  if (gex !== null) parts.push(`|GEX| ${Math.abs(gex).toLocaleString("en-US", { maximumFractionDigits: 0 })} (size only, not direction)`);
  return parts.join(" · ");
}

function levelDetailFromZone(side: LevelSide, rank: number, zone: JsonZone, instrument: "stock" | "spx"): HtmlLevelDetail {
  const validation = zone.option_validation && typeof zone.option_validation === "object"
    ? zone.option_validation as JsonZone : {};
  const anchor = finiteNumber(zone.core_anchor_price) ?? finiteNumber(zone.reference_price) ?? finiteNumber(zone.tradable_center);
  const evidence = Array.isArray(zone.main_evidence) ? zone.main_evidence.filter((item): item is string => typeof item === "string") : [];
  const raw = finiteNumber(zone.raw_confluence_score) ?? finiteNumber(zone.total_score);
  const relevance = finiteNumber(zone.execution_relevance_score);
  return {
    key: levelReportKey(side, rank),
    level: levelReportKey(side, rank),
    areaReference: `${interval(zone.zone_low, zone.zone_high)}${anchor !== null ? ` · Reference anchor ${formatPrice(anchor)}` : ""}`,
    distanceToExecution: percent(zone.distance_from_execution_reference_pct) || text(zone.distance_from_execution_reference),
    distanceToPreviousClose: percent(zone.distance_from_last_close_pct),
    executionStrength: `${relevance === null ? "—" : relevance.toFixed(0)} / ${raw === null ? "—" : raw.toFixed(0)}`,
    mainBasis: evidence.join("；"),
    optionVerification: optionEvidence(validation, instrument),
    behavior: [zone.hold_condition, zone.failure_or_flip_condition].map(text).filter(Boolean).join("；"),
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
  spxLastClose,
  instrument = "spx",
}: {
  side: LevelSide;
  detail: HtmlLevelDetail | undefined;
  rank?: number;
  zone?: JsonZone;
  spxLastClose?: number | null;
  instrument?: "stock" | "spx";
}) {
  const fromJson = !detail && Boolean(zone && rank);
  // Structured JSON is authoritative for price bases and option identity; the HTML
  // table is retained only as a fallback for reports without structured zones.
  const resolved = zone && rank ? levelDetailFromZone(side, rank, zone, instrument) : detail;
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
  const closeLabel = spxLastClose !== null && spxLastClose !== undefined && Number.isFinite(spxLastClose) && spxLastClose > 0
    ? spxLastClose.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : "n/a";
  const anchor = finiteNumber(zone?.core_anchor_price) ?? finiteNumber(zone?.reference_price);
  const midpoint = finiteNumber(zone?.zone_low) !== null && finiteNumber(zone?.zone_high) !== null && anchor !== null &&
    Math.abs(anchor - ((zone!.zone_low as number) + (zone!.zone_high as number)) / 2) < 0.000001;
  const anchorMethod = text(zone?.reference_price_method);
  const anchorInputs = text(zone?.core_anchor_inputs);
  const derivedInstrument = typeof zone?.derived_instrument === "string" ? zone.derived_instrument : null;
  const mappedAnchor = finiteNumber(zone?.mapped_anchor);
  const selectedClose = finiteNumber(zone?.mapping_selected_close);
  const mappedAnchorPct = finiteNumber(zone?.mapped_anchor_vs_selected_close_pct);
  const selectedCloseDate = typeof zone?.mapping_selected_close_date === "string" ? zone.mapping_selected_close_date : "date n/a";
  const derivedPriceChange = derivedInstrument && mappedAnchor !== null && selectedClose !== null && selectedClose > 0 && mappedAnchorPct !== null
    ? `${derivedInstrument} ${formatPrice(mappedAnchor)} (${mappedAnchorPct >= 0 ? "+" : ""}${mappedAnchorPct.toFixed(2)}%) vs 30M close ${formatPrice(selectedClose)} (${selectedCloseDate})`
    : "";
  const compactParts = [sideLabel, resolved.optionVerification,
    derivedInstrument ? derivedPriceChange : spxLastClose != null
      ? `前收 ${closeLabel}${resolved.distanceToPreviousClose ? ` ${resolved.distanceToPreviousClose}` : ""}`
      : resolved.distanceToPreviousClose ? `Previous completed daily close: ${resolved.distanceToPreviousClose}` : ""]
    .filter(Boolean);

  return (
    <div className="mt-2 max-w-4xl text-sm">
      <div className={`font-medium ${side === "resistance" ? "text-red-700" : "text-emerald-700"}`}>
        {compactParts.join(" · ")}
      </div>
      <details className="mt-2 rounded-md border border-slate-200 bg-white/70 px-3 py-2">
        <summary className="cursor-pointer text-xs font-semibold text-slate-600">
          {fromJson ? "Level details (JSON; not in compact HTML table)" : "HTML report level details (structured JSON where available)"}
        </summary>
        <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2">
          {field("等级", resolved.level)}
          {derivedInstrument ? field(`${derivedInstrument} mapped zone`, interval(zone?.mapped_zone_low, zone?.mapped_zone_high)) : null}
          {derivedInstrument && mappedAnchor !== null && selectedClose !== null && selectedClose > 0 && mappedAnchorPct !== null
            ? field("Mapped reference anchor (vs selected close)", `${formatPrice(mappedAnchor)} (${mappedAnchorPct >= 0 ? "+" : ""}${mappedAnchorPct.toFixed(2)}%) vs selected 30M close ${formatPrice(selectedClose)} (${selectedCloseDate})`) : null}
          {field(derivedInstrument ? "Source SPX system zone interval" : "System zone interval", zone ? interval(zone.zone_low, zone.zone_high) : resolved.areaReference)}
          {zone ? field(derivedInstrument ? "Source SPX reference anchor" : midpoint ? "Core anchor (zone midpoint)" : "Core reference anchor (not zone midpoint)", anchor === null ? "" : formatPrice(anchor)) : null}
          {zone ? field("Anchor method / source", [anchorMethod, anchorInputs].filter(Boolean).join(" · ")) : null}
          {zone ? field("Boundary basis (raw vs system)", text(zone.boundary_basis)) : null}
          {zone ? field("Raw mathematical interval", text(zone.mathematical_interval) || interval(zone.mathematical_zone_low, zone.mathematical_zone_high)) : null}
          {zone ? field("Raw option interval", text(zone.option_interval) || interval(zone.option_zone_low, zone.option_zone_high)) : null}
          {field(`Distance vs execution reference${text(zone?.distance_from_execution_reference_pct_basis ?? zone?.distance_from_execution_reference_basis) ? ` (${text(zone?.distance_from_execution_reference_pct_basis ?? zone?.distance_from_execution_reference_basis)})` : ""}`, zone ? percent(zone.distance_from_execution_reference_pct) : resolved.distanceToExecution)}
          {field(`Distance vs previous completed daily close${text(zone?.distance_from_last_close_pct_basis ?? zone?.distance_from_last_close_basis) ? ` (${text(zone?.distance_from_last_close_pct_basis ?? zone?.distance_from_last_close_basis)})` : ""}`, resolved.distanceToPreviousClose)}
          {field("Execution relevance / raw strength", resolved.executionStrength)}
          {field("主要依据", resolved.mainBasis)}
          {field("期权验证", resolved.optionVerification)}
          {zone ? field("Hold condition", text(zone.hold_condition)) : null}
          {zone ? field("Failure / flip condition", text(zone.failure_or_flip_condition)) : null}
          {!zone ? <div className="sm:col-span-2">{field("守住、失效或翻转", resolved.behavior)}</div> : null}
          {validation ? <div className="sm:col-span-2 text-slate-500">Option evidence is dated by observation, not proof it was available at the report’s historical as-of time. |GEX| measures size, not direction or dealer behavior.</div> : null}
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
