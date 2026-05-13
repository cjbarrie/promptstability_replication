#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT_DIR}/pssenv"
PYTHON_BIN="${PYTHON:-python3}"

echo "Repository root: ${ROOT_DIR}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python executable not found: ${PYTHON_BIN}" >&2
  exit 1
fi

if [ ! -d "${VENV_DIR}" ]; then
  echo "Creating virtual environment at ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
else
  echo "Using existing virtual environment at ${VENV_DIR}"
fi

echo "Upgrading pip/setuptools/wheel"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel

echo "Installing Python dependencies from requirements.txt"
"${VENV_DIR}/bin/python" -m pip install -r "${ROOT_DIR}/requirements.txt"

cat <<'EOF'

Python environment setup complete.

Use the environment with:
  source pssenv/bin/activate

Or call scripts directly with:
  pssenv/bin/python replication_pipeline/00_run_full_replication.py

If you plan to run the R stages too, install the R packages with:
  Rscript install_r_dependencies.R

If you plan to run API/model-dependent stages, also ensure:
  - OPENAI_API_KEY is set for OpenAI-backed stages
  - Ollama is installed and running for local DeepSeek/Ollama stages

EOF
