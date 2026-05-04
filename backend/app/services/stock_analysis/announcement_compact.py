"""Compact announcement data to LLM-ready format."""

from datetime import datetime
from typing import Dict, List, Any, Optional
import re


def categorize_announcement(description: str, content: str) -> str:
    """Categorize announcement by type."""
    desc_lower = description.lower() if description else ""
    content_lower = content.lower() if content else ""

    # Funding/Capital
    if any(term in desc_lower for term in ["placement", "capital raising", "spp", "share purchase plan", "rights issue", "appendix 3b"]):
        return "funding"

    # Cash flow/Financial
    if any(term in desc_lower for term in ["appendix 5b", "quarterly", "activities report", "cash flow"]):
        return "financial"

    # Drilling/Exploration
    if any(term in desc_lower for term in ["drill", "assay", "exploration", "results", "intercept", "mineralisation"]):
        return "exploration"

    # Corporate
    if any(term in desc_lower for term in ["agm", "egm", "director", "appointment", "change of director", "substantial holder"]):
        return "corporate"

    # Trading/Price sensitive
    if any(term in desc_lower for term in ["trading halt", "suspension", "pause", "voluntary suspension"]):
        return "trading"

    return "other"


def extract_funding_signals(announcements: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Extract funding and cash position signals."""
    signals = {
        "recent_raise": False,
        "raise_date": None,
        "raise_amount": None,
        "cash_position": "Unknown",
        "runway_months": None,
        "burn_rate": None
    }

    for ann in announcements:
        desc = ann.get("AnnDescr", "").lower()
        content = ann.get("AnnContent", "").lower()

        # Detect capital raising
        if any(term in desc for term in ["placement", "capital raising", "spp"]):
            signals["recent_raise"] = True
            if ann.get("AnnDateTime"):
                signals["raise_date"] = ann["AnnDateTime"]

        # Extract cash figures from quarterly reports
        if "appendix 5b" in desc or "quarterly" in desc:
            # Try to extract cash at quarter end
            cash_match = re.search(r'cash.*?(\d+[,\d]*)\s*(?:million|m|k)', content)
            if cash_match:
                signals["cash_position"] = f"${cash_match.group(1)}"

            # Try to extract burn rate
            burn_match = re.search(r'(?:burn|outflow|payments).*?(\d+[,\d]*)\s*(?:million|m|k)', content)
            if burn_match:
                signals["burn_rate"] = f"${burn_match.group(1)}"

    return signals


def extract_catalysts(announcements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Extract explicit and inferred catalysts."""
    catalysts = []

    for ann in announcements:
        desc = ann.get("AnnDescr", "")
        content = ann.get("AnnContent", "")
        date = ann.get("AnnDateTime")

        # Explicit catalyst keywords
        if any(term in desc.lower() for term in ["expected", "anticipated", "scheduled", "planned", "upcoming"]):
            catalysts.append({
                "type": "explicit",
                "item": desc,
                "date": date,
                "certainty": "high",
                "timing": "next_90d"  # Default, refine with date parsing
            })

        # Inferred catalysts from drilling programs
        if any(term in desc.lower() for term in ["drill", "program", "campaign"]) and "commenced" in desc.lower():
            catalysts.append({
                "type": "inferred",
                "item": f"Drill results from {desc}",
                "date": date,
                "certainty": "medium",
                "timing": "next_90d"
            })

    return catalysts[:5]  # Top 5 most recent


def extract_red_flags(announcements: List[Dict[str, Any]]) -> List[str]:
    """Extract red flags and risks."""
    flags = []

    for ann in announcements:
        desc = ann.get("AnnDescr", "").lower()

        # Trading halts
        if "trading halt" in desc or "suspension" in desc:
            flags.append(f"Trading halt/suspension: {ann.get('AnnDateTime')}")

        # Delays
        if any(term in desc for term in ["delay", "postponed", "extended"]):
            flags.append(f"Timeline delay: {desc}")

        # Negative drilling results
        if "drill" in desc and any(term in desc for term in ["no significant", "below", "lower than"]):
            flags.append(f"Weak drill results: {desc}")

    return flags[:5]


def compact_announcements(raw_announcements: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Compact announcements to LLM-ready format.
    Target: ~3,000 tokens
    """
    if not raw_announcements:
        return {
            "coverage": {"start_date": None, "end_date": None, "total_count": 0},
            "material_events": [],
            "funding_signals": {},
            "catalysts": [],
            "red_flags": []
        }

    # Sort by date (most recent first)
    announcements = sorted(
        raw_announcements,
        key=lambda x: x.get("AnnDateTime") or "",
        reverse=True
    )

    # Coverage stats
    dates = [ann.get("AnnDateTime") for ann in announcements if ann.get("AnnDateTime")]
    coverage = {
        "start_date": min(dates).isoformat() if dates else None,
        "end_date": max(dates).isoformat() if dates else None,
        "total_count": len(announcements)
    }

    # Material events (top 10 most recent)
    material_events = []
    for ann in announcements[:10]:
        category = categorize_announcement(
            ann.get("AnnDescr", ""),
            ann.get("AnnContent", "")
        )
        material_events.append({
            "id": ann.get("AnnouncementID"),
            "date": ann.get("AnnDateTime").isoformat() if ann.get("AnnDateTime") else None,
            "description": ann.get("AnnDescr", ""),
            "market_sensitive": ann.get("MarketSensitiveIndicator") == "Y",
            "category": category,
            "url": ann.get("AnnURL")
        })

    # Extract signals
    funding_signals = extract_funding_signals(announcements)
    catalysts = extract_catalysts(announcements)
    red_flags = extract_red_flags(announcements)

    # Category breakdown
    category_counts = {}
    for ann in announcements:
        category = categorize_announcement(
            ann.get("AnnDescr", ""),
            ann.get("AnnContent", "")
        )
        category_counts[category] = category_counts.get(category, 0) + 1

    return {
        "coverage": coverage,
        "category_counts": category_counts,
        "material_events": material_events,
        "funding_signals": funding_signals,
        "catalysts": catalysts,
        "red_flags": red_flags
    }
