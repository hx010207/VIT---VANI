# PURPOSE: Generator script creating docs/FILE_MAP.md indexing all files and single-sentence purposes.
# ROLE IN SYSTEM: Builds the primary repository navigation index for engineers and AI agents.
# TALKS TO: docs/FILE_MAP.md
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent

# Discover all tracked files in vaniguard
ignore_dirs = {'.venv', '__pycache__', '.pytest_cache', '.git'}
files = []
for p in sorted(root.rglob('*')):
    if p.is_file() and not any(part in ignore_dirs for part in p.parts):
        rel = p.relative_to(root)
        files.append(rel)

file_entries = []

# Non-annotated file descriptions
FALLBACK_PURPOSES = {
    ".env": "Local environment secret configuration file (never committed to git).",
    ".env.example": "Template environment variables file showing required keys and format.",
    ".gitignore": "Git ignore rules for caches, virtual environments, models, and secrets.",
    "pytest.ini": "Pytest configuration defining test discovery patterns and options.",
    "pyproject.toml": "Project dependency specifications, metadata, and build configurations.",
    "RULES.md": "Development rules, security constraints, and coding invariants for VaniGuard.",
    "app/pubspec.yaml": "Flutter project dependencies, asset registrations, and app metadata.",
    "bench/fixtures/scam_eval_dataset.json": "Evaluation dataset containing benchmark coercion utterances and transcripts.",
    "worker/scam_lexicon.en.json": "Curated English scam and coercion lexicon keywords with risk weights.",
    "worker/scam_lexicon.hi.json": "Curated Hindi scam and coercion lexicon keywords with risk weights.",
    "scripts/apply_file_headers.py": "Utility script that applied standardized documentation headers across files.",
    "scripts/headers_data.py": "Dictionary definitions for file header documentation and summaries.",
    "scripts/generate_file_map.py": "Generator script creating docs/FILE_MAP.md file purpose catalog.",
}

for rel in files:
    rel_str = str(rel).replace("\\", "/")
    file_path = root / rel
    purpose = ""
    
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read(1500)
    except Exception:
        content = ""
    
    # Check for PURPOSE in comment header
    m = re.search(r"PURPOSE:\s*([^\n\r]+)", content)
    if m:
        purpose = m.group(1).strip()
    elif rel_str.startswith("docs/"):
        m_doc = re.search(r"\*\*Summary\*\*:\s*([^\n\r]+)", content)
        if m_doc:
            purpose = m_doc.group(1).strip()
        else:
            purpose = f"Documentation file covering {rel.stem}."
    elif rel_str in FALLBACK_PURPOSES:
        purpose = FALLBACK_PURPOSES[rel_str]
    else:
        purpose = f"Project file for {rel.name}."
    
    # Ensure no em-dashes and truncate to 100 characters max
    purpose = purpose.replace("—", "-").replace("–", "-")
    if len(purpose) > 100:
        purpose = purpose[:97].rstrip() + "..."
    
    file_entries.append((rel_str, purpose))

# Build tree-style FILE_MAP.md
lines = [
    "# VaniGuard: Repository File Map",
    "",
    "> **Notice for AI Agents and Engineers**: Read this file first to locate relevant modules before opening source files.",
    "",
    "## Project Tree and File Purpose Index",
    "",
]

for path, purpose in file_entries:
    lines.append(f"- `{path}`: {purpose}")

lines.append("")

output_file = root / "docs" / "FILE_MAP.md"
with open(output_file, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines))

print(f"FILE_MAP.md generated with {len(file_entries)} file entries.")

# Print tree representation to stdout as required by rule 5
for path, purpose in file_entries:
    print(f"{path}: {purpose}")
