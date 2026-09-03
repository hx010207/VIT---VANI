# VANIGUARD: TEAM HANDOFF DOCUMENT
# Read this fully before touching any code.

## 1. WHAT VANIGUARD IS
Voice-first banking for elderly, visually impaired, and first-time
digital users (Hindi + English). While the user speaks a transaction,
the same voice channel detects coercion in real time. Five signals
produce a 0-100 risk score. Three bands: PROCEED (0-39, settle
atomically), SOFT_VERIFY (40-69, spoken 6-digit challenge), 
CIRCUIT_BREAK (70-100, transfer HELD, 30-min cooling window, Trusted
Contact approves or denies from their own device). We never block and
never auto-complete a dangerous transfer. We pause and bring in a human.

THE ONE-LINE THESIS: Existing systems verify the voice. VaniGuard
verifies the freedom of the person behind it.

## 2. WHAT IS BUILT AND VERIFIED LIVE (do not rebuild any of this)

BACKEND: ALL WORKING, VERIFIED THROUGH REAL HTTP/WS CALLS:
- Supabase PostgreSQL, region ap-northeast-1, 12 tables, RLS on all,
  immutable audit_log (DB trigger rejects UPDATE/DELETE), 188 seeded
  lexicon terms (90 en + 98 hi, deduped), versioned risk_signal_config.
- FastAPI gateway: 25 REST endpoints (not 22, it grew). /health 200,
  sweeper_active: true. Supabase JWT auth via JWKS verified: no token
  401, forged token 401, valid token 200.
- KMS envelope encryption: voiceprints stored as AES-256-GCM BYTEA
  (1040 bytes), key_id kms-v1, per-record IV.
- Double-entry ledger: FOR UPDATE locks, X-Idempotency-Key replay
  safety PROVEN on live DB (replay returned same transfer, balance
  unchanged, still 2 ledger rows).
