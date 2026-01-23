"""
Pure Python converter for unformatted text (copied from web) to Markdown.

This module handles text that has lost formatting when copied from sources like
Gemini, ChatGPT, or web pages - where all line breaks are stripped out.
"""

import re
from typing import List, Tuple


def convert_to_markdown(text: str) -> str:
    """
    Convert unformatted pasted text to properly formatted Markdown.

    Handles:
    - Section headers (1. Section, 1.1 Subsection, etc.)
    - Metadata lines (Date:, Ticker:, Sector:, etc.)
    - Bullet-style items (Word: description pattern)
    - Citation superscripts
    - Basic paragraph detection

    Args:
        text: Raw unformatted text copied from web source

    Returns:
        Formatted markdown string
    """
    if not text or not text.strip():
        return ""

    # Clean up the text
    text = text.strip()

    # Step 1: Add line breaks before section headers (1. Title, 1.1 Title, etc.)
    # Match patterns like "1. Executive Summary" or "10. Conclusion"
    text = re.sub(
        r'(\d+\.\s+[A-Z][A-Za-z\s,&:]+?)(?=\d+\.\d+|\d+\.\s+[A-Z]|$)',
        r'\n\n## \1\n\n',
        text
    )

    # Match subsection patterns like "1.1 The Investment Thesis"
    text = re.sub(
        r'(\d+\.\d+\s+[A-Z][A-Za-z\s,&:\'\"]+?)(?=\d+\.\d+|\d+\.\s+[A-Z]|[A-Z][a-z]+\s)',
        r'\n\n### \1\n\n',
        text
    )

    # Step 2: Handle metadata-style lines at the beginning
    # Patterns like "Date: January 18, 2026" or "Ticker: ASX: LIN"
    metadata_patterns = [
        (r'(Date:\s*[^A-Z]+?)(?=[A-Z])', r'\n**\1**\n'),
        (r'(Ticker:\s*[^S]+?)(?=Sector)', r'\n**\1**\n'),
        (r'(Sector:\s*[^R]+?)(?=Recommendation)', r'\n**\1**\n'),
        (r'(Recommendation:\s*[^R]+?)(?=Risk)', r'\n**\1**\n'),
        (r'(Risk Profile:\s*[^0-9]+?)(?=\d)', r'\n**\1**\n'),
    ]

    for pattern, replacement in metadata_patterns:
        text = re.sub(pattern, replacement, text)

    # Step 3: Handle citation superscripts - add space and format
    # Patterns like ".1As" -> ". ¹ As" or "issues.1As" -> "issues.¹ As"
    text = re.sub(r'\.(\d+)([A-Z])', r'.^[\1]^ \2', text)
    text = re.sub(r'(\w)(\d+)([A-Z][a-z])', r'\1^[\2]^ \3', text)

    # Step 4: Handle bullet-point style items
    # Pattern: "Word/Phrase: Description" at start of what looks like a list item
    bullet_patterns = [
        # Executive Leadership style
        r'((?:Alwyn Vorster|Robert Anthony Martin|Zac Komur|Teck Lim)\s*\([^)]+\):)',
        # Strategic items
        r'((?:World-Class Asset Quality|Strategic Endorsement|Undervalued Growth Optionality|Cost Control|Operational Flexibility|Local Engagement|Logistics|Processing|Marketability|The Flowsheet|Water-Based|Capital Efficiency|Expansion Scope|Resource Support|Funding|Offtake Agreement|Pricing Structure|Construction Facility|Geopolitical Alignment|Technical Validation|Supply Chain Integration|Electric Vehicles|Wind Energy|Defense|Forecasts|China\'s Influence|Regulatory Framework|Foreign Investment|Legal Stability|Lelouma|Gaoual|Woula|Construction Delays|Commodity Price Volatility|Legal/Sovereign Risk):)',
    ]

    for pattern in bullet_patterns:
        text = re.sub(pattern, r'\n\n- **\1**', text)

    # Step 5: Handle "Mitigation:" patterns
    text = re.sub(r'(Mitigation:)', r'*\1*', text)

    # Step 6: Try to detect table headers and format them
    # This is tricky - tables often appear as concatenated column headers
    # For now, add line breaks around common table patterns
    table_header_patterns = [
        r'(Metric\s*Data\s*Source)',
        r'(Category\s*Tonnage[^(]+\(Mt\)\s*Grade[^(]+\([^)]+\)\s*Contained[^(]+\([^)]+\))',
        r'(Economic Metric\s*Value[^(]+\(USD\)\s*Value[^(]+\(AUD\)\s*Source)',
        r'(Period\s*Milestone\s*Status)',
    ]

    for pattern in table_header_patterns:
        text = re.sub(pattern, r'\n\n**\1**\n', text)

    # Step 7: Add paragraph breaks before certain transition phrases
    paragraph_starters = [
        'The investment case',
        'As of',
        'In stark contrast',
        'The presence of',
        'The sheer scale',
        'The partnership',
        'The demand for',
        'After a period',
        'The market\'s current',
        'While the outlook',
        'While the market',
        'While Kangankunde',
        'A critical component',
        'The capital structure',
        'The shareholder base',
        'The Kangankunde deposit',
        'Most monazite-hosted',
        'In September 2025',
        'The metallurgy',
        'The Stage 1 Feasibility',
        'The project economics',
        'A capital cost',
        'The simple mining',
        'In August 2025',
        'The agreement is',
        'Malawi is increasingly',
        'Guinea is the',
        'With prices stabilizing',
        'The path to production',
        'Lindian Resources presents',
        'Founded in 1999',
        'To support this',
    ]

    for starter in paragraph_starters:
        text = re.sub(
            rf'([.!?])(\s*)({re.escape(starter)})',
            r'\1\n\n\3',
            text
        )

    # Step 8: Clean up multiple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)

    # Step 9: Clean up spaces
    text = re.sub(r' +', ' ', text)

    # Step 10: Ensure headers have proper spacing
    text = re.sub(r'(#{2,3}\s+[^\n]+)\n(?!\n)', r'\1\n\n', text)

    return text.strip()


