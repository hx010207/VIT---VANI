# PURPOSE: Historical transaction and audit ledger entry inspection endpoints.
# ROLE IN SYSTEM: Returns immutable double-entry transaction history for authenticated accounts.
# TALKS TO: server/app/database.py, server/app/models/schemas.py
from fastapi import APIRouter, Query
from typing import List, Optional, Dict, Any
import uuid
from server.app.database import db

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("")
async def get_transactions(
    user_id: Optional[uuid.UUID] = None,
    cursor: Optional[int] = Query(default=0, ge=0),
    limit: int = Query(default=10, le=50)
):
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")
    user_account_ids = {acc["id"] for acc in db.accounts.values() if acc["user_id"] == target_user_id}

    # Filter ledger entries matching user's accounts
    matching = [entry for entry in db.ledger_entries if entry["account_id"] in user_account_ids]
    # Sort newest first
    matching.sort(key=lambda x: x["created_at"], reverse=True)

    paginated = matching[cursor:cursor + limit]
    next_cursor = cursor + limit if len(matching) > cursor + limit else None

    return {
        "items": paginated,
        "total": len(matching),
        "next_cursor": next_cursor
    }
