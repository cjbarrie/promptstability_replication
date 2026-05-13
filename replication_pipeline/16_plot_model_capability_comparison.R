# Canonical model-capability plotting stage.
library(dplyr)
library(reticulate)
library(readr)
library(ggplot2)
library(cowplot)

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", file_arg[1]))
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

python_bin <- file.path(project_root, "pssenv", "bin", "python")
if (!file.exists(python_bin)) {
  stop(
    paste(
      "Required Python environment not found at", shQuote(python_bin),
      "Run `bash setup_pssenv.sh` from the repo root before stage 16."
    )
  )
}

col_gpt <- "#2A6F97"
col_deepseek <- "#D77A61"
col_benchmark <- "#6C757D"
col_grid_x <- "#EAEFF3"
col_grid_y <- "#E2E8EE"
col_panel_bg <- "#FBFCFD"
col_label_fill <- "#FFF8ED"
col_panel_border <- "#D7DEE6"
fill_gpt <- "#E7F1F7"
fill_deepseek <- "#F5E4DD"

capability_theme <- theme_minimal(base_size = 11) +
  theme(
    panel.background = element_rect(fill = col_panel_bg, colour = NA),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = col_grid_x, linewidth = 0.28),
    panel.grid.major.y = element_line(colour = col_grid_y, linewidth = 0.30),
    panel.border = element_rect(fill = NA, colour = col_panel_border, linewidth = 0.42),
    axis.title = element_text(size = 10.8),
    axis.text = element_text(size = 8.8, colour = "#41505F"),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 11, face = "bold"),
    legend.key.width = unit(1.35, "lines"),
    legend.key.height = unit(0.95, "lines"),
    legend.margin = margin(t = 3, b = 0),
    plot.margin = margin(t = 4, r = 6, b = 4, l = 4),
    aspect.ratio = 1
  )

make_stats_box <- function(label_text) {
  ggplot() +
    annotate(
      "label",
      x = 0.02,
      y = 0.98,
      hjust = 0,
      vjust = 1,
      label = label_text,
      size = 3.0,
      family = "mono",
      fontface = "bold",
      label.size = 0.34,
      label.padding = unit(0.22, "lines"),
      label.r = unit(0.16, "lines"),
      fill = col_label_fill,
      colour = "#33404C"
    ) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") +
    theme_void() +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.margin = margin(t = 0, r = 6, b = 0, l = 4)
    )
}

fmt_num <- function(x) sprintf("%.3f", x)
fmt_temp <- function(x) sprintf("%.1f", x)
fmt_stable <- function(x) ifelse(is.na(x), "-", sprintf("%02d", round(x)))

extract_integer_after_think <- function(annotation_text) {
  extracted <- sub(".*think>\\s*(\\d+).*", "\\1", annotation_text)
  as.numeric(extracted)
}

use_python(python_bin, required = TRUE)
output_dir <- file.path(project_root, "data", "example")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_root, "plots"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_root, "replication_pipeline", "data", "example"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_root, "replication_pipeline", "plots"), recursive = TRUE, showWarnings = FALSE)

ollama_raw_file <- file.path(output_dir, "ollama_intra.csv")
ollama_clean_file <- file.path(output_dir, "ollama_intra_cleaned.csv")
openai_intra_file <- file.path(output_dir, "openai_intra.csv")
ollama_rescored_file <- file.path(output_dir, "ollama_intra_rescored.csv")
openai_rescored_file <- file.path(output_dir, "openai_intra_rescored.csv")
intra_summary_file <- file.path(output_dir, "intra_comparison_summary.csv")
inter_file <- file.path(output_dir, "ollama_inter.csv")
inter_clean_file <- file.path(output_dir, "ollama_inter_cleaned.csv")
openai_inter_file <- file.path(output_dir, "openai_inter.csv")
ka_results_file <- file.path(output_dir, "ka_results_combined.csv")
inter_summary_file <- file.path(output_dir, "inter_comparison_summary.csv")