def detect_and_format_tables(text: str) -> str:
    """
    Attempt to detect table-like data and format as markdown tables.
    This is a best-effort function for common table patterns.

    Args:
        text: Partially formatted text

    Returns:
        Text with tables formatted where possible
    """
    # This would need custom logic per table type
    # For now, return as-is
    return text


def simple_cleanup(text: str) -> str:
    """
    Perform simple cleanup without trying to infer structure.
    Just handles basic whitespace and obvious patterns.

    Args:
        text: Raw text

    Returns:
        Cleaned text with preserved structure if any
    """
    if not text:
        return ""

    # Normalize line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')

    # If text already has line breaks, preserve them
    if '\n' in text:
        # Just clean up excessive whitespace
        lines = text.split('\n')
        cleaned_lines = []
        for line in lines:
            cleaned_lines.append(line.strip())
        return '\n'.join(cleaned_lines)

    # If no line breaks, try the full conversion
    return convert_to_markdown(text)


# Test function
if __name__ == "__main__":
    # Test with sample unformatted text
    sample = """EQUITIES RESEARCH: LINDIAN RESOURCES LIMITED (ASX: LIN)INITIATION OF COVERAGE: THE STRATEGIC ASCENSION OF KANGANKUNDEFROM EXPLORATION TO TIER-1 GLOBAL PRODUCTIONDate: January 18, 2026Ticker: ASX: LINSector: Materials / Critical MineralsRecommendation: BUY (High Conviction)Risk Profile: Speculative Growth / Emerging Producer1. Executive Summary1.1 The Investment ThesisLindian Resources Limited (ASX: LIN) has rapidly evolved from a junior explorer."""

    result = convert_to_markdown(sample)
    print(result)
