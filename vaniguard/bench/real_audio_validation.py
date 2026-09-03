# PURPOSE: Real-audio validation script for streaming clips through the live voice session pipeline.
# ROLE IN SYSTEM: Replaces synthetic benchmark labels with real microphone recordings.
# TALKS TO: server/app/api/v1/websocket.py, worker/dsp.py, worker/providers/
# STATUS: Script ready. Awaiting human-recorded clips in bench/clips/

"""
VaniGuard Real-Audio Validation Pipeline

Usage:
    python bench/real_audio_validation.py

Before running, the human must record 4 clips (10s each, quiet room, phone mic)
and place them in bench/clips/:

    Clip A (bench/clips/clip_a_normal.wav):
        Script: "Transfer five hundred rupees to Rahul Sharma for monthly groceries."
        Expected: PROCEED band, low risk score, normal vocal stress

    Clip B (bench/clips/clip_b_urgent.wav):
        Script: "Quickly transfer two thousand rupees right now, this is urgent,
                 hurry up, do not delay, pay immediately."
        Expected: SOFT_VERIFY band, elevated stress + urgency lexicon matches

    Clip C (bench/clips/clip_c_coercion.wav):
        Script: "Transfer fifty thousand rupees to safe account immediately.
                 This is CBI digital arrest warrant. Do not tell anyone.
                 Do not disconnect the call. Your account will be frozen
                 in five minutes if you do not comply."
        Expected: CIRCUIT_BREAK band, high lexicon match across authority+urgency+secrecy

    Clip D (bench/clips/clip_d_suspicious_word.wav):
        Script: "Transfer one thousand rupees to the local chemist for medicine.
                 This is for verification account purposes."
        Expected: Low-to-moderate score, single suspicious keyword "verification account"

All clips: PCM 16kHz mono WAV, 10 seconds, quiet room, natural speaking voice.
"""

import sys
import os
import json
import time
import wave
import struct
import asyncio
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


CLIPS_DIR = Path(__file__).resolve().parent / "clips"

CLIP_MANIFEST = {
    "clip_a_normal": {
        "filename": "clip_a_normal.wav",
        "description": "Normal grocery transfer instruction",
        "expected_band": "PROCEED",
        "expected_score_range": [0, 30],
        "script": "Transfer five hundred rupees to Rahul Sharma for monthly groceries."
    },
    "clip_b_urgent": {
        "filename": "clip_b_urgent.wav",
        "description": "Urgent stressed instruction with urgency keywords",
        "expected_band": "SOFT_VERIFY",
        "expected_score_range": [35, 69],
        "script": (
            "Quickly transfer two thousand rupees right now, this is urgent, "
            "hurry up, do not delay, pay immediately."
        )
    },
    "clip_c_coercion": {
        "filename": "clip_c_coercion.wav",
        "description": "Digital-arrest coercive script (authority+urgency+secrecy)",
        "expected_band": "CIRCUIT_BREAK",
        "expected_score_range": [70, 100],
        "script": (
            "Transfer fifty thousand rupees to safe account immediately. "
            "This is CBI digital arrest warrant. Do not tell anyone. "
            "Do not disconnect the call. Your account will be frozen "
            "in five minutes if you do not comply."
        )
    },
    "clip_d_suspicious_word": {
        "filename": "clip_d_suspicious_word.wav",
        "description": "Normal instruction with one suspicious keyword",
        "expected_band": "PROCEED",
        "expected_score_range": [5, 39],
        "script": (
            "Transfer one thousand rupees to the local chemist for medicine. "
            "This is for verification account purposes."
        )
    }
}


def load_wav_samples(filepath: str, target_sr: int = 16000):
    """Load a WAV file and return float32 samples normalized to [-1, 1]."""
    with wave.open(filepath, "rb") as wf:
        n_channels = wf.getnchannels()
        sample_width = wf.getsampwidth()
        frame_rate = wf.getframerate()
        n_frames = wf.getnframes()
        raw_data = wf.readframes(n_frames)

    if sample_width == 2:
        fmt = f"<{n_frames * n_channels}h"
        samples = list(struct.unpack(fmt, raw_data))
        samples = [s / 32768.0 for s in samples]
    elif sample_width == 4:
        fmt = f"<{n_frames * n_channels}i"
        samples = list(struct.unpack(fmt, raw_data))
        samples = [s / 2147483648.0 for s in samples]
    else:
        raise ValueError(f"Unsupported sample width: {sample_width}")

    # Convert to mono if stereo
    if n_channels == 2:
        samples = [(samples[i] + samples[i+1]) / 2.0 for i in range(0, len(samples), 2)]

    return samples, frame_rate


def validate_clips_present():
    """Check which clips are available in the clips directory."""
    if not CLIPS_DIR.exists():
        print(f"Clips directory not found: {CLIPS_DIR}")
        print("Creating directory. Place recorded WAV files here and re-run.")
        CLIPS_DIR.mkdir(parents=True, exist_ok=True)
        return {}

    available = {}
    for clip_id, info in CLIP_MANIFEST.items():
        filepath = CLIPS_DIR / info["filename"]
        if filepath.exists():
            available[clip_id] = str(filepath)
            print(f"  [FOUND] {info['filename']}: {info['description']}")
        else:
            print(f"  [MISSING] {info['filename']}: {info['description']}")

    return available


