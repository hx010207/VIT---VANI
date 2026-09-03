# PURPOSE: Automated script that prepends standardized file purpose headers across the codebase.
# ROLE IN SYSTEM: Repository maintenance utility for documentation pass compliance.
# TALKS TO: scripts/headers_data.py
import os
import sys
from pathlib import Path

# Add project root to sys.path
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root))

from scripts.headers_data import HEADERS, DOC_SUMMARIES

annotated_count = 0
skipped_files = []

# 1. Apply code file headers
for rel_path, header in HEADERS.items():
    file_path = root / rel_path
    if not file_path.exists():
        print(f"MISSING FILE: {rel_path}")
        skipped_files.append((rel_path, "File not found on disk"))
        continue
    
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Check if already has PURPOSE header
    if "PURPOSE:" in content[:200]:
        print(f"ALREADY ANNOTATED: {rel_path}")
        continue
    
    # Prepend header cleanly
    new_content = header + content
    with open(file_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_content)
    
    annotated_count += 1
    print(f"Annotated: {rel_path}")

# 2. Apply documentation summaries
for rel_path, summary in DOC_SUMMARIES.items():
    file_path = root / rel_path
    if not file_path.exists():
        print(f"MISSING DOC: {rel_path}")
        skipped_files.append((rel_path, "Doc not found on disk"))
        continue
    
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    if any("> **Summary**:" in line for line in lines[:5]):
        print(f"ALREADY SUMMARIZED: {rel_path}")
        continue
    
    # Place after title (# ...)
    if lines and lines[0].startswith("# "):
        new_lines = [lines[0], "\n", summary] + lines[1:]
    else:
        new_lines = [summary] + lines
    
    with open(file_path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(new_lines)
    
    annotated_count += 1
    print(f"Summarized doc: {rel_path}")

# 3. Apply ARB headers
arb_files = {
    "app/lib/l10n/app_en.arb": (
        "English localization strings dictionary defining UI labels, prompts, and mandated calm guidance."
    ),
    "app/lib/l10n/app_hi.arb": (
        "Hindi localization strings dictionary defining UI labels, prompts, and mandated calm guidance."
    )
}

for rel_path, purpose_desc in arb_files.items():
    file_path = root / rel_path
    if not file_path.exists():
        continue
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    if any("@_FILE_HEADER" in line for line in lines[:10]):
        print(f"ALREADY HAS ARB HEADER: {rel_path}")
        continue
    
    # Insert after first line '{'
    header_block = (
        '  "@_FILE_HEADER": {\n'
        f'    "description": "PURPOSE: {purpose_desc} ROLE IN SYSTEM: UI translation bundle. TALKS TO: app/lib/screens/."\n'
        '  },\n'
    )
    new_lines = [lines[0], header_block] + lines[1:]
    with open(file_path, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(new_lines)
    annotated_count += 1
    print(f"Annotated ARB: {rel_path}")

print(f"\nTOTAL FILES ANNOTATED IN PASS: {annotated_count}")
