# PURPOSE: Benchmark evaluating coercion script lexicon matching against test utterances.
# ROLE IN SYSTEM: Measures keyword recall, weighting accuracy, and false-positive boundaries.
# TALKS TO: worker/scam_lexicon.en.json, worker/scam_lexicon.hi.json, server/app/services/risk_engine.py
import json
import sys
from pathlib import Path

# Add project root to sys.path
root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from server.app.services.risk_engine import risk_engine


def run_scam_lexicon_benchmark():
    fixtures_path = Path(__file__).resolve().parent / "fixtures" / "scam_eval_dataset.json"
    if not fixtures_path.exists():
        print(f"Error: Fixtures file not found at {fixtures_path}")
        sys.exit(1)

    with open(fixtures_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    samples = data.get("samples", [])
    print(f"Running Scam Lexicon Benchmark on {len(samples)} curated utterances...")

    tp = 0
    fp = 0
    tn = 0
    fn = 0

    results_by_lang = {"en": {"tp": 0, "fp": 0, "tn": 0, "fn": 0}, "hi": {"tp": 0, "fp": 0, "tn": 0, "fn": 0}}

    for item in samples:
        text = item["text"]
        label = item["label"]
        lang = item.get("language", "en")
        
        score, evidence = risk_engine.compute_lexicon_score(text, lang)
        predicted_coercion = (score >= 5)  # Operating point: any confirmed scam marker matched

        if label == "coercion" and predicted_coercion:
            tp += 1
            results_by_lang[lang]["tp"] += 1
        elif label == "legitimate" and predicted_coercion:
            fp += 1
            results_by_lang[lang]["fp"] += 1
            print(f"False Positive [{lang}]: '{text}' (Score: {score}, Evidence: {evidence})")
        elif label == "legitimate" and not predicted_coercion:
            tn += 1
            results_by_lang[lang]["tn"] += 1
        elif label == "coercion" and not predicted_coercion:
            fn += 1
            results_by_lang[lang]["fn"] += 1
            print(f"False Negative [{lang}]: '{text}' (Score: {score})")

    total = len(samples)
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
    accuracy = (tp + tn) / total if total > 0 else 0.0

    print("\nBenchmark Evaluation Results:")
    print(f"Total Utterances: {total}")
    print(f"True Positives (TP): {tp}")
    print(f"False Positives (FP): {fp}")
    print(f"True Negatives (TN): {tn}")
    print(f"False Negatives (FN): {fn}")
    print(f"Precision: {precision:.4f} (Target: >= 0.9000)")
    print(f"Recall: {recall:.4f}")
    print(f"F1 Score: {f1:.4f}")
    print(f"Overall Accuracy: {accuracy:.4f}")

    for lang, m in results_by_lang.items():
        lang_prec = m["tp"] / (m["tp"] + m["fp"]) if (m["tp"] + m["fp"]) > 0 else 0.0
        lang_rec = m["tp"] / (m["tp"] + m["fn"]) if (m["tp"] + m["fn"]) > 0 else 0.0
        print(f"  Language [{lang}]: Precision = {lang_prec:.4f}, Recall = {lang_rec:.4f}, (TP: {m['tp']}, FP: {m['fp']})")

    assert precision >= 0.90, f"Benchmark Failure: Precision {precision:.4f} is below 0.90 target"
    print("\nPASS: Scam Lexicon Detector meets precision target >= 0.90 at operating threshold.")
    if precision >= 0.99 or recall >= 0.99:
        print("WARNING: Fixture set is synthetic/curated. Result reflects algorithmic rule validation;")
        print("real-world unstructured conversational audio requires field revalidation.")
    return {
        "total": total,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "accuracy": accuracy
    }


if __name__ == "__main__":
    run_scam_lexicon_benchmark()
