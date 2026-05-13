#!/usr/bin/env python3
"""Canonical raw-annotation generation stage."""

import argparse
import concurrent.futures
import os
import subprocess
import sys
import warnings


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PYTHON_BIN = os.path.join(PROJECT_ROOT, "pssenv", "bin", "python")
if not os.path.exists(PYTHON_BIN):
    PYTHON_BIN = sys.executable

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings(
    "ignore",
    message="Some weights of PegasusForConditionalGeneration were not initialized from the model checkpoint",
)

SCRIPTS = [
    "00a_tweets_rd_example.py",
    "00b_tweets_pop_example.py",
    "01a_news_example.py",
    "01b_news_short_example.py",
    "02a_manifestos_example.py",
    "02b_manifestos_multi_example.py",
    "03a_stance_example.py",
    "03b_stance_long_example.py",
    "04a_mii_example.py",
    "04b_mii_long_example.py",
    "05a_synth_example.py",
    "05b_synth_short_example.py",
]


def run_script(script: str) -> int:
    print(f"Running {script}...")
    process = subprocess.Popen(
        [PYTHON_BIN, script],
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    while True:
        output = process.stdout.readline()
        if output == "" and process.poll() is not None:
            break
        if output:
            print(f"{script} stdout: {output.strip()}")

    error = process.stderr.read()
    if error:
        print(f"{script} stderr: {error.strip()}")

    process.wait()
    print(f"Finished {script} with return code {process.returncode}")
    return process.returncode


def main():
    parser = argparse.ArgumentParser(description="Run the twelve raw annotation scripts.")
    parser.add_argument("--max-workers", type=int, default=2, help="Number of annotation scripts to run in parallel.")
    args = parser.parse_args()

    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        future_map = {executor.submit(run_script, script): script for script in SCRIPTS}
        for future in concurrent.futures.as_completed(future_map):
            script = future_map[future]
            try:
                return_code = future.result()
                if return_code != 0:
                    failures.append((script, return_code))
            except Exception as exc:  # pragma: no cover - defensive
                failures.append((script, exc))

    if failures:
        for script, failure in failures:
            print(f"Failure in {script}: {failure}")
        raise SystemExit(1)

    print("All raw annotation scripts completed successfully.")


if __name__ == "__main__":
    main()
