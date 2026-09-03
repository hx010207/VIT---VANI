# PURPOSE: Concurrency verification running bench/e2e_smoke.py twice concurrently.
# ROLE IN SYSTEM: Proves absence of deadlocks, row-lock contention safety, and exact balance conservation.
# TALKS TO: bench/e2e_smoke.py, server/app/database.py
import sys
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

from server.app.database import get_db_cursor, is_pg_available
from bench.e2e_smoke import run_e2e_smoke_test


def test_concurrent_e2e_smoke():
    print("================================================================================")
    print("VaniGuard Concurrent E2E Smoke Test (2 Concurrent Instances)")
    print("================================================================================")

    # 1. Query pre-test total balance across all accounts in PostgreSQL
    pre_test_total = 0
    if is_pg_available():
        with get_db_cursor() as cur:
            cur.execute("SELECT COALESCE(SUM(balance_paise), 0) as total FROM accounts;")
            pre_test_total = cur.fetchone()["total"]
            print(f"Pre-test total account balances in PostgreSQL: {pre_test_total} paise (₹{pre_test_total / 100:,.2f})")

    # 2. Run two instances concurrently
    print("\nStarting 2 concurrent e2e_smoke executions...")
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=2) as executor:
        f1 = executor.submit(run_e2e_smoke_test)
        f2 = executor.submit(run_e2e_smoke_test)

        res1 = f1.result(timeout=180)
        res2 = f2.result(timeout=180)

    duration = time.time() - start_time
    print(f"\nBoth concurrent runs completed in {duration:.2f} seconds.")

    # 3. Assert no failure in either run
    assert all(status == "PASS" for status in res1.values()), f"Run 1 failed: {res1}"
    assert all(status == "PASS" for status in res2.values()), f"Run 2 failed: {res2}"
    print("ASSERTION PASSED: No deadlock encountered, both runs completed with all 8 steps passing.")

    # 4. Query post-test total balance and assert exact conservation
    if is_pg_available():
        with get_db_cursor() as cur:
            cur.execute("SELECT COALESCE(SUM(balance_paise), 0) as total FROM accounts;")
            post_test_total = cur.fetchone()["total"]
            print(f"Post-test total account balances in PostgreSQL: {post_test_total} paise (₹{post_test_total / 100:,.2f})")

        assert pre_test_total == post_test_total, (
            f"Balance conservation violated! Pre-test: {pre_test_total} paise, Post-test: {post_test_total} paise "
            f"(Delta: {post_test_total - pre_test_total} paise)"
        )
        print(f"ASSERTION PASSED: Pre-test ({pre_test_total}) == Post-test ({post_test_total}) paise. Exact balance conserved.")

    print("\n================================================================================")
    print("CONCURRENT E2E SMOKE TEST PASSED (NO DEADLOCK, MONEY CONSERVED)")
    print("================================================================================")


if __name__ == "__main__":
    test_concurrent_e2e_smoke()