- Coercion Risk Engine, 5 signals: SECOND_VOICE_DETECTION 35
  (pYIN pitch, 85-255Hz, >=22Hz deviation during user pauses),
  SPEAKER_MISMATCH 30 (ECAPA-TDNN 256-d cosine vs voiceprint,
  threshold 0.68), COERCION_SCRIPT_MATCH 25 (bilingual weighted
  matching: urgency/authority/secrecy/framing), VOCAL_STRESS_INDEX 20
  (jitter/shimmer/pitch vs USER'S OWN baseline: fairness mechanism),
  CONTEXTUAL_ANOMALY 20 (amount vs 90-day pattern, payee age <24h,
  night hours, velocity). CIRCUIT_BREAK_JITTER_RANGE=5 anti-gaming.
  Every score returns full explainability payload with per-signal
  contribution and evidence_summary.
- Cooling sweeper: 15s background thread, auto-cancels expired HELD.
- Right-to-erasure endpoint (DPDP Act 2023), tested.
- WebSocket /ws/voice-session: PCM 16kHz chunks in, typed events out
  (prompt, partial_transcript, final_transcript, risk_update,
  mode_change, challenge_required, transfer_held, session_closed).
- 26/26 automated tests passing (15 original + 3 cooling timestamp + 8 InProcessAsyncQueue).
  8/8 e2e money-path smoke on live DB.
- Worker: arq (Redis) with InProcessAsyncQueue fallback when Redis
  absent. Models loaded ONCE at boot: faster-whisper small int8 +
  ECAPA-TDNN, cold start 7.07s (use persistent worker, never
  per-request loads).

THE FULL LIVE LOOP WAS EXECUTED (session matrix):
- Session A: "What is my balance" + "Transfer 500 rupees to sunita"
  -> score 0, PROCEED, COMPLETED. All five signals explained.
- Session B: urgent transfer with stress -> score 41 (stress +19,
  script +22), SOFT_VERIFY, spoken challenge code 799787 verified
  (liveness ratio 471.9, similarity 1.000), then COMPLETED.
- Session C: "Digital arrest warrant CBI police transfer immediately
  to safe account" for 3000 INR (above 2000 INR TC threshold) ->
  score 78 (second voice +35, stress +18, script +25), CIRCUIT_BREAK,
  HELD, bilingual calm copy delivered, TC denied with attestation
  note, state CANCELLED. Zero rupees moved.

## 3. ENVIRONMENT REALITIES (host machine)
- Python 3.12.13 + uv 0.10.9: working.
- Redis: NOT installed -> InProcessAsyncQueue fallback is active and
  works. Do not assume Redis exists.
- Docker: NOT installed -> native uvicorn + worker. Compose files
  lint-validated only.
- Flutter SDK: 3.44.2 installed. ADB 1.0.41 works. Two physical Android
  phones are the demo target (host RAM only 15.4GB, 2.2GB free -> NO
  emulator, use real devices over USB). Four screens wired to live API
  with offline fallback: enrollment, voice session, held, TC portal.
  API client at app/lib/services/api_client.dart.
- NO MICROPHONE on host -> all prior sessions used LABELED synthetic
  harmonic waveforms. Every real-audio number is still unverified.
- Supabase WAN latency: 2-3s per NEW connection, 9-27s per full
  transfer benchmark. Fix = single-round-trip DB function + connection
  pooling (see GAP 1).

## 4. THE GAP LIST, RANKED (this is the work order)
GAP 1 (CLOSED): Flutter app screens wired to live API via
  app/lib/services/api_client.dart. All 4 critical screens (enrollment,
  voice session, held screen, TC portal) use real microphone, WebSocket,
  and REST calls. Offline fallback active when API unavailable.
  REMAINING: compile and test on physical devices.
GAP 2 (SCRIPT READY): Real-audio validation script created at
  bench/real_audio_validation.py with 4 clip recording prompts.
  bench/clips/ directory created. AWAITING human-recorded clips.
GAP 3 (CODE READY): Transfer latency fix implemented.
  migrations/002_transfer_commit_function.sql: server-side PL/pgSQL
  function reduces settlement from 6-8 WAN queries to 1.
  database.py: asyncpg persistent connection pool added.
  ledger.py: execute_settlement_fast() async fast path added.
  transfers.py: tries fast path first, falls back to multi-query.
  REMAINING: apply migration to live Supabase and benchmark.
GAP 4 (CLOSED): cooling_expires_at verified correct. Uses
  datetime.now(timezone.utc) + timedelta(minutes=30). 3 regression
  tests added in test_cooling_timestamp.py, all passing.
GAP 5 (CLOSED): InProcessAsyncQueue now has 8 dedicated tests
  covering submit/execute, sync handlers, failure propagation, missing
  handlers, lifecycle, concurrency, auto-start, and multi-handler.
  All 8 passing.
GAP 6: Docker runtime unverified (lint only).

## 5. NON-NEGOTIABLE RULES
- No em dashes anywhere in code, docs, or UI copy.
- No marketing words: revolutionary, cutting-edge, seamless,
  game-changing, etc.
- No emojis anywhere.
- Never use the words hackathon, judges, demo, competition in code
  or UI (the pitch deck is separate).
- Honest labeling: any synthetic fixture, estimated number, or
  unmeasured value must be labeled SYNTHETIC/ESTIMATED/NOT YET
  MEASURED. Never invent a number. Never present synthetic results
  as real-world validation.
- Money is paise (integers) only, never floats.
- Raw audio lives in RAM only, purged <500ms, never written to disk.
- No demographic fields may enter the risk engine (schema + runtime
  enforced, tested).
- Secrets: SUPABASE_SERVICE_ROLE_KEY, KMS_MASTER_KEY, JWT_SECRET
  stay server-side only, never in the app, never in git, never in
  logs (log 6-char fingerprints only). The password was rotated once
  after a leak: do not leak it again.
- Every risky change ends with: make test (26/26), /health 200,
  e2e_smoke.py 8/8, cleanup of bench entities (0 leftover rows).

## 6. KEY FILES
- docs/FILE_MAP.md: MUST READ FIRST. One-line map of every file and its purpose.
- server/app/services/risk_engine.py: 5 signals, bands, explainability
- server/app/services/ledger.py: double-entry, locks, idempotency
- worker/dsp.py: VAD, pYIN, jitter/shimmer, second-voice
- worker/providers/: ASR + speaker provider interfaces (pluggable)
- migrations/001_initial_schema.sql: all 12 tables, RLS, trigger
- migrations/002_transfer_commit_function.sql: single-round-trip transfer
- bench/real_audio_validation.py: real-audio validation script
- bench/clips/: directory for human-recorded validation clips
- app/lib/services/api_client.dart: Flutter API client
- bench/e2e_smoke.py: the 8-step live proof
- app/lib/screens/: 9 Flutter screens, Quiet Vault design system
  (deep green #1B4332 on ivory #FAF7F0, brass #B08968 warnings only,
  18sp min text, 64dp touch targets, TTS 0.85x, en+hi .arb files)

## 7. DEMO PLAN (three layers, in order of preference)
1. Live voice on phone: speak a coercive transfer, watch risk monitor
   climb per-signal, transfer holds, TC denies from second phone.
2. Prerecorded real clips streamed through the REAL WebSocket
   pipeline (same code path, no venue-mic risk).
3. NotebookLM video (last resort only).
On-screen footer required: "Prototype operating on synthetic users
and sandbox transactions. Thresholds are demonstration values."

## 8. CIRCUIT-BREAK CALM COPY (exact, mandated, both languages)
EN: "For your safety, we are holding this transfer for a moment.
Take your time. Nothing has left your account. If you are being
pressured by anyone on a call, we can help. You may also confirm
this transfer with your trusted contact."
HI: "आपकी सुरक्षा के लिए, हम इस ट्रांसफर को एक क्षण के लिए रोक रहे
हैं। जल्दी करने की आवश्यकता नहीं है। आपके खाते से अभी कुछ नहीं गया
है। यदि कोई आपको कॉल पर दबाव डाल रहा है, तो हम सहायता कर सकते हैं।"

## 9. NUMBERS TO KEEP CONSISTENT ACROSS ALL DOCS
25 endpoints. 12 tables. 5 signals (35/30/25/20/20). Bands 0-39 /
40-69 / 70-100. 90 en + 98 hi lexicon terms. 26/26 tests. 8/8 e2e.
Speaker threshold 0.68. 256-d embeddings. AES-256-GCM. 30-min
cooling. 6-digit spoken challenge. Audio purged <500ms. Model cold
start 7.07s (fix: persistent worker).
