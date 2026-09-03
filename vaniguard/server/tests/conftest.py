import sys
from pathlib import Path

# Add vaniguard directory to sys.path
vaniguard_dir = Path(__file__).resolve().parent.parent.parent
if str(vaniguard_dir) not in sys.path:
    sys.path.insert(0, str(vaniguard_dir))
