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


FILTERED_DATASETS = [
    'tweets_rd',
    'tweets_pop',
    'news',
    'news_short',
    'manifestos',
    'manifestos_multi',
    'stance',
    'stance_long',
    'mii',
    'mii_long',
    'synth',
    'synth_short'
]

FILTERED_VARIANTS = [
    ('Filtered', '_filtered_rescored.csv'),
    ('Filtered & Balanced', '_filtered_balanced_rescored.csv')
]


def flatten_summary(dataset_name, source_type, summary_dict):
    row = {'dataset': dataset_name, 'type': source_type}
    for mode_name, metrics in summary_dict.items():
        prefix = 'cumulative' if mode_name == 'cumulative_alpha' else 'adjacent'
        for key, value in metrics.items():
            row[f'{prefix}_{key}'] = value
    return row


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
        '# Filtered Intra-PSS Summary Metrics',
        '',
        'Generated from rescored filtered within-prompt outputs.',
        ''
    ]

    for source_type in ['Filtered', 'Filtered & Balanced']:
        subset = df[df['type'] == source_type].sort_values('dataset')
        if subset.empty:
            continue

        lines.extend([
            f'## {source_type}',
            '',
            '### Cumulative',
            '',
            '| dataset | final alpha | final CI width | run count to estimate stability | run count to precision stability | max abs deviation from final |',
            '| --- | ---: | ---: | ---: | ---: | ---: |'
        ])

        for _, row in subset.iterrows():
            lines.append(
                f"| {row['dataset']} | {fmt(row.get('cumulative_final_alpha'))} | "
                f"{fmt(row.get('cumulative_final_ci_width'))} | "
                f"{fmt(row.get('cumulative_run_count_to_estimate_stability'))} | "
                f"{fmt(row.get('cumulative_run_count_to_precision_stability'))} | "
                f"{fmt(row.get('cumulative_max_abs_deviation_from_final'))} |"
            )

        lines.extend([
            '',
            '### Adjacent',
            '',
            '| dataset | mean alpha | sd alpha | IQR alpha | min alpha | max alpha | share below threshold | mean CI width |',
            '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
        ])

        for _, row in subset.iterrows():
            lines.append(
                f"| {row['dataset']} | {fmt(row.get('adjacent_mean_alpha'))} | "
                f"{fmt(row.get('adjacent_sd_alpha'))} | "
                f"{fmt(row.get('adjacent_iqr_alpha'))} | "
                f"{fmt(row.get('adjacent_min_alpha'))} | "
                f"{fmt(row.get('adjacent_max_alpha'))} | "
                f"{fmt(row.get('adjacent_share_below_threshold'))} | "
                f"{fmt(row.get('adjacent_mean_ci_width'))} |"
            )

        lines.append('')

    with open(output_path, 'w') as handle:
        handle.write('\n'.join(lines) + '\n')


def main():
    parser = argparse.ArgumentParser(description='Summarize rescored filtered within-prompt intra-PSS outputs.')
    parser.add_argument('--input-dir', default='data/annotated/reannotated/within_rescored', help='Directory containing rescored filtered within CSVs.')
    parser.add_argument('--threshold', type=float, default=0.8, help='Threshold used for adjacent share_below_threshold.')
    parser.add_argument('--estimate-tolerance', type=float, default=0.01, help='Tolerance for cumulative estimate stability.')
    parser.add_argument('--precision-tolerance', type=float, default=0.02, help='Tolerance for cumulative precision stability.')
    parser.add_argument('--output-csv', default='data/annotated/reannotated/within_rescored/intra_summary_metrics.csv', help='CSV output path.')
    parser.add_argument('--output-md', default='data/output/intra_summary_metrics_filtered_within.md', help='Markdown output path.')
    args = parser.parse_args()

    os.chdir(PROJECT_ROOT)
    rows = []
    psa = PromptStabilityAnalysis(annotation_function=None, data=[], load_generation_models=False)

    for dataset_name in FILTERED_DATASETS:
        for source_type, suffix in FILTERED_VARIANTS:
            input_path = os.path.join(args.input_dir, f'{dataset_name}{suffix}')
            if not os.path.exists(input_path):
                print(f'Skipping {dataset_name} [{source_type}]: missing {input_path}')
                continue

            print(f'Summarizing {dataset_name} [{source_type}] from {input_path}...')
            df = pd.read_csv(input_path)
            score_map = psa.extract_intra_score_map(df, analysis_modes=['cumulative_alpha', 'adjacent_alpha'])
            summaries = psa.summarize_intra_scores(
                score_map,
                threshold=args.threshold,
                estimate_tolerance=args.estimate_tolerance,
                precision_tolerance=args.precision_tolerance
            )
            rows.append(flatten_summary(dataset_name, source_type, summaries))

    summary_df = pd.DataFrame(rows)

    os.makedirs(os.path.dirname(args.output_csv), exist_ok=True)
    summary_df.to_csv(args.output_csv, index=False)
    print(f'Wrote {args.output_csv}')

    os.makedirs(os.path.dirname(args.output_md), exist_ok=True)
    build_markdown(summary_df, args.output_md)
    print(f'Wrote {args.output_md}')


if __name__ == '__main__':
    main()
