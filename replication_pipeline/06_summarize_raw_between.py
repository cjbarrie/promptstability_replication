import argparse
import math
import os
import subprocess
import sys

import pandas as pd

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LOCAL_VENV_PYTHON = os.path.join(PROJECT_ROOT, 'pssenv', 'bin', 'python')
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

try:
    from utils import PromptStabilityAnalysis
except ModuleNotFoundError as exc:
    if os.path.exists(LOCAL_VENV_PYTHON) and os.path.abspath(sys.executable) != os.path.abspath(LOCAL_VENV_PYTHON):
        print(f"{exc}. Re-running with {LOCAL_VENV_PYTHON}...")
        completed = subprocess.run([LOCAL_VENV_PYTHON, __file__, *sys.argv[1:]], check=False)
        raise SystemExit(completed.returncode)
    raise


BETWEEN_FILES = {
    'tweets_rd': 'data/annotated/tweets_rd_between_expanded.csv',
    'tweets_pop': 'data/annotated/tweets_pop_between_expanded.csv',
    'news': 'data/annotated/news_between_expanded.csv',
    'news_short': 'data/annotated/news_short_between_expanded.csv',
    'manifestos': 'data/annotated/manifestos_between_expanded.csv',
    'manifestos_multi': 'data/annotated/manifestos_multi_between_expanded.csv',
    'stance': 'data/annotated/stance_between_expanded.csv',
    'stance_long': 'data/annotated/stance_long_between_expanded.csv',
    'mii': 'data/annotated/mii_between_expanded.csv',
    'mii_long': 'data/annotated/mii_long_between_expanded.csv',
    'synth': 'data/annotated/synth_between_expanded.csv',
    'synth_short': 'data/annotated/synth_short_between_expanded.csv'
}


def fmt(value, digits=3):
    if value is None:
        return ''
    if isinstance(value, (int, float)):
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return ''
        if float(value).is_integer() and abs(value) >= 1:
            return str(int(value))
        return f'{value:.{digits}f}'
    return str(value)


def build_markdown(df, output_path):
    lines = [
        '# Inter-PSS Summary Metrics',
        '',
        'Generated from saved between-prompt outputs.',
        '',
        '| dataset | mean alpha | sd across temperatures | min alpha | temp at min | max alpha | range | share below threshold |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
    ]

    for _, row in df.sort_values('dataset').iterrows():
        lines.append(
            f"| {row['dataset']} | {fmt(row.get('mean_alpha'))} | "
            f"{fmt(row.get('sd_alpha_across_temperatures'))} | "
            f"{fmt(row.get('min_alpha'))} | "
            f"{fmt(row.get('temperature_at_min_alpha'))} | "
            f"{fmt(row.get('max_alpha'))} | "
            f"{fmt(row.get('temperature_range_alpha'))} | "
            f"{fmt(row.get('share_temperatures_below_threshold'))} |"
        )

    with open(output_path, 'w') as handle:
        handle.write('\n'.join(lines) + '\n')


def main():
    parser = argparse.ArgumentParser(description='Summarize saved inter-prompt outputs.')
    parser.add_argument('--threshold', type=float, default=0.8, help='Threshold used for share_temperatures_below_threshold.')
    parser.add_argument('--output-csv', default='data/annotated/inter_summary_metrics.csv', help='CSV output path.')
    parser.add_argument('--output-md', default='data/output/inter_summary_metrics.md', help='Markdown output path.')
    args = parser.parse_args()

    os.chdir(PROJECT_ROOT)
    rows = []
    psa = PromptStabilityAnalysis(annotation_function=None, data=[], load_generation_models=False)

    for dataset_name, input_path in BETWEEN_FILES.items():
        if not os.path.exists(input_path):
            print(f'Skipping {dataset_name}: missing {input_path}')
            continue

        print(f'Summarizing {dataset_name} from {input_path}...')
        df = pd.read_csv(input_path)
        score_map = psa.extract_inter_score_map(df)
        summary = psa.summarize_inter_scores(score_map, threshold=args.threshold)
        summary['dataset'] = dataset_name
        rows.append(summary)

    summary_df = pd.DataFrame(rows)

    os.makedirs(os.path.dirname(args.output_csv), exist_ok=True)
    summary_df.to_csv(args.output_csv, index=False)
    print(f'Wrote {args.output_csv}')

    os.makedirs(os.path.dirname(args.output_md), exist_ok=True)
    build_markdown(summary_df, args.output_md)
    print(f'Wrote {args.output_md}')


if __name__ == '__main__':
    main()
