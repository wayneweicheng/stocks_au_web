"""
GEX Auto Insight Service

Handles automatic processing of GEX insights for configured stocks.
Checks for new GEX data availability and generates LLM predictions.
"""

from typing import List, Dict, Any, Optional
from datetime import date, datetime
from app.core.db import get_db_connection
from app.services.gex_data_service import GEXDataService
from app.services.prompt_template_service import PromptTemplateService
from app.services.llm_prediction_service import LLMPredictionService
from app.services.prediction_cache_service import PredictionCacheService
from app.services.signal_strength_parser import SignalStrengthParser
from app.services.signal_strength_db_service import SignalStrengthDBService
import logging
from pathlib import Path

logger = logging.getLogger("app.gex_auto_insight")

# Database constants
DATABASE = "StockDB_US"
CONFIG_SCHEMA = "Configuration"
CONFIG_TABLE = "GEXAutoInsightStocks"


class GEXAutoInsightService:
    """Service for automatic GEX insight processing."""

    def __init__(self):
        self.gex_service = GEXDataService()
        self.template_service = PromptTemplateService()
        self.llm_service = LLMPredictionService()
        self.cache_service = PredictionCacheService()
        self.signal_strength_db = SignalStrengthDBService()

    def _resolve_effective_observation_date(self, stock_code: str, target_date: date) -> Optional[date]:
        """
        Resolve the most recent observation date with data available, on or before target_date.
        Returns None if no data exists up to target_date.
        """
        try:
            return self.gex_service.get_latest_observation_date(stock_code, target_date)
        except Exception as e:
            logger.error(f"Failed to resolve effective observation date for {stock_code}: {e}")
            return None

    def get_configured_stocks(self, active_only: bool = True) -> List[Dict[str, Any]]:
        """
        Get the list of stocks configured for automatic GEX insight processing.

        Args:
            active_only: If True, only return active stocks

        Returns:
            List of stock configuration dictionaries
        """
        try:
            conn = get_db_connection(database=DATABASE)
            cursor = conn.cursor()

            cursor.execute(
                f"EXEC [{CONFIG_SCHEMA}].[usp_GetGEXAutoInsightStocks] @pbitActiveOnly = ?",
                (1 if active_only else 0,)
            )

            columns = [column[0] for column in cursor.description]
            rows = cursor.fetchall()

            result = []
            for row in rows:
                result.append(dict(zip(columns, row)))

            logger.info(f"Retrieved {len(result)} configured stocks (active_only={active_only})")
            return result

        except Exception as e:
            logger.error(f"Failed to get configured stocks: {e}")
            return []
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    def upsert_stock(
        self,
        stock_code: str,
        display_name: Optional[str] = None,
        is_active: bool = True,
        priority: int = 0,
        llm_model: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Add or update a stock in the configuration.

        Returns:
            The upserted stock record, or None on failure
        """
        try:
            conn = get_db_connection(database=DATABASE)
            cursor = conn.cursor()

            # Ensure stock code has .US suffix for consistency
            normalized_code = stock_code.upper().strip()
            if not normalized_code.endswith('.US'):
                normalized_code = f"{normalized_code}.US"

            cursor.execute(
                f"""EXEC [{CONFIG_SCHEMA}].[usp_UpsertGEXAutoInsightStock]
                    @pvchStockCode = ?,
                    @pnvcDisplayName = ?,
                    @pbitIsActive = ?,
                    @pintPriority = ?,
                    @pvchLLMModel = ?""",
                (normalized_code, display_name, is_active, priority, llm_model)
            )

            columns = [column[0] for column in cursor.description]
            row = cursor.fetchone()
            conn.commit()

            if row:
                result = dict(zip(columns, row))
                logger.info(f"Upserted stock config: {stock_code}")
                return result
            return None

        except Exception as e:
            logger.error(f"Failed to upsert stock {stock_code}: {e}")
            return None
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    def delete_stock(self, stock_code: str) -> bool:
        """
        Remove a stock from the configuration.

        Returns:
            True if deleted, False otherwise
        """
        try:
            conn = get_db_connection(database=DATABASE)
            cursor = conn.cursor()

            # Ensure stock code has .US suffix for consistency
            normalized_code = stock_code.upper().strip()
            if not normalized_code.endswith('.US'):
                normalized_code = f"{normalized_code}.US"

            cursor.execute(
                f"EXEC [{CONFIG_SCHEMA}].[usp_DeleteGEXAutoInsightStock] @pvchStockCode = ?",
                (normalized_code,)
            )

            row = cursor.fetchone()
            conn.commit()

            deleted = row[0] > 0 if row else False
            logger.info(f"Deleted stock config: {stock_code} (success={deleted})")
            return deleted

        except Exception as e:
            logger.error(f"Failed to delete stock {stock_code}: {e}")
            return False
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    def check_gex_data_available(self, stock_code: str, target_date: date) -> bool:
        """
        Check if GEX data is available for a stock on the target date.

        Args:
            stock_code: Stock code (without .US suffix)
            target_date: Date to check

        Returns:
            True if GEX data exists for the exact target date
        """
        try:
            gex_rows = self.gex_service.get_recent_features(stock_code, target_date, days=1)
            if not gex_rows:
                return False

            # Check if the latest row is for the target date
            latest_row = gex_rows[-1]
            latest_date_value = latest_row.get('ObservationDate')

            if isinstance(latest_date_value, str):
                latest_date = datetime.strptime(latest_date_value[:10], '%Y-%m-%d').date()
            elif hasattr(latest_date_value, 'date'):
                latest_date = latest_date_value.date()
            else:
                latest_date = latest_date_value

            return latest_date == target_date

        except Exception as e:
            logger.error(f"Error checking GEX data for {stock_code}: {e}")
            return False

    def check_signal_strength_exists(self, stock_code: str, target_date: date) -> bool:
        """
        Check if signal strength already exists for a stock on the target date.

        Args:
            stock_code: Stock code (with or without .US suffix)
            target_date: Date to check

        Returns:
            True if signal strength record exists
        """
        # Normalize stock code - signal strength is stored without .US suffix
        base_code = self.cache_service.normalize_stock_code(stock_code)
        existing = self.signal_strength_db.get_signal_strength(
            stock_code=base_code,
            observation_date=target_date,
            source_type="GEX"
        )
        return existing is not None

    def get_processing_status(self, target_date: date) -> Dict[str, Any]:
        """
        Get the processing status for all configured stocks on a target date.

        Returns:
            Dictionary with status information for each stock
        """
        stocks = self.get_configured_stocks(active_only=True)

        status = {
            "target_date": target_date.isoformat(),
            "total_configured": len(stocks),
            "stocks": []
        }

        available_count = 0
        processed_count = 0
        pending_count = 0

        for stock in stocks:
            stock_code = stock["StockCode"]
            # Normalize for signal strength lookup (stored without .US suffix)
            base_code = self.cache_service.normalize_stock_code(stock_code)
            effective_date = self._resolve_effective_observation_date(stock_code, target_date)
            has_gex_data = effective_date is not None
            has_signal = False
            if has_gex_data:
                has_signal = self.check_signal_strength_exists(stock_code, effective_date)  # base_code used inside

            stock_status = {
                "stock_code": stock_code,
                "display_name": stock.get("DisplayName"),
                "priority": stock.get("Priority", 0),
                "has_gex_data": has_gex_data,
                "has_signal_strength": has_signal,
                "status": "no_data",
                "effective_date": effective_date.isoformat() if effective_date else None
            }

            if has_gex_data:
                available_count += 1
                if has_signal:
                    processed_count += 1
                    # Get the actual signal strength value (use normalized code)
                    signal = self.signal_strength_db.get_signal_strength(base_code, effective_date, "GEX")
                    stock_status["signal_strength"] = signal
                    stock_status["status"] = "processed"
                else:
                    pending_count += 1
                    stock_status["status"] = "pending"

            status["stocks"].append(stock_status)

        status["available_count"] = available_count
        status["processed_count"] = processed_count
        status["pending_count"] = pending_count

        return status

    def process_stock(
        self,
        stock_code: str,
        target_date: date,
        model: Optional[str] = None,
        force_regenerate: bool = False
    ) -> Dict[str, Any]:
        """
        Process a single stock - generate GEX insight prediction.

        Args:
            stock_code: Stock code to process
            target_date: Observation date
            model: LLM model to use (None = default)
            force_regenerate: If True, regenerate even if cached

        Returns:
            Dictionary with processing result
        """
        base_code = self.cache_service.normalize_stock_code(stock_code)
        default_model = "google/gemini-2.5-flash"
        llm_model = model or default_model

        result = {
            "stock_code": base_code,
            "target_date": None,
            "model": llm_model,
            "success": False,
            "cached": False,
            "signal_strength": None,
            "error": None
        }

        try:
            # Resolve most recent available observation date (<= target_date)
            effective_date = self._resolve_effective_observation_date(base_code, target_date)
            if effective_date is None:
                result["error"] = f"No GEX data available on or before {target_date}"
                logger.warning(f"No GEX data for {base_code} up to {target_date}")
                return result
            result["target_date"] = effective_date.isoformat()

            # Check if already processed (unless force_regenerate)
            if not force_regenerate and self.check_signal_strength_exists(base_code, effective_date):
                existing_signal = self.signal_strength_db.get_signal_strength(base_code, effective_date, "GEX")
                result["success"] = True
                result["cached"] = True
                result["signal_strength"] = existing_signal
                result["message"] = "Already processed"
                logger.info(f"Stock {base_code} already processed for {effective_date}")
                return result

            # Check cache file and optionally upsert DB from cache (avoid LLM if cache exists)
            if not force_regenerate and self.cache_service.cache_exists(base_code, effective_date):
                cached_text = self.cache_service.get_cached_prediction(base_code, effective_date) or ""
                result["cached"] = True
                # Try to extract and persist signal strength if missing
                if not self.check_signal_strength_exists(base_code, effective_date):
                    signal_from_cache = SignalStrengthParser.extract_signal_strength(cached_text)
                    if signal_from_cache:
                        self.signal_strength_db.upsert_signal_strength(
                            stock_code=base_code,
                            observation_date=effective_date,
                            signal_strength_level=signal_from_cache,
                            source_type="GEX"
                        )
                        result["signal_strength"] = signal_from_cache
                result["success"] = True
                result["message"] = "Cache hit; skipped LLM generation"
                logger.info(f"Cache hit for {base_code} on {effective_date}; skipped LLM")
                return result

            # Get GEX features
            gex_rows = self.gex_service.get_recent_features(base_code, effective_date, days=30)
            if not gex_rows:
                result["error"] = "Failed to retrieve GEX features"
                return result

            # Format data
            recent_data = self.gex_service.format_as_json(gex_rows)

            # Load template
            template, used_fallback = self.template_service.get_template(base_code)
            prompt = self.template_service.inject_variables(
                template=template,
                recent_data=recent_data,
                stock_code=base_code,
                observation_date=effective_date.isoformat()
            )

            # Generate prediction
            logger.info(f"Generating LLM prediction for {base_code} using {llm_model}")
            llm_result = self.llm_service.generate_prediction(
                prompt=prompt,
                stock_code=base_code,
                observation_date=effective_date.isoformat(),
                model=llm_model
            )
            prediction_text = llm_result["prediction_text"]
            result["token_usage"] = llm_result.get("token_usage")

            # Save to cache
            try:
                self.cache_service.save_prediction(base_code, effective_date, prediction_text)
            except Exception as e:
                logger.warning(f"Cache save failed for {base_code}: {e}")

            # Extract and save signal strength
            signal_strength = SignalStrengthParser.extract_signal_strength(prediction_text)
            if signal_strength:
                success = self.signal_strength_db.upsert_signal_strength(
                    stock_code=base_code,
                    observation_date=effective_date,
                    signal_strength_level=signal_strength,
                    source_type="GEX"
                )
                if success:
                    result["signal_strength"] = signal_strength
                    result["success"] = True
                    logger.info(f"Successfully processed {base_code} on {effective_date}: {signal_strength}")
                else:
                    result["error"] = "Failed to save signal strength to database"
            else:
                result["error"] = "Failed to extract signal strength from LLM response"
                logger.warning(f"No signal strength extracted for {base_code}")

            if used_fallback:
                result["warning"] = f"Used SPXW fallback template for {base_code}"

            return result

        except Exception as e:
            result["error"] = str(e)
            logger.error(f"Error processing {base_code}: {e}", exc_info=True)
            return result

    def process_all_pending(
        self,
        target_date: date,
        dry_run: bool = False
    ) -> Dict[str, Any]:
        """
        Process all configured stocks that have pending GEX data.

        Args:
            target_date: Date to process
            dry_run: If True, only report what would be processed

        Returns:
            Summary of processing results
        """
        status = self.get_processing_status(target_date)
        pending_stocks = [s for s in status["stocks"] if s["status"] == "pending"]

        summary = {
            "target_date": target_date.isoformat(),
            "dry_run": dry_run,
            "total_configured": status["total_configured"],
            "available": status["available_count"],
            "already_processed": status["processed_count"],
            "pending": len(pending_stocks),
            "processed": [],
            "failed": [],
            "skipped": []
        }

        if dry_run:
            summary["skipped"] = [s["stock_code"] for s in pending_stocks]
            logger.info(f"Dry run: would process {len(pending_stocks)} stocks")
            return summary

        # Process each pending stock
        for stock_info in pending_stocks:
            stock_code = stock_info["stock_code"]
            logger.info(f"Processing {stock_code} for {target_date}")

            # Get configured LLM model for this stock
            stocks = self.get_configured_stocks(active_only=True)
            stock_config = next((s for s in stocks if s["StockCode"] == stock_code), None)
            llm_model = stock_config.get("LLMModel") if stock_config else None

            result = self.process_stock(stock_code, target_date, model=llm_model)

            if result["success"]:
                summary["processed"].append({
                    "stock_code": stock_code,
                    "signal_strength": result.get("signal_strength"),
                    "cached": result.get("cached", False)
                })
            else:
                summary["failed"].append({
                    "stock_code": stock_code,
                    "error": result.get("error")
                })

        logger.info(
            f"Processing complete: {len(summary['processed'])} succeeded, "
            f"{len(summary['failed'])} failed"
        )

        return summary
