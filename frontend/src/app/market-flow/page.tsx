"use client";

import { useEffect, useMemo, useState, useCallback } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import MarkdownRenderer from "../components/MarkdownRenderer";
import GEXAutoInsightTab from "../components/GEXAutoInsightTab";
import InsightTab from "../components/InsightTab";
import PageHeader from "../components/PageHeader";

type AnyRow = Record<string, any>;

type HorizonKey = "1d" | "2d" | "5d" | "10d" | "20d";

type SignalMeta = {
  logicId: string;
  name: string;
  description: string;
  bestHorizon: HorizonKey;
  bias?: "long" | "short";
  horizonStats: Record<string, { avgReturnPct: number; winRatePct: number; sample: number; stars: number }>;
  examples?: string[];
};

type TriggeredSignal = {
  logicId: string;
  name: string;
  description: string;
  bestHorizon: HorizonKey;
  stars: number;
  bias?: "long" | "short";
  bestStats?: { avgReturnPct: number; winRatePct: number; sample: number };
  examples?: string[];
};

const DEFAULT_STOCK = "SPXW";

function parseNum(v: any): number {
  if (v === null || v === undefined) return NaN;
  if (typeof v === "number") return v;
  const s = String(v).replace(/,/g, "").replace(/[%\s]/g, "");
  // Keep only digits, optional leading -, and dot
  const cleaned = s.match(/-?\d+(\.\d+)?/)?.[0] ?? "";
  const n = Number(cleaned);
  return isNaN(n) ? NaN : n;
}

function getField(row: AnyRow, candidates: string[]): any {
  const keys = Object.keys(row || {});
  for (const c of candidates) {
    const found = keys.find((k) => k.toLowerCase() === c.toLowerCase());
    if (found) return row[found];
  }
  return undefined;
}

function isSwingUp(row: AnyRow): boolean {
  return String(row?.SwingIndicator || "").toLowerCase() === "swing up";
}
function isPotentialSwingUp(row: AnyRow): boolean {
  return String(row?.PotentialSwingIndicator || "").toLowerCase() === "potential swing up";
}

// Default cross-stock signal definitions (names, bias, fallback best horizon)
const SIGNAL_DEFS: Record<
  string,
  { name: string; description: string; bias?: "long" | "short"; bestHorizon: HorizonKey }
> = {
  GOLDEN_SETUP: {
    name: "Golden Setup (VIX>20 & RSI<35)",
    description: "High VIX + oversold RSI; strongest 5-10 day rally probability.",
    bias: "long",
    bestHorizon: "5d"
  },
  CRASH_SHORT: {
    name: "Crash Signal (Swing Down + Negative GEX)",
    description: "Short bias: swing down while GEX is negative removes support; expect next-day drop.",
    bias: "short",
    bestHorizon: "1d"
  },
  CONFIRMED_SWING_UP: {
    name: "Confirmed Swing Up",
    description: "Safer trend buy; consistent positive drift over multi-week horizon.",
    bias: "long",
    bestHorizon: "20d"
  },
  NEG_GEX_HIGH_VIX: {
    name: "Negative GEX + High VIX (>20)",
    description: "Capitulation/bottoming; volatile but powerful 10-20 day snapback.",
    bias: "long",
    bestHorizon: "10d"
  },
  VIX_VERY_HIGH: {
    name: "VIX Very High (>20)",
    description: "Volatility regime powerful across horizons; best at 10-20 days.",
    bias: "long",
    bestHorizon: "20d"
  },
  POT_SWING_UP_NEG_GEXCHANGE: {
    name: "Potential Swing Up + Negative GEXChange",
    description: "Combined swing inflection with falling GEX; consistent across all horizons.",
    bias: "long",
    bestHorizon: "20d"
  },
  GEX_ESCAPED_VERYLOW_Z: {
    name: "GEX Escaped Very Low Z-Score",
    description: "Breakout from deeply negative Z-score; strong follow-through across horizons.",
    bias: "long",
    bestHorizon: "20d"
  },
  GEX_ZSCORE_VERY_HIGH: {
    name: "GEX Z-Score Very High (>2.0)",
    description: "Extreme positive GEX often bounces next day or two.",
    bias: "long",
    bestHorizon: "2d"
  },
  GEX_ZSCORE_HIGH: {
    name: "GEX Z-Score High (1.5 to 2.0)",
    description: "High positive GEX; bullish across 1-5 days.",
    bias: "long",
    bestHorizon: "5d"
  },
  DARKPOOL_RATIO_GT_2: {
    name: "Dark Pool Ratio > 2.0",
    description: "Institutional accumulation; moderate next-day edge and context for longs.",
    bias: "long",
    bestHorizon: "1d"
  },
  DARKPOOL_RATIO_LT_0_6: {
    name: "Dark Pool Ratio Very Low (<0.6)",
    description: "Contrarian buy (capitulation) specific to GDX; buying exhaustion often precedes rebound.",
    bias: "long",
    bestHorizon: "1d"
  },
  DARKPOOL_RATIO_GT_2_TRAP: {
    name: "Dark Pool Ratio High (>2.0) Trap",
    description: "For GDX, high dark pool ratio often underperforms short-term; avoid chasing strength.",
    bestHorizon: "1d"
  },
  GEX_FLIP_POSITIVE: {
    name: "GEX Flip Positive",
    description: "Momentum/volatility dampening regime; slight positive next day.",
    bias: "long",
    bestHorizon: "1d"
  },
  GEX_FLIP_NEGATIVE: {
    name: "GEX Flip Negative",
    description: "Loss of support; bearish skew next day.",
    bias: "short",
    bestHorizon: "1d"
  },
  GEX_HIGH_VOLATILITY: {
    name: "GEX High Volatility",
    description: "Elevated gamma volatility context; supportive for medium/long horizons in some regimes.",
    bias: "long",
    bestHorizon: "20d"
  },
  POT_SWING_DOWN_NOEDGE: {
    name: "Potential Swing Down (No Short Edge)",
    description: "For SLV, potential swing down is not a reliable short setup; avoid shorting.",
    bestHorizon: "1d"
  },
  VIX_PANIC_GEX_POSITIVE: {
    name: "Volatility Crush (VIX>25 & GEX>0)",
    description: "Market panic but stock GEX stable/positive; powerful reversal setup.",
    bias: "long",
    bestHorizon: "10d"
  },
  VIX_PANIC_RSI_LT_40: {
    name: "VIX Panic Buy (VIX>25 & RSI<40)",
    description: "Extreme capitulation filter; deeper variant of Golden Setup.",
    bias: "long",
    bestHorizon: "20d"
  },
};

