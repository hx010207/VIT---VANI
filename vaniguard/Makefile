# PURPOSE: Development task orchestration definitions for linting, testing, and running services.
# ROLE IN SYSTEM: Provides unified CLI commands for test execution, migrations, and service startup.
# TALKS TO: pytest, uvicorn, docker-compose.yml
.PHONY: help dev test lint bench models

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

dev:
	$(UVICORN) server.app.main:app --host 0.0.0.0 --port 8000 --reload

test:
	$(PYTEST) server/tests -v

lint:
	$(PYTHON) -c "import re, os, sys; emoji_pat = re.compile(r'[\U00010000-\U0010ffff]'); bad_words = ['hackathon', 'competition', 'demo mode']; found = []; [found.append((os.path.join(r, f), 'emoji')) for r, d, fs in os.walk('.') if '.venv' not in r and '.git' not in r for f in fs if f.endswith(('.py', '.sql', '.json', '.md', '.yaml', '.yml')) and emoji_pat.search(open(os.path.join(r, f), encoding='utf-8', errors='ignore').read())]; [found.append((os.path.join(r, f), w)) for r, d, fs in os.walk('.') if '.venv' not in r and '.git' not in r for f in fs if f.endswith(('.py', '.sql', '.json', '.md', '.yaml', '.yml')) for w in bad_words if re.search(rf'\b{w}\b', open(os.path.join(r, f), encoding='utf-8', errors='ignore').read(), re.I)]; (print('LINT FAILED:', found) or sys.exit(1)) if found else print('LINT PASSED: Zero emojis and zero prohibited terms.')"

bench:
	$(PYTHON) bench/bench_latency_budget.py
	$(PYTHON) bench/bench_scam_lexicon.py
	$(PYTHON) bench/bench_challenge_verification.py
	$(PYTHON) bench/bench_speaker_verification.py
	$(PYTHON) bench/bench_second_voice_snr.py

models:
	$(PYTHON) worker/prefetch_models.py
