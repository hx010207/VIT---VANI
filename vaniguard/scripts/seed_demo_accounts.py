# PURPOSE: Idempotent database seeding script for permanent demo accounts (Elder and Guardian).
# ROLE IN SYSTEM: Populates Supabase and DatabaseStore with Asha Sharma (+919876543210) and Priya Sharma (+919876543211).
# TALKS TO: Supabase PostgreSQL, server/app/database.py, HANDOFF.md
import os
import sys
import uuid
import datetime
import hashlib
from pathlib import Path
from dotenv import load_dotenv

# Load environment
vaniguard_dir = Path(__file__).resolve().parent.parent
load_dotenv(vaniguard_dir / ".env")

ELDER_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
ELDER_PHONE = "+919876543210"
ELDER_NAME = "Asha Sharma (Elder)"
ELDER_PASS = "Asha@Demo2026"
ELDER_ACCOUNT_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
ELDER_BALANCE_PAISE = 5000000  # 50,000 INR

GUARDIAN_ID = uuid.UUID("55555555-5555-5555-5555-555555555555")
GUARDIAN_PHONE = "+919876543211"
GUARDIAN_NAME = "Priya Sharma (Guardian)"
GUARDIAN_PASS = "Priya@Demo2026"
GUARDIAN_ACCOUNT_ID = uuid.UUID("77777777-7777-7777-7777-777777777777")
GUARDIAN_BALANCE_PAISE = 2500000  # 25,000 INR

TRUST_ID = uuid.UUID("66666666-6666-6666-6666-666666666666")


def hash_password(password: str, salt: str = None) -> tuple[str, str]:
    if not salt:
        salt = os.urandom(16).hex()
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), bytes.fromhex(salt), 100000)
    return dk.hex(), salt


def generate_payees(user_id: uuid.UUID) -> list[dict]:
    """Generates 100+ realistic Indian contacts, utility billers, and merchants."""
    first_names = [
        "Rahul", "Sunita", "Amit", "Pooja", "Vikram", "Sneha", "Rohan", "Ananya", "Rajesh", "Kavita",
        "Suresh", "Meera", "Deepak", "Ritu", "Manoj", "Shweta", "Arun", "Neha", "Alok", "Preeti",
        "Sanjay", "Nisha", "Gaurav", "Divya", "Vikas", "Aarti", "Ashok", "Swati", "Nitin", "Poonam"
    ]
    last_names = ["Sharma", "Verma", "Gupta", "Malhotra", "Singh", "Patel", "Joshi", "Iyer", "Nair", "Reddy"]
    
    payees = []
    
    # 1. Primary family payee (Son Rahul) - pre-approved / always allow
    son_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
    payees.append({
        "id": son_id,
        "user_id": user_id,
        "name": "Rahul Sharma",
        "masked_account": "...9921",
        "account_ref": "HDFC0001234",
        "nickname": "Son Rahul",
        "verified": True
    })

    # 2. Trusted local chemist / grocery
    payees.append({
        "id": uuid.UUID("44444444-4444-4444-4444-444444444445"),
        "user_id": user_id,
        "name": "Local Chemist & Grocer",
        "masked_account": "...4112",
        "account_ref": "SBIN0004567",
        "nickname": "Apollo Pharmacy",
        "verified": True
    })

    # 3. Essential utility billers
    billers = [
        ("BSES Rajdhani Electricity", "...1001", "BSES-DL-98214", "Electricity Bill"),
        ("Tata Power Delhi Distribution", "...1002", "TPDDL-DL-1102", "Electricity Bill"),
        ("Delhi Jal Board Water", "...1003", "DJB-WATER-4481", "Water Bill"),
        ("Indraprastha Gas Piped Gas", "...1004", "IGL-PNG-88219", "Gas Bill"),
        ("Airtel Postpaid & Broadband", "...1005", "AIRTEL-981100", "Mobile Bill"),
        ("Jio Fiber Broadband", "...1006", "JIO-FIBER-0123", "Broadband Bill"),
        ("Mahanagar Gas Mumbai", "...1007", "MGL-PNG-55123", "Gas Bill"),
        ("BEST Mumbai Electricity", "...1008", "BEST-MUM-8812", "Electricity Bill")
    ]
    for b_name, b_mask, b_ref, b_nick in billers:
        payees.append({
            "id": uuid.uuid5(user_id, b_ref),
            "user_id": user_id,
            "name": b_name,
            "masked_account": b_mask,
            "account_ref": b_ref,
            "nickname": b_nick,
            "verified": True
        })

    # 4. 100 Realistic Personal Contacts
    count = 1
    for f in first_names:
        for l in last_names:
            if len(payees) >= 105:
                break
            full = f"{f} {l}"
            ref = f"UPI{f.lower()}{count}@oksbi"
            mask = f"...{1000 + count}"
            payees.append({
                "id": uuid.uuid5(user_id, ref),
                "user_id": user_id,
                "name": full,
                "masked_account": mask,
                "account_ref": ref,
                "nickname": f,
                "verified": (count % 3 == 0)
            })
            count += 1
        if len(payees) >= 105:
            break

    return payees


