# R Example Guide: Using promptstability with Ollama

This guide provides a complete walkthrough for using the `promptstability` Python package from R via `reticulate`, with Ollama as the LLM backend.

If you are starting from the replication repository itself, the easiest first
step is still:

```bash
bash setup_pssenv.sh
Rscript install_r_dependencies.R
```

The guide below is a fuller manual walkthrough of the same idea from the R side.

## Overview

This script demonstrates how to:
- Set up a Python environment from R using `reticulate`
- Install the `promptstability` package and its dependencies
- Use Ollama (local LLM) for text annotation
- Run prompt stability analysis (intra-PSS and inter-PSS)

**What is Prompt Stability?**
- **Intra-PSS**: Measures consistency when the same prompt is used repeatedly
- **Inter-PSS**: Measures consistency across semantically similar prompts (paraphrases)

## Prerequisites

### 1. R Packages
```r
install.packages("reticulate")
```

### 2. Ollama Installation
Download and install Ollama from: https://ollama.com/download

After installation, start the Ollama service:
```bash
ollama serve
```

Download the model you want to use (e.g., DeepSeek R1 8B):
```bash
ollama pull deepseek-r1:8b
```

### 3. System Requirements
- **macOS ARM (M1/M2/M3)** or compatible system
- **Python 3.10** (will be installed via conda by the script)
- **~5GB disk space** for Python packages and models

---

## Script Walkthrough

### Section 1: Load reticulate and Define Environment Name

```r
library(reticulate)

ENVNAME <- "promptstability_py310"
```

**What it does:**

- Loads the `reticulate` package for R-Python interoperability
- Sets the conda environment name to `promptstability_py310`

---

### Section 2: Check for Conda Installation

```r
# Ensure Miniconda/Conda exists
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
    stop("Failed to install Miniconda automatically...")
  })
}
```

**What it does:**

- Checks if conda is available by trying to list environments
- If conda is not found, attempts to install Miniconda automatically
- Provides helpful error messages if installation fails

**Why this matters:**

- Conda manages isolated Python environments
- Prevents package conflicts with your system Python

---

### Section 3: Clean Start - Remove Old Environment

```r
# Remove env if exists (clean start)
envs <- tryCatch(conda_list(), error = function(e) NULL)
if (!is.null(envs) && (ENVNAME %in% envs$name)) {
  message(sprintf("Removing existing conda env '%s'...", ENVNAME))
  conda_remove(envname = ENVNAME, packages = NULL)
}
```

**What it does:**

- Lists all conda environments
- If `promptstability_py310` already exists, removes it completely
- Ensures a clean installation without corrupted packages

**Why this matters:**

- Prevents issues from partially installed or corrupted packages
- Ensures reproducibility across runs

---

### Section 4: Create Fresh Python 3.10 Environment

```r
# Create env with Python 3.10
message(sprintf("Creating conda env '%s' with Python 3.10...", ENVNAME))
conda_create(envname = ENVNAME, python_version = "3.10")

# Activate env
use_condaenv(ENVNAME, required = TRUE)
print(py_config())
```

**What it does:**

- Creates a new conda environment with Python 3.10
- Activates the environment for use
- Prints Python configuration details

**Why Python 3.10?**

- Compatible with `promptstability 0.1.4`
- Supports all required dependencies

---

### Section 5: Install NumPy and Pandas via Conda

```r
# Install compiled deps via conda-forge (avoid pip build headaches on macOS ARM)
message("Installing numpy/pandas via conda-forge (pandas<2 required)...")
conda_install(
  envname  = ENVNAME,
  packages = c("numpy=1.26.*", "pandas<2"),
  channel  = "conda-forge"
)
```

**What it does:**

- Installs NumPy 1.26.x and Pandas 1.x via conda-forge
- Uses conda instead of pip for compiled packages

**Why conda-forge for these packages?**

- Pre-compiled binaries avoid build issues on macOS ARM
- Faster installation than building from source
- Better compatibility with Apple Silicon

**Why pandas<2?**

