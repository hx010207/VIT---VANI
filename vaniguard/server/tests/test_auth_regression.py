# PURPOSE: Integration regression test verifying demo credentials against live Supabase Auth.
# ROLE IN SYSTEM: Guarantees Asha (+919876543210 / Asha@Demo2026) and Priya (+919876543211 / Priya@Demo2026) authenticate over HTTPS.
# TALKS TO: Supabase Auth /auth/v1/token, server/app/config.py
import pytest
import httpx
from server.app.config import settings


@pytest.mark.asyncio
async def test_live_supabase_demo_logins():
    """Verify both seeded demo credentials authenticate directly against live Supabase Auth over HTTPS."""
    anon_headers = {
        "apikey": settings.SUPABASE_ANON_KEY,
        "Content-Type": "application/json"
    }

    async with httpx.AsyncClient() as client:
        # 1. Elder Demo Account (Asha Sharma)
        resp_asha = await client.post(
            f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers=anon_headers,
            json={"email": "asha@vaniguard.org", "password": "Asha@Demo2026"}
        )
        assert resp_asha.status_code == 200, f"Asha login failed: {resp_asha.text}"
        asha_data = resp_asha.json()
        assert "access_token" in asha_data, "No access token returned for Asha"
        assert asha_data["user"]["id"] == "11111111-1111-1111-1111-111111111111"

        # 2. Guardian Demo Account (Priya Sharma)
        resp_priya = await client.post(
            f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers=anon_headers,
            json={"email": "priya@vaniguard.org", "password": "Priya@Demo2026"}
        )
        assert resp_priya.status_code == 200, f"Priya login failed: {resp_priya.text}"
        priya_data = resp_priya.json()
        assert "access_token" in priya_data, "No access token returned for Priya"
        assert priya_data["user"]["id"] == "55555555-5555-5555-5555-555555555555"

        # 3. Verify Asha PostgREST access to accounts with returned JWT
        asha_token = asha_data["access_token"]
        auth_headers = {
            "apikey": settings.SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {asha_token}"
        }
        resp_acc = await client.get(
            f"{settings.SUPABASE_URL}/rest/v1/accounts?user_id=eq.11111111-1111-1111-1111-111111111111",
            headers=auth_headers
        )
        assert resp_acc.status_code == 200, f"PostgREST accounts read failed: {resp_acc.text}"
        accounts = resp_acc.json()
        assert len(accounts) >= 1
        assert accounts[0]["balance_paise"] > 0
