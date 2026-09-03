# PURPOSE: Development task orchestration definitions for linting, testing, and running services.
# ROLE IN SYSTEM: Provides unified CLI commands for test execution, migrations, and service startup.
# TALKS TO: pytest, uvicorn, docker-compose.yml
.PHONY: help dev test lint bench models demo

PYTHON := .venv/Scripts/python
PYTEST := .venv/Scripts/pytest
UVICORN := .venv/Scripts/uvicorn

help:
	@echo "VaniGuard Automation Targets:"
	@echo "  dev     - Start FastAPI server on port 8000"
	@echo "  test    - Run all automated tests in server/tests"
	@echo "  lint    - Run code verification (zero emojis, zero prohibited terms)"
	@echo "  bench   - Run all 5 empirical benchmarks"
	@echo "  models  - Pre-fetch and cache faster-whisper and ECAPA-TDNN models"
	@echo "  demo    - Full deterministic boot: server + e2e smoke + setup instructions"

dev:
	$(UVICORN) server.app.main:app --host 0.0.0.0 --port 8000 --reload

test:
	$(PYTEST) server/tests -v

lint:
	$(PYTHON) -c "import re, os, sys; emoji_pat = re.compile(r'[\U00010000-\U0010ffff]'); bad_words = ['hackathon', 'competition', 'demo mode']; found = []; [found.append((os.path.join(r, f), 'emoji')) for r, d, fs in os.walk('.') if '.venv' not in r and '.git' not in r for f in fs if f.endswith(('.py', '.sql', '.json', '.md', '.yaml', '.yml')) and emoji_pat.search(open(os.path.join(r, f), encoding='utf-8', errors='ignore').read())]; [found.append((os.path.join(r, f), w)) for r, d, fs in os.walk('.') if '.venv' not in r and '.git' not in r for f in fs if f.endswith(('.py', '.sql', '.json', '.md', '.yaml', '.yml')) for w in bad_words if re.search(rf'\\b{w}\\b', open(os.path.join(r, f), encoding='utf-8', errors='ignore').read(), re.I)]; (print('LINT FAILED:', found) or sys.exit(1)) if found else print('LINT PASSED: Zero emojis and zero prohibited terms.')"

bench:
	$(PYTHON) bench/bench_latency_budget.py
	$(PYTHON) bench/bench_scam_lexicon.py
	$(PYTHON) bench/bench_challenge_verification.py
	$(PYTHON) bench/bench_speaker_verification.py
	$(PYTHON) bench/bench_second_voice_snr.py

models:
	$(PYTHON) worker/prefetch_models.py

demo:
	@echo "================================================================================"
	@echo "VaniGuard: Full Deterministic Boot Sequence"
	@echo "================================================================================"
	@echo ""
	@echo "[1/4] Pre-loading ML models (faster-whisper small int8 + ECAPA-TDNN)..."
	-$(PYTHON) worker/prefetch_models.py
	@echo ""
	@echo "[2/4] Starting VaniGuard API server on port 8000..."
	@echo "      In-process async queue fallback active (Redis not required)."
	@start /B $(UVICORN) server.app.main:app --host 0.0.0.0 --port 8000
	@echo "      Waiting for /health 200..."
	@$(PYTHON) -c "import time, httpx; [time.sleep(1) for _ in range(30) if not (lambda: (r:=httpx.get('http://localhost:8000/health',timeout=2)) and r.status_code==200)()]"
	@echo ""
	@echo "[3/4] Running e2e_smoke.py (8-step live integration test)..."
	-$(PYTHON) bench/e2e_smoke.py
	@echo ""
	@echo "[4/4] Boot complete. Setup instructions:"
	@echo "================================================================================"
	@echo "  API Server:  http://localhost:8000"
	@echo "  Health:      http://localhost:8000/health"
	@echo "  WebSocket:   ws://localhost:8000/ws/voice-session"
	@echo ""
	@echo "  TWO-DEVICE SETUP:"
	@echo "  1. Connect both Android phones via USB"
	@echo "  2. Run: adb devices (expect 2 entries)"
	@echo "  3. Device 1 (Holder): Open VaniGuard app, log in as account holder"
	@echo "  4. Device 2 (TC):     Open VaniGuard app, log in as trusted contact"
	@echo "  5. On Device 1: speak a coercive transfer to trigger CIRCUIT_BREAK"
	@echo "  6. On Device 2: review and deny the held transfer"
	@echo ""
	@echo "  ON-SCREEN FOOTER (required on all screens):"
	@echo "  Prototype operating on synthetic users and sandbox transactions."
	@echo "  Thresholds are demonstration values."
	@echo "================================================================================"
