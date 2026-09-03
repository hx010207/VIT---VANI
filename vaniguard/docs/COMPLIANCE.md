# VaniGuard — Regulatory Compliance and Data Governance Specification

This document details VaniGuard's alignment with the Digital Personal Data Protection (DPDP) Act 2023, Reserve Bank of India (RBI) master directions on digital payment security, and algorithmic fairness standards.

## 1. Digital Personal Data Protection (DPDP) Act 2023 Alignment

### 1.1 Granular, Revocable Consent
Consent is never bundled. During onboarding and within the settings portal, users are provided explicit, independent, and revocable consent toggles for:
1. **Voiceprint Template Enrollment**: Processing speech to create mathematical embedding vectors for identity verification.
2. **Acoustic Session Analysis**: In-memory signal processing of speech-pause segments to detect coercion indicators and vocal stress.
3. **Trusted Contact Alerts**: Transmission of masked transaction summaries to designated family members when safety holds trigger.

All consent state transitions are immutably recorded in the `consents` table with purpose, timestamp, and version metadata.

### 1.2 Data Minimization Architecture
- **In-Memory Audio Processing**: Raw microphone audio is held in volatile memory only during feature extraction and immediately cleared. Raw audio is never persisted to database tables, object storage, or local disk.
- **Mathematical Templates Only**: Stored voiceprints consist solely of 256-dimensional numerical embeddings. Raw voice reconstruction from d-vectors is mathematically intractable.
- **Envelope Encryption**: Embeddings are encrypted at rest using AES-256-GCM with keys managed via an external Key Management Service (KMS) master key.

### 1.3 Right-to-Erasure Protocol
The `/api/v1/auth/erasure` endpoint provides an automated mechanism for account holders to execute their statutory right to erasure.

When triggered:
1. All active and historical encrypted voiceprints are purged from the `voiceprints` table.
2. The user's `baseline_acoustic_profile` is set to null.
3. Active consents are revoked with timestamped records.
4. An immutable audit record is appended to `audit_log`.

### 1.4 Regulatory Data Retention Matrix

| Data Category | Storage Mechanism | Retention Period | Deletion upon Right-to-Erasure | Statutory Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Raw Audio Audio Streams** | Volatile RAM only | Session duration only (deleted upon phrase completion) | Instantaneous / Not retained | DPDP Data Minimization Principle |
| **Voiceprint Embeddings** | AES-256-GCM encrypted BYTEA | Account active duration | **Purged immediately** | DPDP Right-to-Erasure |
| **Baseline Acoustic Metrics** | JSONB profile | Account active duration | **Purged immediately** | DPDP Right-to-Erasure |
| **Double-Entry Financial Ledger** | PostgreSQL tables | 8 years from transaction date | **Retained** | RBI Master Direction / PMLA Section 12 |
| **Audit Log Events** | Append-only PostgreSQL table | 8 years | **Retained** | RBI Digital Payment Security Guidelines |

## 2. RBI Payment Security & Multi-Factor Authentication Alignment

- **Biometric Inherence Factor**: Spoken challenge-response verification satisfies the inherence factor requirement without requiring manual SMS OTPs, which are frequently intercepted or read aloud by coerced elderly victims.
- **Dynamic Risk-Based Authentication**: Automated escalation to Trusted Contact review and cooling-window holds reflects RBI directives encouraging real-time transaction anomaly monitoring.
- **Anti-Coercion Circuit Breaker**: The 30-minute hold ensures funds cannot be irreversibly liquidated during active scam calls, providing a critical window for intervention.

## 3. Algorithmic Fairness and Anti-Bias Guarantees

- **Self-Referenced Baselines**: Vocal stress, pitch variance, and speech cadence are measured exclusively against the account holder's personal baseline established at enrollment.
- **No Population Stereotypes**: The system does not utilize population averages or demographic classifiers.
- **Zero Demographic Inputs**: The risk engine feature schema strictly prohibits age, gender, caste, religion, or demographic proxy inputs. This invariant is validated by continuous automated CI tests (`server/tests/test_fairness_invariants.py`).
