from typing import Optional, Tuple
from pathlib import Path
import logging
import re

logger = logging.getLogger(__name__)


class PromptTemplateService:
    """Service for loading and processing prompt templates from signal_pattern directory."""

    def __init__(self, template_dir: str = "signal_pattern"):
        """
        Initialize the template service.

        Args:
            template_dir: Directory containing signal pattern templates
        """
        self.template_dir = Path(template_dir)
        if not self.template_dir.exists():
            logger.warning(f"Template directory does not exist: {self.template_dir}")

    def normalize_stock_code(self, stock_code: str) -> str:
        """
        Normalize stock code for template file lookup.

        Args:
            stock_code: Stock code (with or without .US suffix)

        Returns:
            Uppercase base stock code without .US suffix
        """
        return stock_code.replace(".US", "").replace(".us", "").upper()

    def get_template(self, stock_code: str) -> Tuple[str, bool]:
        """
        Load prompt template for stock.

        Args:
            stock_code: Stock code (with or without .US suffix)

        Returns:
            Tuple of (template_content, used_fallback)
            - template_content: Template content from <StockCode>.md file
            - used_fallback: True if SPXW.md fallback was used, False if stock-specific template found

        Raises:
            FileNotFoundError: If neither stock-specific nor fallback template exists
        """
        base_code = self.normalize_stock_code(stock_code)
        template_path = self.template_dir / f"{base_code}.md"

        # Try stock-specific template first
        if template_path.exists():
            try:
                content = template_path.read_text(encoding="utf-8")
                logger.info(f"Loaded template: {template_path.name} ({len(content)} characters)")
                return content, False
            except Exception as e:
                logger.error(f"Failed to read template {template_path}: {e}")
                # Fall through to fallback

        # Fallback to SPXW.md
        logger.warning(f"Template not found for {base_code}, falling back to SPXW.md")
        fallback_path = self.template_dir / "SPXW.md"

        if not fallback_path.exists():
            raise FileNotFoundError(
                f"Neither {template_path.name} nor fallback SPXW.md found in {self.template_dir}"
            )

        try:
            content = fallback_path.read_text(encoding="utf-8")
            logger.info(f"Loaded fallback template: SPXW.md ({len(content)} characters)")
            return content, True
        except Exception as e:
            logger.error(f"Failed to read fallback template {fallback_path}: {e}")
            raise

    def inject_variables(
        self,
        template: str,
        recent_data: str,
        stock_code: Optional[str] = None,
        observation_date: Optional[str] = None
    ) -> str:
        """
        Replace template variables with actual values.

        Replaces:
        - {{ recent_data }} with tab-delimited data
        - {{ stock_code }} with base stock code (optional)
        - {{ observation_date }} with observation date (optional)

        If {{ recent_data }} placeholder not found in template, appends recent_data to end.

        Args:
            template: Template content with placeholders
            recent_data: Tab-delimited GEX features data
            stock_code: Base stock code (optional)
            observation_date: Observation date string (optional)

        Returns:
            Template with variables replaced
        """
        result = template

        # Check if {{ recent_data }} placeholder exists
        has_recent_data_placeholder = "{{ recent_data }}" in result or "{{recent_data}}" in result

        # Replace {{ recent_data }} (with or without spaces)
        result = result.replace("{{ recent_data }}", recent_data)
        result = result.replace("{{recent_data}}", recent_data)

        # If {{ recent_data }} placeholder not found, append to end
        if not has_recent_data_placeholder:
            logger.info("No {{ recent_data }} placeholder found, appending data to end of template")
            result = result.rstrip() + "\n\n## Data (Last 30 Days)\n\n" + recent_data

        # Replace optional variables if provided
        if stock_code is not None:
            base_code = self.normalize_stock_code(stock_code)
            result = result.replace("{{ stock_code }}", base_code)
            result = result.replace("{{stock_code}}", base_code)

        if observation_date is not None:
            result = result.replace("{{ observation_date }}", observation_date)
            result = result.replace("{{observation_date}}", observation_date)

        logger.info(f"Injected variables into template ({len(result)} characters after injection)")

        return result
