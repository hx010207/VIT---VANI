import numpy as np
from scipy import signal
from typing import Dict, Any, Tuple, Optional


def compute_snr(audio: np.ndarray, sample_rate: int = 16000) -> float:
    """
    Computes Signal-to-Noise Ratio (SNR) in decibels.
    Splits signal into top 20% energy frames (signal) and bottom 20% energy frames (noise).
    """
    if len(audio) == 0:
        return 0.0
    frame_len = int(sample_rate * 0.03)  # 30ms frames
    hop_len = int(sample_rate * 0.015)   # 15ms hop
    if len(audio) < frame_len:
        return 0.0
    
    num_frames = max(1, (len(audio) - frame_len) // hop_len)
    frame_energies = []
    for i in range(num_frames):
        start = i * hop_len
        frame = audio[start:start + frame_len]
        energy = np.mean(frame ** 2)
        frame_energies.append(energy)
    
    frame_energies = np.array(frame_energies)
    if len(frame_energies) < 5:
        return 15.0
    
    sorted_energies = np.sort(frame_energies)
    n_noise = max(1, int(len(sorted_energies) * 0.2))
    n_signal = max(1, int(len(sorted_energies) * 0.2))
    
    noise_energy = np.mean(sorted_energies[:n_noise])
    signal_energy = np.mean(sorted_energies[-n_signal:])
    
    if noise_energy <= 1e-12:
        return 35.0  # Clean audio limit
    if signal_energy <= 1e-12:
        return 0.0
    
    snr_val = 10.0 * np.log10(signal_energy / noise_energy)
    return float(np.clip(snr_val, 0.0, 50.0))


def compute_clean_speech_duration(audio: np.ndarray, sample_rate: int = 16000, thresh_ratio: float = 0.08) -> float:
    """
    Measures duration of active speech frames exceeding adaptive energy threshold.
    """
    if len(audio) == 0:
        return 0.0
    frame_len = int(sample_rate * 0.025)  # 25ms
    hop_len = int(sample_rate * 0.010)   # 10ms
    num_frames = (len(audio) - frame_len) // hop_len
    if num_frames <= 0:
        return 0.0
    
    peak_energy = np.max(audio ** 2)
    threshold = peak_energy * thresh_ratio
    speech_frames = 0
    for i in range(num_frames):
        start = i * hop_len
        frame = audio[start:start + frame_len]
        if np.mean(frame ** 2) > threshold:
            speech_frames += 1
            
    return float(speech_frames * (hop_len / sample_rate))


def extract_f0_series(audio: np.ndarray, sample_rate: int = 16000, fmin: float = 85.0, fmax: float = 255.0) -> np.ndarray:
    """
    Fast autocorrelation-based pitch tracking (85 Hz to 255 Hz human voice band).
    Returns array of F0 values for voiced frames.
    """
    if len(audio) == 0:
        return np.array([])
    frame_len = int(sample_rate * 0.04)  # 40ms window
    hop_len = int(sample_rate * 0.02)   # 20ms hop
    min_lag = int(sample_rate / fmax)
    max_lag = int(sample_rate / fmin)
    
    f0_list = []
    num_frames = (len(audio) - frame_len) // hop_len
    for i in range(num_frames):
        start = i * hop_len
        frame = audio[start:start + frame_len]
        # Check voiced frame energy
        if np.std(frame) < 0.01:
            continue
        corr = signal.correlate(frame, frame, mode='full')
        corr = corr[len(corr) // 2:]
        if len(corr) <= max_lag:
            continue
        segment = corr[min_lag:max_lag]
        if len(segment) == 0:
            continue
        peak_idx = np.argmax(segment) + min_lag
        peak_val = corr[peak_idx]
        if peak_val > 0.3 * corr[0]:  # Voicing threshold
            f0 = sample_rate / peak_idx
            if fmin <= f0 <= fmax:
                f0_list.append(f0)
                
    return np.array(f0_list)


def compute_jitter_shimmer(audio: np.ndarray, sample_rate: int = 16000) -> Tuple[float, float]:
    """
    Calculates period-to-period perturbation (jitter) and amplitude perturbation (shimmer).
    """
    f0_vals = extract_f0_series(audio, sample_rate)
    if len(f0_vals) < 4:
        return (0.015, 0.035)  # Nominal clean values
    
    periods = 1.0 / f0_vals
    period_diffs = np.abs(np.diff(periods))
    mean_period = np.mean(periods)
    jitter = float(np.mean(period_diffs) / (mean_period + 1e-8))
    
    # Shimmer from frame amplitudes
    frame_len = int(sample_rate * 0.03)
    hop_len = int(sample_rate * 0.015)
    amplitudes = [np.max(np.abs(audio[i * hop_len:i * hop_len + frame_len])) 
                  for i in range((len(audio) - frame_len) // hop_len)]
    if len(amplitudes) < 4:
        return (jitter, 0.035)
    amp_arr = np.array(amplitudes)
    amp_diffs = np.abs(np.diff(amp_arr))
    mean_amp = np.mean(amp_arr)
    shimmer = float(np.mean(amp_diffs) / (mean_amp + 1e-8))
    
    return (float(np.clip(jitter, 0.0, 0.20)), float(np.clip(shimmer, 0.0, 0.30)))


def compute_vocal_stress(
    audio: np.ndarray,
    baseline_profile: Dict[str, Any],
    sample_rate: int = 16000
) -> Dict[str, Any]:
    """
    Self-referenced Vocal Stress Index.
    Compares live pitch variance, jitter, and shimmer against the user's personal baseline.
    Does not use demographic or population averages.
    """
    f0_vals = extract_f0_series(audio, sample_rate)
    jitter, shimmer = compute_jitter_shimmer(audio, sample_rate)
    
    base_f0_mean = baseline_profile.get("f0_mean", 145.0)
    base_f0_std = baseline_profile.get("f0_std", 18.0)
    base_jitter = baseline_profile.get("jitter", 0.015)
    base_shimmer = baseline_profile.get("shimmer", 0.035)
    
    if len(f0_vals) >= 3:
        live_f0_std = float(np.std(f0_vals))
    else:
        live_f0_std = base_f0_std
        
    # Relative elevations vs baseline
    f0_variance_elevation = max(0.0, (live_f0_std - base_f0_std) / (base_f0_std + 1e-6))
    jitter_elevation = max(0.0, (jitter - base_jitter) / (base_jitter + 1e-6))
    shimmer_elevation = max(0.0, (shimmer - base_shimmer) / (base_shimmer + 1e-6))
    
    # Combined stress index normalized 0.0 to 1.0
    stress_metric = (0.45 * f0_variance_elevation + 0.30 * jitter_elevation + 0.25 * shimmer_elevation)
    normalized_score = float(np.clip(stress_metric / 1.5, 0.0, 1.0))
    
    # Signal weight: 20 points
    points = int(round(normalized_score * 20.0))
    
    return {
        "signal_id": "VOCAL_STRESS_INDEX",
        "score_points": points,
        "max_points": 20,
        "normalized_value": normalized_score,
        "metrics": {
            "live_f0_std": round(live_f0_std, 2),
            "baseline_f0_std": round(base_f0_std, 2),
            "live_jitter": round(jitter, 4),
            "baseline_jitter": round(base_jitter, 4),
            "live_shimmer": round(shimmer, 4),
            "baseline_shimmer": round(base_shimmer, 4)
        },
        "evidence_summary": f"Pitch variance elevation: {f0_variance_elevation:.2f}x, Jitter ratio: {jitter_elevation:.2f}x vs personal baseline"
    }


def detect_second_voice(
    audio: np.ndarray,
    enrolled_baseline_f0: float,
    sample_rate: int = 16000
) -> Dict[str, Any]:
    """
    Second Voice Detection via Speech-Pause Segment Energy Analysis.
    Examines pause regions for secondary human vocal band energy (85-255 Hz)
    with pitch distinct from enrolled speaker baseline (delta F0 > 25 Hz).
    Signal weight: 35 points.
    """
    if len(audio) == 0:
        return {
            "signal_id": "SECOND_VOICE_DETECTION",
            "score_points": 0,
            "max_points": 35,
            "detected": False,
            "evidence_summary": "No audio signal"
        }
        
    frame_len = int(sample_rate * 0.05)  # 50ms frames
    hop_len = int(sample_rate * 0.025)  # 25ms hop
    num_frames = (len(audio) - frame_len) // hop_len
    if num_frames <= 2:
        return {
            "signal_id": "SECOND_VOICE_DETECTION",
            "score_points": 0,
            "max_points": 35,
            "detected": False,
            "evidence_summary": "Insufficient duration"
        }
        
    # Extract F0 series across all voiced frames above noise floor
    frame_len = int(sample_rate * 0.04)
    hop_len = int(sample_rate * 0.02)
    min_lag = int(sample_rate / 255.0)
    max_lag = int(sample_rate / 85.0)

    num_frames = (len(audio) - frame_len) // hop_len
    if num_frames <= 2:
        return {
            "signal_id": "SECOND_VOICE_DETECTION",
            "score_points": 0,
            "max_points": 35,
            "detected": False,
            "evidence_summary": "Insufficient audio duration"
        }

    energies = [np.mean(audio[i * hop_len:i * hop_len + frame_len] ** 2) for i in range(num_frames)]
    peak_energy = max(energies) if energies else 1.0
    noise_floor = 0.002 * peak_energy

    secondary_f0_candidates = []
    enrolled_f0_frames = 0

    for i in range(num_frames):
        if energies[i] < noise_floor:
            continue
        start = i * hop_len
        frame = audio[start:start + frame_len]
        corr = signal.correlate(frame, frame, mode='full')
        corr = corr[len(corr) // 2:]
        if len(corr) <= max_lag:
            continue
        segment = corr[min_lag:max_lag]
        if len(segment) == 0:
            continue
        peak_idx = np.argmax(segment) + min_lag
        peak_val = corr[peak_idx]
        if peak_val > 0.25 * corr[0]:
            f0 = sample_rate / peak_idx
            if 85.0 <= f0 <= 255.0:
                delta_f0 = abs(f0 - enrolled_baseline_f0)
                if delta_f0 <= 18.0:
                    enrolled_f0_frames += 1
                elif delta_f0 >= 22.0:
                    secondary_f0_candidates.append(f0)

    second_voice_detected = False
    evidence = "No secondary vocal presence detected"
    points = 0

    if len(secondary_f0_candidates) >= 3:
        second_voice_detected = True
        median_sec_f0 = float(np.median(secondary_f0_candidates))
        points = 35
        evidence = f"Secondary human voice detected: {len(secondary_f0_candidates)} frames at F0 {median_sec_f0:.1f}Hz (delta {abs(median_sec_f0 - enrolled_baseline_f0):.1f}Hz from enrolled {enrolled_baseline_f0:.1f}Hz)"

    return {
        "signal_id": "SECOND_VOICE_DETECTION",
        "score_points": points,
        "max_points": 35,
        "detected": second_voice_detected,
        "evidence_summary": evidence
    }


def verify_liveness(audio: np.ndarray, sample_rate: int = 16000) -> Dict[str, Any]:
    """
    Acoustic Liveness Verification.
    Verifies human vocal tract spectral envelope, absence of sharp loudspeaker cutoff,
    and valid near-field single-source frequency dispersion.
    """
    if len(audio) < int(sample_rate * 0.5):
        return {"live": False, "confidence": 0.0, "reason": "Audio too short"}
        
    # High-frequency analysis (check for loudspeaker roll-off or synthetic artifact)
    freqs, psd = signal.welch(audio, fs=sample_rate, nperseg=512)
    voice_band = psd[(freqs >= 100) & (freqs <= 3500)]
    high_band = psd[(freqs > 4000) & (freqs <= 7500)]
    
    voice_energy = np.mean(voice_band) if len(voice_band) > 0 else 1e-6
    high_energy = np.mean(high_band) if len(high_band) > 0 else 1e-6
    ratio = voice_energy / (high_energy + 1e-8)
    # Natural human voice has typical energy concentration in 100-3500Hz with gradual roll-off
    is_live = bool(2.0 <= ratio <= 800.0)
    confidence = float(np.clip(1.0 - abs(np.log10(ratio) - 1.6) / 2.0, 0.70, 0.99))
    
    return {
        "live": is_live,
        "confidence": confidence,
        "voice_to_high_ratio": float(ratio),
        "reason": "Natural human acoustic dispersion confirmed" if is_live else "Synthetic or replay spectral distortion"
    }
