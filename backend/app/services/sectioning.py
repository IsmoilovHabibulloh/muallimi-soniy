"""
Lesson Sectioning Engine — deterministic Arabic textbook-aware auto-sectioning.

Input: page with text_units (each has bbox, unit_type, text_content, metadata).
Output: list of Section dicts ready for DB insertion.
"""

import unicodedata
import re
from collections import Counter
from typing import List, Dict, Optional, Tuple


# ─── Arabic text utilities ────────────────────────────────────

# Diacritics (tashkeel) range: U+0610–U+061A, U+064B–U+065F, U+0670
_DIACRITICS_RE = re.compile(r'[\u0610-\u061A\u064B-\u065F\u0670]')

def strip_diacritics(text: str) -> str:
    """Remove Arabic diacritical marks (harakat) from text."""
    return _DIACRITICS_RE.sub('', text)


def is_arabic_letter(ch: str) -> bool:
    """Check if a character is a base Arabic letter."""
    return '\u0621' <= ch <= '\u064A' or '\u0671' <= ch <= '\u06FF'


def extract_arabic_letters(text: str) -> List[str]:
    """Extract base Arabic letters from text (no diacritics)."""
    clean = strip_diacritics(text)
    return [ch for ch in clean if is_arabic_letter(ch)]


def count_chars(text: str) -> int:
    """Count meaningful characters (Arabic letters only, no diacritics/spaces)."""
    return len(extract_arabic_letters(text))


def has_diacritics(text: str) -> bool:
    """Check if text contains any Arabic diacritical marks."""
    return bool(_DIACRITICS_RE.search(text))


# ─── Title generation ──────────────────────────────────────

_LETTER_NAMES_UZ = {
    'ا': 'Alif', 'ب': 'Bo', 'ت': 'To', 'ث': 'So',
    'ج': 'Jim', 'ح': 'Ha', 'خ': 'Xo', 'د': 'Dal',
    'ذ': 'Zol', 'ر': 'Ro', 'ز': 'Zayn', 'س': 'Sin',
    'ش': 'Shin', 'ص': 'Sod', 'ض': 'Zod', 'ط': 'To',
    'ظ': 'Zo', 'ع': 'Ayn', 'غ': 'G\'ayn', 'ف': 'Fo',
    'ق': 'Qof', 'ك': 'Kof', 'ل': 'Lom', 'م': 'Mim',
    'ن': 'Nun', 'ه': 'Ho', 'و': 'Vov', 'ي': 'Yo',
    'ک': 'Kof', 'ی': 'Yo',
}


def _generate_titles(section_type: str, target_letter: Optional[str]) -> Tuple[str, str]:
    """Generate Arabic and Uzbek titles for a section."""
    if section_type == 'opening_sentence':
        return ('بسم الله', 'Bismillah')
    if section_type == 'alphabet_grid':
        return ('الحروف', 'Alifbo')
    if section_type == 'divider':
        return ('', '')

    letter_ar = target_letter or ''
    letter_uz = _LETTER_NAMES_UZ.get(target_letter or '', target_letter or '')

    if section_type == 'letter_introduction':
        return (f'حرف {letter_ar}', f'{letter_uz} harfi')
    if section_type == 'letter_drill':
        return (f'تمرين {letter_ar}', f'{letter_uz} mashqi')
    if section_type == 'word_drill':
        return (f'كلمات {letter_ar}', f'{letter_uz} so\'zlari')

    return (letter_ar, letter_uz or 'Bo\'lim')


# ─── Y-axis segmentation ──────────────────────────────────

def _segment_by_y_axis(units: List[dict], gap_threshold: float = 5.0) -> List[List[dict]]:
    """
    Split units into vertical blocks by detecting Y-axis gaps.
    
    Args:
        units: list of unit dicts with bbox_y, bbox_h, unit_type
        gap_threshold: minimum Y-gap (%) between clusters to split
        
    Returns:
        list of blocks (each block is a list of units)
    """
    if not units:
        return []

    # Sort by Y position
    sorted_units = sorted(units, key=lambda u: u['bbox_y'])
    
    blocks = []
    current_block = [sorted_units[0]]
    
    for i in range(1, len(sorted_units)):
        prev = sorted_units[i - 1]
        curr = sorted_units[i]
        
        prev_bottom = prev['bbox_y'] + prev['bbox_h']
        curr_top = curr['bbox_y']
        gap = curr_top - prev_bottom
        
        # Check for explicit divider units
        is_divider = curr.get('unit_type') == 'divider'
        
        if gap > gap_threshold or is_divider:
            if is_divider:
                # Save current block, add divider as its own block, start new
                if current_block:
                    blocks.append(current_block)
                blocks.append([curr])
                current_block = []
            else:
                blocks.append(current_block)
                current_block = [curr]
        else:
            current_block.append(curr)
    
    if current_block:
        blocks.append(current_block)
    
    return blocks


# ─── Block classification ──────────────────────────────────

