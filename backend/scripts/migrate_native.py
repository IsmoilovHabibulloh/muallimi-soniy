#!/usr/bin/env python3
"""Set all pages to native layout and check text_units counts."""
import asyncio
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import AsyncSessionLocal
from app.models.book import Page, TextUnit
from sqlalchemy import select, func, update

async def migrate():
    async with AsyncSessionLocal() as db:
        # First show current state
        result = await db.execute(
            select(Page.page_number, Page.layout_type)
            .order_by(Page.page_number)
        )
        rows = result.all()
        print(f"Total pages: {len(rows)}")
        for r in rows:
            print(f"  Page {r[0]}: layout={r[1]}")

        # Count text_units per page
        result2 = await db.execute(
            select(Page.page_number, func.count(TextUnit.id))
            .join(TextUnit, TextUnit.page_id == Page.id, isouter=True)
            .group_by(Page.page_number)
            .order_by(Page.page_number)
        )
        counts = result2.all()
        print("\n--- Text Units per Page ---")
        for r in counts:
            print(f"  Page {r[0]}: {r[1]} units")

        # Set all pages to native
        await db.execute(
            update(Page).values(layout_type='native')
        )
        await db.commit()
        print("\n✅ All pages set to layout_type='native'")

asyncio.run(migrate())
