# PURPOSE: Structured catalog of purpose headers, roles, dependencies, and documentation summaries.
# ROLE IN SYSTEM: Data dictionary supporting file header automation and verification.
# TALKS TO: scripts/apply_file_headers.py
import sys
from pathlib import Path

HEADERS = {
    # -------------------------------------------------------------------------
    # Server Core & Config
    # -------------------------------------------------------------------------
    "server/app/main.py": (
        "# PURPOSE: FastAPI application entrypoint, middleware configuration, and lifecycle management.\n"
        "# ROLE IN SYSTEM: Boots HTTP/WS server, initializes cooling sweeper loop, mounts API routers.\n"
        "# TALKS TO: server/app/config.py, server/app/api/v1/, server/app/services/sweeper.py\n"
        "# DO NOT CONFUSE WITH: worker/worker.py (background queue processor)\n"
    ),
    "server/app/config.py": (
        "# PURPOSE: Centralized configuration and environment variable validation using Pydantic Settings.\n"
        "# ROLE IN SYSTEM: Loads Supabase URLs, KMS master keys, JWT secrets, thresholds, and band limits.\n"
        "# TALKS TO: server/app/main.py, server/app/database.py, server/app/services/\n"
    ),
    "server/app/database.py": (
        "# PURPOSE: Database connection management and unified fallback layer for PostgreSQL and memory.\n"
        "# ROLE IN SYSTEM: Provides pooled PostgreSQL cursors with thread-safe in-memory mirror fallback.\n"
        "# TALKS TO: server/app/config.py, psycopg2 pool, all API routers and services\n"
        "# DO NOT CONFUSE WITH: server/app/services/ledger.py (ledger domain logic)\n"
    ),
    "server/app/api/deps.py": (
        "# PURPOSE: FastAPI dependency injection for Supabase JWT authentication and JWKS token verification.\n"
        "# ROLE IN SYSTEM: Validates ES256/HS256 tokens and extracts authenticated user identities.\n"
        "# TALKS TO: server/app/config.py, FastAPI endpoints in server/app/api/v1/\n"
    ),
    "server/app/models/schemas.py": (
        "# PURPOSE: Pydantic schemas, request/response models, and enums for all API operations.\n"
        "# ROLE IN SYSTEM: Enforces data contracts, transfer states, risk bands, and explainability payloads.\n"
        "# TALKS TO: server/app/api/v1/, server/app/services/risk_engine.py, worker/providers/\n"
    ),

    # -------------------------------------------------------------------------
    # Server API Routers (v1)
    # -------------------------------------------------------------------------
    "server/app/api/v1/accounts.py": (
        "# PURPOSE: Account balance queries and account summary endpoints.\n"
        "# ROLE IN SYSTEM: Serves authenticated account holder balances in paise and account metadata.\n"
        "# TALKS TO: server/app/database.py, server/app/models/schemas.py, server/app/api/deps.py\n"
    ),
    "server/app/api/v1/admin.py": (
        "# PURPOSE: Administrative configuration and risk signal threshold adjustment endpoints.\n"
        "# ROLE IN SYSTEM: Allows service-role inspection and dynamic tuning of risk signal weights.\n"
        "# TALKS TO: server/app/database.py, server/app/services/risk_engine.py\n"
    ),
    "server/app/api/v1/auth.py": (
        "# PURPOSE: Authentication helper endpoints, JWT token verification, and session inspection.\n"
        "# ROLE IN SYSTEM: Interacts with Supabase Auth JWKS to confirm user session validity.\n"
        "# TALKS TO: server/app/config.py, server/app/api/deps.py\n"
    ),
    "server/app/api/v1/onboarding.py": (
        "# PURPOSE: User onboarding, DPDP consent grants, and 3-phrase voice biometric enrollment.\n"
        "# ROLE IN SYSTEM: Quality-gates voice samples, creates encrypted voiceprints, sets acoustic baseline.\n"
        "# TALKS TO: server/app/services/crypto.py, worker/providers/speaker_provider.py, server/app/database.py\n"
    ),
    "server/app/api/v1/payees.py": (
        "# PURPOSE: Payee registration, nickname lookup, and trusted payee listing endpoints.\n"
        "# ROLE IN SYSTEM: Resolves spoken payee nicknames to account references during voice banking flows.\n"
        "# TALKS TO: server/app/database.py, server/app/models/schemas.py\n"
    ),
    "server/app/api/v1/tc_actions.py": (
        "# PURPOSE: Trusted contact review endpoints for pending held transfers.\n"
        "# ROLE IN SYSTEM: Allows trusted contacts to inspect HELD transfers and submit attested approve/deny.\n"
        "# TALKS TO: server/app/database.py, server/app/services/ledger.py, server/app/services/audit.py\n"
    ),
    "server/app/api/v1/transactions.py": (
        "# PURPOSE: Historical transaction and audit ledger entry inspection endpoints.\n"
        "# ROLE IN SYSTEM: Returns immutable double-entry transaction history for authenticated accounts.\n"
        "# TALKS TO: server/app/database.py, server/app/models/schemas.py\n"
    ),
    "server/app/api/v1/transfers.py": (
        "# PURPOSE: Money transfer initiation, idempotency control, and risk band enforcement.\n"
        "# ROLE IN SYSTEM: Executes atomic double-entry ledger commits or holds high-risk transfers.\n"
        "# TALKS TO: server/app/services/ledger.py, server/app/services/risk_engine.py, server/app/database.py\n"
    ),
    "server/app/api/v1/trusted_contacts.py": (
        "# PURPOSE: Management endpoints for account holder and trusted contact trust relationships.\n"
        "# ROLE IN SYSTEM: Enrolls trusted contacts, sets notification thresholds in paise, and lists links.\n"
        "# TALKS TO: server/app/database.py, server/app/models/schemas.py\n"
    ),
    "server/app/api/v1/voice.py": (
        "# PURPOSE: Spoken challenge-response generation and acoustic liveness verification endpoints.\n"
        "# ROLE IN SYSTEM: Handles 6-digit challenge flow required when risk falls in SOFT_VERIFY band.\n"
        "# TALKS TO: server/app/services/challenge.py, server/app/services/crypto.py, worker/dsp.py\n"
    ),
    "server/app/api/v1/websocket.py": (
        "# PURPOSE: Real-time bidirectional WebSocket voice session router (/ws/voice-session).\n"
        "# ROLE IN SYSTEM: Streams PCM audio, emits partial/final transcripts, risk updates, and mode events.\n"
        "# TALKS TO: server/app/services/risk_engine.py, worker/dsp.py, worker/providers/speaker_provider.py\n"
    ),

    # -------------------------------------------------------------------------
    # Server Services
    # -------------------------------------------------------------------------
    "server/app/services/audit.py": (
        "# PURPOSE: Tamper-evident append-only audit logging service for regulatory compliance.\n"
        "# ROLE IN SYSTEM: Records security events, consent changes, and ledger state transitions.\n"
        "# TALKS TO: server/app/database.py, server/app/config.py\n"
        "# DO NOT CONFUSE WITH: server/app/services/ledger.py (financial money-path ledger)\n"
    ),
    "server/app/services/challenge.py": (
        "# PURPOSE: Ephemeral 6-digit challenge code generator and verification engine.\n"
        "# ROLE IN SYSTEM: Verifies digit transcription matching, acoustic liveness, and speaker similarity.\n"
        "# TALKS TO: worker/dsp.py, worker/providers/speaker_provider.py, server/app/models/schemas.py\n"
    ),
    "server/app/services/crypto.py": (
        "# PURPOSE: Cryptographic service for AES-256-GCM envelope encryption and KMS key derivation.\n"
        "# ROLE IN SYSTEM: Encrypts speaker biometric embeddings before storage and decrypts during verification.\n"
        "# TALKS TO: server/app/config.py, server/app/api/v1/onboarding.py, server/app/api/v1/voice.py\n"
    ),
    "server/app/services/ledger.py": (
        "# PURPOSE: Strict double-entry accounting ledger engine with atomic balance verification.\n"
        "# ROLE IN SYSTEM: Executes transactional debit/credit commits and enforces idempotency replay safety.\n"
        "# TALKS TO: server/app/database.py, server/app/services/audit.py, server/app/models/schemas.py\n"
        "# DO NOT CONFUSE WITH: server/app/services/audit.py (general security audit log)\n"
    ),
    "server/app/services/risk_engine.py": (
        "# PURPOSE: 5-signal coercion risk engine computing 0-100 scores and explainability payloads.\n"
        "# ROLE IN SYSTEM: Evaluates second voice, vocal stress, mismatch, coercion script, and anomalies.\n"
        "# TALKS TO: worker/scam_lexicon.*.json, server/app/models/schemas.py, server/app/api/v1/websocket.py\n"
    ),
    "server/app/services/sweeper.py": (
        "# PURPOSE: Background asynchronous sweeper for expired cooling windows on held transfers.\n"
        "# ROLE IN SYSTEM: Periodically checks HELD transfers and auto-cancels those exceeding 30 minutes.\n"
        "# TALKS TO: server/app/database.py, server/app/services/audit.py, server/app/main.py\n"
        "# DO NOT CONFUSE WITH: worker/worker.py (general distributed job worker)\n"
    ),
    "server/Dockerfile": (
        "# PURPOSE: Multi-stage container definition for the VaniGuard FastAPI gateway service.\n"
        "# ROLE IN SYSTEM: Packages Python 3.12 runtime, dependencies, and Uvicorn server for deployment.\n"
        "# TALKS TO: server/app/main.py, pyproject.toml, docker-compose.yml\n"
    ),

    # -------------------------------------------------------------------------
    # Server Tests
    # -------------------------------------------------------------------------
    "server/tests/conftest.py": (
        "# PURPOSE: Pytest test fixtures, database mocking, and test client configurations.\n"
        "# ROLE IN SYSTEM: Sets up clean in-memory database state and authentication mocks for test suite.\n"
        "# TALKS TO: pytest, server/app/database.py, server/app/main.py\n"
    ),
    "server/tests/test_auth_compliance.py": (
        "# PURPOSE: Unit tests for authentication compliance, token rejection, and JWKS validation.\n"
        "# ROLE IN SYSTEM: Verifies that missing, expired, and forged tokens are rejected with HTTP 401.\n"
        "# TALKS TO: server/app/api/deps.py, server/app/api/v1/auth.py\n"
    ),
    "server/tests/test_fairness_invariants.py": (
        "# PURPOSE: Invariant verification ensuring zero demographic bias in coercion risk scoring.\n"
        "# ROLE IN SYSTEM: Asserts identical scores across simulated demographic attributes given same acoustics.\n"
        "# TALKS TO: server/app/services/risk_engine.py, server/app/models/schemas.py\n"
    ),
    "server/tests/test_ledger.py": (
        "# PURPOSE: Unit tests for double-entry ledger correctness, balance checks, and idempotency.\n"
        "# ROLE IN SYSTEM: Proves money invariants, atomic debit/credit balancing, and duplicate key safety.\n"
        "# TALKS TO: server/app/services/ledger.py, server/app/database.py\n"
    ),
    "server/tests/test_risk_engine.py": (
        "# PURPOSE: Unit tests for the 5-signal risk calculation and decision band boundaries.\n"
        "# ROLE IN SYSTEM: Verifies scoring thresholds for PROCEED (0-39), SOFT_VERIFY (40-69), CIRCUIT_BREAK (70+).\n"
        "# TALKS TO: server/app/services/risk_engine.py, server/app/models/schemas.py\n"
    ),
    "server/tests/test_rls_policies.py": (
        "# PURPOSE: Test suite verifying PostgreSQL Row-Level Security rules and isolation boundaries.\n"
        "# ROLE IN SYSTEM: Confirms users can only read their own financial records and authorized transfers.\n"
        "# TALKS TO: migrations/001_initial_schema.sql, server/app/database.py\n"
    ),
    "server/tests/test_sweeper.py": (
        "# PURPOSE: Unit tests for cooling window expiration and auto-cancellation logic.\n"
        "# ROLE IN SYSTEM: Validates that transfers held beyond 30 minutes are transitioned to CANCELLED.\n"
        "# TALKS TO: server/app/services/sweeper.py, server/app/database.py\n"
    ),

    # -------------------------------------------------------------------------
    # Worker & DSP
    # -------------------------------------------------------------------------
    "worker/__init__.py": (
        "# PURPOSE: Package initialization for background audio processing and ML inference worker.\n"
        "# ROLE IN SYSTEM: Exposes worker module namespaces and shared utility routines.\n"
        "# TALKS TO: worker/worker.py, worker/dsp.py\n"
    ),
    "worker/worker.py": (
        "# PURPOSE: Background asynchronous task runner using ARQ Redis with in-process queue fallback.\n"
        "# ROLE IN SYSTEM: Executes offloaded speech transcription, embedding computation, and risk jobs.\n"
        "# TALKS TO: worker/in_process_queue.py, worker/providers/, worker/dsp.py\n"
        "# DO NOT CONFUSE WITH: server/app/services/sweeper.py (cooling window timeout sweeper)\n"
    ),
    "worker/dsp.py": (
        "# PURPOSE: Digital signal processing algorithms for acoustic analysis and voice metrics.\n"
        "# ROLE IN SYSTEM: Computes SNR, clean speech duration, F0 pitch tracking, jitter, shimmer, and liveness.\n"
        "# TALKS TO: worker/providers/speaker_provider.py, server/app/services/risk_engine.py\n"
    ),
    "worker/prefetch_models.py": (
        "# PURPOSE: Model pre-caching script to warm faster-whisper and ECAPA-TDNN assets at boot.\n"
        "# ROLE IN SYSTEM: Eliminates per-request cold-start latency by downloading and preparing models.\n"
        "# TALKS TO: worker/providers/asr_provider.py, worker/providers/speaker_provider.py\n"
    ),
    "worker/in_process_queue.py": (
        "# PURPOSE: Lightweight asyncio queue providing Redis-compatible job dispatch when Redis is absent.\n"
        "# ROLE IN SYSTEM: Guarantees background worker functionality on hosts lacking a local Redis daemon.\n"
        "# TALKS TO: worker/worker.py, server/app/main.py\n"
    ),
    "worker/providers/__init__.py": (
        "# PURPOSE: Provider interface exports for ASR, speaker biometrics, and TTS implementations.\n"
        "# ROLE IN SYSTEM: Allows swapping between self-hosted CPU models and external cloud API providers.\n"
        "# TALKS TO: worker/providers/asr_provider.py, worker/providers/speaker_provider.py\n"
    ),
    "worker/providers/asr_provider.py": (
        "# PURPOSE: Automated Speech Recognition provider abstract interface and Faster-Whisper adapter.\n"
        "# ROLE IN SYSTEM: Transcribes incoming Hindi and English speech chunks to text with timestamps.\n"
        "# TALKS TO: worker/worker.py, server/app/api/v1/websocket.py\n"
        "# DO NOT CONFUSE WITH: worker/providers/tts_provider.py (speech synthesizer)\n"
    ),
    "worker/providers/speaker_provider.py": (
        "# PURPOSE: Voice biometric provider computing 256-d speaker embeddings and cosine similarities.\n"
        "# ROLE IN SYSTEM: Evaluates enrollment quality gating and speaker identity matching against baseline.\n"
        "# TALKS TO: worker/dsp.py, server/app/services/risk_engine.py, server/app/api/v1/onboarding.py\n"
    ),
    "worker/providers/tts_provider.py": (
        "# PURPOSE: Text-to-Speech synthesis provider interface and calm guidance audio generator.\n"
        "# ROLE IN SYSTEM: Synthesizes prompts and protective bilingual copy for voice banking responses.\n"
        "# TALKS TO: server/app/api/v1/websocket.py, worker/worker.py\n"
        "# DO NOT CONFUSE WITH: worker/providers/asr_provider.py (speech-to-text transcriber)\n"
    ),
    "worker/Dockerfile": (
        "# PURPOSE: Container definition for the background ML inference and audio DSP worker service.\n"
        "# ROLE IN SYSTEM: Packages audio processing libraries, pre-cached models, and ARQ queue processor.\n"
        "# TALKS TO: worker/worker.py, worker/prefetch_models.py, docker-compose.yml\n"
    ),

    # -------------------------------------------------------------------------
    # Benchmarks
    # -------------------------------------------------------------------------
    "bench/bench_challenge_verification.py": (
        "# PURPOSE: Benchmark suite for the 6-digit challenge response verification engine.\n"
        "# ROLE IN SYSTEM: Evaluates constrained digit decoding accuracy and acoustic liveness detection.\n"
        "# TALKS TO: server/app/services/challenge.py, worker/dsp.py\n"
    ),
    "bench/bench_latency_budget.py": (
        "# PURPOSE: End-to-end latency benchmark measuring post-chunk risk and ledger commit timings.\n"
        "# ROLE IN SYSTEM: Reports true p95 timings against live Supabase PostgreSQL ledger.\n"
        "# TALKS TO: server/app/services/ledger.py, server/app/services/risk_engine.py\n"
    ),
    "bench/bench_scam_lexicon.py": (
        "# PURPOSE: Benchmark evaluating coercion script lexicon matching against test utterances.\n"
        "# ROLE IN SYSTEM: Measures keyword recall, weighting accuracy, and false-positive boundaries.\n"
        "# TALKS TO: worker/scam_lexicon.en.json, worker/scam_lexicon.hi.json, server/app/services/risk_engine.py\n"
    ),
    "bench/bench_second_voice_snr.py": (
        "# PURPOSE: Benchmark measuring second voice detection sensitivity across varying noise floors.\n"
        "# ROLE IN SYSTEM: Tests pitch autocorrelation and secondary speaker identification accuracy.\n"
        "# TALKS TO: worker/dsp.py, server/app/services/risk_engine.py\n"
    ),
    "bench/bench_speaker_verification.py": (
        "# PURPOSE: Benchmark measuring speaker verification cosine similarity and threshold stability.\n"
        "# ROLE IN SYSTEM: Verifies true-accept and false-reject rates across enrolled voiceprints.\n"
        "# TALKS TO: worker/providers/speaker_provider.py, server/app/services/crypto.py\n"
    ),
    "bench/e2e_smoke.py": (
        "# PURPOSE: 8-step live integration smoke test validating the complete money and security path.\n"
        "# ROLE IN SYSTEM: Executes end-to-end checks against live Supabase PostgreSQL and authentication.\n"
        "# TALKS TO: server/app/main.py, server/app/services/ledger.py, server/app/database.py\n"
    ),
    "bench/smoke_websocket.py": (
        "# PURPOSE: Lightweight sanity script for validating WebSocket session handshakes and responses.\n"
        "# ROLE IN SYSTEM: Connects to /ws/voice-session and verifies welcome prompt delivery.\n"
        "# TALKS TO: server/app/api/v1/websocket.py\n"
    ),

    # -------------------------------------------------------------------------
    # Scripts
    # -------------------------------------------------------------------------
    "scripts/audit_lexicon.py": (
        "# PURPOSE: Verification utility for auditing coercion lexicon entries for duplicates and weights.\n"
        "# ROLE IN SYSTEM: Ensures scam lexicon integrity across English and Hindi definitions.\n"
        "# TALKS TO: worker/scam_lexicon.en.json, worker/scam_lexicon.hi.json\n"
    ),
    "scripts/dockerfile_lint.py": (
        "# PURPOSE: Static validation tool inspecting Dockerfiles for security and packaging compliance.\n"
        "# ROLE IN SYSTEM: Verifies non-root user execution, cache pinning, and multi-stage build rules.\n"
        "# TALKS TO: server/Dockerfile, worker/Dockerfile\n"
    ),
    "scripts/migrate_supabase.py": (
        "# PURPOSE: Database migration runner applying SQL schemas and seeds to remote Supabase instances.\n"
        "# ROLE IN SYSTEM: Connects to PostgreSQL to execute migrations/001_initial_schema.sql.\n"
        "# TALKS TO: migrations/001_initial_schema.sql, server/app/config.py\n"
    ),
    "scripts/run_live_onboarding.py": (
        "# PURPOSE: Automated runner executing Phase 2 live user onboarding and voice enrollment.\n"
        "# ROLE IN SYSTEM: Verifies Supabase signup, DPDP consents, quality gating, and encrypted storage.\n"
        "# TALKS TO: server/app/api/v1/onboarding.py, server/app/api/v1/payees.py, server/app/database.py\n"
    ),
    "scripts/run_live_voice_sessions.py": (
        "# PURPOSE: Automated runner executing Phase 3 live WebSocket voice sessions and session matrix.\n"
        "# ROLE IN SYSTEM: Tests nominal flow, soft verification challenge, and circuit break with TC deny.\n"
        "# TALKS TO: server/app/api/v1/websocket.py, server/app/api/v1/voice.py, server/app/api/v1/tc_actions.py\n"
    ),
    "scripts/update_schema_seeds.py": (
        "# PURPOSE: Schema seed update utility syncing JSON lexicon files into SQL migration seeds.\n"
        "# ROLE IN SYSTEM: Re-generates SQL insert statements for scam_lexicon from JSON source assets.\n"
        "# TALKS TO: worker/scam_lexicon.*.json, migrations/001_initial_schema.sql\n"
    ),
    "scripts/verify_auth_proof.py": (
        "# PURPOSE: Security verification script proving JWKS token validation and signature enforcement.\n"
        "# ROLE IN SYSTEM: Confirms authentic tokens pass and forged or unauthenticated requests fail 401.\n"
        "# TALKS TO: server/app/api/deps.py, server/app/config.py\n"
    ),

    # -------------------------------------------------------------------------
    # Migrations, Build, and Config
    # -------------------------------------------------------------------------
    "migrations/001_initial_schema.sql": (
        "-- PURPOSE: Primary PostgreSQL database schema migration establishing tables, triggers, and RLS.\n"
        "-- ROLE IN SYSTEM: Creates 12 relational tables, double-entry ledger, immutable audit log, and RLS.\n"
        "-- TALKS TO: PostgreSQL, server/app/database.py, server/app/services/ledger.py\n"
    ),
    "Makefile": (
        "# PURPOSE: Development task orchestration definitions for linting, testing, and running services.\n"
        "# ROLE IN SYSTEM: Provides unified CLI commands for test execution, migrations, and service startup.\n"
        "# TALKS TO: pytest, uvicorn, docker-compose.yml\n"
    ),
    "docker-compose.yml": (
        "# PURPOSE: Docker Compose service definitions for orchestrating the VaniGuard backend stack.\n"
        "# ROLE IN SYSTEM: Defines multi-container networking for the FastAPI gateway and background worker.\n"
        "# TALKS TO: server/Dockerfile, worker/Dockerfile\n"
    ),

    # -------------------------------------------------------------------------
    # Flutter Application (app/lib/)
    # -------------------------------------------------------------------------
    "app/lib/main.dart": (
        "/// PURPOSE: Flutter mobile application entrypoint and root widget initialization.\n"
        "/// ROLE IN SYSTEM: Initializes MaterialApp, applies Quiet Vault theme, and mounts AppRouter.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/theme/quiet_vault_theme.dart\n"
    ),
    "app/lib/router.dart": (
        "/// PURPOSE: Declarative route definitions and navigation management for the Flutter client.\n"
        "/// ROLE IN SYSTEM: Maps URI routes to screens (dashboard, voice session, challenge, TC portal).\n"
        "/// TALKS TO: app/lib/screens/, app/lib/main.dart\n"
    ),
    "app/lib/theme/quiet_vault_theme.dart": (
        "/// PURPOSE: Quiet Vault design system theme definitions, typography, and color tokens.\n"
        "/// ROLE IN SYSTEM: Enforces deep green (#1B4332), ivory (#FAF7F0), brass (#B08968), and 18sp text.\n"
        "/// TALKS TO: app/lib/main.dart, app/lib/widgets/, app/lib/screens/\n"
    ),
    "app/lib/widgets/accessible_button.dart": (
        "/// PURPOSE: High-contrast touch target widget meeting accessibility guidelines.\n"
        "/// ROLE IN SYSTEM: Provides 64dp minimum touch target buttons for elderly and visually impaired users.\n"
        "/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/\n"
    ),
    "app/lib/widgets/offline_banner.dart": (
        "/// PURPOSE: Persistent banner widget alerting users when network connectivity is lost.\n"
        "/// ROLE IN SYSTEM: Informs user that voice sessions require secure connectivity to proceed.\n"
        "/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/\n"
    ),
    "app/lib/widgets/voice_waveform.dart": (
        "/// PURPOSE: Real-time animated acoustic waveform visualizer widget.\n"
        "/// ROLE IN SYSTEM: Renders visual feedback during microphone capture and voice session streaming.\n"
        "/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/voice_session_screen.dart\n"
    ),
    "app/lib/screens/banking_dashboard_screen.dart": (
        "/// PURPOSE: Main banking dashboard display showing balance in paise and recent activity.\n"
        "/// ROLE IN SYSTEM: Primary interface presenting account status and launching voice banking sessions.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart\n"
    ),
    "app/lib/screens/challenge_verification_screen.dart": (
        "/// PURPOSE: Spoken challenge-response UI presented when risk falls into SOFT_VERIFY band.\n"
        "/// ROLE IN SYSTEM: Displays 6-digit code and prompts user to speak digits for liveness verification.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart\n"
    ),
    "app/lib/screens/consents_privacy_screen.dart": (
        "/// PURPOSE: DPDP Act 2023 consent management and privacy settings screen.\n"
        "/// ROLE IN SYSTEM: Allows user to review and manage purpose-specific voice biometric consents.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart\n"
    ),
    "app/lib/screens/risk_monitor_screen.dart": (
        "/// PURPOSE: Real-time explainability monitor visualizing the 5 coercion risk signals.\n"
        "/// ROLE IN SYSTEM: Displays score contributions, active decision band, and evidence summaries.\n"
        "/// TALKS TO: app/lib/theme/quiet_vault_theme.dart, app/lib/screens/voice_session_screen.dart\n"
    ),
    "app/lib/screens/transfer_held_screen.dart": (
        "/// PURPOSE: Protective intervention screen displayed when risk triggers CIRCUIT_BREAK.\n"
        "/// ROLE IN SYSTEM: Displays mandated bilingual calm copy, cooling countdown, and cancellation button.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart\n"
    ),
    "app/lib/screens/trusted_contact_portal_screen.dart": (
        "/// PURPOSE: Dedicated portal screen for designated trusted contacts to review HELD transfers.\n"
        "/// ROLE IN SYSTEM: Provides out-of-band attested review controls to approve or deny held transfers.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/accessible_button.dart\n"
    ),
    "app/lib/screens/voice_enrollment_screen.dart": (
        "/// PURPOSE: Guided 3-phrase voice enrollment onboarding flow for new users.\n"
        "/// ROLE IN SYSTEM: Captures enrollment phrases and displays SNR and duration quality feedback.\n"
        "/// TALKS TO: app/lib/router.dart, app/lib/widgets/voice_waveform.dart\n"
    ),
    "app/lib/screens/voice_session_screen.dart": (
        "/// PURPOSE: Active conversational voice banking session interface over WebSocket.\n"
        "/// ROLE IN SYSTEM: Streams microphone audio, displays live transcripts, and handles band transitions.\n"
        "/// TALKS TO: app/lib/widgets/voice_waveform.dart, app/lib/screens/risk_monitor_screen.dart\n"
    ),
}

