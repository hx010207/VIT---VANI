-- PURPOSE: Primary PostgreSQL database schema migration establishing tables, triggers, and RLS.
-- ROLE IN SYSTEM: Creates 12 relational tables, double-entry ledger, immutable audit log, and RLS.
-- TALKS TO: PostgreSQL, server/app/database.py, server/app/services/ledger.py
-- VaniGuard Production Postgres Migration 001: Initial Schema
-- Designed for Supabase Postgres with Row Level Security (RLS) and Immutable Audit Logging

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE transfer_state AS ENUM (
    'INITIATED',
    'VOICE_VERIFIED',
    'RISK_SCORED',
    'COMPLETED',
    'HELD',
    'CANCELLED',
    'FAILED'
);

CREATE TYPE risk_band AS ENUM (
    'PROCEED',
    'SOFT_VERIFY',
    'CIRCUIT_BREAK'
);

CREATE TYPE ledger_direction AS ENUM (
    'debit',
    'credit'
);

CREATE TYPE tc_action_type AS ENUM (
    'approve',
    'deny'
);

CREATE TYPE consent_purpose AS ENUM (
    'voiceprint_enrollment',
    'acoustic_analysis',
    'trusted_contact_alerts'
);

-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    phone VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    preferred_language VARCHAR(10) NOT NULL DEFAULT 'hi',
    accessibility_prefs JSONB NOT NULL DEFAULT '{"high_contrast": false, "screen_reader": false, "speech_rate": 0.85}'::jsonb,
    baseline_acoustic_profile JSONB DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Voiceprints Table (App-level AES-256-GCM encrypted embeddings)
CREATE TABLE voiceprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    embedding_encrypted BYTEA NOT NULL,
    encryption_iv BYTEA NOT NULL,
    key_id VARCHAR(64) NOT NULL,
    model_version VARCHAR(64) NOT NULL DEFAULT 'ecapa-tdnn-v1',
    snr_db REAL NOT NULL DEFAULT 15.0,
    clean_speech_duration_sec REAL NOT NULL DEFAULT 3.5,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE INDEX idx_voiceprints_user ON voiceprints(user_id) WHERE active = TRUE;

-- Accounts Table
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    account_number_masked VARCHAR(20) NOT NULL,
    account_type VARCHAR(32) NOT NULL DEFAULT 'SAVINGS',
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    balance_paise BIGINT NOT NULL DEFAULT 0 CHECK (balance_paise >= 0),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_accounts_user ON accounts(user_id);

-- Payees Table
CREATE TABLE payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    masked_account VARCHAR(32) NOT NULL,
    account_ref VARCHAR(64) NOT NULL,
    nickname VARCHAR(100),
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_payees_user ON payees(user_id);

-- Transfers Table
CREATE TABLE transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    source_account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    payee_id UUID NOT NULL REFERENCES payees(id) ON DELETE RESTRICT,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    state transfer_state NOT NULL DEFAULT 'INITIATED',
    risk_score INTEGER CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_band risk_band DEFAULT NULL,
    explainability JSONB DEFAULT '[]'::jsonb,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    cooling_expires_at TIMESTAMPTZ DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    final_at TIMESTAMPTZ DEFAULT NULL
);
CREATE INDEX idx_transfers_user ON transfers(user_id);
CREATE INDEX idx_transfers_state_cooling ON transfers(state, cooling_expires_at) WHERE state = 'HELD';
CREATE INDEX idx_transfers_idempotency ON transfers(idempotency_key);

-- Ledger Entries Table (Double-entry pairs inserted atomically)
CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    direction ledger_direction NOT NULL,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    balance_after_paise BIGINT NOT NULL CHECK (balance_after_paise >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_ledger_transfer ON ledger_entries(transfer_id);
CREATE INDEX idx_ledger_account ON ledger_entries(account_id);

-- Trust Relationships Table
CREATE TABLE trust_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_holder_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trusted_contact_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    threshold_paise BIGINT NOT NULL DEFAULT 500000, -- Default 5000 INR
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ DEFAULT NULL,
    CONSTRAINT check_distinct_users CHECK (account_holder_id != trusted_contact_id),
    CONSTRAINT uq_active_trust UNIQUE (account_holder_id, trusted_contact_id)
);
CREATE INDEX idx_trust_contact ON trust_relationships(trusted_contact_id) WHERE active = TRUE;
CREATE INDEX idx_trust_holder ON trust_relationships(account_holder_id) WHERE active = TRUE;

