# PURPOSE: Pytest test fixtures, database mocking, and test client configurations.
# ROLE IN SYSTEM: Sets up clean in-memory database state and authentication mocks for test suite.
# TALKS TO: pytest, server/app/database.py, server/app/main.py
import sys
from pathlib import Path

# Add vaniguard directory to sys.path
vaniguard_dir = Path(__file__).resolve().parent.parent.parent
if str(vaniguard_dir) not in sys.path:
    sys.path.insert(0, str(vaniguard_dir))
