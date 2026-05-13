import simpledorff

import pandas as pd
import numpy as np
import time
import sys
import os

import seaborn as sns
import matplotlib.pyplot as plt
import plotly.express as px
import plotly.graph_objects as go

def get_openai_api_key():
    """Retrieve OpenAI API key from environment variables."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("API key not found. Please set the OPENAI_API_KEY environment variable.")
    return api_key


class PromptStabilityAnalysis:

    def __init__(self, annotation_function, data, metric_fn=simpledorff.metrics.nominal_metric, parse_function=None, load_generation_models=True) -> None:
        self.annotation_function = annotation_function
        self.parse_function = parse_function if parse_function is not None else lambda x: x  # Default parse function
        self.data = data
        self.metric_fn = metric_fn
        self.load_generation_models = load_generation_models
        self.embedding_model = None
        self.tokenizer = None
        self.model = None
        self.torch_device = 'cpu'
        self.paraphrase_model_name = 'tuner007/pegasus_paraphrase'

        if self.load_generation_models:
            self.__load_generation_models()

    def __load_generation_models(self):
        import torch
        from sentence_transformers import SentenceTransformer
        from transformers import PegasusForConditionalGeneration, PegasusTokenizer

        self.torch_device = 'cuda' if torch.cuda.is_available() else 'cpu'
        if self.embedding_model is None:
            self.embedding_model = SentenceTransformer('paraphrase-MiniLM-L6-v2')
        if self.tokenizer is None:
            self.tokenizer = PegasusTokenizer.from_pretrained(self.paraphrase_model_name)
        if self.model is None:
            self.model = PegasusForConditionalGeneration.from_pretrained(self.paraphrase_model_name).to(self.torch_device)

    def __paraphrase_sentence(self, input_text, num_return_sequences=10, num_beams=50, temperature=1.0):
        self.__load_generation_models()
        batch = self.tokenizer([input_text], truncation=True, padding='longest', max_length=60, return_tensors="pt").to(self.torch_device)
        translated = self.model.generate(**batch, max_length=60, num_beams=num_beams, num_return_sequences=num_return_sequences, temperature=temperature, do_sample=True)
        tgt_text = self.tokenizer.batch_decode(translated, skip_special_tokens=True)
        return tgt_text

    def __generate_paraphrases(self, original_text, prompt_postfix, nr_variations, temperature=1.0):
        phrases = self.__paraphrase_sentence(original_text, num_return_sequences=nr_variations, temperature=temperature)
        l = [{'phrase': f'{original_text} {prompt_postfix}', 'original': True}]
        for phrase in phrases:
            l.append({'phrase': f'{phrase} {prompt_postfix}', 'original': False})
        self.paraphrases = pd.DataFrame(l)
        return self.paraphrases

    def __calculate_krippendorff(self, df, annotator_col, class_col='annotation'):
        return simpledorff.calculate_krippendorffs_alpha_for_df(
            df,
            metric_fn=self.metric_fn,
            experiment_col='id',
            annotator_col=annotator_col,
            class_col=class_col
        )

    def __format_mode_scores(self, mean_score, ci_lower, ci_upper):
        return {'Average Alpha': mean_score, 'CI Lower': ci_lower, 'CI Upper': ci_upper}

    def __scores_to_frame(self, mode_scores):
        records = []
        for iteration, stats in mode_scores.items():
            records.append({
                'iteration': int(iteration),
                'run_count': int(iteration) + 1,
                'alpha': stats['Average Alpha'],
                'ci_lower': stats['CI Lower'],
                'ci_upper': stats['CI Upper']
            })
        df = pd.DataFrame(records)
        if not df.empty:
            df = df.sort_values('iteration').reset_index(drop=True)
            df['ci_width'] = df['ci_upper'] - df['ci_lower']
        return df

    def __inter_scores_to_frame(self, score_map):
        records = []
        for temperature, stats in score_map.items():
            records.append({
                'temperature': float(temperature),
                'alpha': stats['Average Alpha'],
                'ci_lower': stats['CI Lower'],
                'ci_upper': stats['CI Upper']
            })
        df = pd.DataFrame(records)
        if not df.empty:
            df = df.sort_values('temperature').reset_index(drop=True)
            df['ci_width'] = df['ci_upper'] - df['ci_lower']
        return df

    def __frame_to_mode_scores(self, df):
        if df.empty:
            return {}

        mode_scores = {}
        for _, row in df.iterrows():
            iteration = int(row['iteration'])
            alpha = row['alpha']
            ci_lower = row['ci_lower']
            ci_upper = row['ci_upper']
            if pd.isna(alpha):
                continue
            mode_scores[iteration] = self.__format_mode_scores(alpha, ci_lower, ci_upper)
        return mode_scores

    def __first_stable_run_count(self, values, tolerance):
        values = np.asarray(values, dtype=float)
        if len(values) == 0:
            return np.nan
        for idx in range(len(values)):
            if np.all(np.abs(values[idx:] - values[-1]) <= tolerance):
                return idx + 2  # run_count = iteration + 1, and first score starts at iteration 1
        return np.nan

    def __first_threshold_run_count(self, values, threshold):
        values = np.asarray(values, dtype=float)
        if len(values) == 0:
            return np.nan
        for idx in range(len(values)):
            if np.all(values[idx:] <= threshold):
                return idx + 2
        return np.nan

    def summarize_intra_scores(
        self,
        score_map,
        threshold=0.8,
        estimate_tolerance=0.01,
        precision_tolerance=0.02
    ):
        summaries = {}

        if 'cumulative_alpha' in score_map:
            cumulative_df = self.__scores_to_frame(score_map['cumulative_alpha'])
            if cumulative_df.empty:
                summaries['cumulative_alpha'] = {
                    'final_alpha': np.nan,
                    'final_ci_lower': np.nan,
                    'final_ci_upper': np.nan,
                    'final_ci_width': np.nan,
                    'run_count_to_estimate_stability': np.nan,
                    'run_count_to_precision_stability': np.nan,
                    'max_abs_deviation_from_final': np.nan
                }
            else:
                final_row = cumulative_df.iloc[-1]
                summaries['cumulative_alpha'] = {
                    'final_alpha': final_row['alpha'],
                    'final_ci_lower': final_row['ci_lower'],
                    'final_ci_upper': final_row['ci_upper'],
                    'final_ci_width': final_row['ci_width'],
                    'run_count_to_estimate_stability': self.__first_stable_run_count(
                        cumulative_df['alpha'].values,
                        estimate_tolerance
                    ),
                    'run_count_to_precision_stability': self.__first_threshold_run_count(
                        cumulative_df['ci_width'].values,
                        precision_tolerance
                    ),
                    'max_abs_deviation_from_final': np.max(np.abs(cumulative_df['alpha'].values - final_row['alpha']))
                }

        if 'adjacent_alpha' in score_map:
            adjacent_df = self.__scores_to_frame(score_map['adjacent_alpha'])
            if adjacent_df.empty:
                summaries['adjacent_alpha'] = {
                    'mean_alpha': np.nan,
                    'sd_alpha': np.nan,
                    'iqr_alpha': np.nan,
                    'min_alpha': np.nan,
                    'max_alpha': np.nan,
                    'share_below_threshold': np.nan,
                    'mean_ci_width': np.nan
                }
            else:
                alpha_values = adjacent_df['alpha'].values
                summaries['adjacent_alpha'] = {
                    'mean_alpha': float(np.mean(alpha_values)),
                    'sd_alpha': float(np.std(alpha_values, ddof=1)) if len(alpha_values) > 1 else 0.0,
                    'iqr_alpha': float(np.percentile(alpha_values, 75) - np.percentile(alpha_values, 25)),
                    'min_alpha': float(np.min(alpha_values)),
                    'max_alpha': float(np.max(alpha_values)),
                    'share_below_threshold': float(np.mean(alpha_values < threshold)),
                    'mean_ci_width': float(np.mean(adjacent_df['ci_width'].values))
                }

        return summaries

    def extract_intra_score_map(self, annotated_df, analysis_modes=None):
        if analysis_modes is None:
            analysis_modes = ['cumulative_alpha', 'adjacent_alpha']

        valid_modes = {'cumulative_alpha', 'adjacent_alpha'}
        unknown_modes = set(analysis_modes) - valid_modes
        if unknown_modes:
            raise ValueError(f"Unknown intra-PSS analysis modes: {sorted(unknown_modes)}")

        all_annotated = annotated_df.copy()
        all_annotated['iteration'] = pd.to_numeric(all_annotated['iteration'], errors='coerce')
        all_annotated = all_annotated.dropna(subset=['iteration']).copy()
        all_annotated['iteration'] = all_annotated['iteration'].astype(int)

        score_map = {}

        if 'cumulative_alpha' in analysis_modes:
            if {'cumulative_ka_mean', 'cumulative_ka_lower', 'cumulative_ka_upper'}.issubset(all_annotated.columns):
                cumulative_df = all_annotated[['iteration', 'cumulative_ka_mean', 'cumulative_ka_lower', 'cumulative_ka_upper']] \
                    .drop_duplicates() \
                    .rename(columns={
                        'cumulative_ka_mean': 'alpha',
                        'cumulative_ka_lower': 'ci_lower',
                        'cumulative_ka_upper': 'ci_upper'
                    })
            elif {'ka_mean', 'ka_lower', 'ka_upper'}.issubset(all_annotated.columns):
                cumulative_df = all_annotated[['iteration', 'ka_mean', 'ka_lower', 'ka_upper']] \
                    .drop_duplicates() \
                    .rename(columns={
                        'ka_mean': 'alpha',
                        'ka_lower': 'ci_lower',
                        'ka_upper': 'ci_upper'
                    })
            else:
                raise ValueError("No cumulative intra-PSS columns found in annotated dataframe.")

            score_map['cumulative_alpha'] = self.__frame_to_mode_scores(cumulative_df)

        if 'adjacent_alpha' in analysis_modes:
            required_cols = {'adjacent_ka_mean', 'adjacent_ka_lower', 'adjacent_ka_upper'}
            if not required_cols.issubset(all_annotated.columns):
                raise ValueError("No adjacent intra-PSS columns found in annotated dataframe.")

            adjacent_df = all_annotated[['iteration', 'adjacent_ka_mean', 'adjacent_ka_lower', 'adjacent_ka_upper']] \
                .drop_duplicates() \
                .rename(columns={
                    'adjacent_ka_mean': 'alpha',
                    'adjacent_ka_lower': 'ci_lower',
                    'adjacent_ka_upper': 'ci_upper'
                })

            score_map['adjacent_alpha'] = self.__frame_to_mode_scores(adjacent_df)

        return score_map

    def summarize_inter_scores(self, score_map, threshold=0.8):
        inter_df = self.__inter_scores_to_frame(score_map)
        if inter_df.empty:
            return {
                'mean_alpha': np.nan,
                'sd_alpha_across_temperatures': np.nan,
                'min_alpha': np.nan,
                'temperature_at_min_alpha': np.nan,
                'max_alpha': np.nan,
                'temperature_range_alpha': np.nan,
                'share_temperatures_below_threshold': np.nan
            }

        min_idx = inter_df['alpha'].idxmin()
        max_idx = inter_df['alpha'].idxmax()
        alpha_values = inter_df['alpha'].values

        return {
            'mean_alpha': float(np.mean(alpha_values)),
            'sd_alpha_across_temperatures': float(np.std(alpha_values, ddof=1)) if len(alpha_values) > 1 else 0.0,
            'min_alpha': float(inter_df.loc[min_idx, 'alpha']),
            'temperature_at_min_alpha': float(inter_df.loc[min_idx, 'temperature']),
            'max_alpha': float(inter_df.loc[max_idx, 'alpha']),
            'temperature_range_alpha': float(np.max(alpha_values) - np.min(alpha_values)),
            'share_temperatures_below_threshold': float(np.mean(alpha_values < threshold))
        }

    def extract_inter_score_map(self, annotated_df):
        required_cols = {'temperature', 'ka_mean', 'ka_lower', 'ka_upper'}
        if not required_cols.issubset(annotated_df.columns):
            raise ValueError("Annotated dataframe must contain temperature, ka_mean, ka_lower, and ka_upper columns.")

        inter_df = annotated_df[['temperature', 'ka_mean', 'ka_lower', 'ka_upper']] \
            .drop_duplicates() \
            .copy()
        inter_df['temperature'] = pd.to_numeric(inter_df['temperature'], errors='coerce')
        inter_df['ka_mean'] = pd.to_numeric(inter_df['ka_mean'], errors='coerce')
        inter_df['ka_lower'] = pd.to_numeric(inter_df['ka_lower'], errors='coerce')
        inter_df['ka_upper'] = pd.to_numeric(inter_df['ka_upper'], errors='coerce')
        inter_df = inter_df.dropna(subset=['temperature', 'ka_mean']).sort_values('temperature')

        score_map = {}
        for _, row in inter_df.iterrows():
            score_map[float(row['temperature'])] = self.__format_mode_scores(
                row['ka_mean'],
                row['ka_lower'],
                row['ka_upper']
            )

        return score_map

    def __plot_intra_scores(self, mode_scores, plot_mode, save_path=None):
        iterations_list = list(mode_scores.keys())
        ka_values = [mode_scores[i]['Average Alpha'] for i in iterations_list]
        average_ka = np.mean(ka_values)
        ci_lowers = [mode_scores[i]['Average Alpha'] - mode_scores[i]['CI Lower'] for i in iterations_list]
        ci_uppers = [mode_scores[i]['CI Upper'] - mode_scores[i]['Average Alpha'] for i in iterations_list]

        plot_titles = {
            'cumulative_alpha': "Cumulative Intra-PSS with 95% CI Across Iterations",
            'adjacent_alpha': "Adjacent-Run Intra-PSS with 95% CI Across Iterations"
        }
        plot_labels = {
            'cumulative_alpha': "Cumulative Krippendorff's Alpha (KA)",
            'adjacent_alpha': "Adjacent-Run Krippendorff's Alpha (KA)"
        }
        mean_labels = {
            'cumulative_alpha': 'Average cumulative KA',
            'adjacent_alpha': 'Average adjacent-run KA'
        }

        plt.figure(figsize=(10, 5))
        plt.errorbar(iterations_list, ka_values, yerr=[ci_lowers, ci_uppers], fmt='o', linestyle='-', color='b', ecolor='gray', capsize=3)
        plt.axhline(y=average_ka, color='r', linestyle='--', label=f"{mean_labels.get(plot_mode, 'Average KA')}: {average_ka:.2f}")
        plt.xlabel('Iteration')
        plt.ylabel(plot_labels.get(plot_mode, "Krippendorff's Alpha (KA)"))
        plt.title(plot_titles.get(plot_mode, "Krippendorff's Alpha Scores with 95% CI Across Iterations"))
        plt.xticks(iterations_list)
        plt.legend()
        plt.grid(True)
        plt.axhline(y=0.8, color='black', linestyle='--', linewidth=.5)

        if save_path:
            plt.savefig(save_path)
            print(f"Plot saved to {save_path}")
        else:
            plt.show()

    def score_intra_annotations(self, annotated_df, bootstrap_samples=1000, analysis_modes=None):
        if analysis_modes is None:
            analysis_modes = ['cumulative_alpha']

        valid_modes = {'cumulative_alpha', 'adjacent_alpha'}
        unknown_modes = set(analysis_modes) - valid_modes
        if unknown_modes:
            raise ValueError(f"Unknown intra-PSS analysis modes: {sorted(unknown_modes)}")

        all_annotated = annotated_df.copy()
        all_annotated['iteration'] = pd.to_numeric(all_annotated['iteration'], errors='coerce')
        all_annotated = all_annotated.dropna(subset=['iteration']).copy()
        all_annotated['iteration'] = all_annotated['iteration'].astype(int)
        all_annotated['run_count'] = all_annotated['iteration'] + 1

        sorted_iterations = sorted(all_annotated['iteration'].unique())
        if len(sorted_iterations) < 2:
            raise ValueError("At least two iterations are required to compute intra-PSS summaries.")

        score_map = {}

        if 'cumulative_alpha' in analysis_modes:
            cumulative_scores = {}
            for current_iter in sorted_iterations[1:]:
                subset = all_annotated[all_annotated['iteration'] <= current_iter]
                mean_alpha, (ci_lower, ci_upper) = self.bootstrap_krippendorff(subset, 'iteration', bootstrap_samples)
                cumulative_scores[current_iter] = self.__format_mode_scores(mean_alpha, ci_lower, ci_upper)

            for current_iter, stats in cumulative_scores.items():
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'cumulative_ka_mean'] = stats['Average Alpha']
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'cumulative_ka_lower'] = stats['CI Lower']
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'cumulative_ka_upper'] = stats['CI Upper']

            # Preserve legacy column names for backward compatibility.
            all_annotated['ka_mean'] = all_annotated['cumulative_ka_mean']
            all_annotated['ka_lower'] = all_annotated['cumulative_ka_lower']
            all_annotated['ka_upper'] = all_annotated['cumulative_ka_upper']
            score_map['cumulative_alpha'] = cumulative_scores

        if 'adjacent_alpha' in analysis_modes:
            adjacent_scores = {}
            for idx in range(1, len(sorted_iterations)):
                previous_iter = sorted_iterations[idx - 1]
                current_iter = sorted_iterations[idx]
                subset = all_annotated[all_annotated['iteration'].isin([previous_iter, current_iter])]
                mean_alpha, (ci_lower, ci_upper) = self.bootstrap_krippendorff(subset, 'iteration', bootstrap_samples)
                adjacent_scores[current_iter] = self.__format_mode_scores(mean_alpha, ci_lower, ci_upper)
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'adjacent_reference_iteration'] = previous_iter

            for current_iter, stats in adjacent_scores.items():
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'adjacent_ka_mean'] = stats['Average Alpha']
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'adjacent_ka_lower'] = stats['CI Lower']
                all_annotated.loc[all_annotated['iteration'] == current_iter, 'adjacent_ka_upper'] = stats['CI Upper']

            score_map['adjacent_alpha'] = adjacent_scores

        return score_map, all_annotated

    def intra_pss(
        self,
        original_text,
        prompt_postfix,
        iterations=10,
        bootstrap_samples=1000,
        analysis_modes=None,
        plot=False,
        plot_mode='cumulative_alpha',
        save_path=None,
        save_csv=None,
        return_summaries=False,
        summary_threshold=0.8,
        estimate_tolerance=0.01,
        precision_tolerance=0.02
    ):
        prompt = f'{original_text} {prompt_postfix}'
        all_annotations = []  # Use a list to collect all annotations

        for i in range(iterations):
            print(f"Iteration {i+1}/{iterations}...", end='\r')
            sys.stdout.flush()

            annotations = []

            for j, d in enumerate(self.data):
                annotation = self.parse_function(self.annotation_function(d, prompt))
                annotations.append({'id': j, 'text': d, 'annotation': annotation, 'iteration': i})

            all_annotations.extend(annotations)  # Extend the list with the current iteration's annotations

        all_annotated = pd.DataFrame(all_annotations)  # Convert list to DataFrame once
        score_map, all_annotated = self.score_intra_annotations(
            all_annotated,
            bootstrap_samples=bootstrap_samples,
            analysis_modes=analysis_modes
        )

        if save_csv:
            all_annotated.to_csv(save_csv, index=False)
            print(f"Annotated data saved to {save_csv}")

        if plot:
            if plot_mode not in score_map:
                raise ValueError(f"Plot mode '{plot_mode}' was not computed. Available modes: {sorted(score_map.keys())}")
            self.__plot_intra_scores(score_map[plot_mode], plot_mode=plot_mode, save_path=save_path)

        if analysis_modes is None:
            analysis_modes = ['cumulative_alpha']

        summaries = None
        if return_summaries:
            summaries = self.summarize_intra_scores(
                score_map,
                threshold=summary_threshold,
                estimate_tolerance=estimate_tolerance,
                precision_tolerance=precision_tolerance
            )

        if len(analysis_modes) == 1:
            if return_summaries:
                return score_map[analysis_modes[0]], all_annotated, summaries
            return score_map[analysis_modes[0]], all_annotated
        if return_summaries:
            return score_map, all_annotated, summaries
        return score_map, all_annotated


    def inter_pss(self, original_text, prompt_postfix=None, nr_variations=5, temperatures=[0.5, 0.7, 0.9], iterations=1, bootstrap_samples=1000, print_prompts=False, edit_prompts_path=None, plot=False, save_path=None, save_csv=None):
        ka_scores = {}
        all_annotated = []

        for temp in temperatures:
            paraphrases = self.__generate_paraphrases(original_text, prompt_postfix, nr_variations=nr_variations, temperature=temp)
            annotated = []

            for i in range(iterations):
                start_time = time.time() #
                for j, (paraphrase, original) in enumerate(zip(paraphrases['phrase'], paraphrases['original'])):

                    print(f"Temperature {temp}, Iteration {i+1}/{iterations}", end='\r')
                    sys.stdout.flush()
                    for k, d in enumerate(self.data):
                        annotation = self.parse_function(self.annotation_function(d, paraphrase))
                        annotated.append({'id': k, 'text': d, 'annotation': annotation, 'prompt_id': j, 'prompt': paraphrase, 'original': original, 'temperature': temp})

                end_time = time.time()  #
                elapsed_time = end_time - start_time  #
                print(f"Temperature {temp} completed in {elapsed_time:.2f} seconds")

            annotated_data = pd.DataFrame(annotated)
            all_annotated.append(annotated_data)

            # Bootstrap Krippendorff's Alpha calculation for each temperature
            annotator_col = 'prompt_id'
            print(f'KA calculation for {bootstrap_samples} bootstrap samples...')
            mean_alpha, (ci_lower, ci_upper) = self.bootstrap_krippendorff(annotated_data, annotator_col, bootstrap_samples)
            ka_scores[temp] = {'Average Alpha': mean_alpha, 'CI Lower': ci_lower, 'CI Upper': ci_upper}
            print(f'KA calculation completed.')
            print()

        # Concatenate all annotated data
        combined_annotated_data = pd.concat(all_annotated, ignore_index=True)

         # Add average KA, CI lower, and CI upper to the combined data for CSV output
        for temp in ka_scores:
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_mean'] = ka_scores[temp]['Average Alpha']
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_lower'] = ka_scores[temp]['CI Lower']
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_upper'] = ka_scores[temp]['CI Upper']

        if save_csv:
            combined_annotated_data.to_csv(save_csv, index=False)
            print(f"Annotated data saved to {save_csv}")

        if print_prompts:
            unique_prompts = combined_annotated_data['prompt'].unique()
            print("Unique prompts:")
            for prompt in unique_prompts:
                print(prompt)

        if edit_prompts_path:
            prompts_df = combined_annotated_data.drop_duplicates(subset=['prompt_id', 'temperature', 'prompt', 'original'])
            prompts_df = prompts_df[['prompt_id', 'temperature', 'prompt', 'original']]
            prompts_df.columns = ['prompt_id', 'temperature', 'prompt_text', 'original_prompt']
            prompts_df.to_csv(edit_prompts_path, index=False)
            print(f"{nr_variations} prompts per temperature saved and available to edit at {edit_prompts_path}")

        if plot:
            temperatures_list = list(ka_scores.keys())
            ka_values = [ka_scores[temp]['Average Alpha'] for temp in temperatures_list]
            ka_lowers = [ka_scores[temp]['Average Alpha'] - ka_scores[temp]['CI Lower'] for temp in temperatures_list]
            ka_uppers = [ka_scores[temp]['CI Upper'] - ka_scores[temp]['Average Alpha'] for temp in temperatures_list]

            plt.figure(figsize=(10, 5))
            plt.plot(temperatures_list, ka_values, marker='o', linestyle='-', color='b')
            plt.errorbar(temperatures_list, ka_values, yerr=[ka_lowers, ka_uppers], fmt='o', linestyle='-', color='b', ecolor='gray', capsize=3)
            plt.xlabel('Temperature')
            plt.ylabel('Krippendorff\'s Alpha (KA)')
            plt.title('Krippendorff\'s Alpha Scores with 95% CI Across Temperatures')
            plt.xticks(temperatures_list)  # Set x-axis ticks to be whole integers
            plt.grid(True)
            plt.ylim(0.0, 1.05)
            plt.axhline(y=0.80, color='black', linestyle='--', linewidth=.5)

            if save_path:
                plt.savefig(save_path)
                print(f"Plot saved to {save_path}")
            else:
                plt.show()

        return ka_scores, combined_annotated_data

    def manual_interprompt_stochasticity(self, edit_prompts_path, bootstrap_samples=1000, plot=False, save_path=None, save_csv=None):
        # Load the manually edited prompts CSV
        prompts_df = pd.read_csv(edit_prompts_path)

        # Assuming 'original_prompt' column is used to filter out original, unedited prompts
        prompts_df = prompts_df[prompts_df['original_prompt'] == False]

        ka_scores = {}
        all_annotated = []

        # Iterate through each unique temperature found in the prompts DataFrame
        for temp in prompts_df['temperature'].unique():
            temp_prompts = prompts_df[prompts_df['temperature'] == temp]
            annotated = []
            start_time = time.time()

            # Annotate data using each prompt at the current temperature
            for _, prompt_entry in temp_prompts.iterrows():
                prompt = prompt_entry['prompt_text']
                prompt_id = prompt_entry['prompt_id']

                for k, d in enumerate(self.data):
                    annotation = self.parse_function(self.annotation_function(d, prompt))
                    annotated.append({
                        'id': k,
                        'text': d,
                        'annotation': annotation,
                        'prompt_id': prompt_id,
                        'prompt': prompt,
                        'temperature': temp
                    })

            end_time = time.time()  #
            elapsed_time = end_time - start_time  #
            print(f"Temperature {temp} completed in {elapsed_time:.2f} seconds")

            annotated_data = pd.DataFrame(annotated)
            all_annotated.append(annotated_data)

            # Bootstrap Krippendorff's Alpha calculation for each temperature
            print(f'KA calculation for {bootstrap_samples} bootstrap samples...')
            mean_alpha, (ci_lower, ci_upper) = self.bootstrap_krippendorff(annotated_data, 'prompt_id', bootstrap_samples)
            ka_scores[temp] = {'Average Alpha': mean_alpha, 'CI Lower': ci_lower, 'CI Upper': ci_upper}
            print(f'KA calculation completed.')
            print()

        # Concatenate all annotated data
        combined_annotated_data = pd.concat(all_annotated, ignore_index=True)

        # Add average KA, CI lower, and CI upper to the combined data for CSV output
        for temp in ka_scores:
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_mean'] = ka_scores[temp]['Average Alpha']
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_lower'] = ka_scores[temp]['CI Lower']
            combined_annotated_data.loc[combined_annotated_data['temperature'] == temp, 'ka_upper'] = ka_scores[temp]['CI Upper']

        # Output results as needed
        if save_csv:
            combined_annotated_data.to_csv(save_csv, index=False)
            print(f"Annotated data saved to {save_csv}")

        if plot:
            temperatures_list = list(ka_scores.keys())
            ka_values = [ka_scores[temp]['Average Alpha'] for temp in temperatures_list]
            ka_lowers = [ka_scores[temp]['Average Alpha'] - ka_scores[temp]['CI Lower'] for temp in temperatures_list]
            ka_uppers = [ka_scores[temp]['CI Upper'] - ka_scores[temp]['Average Alpha'] for temp in temperatures_list]

            plt.figure(figsize=(10, 5))
            plt.plot(temperatures_list, ka_values, marker='o', linestyle='-', color='b')
            plt.errorbar(temperatures_list, ka_values, yerr=[ka_lowers, ka_uppers], fmt='o', linestyle='-', color='b', ecolor='gray', capsize=3)
            plt.xlabel('Temperature')
            plt.ylabel('Krippendorff\'s Alpha (KA)')
            plt.title('Krippendorff\'s Alpha Scores with 95% CI Across Temperatures')
            plt.xticks(temperatures_list)  # Set x-axis ticks to be whole integers
            plt.grid(True)
            plt.ylim(0.0, 1.05)
            plt.axhline(y=0.80, color='black', linestyle='--', linewidth=.5)

            if save_path:
                plt.savefig(save_path)
                print(f"Plot saved to {save_path}")
            else:
                plt.show()

        return ka_scores, combined_annotated_data

    def bootstrap_krippendorff(self, df, annotator_col, bootstrap_samples, confidence_level=95):
        alpha_scores = []

        for _ in range(bootstrap_samples):  # Number of bootstrap samples
            bootstrap_sample = df.sample(n=len(df), replace=True)
            try:
                alpha = self.__calculate_krippendorff(bootstrap_sample, annotator_col=annotator_col)
            except ZeroDivisionError:
                alpha = np.nan
            alpha_scores.append(alpha)

        alpha_scores = np.array(alpha_scores, dtype=float)
        alpha_scores = alpha_scores[~np.isnan(alpha_scores)]
        if len(alpha_scores) == 0:
            return np.nan, (np.nan, np.nan)
        mean_alpha = np.mean(alpha_scores)
        ci_lower = np.percentile(alpha_scores, (100 - confidence_level) / 2)
        ci_upper = np.percentile(alpha_scores, 100 - (100 - confidence_level) / 2)
        return mean_alpha, (ci_lower, ci_upper)
