import argparse
import os
import subprocess
import sys

import pandas as pd

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LOCAL_VENV_PYTHON = os.path.join(PROJECT_ROOT, 'pssenv', 'bin', 'python')
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

try:
    import simpledorff
except ModuleNotFoundError:
    if os.path.exists(LOCAL_VENV_PYTHON) and os.path.abspath(sys.executable) != os.path.abspath(LOCAL_VENV_PYTHON):
        print(f"simpledorff not found in {sys.executable}. Re-running with {LOCAL_VENV_PYTHON}...")
        completed = subprocess.run([LOCAL_VENV_PYTHON, __file__, *sys.argv[1:]], check=False)
        raise SystemExit(completed.returncode)
    raise SystemExit(
        "simpledorff is not installed in the active Python environment.\n"
        "Try either:\n"
        "  pssenv/bin/python 29_rescore_existing_intra_outputs.py --bootstrap-samples 1000\n"
        "or activate the project environment before running the script."
    )

from utils import PromptStabilityAnalysis


WITHIN_FILES = {
    'tweets_rd': 'data/annotated/tweets_rd_within_expanded.csv',
    'tweets_pop': 'data/annotated/tweets_pop_within_expanded.csv',
    'news': 'data/annotated/news_within_expanded.csv',
    'news_short': 'data/annotated/news_short_within_expanded.csv',
    'manifestos': 'data/annotated/manifestos_within_expanded.csv',
    'manifestos_multi': 'data/annotated/manifestos_multi_within_expanded.csv',
    'stance': 'data/annotated/stance_within_expanded.csv',
    'stance_long': 'data/annotated/stance_long_within_expanded.csv',
    'mii': 'data/annotated/mii_within_expanded.csv',
    'mii_long': 'data/annotated/mii_long_within_expanded.csv',
    'synth': 'data/annotated/synth_within_expanded.csv',
    'synth_short': 'data/annotated/synth_short_within_expanded.csv'
}


def get_metric_fn(dataset_name):
    if dataset_name == 'manifestos_multi':
        return simpledorff.metrics.interval_metric
    return simpledorff.metrics.nominal_metric


def main():
    parser = argparse.ArgumentParser(description="Rescore saved intra-PSS annotation files without rerunning model calls.")
    parser.add_argument('--bootstrap-samples', type=int, default=1000, help='Number of bootstrap samples to use.')
    parser.add_argument(
        '--output-dir',
        default='data/annotated/rescored_intra',
        help='Directory where rescored CSVs should be written.'
    )
    parser.add_argument(
        '--skip-existing',
        action='store_true',
        help='Skip rescoring when the target output CSV already exists.'
    )
    parser.add_argument(
        '--skip-up-to-date',
        action='store_true',
        help='Skip rescoring when the target output CSV exists and is newer than the input CSV.'
    )
    args = parser.parse_args()

    os.chdir(PROJECT_ROOT)
    os.makedirs(args.output_dir, exist_ok=True)

    for dataset_name, input_path in WITHIN_FILES.items():
        output_path = os.path.join(args.output_dir, f'{dataset_name}_within_rescored.csv')

        if args.skip_existing and os.path.exists(output_path):
            print(f"Skipping existing output {output_path}")
            continue

        if args.skip_up_to_date and os.path.exists(output_path):
            input_mtime = os.path.getmtime(input_path)
            output_mtime = os.path.getmtime(output_path)
            if output_mtime >= input_mtime:
                print(f"Skipping up-to-date output {output_path}")
                continue

        print(f'Rescoring {dataset_name} from {input_path}...')
        df = pd.read_csv(input_path)

        psa = PromptStabilityAnalysis(
            annotation_function=None,
            data=[],
            metric_fn=get_metric_fn(dataset_name),
            load_generation_models=False
        )

        _, rescored_df = psa.score_intra_annotations(
            df,
            bootstrap_samples=args.bootstrap_samples,
            analysis_modes=['cumulative_alpha', 'adjacent_alpha']
        )

        rescored_df.to_csv(output_path, index=False)
        print(f'Wrote {output_path}')


if __name__ == '__main__':
    main()
