from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
import uuid
from server.app.database import db, is_pg_available, get_db_cursor
from server.app.models.schemas import AccountResponse

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("/me", response_model=List[AccountResponse])
async def get_my_accounts(user_id: Optional[uuid.UUID] = None):
    # Default to primary seeded user if not provided
    target_user_id = user_id or uuid.UUID("11111111-1111-1111-1111-111111111111")
    if is_pg_available():
        try:
            with get_db_cursor() as cur:
                cur.execute("SELECT * FROM accounts WHERE user_id = %s;", (str(target_user_id),))
                rows = cur.fetchall()
                if rows:
                    return [AccountResponse(**dict(r)) for r in rows]
        except Exception:
            pass

    accounts = [
        AccountResponse(
            id=acc["id"],
            user_id=acc["user_id"],
            account_number_masked=acc["account_number_masked"],
            account_type=acc["account_type"],
            currency=acc["currency"],
            balance_paise=acc["balance_paise"],
            opened_at=acc["opened_at"]
        )
        for acc in db.accounts.values()
        if acc["user_id"] == target_user_id
    ]
    return accounts
