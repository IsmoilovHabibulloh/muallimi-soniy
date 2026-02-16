"""Telegram bot integration service."""

import logging
from typing import Tuple

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.feedback import FeedbackSubmission
from app.models.system import SystemSettings

logger = logging.getLogger("muallimi")

TELEGRAM_API = "https://api.telegram.org"


async def _get_telegram_config(db: AsyncSession) -> Tuple[str, list]:
    """Get Telegram bot token and chat IDs from database settings."""
    result = await db.execute(
        select(SystemSettings).where(SystemSettings.key == "telegram_bot_token")
    )
    token_setting = result.scalar_one_or_none()

    result = await db.execute(
        select(SystemSettings).where(SystemSettings.key == "telegram_chat_ids")
    )
    ids_setting = result.scalar_one_or_none()

    token = token_setting.value if token_setting else ""
    chat_ids = []
    if ids_setting and ids_setting.value:
        chat_ids = [cid.strip() for cid in ids_setting.value.split(",") if cid.strip()]

    return token, chat_ids


async def send_feedback_to_telegram(
    feedback: FeedbackSubmission,
    db: AsyncSession,
) -> bool:
    """Send feedback notification to all configured Telegram chats."""
    token, chat_ids = await _get_telegram_config(db)

    if not token or not chat_ids:
        logger.warning("Telegram not configured, skipping notification")
        return False

    type_label = "📝 Taklif" if feedback.feedback_type == "taklif" else "🐛 Xatolik"

    message = (
        f"🔔 *Yangi fikr-mulohaza*\n\n"
        f"*Turi:* {type_label}\n"
        f"*Ismi:* {_escape_md(feedback.name)}\n"
        f"*Telefon:* {_escape_md(feedback.phone)}\n"
        f"*Tafsilotlar:*\n{_escape_md(feedback.details)}\n\n"
        f"📅 {feedback.created_at.strftime('%Y-%m-%d %H:%M') if feedback.created_at else 'N/A'}"
    )

    success = True
    async with httpx.AsyncClient(timeout=10.0) as client:
        for chat_id in chat_ids:
            try:
                response = await client.post(
                    f"{TELEGRAM_API}/bot{token}/sendMessage",
                    json={
                        "chat_id": chat_id,
                        "text": message,
                        "parse_mode": "Markdown",
                    },
                )
                if response.status_code != 200:
                    logger.error(
                        f"Telegram send failed for chat {chat_id}: "
                        f"{response.status_code} {response.text}"
                    )
                    success = False
            except Exception as e:
                logger.error(f"Telegram error for chat {chat_id}: {e}")
                success = False

    return success


async def test_telegram_connection(db: AsyncSession) -> Tuple[bool, str]:
    """Test Telegram bot connection by sending a test message."""
    token, chat_ids = await _get_telegram_config(db)

    if not token:
        return False, "Bot token sozlanmagan"
    if not chat_ids:
        return False, "Chat ID'lar sozlanmagan"

    test_message = "✅ Muallimi Soniy — Telegram ulanishi muvaffaqiyatli!"

    async with httpx.AsyncClient(timeout=10.0) as client:
        for chat_id in chat_ids:
            try:
                response = await client.post(
                    f"{TELEGRAM_API}/bot{token}/sendMessage",
                    json={"chat_id": chat_id, "text": test_message},
                )
                if response.status_code != 200:
                    return False, f"Chat {chat_id}: {response.text}"
            except Exception as e:
                return False, f"Xatolik: {str(e)}"

    return True, f"{len(chat_ids)} ta chatga muvaffaqiyatli yuborildi"


def _escape_md(text: str) -> str:
    """Escape special Markdown characters."""
    for char in ["_", "*", "[", "]", "(", ")", "~", "`", ">", "#", "+", "-", "=", "|", "{", "}", ".", "!"]:
        text = text.replace(char, f"\\{char}")
    return text
