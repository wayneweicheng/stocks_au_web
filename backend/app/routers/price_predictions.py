from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Dict, Any
from datetime import date, datetime
from app.routers.auth import verify_credentials
from app.services.gex_data_service import GEXDataService
from app.services.prompt_template_service import PromptTemplateService
from app.services.llm_prediction_service import LLMPredictionService
from app.services.prediction_cache_service import PredictionCacheService
from app.services.signal_strength_parser import SignalStrengthParser
from app.services.signal_strength_db_service import SignalStrengthDBService
import logging

router = APIRouter(prefix="/api", tags=["price-predictions"])
logger = logging.getLogger("app.price_predictions")


def _build_price_prediction_prompt(
    base_code: str,
    observation_date: date,
    gex_service: GEXDataService,
    template_service: PromptTemplateService,
) -> Dict[str, Any]:
    """Build the Market Flow price prediction prompt and return source metadata."""
    try:
        gex_rows = gex_service.get_recent_features(base_code, observation_date, days=30)
        if not gex_rows:
            raise HTTPException(
                status_code=404,
                detail=f"No GEX features found for {base_code} on or before {observation_date}"
            )

        latest_row = gex_rows[-1]
        latest_date_value = latest_row.get('ObservationDate')

        if isinstance(latest_date_value, str):
            latest_date = datetime.strptime(latest_date_value[:10], '%Y-%m-%d').date()
        elif hasattr(latest_date_value, 'date'):
            latest_date = latest_date_value.date()
        else:
            latest_date = latest_date_value

        if latest_date != observation_date:
            raise HTTPException(
                status_code=404,
                detail=f"No data available for {observation_date.isoformat()}. Latest available data is from {latest_date.isoformat()}"
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database query failed: {e}")
        raise HTTPException(status_code=503, detail="Database unavailable")

    recent_data = gex_service.format_as_json(gex_rows)

    option_rows = []
    try:
        option_rows = gex_service.get_option_trades(base_code, observation_date)
        option_trades_data = gex_service.format_option_trades_as_pipe_delimited(option_rows)
        logger.info(f"Retrieved {len(option_rows)} option trades for {base_code} on {observation_date}")
    except Exception as e:
        logger.warning(f"Failed to fetch option trades for {base_code}: {e}")
        option_trades_data = "Option trade data unavailable."

    bar_rows = []
    try:
        bar_rows = gex_service.get_price_bars_30m(base_code, observation_date)
        price_bars_data = gex_service.format_price_bars_as_pipe_delimited(bar_rows)
        logger.info(f"Retrieved {len(bar_rows)} 30M bars for {base_code}")
    except Exception as e:
        logger.warning(f"Failed to fetch 30M price bars for {base_code}: {e}")
        price_bars_data = "30-minute bar data unavailable."

    option_oi_rows = []
    try:
        option_oi_rows = gex_service.get_option_oi_changes(base_code, observation_date)
        option_oi_data = gex_service.format_option_oi_changes_as_pipe_delimited(option_oi_rows, max_rows=50)
        logger.info(f"Retrieved {len(option_oi_rows)} option OI changes for {base_code}")
    except Exception as e:
        logger.warning(f"Failed to fetch option OI changes for {base_code}: {e}")
        option_oi_data = "No option OI change data available."

    top_options_rows = []
    try:
        top_options_rows = gex_service.get_top_options_by_oi(base_code, observation_date, limit=50)
        top_options_oi_data = gex_service.format_top_options_by_oi_as_pipe_delimited(top_options_rows)
        logger.info(f"Retrieved {len(top_options_rows)} top options by OI for {base_code}")
    except Exception as e:
        logger.warning(f"Failed to fetch top options by OI for {base_code}: {e}")
        top_options_oi_data = "No option OI data available."

    try:
        template, used_fallback = template_service.get_template(base_code)
        prompt = template_service.inject_variables(
            template=template,
            recent_data=recent_data,
            stock_code=base_code,
            observation_date=observation_date.isoformat(),
            option_trades=option_trades_data,
            price_bars_30m=price_bars_data,
            option_oi_changes=option_oi_data,
            top_options_oi=top_options_oi_data,
        )
    except FileNotFoundError as e:
        logger.error(f"Template loading failed: {e}")
        raise HTTPException(status_code=500, detail="Prediction template not found")
    except Exception as e:
        logger.error(f"Template processing failed: {e}")
        raise HTTPException(status_code=500, detail="Template processing error")

    template_file = f"{base_code}.md" if not used_fallback else "SPXW.md"

    return {
        "prompt": prompt,
        "used_fallback": used_fallback,
        "template_file": template_file,
        "template_path": str(template_service.template_dir / template_file),
        "prompt_length": len(prompt),
        "estimated_tokens": len(prompt) // 4,
        "has_option_trades": "no large option trades" not in option_trades_data.lower(),
        "has_price_bars_30m": "30-minute bar data unavailable" not in price_bars_data.lower(),
        "has_option_oi": "no option oi" not in option_oi_data.lower(),
        "database_results": {
            "gex_feature_rows": len(gex_rows),
            "option_trade_rows": len(option_rows),
            "price_bar_30m_rows": len(bar_rows),
            "option_oi_change_rows": len(option_oi_rows),
            "top_options_by_oi_rows": len(top_options_rows),
        },
    }


@router.get("/price-prediction")
def get_price_prediction(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SPXW", min_length=1, description="Stock code, e.g. BAC, NVDA.US"),
    regenerate: bool = Query(False, description="Force regeneration even if cached file exists"),
    model: str = Query("google/gemini-2.5-flash", description="LLM model to use for generation"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns price action prediction markdown content.
    Checks cache first, generates via LLM if needed.

    Args:
        observation_date: Observation date for prediction
        stock_code: Stock code (with or without .US suffix)
        regenerate: Force regeneration bypassing cache
        model: LLM model name (e.g., qwen/qwen3-30b-a3b, openai/gpt-5-mini)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - prediction_markdown: Markdown content
        - cached: Whether result was from cache
        - cache_file: Cache filename
        - observation_date: Observation date string
        - stock_code: Normalized stock code
        - token_usage: LLM token usage (if generated)
        - generated_at: ISO timestamp
    """
    try:
        # Initialize services
        cache_service = PredictionCacheService()
        gex_service = GEXDataService()
        template_service = PromptTemplateService()
        llm_service = LLMPredictionService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Price prediction request for {base_code} on {observation_date} (regenerate={regenerate})")

        # Check cache if not regenerating
        cached_prediction = None
        if not regenerate:
            cached_prediction = cache_service.get_cached_prediction(base_code, observation_date)

        if cached_prediction is not None:
            # On cache hit, extract and persist signal strength and ranges as needed (no extra LLM call)
            try:
                db_service = SignalStrengthDBService()
                signal_strength = SignalStrengthParser.extract_signal_strength(cached_prediction)
                ranges = SignalStrengthParser.extract_trade_ranges(cached_prediction)
                if signal_strength:
                    db_service.upsert_signal_strength(
                        stock_code=base_code,
                        observation_date=observation_date,
                        signal_strength_level=signal_strength,
                        source_type="GEX",
                        buy_dip_range=ranges.get("buy_dip_range"),
                        sell_rip_range=ranges.get("sell_rip_range"),
                    )
            except Exception as e:
                logger.warning(f"Cache extraction/upsert failed for {base_code} on {observation_date}: {e}")

            # Return cached prediction
            logger.info(f"Returning cached prediction for {base_code}")
            return {
                "prediction_markdown": cached_prediction,
                "cached": True,
                "cache_file": cache_service.get_cache_filename(base_code, observation_date),
                "observation_date": observation_date.isoformat(),
                "stock_code": base_code,
                "token_usage": None,
                "generated_at": datetime.now().isoformat()
            }

        # Generate new prediction
        logger.info(f"Generating new prediction for {base_code}")

        # Steps 1-3: Query DB data, load saved markdown template, and inject data.
        prompt_info = _build_price_prediction_prompt(
            base_code=base_code,
            observation_date=observation_date,
            gex_service=gex_service,
            template_service=template_service,
        )
        prompt = prompt_info["prompt"]

        # Step 4: Generate prediction via LLM
        try:
            llm_result = llm_service.generate_prediction(
                prompt=prompt,
                stock_code=base_code,
                observation_date=observation_date.isoformat(),
                model=model
            )
            prediction_text = llm_result["prediction_text"]
            token_usage = llm_result["token_usage"]
        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise HTTPException(status_code=500, detail="LLM service unavailable, please try again")

        # Step 5: Save to cache
        try:
            cache_service.save_prediction(base_code, observation_date, prediction_text)
        except Exception as e:
            logger.error(f"Cache save failed: {e}")
            # Don't fail the request if cache save fails, just log it

        # Step 6: Extract and save signal strength and trade ranges to database
        signal_strength = None
        try:
            logger.info(f"Attempting to extract signal strength from prediction (length: {len(prediction_text)} chars)")
            signal_strength = SignalStrengthParser.extract_signal_strength(prediction_text)
            ranges = SignalStrengthParser.extract_trade_ranges(prediction_text)

            if signal_strength:
                logger.info(f"[OK] Extracted signal strength: {signal_strength} for {base_code}")
                db_service = SignalStrengthDBService()

                logger.info(f"Attempting to save signal strength/ranges to database: {base_code} on {observation_date} -> {signal_strength}")
                success = db_service.upsert_signal_strength(
                    stock_code=base_code,
                    observation_date=observation_date,
                    signal_strength_level=signal_strength,
                    source_type="GEX",
                    buy_dip_range=ranges.get("buy_dip_range"),
                    sell_rip_range=ranges.get("sell_rip_range"),
                )

                if success:
                    logger.info(f"[OK] Successfully saved signal strength/ranges: {base_code} -> {signal_strength}")
                else:
                    logger.error(f"[FAIL] Database upsert returned False for {base_code}")
            else:
                logger.warning(f"[WARN] No signal strength extracted from LLM output for {base_code}")
                # Log last 500 chars of prediction for debugging
                logger.debug(f"Last 500 chars of prediction: {prediction_text[-500:]}")
        except Exception as e:
            logger.error(f"[FAIL] Signal strength extraction/save failed for {base_code}: {e}", exc_info=True)
            # Don't fail the request if signal strength save fails

        # Return generated prediction
        response_data = {
            "prediction_markdown": prediction_text,
            "cached": False,
            "cache_file": cache_service.get_cache_filename(base_code, observation_date),
            "observation_date": observation_date.isoformat(),
            "stock_code": base_code,
            "token_usage": token_usage,
            "generated_at": datetime.now().isoformat(),
            "signal_strength": signal_strength,  # Include extracted signal strength
            "prompt": prompt,
            "prompt_metadata": {
                "template_file": prompt_info["template_file"],
                "template_path": prompt_info["template_path"],
                "used_fallback": prompt_info["used_fallback"],
                "prompt_length": prompt_info["prompt_length"],
                "estimated_tokens": prompt_info["estimated_tokens"],
                "has_option_trades": prompt_info["has_option_trades"],
                "has_price_bars_30m": prompt_info["has_price_bars_30m"],
                "has_option_oi": prompt_info["has_option_oi"],
                "database_results": prompt_info["database_results"],
            }
        }

        # Add warning if fallback template was used
        if prompt_info["used_fallback"]:
            response_data["warning"] = f"No learned pattern available for {base_code}. Using SPXW fallback template."

        return response_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in price prediction endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/price-prediction-prompt")
def get_price_prediction_prompt(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SPXW", min_length=1, description="Stock code, e.g. BAC, NVDA.US"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns the LLM prompt text (template + injected data) without generating prediction.

    Args:
        observation_date: Observation date for prompt
        stock_code: Stock code (with or without .US suffix)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - prompt: Full prompt text with template and data
        - stock_code: Normalized stock code
        - observation_date: Observation date string
        - used_fallback: Whether SPXW fallback template was used
        - template_file: Template filename used
        - prompt_length: Character count for monitoring
    """
    try:
        # Initialize services
        cache_service = PredictionCacheService()
        gex_service = GEXDataService()
        template_service = PromptTemplateService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Prompt request for {base_code} on {observation_date}")

        prompt_info = _build_price_prediction_prompt(
            base_code=base_code,
            observation_date=observation_date,
            gex_service=gex_service,
            template_service=template_service,
        )

        return {
            "prompt": prompt_info["prompt"],
            "stock_code": base_code,
            "observation_date": observation_date.isoformat(),
            "used_fallback": prompt_info["used_fallback"],
            "template_file": prompt_info["template_file"],
            "template_path": prompt_info["template_path"],
            "prompt_length": prompt_info["prompt_length"],
            "estimated_tokens": prompt_info["estimated_tokens"],
            "has_option_trades": prompt_info["has_option_trades"],
            "has_price_bars_30m": prompt_info["has_price_bars_30m"],
            "has_option_oi": prompt_info["has_option_oi"],
            "database_results": prompt_info["database_results"],
            "generated_at": datetime.now().isoformat()
        }

        # Query GEX features data
        try:
            gex_rows = gex_service.get_recent_features(base_code, observation_date, days=30)
            if not gex_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No GEX features found for {base_code} on or before {observation_date}"
                )

            # Validate data exists for requested date
            latest_row = gex_rows[-1]
            latest_date_value = latest_row.get('ObservationDate')

            if isinstance(latest_date_value, str):
                latest_date = datetime.strptime(latest_date_value[:10], '%Y-%m-%d').date()
            elif hasattr(latest_date_value, 'date'):
                latest_date = latest_date_value.date()
            else:
                latest_date = latest_date_value

            if latest_date != observation_date:
                raise HTTPException(
                    status_code=404,
                    detail=f"No data available for {observation_date.isoformat()}. Latest available data is from {latest_date.isoformat()}"
                )

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Format data as JSON
        recent_data = gex_service.format_as_json(gex_rows)

        # Fetch and format option trades
        try:
            option_rows = gex_service.get_option_trades(base_code, observation_date)
            option_trades_data = gex_service.format_option_trades_as_pipe_delimited(option_rows)
            logger.info(f"Retrieved {len(option_rows)} option trades for {base_code} on {observation_date}")
        except Exception as e:
            logger.warning(f"Failed to fetch option trades for {base_code}: {e}")
            option_trades_data = "Option trade data unavailable."

        # Fetch and format 30-minute price bars
        try:
            bar_rows = gex_service.get_price_bars_30m(base_code, observation_date)
            price_bars_data = gex_service.format_price_bars_as_pipe_delimited(bar_rows)
            logger.info(f"Retrieved {len(bar_rows)} 30M bars for {base_code}")
        except Exception as e:
            logger.warning(f"Failed to fetch 30M price bars for {base_code}: {e}")
            price_bars_data = "30-minute bar data unavailable."

        # Fetch and format option OI changes (top 50 by absolute change)
        try:
            option_oi_rows = gex_service.get_option_oi_changes(base_code, observation_date)
            option_oi_data = gex_service.format_option_oi_changes_as_pipe_delimited(option_oi_rows, max_rows=50)
            logger.info(f"Retrieved {len(option_oi_rows)} option OI changes for {base_code}")
        except Exception as e:
            logger.warning(f"Failed to fetch option OI changes for {base_code}: {e}")
            option_oi_data = "No option OI change data available."

        # Fetch and format top 50 options by current open interest
        try:
            top_options_rows = gex_service.get_top_options_by_oi(base_code, observation_date, limit=50)
            top_options_oi_data = gex_service.format_top_options_by_oi_as_pipe_delimited(top_options_rows)
            logger.info(f"Retrieved {len(top_options_rows)} top options by OI for {base_code}")
        except Exception as e:
            logger.warning(f"Failed to fetch top options by OI for {base_code}: {e}")
            top_options_oi_data = "No option OI data available."

        # Load and inject template
        try:
            template, used_fallback = template_service.get_template(base_code)
            prompt = template_service.inject_variables(
                template=template,
                recent_data=recent_data,
                stock_code=base_code,
                observation_date=observation_date.isoformat(),
                option_trades=option_trades_data,
                price_bars_30m=price_bars_data,
                option_oi_changes=option_oi_data,
                top_options_oi=top_options_oi_data,
            )
        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Prediction template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Return prompt
        template_file = f"{base_code}.md" if not used_fallback else "SPXW.md"

        # Estimate token count (rough estimate: 1 token ≈ 4 characters)
        estimated_tokens = len(prompt) // 4

        # Check if new data sections are included
        has_option_trades = "no large option trades" not in option_trades_data.lower()
        has_price_bars = "30-minute bar data unavailable" not in price_bars_data.lower()
        has_option_oi = "no option oi" not in option_oi_data.lower()

        return {
            "prompt": prompt,
            "stock_code": base_code,
            "observation_date": observation_date.isoformat(),
            "used_fallback": used_fallback,
            "template_file": template_file,
            "prompt_length": len(prompt),
            "estimated_tokens": estimated_tokens,
            "has_option_trades": has_option_trades,
            "has_price_bars_30m": has_price_bars,
            "has_option_oi": has_option_oi,
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