# -----------------------------------------------------------------------------
# Documentation Summaries (Rule 4: Two-line summary at top of docs)
# -----------------------------------------------------------------------------
DOC_SUMMARIES = {
    "docs/API.md": (
        "> **Summary**: Comprehensive reference of all 25 REST endpoints and WebSocket protocols in VaniGuard.\n"
        "> **When to read**: Consult when integrating frontend clients or modifying backend service contracts.\n\n"
    ),
    "docs/ARCHITECTURE.md": (
        "> **Summary**: System architecture documentation covering the voice biometric, risk engine, and ledger planes.\n"
        "> **When to read**: Consult to understand end-to-end data flow, system boundaries, and design invariants.\n\n"
    ),
    "docs/BENCHMARKS.md": (
        "> **Summary**: Empirical benchmark results and methodologies for latency, speaker verification, and DSP.\n"
        "> **When to read**: Consult when evaluating system performance budgets or reproducing benchmark claims.\n\n"
    ),
    "docs/COMPLIANCE.md": (
        "> **Summary**: Regulatory compliance specification aligning platform controls with the DPDP Act 2023.\n"
        "> **When to read**: Consult when verifying consent management, data minimization, and audit requirements.\n\n"
    ),
    "docs/MODEL_CARD.md": (
        "> **Summary**: Machine learning model card detailing Faster-Whisper and ECAPA-TDNN operational specs.\n"
        "> **When to read**: Consult to review acoustic model parameters, training baselines, and fairness invariants.\n\n"
    ),
}
