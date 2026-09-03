# VaniGuard

Voice-First Secure Banking Platform with Real-Time Coercion Detection and Fraud Intervention.

---

## Overview

VaniGuard is a production-grade banking platform designed to protect vulnerable account holders during financial transactions. Existing security solutions verify speaker identity; VaniGuard continuously verifies the freedom and volition of the person speaking.

Using real-time acoustic signal processing, deep speaker verification (ECAPA-TDNN), streaming speech recognition (Faster-Whisper), and bilingual coercion script matching, VaniGuard identifies acoustic coercion markers and triggers protective financial holds (Circuit-Break) with trusted contact escalation.

---

## Direct APK Download (No ADB Required)

You can download and install VaniGuard directly on any Android device without needing USB cables or developer tools.

### Installing from GitHub Releases
1. Open this repository on your mobile phone browser.
2. Go to the **Releases** section.
3. Download **`app-release.apk`** (or `app-debug.apk`).
4. Tap the downloaded file to install VaniGuard on your phone (enable *Install from Unknown Sources* if prompted by Android).
5. Open VaniGuard and begin transaction testing.

### Triggering Automated Builds via GitHub Actions
This repository includes a GitHub Actions workflow (`.github/workflows/release_apk.yml`) that compiles the Flutter app and publishes APK binaries automatically.

- **To create a new release release automatically**:
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
- **To build manually**: Go to the **Actions** tab on GitHub, select **Build and Release Flutter APK**, and click **Run workflow**.

---

## Quick Setup Instructions

### 1. Physical Device Connection (USB Mode)
If you have a physical phone connected via USB:
```powershell
powershell -ExecutionPolicy Bypass -File .\setup_prototype.ps1
# OR
make setup
```
This runs `adb reverse tcp:8000 tcp:8000`, binding your phone's network traffic to `http://localhost:8000`.

### 2. Launch Local Backend Server
```bash
make dev
```
Starts the FastAPI server on `http://0.0.0.0:8000` with live Supabase database connections.

### 3. Launch Public Server for Remote Access
```bash
make public
```
Starts the FastAPI server and opens a secure public HTTPS and WSS tunnel for devices outside your local network.

---

## System Architecture

```
                                  +-----------------------+
                                  | Flutter Mobile Client |
                                  +-----------+-----------+
                                              |
                               (REST API / WebSocket Stream)
                                              |
                                              v
                                   +---------------------+
                                   | FastAPI Gateway API |
                                   +----------+----------+
                                              |
               +------------------------------+------------------------------+
               |                              |                              |
               v                              v                              v
    +--------------------+        +-----------------------+        +--------------------+
    | Coercion Risk Engine|       | KMS Envelope Crypto   |        | PostgreSQL DB      |
    | (5 Acoustic Signals)|       | (AES-256-GCM Vectors) |        | (Supabase RLS)     |
    +--------------------+        +-----------------------+        +--------------------+
```

---

## Verification Test Suite

Run the full automated test suite (26 tests covering RLS policies, double-entry ledger safety, cooling window sweepers, and risk engine bounds):

```bash
make test
```

### Empirical Benchmarks
Run all 5 empirical accuracy and performance benchmark suites:
```bash
make bench
```

---

## Engineering Rules and Compliance
- **Zero Emojis**: Enforced across code, documentation, and user interfaces.
- **Fairness Invariant**: Acoustic signals are self-referenced to the user's personal baseline. Zero demographic or age proxy variables.
- **Accessibility**: 64dp minimum touch targets, 18sp body typography, high contrast focus indicators, and screen-reader semantics in English and Hindi.
