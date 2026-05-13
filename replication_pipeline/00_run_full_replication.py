#!/usr/bin/env python3
"""Canonical end-to-end replication orchestrator.

Run this script from the repository root, or from anywhere via an absolute path.
It executes the numbered stages in `replication_pipeline/` in a fixed order and
prints the expected artifacts for each stage.
"""

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PYTHON_BIN = os.path.join(PROJECT_ROOT, "pssenv", "bin", "python")
if not os.path.exists(PYTHON_BIN):
    PYTHON_BIN = sys.executable
RSCRIPT_BIN = "Rscript"


@dataclass(frozen=True)
class Stage:
    number: int
    name: str
    command: list[str]
    outputs: list[str]


def script_path(name: str) -> str:
    return os.path.join(PROJECT_ROOT, "replication_pipeline", name)


STAGES = [
    Stage(1, "raw annotations", [PYTHON_BIN, script_path("01_run_raw_annotations.py")], [
        "data/annotated/*_within_expanded.csv",
        "data/annotated/*_between_expanded.csv",
    ]),
    Stage(2, "prompt exports", [PYTHON_BIN, script_path("02_export_prompt_texts.py")], [
        "data/output/original_prompts.tex",
        "data/output/prompt_variants_expanded.tex",
        "data/output/poor_performing_prompts.tex",
        "data/output/poor_performing_prompts.csv",
    ]),
    Stage(3, "raw within rescoring", [PYTHON_BIN, script_path("03_rescore_raw_within.py")], [
        "data/annotated/rescored_intra/*_within_rescored.csv",
    ]),
    Stage(4, "raw within summaries", [PYTHON_BIN, script_path("04_summarize_raw_within.py")], [
        "data/annotated/rescored_intra/intra_summary_metrics.csv",
        "data/output/intra_summary_metrics.md",
    ]),
    Stage(5, "raw within plots", [RSCRIPT_BIN, script_path("05_plot_raw_within.R")], [
        "plots/combined_within_cumulative.png",
        "plots/combined_within_adjacent.png",
        "plots/combined_postpro_within_diagnostics.png",
    ]),
    Stage(6, "raw inter summaries", [PYTHON_BIN, script_path("06_summarize_raw_between.py")], [
        "data/annotated/inter_summary_metrics.csv",
        "data/output/inter_summary_metrics.md",
    ]),
    Stage(7, "raw inter plots", [RSCRIPT_BIN, script_path("07_plot_raw_between.R")], [
        "plots/combined_between_expanded.png",
        "plots/combined_postpro_between_diagnostics.png",
    ]),
    Stage(8, "filter annotations", [RSCRIPT_BIN, script_path("08_filter_annotations.R")], [
        "data/annotated/reannotated/within/*_filtered.csv",
        "data/annotated/reannotated/between/*_filtered.csv",
    ]),
    Stage(9, "filtered within rescoring", [PYTHON_BIN, script_path("09_rescore_filtered_within.py")], [
        "data/annotated/reannotated/within_rescored/*_rescored.csv",
    ]),
    Stage(10, "filtered within summaries", [PYTHON_BIN, script_path("10_summarize_filtered_within.py")], [
        "data/annotated/reannotated/within_rescored/intra_summary_metrics.csv",
        "data/output/intra_summary_metrics_filtered_within.md",
    ]),
    Stage(11, "filtered within plots", [RSCRIPT_BIN, script_path("11_plot_filtered_within.R")], [
        "plots/combined_within_postpro_cumulative.png",
        "plots/combined_within_postpro_adjacent.png",
    ]),
    Stage(12, "filtered between plots", [RSCRIPT_BIN, script_path("12_plot_filtered_between.R")], [
        "plots/combined_between_postpro.png",
    ]),
    Stage(13, "cost diagnostics", [RSCRIPT_BIN, script_path("13_generate_cost_diagnostics.R")], [
        "data/annotated/reannotated/comparison/final_summary_rows_subsamples_with_totals.csv",
        "data/annotated/reannotated/comparison/models_cost_estimate.csv",
    ]),
    Stage(14, "subsample plots", [RSCRIPT_BIN, script_path("14_plot_subsample_comparisons.R")], [
        "plots/combined_between_subsamples.png",
    ]),
    Stage(15, "model capability raw comparison", [PYTHON_BIN, script_path("15_run_model_capability_comparison.py")], [
        "data/example/openai_intra.csv",
        "data/example/openai_inter.csv",
        "data/example/ollama_intra.csv",
        "data/example/ollama_inter.csv",
    ]),
    Stage(16, "model capability plot", [RSCRIPT_BIN, script_path("16_plot_model_capability_comparison.R")], [
        "plots/combined_model_comparison_plot.png",
    ]),
    Stage(17, "updated-model robustness rerun", [PYTHON_BIN, script_path("17_run_updated_model_robustness.py")], [
        "data/annotated/news_short_between_updated.csv",
        "data/annotated/news_between_updated.csv",
        "data/annotated/stance_long_between_updated.csv",
        "data/annotated/synth_short_between_updated.csv",
    ]),
    Stage(18, "updated-model robustness plot", [RSCRIPT_BIN, script_path("18_plot_updated_model_robustness.R")], [
        "plots/combined_between_updated.png",
    ]),
    Stage(19, "bundle replication artifacts", [PYTHON_BIN, script_path("19_bundle_artifacts.py")], [
        "replication_pipeline/data/",
        "replication_pipeline/plots/",
        "replication_pipeline/ARTIFACT_BUNDLE_MANIFEST.md",
    ]),
]


