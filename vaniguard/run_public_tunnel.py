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
    tunnel_file = Path(".active_tunnel_url")
    while True:
        print("\n[Tunnel] Establishing public HTTPS & WSS tunnel via localhost.run...")
        cmd = ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=30", "-R", "80:127.0.0.1:8000", "nokey@localhost.run"]
        try:
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
                if "tunneled with tls termination, https://" in line_clean:
                    public_url = "https://" + line_clean.split("https://")[-1].strip()
                elif "Forwarding HTTP traffic from" in line_clean:
                    public_url = line_clean.split("from")[-1].strip()

                if public_url and "================================================================================" not in line_clean:
                    wss_url = public_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws/voice-session"
                    try:
                        tunnel_file.write_text(public_url)
                    except Exception:
                        pass
                    print("================================================================================", flush=True)
                    print("VANIGUARD PUBLIC ACCESS LIVE", flush=True)
                    print("================================================================================", flush=True)
                    print(f"  Public REST API Base URL:  {public_url}", flush=True)
                    print(f"  Public Health Check:        {public_url}/health", flush=True)
                    print(f"  Public WebSocket Stream:    {wss_url}", flush=True)
                    print("================================================================================", flush=True)
                    print("  Copy the Public REST API Base URL into your Flutter app's api_client.dart", flush=True)
                    print("================================================================================\n", flush=True)
                    public_url = None
                elif line_clean:
                    if "Tip (" not in line_clean and "Warning:" not in line_clean and "==" not in line_clean:
                        print(f"[Tunnel] {line_clean}", flush=True)
            proc.wait()
        except Exception as e:
            print(f"[Tunnel Error] {e}", flush=True)
        print("[Tunnel] Connection dropped. Reconnecting in 3 seconds...", flush=True)
        time.sleep(3)

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
