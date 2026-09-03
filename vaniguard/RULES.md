# VaniGuard - Engineering Rules and System Invariants

## 1. Language and Content Constraints
1. ZERO emojis anywhere in the codebase, UI copy, logs, documentation, comments, or commit history.
2. ZERO references to hackathons, competitions, judges, or temporary prototypes. VaniGuard is built as a production-grade banking platform.
3. All user-facing strings, prompts, and error responses must be provided in both English and Hindi. Strings are never hardcoded inside widget logic or API endpoints.

## 2. Security and Cryptography Invariants
4. Supabase Service Role key exists strictly within backend environment variables. It is never exposed to the client application, git history, or client logs.
5. Raw user microphone audio is never written to disk or database. All digital signal processing (DSP) and feature extraction occur in-memory within worker execution memory.
6. Voiceprints are stored exclusively as mathematical embedding vectors (d-vectors). Every embedding vector is encrypted at rest using AES-256-GCM envelope encryption with KMS key rotation metadata.
7. Row Level Security (RLS) is strictly enabled on every Postgres table. Policies are verified in automated test suites across anonymous, authenticated, and service roles.
8. Double-entry ledger invariant: Every money movement is atomic and consists of equal debit and credit legs executed within a single database transaction under row-level locking.
9. All financial mutations require unique `X-Idempotency-Key` headers. Duplicate submissions return the original transaction record without duplicate balance alterations.
10. System audit log is strictly append-only. Updates and deletions are prevented at the database layer via PostgreSQL triggers.

## 3. Coercion Risk Engine and Fairness Invariants
11. Fairness Invariant: All acoustic and vocal stress signals are self-referenced to the user's personal enrollment baseline. No demographic, age, gender, caste, or proxy inputs are permitted to enter the risk engine. This invariant is enforced by automated CI schema tests.
12. Explainability Invariant: Every risk score (0-100) must emit a complete explainability payload itemizing the contribution, maximum points, and acoustic evidence summary for each transparent signal.
13. High risk produces a protective hold with a 30-minute cooling window and Trusted Contact escalation. The system never executes permanent punitive automated blocking.
14. Stress and acoustic signals are probabilistic risk indicators only. The system must never state or imply an emotional, cognitive, or medical determination about the account holder.

## 4. Accessibility and Inclusive Design
15. Minimum body typography is 18sp (larger than standard), with title scale at 24sp and display at 34sp. Minimum font weight is 400.
16. Interactive touch targets are 64dp minimum across all surfaces.
17. A high-contrast 3px focus ring (#D97706) is rendered on focused elements for complete keyboard navigation.
18. Semantics labels and live regions are declared on every interactive element in both English and Hindi.
19. Every banking workflow is completable by voice alone and by keyboard alone.
20. Reduced-motion system preferences are respected across all animations and waveform visualizers.

## 5. Architecture and Reliability
21. Strict type checking across the entire boundary: Pydantic v2 schemas server-side, typed models client-side.
22. Non-blocking I/O throughout FastAPI async routes; heavy audio DSP and model inference offloaded to worker queue.
23. Periodic cooling-window sweeper background task automatically resolves expired held transfers to cancelled status with immutable audit logging.
24. Health check endpoints and Docker container health checks are enabled across API, worker, and Redis services.
