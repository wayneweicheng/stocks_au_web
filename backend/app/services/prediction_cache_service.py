from typing import Optional
from datetime import date
from pathlib import Path
import logging
import os

logger = logging.getLogger(__name__)


class PredictionCacheService:
    """Service for file-based caching of price action predictions."""

    def __init__(self, cache_dir: str = "prediction"):
        """
        Initialize the cache service.

        Args:
            cache_dir: Directory to store cached predictions
        """
        self.cache_dir = Path(cache_dir)
        self._ensure_cache_directory()

    def _ensure_cache_directory(self):
        """Create cache directory if it doesn't exist."""
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"Cache directory ready: {self.cache_dir}")
        except Exception as e:
            logger.error(f"Failed to create cache directory: {e}")
            raise

    def normalize_stock_code(self, stock_code: str) -> str:
        """
        Normalize stock code for file naming.

        Args:
            stock_code: Stock code (with or without .US suffix)

        Returns:
            Uppercase base stock code without .US suffix
        """
        return stock_code.replace(".US", "").replace(".us", "").upper()

    def get_cache_filename(self, stock_code: str, observation_date: date) -> str:
        """
        Generate cache filename.

        Args:
            stock_code: Stock code (with or without .US suffix)
            observation_date: Observation date

        Returns:
            Filename in format: <StockCode>_<YYYYMMDD>.md
            Example: NVDA_20251211.md
        """
        base_code = self.normalize_stock_code(stock_code)
        date_str = observation_date.strftime("%Y%m%d")
        filename = f"{base_code}_{date_str}.md"
        logger.debug(f"Generated cache filename: {filename}")
        return filename

    def get_cache_filepath(self, stock_code: str, observation_date: date) -> Path:
        """
        Get full path to cache file.

        Args:
            stock_code: Stock code
            observation_date: Observation date

        Returns:
            Full Path object to cache file
        """
        filename = self.get_cache_filename(stock_code, observation_date)
        return self.cache_dir / filename

    def get_cached_prediction(
        self,
        stock_code: str,
        observation_date: date
    ) -> Optional[str]:
        """
        Read cached prediction if exists.

        Args:
            stock_code: Stock code
            observation_date: Observation date

        Returns:
            Markdown content if cache exists, None otherwise
        """
        filepath = self.get_cache_filepath(stock_code, observation_date)

        if not filepath.exists():
            logger.info(f"Cache miss: {filepath.name}")
            return None

        try:
            content = filepath.read_text(encoding="utf-8")
            logger.info(f"Cache hit: {filepath.name} ({len(content)} characters)")
            return content
        except Exception as e:
            logger.error(f"Failed to read cache file {filepath}: {e}")
            return None

    def save_prediction(
        self,
        stock_code: str,
        observation_date: date,
        markdown_content: str
    ):
        """
        Save prediction markdown to cache file.

        Args:
            stock_code: Stock code
            observation_date: Observation date
            markdown_content: Markdown content to save

        Raises:
            Exception: If file write fails
        """
        filepath = self.get_cache_filepath(stock_code, observation_date)

        try:
            filepath.write_text(markdown_content, encoding="utf-8")
            logger.info(f"Saved prediction to cache: {filepath.name} ({len(markdown_content)} characters)")
        except Exception as e:
            logger.error(f"Failed to save cache file {filepath}: {e}")
            raise

    def cache_exists(self, stock_code: str, observation_date: date) -> bool:
        """
        Check if cache file exists.

        Args:
            stock_code: Stock code
            observation_date: Observation date

        Returns:
            True if cache file exists, False otherwise
        """
        filepath = self.get_cache_filepath(stock_code, observation_date)
        return filepath.exists()