- `promptstability 0.1.4` requires Pandas 1.x

---

### Section 6: Install PyTorch 1.x via pip

```r
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
```

**What it does:**

- Installs PyTorch 1.13.1+ (but <2.0) via pip
- Installs matching versions of torchvision and torchaudio
- Verifies PyTorch can be imported successfully

**Why PyTorch 1.x instead of 2.x?**

- `promptstability 0.1.4` requires `torch<2.0.0`
- Must install PyTorch BEFORE transformers so transformers can detect it

**Why install separately?**

- Installing PyTorch first ensures transformers can find it during installation
- Prevents "PyTorch not found" errors

---

### Section 7: Install Remaining Python Packages via pip

```r
# Install remaining deps via pip
message("Installing remaining Python packages via pip...")
py_install(
  packages = c(
    "transformers>=4.35,<4.37",  # Pin to version compatible with torch 1.x
    "sentence-transformers>=2.6",
    "simpledorff>=0.0.2",
    "accelerate>=0.30",
    "matplotlib>=3.7",
    "seaborn==0.12.2",      # REQUIRED for promptstability 0.1.4
    "sentencepiece",
    "protobuf",
    "ollama",
    "git+https://github.com/palaiole13/promptstability.git"
  ),
  method = "pip",
  pip = TRUE
)
```

**What it does:**

- Installs HuggingFace transformers (pinned to 4.35-4.36)
- Installs sentence-transformers for embeddings
- Installs simpledorff for Krippendorff's Alpha calculation
- Installs plotting libraries (matplotlib, seaborn)
- Installs the Ollama Python client
- Installs promptstability directly from GitHub

**Key version constraints:**

- `transformers>=4.35,<4.37`: Compatible with torch 1.x (4.37+ requires torch 2.x)
- `seaborn==0.12.2`: Exact version required by promptstability 0.1.4
- `simpledorff>=0.0.2`: For reliability calculations

**Why install from GitHub?**

- Gets the latest version of promptstability
- May include bug fixes not yet on PyPI

---

### Section 8: Verify Installation

```r
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
```

**What it does:**

- Imports all critical packages
- Prints version numbers for debugging
- Shows where promptstability is installed

**Expected output:**
```
Python: 3.10.x
numpy: 1.26.x
pandas: 1.5.x
torch: 1.13.1
transformers: 4.35.x or 4.36.x
seaborn: 0.12.2
matplotlib: 3.x.x
```

---

### Section 9: Import promptstability Classes

```r
# Import from package root (NOT promptstability.promptstability)
ps <- import("promptstability", convert = FALSE)
PromptStabilityAnalysis <- ps$PromptStabilityAnalysis
```

**What it does:**

- Imports the promptstability module into R
- Extracts the `PromptStabilityAnalysis` class

**Why `convert = FALSE`?**

- Keeps Python objects as-is instead of converting to R types
- Necessary for proper class functionality

---

### Section 10: Prepare Sample Data

```r
# Dummy data frame in R
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
```

**What it does:**

- Creates sample texts with varying sentiments (positive, negative, neutral)
- Extracts the text column as a vector

**Your own data:**

Replace this with your own texts:

```r
my_texts <- c("text1", "text2", "text3", ...)
```

---

### Section 11: Define Ollama Annotation Function

```r
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
```

**What it does:**

- Defines a Python function that calls Ollama's chat API
- Uses `deepseek-r1:8b` as the model (you can change this)
- Takes text and prompt as input, returns the model's response

**How the annotation function works:**

1. Takes the text to classify
2. Takes the classification prompt (system message)
3. Sends both to Ollama
4. Returns the model's classification

**To use a different model:**

Change `OLLAMA_MODEL = 'deepseek-r1:8b'` to any model you have:

```python
OLLAMA_MODEL = 'llama3:instruct'  # or 'mistral:7b', etc.
```

---

### Section 12: Initialize PromptStabilityAnalysis

```r
# Instantiate analysis
psa <- PromptStabilityAnalysis(annotation_function = annotate_ollama, data = texts)
```