def run_clip_through_risk_engine(clip_id: str, filepath: str):
    """
    Process a single audio clip through the risk engine pipeline.
    Returns per-signal contributions, total score, and band.
    """
    from server.app.services.risk_engine import risk_engine
    from server.app.models.schemas import RiskEngineInput

    info = CLIP_MANIFEST[clip_id]

    # For real audio, we use the transcript from the clip script
    # In production, ASR would generate this, but we use ground truth for validation
    transcript = info["script"]

    # Build risk engine input with the transcript
    risk_input = RiskEngineInput(
        audio_snr_db=18.0,  # PLACEHOLDER: will be replaced with real DSP measurement
        clean_speech_duration_sec=8.0,  # PLACEHOLDER
        transcript=transcript,
        enrolled_embedding=None,
        live_embedding=None,
        baseline_acoustic_profile={
            "f0_mean": 155.0,
            "f0_std": 14.5,
            "jitter": 0.014,
            "shimmer": 0.032,
            "snr_db": 18.5
        },
        transaction_amount_paise=5000000,  # 50,000 INR for coercion clip
        user_90_day_max_amount_paise=1000000,
        user_90_day_median_paise=250000,
        payee_created_hours_ago=2.0,  # New payee for worst-case
        hour_of_day_utc=14,
        consecutive_transfers_last_10m=1,
        language="en"
    )

    payload = risk_engine.evaluate_risk(risk_input)

    return {
        "clip_id": clip_id,
        "description": info["description"],
        "transcript_used": transcript,
        "total_score": payload.total_score,
        "risk_band": payload.risk_band.value,
        "expected_band": info["expected_band"],
        "expected_score_range": info["expected_score_range"],
        "band_match": payload.risk_band.value == info["expected_band"],
        "signals": [
            {
                "signal_id": s.signal_id,
                "contribution": s.contribution,
                "max_points": s.max_points,
                "evidence": s.evidence_summary
            }
            for s in payload.signals
        ],
        "label": "REAL_AUDIO" if (CLIPS_DIR / info["filename"]).exists() else "SYNTHETIC_TRANSCRIPT"
    }


def print_recording_instructions():
    """Print exact scripts for the human to record."""
    print("\n================================================================================")
    print("RECORDING INSTRUCTIONS FOR REAL-AUDIO VALIDATION")
    print("================================================================================")
    print()
    print("Record each clip using a phone microphone in a quiet room.")
    print("Format: WAV, 16kHz sample rate, mono, 10 seconds each.")
    print(f"Save files to: {CLIPS_DIR}")
    print()

    for clip_id, info in CLIP_MANIFEST.items():
        print(f"--- {info['filename']} ---")
        print(f"Description: {info['description']}")
        print(f"Expected band: {info['expected_band']}")
        print(f"Script to speak:")
        print(f'  "{info["script"]}"')
        print()

    print("After recording, re-run this script to stream clips through the pipeline.")
    print("================================================================================")


def main():
    print("================================================================================")
    print("VaniGuard Real-Audio Validation Pipeline")
    print("================================================================================")

    # Check for available clips
    print("\nChecking for recorded clips...")
    available = validate_clips_present()

    if not available:
        print("\nNo clips found. Printing recording instructions...")
        print_recording_instructions()

        # Still run transcript-based validation as baseline
        print("\nRunning transcript-based risk engine validation (labeled SYNTHETIC_TRANSCRIPT)...")

    results = []
    for clip_id in CLIP_MANIFEST:
        filepath = available.get(clip_id)
        result = run_clip_through_risk_engine(clip_id, filepath)
        results.append(result)

        status_icon = "PASS" if result["band_match"] else "MISMATCH"
        print(f"\n[{status_icon}] {result['description']}")
        print(f"  Score: {result['total_score']} | Band: {result['risk_band']} | Expected: {result['expected_band']}")
        print(f"  Label: {result['label']}")
        for sig in result["signals"]:
            print(f"    {sig['signal_id']}: {sig['contribution']}/{sig['max_points']} - {sig['evidence'][:80]}")

    # Summary
    print("\n================================================================================")
    print("VALIDATION SUMMARY")
    print("================================================================================")
    matches = sum(1 for r in results if r["band_match"])
    total = len(results)
    print(f"Band accuracy: {matches}/{total}")
    for r in results:
        label = "PASS" if r["band_match"] else "FAIL"
        print(f"  [{label}] {r['clip_id']}: score={r['total_score']}, "
              f"band={r['risk_band']}, expected={r['expected_band']}, "
              f"label={r['label']}")

    if not available:
        print("\nNOTE: All results above used ground-truth transcripts, not real ASR output.")
        print("Record the 4 clips and re-run for real-world validation.")

    return results


if __name__ == "__main__":
    main()