CANONICAL_OUTPUTS = [
    "plots/combined_within_cumulative.png",
    "plots/combined_within_adjacent.png",
    "plots/combined_postpro_within_diagnostics.png",
    "plots/combined_between_expanded.png",
    "plots/combined_postpro_between_diagnostics.png",
    "data/annotated/inter_summary_metrics.csv",
    "data/output/inter_summary_metrics.md",
    "plots/combined_within_postpro_cumulative.png",
    "plots/combined_within_postpro_adjacent.png",
    "data/annotated/reannotated/within_rescored/intra_summary_metrics.csv",
    "data/output/intra_summary_metrics_filtered_within.md",
    "plots/combined_between_postpro.png",
    "plots/combined_between_subsamples.png",
    "plots/combined_model_comparison_plot.png",
    "plots/combined_between_updated.png",
    "replication_pipeline/data/",
    "replication_pipeline/plots/",
    "replication_pipeline/ARTIFACT_BUNDLE_MANIFEST.md",
]


def parse_args():
    parser = argparse.ArgumentParser(description="Run the canonical replication pipeline.")
    parser.add_argument("--from-stage", type=int, default=1, help="First stage number to run.")
    parser.add_argument("--to-stage", type=int, default=19, help="Last stage number to run.")
    parser.add_argument("--bootstrap-samples", type=int, default=1000, help="Bootstrap samples for heavy rescoring stages.")
    parser.add_argument("--skip-existing", action="store_true", help="Skip rescoring outputs that already exist.")
    parser.add_argument("--skip-up-to-date", action="store_true", help="Skip rescoring outputs that are newer than their inputs.")
    return parser.parse_args()


def run_stage(stage: Stage, args) -> None:
    command = list(stage.command)
    if stage.number in {3, 9}:
        command.extend(["--bootstrap-samples", str(args.bootstrap_samples)])
        if args.skip_existing:
            command.append("--skip-existing")
        if args.skip_up_to_date or not args.skip_existing:
            command.append("--skip-up-to-date")

    print(f"\n=== Stage {stage.number:02d}: {stage.name} ===")
    print("Command:", " ".join(command))
    print("Expected outputs:")
    for output in stage.outputs:
        print(f"  - {output}")

    completed = subprocess.run(command, cwd=PROJECT_ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(f"Stage {stage.number:02d} failed with exit code {completed.returncode}.")


def main():
    args = parse_args()
    if args.from_stage < 1 or args.to_stage > len(STAGES) or args.from_stage > args.to_stage:
        raise SystemExit("Invalid stage range.")

    for stage in STAGES:
        if args.from_stage <= stage.number <= args.to_stage:
            run_stage(stage, args)

    print("\nReplication pipeline finished.")
    print("Canonical current outputs:")
    for output in CANONICAL_OUTPUTS:
        print(f"  - {output}")


if __name__ == "__main__":
    main()
