# Canonical model-capability plotting stage.
# This numbered entrypoint reproduces the current DeepSeek/GPT figure path by
# running the existing within-cleaning and between-combination plotting logic.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", file_arg[1]))
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "24_plot_cleaned_model_comparisons_within.R"))
source(file.path(project_root, "25_plot_cleaned_model_comparisons_between.R"))
