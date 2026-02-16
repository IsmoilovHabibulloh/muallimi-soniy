"""Feedback submission endpoint."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.feedback import FeedbackSubmission
from app.schemas.feedback import FeedbackCreate, FeedbackOut
from app.services.telegram import send_feedback_to_telegram

logger = logging.getLogger("muallimi")

router = APIRouter(prefix="/feedback", tags=["Feedback"])


@router.post("", response_model=FeedbackOut, status_code=201)
async def submit_feedback(
    data: FeedbackCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Submit user feedback. Sends to Telegram if configured."""
    feedback = FeedbackSubmission(
        name=data.name,
        phone=data.phone,
        feedback_type=data.feedback_type,
        details=data.details,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent", "")[:500],
    )
    db.add(feedback)
    await db.flush()

    # Send to Telegram (non-blocking, don't fail the request)
    try:
        success = await send_feedback_to_telegram(feedback, db)
        feedback.telegram_sent = success
        if not success:
            feedback.telegram_error = "Telegram yuborilmadi"
    except Exception as e:
        logger.error(f"Telegram error: {e}")
        feedback.telegram_sent = False
        feedback.telegram_error = str(e)[:500]

    await db.flush()
    return feedback
