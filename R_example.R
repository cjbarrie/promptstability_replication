############################################################
# promptstability + Ollama via reticulate (fix seaborn pin)
# - promptstability 0.1.4 requires seaborn >=0.12.2,<0.13
############################################################

library(reticulate)

ENVNAME <- "promptstability_py310"

# Ensure Miniconda/Conda exists
# Try to check if conda is available
conda_available <- tryCatch({
  conda_list()
  TRUE
}, error = function(e) {
  FALSE
})

if (!conda_available) {
  message("Conda not found. Attempting to install Miniconda...")
  tryCatch({
    install_miniconda()
    message("Miniconda installed successfully!")
  }, error = function(e) {
    stop("Failed to install Miniconda automatically. Please install manually:\n",
         "  install.packages('reticulate')\n",
         "  reticulate::install_miniconda()\n",
         "Or visit: https://docs.conda.io/en/latest/miniconda.html")
  })
}

# Remove env if exists (clean start)
envs <- tryCatch(conda_list(), error = function(e) NULL)
if (!is.null(envs) && (ENVNAME %in% envs$name)) {
  message(sprintf("Removing existing conda env '%s'...", ENVNAME))
  conda_remove(envname = ENVNAME, packages = NULL)
}

# Create env with Python 3.10
message(sprintf("Creating conda env '%s' with Python 3.10...", ENVNAME))
conda_create(envname = ENVNAME, python_version = "3.10")

# Activate env
use_condaenv(ENVNAME, required = TRUE)
print(py_config())

# Install compiled deps via conda-forge (avoid pip build headaches on macOS ARM)
message("Installing numpy/pandas via conda-forge (pandas<2 required)...")
conda_install(
  envname  = ENVNAME,
  packages = c("numpy=1.26.*", "pandas<2"),
  channel  = "conda-forge"
)

# Install PyTorch FIRST (required by transformers/sentence-transformers)
message("Installing PyTorch 1.x via pip...")
py_install(
  packages = c(
    "torch>=1.13.1,<2.0.0", # PyTorch 1.x required by promptstability 0.1.4
    "torchvision<0.16",     # Match torch 1.x
    "torchaudio<2.1"        # Match torch 1.x
  ),
  method = "pip",
  pip = TRUE
)

# Verify torch installation
message("Verifying PyTorch installation...")
py_run_string("import torch; print('PyTorch version:', torch.__version__)")

# Install remaining deps via pip
# IMPORTANT: pin seaborn to <0.13 to satisfy promptstability 0.1.4
message("Installing remaining Python packages via pip...")
py_install(
  packages = c(
    "transformers>=4.35,<4.37",  # Pin to version compatible with torch 1.x
    "sentence-transformers>=2.6",
    "simpledorff>=0.0.2",
    "accelerate>=0.30",
    "matplotlib>=3.7",      # keep flexible; 3.8 is fine if it resolves
    "seaborn==0.12.2",      # REQUIRED for promptstability 0.1.4
    "sentencepiece",
    "protobuf",
    "ollama",
    "git+https://github.com/palaiole13/promptstability.git"
  ),
  method = "pip",
  pip = TRUE
)

# Sanity checks
message("Sanity check imports/versions...")
py_run_string("
import sys
import numpy as np
import pandas as pd
import torch
import transformers
import seaborn as sns
import matplotlib
import promptstability

print('Python:', sys.version)
print('numpy:', np.__version__)
print('pandas:', pd.__version__)
print('torch:', torch.__version__)
print('transformers:', transformers.__version__)
print('seaborn:', sns.__version__)
print('matplotlib:', matplotlib.__version__)
print('promptstability file:', promptstability.__file__)
")

# Import from package root (NOT promptstability.promptstability)
ps <- import("promptstability", convert = FALSE)
PromptStabilityAnalysis <- ps$PromptStabilityAnalysis

# Dummy data frame in R (any column name is fine)
dummy_df <- data.frame(
  id   = 1:8,
  text = c(
    "The economy is improving and unemployment is down.",
    "This policy is a disaster and will hurt working families.",
    "I don't care about politics; I just want lower prices.",
    "The candidate handled the debate well, very convincing.",
    "Corruption allegations are serious and should be investigated.",
    "The new program helped my community a lot.",
    "Taxes are too high and the government wastes money.",
    "I feel neutral about this issue; I need more information."
  ),
  stringsAsFactors = FALSE
)

# The object PromptStabilityAnalysis wants:
texts <- dummy_df$text

# Define Ollama annotation function in Python
py_run_string("
import ollama
OLLAMA_MODEL = 'deepseek-r1:8b'

def annotate_ollama(text, prompt, temperature=0.1):
    response = ollama.chat(
        model=OLLAMA_MODEL,
        messages=[
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': text}
        ]
    )
    return response['message']['content']
")

annotate_ollama <- py$annotate_ollama

# Instantiate analysis
psa <- PromptStabilityAnalysis(annotation_function = annotate_ollama, data = texts)

# Minimal test prompt
original_text  <- "You are a text classifier. Classify the sentiment of the user's text as Positive, Negative, or Neutral."
prompt_postfix <- "Respond with exactly one of: Positive, Negative, Neutral. Respond with nothing else."

# Run intra-PSS (small test)
message("Running intra-PSS (small test)...")
intra_res <- psa$intra_pss(
  original_text     = original_text,
  prompt_postfix    = prompt_postfix,
  iterations        = as.integer(3),
  bootstrap_samples = as.integer(100),
  plot              = FALSE
)
print(intra_res[[1]])

# Run inter-PSS (small test)
message("Running inter-PSS (small test)...")
inter_res <- psa$inter_pss(
  original_text     = original_text,
  prompt_postfix    = prompt_postfix,
  nr_variations     = as.integer(2),
  temperatures      = list(0.1, 0.5),
  iterations        = as.integer(1),
  bootstrap_samples = as.integer(100),
  plot              = FALSE,
  print_prompts     = TRUE
)
print(inter_res[[1]])

message("Completed successfully.")
