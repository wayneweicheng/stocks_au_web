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

router = APIRouter(prefix="/api", tags=["option-insights"])
logger = logging.getLogger("app.option_insights")


@router.get("/option-insight-prediction")
def get_option_insight_prediction(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SLV", min_length=1, description="Stock code, e.g. SLV, NVDA.US"),
    regenerate: bool = Query(False, description="Force regeneration even if cached file exists"),
    model: str = Query("google/gemini-2.5-flash", description="LLM model to use for generation"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns option insight prediction markdown content.
    Checks cache first (llm_output/us_option_insights), generates via LLM if needed.

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
        # Initialize services with option-specific cache directory
        cache_service = PredictionCacheService(cache_dir="llm_output/us_option_insights")
        gex_service = GEXDataService()
        llm_service = LLMPredictionService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Option insight request for {base_code} on {observation_date} (regenerate={regenerate})")

        # Check cache if not regenerating
        cached_prediction = None
        if not regenerate:
            cached_prediction = cache_service.get_cached_prediction(base_code, observation_date)

        if cached_prediction is not None:
            # On cache hit, extract and persist signal strength as needed
            try:
                db_service = SignalStrengthDBService()
                signal_strength = SignalStrengthParser.extract_signal_strength(cached_prediction)
                ranges = SignalStrengthParser.extract_trade_ranges(cached_prediction)
                if signal_strength:
                    db_service.upsert_signal_strength(
                        stock_code=base_code,
                        observation_date=observation_date,
                        signal_strength_level=signal_strength,
                        source_type="OPTION",
                        buy_dip_range=ranges.get("buy_dip_range"),
                        sell_rip_range=ranges.get("sell_rip_range"),
                    )
            except Exception as e:
                logger.warning(f"Cache extraction/upsert failed for {base_code} on {observation_date}: {e}")

            # Return cached prediction
            logger.info(f"Returning cached option insight for {base_code}")
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
        logger.info(f"Generating new option insight for {base_code}")

        # Step 1a: Query option OI changes data
        try:
            option_oi_rows = gex_service.get_option_oi_changes(base_code, observation_date)
            if not option_oi_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No option OI change data found for {base_code} on {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Step 1b: Query top 50 options by open interest
        try:
            top_options_rows = gex_service.get_top_options_by_oi(base_code, observation_date, limit=50)
            logger.info(f"Retrieved {len(top_options_rows)} top options by OI for {base_code}")
        except Exception as e:
            logger.error(f"Failed to query top options by OI: {e}")
            top_options_rows = []

        # Step 2: Format data as pipe-delimited
        option_oi_data = gex_service.format_option_oi_changes_as_pipe_delimited(option_oi_rows)
        top_options_data = gex_service.format_top_options_by_oi_as_pipe_delimited(top_options_rows)

        # Step 3: Load option insights template
        try:
            # Use the generic option insights template
            template_path = "signal_pattern/option_insights_template.md"
            from pathlib import Path
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Option insights template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")
            logger.info(f"Loaded option insights template ({len(template)} characters)")

            # Replace placeholders in template
            prompt = template.replace("{{ stock_code }}", base_code)
            prompt = prompt.replace("{{ option_oi_data }}", option_oi_data)
            prompt = prompt.replace("{{ top_options_oi }}", top_options_data)
            prompt = prompt.replace("{{stock_code}}", base_code)
            prompt = prompt.replace("{{option_oi_data}}", option_oi_data)
            prompt = prompt.replace("{{top_options_oi}}", top_options_data)

            # Prepend option-specific signal strength system prompt (without GEX-specific instructions)
            template_service = PromptTemplateService()
            prompt = template_service.OPTION_SIGNAL_STRENGTH_PROMPT + prompt

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Option insights template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

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
            # Don't fail the request if cache save fails

        # Step 6: Extract and save signal strength to database with source_type=OPTION
        signal_strength = None
        try:
            logger.info(f"Attempting to extract signal strength from option insight (length: {len(prediction_text)} chars)")
            signal_strength = SignalStrengthParser.extract_signal_strength(prediction_text)
            ranges = SignalStrengthParser.extract_trade_ranges(prediction_text)

            if signal_strength:
                logger.info(f"✓ Extracted signal strength: {signal_strength} for {base_code}")
                db_service = SignalStrengthDBService()

                logger.info(f"Attempting to save signal strength to database: {base_code} on {observation_date} -> {signal_strength} (OPTION)")
                success = db_service.upsert_signal_strength(
                    stock_code=base_code,
                    observation_date=observation_date,
                    signal_strength_level=signal_strength,
                    source_type="OPTION",
                    buy_dip_range=ranges.get("buy_dip_range"),
                    sell_rip_range=ranges.get("sell_rip_range"),
                )

                if success:
                    logger.info(f"✓ Successfully saved signal strength: {base_code} -> {signal_strength} (OPTION)")
                else:
                    logger.error(f"✗ Database upsert returned False for {base_code}")
            else:
                logger.warning(f"✗ No signal strength extracted from LLM output for {base_code}")
                logger.debug(f"Last 500 chars of prediction: {prediction_text[-500:]}")
        except Exception as e:
            logger.error(f"✗ Signal strength extraction/save failed for {base_code}: {e}", exc_info=True)
            # Don't fail the request if signal strength save fails

        # Return generated prediction
        return {
            "prediction_markdown": prediction_text,
            "cached": False,
            "cache_file": cache_service.get_cache_filename(base_code, observation_date),
            "observation_date": observation_date.isoformat(),
            "stock_code": base_code,
            "token_usage": token_usage,
            "generated_at": datetime.now().isoformat(),
            "signal_strength": signal_strength
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in option insight endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/option-insight-prompt")
def get_option_insight_prompt(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SLV", min_length=1, description="Stock code, e.g. SLV, NVDA.US"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns the LLM prompt text for option insights without generating prediction.

    Args:
        observation_date: Observation date for prompt
        stock_code: Stock code (with or without .US suffix)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - prompt: Full prompt text with template and data
        - stock_code: Normalized stock code
        - observation_date: Observation date string
        - prompt_length: Character count
        - estimated_tokens: Rough token estimate
    """
    try:
        # Initialize services
        cache_service = PredictionCacheService(cache_dir="llm_output/us_option_insights")
        gex_service = GEXDataService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Option insight prompt request for {base_code} on {observation_date}")

        # Query option OI changes data
        try:
            option_oi_rows = gex_service.get_option_oi_changes(base_code, observation_date)
            if not option_oi_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No option OI change data found for {base_code} on {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Query top 50 options by open interest
        try:
            top_options_rows = gex_service.get_top_options_by_oi(base_code, observation_date, limit=50)
            logger.info(f"Retrieved {len(top_options_rows)} top options by OI for {base_code}")
        except Exception as e:
            logger.error(f"Failed to query top options by OI: {e}")
            top_options_rows = []

        # Format data as pipe-delimited
        option_oi_data = gex_service.format_option_oi_changes_as_pipe_delimited(option_oi_rows)
        top_options_data = gex_service.format_top_options_by_oi_as_pipe_delimited(top_options_rows)

        # Query option trades data to validate availability
        try:
            option_trades_rows = gex_service.get_option_trades(base_code, observation_date)
            option_trades_data = gex_service.format_option_trades_as_pipe_delimited(option_trades_rows)
            logger.info(f"Retrieved {len(option_trades_rows)} option trades for {base_code} on {observation_date}")
        except Exception as e:
            logger.warning(f"Failed to fetch option trades for {base_code}: {e}")
            option_trades_data = "No large option trades (size > 300) recorded for this date."

        # Load and inject template
        try:
            template_path = "signal_pattern/option_insights_template.md"
            from pathlib import Path
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Option insights template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")

            # Replace placeholders
            prompt = template.replace("{{ stock_code }}", base_code)
            prompt = prompt.replace("{{ option_oi_data }}", option_oi_data)
            prompt = prompt.replace("{{ top_options_oi }}", top_options_data)
            prompt = prompt.replace("{{stock_code}}", base_code)
            prompt = prompt.replace("{{option_oi_data}}", option_oi_data)
            prompt = prompt.replace("{{top_options_oi}}", top_options_data)

            # Prepend option-specific signal strength system prompt (without GEX-specific instructions)
            template_service = PromptTemplateService()
            prompt = template_service.OPTION_SIGNAL_STRENGTH_PROMPT + prompt

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Option insights template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Estimate token count (rough estimate: 1 token ≈ 4 characters)
        estimated_tokens = len(prompt) // 4

        # Check if option trades data is available
        has_option_trades = "no large option trades" not in option_trades_data.lower()

        return {
            "prompt": prompt,
            "stock_code": base_code,
            "observation_date": observation_date.isoformat(),
            "prompt_length": len(prompt),
            "estimated_tokens": estimated_tokens,
            "has_option_trades": has_option_trades,
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in option insight prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/option-trades-insight-prediction")
def get_option_trades_insight_prediction(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SLV", min_length=1, description="Stock code, e.g. SLV, NVDA.US"),
    regenerate: bool = Query(False, description="Force regeneration even if cached file exists"),
    model: str = Query("google/gemini-2.5-flash", description="LLM model to use for generation"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns option trades insight prediction markdown content based on option trades data only (no OI).
    Checks cache first (llm_output/us_option_trades_insights), generates via LLM if needed.

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
        - warning: Optional warning message if no option trades data found
    """
    try:
        # Initialize services with option trades specific cache directory
        cache_service = PredictionCacheService(cache_dir="llm_output/us_option_trades_insights")
        gex_service = GEXDataService()
        llm_service = LLMPredictionService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Option trades insight request for {base_code} on {observation_date} (regenerate={regenerate})")

        # Check cache if not regenerating
        cached_prediction = None
        if not regenerate:
            cached_prediction = cache_service.get_cached_prediction(base_code, observation_date)

        if cached_prediction is not None:
            # Return cached prediction
            logger.info(f"Returning cached option trades insight for {base_code}")
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
        logger.info(f"Generating new option trades insight for {base_code}")

        # Step 1: Query option trades data only (no OI data)
        try:
            option_trades_rows = gex_service.get_option_trades(base_code, observation_date)
            if not option_trades_rows:
                # Return a warning message instead of failing
                warning_msg = f"No option trades data (size > 300) found for {base_code} on {observation_date}"
                logger.warning(warning_msg)
                return {
                    "prediction_markdown": f"## No Option Trades Data Available\n\n{warning_msg}\n\nPlease check if option trades data exists for this stock and date.",
                    "cached": False,
                    "cache_file": cache_service.get_cache_filename(base_code, observation_date),
                    "observation_date": observation_date.isoformat(),
                    "stock_code": base_code,
                    "token_usage": None,
                    "generated_at": datetime.now().isoformat(),
                    "warning": warning_msg
                }
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Step 2: Format data as pipe-delimited
        option_trades_data = gex_service.format_option_trades_as_pipe_delimited(option_trades_rows)

        # Step 2b: Query 5-minute price bars for context
        try:
            price_bars_5m_rows = gex_service.get_price_bars_5m(base_code, observation_date)
            price_bars_5m_data = gex_service.format_price_bars_as_pipe_delimited(price_bars_5m_rows)
        except Exception as e:
            logger.warning(f"Failed to fetch 5M price bars for {base_code} on {observation_date}: {e}")
            price_bars_5m_data = "No 5-minute bar data available for this date."

        # Step 3: Load option trades insights template
        try:
            # Use a separate template for option trades insights
            template_path = "signal_pattern/option_trades_insights_template.md"
            from pathlib import Path
            template_file = Path(template_path)

            if not template_file.exists():
                # Fallback to generic option insights template if trades-specific doesn't exist
                logger.warning(f"Option trades template not found at {template_path}, using option insights template")
                template_path = "signal_pattern/option_insights_template.md"
                template_file = Path(template_path)

                if not template_file.exists():
                    raise FileNotFoundError(f"Option insights template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")
            logger.info(f"Loaded option trades insights template ({len(template)} characters)")

            # Replace placeholders in template
            prompt = template.replace("{{ stock_code }}", base_code)
            prompt = prompt.replace("{{ option_trades_data }}", option_trades_data)
            prompt = prompt.replace("{{ price_bars_5m }}", price_bars_5m_data)
            prompt = prompt.replace("{{stock_code}}", base_code)
            prompt = prompt.replace("{{option_trades_data}}", option_trades_data)
            prompt = prompt.replace("{{price_bars_5m}}", price_bars_5m_data)
            # Remove OI-related placeholders since we don't use them
            prompt = prompt.replace("{{ option_oi_data }}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{ top_options_oi }}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{option_oi_data}}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{top_options_oi}}", "Not applicable for option trades analysis")

            # Don't add signal strength prompt for option trades (it's focused on trade flow, not signals)
            # Just use the template as is

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Option trades insights template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

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
            # Don't fail the request if cache save fails

        # Return generated prediction (no signal strength extraction for option trades)
        return {
            "prediction_markdown": prediction_text,
            "cached": False,
            "cache_file": cache_service.get_cache_filename(base_code, observation_date),
            "observation_date": observation_date.isoformat(),
            "stock_code": base_code,
            "token_usage": token_usage,
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in option trades insight endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/option-trades-insight-prompt")
def get_option_trades_insight_prompt(
    observation_date: date = Query(..., description="Observation date, e.g. 2025-12-11"),
    stock_code: str = Query("SLV", min_length=1, description="Stock code, e.g. SLV, NVDA.US"),
    username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
    """
    Returns the LLM prompt text for option trades insights without generating prediction.

    Args:
        observation_date: Observation date for prompt
        stock_code: Stock code (with or without .US suffix)
        username: Authenticated username (injected by dependency)

    Returns:
        Dictionary containing:
        - prompt: Full prompt text with template and data
        - stock_code: Normalized stock code
        - observation_date: Observation date string
        - prompt_length: Character count
        - estimated_tokens: Rough token estimate
    """
    try:
        # Initialize services
        cache_service = PredictionCacheService(cache_dir="llm_output/us_option_trades_insights")
        gex_service = GEXDataService()

        # Normalize stock code
        base_code = cache_service.normalize_stock_code(stock_code)

        logger.info(f"Option trades insight prompt request for {base_code} on {observation_date}")

        # Query option trades data
        try:
            option_trades_rows = gex_service.get_option_trades(base_code, observation_date)
            if not option_trades_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No option trades data (size > 300) found for {base_code} on {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Format data as pipe-delimited
        option_trades_data = gex_service.format_option_trades_as_pipe_delimited(option_trades_rows)

        # Query 5-minute price bars for context
        try:
            price_bars_5m_rows = gex_service.get_price_bars_5m(base_code, observation_date)
            price_bars_5m_data = gex_service.format_price_bars_as_pipe_delimited(price_bars_5m_rows)
        except Exception as e:
            logger.warning(f"Failed to fetch 5M price bars for {base_code} on {observation_date}: {e}")
            price_bars_5m_data = "No 5-minute bar data available for this date."

        # Load and inject template
        try:
            template_path = "signal_pattern/option_trades_insights_template.md"
            from pathlib import Path
            template_file = Path(template_path)

            if not template_file.exists():
                # Fallback to generic option insights template
                logger.warning(f"Option trades template not found at {template_path}, using option insights template")
                template_path = "signal_pattern/option_insights_template.md"
                template_file = Path(template_path)

                if not template_file.exists():
                    raise FileNotFoundError(f"Option insights template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")

            # Replace placeholders
            prompt = template.replace("{{ stock_code }}", base_code)
            prompt = prompt.replace("{{ option_trades_data }}", option_trades_data)
            prompt = prompt.replace("{{ price_bars_5m }}", price_bars_5m_data)
            prompt = prompt.replace("{{stock_code}}", base_code)
            prompt = prompt.replace("{{option_trades_data}}", option_trades_data)
            prompt = prompt.replace("{{price_bars_5m}}", price_bars_5m_data)
            # Remove OI-related placeholders
            prompt = prompt.replace("{{ option_oi_data }}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{ top_options_oi }}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{option_oi_data}}", "Not applicable for option trades analysis")
            prompt = prompt.replace("{{top_options_oi}}", "Not applicable for option trades analysis")

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Option trades insights template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Estimate token count (rough estimate: 1 token ≈ 4 characters)
        estimated_tokens = len(prompt) // 4

        return {
            "prompt": prompt,
            "stock_code": base_code,
            "observation_date": observation_date.isoformat(),
            "prompt_length": len(prompt),
            "estimated_tokens": estimated_tokens,
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in option trades insight prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
