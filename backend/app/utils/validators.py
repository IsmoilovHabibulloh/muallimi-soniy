"""Input validators."""

import re
from typing import Optional


def validate_phone(phone: str) -> Optional[str]:
    """Validate and clean phone number. Returns cleaned number or None."""
    cleaned = re.sub(r"[\s\-\(\)]", "", phone)
    if re.match(r"^\+?[0-9]{7,15}$", cleaned):
        return cleaned
    return None


def validate_file_extension(filename: str, allowed: list[str]) -> bool:
    """Check if file has an allowed extension."""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return ext in allowed


def sanitize_filename(filename: str) -> str:
    """Remove potentially dangerous characters from filename."""
    name = re.sub(r"[^\w\-\.]", "_", filename)
    return name[:200]
