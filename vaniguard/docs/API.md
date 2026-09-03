# VaniGuard API Reference

The VaniGuard API provides RESTful endpoints for transactional banking, biometric onboarding, trusted contact governance, and administrative auditing, alongside a high-performance WebSocket protocol for real-time conversational voice sessions.

Base URL: `http://localhost:8000/api/v1`

---

## 1. Standard Error Contract

All non-2xx responses adhere to the strict bilingual error format:

```json
{
  "error": {
    "code": "INSUFFICIENT_FUNDS",
    "message": "Account balance is insufficient for this transfer.",
    "user_message_hi": "इस ट्रांसफर के लिए आपके खाते में पर्याप्त शेष राशि नहीं है।",
    "user_message_en": "Your account balance is insufficient to complete this transfer.",
    "request_id": "req-98f98234-a81d-4019-9cf9"
  }
}
```

---

## 2. Authentication & DPDP Compliance

### `POST /auth/session`
Exchanges user phone number and language preference for a session token.
- **Request**: `{"phone": "+919876543210", "preferred_language": "hi"}`
- **Response (200)**: User session object with bearer token.

### `POST /auth/erasure`
Executes the account holder's statutory right to erasure under DPDP Act 2023.
- **Query Param**: `user_id={UUID}`
- **Response (200)**:
```json
{
  "status": "success",
  "message": "Right to erasure executed successfully under DPDP Act 2023.",
  "user_id": "11111111-1111-1111-1111-111111111111",
  "voiceprints_purged": 1,
  "acoustic_baseline_cleared": true,
  "consents_revoked": 2,
  "regulatory_financial_records_retained": true,
  "erased_at": "2026-09-03T18:00:00Z"
}
```

---

## 3. Biometric Onboarding & Voiceprint Enrollment

### `POST /onboarding/enroll`
Submits 3 audio recordings to enroll the user's voice biometric template.
- **Request**: `EnrollmentRequest` containing 3 audio sample arrays.
- **Quality Gates**: Requires >= 3.0s clean speech per phrase and >= 12.0 dB SNR.
- **Response (200)**: `VoiceprintResponse` with encryption key ID and baseline profile.

### `GET /onboarding/status`
Checks enrollment status for a user.

---

## 4. Accounts & Atomic Ledger Transactions

### `GET /accounts`
Lists all active accounts and balances for the authenticated user.

### `GET /transactions`
Retrieves paginated double-entry ledger history with cursor pagination.

### `POST /transfers`
Initiates a transfer under atomic row locking and real-time coercion risk evaluation.
- **Header**: `X-Idempotency-Key: {unique-key}`
- **Request**:
```json
{
  "source_account_id": "22222222-2222-2222-2222-222222222222",
  "payee_id": "44444444-4444-4444-4444-444444444444",
  "amount_paise": 1000000,
  "transcript": "Transfer 10,000 rupees to Rahul Sharma"
}
```
- **Response**:
  - `state == 'COMPLETED'`: Low risk, double-entry settlement committed immediately.
  - `state == 'HELD'`: Coercion risk triggered; 30-minute cooling window established.

---

## 5. Trusted Contact Governance

### `GET /tc/pending`
Returns held transfers for review by the authenticated Trusted Contact. Masked details only (payee name, masked account, amount).

### `POST /tc/transfers/{id}/approve`
Trusted Contact authorizes a held transfer.
- **Request**: `{"attestation": true, "note": "Spoke via phone. Confirmed genuine."}`
- **Constraint**: `attestation` must be `true`. Commits ledger settlement.

### `POST /tc/transfers/{id}/deny`
Trusted Contact rejects a held transfer.
- **Request**: `{"reason_category": "suspected_coercion", "note": "Caller confirmed pressure."}`
- **Effect**: Cancels transfer and safeguards funds.

---

## 6. Voice Challenge-Response Verification

### `POST /voice/challenge`
Generates a random 6-digit challenge code and spoken prompts in English and Hindi.

### `POST /voice/verify-challenge`
Verifies live speech against assigned challenge code, evaluating speaker embedding similarity, digit transcription accuracy, and acoustic liveness.

---

## 7. Real-Time Voice Session WebSocket

- **Endpoint**: `WS /ws/voice-session`
- **Client Messages**:
  - `{"type": "utterance_chunk", "transcript": "...", "audio_samples": [...]}`
  - `{"type": "close"}`
- **Server Events**:
  - `prompt`: Spoken agent instructions in English and Hindi.
  - `final_transcript`: Processed utterance text.
  - `risk_update`: Live score (0-100), decision band, and signal array.
  - `mode_change`: Mode transitions (`normal`, `soft_verify`, `circuit_break`).
  - `session_closed`: Session termination acknowledgment.