def seed_supabase():
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("[WARN] DATABASE_URL not found. Skipping live Supabase seed.")
        return

    import psycopg2
    print(f"Connecting to live Supabase PostgreSQL...")
    conn = psycopg2.connect(db_url)
    conn.autocommit = True

    elder_hash, elder_salt = hash_password(ELDER_PASS)
    guardian_hash, guardian_salt = hash_password(GUARDIAN_PASS)

    with conn.cursor() as cur:
        # 1. Upsert Elder User
        cur.execute("""
            INSERT INTO users (id, phone, full_name, preferred_language, accessibility_prefs, guardian_mode, password_hash, password_salt)
            VALUES (%s, %s, %s, 'hi', '{"high_contrast": false, "screen_reader": true, "speech_rate": 0.85}'::jsonb, TRUE, %s, %s)
            ON CONFLICT (id) DO UPDATE SET
                phone = EXCLUDED.phone,
                full_name = EXCLUDED.full_name,
                guardian_mode = TRUE,
                password_hash = EXCLUDED.password_hash,
                password_salt = EXCLUDED.password_salt;
        """, (str(ELDER_ID), ELDER_PHONE, ELDER_NAME, elder_hash, elder_salt))

        # 2. Upsert Guardian User
        cur.execute("""
            INSERT INTO users (id, phone, full_name, preferred_language, accessibility_prefs, guardian_mode, password_hash, password_salt)
            VALUES (%s, %s, %s, 'en', '{"high_contrast": false, "screen_reader": false, "speech_rate": 1.0}'::jsonb, FALSE, %s, %s)
            ON CONFLICT (id) DO UPDATE SET
                phone = EXCLUDED.phone,
                full_name = EXCLUDED.full_name,
                password_hash = EXCLUDED.password_hash,
                password_salt = EXCLUDED.password_salt;
        """, (str(GUARDIAN_ID), GUARDIAN_PHONE, GUARDIAN_NAME, guardian_hash, guardian_salt))

        # 3. Upsert Accounts
        cur.execute("""
            INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
            VALUES (%s, %s, '...4819', 'SAVINGS', 'INR', %s)
            ON CONFLICT (id) DO UPDATE SET
                balance_paise = EXCLUDED.balance_paise;
        """, (str(ELDER_ACCOUNT_ID), str(ELDER_ID), ELDER_BALANCE_PAISE))

        cur.execute("""
            INSERT INTO accounts (id, user_id, account_number_masked, account_type, currency, balance_paise)
            VALUES (%s, %s, '...8821', 'SAVINGS', 'INR', %s)
            ON CONFLICT (id) DO UPDATE SET
                balance_paise = EXCLUDED.balance_paise;
        """, (str(GUARDIAN_ACCOUNT_ID), str(GUARDIAN_ID), GUARDIAN_BALANCE_PAISE))

        # 4. Upsert Trust Relationship (Priya is Asha's Guardian)
        cur.execute("""
            INSERT INTO trust_relationships (id, account_holder_id, trusted_contact_id, threshold_paise, active, relationship_type, cooling_window_minutes, is_guardian)
            VALUES (%s, %s, %s, 200000, TRUE, 'daughter', 30, TRUE)
            ON CONFLICT (account_holder_id, trusted_contact_id) DO UPDATE SET
                threshold_paise = EXCLUDED.threshold_paise,
                active = TRUE,
                relationship_type = 'daughter',
                cooling_window_minutes = 30,
                is_guardian = TRUE;
        """, (str(TRUST_ID), str(ELDER_ID), str(GUARDIAN_ID)))

        # 5. Pre-approve Son Rahul in always_allow_payees
        son_id = uuid.UUID("44444444-4444-4444-4444-444444444444")
        # Ensure payee exists first
        cur.execute("""
            INSERT INTO payees (id, user_id, name, masked_account, account_ref, nickname, verified)
            VALUES (%s, %s, 'Rahul Sharma', '...9921', 'HDFC0001234', 'Son Rahul', TRUE)
            ON CONFLICT (id) DO NOTHING;
        """, (str(son_id), str(ELDER_ID)))

        cur.execute("""
            INSERT INTO always_allow_payees (account_holder_id, guardian_id, payee_id, active)
            VALUES (%s, %s, %s, TRUE)
            ON CONFLICT (account_holder_id, payee_id) DO NOTHING;
        """, (str(ELDER_ID), str(GUARDIAN_ID), str(son_id)))

        # 6. Seed 100+ Contacts
        payees = generate_payees(ELDER_ID)
        for p in payees:
            cur.execute("""
                INSERT INTO payees (id, user_id, name, masked_account, account_ref, nickname, verified)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    nickname = EXCLUDED.nickname,
                    verified = EXCLUDED.verified;
            """, (str(p["id"]), str(p["user_id"]), p["name"], p["masked_account"], p["account_ref"], p["nickname"], p["verified"]))

    conn.close()
    print("SUCCESS: Live Supabase seeded with permanent demo accounts and 100+ payees!")


