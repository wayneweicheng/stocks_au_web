"use client";

import SkillReportPage from "../components/SkillReportPage";

const fields = [
  {
    name: "stock_code",
    label: "Stock code",
    placeholder: "MRVL",
    defaultValue: "MRVL",
    required: true,
  },
  {
    name: "company_name",
    label: "Company name",
    placeholder: "Marvell Technology",
    defaultValue: "Marvell Technology",
  },
  {
    name: "focus",
    label: "Focus",
    placeholder: "AI infrastructure, custom silicon, and retail sentiment after earnings",
    multiline: true,
    defaultValue: "AI infrastructure, custom silicon, and retail sentiment after earnings",
  },
  {
    name: "sources",
    label: "Sources",
    placeholder: "reddit,xueqiu",
    defaultValue: "reddit,xueqiu",
  },
  {
    name: "timeout_minutes",
    label: "Timeout minutes",
    defaultValue: 75,
    min: 1,
    max: 240,
  },
];

export default function StockSocialSentimentReportsPage() {
  return (
    <SkillReportPage
      title="Stock Social Sentiment"
      subtitle="View stock social sentiment reports and run new Reddit/Xueqiu sentiment jobs through the skill-runner proxy."
      reportsEndpoint="/api/stock-social-sentiment-reports"
      jobsEndpoint="/api/stock-social-sentiment/jobs"
      storageKey="stocks_au_stock_social_sentiment_jobs"
      submitLabel="Submit Sentiment Job"
      emptyLabel="No stock social sentiment reports found."
      fields={fields}
      makeJobLabel={(values) => `${String(values.stock_code || "").toUpperCase()} social sentiment`}
    />
  );
}
