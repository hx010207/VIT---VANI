-- PURPOSE: Schema enhancements for Guardian Mode, always-allow payees, 24h pending changes, and password hashing.
-- ROLE IN SYSTEM: Extends users and trust_relationships, adds guardian_pending_changes and always_allow_payees with RLS.
-- TALKS TO: PostgreSQL, server/app/database.py, server/app/api/v1/guardian.py

-- 1. Extend Users Table
ALTER TABLE users ADD COLUMN IF NOT EXISTS guardian_mode BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_salt VARCHAR(64) DEFAULT NULL;

-- 2. Extend Trust Relationships Table
ALTER TABLE trust_relationships ADD COLUMN IF NOT EXISTS relationship_type VARCHAR(64) DEFAULT 'caregiver';
ALTER TABLE trust_relationships ADD COLUMN IF NOT EXISTS cooling_window_minutes INTEGER NOT NULL DEFAULT 30;
ALTER TABLE trust_relationships ADD COLUMN IF NOT EXISTS is_guardian BOOLEAN NOT NULL DEFAULT TRUE;

-- 3. Guardian Pending Changes Table (24h Cooling for Guardian Swap/Removal)
CREATE TABLE IF NOT EXISTS guardian_pending_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_holder_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    current_guardian_id UUID REFERENCES users(id) ON DELETE SET NULL,
    proposed_guardian_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(32) NOT NULL CHECK (action IN ('CHANGE', 'REMOVE')),
    challenge_verified BOOLEAN NOT NULL DEFAULT FALSE,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'EXECUTED', 'CANCELLED'))
);

CREATE INDEX IF NOT EXISTS idx_gpc_holder ON guardian_pending_changes(account_holder_id, status);
CREATE INDEX IF NOT EXISTS idx_gpc_effective ON guardian_pending_changes(effective_at) WHERE status = 'PENDING';

-- 4. Always Allow Payees Table (Guardian Pre-Approved Payees)
CREATE TABLE IF NOT EXISTS always_allow_payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_holder_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    guardian_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payee_id UUID NOT NULL REFERENCES payees(id) ON DELETE CASCADE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_always_allow UNIQUE (account_holder_id, payee_id)
);

CREATE INDEX IF NOT EXISTS idx_always_allow_lookup ON always_allow_payees(account_holder_id, payee_id) WHERE active = TRUE;

-- 5. Row-Level Security
ALTER TABLE guardian_pending_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE always_allow_payees ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'guardian_pending_changes' AND policyname = 'gpc_service_role_all'
    ) THEN
        CREATE POLICY gpc_service_role_all ON guardian_pending_changes FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'always_allow_payees' AND policyname = 'aap_service_role_all'
    ) THEN
        CREATE POLICY aap_service_role_all ON always_allow_payees FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;
