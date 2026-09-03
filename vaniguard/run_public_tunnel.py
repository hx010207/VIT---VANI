# PURPOSE: Launches FastAPI server on 0.0.0.0:8000 and exposes a public HTTPS & WSS tunnel via Serveo.
# ROLE IN SYSTEM: Enables remote mobile devices, physical phones, and external evaluators to reach the live backend.
# TALKS TO: server/app/main.py, serveo.net

import sys
import time
import subprocess
import threading
import httpx
from pathlib import Path

def start_serveo_tunnel():
    print("\n[Tunnel] Establishing public HTTPS & WSS tunnel via Serveo...")
    cmd = ["ssh", "-tt", "-o", "StrictHostKeyChecking=no", "-R", "80:localhost:8000", "serveo.net"]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    public_url = None
    for line in iter(proc.stdout.readline, ""):
        line_clean = line.strip()
        if "Forwarding HTTP traffic from" in line_clean:
            public_url = line_clean.split("from")[-1].strip()
            wss_url = public_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws/voice-session"
            print("================================================================================")
            print("VANIGUARD PUBLIC ACCESS LIVE")
            print("================================================================================")
            print(f"  Public REST API Base URL:  {public_url}")
            print(f"  Public Health Check:        {public_url}/health")
            print(f"  Public WebSocket Stream:    {wss_url}")
            print("================================================================================")
            print("  Copy the Public REST API Base URL into your Flutter app's api_client.dart")
            print("================================================================================\n")
        elif line_clean:
            # Silence tip output
            if "Tip (" not in line_clean and "Warning:" not in line_clean:
                print(f"[Tunnel] {line_clean}")
    proc.wait()

def main():
    print("================================================================================")
    print("Starting VaniGuard Public Gateway Server (24h Prototype Mode)")
    print("================================================================================")
    
    # 1. Start Uvicorn Server in background thread or process
    venv_uvicorn = Path(".venv/Scripts/uvicorn.exe")
    uvicorn_cmd = [
        str(venv_uvicorn) if venv_uvicorn.exists() else "uvicorn",
        "server.app.main:app",
        "--host", "0.0.0.0",
        "--port", "8000"
    ]

    print("[Server] Starting uvicorn gateway on 0.0.0.0:8000...")
    server_proc = subprocess.Popen(uvicorn_cmd)

    # 2. Wait for local health check
    print("[Server] Waiting for local health check http://localhost:8000/health ...")
    health_ok = False
    for _ in range(30):
        try:
            r = httpx.get("http://localhost:8000/health", timeout=2)
            if r.status_code == 200:
                health_ok = True
                print("[Server] Local health check PASSED (HTTP 200 OK)")
                break
        except Exception:
            pass
        time.sleep(1)

    if not health_ok:
        print("[ERROR] Server failed to start on localhost:8000")
        server_proc.terminate()
        sys.exit(1)

    # 3. Start tunnel
    tunnel_thread = threading.Thread(target=start_serveo_tunnel, daemon=True)
    tunnel_thread.start()

    try:
        server_proc.wait()
    except KeyboardInterrupt:
        print("\nShutting down public gateway...")
        server_proc.terminate()
        sys.exit(0)

if __name__ == "__main__":
    main()