-- Trusted Contact Actions Table
CREATE TABLE tc_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE RESTRICT,
    trusted_contact_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action tc_action_type NOT NULL,
    attestation BOOLEAN NOT NULL DEFAULT FALSE,
    attested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    note TEXT DEFAULT NULL,
    reason_category VARCHAR(64) DEFAULT NULL
);
CREATE INDEX idx_tc_actions_transfer ON tc_actions(transfer_id);

-- Consent Ledger Table (DPDP Act 2023)
CREATE TABLE consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose consent_purpose NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ DEFAULT NULL,
    version VARCHAR(32) NOT NULL DEFAULT '2024.1',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX idx_consents_user ON consents(user_id, purpose) WHERE revoked_at IS NULL;

-- Immutable Audit Log Table
CREATE TABLE audit_log (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id VARCHAR(128) NOT NULL,
    entity VARCHAR(64) NOT NULL,
    entity_id VARCHAR(128) NOT NULL,
    action VARCHAR(64) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    request_id VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_entity ON audit_log(entity, entity_id);
CREATE INDEX idx_audit_request ON audit_log(request_id);

-- Trigger to enforce append-only audit_log
CREATE OR REPLACE FUNCTION audit_log_immutable_guard()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit log entries are immutable and cannot be updated or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION audit_log_immutable_guard();

-- Scam Lexicon Table
CREATE TABLE scam_lexicon (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language VARCHAR(5) NOT NULL CHECK (language IN ('en', 'hi')),
    term VARCHAR(255) NOT NULL,
    weight INTEGER NOT NULL CHECK (weight >= 1 AND weight <= 30),
    category VARCHAR(64) NOT NULL,
    version VARCHAR(32) NOT NULL DEFAULT 'v1',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_lexicon_term UNIQUE (language, term, version)
);
CREATE INDEX idx_scam_lexicon_lookup ON scam_lexicon(language, active);

-- Risk Signal Config Table
CREATE TABLE risk_signal_config (
    version VARCHAR(32) NOT NULL,
    signal_id VARCHAR(64) NOT NULL,
    weight INTEGER NOT NULL CHECK (weight >= 0 AND weight <= 100),
    threshold REAL NOT NULL DEFAULT 0.5,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (version, signal_id)
);

-- Seed Risk Signal Config
INSERT INTO risk_signal_config (version, signal_id, weight, threshold, active) VALUES
('v1', 'SECOND_VOICE_DETECTION', 35, 0.40, TRUE),
('v1', 'VOCAL_STRESS_INDEX', 20, 0.50, TRUE),
('v1', 'SPEAKER_MISMATCH', 30, 0.65, TRUE),
('v1', 'COERCION_SCRIPT_MATCH', 25, 0.35, TRUE),
('v1', 'CONTEXTUAL_ANOMALY', 20, 0.60, TRUE);

-- Seed English Scam Lexicon (90 terms)
INSERT INTO scam_lexicon (language, term, weight, category, version, active) VALUES
('en', 'immediately', 8, 'urgency', 'v1', TRUE),
('en', 'right now', 8, 'urgency', 'v1', TRUE),
('en', 'within 10 minutes', 10, 'urgency', 'v1', TRUE),
('en', 'within 15 minutes', 10, 'urgency', 'v1', TRUE),
('en', 'within one hour', 7, 'urgency', 'v1', TRUE),
('en', 'urgent transfer', 9, 'urgency', 'v1', TRUE),
('en', 'hurry up', 7, 'urgency', 'v1', TRUE),
('en', 'last chance', 8, 'urgency', 'v1', TRUE),
('en', 'final warning', 9, 'urgency', 'v1', TRUE),
('en', 'immediate arrest', 10, 'urgency', 'v1', TRUE),
('en', 'immediate deportation', 10, 'urgency', 'v1', TRUE),
('en', 'time is running out', 7, 'urgency', 'v1', TRUE),
('en', 'do not delay', 8, 'urgency', 'v1', TRUE),
('en', 'without any delay', 8, 'urgency', 'v1', TRUE),
('en', 'penalty timer', 8, 'urgency', 'v1', TRUE),
('en', 'before the clock runs out', 7, 'urgency', 'v1', TRUE),
('en', 'account closing soon', 9, 'urgency', 'v1', TRUE),
('en', 'freeze in 5 minutes', 10, 'urgency', 'v1', TRUE),
('en', 'instant verification needed', 8, 'urgency', 'v1', TRUE),
('en', 'critical deadline', 7, 'urgency', 'v1', TRUE),
('en', 'pay immediately', 9, 'urgency', 'v1', TRUE),
('en', 'act now', 6, 'urgency', 'v1', TRUE),
('en', 'enforcement directorate', 10, 'authority', 'v1', TRUE),
('en', 'ED', 9, 'authority', 'v1', TRUE),
('en', 'cbi', 10, 'authority', 'v1', TRUE),
('en', 'central bureau of investigation', 10, 'authority', 'v1', TRUE),
('en', 'police headquarters', 9, 'authority', 'v1', TRUE),
('en', 'cyber crime police', 9, 'authority', 'v1', TRUE),
('en', 'cyber cell', 8, 'authority', 'v1', TRUE),
('en', 'arrest warrant', 10, 'authority', 'v1', TRUE),
('en', 'fir registered', 9, 'authority', 'v1', TRUE),
('en', 'account freeze order', 10, 'authority', 'v1', TRUE),
('en', 'court summons', 8, 'authority', 'v1', TRUE),
('en', 'supreme court order', 9, 'authority', 'v1', TRUE),
('en', 'rbi vigilance officer', 10, 'authority', 'v1', TRUE),
('en', 'reserve bank of india', 7, 'authority', 'v1', TRUE),
('en', 'income tax department', 8, 'authority', 'v1', TRUE),
('en', 'narcotics control bureau', 10, 'authority', 'v1', TRUE),
('en', 'ncb officer', 10, 'authority', 'v1', TRUE),
('en', 'customs seizure', 9, 'authority', 'v1', TRUE),
('en', 'anti terror squad', 10, 'authority', 'v1', TRUE),
('en', 'dcp crime branch', 10, 'authority', 'v1', TRUE),
('en', 'inspector in charge', 8, 'authority', 'v1', TRUE),
('en', 'legal notice issued', 8, 'authority', 'v1', TRUE),
('en', 'digital arrest', 10, 'authority', 'v1', TRUE),
('en', 'police custody', 9, 'authority', 'v1', TRUE),
('en', 'surrender immediately', 9, 'authority', 'v1', TRUE),
('en', 'do not disconnect', 10, 'secrecy', 'v1', TRUE),
('en', 'keep the call active', 9, 'secrecy', 'v1', TRUE),
('en', 'keep your phone on', 9, 'secrecy', 'v1', TRUE),
('en', 'stay on the line', 8, 'secrecy', 'v1', TRUE),
('en', 'do not tell your family', 10, 'secrecy', 'v1', TRUE),
('en', 'do not tell anyone', 10, 'secrecy', 'v1', TRUE),
('en', 'confidential protocol', 8, 'secrecy', 'v1', TRUE),
('en', 'secret investigation', 10, 'secrecy', 'v1', TRUE),
('en', 'official secrecy act', 9, 'secrecy', 'v1', TRUE),
('en', 'do not talk to bank staff', 10, 'secrecy', 'v1', TRUE),
('en', 'do not visit the branch', 10, 'secrecy', 'v1', TRUE),
('en', 'lock your room', 9, 'secrecy', 'v1', TRUE),
('en', 'isolate yourself', 9, 'secrecy', 'v1', TRUE),
('en', 'close the doors', 8, 'secrecy', 'v1', TRUE),
('en', 'stay alone', 8, 'secrecy', 'v1', TRUE),
('en', 'do not consult your lawyer', 9, 'secrecy', 'v1', TRUE),
('en', 'do not reveal to children', 9, 'secrecy', 'v1', TRUE),
('en', 'mute other incoming calls', 8, 'secrecy', 'v1', TRUE),
('en', 'strictly confidential audit', 8, 'secrecy', 'v1', TRUE),
('en', 'private clearance', 7, 'secrecy', 'v1', TRUE),
('en', 'verification account', 10, 'unusual_framing', 'v1', TRUE),
('en', 'safe account', 10, 'unusual_framing', 'v1', TRUE),
('en', 'secure govt account', 10, 'unusual_framing', 'v1', TRUE),
('en', 'rbi verification account', 10, 'unusual_framing', 'v1', TRUE),
('en', 'temporary escrow holding', 9, 'unusual_framing', 'v1', TRUE),
('en', 'refund clearing account', 9, 'unusual_framing', 'v1', TRUE),
('en', 'security deposit transfer', 9, 'unusual_framing', 'v1', TRUE),
('en', 'unfreeze deposit', 9, 'unusual_framing', 'v1', TRUE),
('en', 'anti money laundering clearance', 9, 'unusual_framing', 'v1', TRUE),
('en', 'bail deposit', 10, 'unusual_framing', 'v1', TRUE),
('en', 'penalty clearing pool', 8, 'unusual_framing', 'v1', TRUE),
('en', 'clearing pool transfer', 8, 'unusual_framing', 'v1', TRUE),
('en', 'temporary holding account', 9, 'unusual_framing', 'v1', TRUE),
('en', 'protection wallet', 8, 'unusual_framing', 'v1', TRUE),
('en', 'fund security test', 8, 'unusual_framing', 'v1', TRUE),
('en', 'money routing test', 8, 'unusual_framing', 'v1', TRUE),
('en', 'reserve bank transit', 9, 'unusual_framing', 'v1', TRUE),
('en', 'audit deposit', 8, 'unusual_framing', 'v1', TRUE),
('en', 'temporary bond payment', 9, 'unusual_framing', 'v1', TRUE),
('en', 'customs clearance penalty', 9, 'unusual_framing', 'v1', TRUE),
('en', 'do not visit the bank branch', 10, 'secrecy', 'v1', TRUE),
('en', 'security verification deposit', 10, 'unusual_framing', 'v1', TRUE),
('en', 'terminated in 5 minutes', 9, 'urgency', 'v1', TRUE)
ON CONFLICT (language, term, version) DO NOTHING;

-- Seed Hindi Scam Lexicon (99 terms)
INSERT INTO scam_lexicon (language, term, weight, category, version, active) VALUES
('hi', 'तुरंत', 8, 'urgency', 'v1', TRUE),
('hi', 'अभी के अभी', 9, 'urgency', 'v1', TRUE),
('hi', 'दस मिनट के अंदर', 10, 'urgency', 'v1', TRUE),
('hi', 'पंद्रह मिनट में', 9, 'urgency', 'v1', TRUE),
('hi', 'एक घंटे में', 7, 'urgency', 'v1', TRUE),
('hi', 'जल्दी करो', 8, 'urgency', 'v1', TRUE),
('hi', 'अंतिम मौका', 8, 'urgency', 'v1', TRUE),
('hi', 'आखरी चेतावनी', 9, 'urgency', 'v1', TRUE),
('hi', 'तुरंत गिरफ्तारी', 10, 'urgency', 'v1', TRUE),
('hi', 'समय खत्म हो रहा है', 8, 'urgency', 'v1', TRUE),
('hi', 'देरी मत करो', 8, 'urgency', 'v1', TRUE),
('hi', 'बिना किसी देरी के', 8, 'urgency', 'v1', TRUE),
('hi', 'खाता अभी बंद हो जाएगा', 9, 'urgency', 'v1', TRUE),
('hi', 'पांच मिनट में ब्लॉक', 10, 'urgency', 'v1', TRUE),
('hi', 'तुरंत सत्यापन', 8, 'urgency', 'v1', TRUE),
('hi', 'तुरंत पैसा भेजो', 9, 'urgency', 'v1', TRUE),
('hi', 'turant', 8, 'urgency', 'v1', TRUE),
('hi', 'abhi ke abhi', 9, 'urgency', 'v1', TRUE),
('hi', 'jaldi karo', 8, 'urgency', 'v1', TRUE),
('hi', 'aakhri mauka', 8, 'urgency', 'v1', TRUE),
('hi', 'deri mat karo', 8, 'urgency', 'v1', TRUE),
('hi', 'paanch minute mein', 9, 'urgency', 'v1', TRUE),
('hi', 'प्रवर्तन निदेशालय', 10, 'authority', 'v1', TRUE),
('hi', 'ईडी', 9, 'authority', 'v1', TRUE),
('hi', 'सीबीआई', 10, 'authority', 'v1', TRUE),
('hi', 'पुलिस मुख्यालय', 9, 'authority', 'v1', TRUE),
('hi', 'साइबर क्राइम पुलिस', 9, 'authority', 'v1', TRUE),
('hi', 'साइबर सेल', 8, 'authority', 'v1', TRUE),
('hi', 'गिरफ्तारी वारंट', 10, 'authority', 'v1', TRUE),
('hi', 'एफआईआर दर्ज', 9, 'authority', 'v1', TRUE),
('hi', 'खाता फ्रीज आदेश', 10, 'authority', 'v1', TRUE),
('hi', 'कोर्ट समन', 8, 'authority', 'v1', TRUE),
('hi', 'सुप्रीम कोर्ट का आदेश', 9, 'authority', 'v1', TRUE),
('hi', 'आरबीआई अधिकारी', 10, 'authority', 'v1', TRUE),
('hi', 'रिजर्व बैंक ऑफ इंडिया', 7, 'authority', 'v1', TRUE),
('hi', 'आयकर विभाग', 8, 'authority', 'v1', TRUE),
('hi', 'नारकोटिक्स विभाग', 10, 'authority', 'v1', TRUE),
('hi', 'कस्टम जब्ती', 9, 'authority', 'v1', TRUE),
('hi', 'एंटी टेरर स्क्वाड', 10, 'authority', 'v1', TRUE),
('hi', 'क्राइम ब्रांच डीसीपी', 10, 'authority', 'v1', TRUE),
('hi', 'थाना प्रभारी', 8, 'authority', 'v1', TRUE),
('hi', 'कानूनी नोटिस', 8, 'authority', 'v1', TRUE),
('hi', 'डिजिटल अरेस्ट', 10, 'authority', 'v1', TRUE),
('hi', 'पुलिस हिरासत', 9, 'authority', 'v1', TRUE),
('hi', 'आत्मसमर्पण करो', 9, 'authority', 'v1', TRUE),
('hi', 'giraftari warrant', 10, 'authority', 'v1', TRUE),
('hi', 'khata freeze', 9, 'authority', 'v1', TRUE),
('hi', 'cyber crime thana', 9, 'authority', 'v1', TRUE),
('hi', 'digital arrest', 10, 'authority', 'v1', TRUE),
('hi', 'फोन मत काटना', 10, 'secrecy', 'v1', TRUE),
('hi', 'कॉल चालू रखो', 9, 'secrecy', 'v1', TRUE),
('hi', 'फोन डिस्कनेक्ट मत करो', 10, 'secrecy', 'v1', TRUE),
('hi', 'लाइन पर बने रहो', 8, 'secrecy', 'v1', TRUE),
('hi', 'परिवार को मत बताना', 10, 'secrecy', 'v1', TRUE),
('hi', 'किसी को मत बताना', 10, 'secrecy', 'v1', TRUE),
('hi', 'गोपनीय प्रक्रिया', 8, 'secrecy', 'v1', TRUE),
('hi', 'गुप्त जांच', 10, 'secrecy', 'v1', TRUE),
('hi', 'सरकारी गोपनीयता कानून', 9, 'secrecy', 'v1', TRUE),
('hi', 'बैंक वालों से बात मत करो', 10, 'secrecy', 'v1', TRUE),
('hi', 'ब्रांच में मत जाना', 10, 'secrecy', 'v1', TRUE),
('hi', 'कमरा बंद कर लो', 9, 'secrecy', 'v1', TRUE),
('hi', 'अकेले बैठो', 9, 'secrecy', 'v1', TRUE),
('hi', 'दरवाजा बंद रखो', 8, 'secrecy', 'v1', TRUE),
('hi', 'वकील से बात मत करो', 9, 'secrecy', 'v1', TRUE),
('hi', 'बच्चों को मत बताना', 9, 'secrecy', 'v1', TRUE),
('hi', 'दूसरा फोन म्यूट करो', 8, 'secrecy', 'v1', TRUE),
('hi', 'phone mat kaatna', 10, 'secrecy', 'v1', TRUE),
('hi', 'kisi ko mat batana', 10, 'secrecy', 'v1', TRUE),
('hi', 'kamra band kar lo', 9, 'secrecy', 'v1', TRUE),
('hi', 'bank walo ko mat batana', 10, 'secrecy', 'v1', TRUE),
('hi', 'gupt jaanch', 9, 'secrecy', 'v1', TRUE),
('hi', 'सत्यापन खाता', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सुरक्षित खाता', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सुरक्षित खाते', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सरकारी सुरक्षित खाता', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सरकारी सुरक्षित खाते', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'आरबीआई सत्यापन खाता', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सत्यापन खाता', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'सत्यापन खाते', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'अस्थायी एस्क्रो खाता', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'रिफंड क्लियरिंग खाता', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'सुरक्षा जमा ट्रांसफर', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'अनफ्रीज शुल्क जमा', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'एंटी मनी लॉन्ड्रिंग क्लीयरेंस', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'जमानत जमा राशि', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'पेनाल्टी क्लीयरिंग पूल', 8, 'unusual_framing', 'v1', TRUE),
('hi', 'अस्थायी होल्डिंग खाता', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'फंड सुरक्षा परीक्षण', 8, 'unusual_framing', 'v1', TRUE),
('hi', 'मनी रूटिंग टेस्ट', 8, 'unusual_framing', 'v1', TRUE),
('hi', 'कस्टम क्लीयरेंस पेनाल्टी', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'surakshit khata', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'satyapan khata', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'rbi verification khata', 10, 'unusual_framing', 'v1', TRUE),
('hi', 'jamanaat rashi', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'unfreeze deposit', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'बैंक वालों को मत बताना', 10, 'secrecy', 'v1', TRUE),
('hi', 'क्लियरिंग पूल', 9, 'unusual_framing', 'v1', TRUE),
('hi', 'फोन चालू रखो', 9, 'secrecy', 'v1', TRUE),
('hi', 'line par bane raho', 9, 'secrecy', 'v1', TRUE)
ON CONFLICT (language, term, version) DO NOTHING;

-- Row Level Security (RLS) Declarations
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE voiceprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE payees ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE tc_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE scam_lexicon ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_signal_config ENABLE ROW LEVEL SECURITY;

-- 1. Users policies
CREATE POLICY users_self_read ON users
    FOR SELECT TO authenticated
    USING (id = auth.uid());

CREATE POLICY users_self_update ON users
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- 2. Voiceprints policies
CREATE POLICY voiceprints_self_read ON voiceprints
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- 3. Accounts policies
CREATE POLICY accounts_self_read ON accounts
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- 4. Payees policies
CREATE POLICY payees_self_manage ON payees
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 5. Transfers policies (Account holder sees own, Trusted contact sees HELD transfers if active relationship exists and threshold met)
CREATE POLICY transfers_self_read ON transfers
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        (
            state = 'HELD' AND
            EXISTS (
                SELECT 1 FROM trust_relationships tr
                WHERE tr.account_holder_id = transfers.user_id
                  AND tr.trusted_contact_id = auth.uid()
                  AND tr.active = TRUE
                  AND transfers.amount_paise >= tr.threshold_paise
            )
        )
    );

CREATE POLICY transfers_self_insert ON transfers
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- 6. Ledger Entries policies
CREATE POLICY ledger_self_read ON ledger_entries
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM accounts a
            WHERE a.id = ledger_entries.account_id
              AND a.user_id = auth.uid()
        )
    );