def main():
    print("=" * 70)
    print("VANIGUARD DEMO ACCOUNTS SEEDING (IDEMPOTENT)")
    print("=" * 70)

    elder_hash, elder_salt = hash_password(ELDER_PASS)
    guardian_hash, guardian_salt = hash_password(GUARDIAN_PASS)

    print("\n[CREDENTIALS - DEMO RUN SHEET]")
    print(f"1. ELDER (Account Holder)")
    print(f"   Phone:        {ELDER_PHONE} (or +91 98765 43210)")
    print(f"   Password:     {ELDER_PASS}")
    print(f"   Name:         {ELDER_NAME}")
    print(f"   Balance:      {ELDER_BALANCE_PAISE // 100:,} INR ({ELDER_BALANCE_PAISE:,} paise)")
    print(f"   GuardianMode: ON (Cooling window 30 min)")

    print(f"\n2. GUARDIAN (Trusted Contact)")
    print(f"   Phone:        {GUARDIAN_PHONE} (or +91 98765 43211)")
    print(f"   Password:     {GUARDIAN_PASS}")
    print(f"   Name:         {GUARDIAN_NAME}")
    print(f"   Balance:      {GUARDIAN_BALANCE_PAISE // 100:,} INR ({GUARDIAN_BALANCE_PAISE:,} paise)")
    print(f"   Role:         Guardian for {ELDER_NAME}")

    print("\nConnecting to database...")
    seed_supabase()

    print("\nSeeding complete. Credentials are permanently ready for demo runs.")
    print("=" * 70)


if __name__ == "__main__":
    main()