**What it does:**

- Creates a `PromptStabilityAnalysis` object
- Passes your annotation function (Ollama)
- Passes your data (8 sample texts)

**What happens behind the scenes:**

- Loads the PEGASUS paraphrase model (for inter-PSS)
- Loads sentence-transformers for embedding generation
- Prepares data for analysis

---

### Section 13: Define Prompts

```r
# Minimal test prompt
original_text  <- "You are a text classifier. Classify the sentiment of the user's text as Positive, Negative, or Neutral."
prompt_postfix <- "Respond with exactly one of: Positive, Negative, Neutral. Respond with nothing else."
```

**What it does:**

- `original_text`: The main instruction for the LLM
- `prompt_postfix`: Additional constraints (remains constant across paraphrases)

**Prompt design tips:**

- Be specific about expected outputs
- Use clear categories
- Add constraints to reduce variability

---

### Section 14: Run Intra-PSS (Within-Prompt Stability)

```r
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
```

**What it does:**

- Uses the **same prompt** repeatedly (3 times)
- Classifies all 8 texts with each iteration
- Calculates Krippendorff's Alpha to measure consistency
- Uses bootstrap resampling (100 samples) for confidence intervals

**Parameters explained:**

- `iterations`: How many times to run the same prompt (default: 10)
- `bootstrap_samples`: Number of bootstrap samples for CI estimation (default: 1000)
- `plot`: Whether to plot results (FALSE = no plot)

**Output:**

Returns a tuple:
1. Dictionary with KA scores: `{3: {'ka': 0.85, 'ci_lower': 0.75, 'ci_upper': 0.92}}`
2. DataFrame with all annotations

**Interpreting Krippendorff's Alpha:**

- **1.0**: Perfect agreement
- **0.8-1.0**: Good reliability
- **0.667-0.8**: Tentative conclusions
- **<0.667**: Unreliable

**Why `as.integer()`?**

- R passes numbers as floats by default
- PyTorch requires integers for certain parameters
- Without `as.integer()`, you'll get a TypeError

---

### Section 15: Run Inter-PSS (Between-Prompt Stability)

```r
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
```

**What it does:**

- Generates **paraphrases** of the original prompt using PEGASUS
- Tests two temperature settings (0.1 and 0.5)
- Creates 2 variations per temperature
- Measures consistency across semantically similar prompts

**Parameters explained:**

- `nr_variations`: Number of paraphrases per temperature (default: 5)
- `temperatures`: List of temperatures for paraphrase generation
  - Lower temp (0.1) = more similar to original
  - Higher temp (5.0) = more different from original
- `iterations`: How many times to run each paraphrased prompt (default: 1)
- `bootstrap_samples`: For confidence interval estimation
- `print_prompts`: Print generated paraphrases (useful for debugging)

**Output:**

Returns a tuple:
1. Dictionary with KA scores per temperature: `{0.1: {'ka': 0.75, ...}, 0.5: {'ka': 0.65, ...}}`
2. Combined DataFrame with all annotations

**Temperature interpretation:**

- **Lower temperatures** should yield higher KA scores (prompts are more similar)
- **Higher temperatures** typically yield lower KA scores (more semantic variation)

---

### Section 16: Completion Message

```r
message("Completed successfully.")
```

**What it does:**

- Prints a success message
- Indicates the script finished without errors

---

## Running the Script

### Step 1: Start Ollama

In a terminal:

```bash
ollama serve
```

Leave this running in the background.

### Step 2: Run the R Script

In R or RStudio:

```r
source("R_example.R")
```

### Step 3: Wait for Completion

The script will:

1. Set up the Python environment (~5-10 minutes first time)
2. Install all packages
3. Run the analysis
4. Print results

**Expected runtime:**

- First run: ~10-15 minutes (package installation)
- Subsequent runs: ~2-3 minutes (just analysis)

---

## Troubleshooting

### Error: "Conda not found"

**Solution:** The script will try to install Miniconda automatically. If it fails:

