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

        # Step 1: Query GEX features data
        try:
            gex_rows = gex_service.get_recent_features(base_code, observation_date, days=30)
            if not gex_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No GEX features found for {base_code} on or before {observation_date}"
                )

            # Validate that data exists for the requested date
            latest_row = gex_rows[-1]  # Last row is most recent (query orders ASC)
            latest_date_value = latest_row.get('ObservationDate')

            # Convert to date if needed
            if isinstance(latest_date_value, str):
                latest_date = datetime.strptime(latest_date_value[:10], '%Y-%m-%d').date()
            elif hasattr(latest_date_value, 'date'):
                latest_date = latest_date_value.date()
            else:
                latest_date = latest_date_value

            # Compare with requested date
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

        # Step 2: Format data as JSON
        recent_data = gex_service.format_as_json(gex_rows)

        # Step 3: Load and inject template
        try:
            template, used_fallback = template_service.get_template(base_code)
            prompt = template_service.inject_variables(
                template=template,
                recent_data=recent_data,
                stock_code=base_code,
                observation_date=observation_date.isoformat()
            )
        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Prediction template not found")
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
            # Don't fail the request if cache save fails, just log it

        # Step 6: Extract and save signal strength to database
        signal_strength = None
        try:
            logger.info(f"Attempting to extract signal strength from prediction (length: {len(prediction_text)} chars)")
            signal_strength = SignalStrengthParser.extract_signal_strength(prediction_text)

            if signal_strength:
                logger.info(f"✓ Extracted signal strength: {signal_strength} for {base_code}")
                db_service = SignalStrengthDBService()

                logger.info(f"Attempting to save signal strength to database: {base_code} on {observation_date} -> {signal_strength}")
                success = db_service.upsert_signal_strength(
                    stock_code=base_code,
                    observation_date=observation_date,
                    signal_strength_level=signal_strength
                )

                if success:
                    logger.info(f"✓ Successfully saved signal strength: {base_code} -> {signal_strength}")
                else:
                    logger.error(f"✗ Database upsert returned False for {base_code}")
            else:
                logger.warning(f"✗ No signal strength extracted from LLM output for {base_code}")
                # Log last 500 chars of prediction for debugging
                logger.debug(f"Last 500 chars of prediction: {prediction_text[-500:]}")
        except Exception as e:
            logger.error(f"✗ Signal strength extraction/save failed for {base_code}: {e}", exc_info=True)
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
            "signal_strength": signal_strength  # Include extracted signal strength
        }

        # Add warning if fallback template was used
        if used_fallback:
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

        # Load and inject template
        try:
            template, used_fallback = template_service.get_template(base_code)
            prompt = template_service.inject_variables(
                template=template,
                recent_data=recent_data,
                stock_code=base_code,
                observation_date=observation_date.isoformat()
            )
        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Prediction template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Return prompt
        template_file = f"{base_code}.md" if not used_fallback else "SPXW.md"

        return {
            "prompt": prompt,
            "stock_code": base_code,
            "observation_date": observation_date.isoformat(),
            "used_fallback": used_fallback,
            "template_file": template_file,
            "prompt_length": len(prompt),
            "generated_at": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
