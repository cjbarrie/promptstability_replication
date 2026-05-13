# promptstability

Repository for the prompt-stability analyses, figures, and manuscript support files used in the current revision workflow.

## Quick start

From a fresh clone, the recommended setup is:

```bash
bash setup_pssenv.sh
Rscript install_r_dependencies.R
```

This creates the project-local Python environment at `pssenv/` and installs the
R packages used by the replication scripts.

Then download the heavyweight data bundle and extract it from the repository
root:

```bash
tar -xf FROZEN_EXPORT_large_files.tar
```

After that, the main replication entrypoint is:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py
```

If you only want the lightweight shipped outputs and post hoc refreshes, you can
start from a later stage; examples are given below and in
[REPLICATION_RUNBOOK.md](REPLICATION_RUNBOOK.md).

## Large-file note

This GitHub-facing export is intentionally lightweight.

Small and moderate-sized CSVs, plots, code, and manuscript files are included
directly in the repo. The largest annotated CSVs have been moved into an
external archive:

- `FROZEN_EXPORT_large_files.tar`

Download the external bundle here:

- [FROZEN_EXPORT_large_files.tar](https://nyu.box.com/s/etfjj3rs4raw7kgu3tysvo8f18elxzq4)

See [LARGE_FILES_MANIFEST.txt](LARGE_FILES_MANIFEST.txt) for the exact file list that lives in the external bundle.

To restore the repo to a fully self-contained state after downloading the
archive, extract it from the repository root:

```bash
tar -xf FROZEN_EXPORT_large_files.tar
```

## Setup details

### Python

The replication scripts assume a project-local virtual environment named
`pssenv/`. The helper script:

```bash
bash setup_pssenv.sh
```

creates that environment and installs everything listed in
[requirements.txt](requirements.txt), including:

- `pandas`, `numpy`, `scipy`
- `matplotlib`, `seaborn`, `plotly`
- `simpledorff`
- `transformers`, `sentence-transformers`, `sentencepiece`, `torch`
- `openai`, `ollama`

### R

Install the required R packages with:

```bash
Rscript install_r_dependencies.R
```

This installs:

- `reticulate`
- `dplyr`, `ggplot2`, `readr`, `tidyr`
- `cowplot`, `stringr`, `tidylog`
- `knitr`, `kableExtra`

### API and model prerequisites

Some stages are entirely post hoc and need no API access. The following stages
do require live model access:

- stage `01`: raw annotations
- stage `15`: DeepSeek/GPT capability comparison
- stage `17`: updated-model robustness rerun

For those stages you will need:

- `OPENAI_API_KEY` set in your shell for OpenAI-backed analyses
- Ollama installed and running for the local DeepSeek/Ollama analyses

## Canonical rerun path

The primary replication entrypoint is:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py
```

This canonical pipeline:

- runs the numbered replication stages in `replication_pipeline/`
- supports partial reruns via `--from-stage` and `--to-stage`
- uses resumable skip behavior for the heavy rescoring stages by default
- regenerates the current paper-facing raw/filtered plots and summary artifacts
- now includes the refined raw-within overlay figure `plots/combined_within_overlay.png`
- rebuilds the lightweight current outputs shipped in this repo
- can use the external large-file archive to restore the full heavyweight rerun state when needed

For full instructions, expected outputs, and partial-rerun examples, see [REPLICATION_RUNBOOK.md](REPLICATION_RUNBOOK.md).

## R walkthrough

For a concrete run-through of how to use R for estimation with this replication package, see [R_example_guide.md](R_example_guide.md) together with the companion script [R_example.R](R_example.R). The guide walks through the R-side estimation workflow and shows how the shipped files can be used from an R session.

## Legacy scripts

The original top-level scripts remain in place for historical continuity, but they are no longer the recommended rerun path.

Examples:

- `00_master.py`
- `12_postpro_within_diagnostics.R`
- `13_postpro_between_diagnostics.R`
- `29_rescore_existing_intra_outputs.py`
- `32_rescore_filtered_within_outputs.py`

Each of these now carries a short header pointing to its canonical equivalent under `replication_pipeline/`.

## Common commands

Run only the current post hoc raw-within and raw-between refresh:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 3 --to-stage 7
```

Resume filtered-within rescoring and plotting after interruption:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 9 --to-stage 11 --skip-up-to-date
```

Refresh only the self-contained artifact bundle:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 19 --to-stage 19
```

## Development package

[![PyPI](https://img.shields.io/pypi/v/promptstability.svg)](https://pypi.org/project/promptstability/)
[![Tests](https://github.com/palaiole13/promptstability/actions/workflows/test.yml/badge.svg)](https://github.com/palaiole13/promptstability/actions/workflows/test.yml)
[![Changelog](https://img.shields.io/github/v/release/palaiole13/promptstability?include_prereleases&label=changelog)](https://github.com/palaiole13/promptstability/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/palaiole13/promptstability/blob/main/LICENSE)

## Installation

### PyPI installation

```bash
pip install promptstability
```

## Library example

```python
import pandas as pd
from utils import PromptStabilityAnalysis, get_openai_api_key
from openai import OpenAI
import ollama

df = pd.read_csv("data/manifestos.csv")
df = df[df["scale"] == "Economic"]
df = df.sample(max(1, int(0.1 * len(df))), random_state=123)
data = list(df["sentence_context"].values)

original_text = (
    "The text provided is a UK party manifesto. "
    "Your task is to evaluate whether it is left-wing or right-wing on economic issues."
)
prompt_postfix = "Respond with 0 for left-wing or 1 for right-wing."

APIKEY = get_openai_api_key()
client = OpenAI(api_key=APIKEY)

def annotate_openai(text, prompt, temperature=0.1):
    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        temperature=temperature,
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": text},
        ],
    )
    return "".join(choice.message.content for choice in response.choices)

psa_openai = PromptStabilityAnalysis(annotation_function=annotate_openai, data=data)
ka_openai_intra, annotated_openai_intra = psa_openai.intra_pss(
    original_text,
    prompt_postfix,
    iterations=3,
    plot=False,
)

def annotate_ollama(text, prompt, temperature=0.1):
    response = ollama.chat(
        model="deepseek-r1:8b",
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": text},
        ],
    )
    return response["message"]["content"]

psa_ollama = PromptStabilityAnalysis(annotation_function=annotate_ollama, data=data)
ka_ollama_inter, annotated_ollama_inter = psa_ollama.inter_pss(
    original_text,
    prompt_postfix,
    nr_variations=3,
    temperatures=[0.1, 0.5],
    iterations=1,
    plot=False,
)
```

## Development

To contribute to the library package itself, send PRs to the library repo at [https://github.com/palaiole13/promptstability](https://github.com/palaiole13/promptstability).