```r
reticulate::install_miniconda()
```

### Error: "Failed to connect to Ollama"

**Solution:** Start Ollama:

```bash
ollama serve
```

### Error: "PyTorch library but it was not found"

**Solution:** This was fixed by:

1. Installing PyTorch separately before other packages
2. Pinning transformers to <4.37 (compatible with torch 1.x)

If you still see this, completely remove and recreate the environment:

```bash
rm -rf ~/Library/r-miniconda-arm64/envs/promptstability_py310
```

Then re-run the script.

### Error: "'float' object cannot be interpreted as an integer"

**Solution:** Use `as.integer()` for numeric parameters:

```r
iterations = as.integer(10)
```

### Model not found error

**Solution:** Pull the model first:

```bash
ollama pull deepseek-r1:8b
```

### Out of memory errors

**Solution:**

- Use a smaller model (e.g., `llama3.2:3b` instead of `deepseek-r1:8b`)
- Reduce `nr_variations` and `bootstrap_samples`
- Close other applications

---

## Customization

### Use Your Own Data

Replace the dummy data:

```r
# Load from CSV
my_data <- read.csv("your_data.csv")
texts <- my_data$text_column

# Or create manually
texts <- c("text 1", "text 2", "text 3")
```

### Use a Different Model

Change the model in the annotation function:

```r
py_run_string("
OLLAMA_MODEL = 'llama3:instruct'  # or any model you have
")
```

### Change the Classification Task

Modify the prompts:

```r
# For binary classification
original_text  <- "Classify the following text as relevant or not relevant to climate change."
prompt_postfix <- "Respond with exactly one word: Relevant or Irrelevant."

# For multi-class classification
original_text  <- "Categorize this text into one of these topics: Politics, Sports, Technology, or Entertainment."
prompt_postfix <- "Respond with exactly one word from the list above."
```

### Adjust Analysis Parameters

For production use, increase iterations and bootstrap samples:

```r
intra_res <- psa$intra_pss(
  original_text     = original_text,
  prompt_postfix    = prompt_postfix,
  iterations        = as.integer(10),      # More iterations
  bootstrap_samples = as.integer(1000),    # More bootstrap samples
  plot              = TRUE,                 # Generate plot
  save_path         = "intra_plot.png"     # Save plot to file
)
```

### Save Results

Save annotations to CSV:

```r
intra_res <- psa$intra_pss(
  ...,
  save_csv = "intra_annotations.csv"
)
```

---

## Understanding the Results

### Intra-PSS Results

Example output:

```
{3: {'ka': 0.85, 'ci_lower': 0.78, 'ci_upper': 0.91}}
```

**Interpretation:**

- After 3 iterations, Krippendorff's Alpha is **0.85**
- 95% confidence interval: [0.78, 0.91]
- **Conclusion:** Good reliability (KA > 0.8)

### Inter-PSS Results

Example output:

```
{
  0.1: {'ka': 0.82, 'ci_lower': 0.74, 'ci_upper': 0.88},
  0.5: {'ka': 0.71, 'ci_lower': 0.62, 'ci_upper': 0.79}
}
```

**Interpretation:**

- At temperature 0.1 (similar paraphrases): KA = 0.82 (good)
- At temperature 0.5 (more variation): KA = 0.71 (tentative)
- **Conclusion:** Prompt is more stable with minimal paraphrasing

---

## Additional Resources

- **promptstability GitHub**: https://github.com/palaiole13/promptstability
- **Ollama Documentation**: https://ollama.com/docs
- **reticulate Documentation**: https://rstudio.github.io/reticulate/
- **Krippendorff's Alpha**: https://en.wikipedia.org/wiki/Krippendorff%27s_alpha

---

## Citation

If you use this code or the promptstability package, please cite:

```
Palaiologo, L. (2024). promptstability: A Python package for evaluating prompt stability
in large language models. GitHub repository: https://github.com/palaiole13/promptstability
```

---

## License

This example script is provided as-is for educational and research purposes.
