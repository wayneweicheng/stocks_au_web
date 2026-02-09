from fastapi import APIRouter, Depends, HTTPException
from typing import Dict
from datetime import date

from app.routers.auth import verify_credentials
from app.services.gex_data_service import GEXDataService
from app.services.llm_prediction_service import LLMPredictionService
from app.services.prediction_cache_service import PredictionCacheService

import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["discord_summary"])

FOLLOWER_USERNAMES = [
    "Fanfansd",
    "Williambayc6866",
    "A_beelining_capybara",
    "Ming09082",
    "Will01138",
    "Lancebao",
    "Royalflush88888",
    "Jayoscar2238",
    "Sr5772",
    "Yuanzidan",
]


@router.get("/discord-summary")
def get_discord_summary(
    observation_date: date,
    regenerate: bool = False,
    model: str = "google/gemini-2.5-flash",
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Generate or retrieve Discord channel summary for a given observation date.

    Args:
        observation_date: Date to analyze Discord messages
        regenerate: If True, bypass cache and regenerate summary
        model: LLM model to use for generation
        username: Authenticated username (from dependency)

    Returns:
        Dictionary containing summary markdown and metadata
    """
    try:
        gex_service = GEXDataService()
        llm_service = LLMPredictionService()
        cache_service = PredictionCacheService(cache_dir="llm_output/discord_message_summary")

        logger.info(f"Discord summary request for {observation_date}, regenerate={regenerate}, model={model}")

        # Step 1: Check cache unless regeneration requested
        if not regenerate:
            cached = cache_service.get_cached_prediction(
                stock_code="DISCORD",  # Use a constant since no stock code
                observation_date=observation_date
            )
            if cached:
                logger.info(f"Returning cached Discord summary for {observation_date}")
                return {
                    "summary_markdown": cached,
                    "observation_date": observation_date.isoformat(),
                    "cached": True,
                    "model": "cached"
                }

        # Generate new summary
        logger.info(f"Generating new Discord summary for {observation_date}")

        # Step 2: Query Discord messages
        try:
            discord_rows = gex_service.get_discord_messages(observation_date)
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Step 3: Format data as pipe-delimited
        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        # Step 4: Load Discord summary template
        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")
            logger.info(f"Loaded Discord summary template ({len(template)} characters)")

            # Replace placeholders in template
            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Step 5: Generate summary via LLM
        try:
            llm_result = llm_service.generate_prediction(
                prompt=prompt,
                stock_code="DISCORD",
                observation_date=observation_date.isoformat(),
                model=model
            )
            summary_text = llm_result.get("prediction_text", "")
            logger.info(f"LLM generated Discord summary ({len(summary_text)} characters)")
        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise HTTPException(status_code=500, detail="LLM service unavailable, please try again")

        # Step 6: Save to cache
        try:
            cache_service.save_prediction(
                stock_code="DISCORD",
                observation_date=observation_date,
                markdown_content=summary_text
            )
            logger.info(f"Cached Discord summary for {observation_date}")
        except Exception as e:
            logger.error(f"Cache write failed (non-fatal): {e}")

        # Step 7: Return result
        return {
            "summary_markdown": summary_text,
            "observation_date": observation_date.isoformat(),
            "cached": False,
            "model": model
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/discord-summary-prompt")
def get_discord_summary_prompt(
    observation_date: date,
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Get the LLM prompt that would be used for Discord summary generation.

    Args:
        observation_date: Date to analyze Discord messages
        username: Authenticated username (from dependency)

    Returns:
        Dictionary containing the prompt and metadata
    """
    try:
        gex_service = GEXDataService()

        logger.info(f"Discord summary prompt request for {observation_date}")

        # Query Discord messages data
        try:
            discord_rows = gex_service.get_discord_messages(observation_date)
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Format data as pipe-delimited
        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        # Load and inject template
        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")

            # Replace placeholders
            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Estimate token count (rough approximation: ~4 characters per token)
        estimated_tokens = len(prompt) // 4

        return {
            "prompt": prompt,
            "observation_date": observation_date.isoformat(),
            "estimated_tokens": estimated_tokens,
            "message_count": len(discord_rows)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary_prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/discord-summary-user")
def get_discord_summary_for_user(
    observation_date: date,
    username_filter: str,
    regenerate: bool = False,
    model: str = "google/gemini-2.5-flash",
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Generate or retrieve Discord summary for a specific user on a given observation date.

    Args:
        observation_date: Date to analyze Discord messages
        username_filter: Discord username to filter messages by
        regenerate: If True, bypass cache and regenerate summary
        model: LLM model to use for generation
        username: Authenticated username (from dependency)

    Returns:
        Dictionary containing summary markdown and metadata
    """
    try:
        gex_service = GEXDataService()
        llm_service = LLMPredictionService()
        cache_service = PredictionCacheService(cache_dir="llm_output/discord_message_summary_users")

        logger.info(
            f"Discord user summary request for {observation_date}, user={username_filter}, "
            f"regenerate={regenerate}, model={model}"
        )

        cache_key = f"DISCORD_{username_filter}"

        # Step 1: Check cache unless regeneration requested
        if not regenerate:
            cached = cache_service.get_cached_prediction(
                stock_code=cache_key,
                observation_date=observation_date
            )
            if cached:
                logger.info(f"Returning cached Discord summary for {observation_date} (user={username_filter})")
                return {
                    "summary_markdown": cached,
                    "observation_date": observation_date.isoformat(),
                    "cached": True,
                    "model": "cached"
                }

        # Generate new summary
        logger.info(f"Generating new Discord user summary for {observation_date} (user={username_filter})")

        # Step 2: Query Discord messages
        try:
            discord_rows = gex_service.get_discord_messages_by_users(observation_date, [username_filter])
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date} (user: {username_filter})"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Step 3: Format data as pipe-delimited
        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        # Step 4: Load Discord user summary template
        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_follower_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord follower summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")
            logger.info(f"Loaded Discord follower summary template ({len(template)} characters)")

            # Replace placeholders in template
            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{ username }}", username_filter)
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)
            prompt = prompt.replace("{{username}}", username_filter)

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord follower summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Step 5: Generate summary via LLM
        try:
            llm_result = llm_service.generate_prediction(
                prompt=prompt,
                stock_code=cache_key,
                observation_date=observation_date.isoformat(),
                model=model
            )
            summary_text = llm_result.get("prediction_text", "")
            logger.info(f"LLM generated Discord user summary ({len(summary_text)} characters)")
        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise HTTPException(status_code=500, detail="LLM service unavailable, please try again")

        # Step 6: Save to cache
        try:
            cache_service.save_prediction(
                stock_code=cache_key,
                observation_date=observation_date,
                markdown_content=summary_text
            )
            logger.info(f"Cached Discord user summary for {observation_date} (user={username_filter})")
        except Exception as e:
            logger.error(f"Cache write failed (non-fatal): {e}")

        # Step 7: Return result
        return {
            "summary_markdown": summary_text,
            "observation_date": observation_date.isoformat(),
            "cached": False,
            "model": model
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary_user endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/discord-summary-user-prompt")
def get_discord_summary_user_prompt(
    observation_date: date,
    username_filter: str,
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Get the LLM prompt that would be used for Discord user summary generation.

    Args:
        observation_date: Date to analyze Discord messages
        username_filter: Discord username to filter messages by
        username: Authenticated username (from dependency)

    Returns:
        Dictionary containing the prompt and metadata
    """
    try:
        gex_service = GEXDataService()

        logger.info(f"Discord user summary prompt request for {observation_date} (user={username_filter})")

        # Query Discord messages data
        try:
            discord_rows = gex_service.get_discord_messages_by_users(observation_date, [username_filter])
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date} (user: {username_filter})"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        # Format data as pipe-delimited
        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        # Load and inject template
        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_follower_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord follower summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")

            # Replace placeholders
            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{ username }}", username_filter)
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)
            prompt = prompt.replace("{{username}}", username_filter)

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord follower summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        # Estimate token count (rough approximation: ~4 characters per token)
        estimated_tokens = len(prompt) // 4

        return {
            "prompt": prompt,
            "observation_date": observation_date.isoformat(),
            "estimated_tokens": estimated_tokens,
            "message_count": len(discord_rows)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary_user_prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/discord-summary-followers")
def get_discord_summary_followers(
    observation_date: date,
    regenerate: bool = False,
    model: str = "google/gemini-2.5-flash",
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Generate or retrieve Discord summary for a predefined list of follower usernames.
    """
    try:
        gex_service = GEXDataService()
        llm_service = LLMPredictionService()
        cache_service = PredictionCacheService(cache_dir="llm_output/discord_message_summary_followers")

        logger.info(f"Discord followers summary request for {observation_date}, regenerate={regenerate}, model={model}")

        cache_key = "DISCORD_FOLLOWERS"

        if not regenerate:
            cached = cache_service.get_cached_prediction(
                stock_code=cache_key,
                observation_date=observation_date
            )
            if cached:
                logger.info(f"Returning cached Discord followers summary for {observation_date}")
                return {
                    "summary_markdown": cached,
                    "observation_date": observation_date.isoformat(),
                    "cached": True,
                    "model": "cached"
                }

        try:
            discord_rows = gex_service.get_discord_messages_by_users(observation_date, FOLLOWER_USERNAMES)
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date} (followers list)"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_followers_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord followers summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")
            logger.info(f"Loaded Discord followers summary template ({len(template)} characters)")

            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{ follower_usernames }}", ", ".join(FOLLOWER_USERNAMES))
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)
            prompt = prompt.replace("{{follower_usernames}}", ", ".join(FOLLOWER_USERNAMES))

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord followers summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        try:
            llm_result = llm_service.generate_prediction(
                prompt=prompt,
                stock_code=cache_key,
                observation_date=observation_date.isoformat(),
                model=model
            )
            summary_text = llm_result.get("prediction_text", "")
            logger.info(f"LLM generated Discord followers summary ({len(summary_text)} characters)")
        except Exception as e:
            logger.error(f"LLM generation failed: {e}")
            raise HTTPException(status_code=500, detail="LLM service unavailable, please try again")

        try:
            cache_service.save_prediction(
                stock_code=cache_key,
                observation_date=observation_date,
                markdown_content=summary_text
            )
            logger.info(f"Cached Discord followers summary for {observation_date}")
        except Exception as e:
            logger.error(f"Cache write failed (non-fatal): {e}")

        return {
            "summary_markdown": summary_text,
            "observation_date": observation_date.isoformat(),
            "cached": False,
            "model": model
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary_followers endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/discord-summary-followers-prompt")
def get_discord_summary_followers_prompt(
    observation_date: date,
    username: str = Depends(verify_credentials)
) -> Dict:
    """
    Get the LLM prompt for Discord followers summary generation.
    """
    try:
        gex_service = GEXDataService()

        logger.info(f"Discord followers summary prompt request for {observation_date}")

        try:
            discord_rows = gex_service.get_discord_messages_by_users(observation_date, FOLLOWER_USERNAMES)
            if not discord_rows:
                raise HTTPException(
                    status_code=404,
                    detail=f"No Discord messages found for {observation_date} (followers list)"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Database query failed: {e}")
            raise HTTPException(status_code=503, detail="Database unavailable")

        discord_data = gex_service.format_discord_messages_as_pipe_delimited(discord_rows)

        try:
            from pathlib import Path
            template_path = "signal_pattern/discord_followers_summary_template.md"
            template_file = Path(template_path)

            if not template_file.exists():
                raise FileNotFoundError(f"Discord followers summary template not found: {template_path}")

            template = template_file.read_text(encoding="utf-8")

            prompt = template.replace("{{ observation_date }}", observation_date.isoformat())
            prompt = prompt.replace("{{ discord_messages }}", discord_data)
            prompt = prompt.replace("{{ follower_usernames }}", ", ".join(FOLLOWER_USERNAMES))
            prompt = prompt.replace("{{observation_date}}", observation_date.isoformat())
            prompt = prompt.replace("{{discord_messages}}", discord_data)
            prompt = prompt.replace("{{follower_usernames}}", ", ".join(FOLLOWER_USERNAMES))

        except FileNotFoundError as e:
            logger.error(f"Template loading failed: {e}")
            raise HTTPException(status_code=500, detail="Discord followers summary template not found")
        except Exception as e:
            logger.error(f"Template processing failed: {e}")
            raise HTTPException(status_code=500, detail="Template processing error")

        estimated_tokens = len(prompt) // 4

        return {
            "prompt": prompt,
            "observation_date": observation_date.isoformat(),
            "estimated_tokens": estimated_tokens,
            "message_count": len(discord_rows)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in discord_summary_followers_prompt endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