read_csv(ollama_raw_file, show_col_types = FALSE) %>%
  mutate(annotation_cleaned = extract_integer_after_think(annotation)) %>%
  write.csv(ollama_clean_file, row.names = FALSE)

python_script_intra <- paste0(
  "import pandas as pd\n",
  "import simpledorff\n",
  "from utils import PromptStabilityAnalysis\n",
  "BOOTSTRAP = 250\n",
  "def compute_intra(input_path, annotation_col, output_path, model_name):\n",
  "    df = pd.read_csv(input_path).copy()\n",
  "    df['annotation'] = pd.to_numeric(df[annotation_col], errors='coerce')\n",
  "    df['iteration'] = pd.to_numeric(df['iteration'], errors='coerce')\n",
  "    df['id'] = pd.to_numeric(df['id'], errors='coerce')\n",
  "    keep_cols = [col for col in ['id', 'text', 'annotation', 'iteration'] if col in df.columns]\n",
  "    df = df[keep_cols].dropna(subset=['id', 'annotation', 'iteration']).copy()\n",
  "    df['id'] = df['id'].astype(int)\n",
  "    df['iteration'] = df['iteration'].astype(int)\n",
  "    psa = PromptStabilityAnalysis(annotation_function=None, data=[], metric_fn=simpledorff.metrics.nominal_metric, load_generation_models=False)\n",
  "    score_map, rescored = psa.score_intra_annotations(df, bootstrap_samples=BOOTSTRAP, analysis_modes=['cumulative_alpha', 'adjacent_alpha'])\n",
  "    summaries = psa.summarize_intra_scores(score_map)\n",
  "    rescored['model'] = model_name\n",
  "    rescored.to_csv(output_path, index=False)\n",
  "    cumulative = summaries['cumulative_alpha']\n",
  "    adjacent = summaries['adjacent_alpha']\n",
  "    return {\n",
  "        'model': model_name,\n",
  "        'cumulative_final_alpha': cumulative['final_alpha'],\n",
  "        'cumulative_final_ci_width': cumulative['final_ci_width'],\n",
  "        'cumulative_run_count_to_estimate_stability': cumulative['run_count_to_estimate_stability'],\n",
  "        'adjacent_mean_alpha': adjacent['mean_alpha'],\n",
  "        'adjacent_sd_alpha': adjacent['sd_alpha'],\n",
  "        'adjacent_share_below_threshold': adjacent['share_below_threshold']\n",
  "    }\n",
  "summary_rows = []\n",
  "summary_rows.append(compute_intra('", openai_intra_file, "', 'annotation', '", openai_rescored_file, "', 'gpt-4o'))\n",
  "summary_rows.append(compute_intra('", ollama_clean_file, "', 'annotation_cleaned', '", ollama_rescored_file, "', 'deepseek-r1-8b'))\n",
  "pd.DataFrame(summary_rows).to_csv('", intra_summary_file, "', index=False)\n"
)
reticulate::py_run_string(python_script_intra)

df_openai_intra <- read_csv(openai_rescored_file, show_col_types = FALSE) %>%
  group_by(iteration, run_count, model) %>%
  summarise(pss = mean(as.numeric(cumulative_ka_mean), na.rm = TRUE), .groups = "drop")

df_ollama_intra <- read_csv(ollama_rescored_file, show_col_types = FALSE) %>%
  group_by(iteration, run_count, model) %>%
  summarise(pss = mean(as.numeric(cumulative_ka_mean), na.rm = TRUE), .groups = "drop")

df_intra <- bind_rows(df_openai_intra, df_ollama_intra) %>%
  mutate(model = factor(model, levels = c("gpt-4o", "deepseek-r1-8b"))) %>%
  filter(!is.na(pss))

intra_summary <- read_csv(intra_summary_file, show_col_types = FALSE) %>%
  mutate(model = factor(model, levels = c("gpt-4o", "deepseek-r1-8b")))

