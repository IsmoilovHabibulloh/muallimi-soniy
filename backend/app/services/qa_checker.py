"""QA (Quality Assurance) checker for page content.

Validates that a page's text units meet quality standards before publishing.
Checks: unit count, diacritics, overlaps, duplicates, empty hitboxes, audio coverage.
"""

import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict

from app.services.image_analyzer import has_arabic_diacritics, count_diacritics

logger = logging.getLogger("muallimi")


@dataclass
class QAResult:
    """Result of a QA check."""
    passed: bool
    score: float          # 0.0-1.0 overall quality score
    checks: List[Dict]    # Individual check results
    summary: str          # Human-readable summary

    def to_dict(self) -> dict:
        return asdict(self)


def check_unit_count(units: List[dict], min_units: int = 1) -> dict:
    """Check that page has minimum number of units."""
    count = len(units)
    passed = count >= min_units
    return {
        "name": "unit_count",
        "passed": passed,
        "message": f"{count} ta unit topildi" + ("" if passed else f" (kamida {min_units} kerak)"),
        "details": {"count": count, "min_required": min_units},
    }


def check_diacritics_presence(units: List[dict]) -> dict:
    """Check that Arabic text units have diacritical marks."""
    total_arabic_units = 0
    units_with_diacritics = 0
    units_missing_diacritics = []

    for u in units:
        text = u.get("text_content", "")
        # Check if text has Arabic characters
        has_arabic = any('\u0600' <= c <= '\u06FF' for c in text)
        if has_arabic:
            total_arabic_units += 1
            if has_arabic_diacritics(text):
                units_with_diacritics += 1
            else:
                units_missing_diacritics.append({
                    "sort_order": u.get("sort_order", 0),
                    "text": text[:50],
                })

    if total_arabic_units == 0:
        return {
            "name": "diacritics_presence",
            "passed": True,
            "message": "Arabcha text yo'q",
            "details": {},
        }

    ratio = units_with_diacritics / total_arabic_units if total_arabic_units > 0 else 0
    passed = ratio >= 0.8  # At least 80% of Arabic units should have diacritics

    return {
        "name": "diacritics_presence",
        "passed": passed,
        "message": f"{units_with_diacritics}/{total_arabic_units} Arabcha unitlarda harakatlar bor ({ratio:.0%})",
        "details": {
            "total_arabic_units": total_arabic_units,
            "with_diacritics": units_with_diacritics,
            "ratio": round(ratio, 2),
            "missing": units_missing_diacritics[:10],  # Max 10
        },
    }


def check_overlaps(units: List[dict]) -> dict:
    """Check for overlapping bounding boxes."""
    overlaps = []

    for i, u1 in enumerate(units):
        for j, u2 in enumerate(units):
            if i >= j:
                continue
            # Check if boxes overlap significantly (>30% area)
            x1, y1, w1, h1 = u1.get("bbox_x", 0), u1.get("bbox_y", 0), u1.get("bbox_w", 0), u1.get("bbox_h", 0)
            x2, y2, w2, h2 = u2.get("bbox_x", 0), u2.get("bbox_y", 0), u2.get("bbox_w", 0), u2.get("bbox_h", 0)

            # Skip if no bbox set
            if w1 == 0 or w2 == 0:
                continue

            overlap_x = max(0, min(x1 + w1, x2 + w2) - max(x1, x2))
            overlap_y = max(0, min(y1 + h1, y2 + h2) - max(y1, y2))
            overlap_area = overlap_x * overlap_y

            area1 = w1 * h1
            area2 = w2 * h2
            min_area = min(area1, area2) if min(area1, area2) > 0 else 1

            if overlap_area / min_area > 0.3:
                overlaps.append({
                    "unit_a": u1.get("sort_order", i),
                    "unit_b": u2.get("sort_order", j),
                    "overlap_ratio": round(overlap_area / min_area, 2),
                })

    passed = len(overlaps) == 0
    return {
        "name": "no_overlaps",
        "passed": passed,
        "message": f"{len(overlaps)} ta overlap topildi" if not passed else "Overlap yo'q",
        "details": {"overlaps": overlaps[:10]},
    }


def check_duplicates(units: List[dict]) -> dict:
    """Check for duplicate text content."""
    seen = {}
    duplicates = []

    for u in units:
        text = u.get("text_content", "").strip()
        if not text:
            continue
        if text in seen:
            duplicates.append({
                "text": text[:50],
                "sort_order_a": seen[text],
                "sort_order_b": u.get("sort_order", 0),
            })
        else:
            seen[text] = u.get("sort_order", 0)

    passed = len(duplicates) == 0
    return {
        "name": "no_duplicates",
        "passed": passed,
        "message": f"{len(duplicates)} ta dublikat topildi" if not passed else "Dublikat yo'q",
        "details": {"duplicates": duplicates[:10]},
    }


def check_empty_hitboxes(units: List[dict]) -> dict:
    """Check for units with empty/zero bounding boxes."""
    empty = []

    for u in units:
        w = u.get("bbox_w", 0)
        h = u.get("bbox_h", 0)
        if w == 0 or h == 0:
            empty.append({
                "sort_order": u.get("sort_order", 0),
                "text": u.get("text_content", "")[:30],
            })

    # Allow empty hitboxes for now (native layout doesn't always need them)
    passed = True
    return {
        "name": "hitbox_check",
        "passed": passed,
        "message": f"{len(empty)} ta unit bbox'siz" if empty else "Barcha unitlarning bbox'i bor",
        "details": {"empty_count": len(empty), "empty_units": empty[:10]},
    }


def check_audio_coverage(units: List[dict]) -> dict:
    """Check audio mapping coverage (informational, not blocking)."""
    total = len(units)
    with_audio = sum(1 for u in units if u.get("audio_segment_url"))

    ratio = with_audio / total if total > 0 else 0
    return {
        "name": "audio_coverage",
        "passed": True,  # Never blocks publish
        "message": f"{with_audio}/{total} unitlarda audio bor ({ratio:.0%})",
        "details": {
            "total": total,
            "with_audio": with_audio,
            "ratio": round(ratio, 2),
        },
    }


def run_qa_checks(units: List[dict]) -> QAResult:
    """Run all QA checks on a page's text units.

    Args:
        units: List of text unit dicts with text_content, bbox_*, sort_order, etc.

    Returns:
        QAResult with overall pass/fail, score, and individual check results.
    """
    checks = [
        check_unit_count(units),
        check_diacritics_presence(units),
        check_overlaps(units),
        check_duplicates(units),
        check_empty_hitboxes(units),
        check_audio_coverage(units),
    ]

    blocking_checks = [c for c in checks if c["name"] != "audio_coverage"]
    passed = all(c["passed"] for c in blocking_checks)

    # Calculate score (weighted)
    weights = {
        "unit_count": 0.15,
        "diacritics_presence": 0.30,
        "no_overlaps": 0.20,
        "no_duplicates": 0.15,
        "hitbox_check": 0.10,
        "audio_coverage": 0.10,
    }

    score = sum(
        weights.get(c["name"], 0.1) * (1.0 if c["passed"] else 0.0)
        for c in checks
    )

    failed = [c["name"] for c in checks if not c["passed"]]
    if passed:
        summary = f"✅ QA o'tdi (ball: {score:.0%})"
    else:
        summary = f"❌ QA o'tmadi: {', '.join(failed)} (ball: {score:.0%})"

    result = QAResult(
        passed=passed,
        score=round(score, 2),
        checks=checks,
        summary=summary,
    )

    logger.info(f"QA result: {summary}")
    return result
