# PURPOSE: Multi-stage container definition for the VaniGuard FastAPI gateway service.
# ROLE IN SYSTEM: Packages Python 3.12 runtime, dependencies, and Uvicorn server for deployment.
# TALKS TO: server/app/main.py, pyproject.toml, docker-compose.yml
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "server.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
