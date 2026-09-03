# PURPOSE: Lightweight sanity script for validating WebSocket session handshakes and responses.
# ROLE IN SYSTEM: Connects to /ws/voice-session and verifies welcome prompt delivery.
# TALKS TO: server/app/api/v1/websocket.py
import asyncio
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np
from fastapi.testclient import TestClient
from server.app.main import app

def test_websocket_smoke():
    print("==================================================")
    print("VaniGuard WebSocket Smoke Test: /ws/voice-session")
    print("==================================================")
    client = TestClient(app)
    with client.websocket_connect("/ws/voice-session") as ws:
        # 1. Receive initial greeting prompt event
        greeting = ws.receive_json()
        print(f"Received Greeting Event: type='{greeting.get('type')}', text_en='{greeting.get('text_en')}'")
        assert greeting.get("type") == "prompt"

        # 2. Generate a chunk of synthetic PCM16 speech (3.5s 150Hz sine wave)
        sample_rate = 16000
        duration = 3.5
        t = np.linspace(0, duration, int(sample_rate * duration))
        audio_samples = (0.5 * np.sin(2 * np.pi * 150.0 * t)).tolist()

        # 3. Send utterance_chunk message
        test_payload = {
            "type": "utterance_chunk",
            "transcript": "Transfer 500 rupees to grocer",
            "audio_samples": audio_samples,
            "amount_paise": 50000
        }
        print("Sending synthetic utterance chunk to WebSocket...")
        ws.send_json(test_payload)

        # 4. Receive typed events back
        final_transcript_event = ws.receive_json()
        print(f"Received Event 1: type='{final_transcript_event.get('type')}', text='{final_transcript_event.get('text')}'")
        assert final_transcript_event.get("type") == "final_transcript"

        risk_update_event = ws.receive_json()
        print(f"Received Event 2: type='{risk_update_event.get('type')}', score={risk_update_event.get('score')}, band='{risk_update_event.get('risk_band')}'")
        assert risk_update_event.get("type") == "risk_update"

        mode_change_event = ws.receive_json()
        print(f"Received Event 3: type='{mode_change_event.get('type')}', mode='{mode_change_event.get('mode')}'")
        assert mode_change_event.get("type") == "mode_change"

        # 5. Send close message
        ws.send_json({"type": "close"})
        session_closed_event = ws.receive_json()
        print(f"Received Event 4: type='{session_closed_event.get('type')}'")
        assert session_closed_event.get("type") == "session_closed"

    print("\nSUCCESS: WebSocket smoke test verified complete bidirectional event flow.")
    print("==================================================")

if __name__ == "__main__":
    test_websocket_smoke()