make_intra_label <- function(summary_df) {
  gpt <- summary_df %>% filter(model == "gpt-4o")
  ds <- summary_df %>% filter(model == "deepseek-r1-8b")
  sprintf(
    paste(
      "gpt-4o",
      "Fin %s | CIw %s",
      "S@  %s | Am  %s",
      "Asd %s | <.8 %s",
      "",
      "deepseek-r1-8b",
      "Fin %s | CIw %s",
      "S@  %s | Am  %s",
      "Asd %s | <.8 %s",
      sep = "\n"
    ),
    fmt_num(gpt$cumulative_final_alpha),
    fmt_num(gpt$cumulative_final_ci_width),
    fmt_stable(gpt$cumulative_run_count_to_estimate_stability),
    fmt_num(gpt$adjacent_mean_alpha),
    fmt_num(gpt$adjacent_sd_alpha),
    sprintf("%.2f", gpt$adjacent_share_below_threshold),
    fmt_num(ds$cumulative_final_alpha),
    fmt_num(ds$cumulative_final_ci_width),
    fmt_stable(ds$cumulative_run_count_to_estimate_stability),
    fmt_num(ds$adjacent_mean_alpha),
    fmt_num(ds$adjacent_sd_alpha),
    sprintf("%.2f", ds$adjacent_share_below_threshold)
  )
}

intra_label <- make_intra_label(intra_summary)
run_min <- min(df_intra$run_count, na.rm = TRUE)
run_max <- max(df_intra$run_count, na.rm = TRUE)
run_breaks <- sort(unique(c(run_min, 5, 10, 15, run_max)))

p_intra_core <- ggplot(df_intra, aes(x = run_count, y = pss, color = model, fill = model)) +
  geom_hline(yintercept = 0.8, colour = col_benchmark, linetype = "dashed", linewidth = 0.36) +
  geom_line(linewidth = 0.78, lineend = "round") +
  geom_point(size = 1.7) +
  labs(x = "Run count", y = "Intra-PSS", color = "Model") +
  scale_color_manual(
    values = c("gpt-4o" = col_gpt, "deepseek-r1-8b" = col_deepseek),
    breaks = c("gpt-4o", "deepseek-r1-8b"),
    labels = c("gpt-4o", "deepseek-r1-8b")
  ) +
  scale_fill_manual(
    values = c("gpt-4o" = fill_gpt, "deepseek-r1-8b" = fill_deepseek),
    guide = "none"
  ) +
  scale_x_continuous(
    breaks = run_breaks,
    limits = c(run_min, run_max),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    limits = c(0.55, 1.0),
    breaks = c(0.6, 0.7, 0.8, 0.9, 1.0),
    expand = expansion(mult = c(0, 0))
  ) +
  capability_theme

p_intra_stats <- make_stats_box(intra_label)
p_intra <- plot_grid(
  p_intra_core + theme(legend.position = "none"),
  p_intra_stats,
  ncol = 1,
  align = "v",
  rel_heights = c(1, 0.24)
)
saveRDS(p_intra, file = file.path(output_dir, "intra_plot.rds"))
saveRDS(p_intra_core, file = file.path(output_dir, "intra_plot_core.rds"))

read_csv(inter_file, show_col_types = FALSE) %>%
  mutate(annotation_cleaned = extract_integer_after_think(annotation)) %>%
  select(-any_of(c("ka_mean", "ka_lower", "ka_upper"))) %>%
  write.csv(inter_clean_file, row.names = FALSE)

