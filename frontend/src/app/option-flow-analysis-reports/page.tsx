"use client";

import SkillReportPage from "../components/SkillReportPage";

function getPreviousBusinessDayISO(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

const defaultObservationDate = getPreviousBusinessDayISO();

const fields = [
  {
    name: "observation_date",
    label: "Observation date",
    inputType: "date" as const,
    placeholder: defaultObservationDate,
    defaultValue: defaultObservationDate,
    required: true,
  },
  {
    name: "ticker",
    label: "Ticker drill-down",
    placeholder: "Leave blank for full market, or enter MU",
    defaultValue: "",
    omitWhenBlank: true,
  },
  {
    name: "top_n",
    label: "Top trades",
    defaultValue: 10,
    min: 1,
    max: 100,
  },
  {
    name: "timeout_minutes",
    label: "Timeout minutes",
    defaultValue: 90,
    min: 1,
    max: 240,
  },
  {
    name: "model",
    label: "Model",
    placeholder: "Leave blank to use the skill-runner default",
    defaultValue: "",
    omitWhenBlank: true,
  },
];

type OptionFlowReportDetail = {
  title: string;
  job_id: string;
  created_at?: string | null;
  stock_code?: string | null;
  content: string;
};

type OptionFlowReportSummary = {
  title: string;
  raw?: Record<string, any>;
};

const OPTION_FLOW_ASSESSMENT_SYSTEM_PROMPT = `You are an options-flow analyst. Use the supplied option-flow markdown to derive whether the flow is overall bullish, bearish, neutral, mildly bullish, and mildly bearish, even it is hard, still try to give an overall assessment in terms of bullish or bearish.

Focus on:
- Call buying versus put buying, and whether trades are opening or closing when that evidence is available.
- Premium concentration, sweep/block urgency, trade size, and whether flow is concentrated in a few tickers or broad across the tape.
- Strike/expiry positioning, moneyness, and whether the flow implies directional conviction, hedging, volatility buying, or positioning unwind.
- Repeated ticker-level evidence, sector clustering, and whether large trades conflict with or confirm the broader flow.
- Any caveats from missing open-interest context, bid/ask ambiguity, stale data, or low-quality/one-off prints.

Return:
1. Overall Assessment: one of Bullish, Bearish, Neutral, Mildly Bullish, or Mildly Bearish.
2. Confidence: High, Medium, or Low.
3. Key reasons, with direct references to the supplied flow.
4. Bullish evidence.
5. Bearish evidence.
6. What would change the assessment.`;

function removeOverallAssessmentSection(markdown: string): string {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const startIndex = lines.findIndex((line) => /^#{1,6}\s+overall assessment\s*$/i.test(line.trim()));

  if (startIndex >= 0) {
    const heading = lines[startIndex].trim();
    const level = heading.match(/^#+/)?.[0].length || 1;
    let endIndex = lines.length;

    for (let index = startIndex + 1; index < lines.length; index += 1) {
      const match = lines[index].match(/^(#{1,6})\s+\S/);
      if (match && match[1].length <= level) {
        endIndex = index;
        break;
      }
    }

    return [...lines.slice(0, startIndex), ...lines.slice(endIndex)].join("\n").trim();
  }

  return markdown
    .replace(/(?:^|\n)(?:\*\*)?Overall Assessment(?:\*\*)?\s*:?\s*\n[\s\S]*?(?=\n#{1,6}\s+\S|\n(?:\*\*)?[A-Z][^\n]{2,80}(?:\*\*)?\s*:|\s*$)/i, "\n")
    .trim();
}

function buildOptionFlowAssessmentPrompt(detail: OptionFlowReportDetail): string {
  const cleanedContent = removeOverallAssessmentSection(detail.content || "");
  if (!cleanedContent) {
    throw new Error("The displayed option-flow report does not contain markdown content to copy.");
  }

  return `${OPTION_FLOW_ASSESSMENT_SYSTEM_PROMPT}

Report metadata:
- Title: ${detail.title}
- Job ID: ${detail.job_id}
- Created at: ${detail.created_at || "unknown"}
${detail.stock_code ? `- Stock code: ${detail.stock_code}\n` : ""}
Option-flow markdown, excluding the original Overall Assessment section:

${cleanedContent}`;
}

function getOptionFlowReportDate(report: OptionFlowReportSummary): string {
  const requestDate = report.raw?.request?.observation_date;
  if (typeof requestDate === "string" && /^\d{4}-\d{2}-\d{2}$/.test(requestDate)) {
    return requestDate;
  }

  return report.title.match(/\d{4}-\d{2}-\d{2}/)?.[0] || "";
}

export default function OptionFlowAnalysisReportsPage() {
  return (
    <SkillReportPage
      title="Option Flow Analysis"
      subtitle="View generated option-flow reports and run full-market significant-trade scans, with optional ticker drill-down."
      reportsEndpoint="/api/option-flow-analysis-reports"
      jobsEndpoint="/api/option-flow-analysis/jobs"
      storageKey="stocks_au_option_flow_analysis_jobs"
      submitLabel="Submit Option Flow Job"
      emptyLabel="No option-flow analysis reports found."
      fields={fields}
      buildReportPrompt={buildOptionFlowAssessmentPrompt}
      reportPromptLabel="Get Assessment Prompt"
      copyPromptLabel="Copy Prompt"
      getReportDate={getOptionFlowReportDate}
      optionCountsEndpoint="/api/option-flow-aggregates"
      optionCountsTitle="Option Records and Contracts by Stock Code"
      canDeleteReports
      makeJobLabel={(values) => {
        const date = String(values.observation_date || "observation date");
        const ticker = String(values.ticker || "").trim().toUpperCase();
        return ticker ? `${date}:${ticker}` : `${date}:full market`;
      }}
    />
  );
}
