from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Dict, Any, Optional, List
from pydantic import BaseModel
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
from app.services.llm_prediction_service import LLMPredictionService
import logging
import re
from datetime import datetime
from pathlib import Path


router = APIRouter(prefix="/api", tags=["announcement-analysis"])
logger = logging.getLogger("app.announcement_analysis")

# Simple file cache
CACHE_DIR = Path("llm_output/announcement_analysis")
CACHE_DIR.mkdir(parents=True, exist_ok=True)


def _fetch_announcement_by_id(announcement_id: int) -> Dict[str, Any]:
	"""
	Load a single announcement row by ID.
	Returns a dict containing all DB columns for internal use.
	"""
	model = get_sql_model()
	sql = """
		SELECT TOP 1
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnRetriveDateTime,
			MarketSensitiveIndicator,
			AnnDescr,
			AnnContent
		FROM [StockData].[Announcement]
		WHERE AnnouncementID = ?
	"""
	rows = model.execute_read_query(sql, (announcement_id,)) or []
	if not rows:
		raise HTTPException(status_code=404, detail=f"Announcement {announcement_id} not found")
	return rows[0]


def _get_latest_research_link(stock_code: str) -> Optional[str]:
	"""
	Returns latest research link URL for a given stock code, if available.
	"""
	try:
		db = get_sql_model()
		sql = """
			SELECT TOP 1 Url
			FROM [Research].[ResearchLink]
			WHERE UPPER(StockCode) = UPPER(?)
			ORDER BY AddedAt DESC
		"""
		rows = db.execute_read_query(sql, (stock_code,)) or []
		return rows[0]["Url"] if rows and rows[0].get("Url") else None
	except Exception as e:
		logger.error("Failed to fetch latest research link for %s: %s", stock_code, e)
		return None


def _get_latest_research_markdown_from_db(stock_code: str, max_chars: int = 20000) -> Optional[str]:
	"""
	Read latest research report markdown content directly from database.
	Returns None if no report found.
	"""
	try:
		db = get_sql_model()
		sql = """
			SELECT TOP 1 Content
			FROM [Research].[ResearchLink]
			WHERE UPPER(StockCode) = UPPER(?)
			ORDER BY AddedAt DESC
		"""
		rows = db.execute_read_query(sql, (stock_code,)) or []
		if not rows:
			return None
		content = rows[0].get("Content")
		if not content or not isinstance(content, str):
			return None
		return content[:max_chars]
	except Exception as e:
		logger.error("Failed to fetch research content from DB for %s: %s", stock_code, e)
		raise HTTPException(status_code=500, detail="Failed to retrieve research report content from database")
	except Exception as e:
		logger.error("Unexpected error fetching research link %s: %s", url, e)
		raise HTTPException(status_code=500, detail="Unexpected error fetching research link content")


def _build_prompt(stock_code: str, research_text: Optional[str], announcement_markdown: str) -> str:
	"""
	Assemble the prompt per requested template.
	"""
	research_block = research_text or "(No research report content available)"
	template = (
		f"You are an experienced ASX Investor and critical analyst. The company {stock_code}'s latest research report is as follows:\n"
		f"{research_block}\n\n"
		f"Now given the latest announcement content as follows:\n"
		f"{announcement_markdown}\n\n"
		f"Please conduct a thorough multi-layered analysis covering ALL of the following sections:\n\n"
		f"## 1. Announcement Analysis\n"
		f"Analyze whether and how much bullish/bearish this announcement is, or if it is neutral. "
		f"Consider: major milestones, key environmental approvals, strategic partnerships that materially "
		f"improve company value, key uncertainty removal (bullish); failed exploration drilling, results "
		f"not commercially viable, potential legal disputes (bearish). Provide a clear rationale.\n\n"
		f"## 2. Devil's Advocate / Critic View\n"
		f"Now put on your critic hat. Even if the announcement appears positive on the surface, identify "
		f"potential hidden risks, red flags, or concerns that the market might latch onto. Consider:\n"
		f"- What could go wrong despite the headline being positive? What are the execution risks?\n"
		f"- Are there any vague or missing details that sophisticated investors would notice?\n"
		f"- If the stock price were to tank after this announcement, what would be the likely reason?\n"
		f"- For seemingly negative announcements, is there a silver lining the market might find?\n"
		f"Be fact-based and specific — do not invent concerns, but scrutinize what is actually stated "
		f"(and notably what is NOT stated) in the announcement.\n\n"
		f"## 3. Financial Health & Capital Raising Risk\n"
		f"Based on the research report and any financial data mentioned in the announcement, scrutinize:\n"
		f"- Cash position: How much cash does the company have? What is the estimated cash runway?\n"
		f"- Debt levels: Any concerning debt obligations, covenants, or upcoming maturities?\n"
		f"- Burn rate: Is the company burning cash at a rate that necessitates near-term funding?\n"
		f"- Capital raising risk: Assess the likelihood of an imminent capital raise (placement, rights issue, "
		f"SPP, convertible notes). If the company is pre-revenue or early-stage, this risk is elevated.\n"
		f"- If data is insufficient to assess, state that clearly rather than speculating.\n\n"
		f"## 4. Price Action Context & Market Positioning\n"
		f"Consider the recent price action context (from the research report if available):\n"
		f"- For a POSITIVE announcement: Has the stock already run up significantly in anticipation? "
		f"Is this a classic 'buy the rumour, sell the news' setup? Would smart money use this pop to exit?\n"
		f"- For a NEGATIVE announcement: Has the stock already been heavily sold off? Could this be the "
		f"final washout where all bad news is now priced in, creating a potential bottom?\n"
		f"- Is the market likely to react immediately, or is this a slow-burn catalyst?\n"
		f"- What would change the current market sentiment around this stock?\n\n"
		f"## 5. Final Verdict\n"
		f"Synthesize all sections above into a concise conclusion. End with a single verdict line in exactly this form:\n"
		f"Verdict: <Strongly Bullish|Mildly Bullish|Neutral|Mildly Bearish|Strongly Bearish> (Confidence: Low|Medium|High)\n"
	)
	return template


