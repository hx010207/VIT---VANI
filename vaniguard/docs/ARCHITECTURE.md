# VaniGuard Architecture Specification

VaniGuard is a voice-first secure banking platform engineered for elderly, visually impaired, and first-time digital banking users. It embeds a real-time Coercion Risk Engine directly into voice interactions, safeguarding vulnerable individuals against digital arrest scams, impersonation fraud, and coerced fund transfers.

## 1. System Topology

```
+-------------------------------------------------------------------------+
|                         Flutter Client Application                      |
|  - Accessible Voice UI (Quiet Vault Theme: 18sp base text, >=64dp touch)|
|  - Dual-mode Speech Interaction (Microphone audio streaming + TTS)      |
|  - Real-time Circuit-Break Hold & Safety Cooling UI                     |
+------------------------------------+------------------------------------+
                                     |
                REST / JSON          |  WebSocket (PCM16 Audio Chunks)
          (Idempotent Mutations)     |  (Typed State Events)
                                     v
+------------------------------------+------------------------------------+
|                         FastAPI Backend (Port 8000)                     |
|  - Authentication & DPDP Right-to-Erasure Endpoints                     |
|  - Double-Entry Atomic Ledger Service (Row-Level Locking)               |
|  - Spoken Challenge-Response Generator & Verifier                       |
|  - Cooling Window Sweeper Periodic Task (Auto-expiry)                   |
+-------------------+--------------------------------+--------------------+
                    |                                |
        Task Queue  |                                | Service-Role / RLS
     (Chunk Events) v                                v
+-------------------+----------+        +------------+--------------------+
|         Async Worker         |        |         Supabase Postgres       |
|  - Audio DSP (VAD, SNR, pYIN)|        |  - users, voiceprints (AES-256) |
|  - Second-Voice Detection    |        |  - accounts, payees, transfers  |
|  - Vocal Stress Index        |        |  - ledger_entries (Atomic)      |
|  - Faster-Whisper (int8 CPU) |        |  - trust_relationships, actions |
|  - Speaker Embedding (ECAPA) |        |  - audit_log (Append-only)      |
+------------------------------+        +---------------------------------+
```

## 2. Coercion Detection Risk Engine (The Core IP)

The Coercion Risk Engine computes a transparent, explainable `CoercionRiskScore` (0 to 100) on completed speech chunks.

### 2.1 Acoustic Signals (Worker DSP)
1. **SECOND_VOICE_DETECTION (Weight: 35 points)**
   - Analyzes speech-pause intervals and voiced frames.
   - Detects presence of secondary human voice within the 85 to 255 Hz fundamental frequency band whose pitch deviates by >= 22 Hz from the enrolled speaker's baseline pitch.
   - Flags predatory coaching or forced stand-in actors.
2. **VOCAL_STRESS_INDEX (Weight: 20 points)**
   - Computes fundamental frequency (F0) standard deviation elevation, period-to-period perturbation (jitter), and amplitude variation (shimmer).
   - Invariant: Completely self-referenced against the account holder's personal baseline acoustic profile registered during enrollment.
3. **SPEAKER_MISMATCH (Weight: 30 points)**
   - Computes cosine similarity of unit-normalized 256-dimensional speaker embeddings against the enrolled voiceprint template.
   - Operating threshold: 0.68 cosine similarity. Proportional risk points added below threshold.

### 2.2 Linguistic Signals (Transcript Analysis)
4. **COERCION_SCRIPT_MATCH (Weight: 25 points)**
   - Scans ASR transcript against bilingual scam lexicons (English and Hindi) comprising 85+ weighted terms each.
   - Four distinct categories:
     - Urgency: "immediately", "within 10 minutes", "account closing"
     - Authority: "ED", "CBI", "police", "arrest warrant", "digital arrest"
     - Secrecy: "do not disconnect", "don't tell family", "lock the door"
     - Unusual Framing: "verification account", "safe account", "clearing pool"
   - Word boundary pattern matching prevents substring false positives on common words (e.g. "hundred", "credited").

### 2.3 Session Context Signals
5. **CONTEXTUAL_ANOMALY (Weight: 20 points)**
   - Evaluates transfer amount relative to the user's 90-day transaction distribution.
   - Flags newly added payees (registered < 24 hours).
   - Evaluates night-time transfer hours (00:00 to 05:00 UTC).
   - Detects rapid repeated attempts (> 2 attempts in 10 minutes).

### 2.4 Decision Bands
- **0 to 39: PROCEED** -> Atomic double-entry ledger settlement commits immediately.
- **40 to 69: SOFT_VERIFY** -> Deliberately introduces friction. Spoken challenge-response verification required; assistant slows speech rate to 0.85x with calm reassurance.
- **70 to 100: CIRCUIT_BREAK** -> Transaction held under safety protocol. 30-minute cooling window begins. No money leaves the account. Escalation notification sent to designated Trusted Contact. Account holder can cancel immediately with one tap.

## 3. Double-Entry Atomic Ledger Service

Every fund transfer is processed under strict double-entry ledger bookkeeping:
- A transfer consists of equal debit and credit legs inserted in a single database transaction.
- Account rows are locked (`SELECT ... FOR UPDATE`) during balance verification and mutation, preventing race conditions and negative balances.
- Idempotency is enforced using unique `X-Idempotency-Key` constraints. Replayed requests return the original transaction status.

## 4. Cooling-Window Sweeper Job

To prevent held transfers from remaining in an indeterminate state indefinitely, a background sweeper task executes periodically (every 15 seconds):
- Scans transfers where `state == 'HELD'` and `cooling_expires_at <= now()`.
- Auto-transitions expired transfers to `CANCELLED`.
- Emits structured `COOLING_EXPIRED_AUTO_CANCEL` events to the immutable audit log.

## 5. Multimodal Voice Challenge-Response Verification

When sensitive operations require verification:
1. System generates a random 6-digit challenge code.
2. System speaks and displays the code in both English and Hindi.
3. User speaks the code into the microphone.
4. Tri-factor validation:
   - Voice Biometric Inherence: Speaker embedding cosine similarity >= 0.68.
   - Cognitive Possession: Constrained digit grammar ASR matches the 6-digit sequence.
   - Acoustic Liveness: Spectral distribution verifies natural human vocal dispersion (voice-to-high frequency ratio between 2.0 and 800.0), rejecting loudspeaker playback and synthetic voice artifacts.