-- 7. Trust Relationships policies
CREATE POLICY trust_read ON trust_relationships
    FOR SELECT TO authenticated
    USING (account_holder_id = auth.uid() OR trusted_contact_id = auth.uid());

CREATE POLICY trust_holder_manage ON trust_relationships
    FOR ALL TO authenticated
    USING (account_holder_id = auth.uid())
    WITH CHECK (account_holder_id = auth.uid());

-- 8. Trusted Contact Actions policies
CREATE POLICY tc_actions_read ON tc_actions
    FOR SELECT TO authenticated
    USING (
        trusted_contact_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM transfers t
            WHERE t.id = tc_actions.transfer_id
              AND t.user_id = auth.uid()
        )
    );

CREATE POLICY tc_actions_insert ON tc_actions
    FOR INSERT TO authenticated
    WITH CHECK (
        trusted_contact_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM transfers t
            JOIN trust_relationships tr ON tr.account_holder_id = t.user_id
            WHERE t.id = tc_actions.transfer_id
              AND tr.trusted_contact_id = auth.uid()
              AND tr.active = TRUE
              AND t.state = 'HELD'
              AND t.amount_paise >= tr.threshold_paise
        )
    );

-- 9. Consents policies
CREATE POLICY consents_self_manage ON consents
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 10. Audit Log policies (Authenticated users can read their own audit entries; writes restricted to service_role)
CREATE POLICY audit_log_user_read ON audit_log
    FOR SELECT TO authenticated
    USING (actor_id = auth.uid()::text);

-- 11. Scam Lexicon and Config policies (Read-only for authenticated users)
CREATE POLICY scam_lexicon_read ON scam_lexicon
    FOR SELECT TO authenticated
    USING (active = TRUE);

CREATE POLICY risk_signal_config_read ON risk_signal_config
    FOR SELECT TO authenticated
    USING (active = TRUE);