@router.get("/announcement/{announcement_id}")
def get_announcement_details(
	announcement_id: int,
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	"""
	Return announcement fields EXCEPT AnnContent (for display).
	"""
	try:
		row = _fetch_announcement_by_id(announcement_id)
		return {
			"AnnouncementID": row.get("AnnouncementID"),
			"ASXCode": row.get("ASXCode"),
			"AnnDateTime": row.get("AnnDateTime"),
			"AnnRetriveDateTime": row.get("AnnRetriveDateTime"),
			"MarketSensitiveIndicator": row.get("MarketSensitiveIndicator"),
			"AnnDescr": row.get("AnnDescr"),
			"has_content": bool(row.get("AnnContent")),
		}
	except HTTPException:
		raise
	except Exception as e:
		logger.error("Failed to load announcement %s: %s", announcement_id, e)
		raise HTTPException(status_code=500, detail="Failed to load announcement")


@router.get("/announcement-analysis-prompt")
def get_announcement_analysis_prompt(
	announcement_id: int = Query(..., description="AnnouncementID"),
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	"""
	Build and return the prompt text combining latest research report content (if available) and the announcement markdown content.
	"""
	try:
		row = _fetch_announcement_by_id(announcement_id)
		stock_code = (row.get("ASXCode") or "").strip().upper()
		announcement_markdown = row.get("AnnContent") or ""

		# Latest research report content from DB (if available)
		research_text: Optional[str] = _get_latest_research_markdown_from_db(stock_code) if stock_code else None

		prompt = _build_prompt(stock_code, research_text, announcement_markdown)
		has_research = research_text is not None and len(research_text) > 0

		return {
			"prompt": prompt,
			"stock_code": stock_code,
			"announcement_id": announcement_id,
			"generated_at": datetime.now().isoformat(),
			"prompt_length": len(prompt),
			"approx_tokens": len(prompt) // 4,
			"has_research_report": has_research,
		}
	except HTTPException:
		raise
	except Exception as e:
		logger.error("Failed to build announcement analysis prompt: %s", e)
		raise HTTPException(status_code=500, detail="Failed to build prompt")


def _sanitize_stock_code_for_filename(stock_code: str) -> str:
	"""Convert stock code like 'LIN.AX' to 'LIN_AX' for filename."""
	return re.sub(r"[^a-zA-Z0-9_]+", "_", stock_code).strip("_") or "UNKNOWN"


def _cache_filename(announcement_id: int, stock_code: str) -> Path:
	"""Generate cache filename: {announcement_id}_{stock_code}.md (e.g., 2399_LIN_AX.md)"""
	stock_part = _sanitize_stock_code_for_filename(stock_code)
	return CACHE_DIR / f"{announcement_id}_{stock_part}.md"


def _read_cache(announcement_id: int, stock_code: str) -> Optional[str]:
	try:
		path = _cache_filename(announcement_id, stock_code)
		if path.exists():
			return path.read_text(encoding="utf-8")
		return None
	except Exception as e:
		logger.info("Read cache failed (non-fatal) for %s: %s", announcement_id, e)
		return None


def _write_cache(announcement_id: int, stock_code: str, content: str) -> Optional[str]:
	try:
		path = _cache_filename(announcement_id, stock_code)
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(content, encoding="utf-8")
		return str(path)
	except Exception as e:
		logger.info("Write cache failed (non-fatal) for %s: %s", announcement_id, e)
		return None


class AnnouncementListItem(BaseModel):
	AnnouncementID: int
	ASXCode: str
	AnnDateTime: Optional[str] = None
	AnnRetriveDateTime: Optional[str] = None
	MarketSensitiveIndicator: Optional[int] = None
	AnnDescr: Optional[str] = None
	has_content: bool


class AnnouncementPage(BaseModel):
	items: List[AnnouncementListItem]
	total: int
	page: int
	page_size: int


@router.get("/announcements", response_model=AnnouncementPage)
def list_announcements(
	asx_code: str = Query(..., description="ASX code to filter announcements, e.g. PLS or PLS.AX"),
	page: int = Query(1, ge=1),
	page_size: int = Query(20, ge=1, le=100),
	username: str = Depends(verify_credentials),
) -> AnnouncementPage:
	"""
	List announcements for a specific ASX code ordered by AnnDateTime DESC, paginated.
	Accepts codes with or without '.AX' suffix (case-insensitive).
	"""
	try:
		model = get_sql_model()
		normalized = (asx_code or "").strip().upper()
		if normalized.endswith(".AX"):
			normalized = normalized[:-3]

		# Total count - check both with and without .AX suffix
		total_rows = model.execute_read_query(
			"""
			SELECT COUNT(*) AS total
			FROM [StockData].[Announcement]
			WHERE UPPER(ASXCode) = UPPER(?) OR UPPER(ASXCode) = UPPER(?)
			""",
			(normalized, normalized + ".AX"),
		) or []
		total = int(total_rows[0]["total"]) if total_rows and "total" in total_rows[0] else 0

		offset = (page - 1) * page_size
		rows = model.execute_read_query(
			"""
			SELECT
				AnnouncementID,
				ASXCode,
				CONVERT(varchar(19), AnnDateTime, 126) AS AnnDateTime,
				CONVERT(varchar(19), AnnRetriveDateTime, 126) AS AnnRetriveDateTime,
				MarketSensitiveIndicator,
				AnnDescr,
				CASE WHEN AnnContent IS NULL OR LEN(AnnContent) = 0 THEN 0 ELSE 1 END AS has_content
			FROM [StockData].[Announcement]
			WHERE UPPER(ASXCode) = UPPER(?) OR UPPER(ASXCode) = UPPER(?)
			ORDER BY AnnDateTime DESC
			OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
			""",
			(normalized, normalized + ".AX", offset, page_size),
		) or []

		# Coerce int->bool for has_content
		for r in rows:
			if "has_content" in r:
				r["has_content"] = bool(r["has_content"])

		return AnnouncementPage(items=rows, total=total, page=page, page_size=page_size)
	except Exception as e:
		logger.error("Failed to list announcements for %s: %s", asx_code, e)
		raise HTTPException(status_code=500, detail="Failed to list announcements")


@router.get("/announcement-analysis")
def get_announcement_analysis(
	announcement_id: int = Query(..., description="AnnouncementID"),
	regenerate: bool = Query(False, description="Force regeneration (no cache currently)"),
	model: str = Query("google/gemini-3-flash-preview", description="LLM model to use for generation"),
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	"""
	Generate LLM analysis for an announcement using the same model default as breakout-consolidation analysis.
	Cache files are stored as: {announcement_id}_{stock_code}.md (e.g., 2399_LIN_AX.md)
	"""
	try:
		# Fetch announcement to get stock_code (needed for cache filename)
		row = _fetch_announcement_by_id(announcement_id)
		stock_code = (row.get("ASXCode") or "").strip().upper()

		# Check cache first unless forcing regenerate
		if not regenerate:
			cached = _read_cache(announcement_id, stock_code)
			if cached is not None:
				cache_path = _cache_filename(announcement_id, stock_code)
				cached_at = datetime.fromtimestamp(cache_path.stat().st_mtime).isoformat() if cache_path.exists() else None
				return {
					"analysis_markdown": cached,
					"token_usage": None,
					"model_used": model,
					"generated_at": datetime.now().isoformat(),
					"announcement_id": announcement_id,
					"stock_code": stock_code,
					"cached": True,
					"cached_at": cached_at,
					"cache_file": str(cache_path),
				}

		# Prepare prompt
		announcement_markdown = row.get("AnnContent") or ""
		research_text: Optional[str] = _get_latest_research_markdown_from_db(stock_code) if stock_code else None

		prompt = _build_prompt(stock_code, research_text, announcement_markdown)

		# Invoke LLM
		llm_service = LLMPredictionService()
		result = llm_service.generate_prediction(
			prompt=prompt,
			stock_code=stock_code or "UNKNOWN",
			observation_date=datetime.now().date().isoformat(),
			model=model,
		)

		analysis_text = result.get("prediction_text", "")
		cache_path = _write_cache(announcement_id, stock_code, analysis_text)

		return {
			"analysis_markdown": analysis_text,
			"token_usage": result.get("token_usage"),
			"model_used": result.get("model_used", model),
			"generated_at": datetime.now().isoformat(),
			"announcement_id": announcement_id,
			"stock_code": stock_code,
			"cached": False,
			"cache_file": cache_path,
		}
	except HTTPException:
		raise
	except Exception as e:
		logger.error("Failed to generate announcement analysis: %s", e)
		raise HTTPException(status_code=500, detail="LLM service unavailable")


