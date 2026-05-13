#!/usr/bin/env python3
"""Canonical DeepSeek/GPT capability comparison generation stage."""

import os
import pandas as pd
from openai import OpenAI
import ollama

from utils import PromptStabilityAnalysis, get_openai_api_key


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(PROJECT_ROOT)


def main():
    df = pd.read_csv('data/manifestos.csv')
    df = df[df['scale'] == 'Economic']
    sample_size = max(1, int(0.1 * len(df)))
    df = df.sample(sample_size, random_state=123)
    data = list(df['sentence_context'].values)

    original_text = (
        "The text provided is a UK party manifesto. "
        "Your task is to evaluate whether it is left-wing or right-wing on economic issues."
    )
    prompt_postfix = (
        "Respond with 0 for left-wing or 1 for right-wing. "
        "Only respond with a one token integer. Do not respond with anything else."
    )

    output_dir = os.path.join('data', 'example')
    os.makedirs(output_dir, exist_ok=True)

    apikey = get_openai_api_key()
    client = OpenAI(api_key=apikey)
    openai_model = 'gpt-4o'

    def annotate_openai(text, prompt, temperature=0.1):
        response = client.chat.completions.create(
            model=openai_model,
            temperature=temperature,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        return ''.join(choice.message.content for choice in response.choices)

    psa_openai = PromptStabilityAnalysis(annotation_function=annotate_openai, data=data)
    print("Running OpenAI intra-prompt analysis...")
    _, annotated_openai_intra = psa_openai.intra_pss(
        original_text,
        prompt_postfix,
        iterations=20,
        plot=False,
    )

    temperatures = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0]
    print("Running OpenAI inter-prompt analysis...")
    _, annotated_openai_inter = psa_openai.inter_pss(
        original_text,
        prompt_postfix,
        nr_variations=3,
        temperatures=temperatures,
        iterations=1,
        plot=False,
    )

    annotated_openai_intra.to_csv(os.path.join(output_dir, 'openai_intra.csv'), index=False)
    annotated_openai_inter.to_csv(os.path.join(output_dir, 'openai_inter.csv'), index=False)

    ollama_model = 'deepseek-r1:8b'

    def annotate_ollama(text, prompt, temperature=0.1):
        response = ollama.chat(
            model=ollama_model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        return response['message']['content']

    psa_ollama = PromptStabilityAnalysis(annotation_function=annotate_ollama, data=data)
    print("Running Ollama intra-prompt analysis...")
    _, annotated_ollama_intra = psa_ollama.intra_pss(
        original_text,
        prompt_postfix,
        iterations=20,
        plot=False,
    )

    print("Running Ollama inter-prompt analysis...")
    _, annotated_ollama_inter = psa_ollama.inter_pss(
        original_text,
        prompt_postfix,
        nr_variations=3,
        temperatures=temperatures,
        iterations=1,
        plot=False,
    )

    annotated_ollama_intra.to_csv(os.path.join(output_dir, 'ollama_intra.csv'), index=False)
    annotated_ollama_inter.to_csv(os.path.join(output_dir, 'ollama_inter.csv'), index=False)


if __name__ == '__main__':
    main()
