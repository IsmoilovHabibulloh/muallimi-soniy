"""Image analysis service for page images.

Takes a page image (PNG/JPG), runs OCR + CV analysis,
and returns semantic text units with bounding boxes.

Uses Tesseract for OCR with Arabic language support.
Designed to be swappable with Google Cloud Vision later.
"""

import os
import re
import logging
from typing import List, Optional
from dataclasses import dataclass, asdict

from app.config import get_settings

logger = logging.getLogger("muallimus")
settings = get_settings()

# Arabic diacritics (tashkeel) Unicode range
ARABIC_DIACRITICS = set([
    '\u064B',  # FATHATAN (tanwin fatha)
    '\u064C',  # DAMMATAN (tanwin damma)
    '\u064D',  # KASRATAN (tanwin kasra)
    '\u064E',  # FATHA (zabar)
    '\u064F',  # DAMMA (pesh)
    '\u0650',  # KASRA (zer)
    '\u0651',  # SHADDA (tashdid)
    '\u0652',  # SUKUN
    '\u0653',  # MADDAH
    '\u0654',  # HAMZA ABOVE
    '\u0655',  # HAMZA BELOW
    '\u0670',  # SUPERSCRIPT ALEF
])


@dataclass
class AnalyzedUnit:
    """A single text unit extracted from image analysis."""
    text: str
    unit_type: str        # letter | word | sentence | drill_group | divider
    bbox_x: float         # X position (% of image width, 0-100)
    bbox_y: float         # Y position (% of image height, 0-100)
    bbox_w: float         # Width (%)
    bbox_h: float         # Height (%)
    confidence: float     # OCR confidence (0.0-1.0)
    sort_order: int       # Display order
    metadata: dict = None

    def to_dict(self) -> dict:
        d = asdict(self)
        if d['metadata'] is None:
            d['metadata'] = {}
        return d


def has_arabic_diacritics(text: str) -> bool:
    """Check if text contains Arabic diacritical marks."""
    return any(c in ARABIC_DIACRITICS for c in text)


def count_diacritics(text: str) -> int:
    """Count Arabic diacritical marks in text."""
    return sum(1 for c in text if c in ARABIC_DIACRITICS)


def classify_unit_type(text: str, word_count: int) -> str:
    """Classify a text fragment into a unit type based on content.

    Rules:
    - Single Arabic letter (1-2 chars + diacritics) → letter
    - Single word → word
    - Multiple words → sentence
    - Lines with only dashes/decorations → divider
    """
    stripped = text.strip()

    if not stripped:
        return "divider"

    # Check if it's a divider (only non-letter chars)
    if re.match(r'^[\s\-–—═━─│┃\*\.•]+$', stripped):
        return "divider"

    # Count base Arabic letters (excluding diacritics)
    base_chars = [c for c in stripped if c not in ARABIC_DIACRITICS and c != ' ']
    arabic_letters = [c for c in base_chars if '\u0600' <= c <= '\u06FF' or '\u0750' <= c <= '\u077F']

    if len(arabic_letters) <= 2 and word_count <= 1:
        return "letter"
    elif word_count <= 1:
        return "word"
    elif word_count <= 4:
        return "word"
    else:
        return "sentence"


def analyze_image_tesseract(image_path: str) -> List[AnalyzedUnit]:
    """Analyze a page image using Tesseract OCR.

    Returns list of AnalyzedUnit with text, bounding boxes, and types.
    Requires pytesseract and Pillow to be installed.
    """
    try:
        import pytesseract
        from PIL import Image
    except ImportError:
        logger.error("pytesseract or Pillow not installed. Install with: pip install pytesseract Pillow")
        return []

    if not os.path.exists(image_path):
        logger.error(f"Image not found: {image_path}")
        return []

    try:
        img = Image.open(image_path)
        img_width, img_height = img.size

        # Run Tesseract with Arabic language
        # PSM 6 = Assume a single uniform block of text
        # OEM 3 = Default (LSTM + Legacy)
        data = pytesseract.image_to_data(
            img,
            lang='ara',
            config='--psm 6 --oem 3',
            output_type=pytesseract.Output.DICT
        )

        units = []
        current_line = []
        current_line_num = -1
        sort_idx = 0

        n_boxes = len(data['text'])

        # Group words by line
        lines = {}
        for i in range(n_boxes):
            text = data['text'][i].strip()
            if not text:
                continue

            line_num = data['line_num'][i]
            conf = float(data['conf'][i]) / 100.0  # Normalize to 0-1

            if line_num not in lines:
                lines[line_num] = []

            lines[line_num].append({
                'text': text,
                'left': data['left'][i],
                'top': data['top'][i],
                'width': data['width'][i],
                'height': data['height'][i],
                'conf': max(0, conf),
            })

        # Process each line
        for line_num in sorted(lines.keys()):
            words = lines[line_num]
            if not words:
                continue

            # Calculate line bounding box
            min_left = min(w['left'] for w in words)
            min_top = min(w['top'] for w in words)
            max_right = max(w['left'] + w['width'] for w in words)
            max_bottom = max(w['top'] + w['height'] for w in words)
            avg_conf = sum(w['conf'] for w in words) / len(words)

            line_text = ' '.join(w['text'] for w in words)
            word_count = len(words)

            # Classify unit type
            unit_type = classify_unit_type(line_text, word_count)

            # Convert to percentages
            bbox_x = (min_left / img_width) * 100
            bbox_y = (min_top / img_height) * 100
            bbox_w = ((max_right - min_left) / img_width) * 100
            bbox_h = ((max_bottom - min_top) / img_height) * 100

            unit = AnalyzedUnit(
                text=line_text,
                unit_type=unit_type,
                bbox_x=round(bbox_x, 2),
                bbox_y=round(bbox_y, 2),
                bbox_w=round(bbox_w, 2),
                bbox_h=round(bbox_h, 2),
                confidence=round(avg_conf, 3),
                sort_order=sort_idx,
                metadata={
                    'word_count': word_count,
                    'has_diacritics': has_arabic_diacritics(line_text),
                    'diacritics_count': count_diacritics(line_text),
                    'source': 'tesseract',
                },
            )
            units.append(unit)
            sort_idx += 1

        logger.info(f"Tesseract analysis: {len(units)} units extracted from {image_path}")
        return units

    except Exception as e:
        logger.error(f"Tesseract analysis failed: {e}")
        return []


def analyze_image(image_path: str, engine: str = "tesseract") -> List[AnalyzedUnit]:
    """Main entry point for image analysis.

    Args:
        image_path: Path to the page image file
        engine: OCR engine to use ("tesseract" or "google_vision")

    Returns:
        List of AnalyzedUnit objects
    """
    if engine == "tesseract":
        return analyze_image_tesseract(image_path)
    elif engine == "google_vision":
        # TODO: Implement Google Cloud Vision support
        logger.warning("Google Vision not yet implemented, falling back to Tesseract")
        return analyze_image_tesseract(image_path)
    else:
        logger.error(f"Unknown OCR engine: {engine}")
        return []
