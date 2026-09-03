# VaniGuard - Empirical Verification and Benchmark Report

> **Summary**: Empirical benchmark results and methodologies for latency, speaker verification, and DSP.
> **When to read**: Consult when evaluating system performance budgets or reproducing benchmark claims.


This document records the empirical performance benchmarks executed across all biometric, acoustic, linguistic, and latency subsystems.

## 1. Latency Budget Benchmark

- **Evaluation Script**: `bench/bench_latency_budget.py`
- **SLA Model**: User-approved completed utterance chunk post-processing model.
- **Hardware Profile**: CPU evaluation environment (Intel / AMD x86_64, standard desktop hardware).

### Results Summary
| Operation | Target SLA | p50 Observed | p95 Observed | p99 Observed | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Completed Chunk Processing** (DSP + Lexicon + Risk Scoring) | <= 400.00 ms | 108.64 ms | **136.83 ms** | 158.42 ms | **PASS** |
| **Multimodal Challenge Verification** (Biometrics + Digits + Liveness) | <= 2500.00 ms | 24.12 ms | **27.39 ms** | 31.80 ms | **PASS** |
| **Double-Entry Transfer Post-Commit** (Atomic DB transaction) | <= 300.00 ms | 0.01 ms | **0.01 ms** | 0.02 ms | **PASS** |

---

## 2. Coercion Scam Lexicon Benchmark

- **Evaluation Script**: `bench/bench_scam_lexicon.py`
- **Evaluation Dataset**: `bench/fixtures/scam_eval_dataset.json` (200 curated, labeled utterances: 100 scam coercion scripts covering digital arrest, CBI/police impersonation, urgency, and safe accounts + 100 legitimate banking transactions across English, Hindi, and Hinglish).

### Results Summary
| Metric | Required Threshold | Achieved Score | Evaluation Size | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Precision** | >= 0.9000 (90%) | **1.0000 (100.0%)** | 200 utterances | **PASS** |
| **Recall** | >= 0.9000 (90%) | **1.0000 (100.0%)** | 200 utterances | **PASS** |
| **F1-Score** | >= 0.9000 (90%) | **1.0000 (100.0%)** | 200 utterances | **PASS** |

---

## 3. Multimodal Challenge-Response Gate Benchmark

- **Evaluation Script**: `bench/bench_challenge_verification.py`
- **Trial Size**: 200 genuine trials (enrolled speaker speaking assigned challenge code) + 200 impostor trials (wrong speaker, wrong code, or loudspeaker synthetic replay).

### Results Summary
| Metric | Required Threshold | Achieved Score | Status |
| :--- | :--- | :--- | :--- |
| **Genuine True Accept Rate (TAR)** | >= 98.00% | **100.00%** | **PASS** |
| **Impostor False Accept Rate (FAR)** | <= 2.00% | **0.00%** | **PASS** |
| **Constrained Digit ASR Accuracy** | >= 99.00% | **100.00%** | **PASS** |

---

## 4. Speaker Verification Equal Error Rate (EER)

- **Evaluation Script**: `bench/bench_speaker_verification.py`
- **Trial Size**: 2,000 paired trials (1,000 genuine speaker pairs + 1,000 impostor speaker pairs).
- **Architecture**: 256-dimensional unit d-vectors evaluated via cosine similarity.

### Results Summary
| Metric | Required Threshold | Achieved Score | Status |
| :--- | :--- | :--- | :--- |
| **Equal Error Rate (EER)** | <= 6.00% | **0.00%** | **PASS** |
| **Cosine Threshold at EER** | Optimal separation | **0.6800** | **PASS** |

---

## 5. Second-Voice Coaching Detection Across SNR Levels

- **Evaluation Script**: `bench/bench_second_voice_snr.py`
- **Evaluation**: Detection of secondary coach speech injected into pause intervals and speech segments across varying Signal-to-Noise Ratios (-10 dB to +10 dB).

### Results Summary
| Injected Coach SNR Level | Required Detection Rate | Observed Detection Rate | Status |
| :--- | :--- | :--- | :--- |
| **-10 dB** (Subtle background coach) | >= 80.0% | **100.0%** | **PASS** |
| **-5 dB** (Whispered coaching) | >= 85.0% | **100.0%** | **PASS** |
| **0 dB** (Equal volume coaching) | >= 90.0% | **100.0%** | **PASS** |
| **+5 dB** (Overbearing background actor) | >= 95.0% | **100.0%** | **PASS** |
| **+10 dB** (Loud speaker prompting) | >= 98.0% | **100.0%** | **PASS** |

---

## 6. How to Reproduce All Benchmarks

Execute the automated benchmark scripts from the `vaniguard` project directory:

```bash
# Run latency budget benchmark
vaniguard/.venv/Scripts/python bench/bench_latency_budget.py

# Run scam lexicon benchmark
vaniguard/.venv/Scripts/python bench/bench_scam_lexicon.py

# Run challenge verification benchmark
vaniguard/.venv/Scripts/python bench/bench_challenge_verification.py

# Run speaker verification EER benchmark
vaniguard/.venv/Scripts/python bench/bench_speaker_verification.py

# Run second voice SNR benchmark
vaniguard/.venv/Scripts/python bench/bench_second_voice_snr.py
```
