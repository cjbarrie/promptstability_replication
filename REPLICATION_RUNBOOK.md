# Replication Runbook

Last updated: 2026-05-13

## Purpose

This is the canonical rerun guide for the current repository.

Use this file when you want to know:

- what to run
- in what order
- which stages are expensive
- how to resume after interruption
- which outputs to expect
- which manuscript-facing figures come from which stages

## External large-file bundle

This frozen export is intentionally GitHub-light.

The largest annotated CSVs are not stored directly in the repo. They are
distributed separately as:

- `FROZEN_EXPORT_large_files.tar`

The archive contains the heavyweight annotated and reannotated CSVs removed from
this repo copy. Download it here:

- [FROZEN_EXPORT_large_files.tar](https://nyu.box.com/s/etfjj3rs4raw7kgu3tysvo8f18elxzq4)

The exact file list is recorded in:

- [LARGE_FILES_MANIFEST.txt](LARGE_FILES_MANIFEST.txt)

After downloading the archive, extract it from the repository root:

```bash
tar -xf FROZEN_EXPORT_large_files.tar
```

That restores the heavyweight files into their expected locations under both:

- `data/`
- `replication_pipeline/data/`

## Environment

Recommended working directory:

- the root of your cloned `promptstability_replication` repository

Recommended Python executable:

```bash
pssenv/bin/python
```

Recommended R entrypoint:

```bash
Rscript
```

## API and model prerequisites

Some stages are pure post hoc rescoring/plotting and do not need API calls.

Some stages do require live model access:

- raw annotation generation: stage `01`
- model capability raw comparison: stage `15`
- updated-model robustness rerun: stage `17`

Those stages depend on the same credentials/model availability as the legacy scripts they replace:

- OpenAI credentials for OpenAI-backed analyses
- local Ollama availability for the DeepSeek comparison

## Canonical entrypoint

Full canonical rerun:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py
```

## Stage order

1. `01_run_raw_annotations.py`
2. `02_export_prompt_texts.py`
3. `03_rescore_raw_within.py`
4. `04_summarize_raw_within.py`
5. `05_plot_raw_within.R`
6. `06_summarize_raw_between.py`
7. `07_plot_raw_between.R`
8. `08_filter_annotations.R`
9. `09_rescore_filtered_within.py`
10. `10_summarize_filtered_within.py`
11. `11_plot_filtered_within.R`
12. `12_plot_filtered_between.R`
13. `13_generate_cost_diagnostics.R`
14. `14_plot_subsample_comparisons.R`
15. `15_run_model_capability_comparison.py`
16. `16_plot_model_capability_comparison.R`
17. `17_run_updated_model_robustness.py`
18. `18_plot_updated_model_robustness.R`
19. `19_bundle_artifacts.py`

## Expensive vs cheap stages

More expensive stages:

- `01` raw annotations
- `03` raw within rescoring
- `09` filtered within rescoring
- `15` model capability raw comparison
- `17` updated-model robustness rerun

Cheap or moderate stages:

- `02`, `04`, `05`, `06`, `07`, `08`, `10`, `11`, `12`, `13`, `14`, `16`, `18`, `19`

## Resume behavior

The heavy rescoring stages support resumable skipping:

- `03_rescore_raw_within.py`
- `09_rescore_filtered_within.py`

The orchestrator uses `--skip-up-to-date` for those rescoring stages unless you explicitly force a different behavior.

Manual resume example:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 9 --to-stage 11 --skip-up-to-date
```

If you want to skip any already-existing rescored outputs regardless of timestamps:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 3 --to-stage 11 --skip-existing
```

## Partial rerun examples

Refresh the current raw-within and raw-between post hoc outputs only:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 3 --to-stage 7
```

Refresh filtering and filtered appendix outputs only:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 8 --to-stage 12 --skip-up-to-date
```

Refresh only the cost and subsample appendix analyses:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 13 --to-stage 14
```

Refresh only the model-comparison appendices:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 15 --to-stage 18
```

Refresh only the self-contained artifact bundle:

```bash
pssenv/bin/python replication_pipeline/00_run_full_replication.py --from-stage 19 --to-stage 19
```

## Canonical outputs

### Raw within

- `plots/combined_within_overlay.png`
- `plots/combined_within_cumulative.png`
- `plots/combined_within_adjacent.png`
- `plots/combined_postpro_within_diagnostics.png`
- `data/annotated/rescored_intra/intra_summary_metrics.csv`
- `data/output/intra_summary_metrics.md`

### Raw inter

- `plots/combined_between_expanded.png`
- `plots/combined_postpro_between_diagnostics.png`
- `data/annotated/inter_summary_metrics.csv`
- `data/output/inter_summary_metrics.md`

### Filtered within

- `plots/combined_within_postpro_cumulative.png`
- `plots/combined_within_postpro_adjacent.png`
- `data/annotated/reannotated/within_rescored/intra_summary_metrics.csv`
- `data/output/intra_summary_metrics_filtered_within.md`

### Filtered between

- `plots/combined_between_postpro.png`

### Cost and subsamples

- `data/annotated/reannotated/comparison/final_summary_rows_subsamples.csv`
- `data/annotated/reannotated/comparison/final_summary_rows_tokens_subsamples.csv`
- `data/annotated/reannotated/comparison/final_summary_rows_subsamples_with_totals.csv`
- `data/annotated/reannotated/comparison/models_cost_estimate.csv`
- `plots/combined_between_subsamples.png`

### Capability

- `plots/combined_model_comparison_plot.png`
- `plots/combined_between_updated.png`

### Self-contained replication bundle

- `replication_pipeline/data/`
- `replication_pipeline/plots/`
- `replication_pipeline/ARTIFACT_BUNDLE_MANIFEST.md`

In this GitHub-light export, the lightweight bundle is included directly and the
heavyweight files are restored from the external archive described above. After
the archive is unpacked, the replication directory becomes fully self-contained
again.

## Manuscript figure dependency map

Current paper-facing dependencies are:

- raw within main-figure candidates:
  - `plots/combined_within_overlay.png`
  - `plots/combined_within_cumulative.png`
  - `plots/combined_within_adjacent.png`
- raw inter main-figure candidate:
  - `plots/combined_between_expanded.png`
- filtered appendix figures:
  - `plots/combined_within_postpro_cumulative.png`
  - `plots/combined_within_postpro_adjacent.png`
  - `plots/combined_between_postpro.png`
- model capability figure:
  - `plots/combined_model_comparison_plot.png`
- updated-model appendix figure:
  - `plots/combined_between_updated.png`
- subsample appendix figure:
  - `plots/combined_between_subsamples.png`

The manuscript itself remains logged separately in:

- [MANUSCRIPT_APPENDIX_REVISION_LOG.md](/Users/christopherbarrie/Dropbox/nyu_projects/promptstability/MANUSCRIPT_APPENDIX_REVISION_LOG.md:1)

## Legacy note

The original top-level scripts still exist and still work in many cases, but they are no longer the recommended rerun path.

Use `replication_pipeline/` as the canonical sequence.