def _classify_block(block: List[dict], block_index: int, total_blocks: int) -> str:
    """
    Classify a block of units into a section type.
    
    Heuristics (priority order):
    1. Divider — single divider-type unit
    2. Opening sentence — single long sentence at top of page
    3. Alphabet grid — many similar-sized letter units
    4. Letter introduction — 1-3 large single-letter units
    5. Letter drill — single letters with diacritics
    6. Word drill — multi-letter tokens
    7. Generic fallback
    """
    if not block:
        return 'generic'
    
    # 1. Divider
    if len(block) == 1 and block[0].get('unit_type') == 'divider':
        return 'divider'
    
    unit_types = [u.get('unit_type', 'letter') for u in block]
    texts = [u.get('text_content', '') for u in block]
    char_counts = [count_chars(t) for t in texts]
    
    sentence_count = unit_types.count('sentence')
    letter_count = unit_types.count('letter')
    word_count = unit_types.count('word')
    
    total = len(block)
    
    # 2. Opening sentence — single sentence at top
    if block_index == 0 and sentence_count >= 1 and total <= 3:
        avg_len = sum(len(t) for t in texts) / max(total, 1)
        if avg_len > 10:
            return 'opening_sentence'
    
    # 3. Alphabet grid — many similar-sized letters
    if letter_count >= 14:
        # Check if heights are similar (grid pattern)
        heights = [u['bbox_h'] for u in block if u.get('unit_type') == 'letter']
        if heights:
            avg_h = sum(heights) / len(heights)
            similar = sum(1 for h in heights if abs(h - avg_h) / max(avg_h, 0.01) < 0.3)
            if similar / len(heights) > 0.7:
                return 'alphabet_grid'

    # 4. Letter introduction — 1-3 large single letters
    if total <= 5:
        single_letters = [u for u in block if count_chars(u.get('text_content', '')) == 1]
        if single_letters and len(single_letters) >= total * 0.5:
            heights = [u['bbox_h'] for u in single_letters]
            max_h = max(heights) if heights else 0
            if max_h > 3.0:  # Large letter (>3% of page height)
                return 'letter_introduction'
    
    # 5. Letter drill — single letters with diacritics
    if letter_count >= total * 0.5 or total >= 3:
        diacritical_count = sum(1 for t in texts if has_diacritics(t) and count_chars(t) <= 2)
        if diacritical_count >= total * 0.4:
            return 'letter_drill'
    
    # 6. Word drill — multi-letter tokens
    if word_count >= total * 0.3 or total >= 2:
        multi_letter = sum(1 for c in char_counts if 2 <= c <= 6)
        if multi_letter >= total * 0.4:
            return 'word_drill'
    
    # 7. Fallback: check if mostly single letters without diacritics  
    if letter_count >= total * 0.6:
        return 'letter_drill'

    return 'generic'


# ─── Target letter extraction ──────────────────────────────

def _extract_target_letter(block: List[dict], section_type: str) -> Optional[str]:
    """Extract dominant/target letter from a block via majority vote."""
    if section_type in ('opening_sentence', 'divider', 'alphabet_grid'):
        return None
    
    all_letters = []
    for u in block:
        letters = extract_arabic_letters(u.get('text_content', ''))
        all_letters.extend(letters)
    
    if not all_letters:
        return None
    
    # Majority vote — most frequent letter
    counter = Counter(all_letters)
    most_common = counter.most_common(1)
    if most_common:
        return most_common[0][0]
    
    return None


# ─── Main auto-sectioning function ─────────────────────────

def auto_section_page(
    page_id: int,
    units: List[dict],
    gap_threshold: float = 5.0,
) -> List[dict]:
    """
    Run deterministic auto-sectioning on a page's text units.
    
    Args:
        page_id: page database ID
        units: list of unit dicts (from DB), each with:
            id, unit_type, text_content, bbox_x, bbox_y, bbox_w, bbox_h, sort_order, metadata
        gap_threshold: Y-gap threshold (%) for splitting blocks
        
    Returns:
        list of section dicts ready for DB insertion:
        {
            page_id, section_type, target_letter, title_ar, title_uz,
            sort_order, unit_ids, bbox_y_start, bbox_y_end, is_manual
        }
        
    Guarantees:
        - Every unit appears in exactly one section (no loss, no duplication)
        - Sections ordered by bbox_y_start
        - Deterministic (same input → same output)
    """
    if not units:
        return []
    
    # Step 1: Y-axis segmentation
    blocks = _segment_by_y_axis(units, gap_threshold)
    
    sections = []
    seen_unit_ids = set()
    
    for i, block in enumerate(blocks):
        # Step 2: Classify
        section_type = _classify_block(block, i, len(blocks))
        
        # Step 3: Extract target letter
        target_letter = _extract_target_letter(block, section_type)
        
        # Step 4: Generate titles
        title_ar, title_uz = _generate_titles(section_type, target_letter)
        
        # Collect unit IDs (maintain sort_order)
        block_sorted = sorted(block, key=lambda u: u.get('sort_order', 0))
        unit_ids = [u['id'] for u in block_sorted]
        
        # Fidelity check — no duplicates
        for uid in unit_ids:
            assert uid not in seen_unit_ids, f"Unit {uid} assigned to multiple sections"
            seen_unit_ids.add(uid)
        
        # Compute bounding box
        y_start = min(u['bbox_y'] for u in block)
        y_end = max(u['bbox_y'] + u['bbox_h'] for u in block)
        
        sections.append({
            'page_id': page_id,
            'section_type': section_type,
            'target_letter': target_letter,
            'title_ar': title_ar,
            'title_uz': title_uz,
            'sort_order': i,
            'unit_ids': unit_ids,
            'bbox_y_start': round(y_start, 2),
            'bbox_y_end': round(y_end, 2),
            'is_manual': False,
        })
    
    # Final fidelity check — all units accounted for
    all_unit_ids = {u['id'] for u in units}
    assert seen_unit_ids == all_unit_ids, (
        f"Unit loss detected: missing={all_unit_ids - seen_unit_ids}, "
        f"extra={seen_unit_ids - all_unit_ids}"
    )
    
    return sections
