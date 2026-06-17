import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, Any, Tuple, List
from datetime import date, datetime
from decimal import Decimal
import re

SKILL_ROOT = Path(r"C:\Repo\midas-touch\ASX-spec-analyzer")
SKILL_TEMPLATE_PATH = SKILL_ROOT / "assets" / "report_template.md"
SKILL_RUBRIC_PATH = SKILL_ROOT / "references" / "report-rubric.md"
SKILL_ROUNDTRIP_SCRIPT = SKILL_ROOT / "scripts" / "llm_api_roundtrip.py"
SKILL_RAW_DRILLDOWN_SCRIPT = SKILL_ROOT / "scripts" / "raw_drilldown.py"


REPORT_TEMPLATE = """# {stock_code} Analysis (as at {observation_date})

Date anchor applied:
- As-at input date: {observation_date}
- Effective trade date (latest trading day on or before as-at): {effective_trade_date}
- Broker cutoff candidate (T+3): {broker_cutoff}
- Broker effective date used: {broker_effective_date}

## 1. Executive Summary
[Provide 2-3 paragraph executive summary covering key fundamentals, recent newsflow, technical position, and broker activity]

## 2. Catalyst Countdown
[List upcoming catalysts in bullet points, organized by timeframe:]
- **Next 30 days:**
- **Next 90 days:**
- **Next 180 days:**

## 3. Technical Structure
[Analyze technical setup in bullet points:]
- Current price and trend
- Support/resistance levels
- Volume and momentum
- Technical setup assessment

## 4. Capital & Survival Assessment
[Assess financial position:]
- Cash position and runway
- Recent capital raises
- Burn rate assessment
- Survival risk

## 5. Broker Activity
[Summarize broker flow:]
- Accumulation/distribution signals
- Top buyers and sellers
- Institutional vs retail flow
- Broker concentration

## 6. Red Flags & Risks
[List key risks and concerns]

## 7. Asymmetry Matrix
[Discuss risk/reward asymmetry:]
- Upside scenarios and probability
- Downside scenarios and probability
- Expected value assessment

## 8. Proper Reasoning
[Detailed analysis tying together all aspects]

## 9. Final Rating & Confidence Score
Aspect Scores:
- Fundamental: [score]/10
- Newsflow/Catalyst: [score]/10
- Technical: [score]/10
- Broker: [score]/10

Weighted Score Calculation:
- Formula: 0.20*Fundamental + 0.30*Newsflow + 0.20*Technical + 0.30*Broker
- Substitution: 0.20*[fundamental] + 0.30*[newsflow] + 0.20*[technical] + 0.30*[broker]
- Total: [weighted score]/10

Rating: [rating]
Confidence Score: [confidence]%
"""


def _load_skill_file(path: Path) -> str:
    try:
        if path.exists():
            return path.read_text(encoding="utf-8")
    except OSError:
        return ""
    return ""


def _render_template(template: str, replacements: Dict[str, str]) -> str:
    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
    return rendered