function computeSignals(
  row: AnyRow,
  statsByLogicId: Record<string, SignalMeta | undefined>,
  stockForThresholds: string
): TriggeredSignal[] {
  const z = parseNum(getField(row, ["GEX_ZScore", "GEXZSCORE"]));
  const gex = parseNum(getField(row, ["GEX"]));
  const vix = parseNum(getField(row, ["VIX"]));
  const rsi = parseNum(getField(row, ["RSI"]));
  const gexChange = parseNum(getField(row, ["GEXChange", "GEXCHANGE"]));
  const goldenExplicit = parseNum(getField(row, ["Golden_Setup", "GOLDEN_SETUP"])) === 1;
  const gexTurnedPositive = parseNum(getField(row, ["GEX_Turned_Positive"])) === 1;
  const gexTurnedNegative = parseNum(getField(row, ["GEX_Turned_Negative"])) === 1;
  const escapedVeryLow = parseNum(getField(row, ["GEX_Escaped_VeryLow_Zscore"])) === 1;
  const gexHighVolatility = parseNum(getField(row, ["GEX_HighVolatility"])) === 1;
  const darkPoolRatio = parseNum(getField(row, ["Stock_DarkPoolBuySellRatio", "DarkPoolBuySellRatio"]));
  // If the DB provides a precomputed flag for Potential Swing Up + Negative GEXChange, use it as an OR condition
  const potSwingUpNegGexChangeFlag = parseNum(getField(row, ["Pot_Swing_Up_AND_Neg_GEXChange"])) === 1;
  const dpThreshold = stockForThresholds === "NVDA" ? 1.5 : 2.0;
  const dpVeryLow = stockForThresholds === "GDX" ? (darkPoolRatio > 0 && darkPoolRatio < 0.6) : false;

  const checks: Record<string, boolean> = {
    POT_SWING_UP_NEG_GEXCHANGE: potSwingUpNegGexChangeFlag || (isPotentialSwingUp(row) && gexChange < 0),
    CONFIRMED_SWING_UP: isSwingUp(row),
    NEG_GEX_HIGH_VIX: (gex < 0) && (vix > 20),
    GOLDEN_SETUP: goldenExplicit || (vix > 20 && rsi < 35),
    VIX_VERY_HIGH: vix > 20,
    VIX_PANIC_GEX_POSITIVE: (vix > 25) && (gex > 0),
    VIX_PANIC_RSI_LT_40: (vix > 25) && (rsi < 40),
    GEX_ESCAPED_VERYLOW_Z: escapedVeryLow,
    GEX_ZSCORE_VERY_HIGH: z > 2.0,
    GEX_ZSCORE_HIGH: z > 1.5 && z <= 2.0,
    DARKPOOL_RATIO_GT_2: darkPoolRatio > dpThreshold,
    DARKPOOL_RATIO_LT_0_6: dpVeryLow,
    GEX_FLIP_POSITIVE: gexTurnedPositive,
    GEX_FLIP_NEGATIVE: gexTurnedNegative,
    CRASH_SHORT: String(getField(row, ["SwingIndicator"])).toLowerCase().includes("down") && gex < 0,
    GEX_HIGH_VOLATILITY: gexHighVolatility
  };

  // Special-case trap signal for GDX: high dark pool ratio is not a buy
  if (stockForThresholds === "GDX") {
    checks["DARKPOOL_RATIO_GT_2_TRAP"] = darkPoolRatio > 2.0;
  }
  // Special-case SLV: Potential swing down shows no short edge
  if (stockForThresholds === "SLV") {
    const psd = String(getField(row, ["PotentialSwingIndicator"])).toLowerCase().includes("down");
    if (psd) checks["POT_SWING_DOWN_NOEDGE"] = true;
  }

  const triggered: TriggeredSignal[] = [];
  for (const logicId of Object.keys(checks)) {
    if (!checks[logicId]) continue;
    const def = SIGNAL_DEFS[logicId];
    if (!def) continue;
    const stats = statsByLogicId[logicId];
    const bestHorizon = stats?.bestHorizon ?? def.bestHorizon;
    const best = stats?.horizonStats?.[bestHorizon];
    triggered.push({
      logicId,
      name: stats?.name ?? def.name,
      description: stats?.description ?? def.description,
      bestHorizon,
      stars: best?.stars ?? 0,
      bias: stats?.bias ?? def.bias,
      bestStats: best ? { avgReturnPct: best.avgReturnPct, winRatePct: best.winRatePct, sample: best.sample } : undefined,
      examples: stats?.examples,
    });
  }
  return triggered;
}

function StarRating({ count }: { count: number }) {
  const full = Math.max(0, Math.min(3, count));
  return (
    <span aria-label={`${full} star rating`} className="text-amber-500">
      {"★".repeat(full)}
      <span className="text-slate-300">{"★".repeat(3 - full)}</span>
    </span>
  );
}

function formatHorizonStat(m: SignalMeta, horizon: HorizonKey) {
	const s = m.horizonStats?.[horizon];
	if (!s) return null;
	return `${horizon}: ${s.avgReturnPct.toFixed(2)}% avg, ${s.winRatePct.toFixed(1)}% win${s.sample ? ` (n=${s.sample})` : ""}`;
}

function BiasBadge({ bias }: { bias?: "long" | "short" }) {
	if (!bias) return null;
	return (
		<span
			className={`inline-block rounded-md px-2 py-0.5 text-xs font-medium ${
				bias === "short"
					? "bg-red-50 text-red-700 border border-red-200"
					: "bg-indigo-50 text-indigo-700 border border-emerald-200"
			}`}
		>
			{bias === "short" ? "Short" : "Long"}
		</span>
	);
}

