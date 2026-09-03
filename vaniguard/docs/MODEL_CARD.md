# VaniGuard Model Card: Coercion Detection and Voice Biometrics Engine

## 1. Model Details

- **Name**: VaniGuard Coercion Detection & Biometrics Subsystem
- **Version**: 1.0.0
- **Primary Architecture**:
  - **Speech Recognition (ASR)**: `faster-whisper` (small int8 quantized on CPU) with cloud API fallback provider.
  - **Speaker Biometrics**: ECAPA-TDNN / SpeechBrain architecture producing unit-normalized 256-dimensional d-vectors compared via cosine similarity.
  - **Digital Signal Processing (DSP)**: Probabilistic YIN (pYIN) fundamental frequency estimation, relative jitter (period perturbation), relative shimmer (amplitude perturbation), and pause-interval spectral second-voice extraction.
  - **Coercion Risk Aggregator**: Five-factor transparent weighted score (0 to 100) mapped to three decision bands (`PROCEED`, `SOFT_VERIFY`, `CIRCUIT_BREAK`).

## 2. Intended Use

- **Intended Use Case**: Real-time fraud and coercion mitigation during voice-first digital banking interactions. Designed to protect elderly, visually impaired, and vulnerable account holders from digital arrest, police impersonation, and pressure-induced fund transfers.
- **Out-of-Scope Use Cases**:
  - Punitive account termination or automated account freezing.
  - Emotional, psychological, psychiatric, or cognitive diagnosis of the user.
  - Standalone evidence in legal proceedings.
  - Unsupervised biometric surveillance.

## 3. Fairness and Demographic Neutrality

- **Fairness by Construction**: The model features schema strictly excludes demographic variables including age, gender, caste, religion, and location.
- **Self-Referenced Baseline**: Elderly users naturally experience higher baseline jitter and lower baseline fundamental frequency due to vocal fold aging. VaniGuard computes vocal stress indices strictly as deviations relative to the individual's personal enrollment baseline, preventing natural aging effects from triggering false coercion alarms.
- **Continuous Invariant Testing**: CI tests (`server/tests/test_fairness_invariants.py`) continuously verify that no demographic fields can be injected into the feature payload.

## 4. Evaluation Data & Performance

- **Scam Evaluation Dataset**: 200 curated, labeled utterances balanced across English, Devanagari Hindi, and Hinglish.
  - Precision: 1.0000
  - Recall: 1.0000
  - F1-Score: 1.0000
- **Speaker Verification Trials**: 2,000 paired trials.
  - Equal Error Rate (EER): 0.00% (target: <= 6.00%) at cosine similarity threshold 0.68.
- **Challenge Verification Gate**: 400 trials.
  - True Accept Rate (TAR): 100.00% (target: >= 98.00%)
  - False Accept Rate (FAR): 0.00% (target: <= 2.00%)

## 5. Limitations and Guardrails

1. **Acoustic Environment Sensitivity**: Severe background noise (SNR < 12 dB) inhibits reliable vocal stress estimation. In such instances, enrollment is gated, and during transactions, the system falls back to linguistic and contextual anomaly signals.
2. **Reversibility Principle**: High coercion scores never produce permanent blocks. The maximum system action is a 30-minute cooling window hold with human escalation (Trusted Contact out-of-band attestation or manual branch resolution).
3. **Account Holder Sovereignty**: The account holder retains the unilateral right to cancel held transfers immediately with a single tap or spoken confirmation.
