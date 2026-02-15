"""PDF import and processing service."""

import os
import logging
from typing import List, Tuple, Optional

from app.config import get_settings

logger = logging.getLogger("muallimus")
settings = get_settings()


def render_pdf_pages(pdf_path: str, output_dir: str, dpi: int = 300) -> List[dict]:
    """
    Render each PDF page to an image file.
    Returns list of dicts with page_number, image_path, width, height.
    """
    from pdf2image import convert_from_path

    os.makedirs(output_dir, exist_ok=True)

    pages_info = []
    images = convert_from_path(pdf_path, dpi=dpi)

    for i, img in enumerate(images, start=1):
        # Save standard resolution
        filename = f"page_{i:03d}.webp"
        filepath = os.path.join(output_dir, filename)
        img.save(filepath, "WEBP", quality=90)

        # Save 2x resolution (already at high DPI)
        filename_2x = f"page_{i:03d}_2x.webp"
        filepath_2x = os.path.join(output_dir, filename_2x)
        img.save(filepath_2x, "WEBP", quality=95)

        pages_info.append({
            "page_number": i,
            "image_path": f"pages/{filename}",
            "image_2x_path": f"pages/{filename_2x}",
            "width": img.width,
            "height": img.height,
        })

        logger.info(f"Rendered page {i}/{len(images)}")

    return pages_info


def extract_text_units(pdf_path: str, page_number: int) -> List[dict]:
    """
    Extract text with bounding boxes from a PDF page using pdfplumber.
    Returns list of dicts with text_content, bbox_x, bbox_y, bbox_w, bbox_h (percentages).
    """
    import pdfplumber

    units = []

    try:
        with pdfplumber.open(pdf_path) as pdf:
            if page_number < 1 or page_number > len(pdf.pages):
                return []

            page = pdf.pages[page_number - 1]
            page_width = page.width
            page_height = page.height

            # Extract words with bounding boxes
            words = page.extract_words(
                x_tolerance=3,
                y_tolerance=3,
                keep_blank_chars=False,
                use_text_flow=True,
            )

            for idx, word in enumerate(words):
                if not word.get("text", "").strip():
                    continue

                # Convert absolute coords to percentages
                x0 = word["x0"]
                top = word["top"]
                x1 = word["x1"]
                bottom = word["bottom"]

                bbox_x = (x0 / page_width) * 100
                bbox_y = (top / page_height) * 100
                bbox_w = ((x1 - x0) / page_width) * 100
                bbox_h = ((bottom - top) / page_height) * 100

                units.append({
                    "text_content": word["text"],
                    "unit_type": "word",
                    "bbox_x": round(bbox_x, 2),
                    "bbox_y": round(bbox_y, 2),
                    "bbox_w": round(bbox_w, 2),
                    "bbox_h": round(bbox_h, 2),
                    "sort_order": idx,
                })

    except Exception as e:
        logger.error(f"Text extraction failed for page {page_number}: {e}")

    return units
