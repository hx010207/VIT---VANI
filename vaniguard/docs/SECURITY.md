# VaniGuard Platform Security Specification and Threat Model

## 1. System Overview and Core Security Thesis

VaniGuard is a voice-first banking platform engineered to protect elderly and vulnerable users against financial coercion, social engineering scams, and remote digital arrest operations.

### The Security Thesis
Standard financial authentication systems verify biometric identity: *Is this the authorized account holder?*
VaniGuard enforces a higher-order security guarantee: **VaniGuard verifies the psychological and physical freedom of the person behind the voice.**

Even when an attacker has full acoustic possession of the user and commands them to speak authentic credentials, VaniGuard detects micro-tremors of vocal stress, secondary coaching in acoustic pause segments, and lexical manipulation patterns. When detected, the platform intervenes deterministically by pausing the transaction and delegating authorization to an independent, out-of-band guardian device.

---

## 2. Threat Model

### Adversary Capabilities (What the Attacker Controls)
1. **Victim's Physical Device**: The attacker may be on an active phone call, observing the victim, or intimidating them in person.
2. **Victim's Voice Channel**: The attacker can order the victim to speak specific phrases, dictate beneficiary account numbers, or repeat spoken challenge digits.
3. **Victim's Visual UI**: The attacker can instruct the victim on which buttons to press or observe the victim's screen.
4. **Social Engineering Scripts**: The attacker utilizes authority impersonation (CBI, Police, RBI, Customs), manufactured urgency ("immediate digital arrest"), and forced secrecy ("tell nobody").

### Adversary Limitations (Trust Boundaries)
1. **Zero Control of Guardian Device**: The attacker does not possess or control the trusted guardian's remote physical phone or authentication session.
2. **Zero Control of the Banking Core Ledger**: The double-entry ledger is locked behind PostgreSQL Row-Level Security, strict atomic transactions (`FOR UPDATE` row locks), and server-side KMS envelope encryption.
3. **Zero Control of Ephemeral Acoustic Physics**: The attacker cannot eliminate pitch perturbation (jitter), amplitude perturbation (shimmer), or harmonic pause leakage (second voice F0 deviation) from the physical acoustic environment.
4. **No Direct Database or Secret Access**: Server-side secrets (`SUPABASE_SERVICE_ROLE_KEY`, `KMS_MASTER_KEY`, `JWT_SECRET`) are isolated and never transmitted to client devices.

---

## 3. Defense-in-Depth Architecture

```
                                  ADVERSARY DOMAIN
                     [Scammer / Coercer via Phone or In-Person]
                                        │
                                        ▼ (Acoustic Coercion)
                          ┌───────────────────────────┐
                          │    Elder Mobile Device    │
                          │   (Microphone & Client)   │
                          └─────────────┬─────────────┘
                                        │ Real-time Audio Stream (PCM 16kHz)
                                        ▼
      ══════════════════════════ TRUST BOUNDARY ══════════════════════════
                                        │
                         ┌──────────────┴──────────────┐
                         │   VaniGuard Secure Gateway  │
                         │   (FastAPI + ML Worker)     │
                         └──────────────┬──────────────┘
                                        │
             ┌──────────────────────────┼──────────────────────────┐
             ▼                          ▼                          ▼
   [5-Signal Risk Engine]      [Double-Entry Ledger]     [Notification Push]
   - Second Voice (35 pts)     - Paise Integer Math       - WebSocket /ws/events
   - Speaker Mismatch (30 pts) - Idempotency Guard        - Instant Alert Cards
   - Scam Lexicon (25 pts)     - Row-Level Locks          - Live Balance Sync
   - Vocal Stress (20 pts)     - Immutable Audit Log
   - Context Anomaly (20 pts)
             │
             ├──► Score 0-39 (PROCEED): Atomic Settlement
             ├──► Score 40-69 (SOFT_VERIFY): Spoken 6-Digit Liveness Challenge
             └──► Score 70-100 (CIRCUIT_BREAK): Transfer HELD (30-Min Cooling)
                                        │
                                        ▼ (Out-of-Band Push Notification)
                          ┌───────────────────────────┐
                          │   Guardian Mobile Phone   │
                          │ (Isolated Approval Device)│
                          └───────────────────────────┘
```

---

## 4. Invariant Cryptographic and Behavioral Controls

1. **Integer Money Model**:
   - All financial balances and transactions are calculated and stored strictly in integer paise (`BIGINT`). Floating-point currency calculations are forbidden by schema constraint and code policy.
2. **Double-Entry Balance Preservation**:
   - Every financial settlement consists of balanced debit and credit legs executed inside an atomic transaction. Balances across all accounts are mathematically conserved before and after every settlement.
3. **Immutable Audit Trail**:
   - The `audit_log` table is protected by a PostgreSQL database trigger (`trg_audit_log_immutable`) that categorically raises an exception on any `UPDATE` or `DELETE` query. Audit records are permanent and append-only.
4. **KMS Envelope Encryption**:
   - Voice biometric templates are encrypted at application level using AES-256-GCM before database insertion. Raw audio lives in RAM only, is processed in ephemeral chunks, and is purged in under 500 milliseconds.
5. **Guardian Privilege Boundaries**:
   - The Guardian has explicit protective authorities: shortening the cooling window (minimum 5 minutes), pre-approving specific payees for challenge bypass, and approving/denying held transfers.
   - The Guardian cannot disable circuit breaks, alter risk engine scoring weights, or purge audit records.
6. **24-Hour Guardian Change Protection**:
   - A scammer in possession of the victim's phone cannot swap the guardian to an accomplice. Guardian change requests require biometric spoken challenge verification followed by a mandatory 24-hour pending window with push notification to the current guardian.
7. **Fail-Closed Resilience**:
   - If the risk engine or downstream inference models encounter an error mid-session, the transaction automatically fails closed to `SOFT_VERIFY` or `CIRCUIT_BREAK`, never silently completing without verification.
8. **Rate Limiting & Single-Use Challenge Hardening**:
   - Spoken 6-digit challenges expire in exactly 2 minutes and are strictly single-use. Three consecutive failed challenges trigger an automatic protective hold and guardian alert.

---

## 5. Security Incident Reporting and Contact

For security inquiries or vulnerability reports, contact the VaniGuard engineering and security team via the repository maintainers.