python_script_inter <- paste0(
  "import pandas as pd\n",
  "import simpledorff\n",
  "from utils import PromptStabilityAnalysis\n",
  "BOOTSTRAP = 250\n",
  "def calculate_ka(df, annotator_col='prompt_id', class_col='annotation_cleaned'):\n",
  "    df = df.copy()\n",
  "    df[annotator_col] = pd.to_numeric(df[annotator_col], errors='coerce')\n",
  "    df[class_col] = pd.to_numeric(df[class_col], errors='coerce')\n",
  "    df['id'] = pd.to_numeric(df['id'], errors='coerce')\n",
  "    df['temperature'] = pd.to_numeric(df['temperature'], errors='coerce')\n",
  "    df = df.dropna(subset=['id', 'temperature', annotator_col, class_col]).copy()\n",
  "    df['id'] = df['id'].astype(int)\n",
  "    grouped = df.groupby('temperature')\n",
  "    results = []\n",
  "    psa = PromptStabilityAnalysis(annotation_function=None, data=[], metric_fn=simpledorff.metrics.nominal_metric, load_generation_models=False)\n",
  "    for temp, group in grouped:\n",
  "        score_input = group[['id', annotator_col, class_col]].rename(columns={class_col: 'annotation'})\n",
  "        mean_alpha, (ci_lower, ci_upper) = psa.bootstrap_krippendorff(score_input, annotator_col, BOOTSTRAP)\n",
  "        results.append({'temperature': temp, 'ka_mean': mean_alpha, 'ka_lower': ci_lower, 'ka_upper': ci_upper})\n",
  "    return pd.DataFrame(results)\n",
  "data = pd.read_csv('", inter_clean_file, "')\n",
  "ka_results = calculate_ka(data, annotator_col='prompt_id')\n",
  "ka_results['dataset'] = 'manifestos'\n",
  "ka_results['type'] = 'inter'\n",
  "ka_results.to_csv('", ka_results_file, "', index=False)\n"
)
reticulate::py_run_string(python_script_inter)

df_deepseek_inter <- read_csv(ka_results_file, show_col_types = FALSE) %>%
  distinct(temperature, ka_mean, ka_lower, ka_upper) %>%
  mutate(model = "deepseek-r1-8b")

df_openai_inter <- read_csv(openai_inter_file, show_col_types = FALSE) %>%
  distinct(temperature, ka_mean, ka_lower, ka_upper) %>%
  mutate(model = "gpt-4o")

df_inter <- bind_rows(df_deepseek_inter, df_openai_inter) %>%
  mutate(
    temperature = as.numeric(temperature),
    ka_mean = as.numeric(ka_mean),
    model = factor(model, levels = c("gpt-4o", "deepseek-r1-8b"))
  ) %>%
  filter(!is.na(ka_mean))

inter_summary <- df_inter %>%
  group_by(model) %>%
  summarise(
    mean_alpha = mean(ka_mean, na.rm = TRUE),
    min_alpha = min(ka_mean, na.rm = TRUE),
    temperature_at_min_alpha = temperature[which.min(ka_mean)][1],
    temperature_range_alpha = max(ka_mean, na.rm = TRUE) - min(ka_mean, na.rm = TRUE),
    share_below_threshold = mean(ka_mean < 0.8, na.rm = TRUE),
    .groups = "drop"
  )
write.csv(inter_summary, inter_summary_file, row.names = FALSE)

make_inter_label <- function(summary_df) {
  gpt <- summary_df %>% filter(model == "gpt-4o")
  ds <- summary_df %>% filter(model == "deepseek-r1-8b")
  sprintf(
    paste(
      "gpt-4o",
      "Mean %s | Min %s",
      "Tmin %s | Rng %s",
      "<.8  %s",
      "",
      "deepseek-r1-8b",
      "Mean %s | Min %s",
      "Tmin %s | Rng %s",
      "<.8  %s",
      sep = "\n"
    ),
    fmt_num(gpt$mean_alpha),
    fmt_num(gpt$min_alpha),
    fmt_temp(gpt$temperature_at_min_alpha),
    fmt_num(gpt$temperature_range_alpha),
    sprintf("%.2f", gpt$share_below_threshold),
    fmt_num(ds$mean_alpha),
    fmt_num(ds$min_alpha),
    fmt_temp(ds$temperature_at_min_alpha),
    fmt_num(ds$temperature_range_alpha),
    sprintf("%.2f", ds$share_below_threshold)
  )
}

