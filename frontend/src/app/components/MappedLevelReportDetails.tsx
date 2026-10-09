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
  const headerRow = rows.find((row) => {
    const text = cellText(row);
    return /等级/.test(text) && /主要依据/.test(text) && /期权验证/.test(text);
  });
  if (!headerRow) return {};

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

  const details: Record<string, HtmlLevelDetail> = {};
  const headerIndex = rows.indexOf(headerRow);
  rows.slice(headerIndex + 1).forEach((row) => {
    const cells = Array.from(row.querySelectorAll("td,th")).map(cellText);
    const level = cells[indices.level] || "";
    const match = level.match(/\b([RS]\d+)\b/i);
    if (!match) return;
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
  });

  return details;
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
}: {
  side: LevelSide;
  detail: HtmlLevelDetail | undefined;
}) {
  if (!detail) return null;

  const sideLabel = side === "resistance" ? "压力" : "支撑";
  const compactParts = [sideLabel, detail.optionVerification, detail.distanceToPreviousClose
    ? `前收 ${detail.distanceToPreviousClose}`
    : ""]
    .filter(Boolean);

  return (
    <div className="mt-2 max-w-4xl text-sm">
      <div className={`font-medium ${side === "resistance" ? "text-red-700" : "text-emerald-700"}`}>
        {compactParts.join(" · ")}
      </div>
      <details className="mt-2 rounded-md border border-slate-200 bg-white/70 px-3 py-2">
        <summary className="cursor-pointer text-xs font-semibold text-slate-600">
          HTML report level details
        </summary>
        <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2">
          {field("等级", detail.level)}
          {field("区域 / 参考价", detail.areaReference)}
          {field("距执行参考", detail.distanceToExecution)}
          {field("距前收", detail.distanceToPreviousClose)}
          {field("执行相关 / 原始强度", detail.executionStrength)}
          {field("主要依据", detail.mainBasis)}
          {field("期权验证", detail.optionVerification)}
          <div className="sm:col-span-2">{field("守住、失效或翻转", detail.behavior)}</div>
        </dl>
      </details>
    </div>
  );
}