export default function GexSignalsPage() {
  const [observationDate, setObservationDate] = useState<string>(() => {
    const d = new Date();
    // Default to today; allow arrows to navigate business days like other page
    return d.toISOString().slice(0, 10);
  });
  const [stockCode, setStockCode] = useState<string>(DEFAULT_STOCK);
  const [rows, setRows] = useState<AnyRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>("");
  const [statsByLogicId, setStatsByLogicId] = useState<Record<string, SignalMeta | undefined>>({});
  const [statsLoadError, setStatsLoadError] = useState<string>("");

  // Price action prediction state
  const [prediction, setPrediction] = useState<string>("");
  const [predictionLoading, setPredictionLoading] = useState(false);
  const [predictionError, setPredictionError] = useState<string>("");
  const [predictionCached, setPredictionCached] = useState<boolean>(false);
  const [predictionWarning, setPredictionWarning] = useState<string>("");
  const [selectedModel, setSelectedModel] = useState<string>("google/gemini-2.5-flash");

  // Prompt state
  const [promptText, setPromptText] = useState<string>("");
  const [promptLoading, setPromptLoading] = useState(false);
  const [promptError, setPromptError] = useState<string>("");
  const [promptCopied, setPromptCopied] = useState(false);
  const [promptMetadata, setPromptMetadata] = useState<{
    estimatedTokens: number;
    hasOptionTrades: boolean;
    hasPriceBars: boolean;
  } | null>(null);

  // Stock codes state
  const [stockCodes, setStockCodes] = useState<Array<{stock_code: string, latest_date: string}>>([]);
  const [stockCodesLoading, setStockCodesLoading] = useState(false);
  const [latestDate, setLatestDate] = useState<string>("");

  // Signal strength matrix state
  const [signalStrengths, setSignalStrengths] = useState<Array<{stock_code: string, signal_strength_level: string, buy_dip_range?: string | null, sell_rip_range?: string | null}>>([]);
  const [signalStrengthsLoading, setSignalStrengthsLoading] = useState(false);

  // Option insights state (separate from overall insights)
  const [optionPrediction, setOptionPrediction] = useState<string>("");
  const [optionPredictionLoading, setOptionPredictionLoading] = useState(false);
  const [optionPredictionError, setOptionPredictionError] = useState<string>("");
  const [optionPredictionCached, setOptionPredictionCached] = useState<boolean>(false);
  const [optionPredictionWarning, setOptionPredictionWarning] = useState<string>("");
  const [selectedOptionModel, setSelectedOptionModel] = useState<string>("google/gemini-2.5-flash");

  const [optionPromptText, setOptionPromptText] = useState<string>("");
  const [optionPromptLoading, setOptionPromptLoading] = useState(false);
  const [optionPromptError, setOptionPromptError] = useState<string>("");
  const [optionPromptCopied, setOptionPromptCopied] = useState(false);
  const [optionPromptMetadata, setOptionPromptMetadata] = useState<{
    estimatedTokens: number;
  } | null>(null);

  // Option Trades Insights state (separate from option insights)
  const [optionTradesPrediction, setOptionTradesPrediction] = useState<string>("");
  const [optionTradesPredictionLoading, setOptionTradesPredictionLoading] = useState(false);
  const [optionTradesPredictionError, setOptionTradesPredictionError] = useState<string>("");
  const [optionTradesPredictionCached, setOptionTradesPredictionCached] = useState<boolean>(false);
  const [optionTradesPredictionWarning, setOptionTradesPredictionWarning] = useState<string>("");
  const [selectedOptionTradesModel, setSelectedOptionTradesModel] = useState<string>("google/gemini-2.5-flash");

  const [optionTradesPromptText, setOptionTradesPromptText] = useState<string>("");
  const [optionTradesPromptLoading, setOptionTradesPromptLoading] = useState(false);
  const [optionTradesPromptError, setOptionTradesPromptError] = useState<string>("");
  const [optionTradesPromptCopied, setOptionTradesPromptCopied] = useState(false);
  const [optionTradesPromptMetadata, setOptionTradesPromptMetadata] = useState<{
    estimatedTokens: number;
  } | null>(null);

  // Tab state
  const [activeTab, setActiveTab] = useState<"overview" | "optionoverview" | "optiontradesinsights" | "autoinsight">("overview");

  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const canonicalStock = (stockCode || "").toUpperCase().split(".")[0] || "SPXW";

  useEffect(() => {
    // Load per-stock stats JSON from /public/meta; fallback to SPXW; if both fail, clear stats
    const code = canonicalStock;
    const urls = [`/meta/gex_signals_meta.${code}.json`, `/meta/gex_signals_meta.SPXW.json`];
    let cancelled = false;
    (async () => {
      setStatsLoadError("");
      for (const u of urls) {
        try {
          const r = await fetch(u, { cache: "no-store" });
          if (r.ok) {
            const data = await r.json();
            const arr: SignalMeta[] = Array.isArray(data?.signals) ? data.signals : [];
            const map: Record<string, SignalMeta> = {};
            for (const s of arr) map[s.logicId] = s;
            if (!cancelled) setStatsByLogicId(map);
            return;
          }
        } catch (e: any) {
          // continue to next url
        }
      }
      if (!cancelled) {
        setStatsByLogicId({});
        setStatsLoadError("No per-stock stats available");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [canonicalStock]);

  // Fetch stock codes for the selected observation date (on mount and when date/tab changes)
  useEffect(() => {
    setStockCodesLoading(true);
    const sourceType = activeTab === "optiontradesinsights" ? "OPTION_TRADES" : "GEX";
    const params = new URLSearchParams();
    if (observationDate) params.set("observation_date", observationDate);
    params.set("source_type", sourceType);
    const url = `${baseUrl}/api/stock-codes${params.toString() ? `?${params.toString()}` : ""}`;
    authenticatedFetch(url)
      .then(async (r) => {
        if (r.ok) {
          const data = await r.json();
          setStockCodes(data);
          // Ensure selected stock code exists in the filtered list; otherwise pick the first available
          if (Array.isArray(data)) {
            const exists = data.some((s: { stock_code: string }) => s.stock_code === stockCode);
            if (!exists) {
              const first = data[0]?.stock_code;
              if (first) setStockCode(first);
            }
          }
        }
      })
      .catch((e) => console.error("Failed to fetch stock codes:", e))
      .finally(() => setStockCodesLoading(false));
  }, [baseUrl, observationDate, activeTab]);

  // Update latest date when stock code changes
  useEffect(() => {
    const found = stockCodes.find(s => s.stock_code === stockCode);
    if (found) {
      setLatestDate(found.latest_date);
    } else {
      setLatestDate("");
    }
  }, [stockCode, stockCodes]);

  // Fetch signal strengths for the selected observation date (GEX source only)
  useEffect(() => {
    if (!observationDate) return;
    setSignalStrengthsLoading(true);
    const url = `${baseUrl}/api/signal-strength?observation_date=${encodeURIComponent(observationDate)}&source_type=GEX`;
    authenticatedFetch(url)
      .then(async (r) => {
        if (r.ok) {
          const data = await r.json();
          setSignalStrengths(Array.isArray(data) ? data : []);
        } else {
          setSignalStrengths([]);
        }
      })
      .catch((e) => {
        console.error("Failed to fetch signal strengths:", e);
        setSignalStrengths([]);
      })
      .finally(() => setSignalStrengthsLoading(false));
  }, [baseUrl, observationDate]);

  useEffect(() => {
    if (!observationDate || !stockCode) return;
    setLoading(true);
    setError("");
    authenticatedFetch(
      `${baseUrl}/api/gex-signals?observation_date=${encodeURIComponent(observationDate)}&stock_code=${encodeURIComponent(
        stockCode.trim().toUpperCase()
      )}`
    )
      .then(async (r) => {
        if (!r.ok) {
          let msg = `HTTP ${r.status}`;
          try {
            const data = await r.json();
            if (data && typeof data.detail === "string") {
              msg += `: ${data.detail}`;
            }
          } catch {
            try {
              const txt = await r.text();
              if (txt) msg += `: ${txt}`;
            } catch {}
          }
          throw new Error(msg);
        }
        return r.json();
      })
      .then((data) => setRows(Array.isArray(data) ? data : []))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [baseUrl, observationDate, stockCode]);

  // Fetch price action prediction
  const fetchPrediction = useCallback(async (forceRegenerate: boolean = false) => {
    if (!observationDate || !stockCode) return;
    setPredictionLoading(true);
    setPredictionError("");

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
      regenerate: String(forceRegenerate),
      model: selectedModel
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/price-prediction?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setPrediction(data.prediction_markdown || "");
      setPredictionCached(data.cached || false);
      setPredictionWarning(data.warning || "");

      // Reload signal strengths after generating/regenerating prediction
      // This ensures the matrix is updated with the latest classification
      if (!data.cached || forceRegenerate) {
        const strengthUrl = `${baseUrl}/api/signal-strength?observation_date=${encodeURIComponent(observationDate)}&source_type=GEX`;
        authenticatedFetch(strengthUrl)
          .then(async (sr) => {
            if (sr.ok) {
              const strengthData = await sr.json();
              setSignalStrengths(Array.isArray(strengthData) ? strengthData : []);
            }
          })
          .catch((e) => console.error("Failed to refresh signal strengths:", e));
      }
    } catch (e: any) {
      setPredictionError(e.message);
      setPredictionWarning("");
    } finally {
      setPredictionLoading(false);
    }
  }, [baseUrl, observationDate, stockCode, selectedModel]);

  // Fetch prompt from API (doesn't copy yet)
  const fetchPrompt = useCallback(async () => {
    if (!observationDate || !stockCode) return;

    setPromptLoading(true);
    setPromptError("");
    setPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/price-prediction-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setPromptText(data.prompt || "");

      // Extract and store metadata
      setPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
        hasOptionTrades: data.has_option_trades || false,
        hasPriceBars: data.has_price_bars_30m || false,
      });
    } catch (e: any) {
      setPromptError(e.message);
      setPromptText("");
      setPromptMetadata(null);
    } finally {
      setPromptLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  // Copy prompt to clipboard (synchronous, mobile-friendly)
  const copyPromptToClipboard = useCallback(() => {
    if (!promptText) return;

    setPromptError("");
    setPromptCopied(false);

    // Mobile-friendly copy: Use a temporary textarea
    const textarea = document.createElement("textarea");
    textarea.value = promptText;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";
    textarea.setAttribute("readonly", "");
    document.body.appendChild(textarea);

    try {
      textarea.focus();
      textarea.select();

      // Use execCommand for maximum mobile compatibility
      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setPromptCopied(true);
      // Reset success message after 2 seconds
      setTimeout(() => setPromptCopied(false), 2000);
    } catch (clipboardError) {
      setPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [promptText]);

  // Don't auto-fetch prediction - only fetch when user clicks Generate/Regenerate button

  // Fetch option insight prediction
  const fetchOptionPrediction = useCallback(async (forceRegenerate: boolean = false) => {
    if (!observationDate || !stockCode) return;
    setOptionPredictionLoading(true);
    setOptionPredictionError("");

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
      regenerate: String(forceRegenerate),
      model: selectedOptionModel
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/option-insight-prediction?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setOptionPrediction(data.prediction_markdown || "");
      setOptionPredictionCached(data.cached || false);
      setOptionPredictionWarning(data.warning || "");

      // Reload signal strengths for OPTION source type after generating/regenerating
      if (!data.cached || forceRegenerate) {
        const strengthUrl = `${baseUrl}/api/signal-strength?observation_date=${encodeURIComponent(observationDate)}&source_type=OPTION`;
        authenticatedFetch(strengthUrl)
          .then(async (sr) => {
            if (sr.ok) {
              const strengthData = await sr.json();
              setSignalStrengths(Array.isArray(strengthData) ? strengthData : []);
            }
          })
          .catch((e) => console.error("Failed to refresh signal strengths:", e));
      }
    } catch (e: any) {
      setOptionPredictionError(e.message);
      setOptionPredictionWarning("");
    } finally {
      setOptionPredictionLoading(false);
    }
  }, [baseUrl, observationDate, stockCode, selectedOptionModel]);

  // Fetch option prompt from API
  const fetchOptionPrompt = useCallback(async () => {
    if (!observationDate || !stockCode) return;

    setOptionPromptLoading(true);
    setOptionPromptError("");
    setOptionPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/option-insight-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setOptionPromptText(data.prompt || "");

      setOptionPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
      });
    } catch (e: any) {
      setOptionPromptError(e.message);
      setOptionPromptText("");
      setOptionPromptMetadata(null);
    } finally {
      setOptionPromptLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  // Copy option prompt to clipboard
  const copyOptionPromptToClipboard = useCallback(() => {
    if (!optionPromptText) return;

    setOptionPromptError("");
    setOptionPromptCopied(false);

    const textarea = document.createElement("textarea");
    textarea.value = optionPromptText;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";
    textarea.setAttribute("readonly", "");
    document.body.appendChild(textarea);

    try {
      textarea.focus();
      textarea.select();

      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setOptionPromptCopied(true);
      setTimeout(() => setOptionPromptCopied(false), 2000);
    } catch (clipboardError) {
      setOptionPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [optionPromptText]);

  // Fetch option trades insight prediction
  const fetchOptionTradesPrediction = useCallback(async (forceRegenerate: boolean = false) => {
    if (!observationDate || !stockCode) return;
    setOptionTradesPredictionLoading(true);
    setOptionTradesPredictionError("");

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
      regenerate: String(forceRegenerate),
      model: selectedOptionTradesModel
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/option-trades-insight-prediction?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setOptionTradesPrediction(data.prediction_markdown || "");
      setOptionTradesPredictionCached(data.cached || false);
      setOptionTradesPredictionWarning(data.warning || "");
    } catch (e: any) {
      setOptionTradesPredictionError(e.message);
      setOptionTradesPredictionWarning("");
    } finally {
      setOptionTradesPredictionLoading(false);
    }
  }, [baseUrl, observationDate, stockCode, selectedOptionTradesModel]);

  // Fetch option trades prompt from API
  const fetchOptionTradesPrompt = useCallback(async () => {
    if (!observationDate || !stockCode) return;

    setOptionTradesPromptLoading(true);
    setOptionTradesPromptError("");
    setOptionTradesPromptCopied(false);

    const params = new URLSearchParams({
      observation_date: observationDate,
      stock_code: stockCode.trim().toUpperCase(),
    });

    try {
      const r = await authenticatedFetch(`${baseUrl}/api/option-trades-insight-prompt?${params}`);
      if (!r.ok) {
        const data = await r.json().catch(() => ({}));
        throw new Error(data.detail || `HTTP ${r.status}`);
      }
      const data = await r.json();
      setOptionTradesPromptText(data.prompt || "");

      setOptionTradesPromptMetadata({
        estimatedTokens: data.estimated_tokens || 0,
      });
    } catch (e: any) {
      setOptionTradesPromptError(e.message);
      setOptionTradesPromptText("");
      setOptionTradesPromptMetadata(null);
    } finally {
      setOptionTradesPromptLoading(false);
    }
  }, [baseUrl, observationDate, stockCode]);

  // Copy option trades prompt to clipboard
  const copyOptionTradesPromptToClipboard = useCallback(() => {
    if (!optionTradesPromptText) return;

    setOptionTradesPromptError("");
    setOptionTradesPromptCopied(false);

    const textarea = document.createElement("textarea");
    textarea.value = optionTradesPromptText;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    textarea.style.top = "0";
    textarea.setAttribute("readonly", "");
    document.body.appendChild(textarea);

    try {
      textarea.focus();
      textarea.select();

      const success = document.execCommand("copy");
      if (!success) {
        throw new Error("Copy command failed");
      }

      setOptionTradesPromptCopied(true);
      setTimeout(() => setOptionTradesPromptCopied(false), 2000);
    } catch (clipboardError) {
      setOptionTradesPromptError("Failed to copy. Please select and copy manually.");
    } finally {
      document.body.removeChild(textarea);
    }
  }, [optionTradesPromptText]);

  const triggeredSignals = useMemo<TriggeredSignal[]>(() => {
    const row = rows?.[0];
    if (!row) return [];
    return computeSignals(row, statsByLogicId, canonicalStock);
  }, [rows, statsByLogicId, canonicalStock]);

  const row = rows?.[0];

	// Map of logicId -> stats (for the current stock); used to render horizon stats
	const byId: Record<string, SignalMeta | undefined> = useMemo(() => {
		return statsByLogicId;
	}, [statsByLogicId]);

	const grouped = useMemo(() => {
		const groups: { short: TriggeredSignal[]; medium: TriggeredSignal[]; long: TriggeredSignal[] } = {
			short: [],
			medium: [],
			long: [],
		};
		for (const s of triggeredSignals) {
			if (s.bestHorizon === "1d" || s.bestHorizon === "2d") groups.short.push(s);
			else if (s.bestHorizon === "5d") groups.medium.push(s);
			else groups.long.push(s); // default 10d / 20d
		}
		return groups;
	}, [triggeredSignals]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Market Flow"
        subtitle="Daily composite signals (GEX/VIX/Dark Pool) plus swing regime context."
      />

        {/* Tab Navigation */}
        <div className="flex border-b border-slate-200 mb-6">
          <button
            type="button"
            onClick={() => setActiveTab("overview")}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              activeTab === "overview"
                ? "border-indigo-500 text-indigo-600"
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            }`}
          >
            Overview
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("optionoverview")}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              activeTab === "optionoverview"
                ? "border-indigo-500 text-indigo-600"
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            }`}
          >
            Option Overview
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("optiontradesinsights")}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              activeTab === "optiontradesinsights"
                ? "border-indigo-500 text-indigo-600"
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            }`}
          >
            Option Trades Insights
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("autoinsight")}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              activeTab === "autoinsight"
                ? "border-indigo-500 text-indigo-600"
                : "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
            }`}
          >
            Market Flow Admin
          </button>
        </div>

        {activeTab === "autoinsight" ? (
          <GEXAutoInsightTab />
        ) : activeTab === "optionoverview" ? (
          <>
            {/* Date and Stock filters for Option Overview */}
            <div className="grid gap-4 sm:grid-cols-3 mb-6">
              <div>
                <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    aria-label="Previous business day"
                    onClick={() => {
                      const d = new Date(observationDate);
                      d.setDate(d.getDate() - 1);
                      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                      setObservationDate(d.toISOString().slice(0, 10));
                    }}
                    className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
                  >
                    ←
                  </button>
                  <input
                    type="date"
                    value={observationDate}
                    onChange={(e) => setObservationDate(e.target.value)}
                    className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
                  />
                  <button
                    type="button"
                    aria-label="Next business day"
                    onClick={() => {
                      const d = new Date(observationDate);
                      d.setDate(d.getDate() + 1);
                      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                      setObservationDate(d.toISOString().slice(0, 10));
                    }}
                    className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
                  >
                    →
                  </button>
                </div>
              </div>
              <div className="sm:col-span-2">
                <label className="block text-sm mb-1 text-slate-600">
                  Stock Code
                  {latestDate && <span className="ml-2 text-xs text-slate-500">(Latest: {latestDate})</span>}
                </label>
                <select
                  value={stockCode}
                  onChange={(e) => setStockCode(e.target.value)}
                  disabled={stockCodesLoading}
                  className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
                >
                  {stockCodes.map((s) => (
                    <option key={s.stock_code} value={s.stock_code}>
                      {s.stock_code}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {/* Option Overview Tab */}
            <InsightTab
              title="Option Flow Insights"
              prediction={optionPrediction}
              predictionLoading={optionPredictionLoading}
              predictionError={optionPredictionError}
              predictionCached={optionPredictionCached}
              predictionWarning={optionPredictionWarning}
              selectedModel={selectedOptionModel}
              onModelChange={setSelectedOptionModel}
              onGenerate={() => fetchOptionPrediction(false)}
              onRegenerate={() => fetchOptionPrediction(true)}
              onGetPrompt={fetchOptionPrompt}
              onCopyPrompt={copyOptionPromptToClipboard}
              promptText={optionPromptText}
              promptLoading={optionPromptLoading}
              promptError={optionPromptError}
              promptCopied={optionPromptCopied}
              promptMetadata={optionPromptMetadata}
            />
          </>
        ) : activeTab === "optiontradesinsights" ? (
          <>
            {/* Date and Stock filters for Option Trades Insights */}
            <div className="grid gap-4 sm:grid-cols-3 mb-6">
              <div>
                <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    aria-label="Previous business day"
                    onClick={() => {
                      const d = new Date(observationDate);
                      d.setDate(d.getDate() - 1);
                      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                      setObservationDate(d.toISOString().slice(0, 10));
                    }}
                    className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
                  >
                    ←
                  </button>
                  <input
                    type="date"
                    value={observationDate}
                    onChange={(e) => setObservationDate(e.target.value)}
                    className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
                  />
                  <button
                    type="button"
                    aria-label="Next business day"
                    onClick={() => {
                      const d = new Date(observationDate);
                      d.setDate(d.getDate() + 1);
                      while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                      setObservationDate(d.toISOString().slice(0, 10));
                    }}
                    className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
                  >
                    →
                  </button>
                </div>
              </div>
              <div className="sm:col-span-2">
                <label className="block text-sm mb-1 text-slate-600">
                  Stock Code
                  {latestDate && <span className="ml-2 text-xs text-slate-500">(Latest: {latestDate})</span>}
                </label>
                <select
                  value={stockCode}
                  onChange={(e) => setStockCode(e.target.value)}
                  disabled={stockCodesLoading}
                  className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
                >
                  {stockCodes.map((s) => (
                    <option key={s.stock_code} value={s.stock_code}>
                      {s.stock_code}
                    </option>
                  ))}
                </select>
                {!stockCodesLoading && stockCodes.length === 0 && (
                  <p className="mt-2 text-xs text-slate-500">
                    No large option trades (size &gt; 300) found for this date. Try another date.
                  </p>
                )}
              </div>
            </div>

            {/* Option Trades Insights Tab */}
            <InsightTab
              title="Option Trades Flow Insights"
              prediction={optionTradesPrediction}
              predictionLoading={optionTradesPredictionLoading}
              predictionError={optionTradesPredictionError}
              predictionCached={optionTradesPredictionCached}
              predictionWarning={optionTradesPredictionWarning}
              selectedModel={selectedOptionTradesModel}
              onModelChange={setSelectedOptionTradesModel}
              onGenerate={() => fetchOptionTradesPrediction(false)}
              onRegenerate={() => fetchOptionTradesPrediction(true)}
              onGetPrompt={fetchOptionTradesPrompt}
              onCopyPrompt={copyOptionTradesPromptToClipboard}
              promptText={optionTradesPromptText}
              promptLoading={optionTradesPromptLoading}
              promptError={optionTradesPromptError}
              promptCopied={optionTradesPromptCopied}
              promptMetadata={optionTradesPromptMetadata}
            />
          </>
        ) : (
          <>
        <div className="grid gap-4 sm:grid-cols-3 mb-6">
          <div>
            <label className="block text-sm mb-1 text-slate-600">Observation Date</label>
            <div className="flex items-center gap-2">
              <button
                type="button"
                aria-label="Previous business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() - 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() - 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
              >
                ←
              </button>
              <input
                type="date"
                value={observationDate}
                onChange={(e) => setObservationDate(e.target.value)}
                className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
              />
              <button
                type="button"
                aria-label="Next business day"
                onClick={() => {
                  const d = new Date(observationDate);
                  d.setDate(d.getDate() + 1);
                  while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
                  setObservationDate(d.toISOString().slice(0, 10));
                }}
                className="rounded-md border border-slate-300 bg-white px-2 py-2 text-sm hover:bg-indigo-50"
              >
                →
              </button>
            </div>
          </div>
          <div className="sm:col-span-2">
            <label className="block text-sm mb-1 text-slate-600">
              Stock Code
              {latestDate && <span className="ml-2 text-xs text-slate-500">(Latest: {latestDate})</span>}
            </label>
            <select
              value={stockCode}
              onChange={(e) => setStockCode(e.target.value)}
              disabled={stockCodesLoading}
              className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400/40 focus:border-indigo-400/40"
            >
              {stockCodes.map((s) => (
                <option key={s.stock_code} value={s.stock_code}>
                  {s.stock_code}
                </option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded-md border border-red-200 bg-red-50 text-red-700 px-3 py-2 text-sm">Error: {error}</div>
        )}

        {/* Price Action Prediction Section */}
        <div className="mb-8">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
              <h2 className="text-lg font-semibold text-slate-700">Price Action Prediction</h2>

              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={selectedModel}
                  onChange={(e) => setSelectedModel(e.target.value)}
                  className="w-full sm:w-auto rounded-md border border-slate-300 px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="google/gemini-2.5-flash">Gemini 2.5 Flash</option>
                  <option value="openai/gpt-5-mini">GPT-5 Mini</option>
                  <option value="qwen/qwen3-30b-a3b">Qwen3 30B</option>
                  <option value="openai/gpt-5.1">GPT-5.1</option>
                  <option value="openai/gpt-4.1-mini">GPT-4.1 Mini</option>
                  <option value="google/gemini-2.5-pro">Gemini 2.5 Pro</option>
                  <option value="deepseek/deepseek-v3.2">DeepSeek V3.2</option>
                  <option value="deepseek/deepseek-r1-0528-qwen3-8b">DeepSeek R1 Qwen3 8B</option>
                  <option value="x-ai/grok-4.1-fast">Grok 4.1 Fast</option>
                </select>
                <button
                  type="button"
                  onClick={() => fetchPrediction(false)}
                  disabled={predictionLoading}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-blue-500 bg-blue-500 px-3 py-1.5 text-sm text-white hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {predictionLoading && !prediction ? "Generating..." : "Generate"}
                </button>
                <button
                  type="button"
                  onClick={() => fetchPrediction(true)}
                  disabled={predictionLoading}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-indigo-500 bg-white px-3 py-1.5 text-sm text-indigo-600 hover:bg-indigo-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {predictionLoading && prediction ? "Regenerating..." : "Regenerate"}
                </button>
                <button
                  type="button"
                  onClick={fetchPrompt}
                  disabled={promptLoading || !observationDate || !stockCode}
                  className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-slate-400 bg-white px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  title="Fetch LLM prompt"
                >
                  {promptLoading ? "Loading..." : "Get Prompt"}
                </button>
                {promptText && (
                  <button
                    type="button"
                    onClick={copyPromptToClipboard}
                    disabled={!promptText}
                    className="flex-1 sm:flex-none min-w-[100px] rounded-md border border-green-500 bg-green-500 px-3 py-1.5 text-sm text-white hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    title="Copy prompt to clipboard"
                  >
                    Copy
                  </button>
                )}
              </div>
            </div>

            {/* Prompt Feedback Messages */}
            {(promptCopied || promptError) && (
              <div className="mb-3">
                {promptCopied && (
                  <div className="text-sm text-indigo-600 flex items-center gap-2 animate-fade-in">
                    <span>✓</span>
                    <span>
                      Prompt copied!
                      {promptMetadata && (
                        <>
                          {" "}~{promptMetadata.estimatedTokens.toLocaleString()} tokens
                          {promptMetadata.hasOptionTrades && " • Option trades ✓"}
                          {promptMetadata.hasPriceBars && " • 30M bars ✓"}
                        </>
                      )}
                    </span>
                  </div>
                )}
                {promptError && (
                  <div className="text-sm text-red-600">
                    Error: {promptError}
                  </div>
                )}
              </div>
            )}

            {predictionLoading ? (
              <div className="text-sm text-slate-600">Loading prediction...</div>
            ) : predictionError ? (
              <div className="text-sm text-red-600">Error: {predictionError}</div>
            ) : prediction ? (
              <div>
                {predictionCached && (
                  <div className="mb-2 text-xs text-slate-500 italic">(Cached prediction)</div>
                )}
                {predictionWarning && (
                  <div className="mb-3 rounded-md border border-yellow-200 bg-yellow-50 text-yellow-800 px-3 py-2 text-sm">
                    ⚠️ {predictionWarning}
                  </div>
                )}
                <div className="prose prose-sm max-w-none">
                  <MarkdownRenderer content={prediction} />
                </div>
              </div>
            ) : (
              <div className="text-sm text-slate-600">
                Click &quot;Generate&quot; to create a price action prediction for this stock and date.
              </div>
            )}
          </div>
        </div>

        {/* Signal Strength Matrix Section */}
        <div className="mb-8">
          <div className="rounded-lg border border-slate-200 bg-white p-6">
            <h2 className="text-lg font-semibold mb-4 text-slate-700">Market Signal Strength Matrix</h2>

            {signalStrengthsLoading ? (
              <div className="text-sm text-slate-600">Loading signal strengths...</div>
            ) : signalStrengths.length === 0 ? (
              <div className="text-sm text-slate-600">
                No signal strength data available for {observationDate}. Generate predictions to populate this matrix.
              </div>
            ) : (
              <div>
                {/* Desktop/Tablet matrix */}
                <div className="hidden sm:block overflow-x-auto">
                  <div className="inline-block min-w-full">
                  {/* Header Row */}
                  <div className="grid grid-cols-8 gap-2 mb-3 pb-2 border-b border-slate-200">
                    <div className="text-xs font-semibold text-slate-600 uppercase">Stock</div>
                    <div className="text-xs font-semibold text-center text-indigo-700">Strongly Bullish</div>
                    <div className="text-xs font-semibold text-center text-emerald-500">Mildly Bullish</div>
                    <div className="text-xs font-semibold text-center text-amber-600">Neutral</div>
                    <div className="text-xs font-semibold text-center text-orange-500">Mildly Bearish</div>
                    <div className="text-xs font-semibold text-center text-red-600">Strongly Bearish</div>
                    <div className="text-xs font-semibold text-center text-slate-600">Buy the Dip Range</div>
                    <div className="text-xs font-semibold text-center text-slate-600">Sell the Rip Range</div>
                  </div>

                  {/* Data Rows */}
                  {signalStrengths.map((item) => {
                    const level = item.signal_strength_level;
                    return (
                      <div key={item.stock_code} className="grid grid-cols-8 gap-2 py-2 border-b border-slate-100 hover:bg-slate-50">
                        <div className="text-sm font-medium text-slate-700">{item.stock_code}</div>

                        {/* Strongly Bullish */}
                        <div className="flex justify-center items-center">
                          {level === "STRONGLY_BULLISH" && (
                            <div className="w-6 h-6 rounded-full bg-indigo-600" title="Strongly Bullish"></div>
                          )}
                        </div>

                        {/* Mildly Bullish */}
                        <div className="flex justify-center items-center">
                          {level === "MILDLY_BULLISH" && (
                            <div className="w-6 h-6 rounded-full bg-emerald-300" title="Mildly Bullish"></div>
                          )}
                        </div>

                        {/* Neutral */}
                        <div className="flex justify-center items-center">
                          {level === "NEUTRAL" && (
                            <div className="w-6 h-6 rounded-full bg-amber-400" title="Neutral"></div>
                          )}
                        </div>

                        {/* Mildly Bearish */}
                        <div className="flex justify-center items-center">
                          {level === "MILDLY_BEARISH" && (
                            <div className="w-6 h-6 rounded-full bg-orange-400" title="Mildly Bearish"></div>
                          )}
                        </div>

                        {/* Strongly Bearish */}
                        <div className="flex justify-center items-center">
                          {level === "STRONGLY_BEARISH" && (
                            <div className="w-6 h-6 rounded-full bg-red-600" title="Strongly Bearish"></div>
                          )}
                        </div>

                        {/* Buy Dip Range */}
                        <div className="flex justify-center items-center text-xs text-slate-700">
                          {item.buy_dip_range || "-"}
                        </div>

                        {/* Sell Rip Range */}
                        <div className="flex justify-center items-center text-xs text-slate-700">
                          {item.sell_rip_range || "-"}
                        </div>
                      </div>
                    );
                  })}
                  </div>
                </div>

                {/* Mobile cards */}
                <div className="sm:hidden space-y-3">
                  {signalStrengths.map((item) => {
                    const level = item.signal_strength_level;
                    const label = (level || "").replace(/_/g, " ");
                    const color =
                      level === "STRONGLY_BULLISH" ? "bg-indigo-600" :
                      level === "MILDLY_BULLISH" ? "bg-emerald-300" :
                      level === "NEUTRAL" ? "bg-amber-400" :
                      level === "MILDLY_BEARISH" ? "bg-orange-400" :
                      level === "STRONGLY_BEARISH" ? "bg-red-600" : "bg-slate-300";
                    return (
                      <div key={item.stock_code} className="rounded-md border border-slate-200 p-3 bg-white">
                        <div className="flex items-center justify-between">
                          <div className="text-sm font-semibold text-slate-800">{item.stock_code}</div>
                          <div className="flex items-center gap-2">
                            <div className={`w-4 h-4 rounded-full ${color}`} aria-hidden />
                            <div className="text-xs text-slate-700 uppercase">{label}</div>
                          </div>
                        </div>
                        <div className="mt-2 grid grid-cols-2 gap-2">
                          <div className="text-xs text-slate-600">
                            <div className="font-medium text-slate-700">Buy Dip</div>
                            <div>{item.buy_dip_range || "-"}</div>
                          </div>
                          <div className="text-xs text-slate-600">
                            <div className="font-medium text-slate-700">Sell Rip</div>
                            <div>{item.sell_rip_range || "-"}</div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="grid gap-4 sm:grid-cols-3 mb-8">
          <div className="sm:col-span-3 rounded-lg border border-slate-200 bg-white p-4">
            <h2 className="text-lg font-semibold mb-3 text-slate-700">Context</h2>
            <ul className="list-disc pl-5 text-sm text-slate-700 space-y-1">
              <li>
                <b>Best short-term signals (1-2d):</b> Potential swing up + negative GEXChange; Swing up.
              </li>
              <li>
                <b>Best 5-20d signals:</b> Low/Very Low GEX Z-scores; combined swing + GEX.
              </li>
              <li>
                <b>Note:</b> Very Low GEX Z (&lt;-2.0) tends to dip on day 1, then rally over 10-20 days.
              </li>
            </ul>
          </div>
        </div>

		<div className="grid gap-4 sm:grid-cols-3">
			<div className="rounded-lg border border-slate-200 bg-white p-4">
				<h2 className="text-lg font-semibold mb-1 text-slate-700">Short-term (1-2d)</h2>
				<p className="text-xs text-slate-500 mb-3">Best for quick tactical trades (tomorrow/2 days).</p>
				{loading ? (
					<div className="text-sm text-slate-600">Loading…</div>
				) : !row ? (
					<div className="text-sm text-slate-600">No data found for selected date/code.</div>
				) : grouped.short.length === 0 ? (
					<div className="text-sm text-slate-600">No short-term signals today.</div>
				) : (
					<ul className="space-y-3">
						{grouped.short.map((s) => {
							const m = byId[s.logicId];
							return (
								<li key={s.logicId} className="rounded-md border border-slate-200 p-3">
									<div className="flex items-center justify-between">
										<div className="font-medium text-slate-800">{s.name}</div>
										<StarRating count={s.stars} />
									</div>
									<div className="mt-1"><BiasBadge bias={s.bias} /></div>
									<div className="text-sm text-slate-600 mt-1">{s.description}</div>
									<div className="text-xs text-slate-700 mt-2 space-x-3">
										{m && <span>{formatHorizonStat(m, "1d")}</span>}
										{m && <span>{formatHorizonStat(m, "2d")}</span>}
									</div>
								</li>
							);
						})}
					</ul>
				)}
			</div>

			<div className="rounded-lg border border-slate-200 bg-white p-4">
				<h2 className="text-lg font-semibold mb-1 text-slate-700">Medium-term (5d)</h2>
				<p className="text-xs text-slate-500 mb-3">Hold for one trading week.</p>
				{loading ? (
					<div className="text-sm text-slate-600">Loading…</div>
				) : !row ? (
					<div className="text-sm text-slate-600">No data found for selected date/code.</div>
				) : grouped.medium.length === 0 ? (
					<div className="text-sm text-slate-600">No medium-term signals today.</div>
				) : (
					<ul className="space-y-3">
						{grouped.medium.map((s) => {
							const m = byId[s.logicId];
							return (
								<li key={s.logicId} className="rounded-md border border-slate-200 p-3">
									<div className="flex items-center justify-between">
										<div className="font-medium text-slate-800">{s.name}</div>
										<StarRating count={s.stars} />
									</div>
									<div className="mt-1"><BiasBadge bias={s.bias} /></div>
									<div className="text-sm text-slate-600 mt-1">{s.description}</div>
									<div className="text-xs text-slate-700 mt-2">
										{m && <span>{formatHorizonStat(m, "5d")}</span>}
									</div>
								</li>
							);
						})}
					</ul>
				)}
			</div>

			<div className="rounded-lg border border-slate-200 bg-white p-4">
				<h2 className="text-lg font-semibold mb-1 text-slate-700">Long-term (10-20d)</h2>
				<p className="text-xs text-slate-500 mb-3">Position trades over 2-4 weeks.</p>
				{loading ? (
					<div className="text-sm text-slate-600">Loading…</div>
				) : !row ? (
					<div className="text-sm text-slate-600">No data found for selected date/code.</div>
				) : grouped.long.length === 0 ? (
					<div className="text-sm text-slate-600">No long-term signals today.</div>
				) : (
					<ul className="space-y-3">
						{grouped.long.map((s) => {
							const m = byId[s.logicId];
							return (
								<li key={s.logicId} className="rounded-md border border-slate-200 p-3">
									<div className="flex items-center justify-between">
										<div className="font-medium text-slate-800">{s.name}</div>
										<StarRating count={s.stars} />
									</div>
									<div className="mt-1"><BiasBadge bias={s.bias} /></div>
									<div className="text-sm text-slate-600 mt-1">{s.description}</div>
									<div className="text-xs text-slate-700 mt-2 space-x-3">
										{m && <span>{formatHorizonStat(m, "10d")}</span>}
										{m && <span>{formatHorizonStat(m, "20d")}</span>}
									</div>
								</li>
							);
						})}
					</ul>
				)}
			</div>
		</div>

		<div className="grid gap-4 sm:grid-cols-2 mt-4">
			<div className="rounded-lg border border-slate-200 bg-white p-4">
            <h2 className="text-lg font-semibold mb-3 text-slate-700">GEX Snapshot</h2>
            {loading ? (
              <div className="text-sm text-slate-600">Loading…</div>
            ) : !row ? (
              <div className="text-sm text-slate-600">No data.</div>
            ) : (
              <div className="text-sm text-slate-700 space-y-2">
                <div>
                  <b>ObservationDate:</b>{" "}
                  {String(getField(row, ["ObservationDate", "OBSERVATIONDATE", "Date", "AsOfDate"]) ?? "")}
                </div>
                <div>
                  <b>ASXCode:</b>{" "}
                  {String(getField(row, ["StockCode", "ASXCode", "ASXCODE", "Symbol", "Ticker"]) ?? "")}
                </div>
                <div>
                  <b>GEX:</b>{" "}
                  {(() => {
                    const formatted = getField(row, ["FormattedGEX", "FORMATTEDGEX"]);
                    if (formatted !== undefined) return String(formatted);
                    const n = parseNum(getField(row, ["GEX"]));
                    return isNaN(n) ? "" : n.toLocaleString();
                  })()}
                </div>
                <div>
                  <b>Prev1GEX:</b>{" "}
                  {(() => {
                    const formatted = getField(row, ["FormattedPrev1GEX", "FORMATTEDPREV1GEX"]);
                    if (formatted !== undefined) return String(formatted);
                    const n = parseNum(getField(row, ["Prev1GEX"]));
                    return isNaN(n) ? "" : n.toLocaleString();
                  })()}
                </div>
                <div>
                  <b>GEXChange:</b>{" "}
                  {String(getField(row, ["GEXChange", "GEXCHANGE"]) ?? "")}
                </div>
                {getField(row, ["GEX_ZScore", "GEXZSCORE"]) !== undefined && (
                  <div>
                    <b>GEX Z-Score:</b>{" "}
                    {String(getField(row, ["GEX_ZScore", "GEXZSCORE"]) ?? "")}
                  </div>
                )}
                <div>
                  <b>Regime:</b>{" "}
                  {(() => {
                    const gex = parseNum(getField(row, ["GEX"]));
                    if (!isNaN(gex)) return gex >= 0 ? "Positive Gamma" : "Negative Gamma";
                    const tp = parseNum(getField(row, ["GEX_Turned_Positive"]));
                    const tn = parseNum(getField(row, ["GEX_Turned_Negative"]));
                    if (tp === 1) return "Turned Positive";
                    if (tn === 1) return "Turned Negative";
                    return "Unknown";
                  })()}
                </div>
              </div>
            )}
          </div>

			<div className="rounded-lg border border-slate-200 bg-white p-4 overflow-x-auto">
            <h2 className="text-lg font-semibold mb-3 text-slate-700">Raw Features (Debug)</h2>
            {loading ? (
              <div className="text-sm text-slate-600">Loading…</div>
            ) : !row ? (
              <div className="text-sm text-slate-600">No data.</div>
            ) : (
              <table className="min-w-full text-sm">
                <tbody>
                  {Object.keys(row)
                    .sort()
                    .map((k) => (
                      <tr key={k} className="hover:bg-indigo-50/40">
                        <td className="px-3 py-2 whitespace-nowrap border-b border-slate-100 font-medium text-slate-600">
                          {k}
                        </td>
                        <td className="px-3 py-2 border-b border-slate-100">
                          {String(row[k] ?? "")}
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
        </>
        )}
    </div>
  );
}


