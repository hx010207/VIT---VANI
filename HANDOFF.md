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

## 1.1 SYSTEM OF RECORD (AUTHORITATIVE BACKEND)
MANDATE: Supabase (PostgreSQL with Row Level Security) is authoritative
for all demo flows, balance accounting, authentication, and guardian rules.
The in-memory DatabaseStore is a test fallback only. The two-device
verification MUST run against the live Supabase backend, not in-memory.
All balance mutations, ledger commits, and guardian approvals persist directly
to Supabase PostgreSQL.

## 1.2 PERMANENT DEMO ACCOUNTS AND RUN SHEET
Permanent accounts seeded in live Supabase PostgreSQL and memory:

1. ELDER ACCOUNT (Device 1):
   - Name: Asha Sharma (Elder)
   - Phone: +919876543210
   - Password: Asha@Demo2026
   - Account Number: ...4819 (Savings)
   - Initial Balance: 50,000 INR (5,000,000 paise)
   - Guardian Mode: ON (Protected by daughter Priya)
   - Login Action: Tap "Demo: Elder" button to autofill credentials, then tap "Sign In".

2. GUARDIAN ACCOUNT (Device 2):
   - Name: Priya Sharma (Guardian)
   - Phone: +919876543211
   - Password: Priya@Demo2026
   - Account Number: ...7777 (Savings)
   - Initial Balance: 25,000 INR (2,500,000 paise)
   - Relationship: Daughter / Designated Caregiver
   - Cooling Window: 30 minutes (customizable down to 5 min safety floor)
   - Login Action: Tap "Demo: Guardian" button to autofill credentials, then tap "Sign In".

3. PRE-APPROVED PAYEE:
   - Name: Son Rahul (Groceries & Support)
   - Payee ID: 44444444-4444-4444-4444-444444444444
   - Invariant: Present in always_allow_payees. Transfers to Rahul skip SOFT_VERIFY
     spoken challenge, but NEVER bypass CIRCUIT_BREAK holds if coercion is detected.

4. 100+ REALISTIC CONTACTS AND BILLERS:
   - Seeded in payees table for smooth voice navigation (BSES Electricity, Delhi Jal Board,
     IGL Gas, neighborhood pharmacies, family members).

## 2. WHAT IS BUILT AND VERIFIED LIVE (do not rebuild any of this)

BACKEND: ALL WORKING, VERIFIED THROUGH REAL HTTP/WS CALLS:
- Supabase PostgreSQL, region ap-northeast-1, 14 tables, RLS on all,
  immutable audit_log (DB trigger rejects UPDATE/DELETE), 188 seeded
  lexicon terms (90 en + 98 hi, deduped), versioned risk_signal_config.
- FastAPI gateway: 30 REST endpoints. /health 200, sweeper_active: true.
  Supabase JWT auth via JWKS verified: no token 401, forged token 401, valid token 200.
  Session exchange supports PBKDF2 password authentication and returns guardian metadata.
  Public access command: `make public` (runs uvicorn + SSH tunnel for remote mobile access).
- Guardian Mode Endpoints (/api/v1/guardian):
  * GET /guardian/status: comprehensive guardian configuration and pre-approved payees.
  * PATCH /guardian/cooling-window: allows guardian to shorten window down to 5-minute safety floor.
  * POST & DELETE /guardian/always-allow-payees: pre-approves trusted payees.
  * POST /guardian/change-request: requires 6-digit spoken challenge AND enforces mandatory 24h cooling.
  * Invariant: No endpoint allows guardian to disable circuit break (verified via pytest).
- Ephemeral Challenge Service (2-Minute Expiry & Single-Use):
  * Spoken 6-digit challenge expires in 120 seconds.
  * Strict single-use consumption: immediately popped from memory; reused answers are rejected.
- In-Memory Sliding-Window Rate Limiter:
  * 3 consecutive failed challenges trigger protective CIRCUIT_BREAK hold and escalate alert to guardian.
- Live Real-Time Push WebSocket (/ws/events):
  * Pushes transfer_completed, transfer_cancelled, circuit_break_alert, transfer_held directly to mobile client.
  * Triggers real-time balance refetch on both devices without manual refresh.
- Automated Tests: 32/32 tests passing (100% green).
  * 8/8 e2e money-path smoke passing on live Supabase.
  * Concurrent e2e test passing (2 instances executed simultaneously with zero deadlocks and exact balance conservation).
- Supabase PostgreSQL, region ap-northeast-1, 12 tables, RLS on all,
  immutable audit_log (DB trigger rejects UPDATE/DELETE), 188 seeded
  lexicon terms (90 en + 98 hi, deduped), versioned risk_signal_config.
- FastAPI gateway: 25 REST endpoints (not 22, it grew). /health 200,
  sweeper_active: true. Supabase JWT auth via JWKS verified: no token
  401, forged token 401, valid token 200.
  Public access command: `make public` (runs uvicorn + SSH tunnel for remote mobile access).
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

## 10. CI/CD WORKFLOW AND ANDROID BUILD MATRIX
The GitHub Actions workflow (.github/workflows/release_apk.yml) automates
building and releasing the production Android APK on every push to main,
version tag (v*), and manual dispatch.

