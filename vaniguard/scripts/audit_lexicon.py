# PURPOSE: Verification utility for auditing coercion lexicon entries for duplicates and weights.
# ROLE IN SYSTEM: Ensures scam lexicon integrity across English and Hindi definitions.
# TALKS TO: worker/scam_lexicon.en.json, worker/scam_lexicon.hi.json
import json
import sys
from collections import Counter
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def audit_and_deduplicate():
    root = Path(__file__).resolve().parent.parent
    for lang, filename in [('en', root / 'worker/scam_lexicon.en.json'), ('hi', root / 'worker/scam_lexicon.hi.json')]:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        terms = data['terms']
        
        seen = {}
        duplicates = []
        unique_terms = []
        for t in terms:
            norm_term = t['term'].strip().lower()
            if norm_term in seen:
                duplicates.append((t, seen[norm_term]))
            else:
                seen[norm_term] = t
                unique_terms.append(t)
        
        print(f"=== {lang.upper()} Lexicon ===")
        print(f"Original Count: {len(terms)}")
        print(f"Duplicates Count: {len(duplicates)}")
        if duplicates:
            for dup, original in duplicates:
                print(f"  Duplicate: '{dup['term']}' ({dup['category']}) matches '{original['term']}' ({original['category']})")
        print(f"Unique Count after dedup: {len(unique_terms)}\n")

        # Save deduplicated
        data['terms'] = unique_terms
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    audit_and_deduplicate()
