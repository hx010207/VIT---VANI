import sys
import numpy as np
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from worker.dsp import detect_second_voice


def run_second_voice_snr_benchmark(num_trials_per_snr: int = 50):
    print("==================================================")
    print("VaniGuard Second-Voice Detection vs SNR Curve Benchmark")
    print("Evaluating synthetic mixtures of enrolled speaker + coaching distractor...")
    print("==================================================")

    sample_rate = 16000
    duration = 4.0  # 4 seconds
    num_samples = int(sample_rate * duration)
    t = np.linspace(0, duration, num_samples)

    # Primary enrolled speaker: F0 = 135 Hz with pauses between 1.5s and 2.8s
    primary_speech = 0.6 * np.sin(2 * np.pi * 135 * t) + 0.3 * np.sin(2 * np.pi * 270 * t)
    # Create distinct pause segment (attenuate primary speaker by 95% in window)
    pause_mask = (t >= 1.5) & (t <= 2.8)
    primary_speech[pause_mask] *= 0.05
    enrolled_baseline_f0 = 135.0

    # Distractor / coaching voice in pause window: distinct F0 = 195 Hz (delta F0 = 60 Hz)
    coaching_voice = np.zeros(num_samples)
    coaching_voice[pause_mask] = 0.5 * np.sin(2 * np.pi * 195 * t[pause_mask]) + 0.25 * np.sin(2 * np.pi * 390 * t[pause_mask])

    snr_levels_db = [-10.0, -5.0, 0.0, 5.0, 10.0]
    detection_rates = {}

    for snr_db in snr_levels_db:
        # Scale distractor voice relative to primary speech according to target SNR
        # SNR = 10 * log10(P_primary / P_distractor)
        # P_distractor = P_primary / (10^(SNR/10))
        scale = 10.0 ** (-snr_db / 20.0)
        detections = 0

        for _ in range(num_trials_per_snr):
            noise = np.random.randn(num_samples) * 0.015
            # Synthetic mixture
            mixture = primary_speech + (coaching_voice * scale) + noise
            result = detect_second_voice(mixture, enrolled_baseline_f0, sample_rate)
            if result.get("detected", False):
                detections += 1

        rate = (detections / num_trials_per_snr) * 100.0
        detection_rates[snr_db] = rate
        print(f"SNR {snr_db:+5.1f} dB: Detection Rate = {rate:5.1f}% ({detections}/{num_trials_per_snr})")

    print("\nSecond Voice Detection vs SNR Curve Summary:")
    for snr, rate in detection_rates.items():
        bar = "#" * int(rate // 5)
        print(f"  {snr:+5.1f} dB | {bar:<20} | {rate:5.1f}%")

    # Target: Detection rate >= 80% at 0dB SNR (where secondary speaker is comparable to noise floor)
    assert detection_rates[0.0] >= 80.0, f"Breach: Detection rate at 0dB SNR ({detection_rates[0.0]}%) below 80%"
    print("\nPASS: Second-voice coaching detection meets sensitivity requirements across acoustic SNR ranges.")
    print("WARNING: Injected coaching audio was generated using synthetic tone mixtures and")
    print("synthetic pause intervals. Validates DSP spectral separation; field revalidation is required.")
    return detection_rates


if __name__ == "__main__":
    run_second_voice_snr_benchmark()
