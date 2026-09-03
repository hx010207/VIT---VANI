# VIT---VANI

## VaniGuard: Voice-First Secure Banking Platform

VaniGuard is a production-grade, voice-first banking interface with an embedded real-time coercion-detection and fraud-intervention engine. It is specifically engineered to protect vulnerable, elderly, and rural banking users against cyber fraud, digital arrest scams, coercion, and social engineering attacks in bilingual environments (Hindi and Indian English).

---

## Architectural Overview

The platform operates across three integrated planes:

1. **Voice Biometrics and Acoustic Intelligence**:
   - 3-phrase acoustic enrollment with strict signal-to-noise ratio (SNR >= 12.0 dB) and clean speech duration (>= 3.0s) gating.
   - Self-referenced vocal stress index comparing pitch variance, jitter, and shimmer against the user's personal baseline.
   - Dual-speaker presence detection via spectral autocorrelation to identify background coercion or whisper coaching.
   - 256-dimensional unit-normalized speaker d-vector embeddings (ECAPA-TDNN).
   - Multi-layer envelope encryption using AES-256-GCM with unique cryptographic initialization vectors and KMS key identifiers.

2. **Real-Time Coercion Risk Engine**:
   - 5-signal explainable risk evaluation:
     - Second Voice Presence (Weight: 35)
     - Vocal Stress Index (Weight: 20)
     - Speaker Identity Mismatch (Weight: 30)
     - Coercion Script & Authority Lexicon Match (Weight: 25)
     - Contextual Transaction Anomaly (Weight: 20)
   - Three operational decision bands:
     - `0 - 39`: **PROCEED** (Normal banking operations)
     - `40 - 69`: **SOFT_VERIFY** (Dynamic 6-digit challenge-response with acoustic liveness and constrained grammar decoding)
     - `70 - 100`: **CIRCUIT_BREAK** (Immediate hold, 30-minute cooling window, trusted contact escalation, protective calm guidance)

3. **Financial Ledger and Protection**:
   - Immutable double-entry accounting ledger with atomic balance validation.
   - Strict idempotency protection via unique transaction keys.
   - Trusted contact workflow with out-of-band attested approvals and cancellations.
   - Asynchronous background sweeper for cooling window expirations.
   - Comprehensive audit logging and DPDP Act 2023 compliance architecture.

---

## Directory Structure

```
VIT - C/
├── vaniguard/
│   ├── app/                      # Mobile client structure (Flutter / Dart)
│   ├── bench/                    # Verification test suites & latency benchmarks
│   ├── docs/                     # Architectural, compliance, and threat model specifications
│   ├── migrations/               # PostgreSQL schema migrations and RLS policies
│   ├── scripts/                  # Automated verification and end-to-end execution scripts
│   ├── server/                   # FastAPI backend services and REST/WebSocket routers
│   │   ├── app/
│   │   │   ├── api/v1/           # API endpoints (onboarding, transfers, voice, TC actions)
│   │   │   ├── models/           # Pydantic data schemas
│   │   │   └── services/         # Risk engine, crypto, sweeper, and challenge services
│   ├── worker/                   # Audio DSP, ML inference, and lexicon assets
│   │   ├── dsp.py                # SNR, pitch tracking, liveness, and stress analysis
│   │   ├── scam_lexicon.en.json  # Curated English coercion lexicon
│   │   └── scam_lexicon.hi.json  # Curated Hindi coercion lexicon
│   ├── docker-compose.yml        # Multi-container service definitions
│   ├── Makefile                  # Build, test, and benchmark targets
│   └── pyproject.toml            # Project dependencies and packaging metadata
├── .gitignore                    # Root ignore configuration preventing secret leaks
└── README.md                     # Platform documentation
```

---

## Getting Started

### Prerequisites

- Python 3.12+
- `uv` package manager
- Supabase account with PostgreSQL instance (or local PostgreSQL 15+)

### Setup

1. Configure environment variables:
   ```bash
   cd vaniguard
   cp .env.example .env
   ```
   Populate `.env` with your Supabase URL, keys, and master encryption keys.

2. Install dependencies:
   ```bash
   uv sync
   ```

3. Run database migrations:
   Apply `migrations/001_initial_schema.sql` against your PostgreSQL database.

4. Start the backend service:
   ```bash
   uvicorn server.app.main:app --host 127.0.0.1 --port 8000
   ```

5. Verify health:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

---

## Verification & Testing

Execute the automated verification suites:

- **End-to-End Ledger and Idempotency**:
  ```bash
  python vaniguard/bench/e2e_smoke.py
  ```
- **Live User Onboarding and Voice Biometrics**:
  ```bash
  python vaniguard/scripts/run_live_onboarding.py
  ```
- **Live Streaming Voice Sessions (Nominal, Soft Verify, Circuit Break)**:
  ```bash
  python vaniguard/scripts/run_live_voice_sessions.py
  ```
- **Transfer Post-Commit Latency Benchmark**:
  ```bash
  python vaniguard/bench/bench_latency_budget.py
  ```

---

## Compliance and Security

- **DPDP Act 2023**: Granular purpose-specific consent management with complete revocation support.
- **Biometric Security**: Voiceprints are encrypted before database insertion and never stored as raw audio or plaintext embeddings.
- **Zero-Trust Challenge**: Spoken digit challenge codes are ephemeral (3-minute expiry), single-use, and validated via acoustic spectral liveness.
- **Audit Logging**: Append-only tamper-evident audit logs with hash chains for forensic traceability.
