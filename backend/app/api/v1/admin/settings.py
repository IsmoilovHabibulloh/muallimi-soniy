"""Admin settings, feedback, and audit log endpoints."""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.api.deps import get_current_admin
from app.models.admin import AdminUser
from app.models.feedback import FeedbackSubmission
from app.models.system import AuditLog, SystemSettings
from app.schemas.admin import (
    AuditLogOut, SystemSettingOut, SystemSettingUpdate,
    TelegramSettings,
)
from app.schemas.feedback import FeedbackOut
from app.services.telegram import test_telegram_connection

router = APIRouter(tags=["Admin Settings"])


# === Settings ===

@router.get("/settings", response_model=List[SystemSettingOut])
async def get_settings_list(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SystemSettings))
    return result.scalars().all()


@router.put("/settings/{key}", response_model=SystemSettingOut)
async def update_setting(
    key: str,
    data: SystemSettingUpdate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SystemSettings).where(SystemSettings.key == key))
    setting = result.scalar_one_or_none()

    if setting:
        setting.value = data.value
        setting.updated_by = admin.id
    else:
        setting = SystemSettings(key=key, value=data.value, updated_by=admin.id)
        db.add(setting)

    await db.flush()
    db.add(AuditLog(
        admin_id=admin.id, action="update_setting",
        entity_type="system_settings", details={"key": key},
    ))
    return setting


@router.put("/telegram-settings")
async def update_telegram_settings(
    data: TelegramSettings,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update Telegram bot token and chat IDs."""
    for key, value in [("telegram_bot_token", data.bot_token), ("telegram_chat_ids", data.chat_ids)]:
        result = await db.execute(select(SystemSettings).where(SystemSettings.key == key))
        setting = result.scalar_one_or_none()
        if setting:
            setting.value = value
            setting.updated_by = admin.id
        else:
            db.add(SystemSettings(key=key, value=value, updated_by=admin.id))

    await db.flush()
    db.add(AuditLog(
        admin_id=admin.id, action="update_telegram",
        entity_type="system_settings",
    ))
    return {"message": "Telegram sozlamalari yangilandi"}


@router.post("/telegram-test")
async def telegram_test(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Send a test message to configured Telegram chats."""
    success, message = await test_telegram_connection(db)
    return {"success": success, "message": message}


# === Feedback ===

@router.get("/feedback", response_model=List[FeedbackOut])
async def get_feedback_list(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    feedback_type: str = Query(None),
):
    query = select(FeedbackSubmission).order_by(desc(FeedbackSubmission.created_at))
    if feedback_type:
        query = query.where(FeedbackSubmission.feedback_type == feedback_type)
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


# === Audit Log ===

@router.get("/audit-log", response_model=List[AuditLogOut])
async def get_audit_log(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    action: str = Query(None),
):
    query = select(AuditLog).order_by(desc(AuditLog.created_at))
    if action:
        query = query.where(AuditLog.action == action)
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()