inter_label <- make_inter_label(inter_summary)

p_inter_core <- ggplot(df_inter, aes(x = temperature, y = ka_mean, color = model, fill = model)) +
  geom_hline(yintercept = 0.8, colour = col_benchmark, linetype = "dashed", linewidth = 0.36) +
  geom_line(linewidth = 0.78, lineend = "round") +
  geom_point(size = 1.7) +
  labs(x = "Temperature", y = "Inter-PSS", color = "Model") +
  scale_color_manual(
    values = c("gpt-4o" = col_gpt, "deepseek-r1-8b" = col_deepseek),
    breaks = c("gpt-4o", "deepseek-r1-8b"),
    labels = c("gpt-4o", "deepseek-r1-8b")
  ) +
  scale_fill_manual(
    values = c("gpt-4o" = fill_gpt, "deepseek-r1-8b" = fill_deepseek),
    guide = "none"
  ) +
  scale_x_continuous(
    breaks = c(0.1, 1, 2, 3, 4, 5),
    limits = c(0.1, 5),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = c(0, 0.4, 0.8, 1.0),
    expand = expansion(mult = c(0, 0))
  ) +
  capability_theme

p_inter_stats <- make_stats_box(inter_label)
legend <- get_legend(p_inter_core)
p_inter <- plot_grid(
  p_inter_core + theme(legend.position = "none"),
  p_inter_stats,
  ncol = 1,
  align = "v",
  rel_heights = c(1, 0.24)
)

combined_panels <- plot_grid(p_intra, p_inter, ncol = 2, align = "hv", axis = "tblr")
combined_panels <- ggdraw(combined_panels) +
  draw_plot_label(
    label = c("A", "B"),
    x = c(0.015, 0.515),
    y = c(0.985, 0.985),
    hjust = 0,
    vjust = 1,
    size = 12,
    fontface = "bold",
    colour = "#1F2A36"
  )
combined_plot <- plot_grid(combined_panels, legend, ncol = 1, rel_heights = c(1, 0.12))

print(combined_plot)
ggsave(file.path(project_root, "plots", "combined_model_comparison_plot.png"), combined_plot, width = 10.2, height = 6.2, dpi = 320, bg = "white")

file.copy(intra_summary_file, file.path(project_root, "replication_pipeline", "data", "example", basename(intra_summary_file)), overwrite = TRUE)
file.copy(inter_summary_file, file.path(project_root, "replication_pipeline", "data", "example", basename(inter_summary_file)), overwrite = TRUE)
file.copy(ollama_clean_file, file.path(project_root, "replication_pipeline", "data", "example", basename(ollama_clean_file)), overwrite = TRUE)
file.copy(inter_clean_file, file.path(project_root, "replication_pipeline", "data", "example", basename(inter_clean_file)), overwrite = TRUE)
file.copy(openai_rescored_file, file.path(project_root, "replication_pipeline", "data", "example", basename(openai_rescored_file)), overwrite = TRUE)
file.copy(ollama_rescored_file, file.path(project_root, "replication_pipeline", "data", "example", basename(ollama_rescored_file)), overwrite = TRUE)
file.copy(ka_results_file, file.path(project_root, "replication_pipeline", "data", "example", basename(ka_results_file)), overwrite = TRUE)
file.copy(file.path(output_dir, "intra_plot.rds"), file.path(project_root, "replication_pipeline", "data", "example", "intra_plot.rds"), overwrite = TRUE)
file.copy(file.path(output_dir, "intra_plot_core.rds"), file.path(project_root, "replication_pipeline", "data", "example", "intra_plot_core.rds"), overwrite = TRUE)
file.copy(file.path(project_root, "plots", "combined_model_comparison_plot.png"), file.path(project_root, "replication_pipeline", "plots", "combined_model_comparison_plot.png"), overwrite = TRUE)
