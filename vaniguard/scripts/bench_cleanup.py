from server.app.database import get_db_cursor

def cleanup():
    with get_db_cursor(commit=True) as cur:
        cur.execute("""
            DELETE FROM ledger_entries WHERE transfer_id IN (
                SELECT id FROM transfers WHERE user_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%')
            );
            DELETE FROM tc_actions WHERE transfer_id IN (
                SELECT id FROM transfers WHERE user_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%')
            );
            DELETE FROM transfers WHERE user_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%');
            DELETE FROM trust_relationships WHERE account_holder_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%');
            DELETE FROM payees WHERE user_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%');
            DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE full_name LIKE '%Gupta%');
            DELETE FROM users WHERE full_name LIKE '%Gupta%';
            UPDATE accounts SET balance_paise = 5000000 WHERE id = '22222222-2222-2222-2222-222222222222';
            UPDATE accounts SET balance_paise = 100000000 WHERE id = '33333333-3333-3333-3333-333333333333';
        """)
        print("Cleanup completed.")

if __name__ == "__main__":
    cleanup()