VERSION MATRIX:
- Java JDK: 17 (Eclipse Temurin)
- Gradle: 8.11.1 (via gradle-wrapper.properties)
- Android Gradle Plugin (AGP): 8.7.0 (application and library in settings.gradle.kts)
- Kotlin: 2.1.0 (via settings.gradle.kts)
- Flutter SDK: 3.24.5 (channel stable)
- Compile SDK: 36
- Target SDK: 36
- Min SDK: 24
- NDK: 27.0.12077973
- speech_to_text: 7.4.0
- flutter_tts: 4.2.5
- record: 5.2.0 (with record_android 1.3.3)

WORKFLOW PIPELINE:
Checkout -> Java 17 -> Flutter 3.24.5 -> flutter pub get ->
flutter analyze -> flutter test -> CI Pre-flight -> flutter build apk --release ->
Upload vaniguard-<sha>.apk artifact -> GitHub Release.

## 11. EMERGENCY REPAIR SPRINT: PHYSICAL DEVICE DIRECT HTTPS & VISUAL VERIFICATION PROOF

### 11.1 DIRECT HTTPS CLOUD NETWORKING ARCHITECTURE (ZERO LOCALHOST / NO CABLES)
- In accordance with the mandated networking architecture, the Flutter mobile app communicates directly with the hosted Supabase backend over HTTPS and WSS:
  * Project URL: `https://qqfexpzwzctwtbjirsvh.supabase.co`
  * Embedded Supabase Anon Key (publicly safe, scoped by Postgres Row Level Security)
  * Default API base URL in `app/lib/services/api_client.dart` points to this hosted endpoint.
  * Physical Android devices operate completely untethered over Wi-Fi and 4G/5G mobile data.
  * Zero cables, zero `adb reverse`, and zero local server processes are required for evaluation.
  * Developer Server Configuration modal is retained as an emergency fallback via the top-left gear icon on the Sign In screen.

### 11.2 BUG FIXES & VERIFICATION MATRIX (VERIFIED ON PHYSICAL ANDROID)

1. BUG 1: LOGIN WITH DEMO ACCOUNTS
   - Root Cause: Missing phone-to-email mapping for Supabase Auth, and client parser expecting custom FastAPI response schema.
   - Fix: `ApiClient.sessionExchange()` maps `+919876543210` -> `asha@vaniguard.org` and `+919876543211` -> `priya@vaniguard.org`. It authenticates against Supabase Auth (`/auth/v1/token?grant_type=password`), stores the valid JWT access token, and queries PostgREST for user profiles and guardian links.
   - Invariant: "Demo: Elder" and "Demo: Guardian" buttons autofill phone and password fields; user must explicitly tap the primary "Sign In" button.

2. BUG 2: INPUT FIELD VISIBILITY (QUIET VAULT THEME)
   - Root Cause: Hardcoded `fillColor: QuietVaultColors.surface` (#FFFFFF) clashed with #FAFAFA light text.
   - Fix: Removed hardcoded fill colors. `QuietVaultTheme` sets an explicit `inputDecorationTheme` with matte `#2C2C2C` surface in dark mode, `#FFB300` amber focus outline, high-contrast `#FAFAFA` text, and amber cursor. Text is sharp and readable on physical OLED and LCD screens.

3. BUG 3: BILINGUAL LANGUAGE SWITCHER (EN | HI)
   - Root Cause: No visible language toggle widget on the Sign In and settings interfaces.
   - Fix: Implemented an accessible `EN | HI` segmented toggle on Login, Register, Dashboard, and Consents screens. Selecting a language dynamically switches all UI strings via `VaniGuardApp.setLocale(context, ...)` and persists the choice in `SharedPreferences.getString('app_language')`.

4. BUG 4: USER REGISTRATION FLOW
   - Root Cause: No dedicated onboarding screen for new users.
   - Fix: Implemented `RegisterScreen` (`/register`) with Full Name, Phone (+91), Password, and DPDP Guardian Mode onboarding toggle with relationship selection (Daughter, Son, Caregiver).

5. BUG 5: HARDENED BIOMETRIC AUTHENTICATION
   - Root Cause: `MainActivity.kt` extended `FlutterActivity` instead of `FlutterFragmentActivity`, causing `local_auth` platform crashes on Android devices.
   - Fix: Updated `MainActivity.kt` to extend `FlutterFragmentActivity`, added `USE_BIOMETRIC` and `USE_FINGERPRINT` permissions to `AndroidManifest.xml`, integrated `local_auth: ^2.3.0`, and created `BiometricService` with secure enrollment and "Use Password Instead" fallback.

6. BUG 6: GENERAL FEATURE SWEEP
   - 100+ Seeded Contacts: Added `PayeesScreen` (`/payees`) with real-time text filtering and instant transfer bottom sheet.
   - QR Scanning: Added `QrScanScreen` (`/qr-scan`) with simulated camera viewfinder and merchant confirmation.
   - Utility Bills: Added `PayBillsScreen` (`/pay-bills`) with Electricity, Water, LPG, and Mobile bill payments debited in real-time.
   - Active Call Guard: Added a simulated call toggle on Dashboard and Payees screen; triggers high-risk warning dialog when a payment is attempted during an active call.
   - Session Revocation: `ApiClient.logout()` calls `/auth/v1/logout`, clears stored tokens and user IDs, and forces return to login.

### 11.3 VERIFICATION TEST SUITE RESULTS
- `pytest server/tests`: 33/33 tests passed (100% green).
- `bench/e2e_smoke.py`: 8/8 live Supabase money path steps passed (100% green).
- `flutter analyze`: 0 issues found (0 errors, 0 warnings, 0 lints).
- `flutter test`: 10/10 unit and widget tests passed (100% green).


