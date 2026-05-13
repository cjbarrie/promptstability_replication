#!/usr/bin/env python3
"""Canonical DeepSeek/GPT capability comparison stage.

This stage is the numbered replication entrypoint for the raw data generation
currently implemented in `23_compare_between_models.py`.
"""

import subprocess
import sys
import os


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
LEGACY_SCRIPT = os.path.join(PROJECT_ROOT, "23_compare_between_models.py")
PYTHON_BIN = os.path.join(PROJECT_ROOT, "pssenv", "bin", "python")
if not os.path.exists(PYTHON_BIN):
    PYTHON_BIN = sys.executable


def main():
    completed = subprocess.run([PYTHON_BIN, LEGACY_SCRIPT], cwd=PROJECT_ROOT, check=False)
    raise SystemExit(completed.returncode)


if __name__ == "__main__":
    main()