def _json_default(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def _parse_roundtrip_stdout(stdout: str) -> Dict[str, Any]:
    text = (stdout or "").strip()
    if not text:
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    for line in reversed(text.splitlines()):
        candidate = line.strip()
        if not candidate:
            continue
        if not candidate.startswith("{"):
            continue
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue

    match = re.search(r"(\{.*\})\s*$", text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass
    return {}


def _collect_context_files(run_dir: Path) -> List[Path]:
    files = [
        SKILL_TEMPLATE_PATH,
        SKILL_RUBRIC_PATH,
        run_dir / "context_pack.json",
        run_dir / "announcement_compact.json",
        run_dir / "price_ta_compact.json",
        run_dir / "broker_compact.json",
        run_dir / "broker_digest.txt",
        run_dir / "liquidity_compact.json",
        run_dir / "verified_funding.json",
    ]
    return [path for path in files if path.exists()]


def _build_skill_report_writer_prompt(
    context_pack: Dict[str, Any],
    run_dir: Path,
    markdown_report_path: Path,
    json_report_path: Path,
    extra_context_files: List[Path] | None = None,
) -> str:
    metadata = context_pack.get("metadata", {})
    stock_code = metadata.get("stock_code") or context_pack.get("asx_market_code") or "UNKNOWN.AX"
    asx_base_code = metadata.get("stock_code_base") or context_pack.get("asx_base_code") or stock_code.replace(".AX", "")
    observation_date = metadata.get("observation_date") or context_pack.get("as_at_date_input") or ""

    extra_lines = ""
    if extra_context_files:
        extra_lines = "\nAdditional generated context files:\n" + "\n".join(
            f"- {path}" for path in extra_context_files
        )

    return f"""Generate the ASX-Spec-Analyzer production report.

Inputs:
- ASX_SPEC_ANALYZER_ROOT: {SKILL_ROOT}
- asx_market_code: {stock_code}
- asx_base_code: {asx_base_code}
- as_at_date_input: {observation_date}
- run_directory: {run_dir}
- context_pack: {run_dir / 'context_pack.json'}
- compact artifacts:
  - {run_dir / 'announcement_compact.json'}
  - {run_dir / 'price_ta_compact.json'}
  - {run_dir / 'broker_compact.json'}
  - {run_dir / 'broker_digest.txt'}
  - {run_dir / 'liquidity_compact.json'}
- report_template: {SKILL_TEMPLATE_PATH}
- report_rubric: {SKILL_RUBRIC_PATH}
- markdown_report_path: {markdown_report_path}
- json_report_path: {json_report_path}
{extra_lines}

Instructions:
- You are the report writer. Read the report rubric, template, context pack, and all compact artifacts from the current run directory only.
- Use the compact artifacts fully, but do not paste them back.
- If `verified_funding.json` is present, treat it as the preferred source of truth for cash, burn, runway, and post-period funding reconciliation.
- If compact funding/runway evidence appears internally inconsistent, use the provided drill-down context if present and prefer the bounded evidence over naive compact extrapolation.
- Do not anchor the capital/survival section on a weaker generic report when `verified_funding.json` or Appendix 5B-style evidence provides a clearer cash figure.
- Apply the deterministic aspect-score, weighted-score, rating, and confidence rules from the rubric.
- Preserve the template structure exactly.
- Always state broker data is T+3 and report the broker effective date used.
- If broker compact indicates transform was blocked or neutralized, explain that clearly instead of fabricating stronger broker conviction.
- Output only the final markdown report content, not JSON, not commentary, not tool notes.
- The final two lines must be exactly `Rating: ...` and `Confidence Score: ...%`.
"""


def _maybe_create_funding_drilldown(
    run_dir: Path,
    announcement_compact: Dict[str, Any],
) -> Path | None:
    funding = announcement_compact.get("funding") or {}
    notes = funding.get("notes") or []
    latest_cash = funding.get("latest_cash_balance_m")
    catalyst_events = announcement_compact.get("material_events") or []
    if not notes and not (isinstance(latest_cash, (int, float)) and latest_cash <= 10):
        return None

    candidate_id = funding.get("source_announcement_id")
    if not candidate_id:
        for item in catalyst_events:
            tags = item.get("tags") or []
            category = item.get("category")
            if category in {"appendix_5b", "quarterly", "capital_raise"} or any(
                tag in {"appendix_5b", "quarterly", "capital_raise"} for tag in tags
            ):
                candidate_id = item.get("announcement_id")
                if candidate_id:
                    break
    if not candidate_id:
        return None

    output_path = run_dir / "funding_drilldown.json"
    command = [
        sys.executable,
        str(SKILL_RAW_DRILLDOWN_SCRIPT),
        "--run-dir",
        str(run_dir),
        "--announcement-id",
        str(candidate_id),
        "--fields",
        "AnnDateTime,AnnDescr,AnnURL,AnnContent",
        "--max-rows",
        "1",
        "--max-chars",
        "2400",
    ]
    completed = subprocess.run(
        command,
        cwd=str(SKILL_ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0 or not (completed.stdout or "").strip():
        return None
    output_path.write_text(completed.stdout, encoding="utf-8")
    return output_path


def parse_report_scores(markdown: str) -> Dict[str, Any]:
    """Extract scores and rating from markdown report."""
    import re

    def extract_score_and_rating(aspect_name: str) -> tuple[float | None, str | None]:
        """Extract both score and rating (e.g., '70 (Bullish)' or '45 (Neutral)')."""
        pattern = rf'{aspect_name}:\s*(\d+(?:\.\d+)?)\s*\(([^)]+)\)'
        match = re.search(pattern, markdown)
        if match:
            return float(match.group(1)), match.group(2).strip()

        # Fallback to score only
        score_only = re.search(rf'{aspect_name}:\s*(\d+(?:\.\d+)?)', markdown)
        if score_only:
            score = float(score_only.group(1))
            # Infer rating from score
            if score >= 70:
                rating = "Bullish"
            elif score >= 40:
                rating = "Neutral"
            else:
                rating = "Bearish"
            return score, rating
        return None, None

    # Extract aspect scores and ratings
    fundamental_score, fundamental_rating = extract_score_and_rating('Fundamental')
    newsflow_score, newsflow_rating = extract_score_and_rating('Newsflow/Catalyst')
    technical_score, technical_rating = extract_score_and_rating('Technical')
    broker_score, broker_rating = extract_score_and_rating('Broker')

    # Prefer the deterministic weighted-score section when present.
    setup_mapping = re.search(r'^\s*-\s*Setup-state band mapping:\s*(\d+(?:\.\d+)?)\s*=>\s*(.+?)\s*$', markdown, re.MULTILINE)
    has_setup_mapping = setup_mapping is not None
    if setup_mapping:
        weighted_score_100 = float(setup_mapping.group(1))
        overall_rating = setup_mapping.group(2).strip()
    else:
        # Extract weighted score (convert from /10 to /100 scale)
        weighted = re.search(r'Total:\s*(\d+(?:\.\d+)?)/10', markdown)
        if weighted:
            weighted_score_10 = float(weighted.group(1))
            weighted_score_100 = weighted_score_10 * 10
        else:
            # Try arithmetic line from the deterministic section
            arithmetic = re.search(r'^\s*-\s*Arithmetic:\s*.*?=\s*(\d+(?:\.\d+)?)\s*$', markdown, re.MULTILINE)
            if arithmetic:
                weighted_score_100 = float(arithmetic.group(1))
            else:
                # Try to find just the number
                weighted_alt = re.search(r'Total:\s*(\d+(?:\.\d+)?)', markdown)
                if weighted_alt:
                    weighted_score_100 = float(weighted_alt.group(1))
                else:
                    weighted_score_100 = 50.0

        # Determine overall rating from weighted score
        if weighted_score_100 >= 70:
            overall_rating = "Bullish"
        elif weighted_score_100 >= 40:
            overall_rating = "Neutral"
        else:
            overall_rating = "Bearish"
    # Extract deterministic recommendation mapping if present.
    deterministic_match = re.search(
        r'^\s*-\s*Deterministic recommendation mapping:\s*.+?=>\s*(.+?)\s*$',
        markdown,
        re.MULTILINE,
    )
    if deterministic_match and not has_setup_mapping:
        overall_rating = deterministic_match.group(1).strip()

    # Extract final rating line only when it begins a line, to avoid matching
    # inline labels like "Broker Rating:".
    rating_match = re.search(r'^\s*Rating:\s*(.+?)\s*$', markdown, re.MULTILINE)
    if rating_match and not has_setup_mapping:
        overall_rating = rating_match.group(1).strip()

    # Extract confidence
    confidence = re.search(r'Confidence Score:\s*(\d+)', markdown)

    return {
        "overall_score": int(round(weighted_score_100)),
        "overall_rating": overall_rating,
        "fundamental_score": int(round(fundamental_score)) if fundamental_score is not None else 50,
        "fundamental_rating": fundamental_rating or "Neutral",
        "newsflow_score": int(round(newsflow_score)) if newsflow_score is not None else 50,
        "newsflow_rating": newsflow_rating or "Neutral",
        "technical_score": int(round(technical_score)) if technical_score is not None else 50,
        "technical_rating": technical_rating or "Neutral",
        "broker_score": int(round(broker_score)) if broker_score is not None else 50,
        "broker_rating": broker_rating or "Neutral",
        "confidence": int(confidence.group(1)) if confidence else 50
    }


async def generate_report(
    run_directory: str,
    context_pack: Dict[str, Any],
    announcement_compact: Dict[str, Any],
    price_ta_compact: Dict[str, Any],
    broker_compact: Dict[str, Any],
    liquidity_compact: Dict[str, Any],
    verified_funding: Dict[str, Any],
    model: str = "deepseek/deepseek-v4-flash"
) -> Tuple[str, Dict[str, Any], int, float]:
    """
    Generate stock analysis report.

    Returns:
        - markdown_report: Full markdown report
        - report_json: Structured data extracted from report
        - tokens_used: LLM tokens consumed
        - processing_time: Time taken in seconds
    """
    start_time = time.time()
    run_dir = Path(run_directory)
    run_dir.mkdir(parents=True, exist_ok=True)

    prompt_file = run_dir / "llm_prompt_final.txt"
    markdown_report_path = run_dir / "final_report.md"
    json_report_path = run_dir / "final_report.json"
    if not markdown_report_path.exists():
        markdown_report_path.write_text("", encoding="utf-8")
    if not json_report_path.exists():
        json_report_path.write_text("", encoding="utf-8")

    verified_funding_path = run_dir / "verified_funding.json"
    if verified_funding and not verified_funding_path.exists():
        verified_funding_path.write_text(json.dumps(verified_funding, indent=2, default=_json_default), encoding="utf-8")
    funding_drilldown_path = _maybe_create_funding_drilldown(run_dir, announcement_compact)
    extra_context_files = [path for path in [verified_funding_path if verified_funding_path.exists() else None, funding_drilldown_path] if path]
    prompt = _build_skill_report_writer_prompt(
        context_pack=context_pack,
        run_dir=run_dir,
        markdown_report_path=markdown_report_path,
        json_report_path=json_report_path,
        extra_context_files=extra_context_files,
    )
    prompt_file.write_text(prompt, encoding="utf-8")

    context_files = _collect_context_files(run_dir) + extra_context_files
    raw_files = [path for path in run_dir.glob("*.json") if path.name not in {
        "context_pack.json",
        "announcement_compact.json",
        "price_ta_compact.json",
        "broker_compact.json",
        "liquidity_compact.json",
        "funding_drilldown.json",
    }]
    excluded_files_raw = ",".join(str(path) for path in raw_files)

    command = [
        sys.executable,
        str(SKILL_ROUNDTRIP_SCRIPT),
        "--output-dir",
        str(run_dir),
        "--provider",
        "openrouter",
        "--api-key-env",
        "OPENROUTER_STANDARD_API_KEY",
        "--stage",
        "final_report",
        "--model",
        model,
        "--prompt-file",
        str(prompt_file),
        "--response-file",
        str(markdown_report_path),
        "--context-files",
        ",".join(str(path) for path in context_files),
        "--excluded-files",
        excluded_files_raw,
    ]
    completed = subprocess.run(
        command,
        cwd=str(SKILL_ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout).strip() or "Unknown skill LLM roundtrip failure"
        raise RuntimeError(f"Skill report writer failed: {message}")

    roundtrip_meta = _parse_roundtrip_stdout(completed.stdout or "")
    markdown_report = markdown_report_path.read_text(encoding="utf-8")
    tokens_used = int(roundtrip_meta.get("provider_total_tokens") or 0)

    # Parse scores
    scores = parse_report_scores(markdown_report)

    # Build structured JSON
    report_json = {
        "metadata": context_pack["metadata"],
        "scores": scores,
        "data_summary": {
            "announcements": len(announcement_compact.get("material_events", [])),
            "catalysts": len((announcement_compact.get("catalysts") or {}).get("explicit", []))
            + len((announcement_compact.get("catalysts") or {}).get("implied", [])),
            "red_flags": len(announcement_compact.get("red_flags", [])),
            "technical_setup": price_ta_compact.get("technical_setup") or (price_ta_compact.get("trend") or {}).get("ta_setup_state"),
            "broker_score": ((broker_compact.get("rating") or {}).get("score_0_100")),
            "liquidity_score": liquidity_compact.get("liquidity_score") or (liquidity_compact.get("liquidity") or {}).get("liquidity_score"),
        },
        "generated_at": datetime.utcnow().isoformat(),
        "skill_run_directory": str(run_dir),
        "response_file": str(markdown_report_path),
        "prompt_file": str(prompt_file),
        "verified_funding": verified_funding,
        "funding_drilldown_file": str(funding_drilldown_path) if funding_drilldown_path else None,
        "roundtrip": roundtrip_meta,
    }
    json_report_path.write_text(json.dumps(report_json, indent=2, default=_json_default), encoding="utf-8")

    processing_time = time.time() - start_time

    return markdown_report, report_json, tokens_used, processing_time
