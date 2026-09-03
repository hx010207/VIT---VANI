# PURPOSE: Container definition for the background ML inference and audio DSP worker service.
# ROLE IN SYSTEM: Packages audio processing libraries, pre-cached models, and ARQ queue processor.
# TALKS TO: worker/worker.py, worker/prefetch_models.py, docker-compose.yml
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "-m", "worker.worker"]
