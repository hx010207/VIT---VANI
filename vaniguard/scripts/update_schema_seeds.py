import json
from pathlib import Path

def generate_lexicon_sql():
    vaniguard_dir = Path(__file__).resolve().parent.parent
    en_path = vaniguard_dir / "worker" / "scam_lexicon.en.json"
    hi_path = vaniguard_dir / "worker" / "scam_lexicon.hi.json"
    migration_path = vaniguard_dir / "migrations" / "001_initial_schema.sql"

    with open(en_path, "r", encoding="utf-8") as f:
        en_terms = json.load(f)["terms"]
    with open(hi_path, "r", encoding="utf-8") as f:
        hi_terms = json.load(f)["terms"]

    inserts = []
    # English terms
    inserts.append("-- Seed English Scam Lexicon (90 terms)")
    inserts.append("INSERT INTO scam_lexicon (language, term, weight, category, version, active) VALUES")
    en_rows = []
    for t in en_terms:
        term_escaped = t["term"].replace("'", "''")
        en_rows.append(f"('en', '{term_escaped}', {t['weight']}, '{t['category']}', 'v1', TRUE)")
    inserts.append(",\n".join(en_rows) + "\nON CONFLICT (language, term, version) DO NOTHING;\n")

    # Hindi terms
    inserts.append("-- Seed Hindi Scam Lexicon (99 terms)")
    inserts.append("INSERT INTO scam_lexicon (language, term, weight, category, version, active) VALUES")
    hi_rows = []
    for t in hi_terms:
        term_escaped = t["term"].replace("'", "''")
        hi_rows.append(f"('hi', '{term_escaped}', {t['weight']}, '{t['category']}', 'v1', TRUE)")
    inserts.append(",\n".join(hi_rows) + "\nON CONFLICT (language, term, version) DO NOTHING;\n")

    sql_seeds = "\n".join(inserts)

    # Read current migration
    with open(migration_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Append after seed risk signal config if not already present
    if "Seed English Scam Lexicon" not in content:
        # Place seeds before RLS declarations
        target = "-- Row Level Security (RLS) Declarations"
        parts = content.split(target)
        if len(parts) == 2:
            new_content = parts[0] + sql_seeds + "\n" + target + parts[1]
            with open(migration_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print("Successfully injected 90 English and 99 Hindi scam terms into 001_initial_schema.sql")
        else:
            print("Could not find target marker in 001_initial_schema.sql")
    else:
        print("Scam lexicon seeds already present in 001_initial_schema.sql")

if __name__ == "__main__":
    generate_lexicon_sql()
