#!/usr/bin/env python3
"""Canonical prompt-export stage."""

import os
import subprocess
import sys


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PYTHON_BIN = os.path.join(PROJECT_ROOT, "pssenv", "bin", "python")
if not os.path.exists(PYTHON_BIN):
    PYTHON_BIN = sys.executable
SCRIPTS = [
    "11_print_prompts.py",
    "28_print_prompt_variants.py",
]


def main():
    for script in SCRIPTS:
        print(f"Running {script}...")
        completed = subprocess.run([PYTHON_BIN, script], cwd=PROJECT_ROOT, check=False)
        if completed.returncode != 0:
            raise SystemExit(f"{script} failed with exit code {completed.returncode}.")
    print("Prompt export stage completed successfully.")


if __name__ == "__main__":
    main()
