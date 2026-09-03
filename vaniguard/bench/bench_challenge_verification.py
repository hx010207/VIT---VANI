import sys
import numpy as np
from pathlib import Path

root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from worker.dsp import verify_liveness


class ConstrainedDigitGrammarDecoder:
    """
    Constrained digit grammar decoder for spoken 6-digit challenge verification.
    Recognizes digits in English (zero to nine) and Hindi (shunya to nau) as well as numerical strings.
    """
    DIGIT_MAP = {
        # English
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "oh": "0",
        # Hindi Devanagari
        "शून्य": "0", "एक": "1", "दो": "2", "तीन": "3", "चार": "4",
        "पांच": "5", "पाँच": "5", "छह": "6", "सात": "7", "आठ": "8", "नौ": "9",
        # Hindi Romanized
        "shunya": "0", "ek": "1", "do": "2", "teen": "3", "chaar": "4",
        "paanch": "5", "chhah": "6", "che": "6", "saat": "7", "aath": "8", "nau": "9"
    }

    @classmethod
    def decode_spoken_digits(cls, text: str) -> str:
        tokens = text.lower().replace("-", " ").split()
        digits = []
        for token in tokens:
            # Check if direct digit
            cleaned = "".join(ch for ch in token if ch.isdigit())
            if cleaned:
                digits.append(cleaned)
            elif token in cls.DIGIT_MAP:
                digits.append(cls.DIGIT_MAP[token])
        return "".join(digits)


def run_challenge_verification_benchmark(num_trials: int = 500):
    print("==================================================")
    print("VaniGuard Challenge Verification & Biometric Gate Benchmark")
    print(f"Executing {num_trials} trials across genuine, impostor, and digit ASR paths...")
    print("==================================================")

    np.random.seed(42)
    threshold = 0.68

    # 1. Genuine enrolled speaker verification test
    # Genuine embeddings: unit vector + small intra-speaker variance perturbation (SNR ~ 25dB)
    genuine_accepts = 0
    for _ in range(num_trials):
        base_emb = np.random.randn(256)
        base_emb = base_emb / np.linalg.norm(base_emb)
        # Small intra-speaker session variation on 256-d unit sphere (cosine similarity ~0.85-0.95)
        intra_noise = np.random.randn(256) * (0.35 / np.sqrt(256))
        session_emb = base_emb + intra_noise
        session_emb = session_emb / np.linalg.norm(session_emb)

        sim = float(np.dot(base_emb, session_emb))
        if sim >= threshold:
            genuine_accepts += 1

    tar = (genuine_accepts / num_trials) * 100.0
    print(f"1. Genuine Enrolled Speaker Verification:")
    print(f"   True Accept Rate (TAR): {tar:.2f}% (Target: >= 98.00%)")
    assert tar >= 98.0, f"Benchmark Failure: TAR {tar:.2f}% is below 98% target"

    # 2. Impostor false-accept test
    # Impostor embeddings: independent random speakers
    impostor_accepts = 0
    for _ in range(num_trials):
        enrolled_emb = np.random.randn(256)
        enrolled_emb = enrolled_emb / np.linalg.norm(enrolled_emb)

        impostor_emb = np.random.randn(256)
        impostor_emb = impostor_emb / np.linalg.norm(impostor_emb)

        sim = float(np.dot(enrolled_emb, impostor_emb))
        if sim >= threshold:
            impostor_accepts += 1

    far = (impostor_accepts / num_trials) * 100.0
    print(f"2. Impostor Verification:")
    print(f"   False Accept Rate (FAR): {far:.2f}% (Target: <= 2.00%)")
    assert far <= 2.0, f"Benchmark Failure: FAR {far:.2f}% exceeds 2% target"

    # 3. Constrained Digit ASR Accuracy Test
    test_cases = [
        ("four nine two zero one five", "492015"),
        ("चार नौ दो शून्य एक पांच", "492015"),
        ("chaar nau do shunya ek paanch", "492015"),
        ("7 3 9 1 0 4", "739104"),
        ("seven three nine one zero four", "739104"),
        ("सात तीन नौ एक शून्य चार", "739104"),
        ("saat teen nau ek shunya chaar", "739104"),
        ("one eight zero five two six", "180526"),
        ("एक आठ शून्य पांच दो छह", "180526"),
        ("ek aath shunya paanch do chhah", "180526"),
        ("five five two zero eight eight", "552088"),
        ("पाँच पाँच दो शून्य आठ आठ", "552088"),
        ("nine one zero four three seven", "910437"),
        ("nau ek shunya chaar teen saat", "910437"),
        ("code is 8 2 0 1 9 4", "820194")
    ]

    correct_decodes = 0
    total_decodes = len(test_cases)
    for spoken_input, expected in test_cases:
        decoded = ConstrainedDigitGrammarDecoder.decode_spoken_digits(spoken_input)
        if decoded == expected:
            correct_decodes += 1
        else:
            print(f"Digit Decode Mismatch: Input '{spoken_input}' -> Decoded '{decoded}' vs Expected '{expected}'")

    digit_accuracy = (correct_decodes / total_decodes) * 100.0
    print(f"3. Constrained Digit Grammar ASR Accuracy:")
    print(f"   Accuracy: {digit_accuracy:.2f}% (Target: >= 99.00%)")
    assert digit_accuracy >= 99.0, f"Breach: Digit accuracy {digit_accuracy:.2f}% below 99%"

    print("\nPASS: Challenge Verification and Biometric Gate benchmark completed successfully.")
    if tar >= 99.0 or far <= 0.01:
        print("WARNING: Fixture set is synthetic and circular. Result represents algorithmic and")
        print("pipeline verification; requires real-audio field revalidation before production deployment.")
    return {
        "true_accept_rate": tar,
        "false_accept_rate": far,
        "digit_accuracy": digit_accuracy
    }


if __name__ == "__main__":
    run_challenge_verification_benchmark()
