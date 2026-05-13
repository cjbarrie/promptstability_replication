library(dplyr)
library(ggplot2)
library(readr)
library(tidyr)

dataset_key <- tibble::tribble(
  ~dataset, ~label,
  "tweets_rd", "Tweets (Rep. Dem.)",
  "tweets_pop", "Tweets (Populism)",
  "news", "News",
  "news_short", "News (Short)",
  "manifestos", "Manifestos",
  "manifestos_multi", "Manifestos Multi",
  "stance", "Stance",
  "stance_long", "Stance (Long)",
  "mii", "MII",
  "mii_long", "MII (Long)",
  "synth", "Synthetic",
  "synth_short", "Synthetic (Short)"
)

raw_within_files <- list(
  'Tweets (Rep. Dem.)' = 'data/annotated/rescored_intra/tweets_rd_within_rescored.csv',
  'Tweets (Populism)' = 'data/annotated/rescored_intra/tweets_pop_within_rescored.csv',
  'News' = 'data/annotated/rescored_intra/news_within_rescored.csv',
  'News (Short)' = 'data/annotated/rescored_intra/news_short_within_rescored.csv',
  'Manifestos' = 'data/annotated/rescored_intra/manifestos_within_rescored.csv',
  'Manifestos Multi' = 'data/annotated/rescored_intra/manifestos_multi_within_rescored.csv',
  'Stance' = 'data/annotated/rescored_intra/stance_within_rescored.csv',
  'Stance (Long)' = 'data/annotated/rescored_intra/stance_long_within_rescored.csv',
  'MII' = 'data/annotated/rescored_intra/mii_within_rescored.csv',
  'MII (Long)' = 'data/annotated/rescored_intra/mii_long_within_rescored.csv',
  'Synthetic' = 'data/annotated/rescored_intra/synth_within_rescored.csv',
  'Synthetic (Short)' = 'data/annotated/rescored_intra/synth_short_within_rescored.csv'
)

filtered_within_files <- list(
  'Tweets (Rep. Dem.)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/tweets_rd_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/tweets_rd_filtered_balanced_rescored.csv'
  ),
  'Tweets (Populism)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/tweets_pop_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/tweets_pop_filtered_balanced_rescored.csv'
  ),
  'News' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/news_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/news_filtered_balanced_rescored.csv'
  ),
  'News (Short)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/news_short_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/news_short_filtered_balanced_rescored.csv'
  ),
  'Manifestos' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/manifestos_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/manifestos_filtered_balanced_rescored.csv'
  ),
  'Manifestos Multi' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/manifestos_multi_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/manifestos_multi_filtered_balanced_rescored.csv'
  ),
  'Stance' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/stance_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/stance_filtered_balanced_rescored.csv'
  ),
  'Stance (Long)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/stance_long_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/stance_long_filtered_balanced_rescored.csv'
  ),
  'MII' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/mii_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/mii_filtered_balanced_rescored.csv'
  ),
  'MII (Long)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/mii_long_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/mii_long_filtered_balanced_rescored.csv'
  ),
  'Synthetic' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/synth_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/synth_filtered_balanced_rescored.csv'
  ),
  'Synthetic (Short)' = list(
    'Filtered' = 'data/annotated/reannotated/within_rescored/synth_short_filtered_rescored.csv',
    'Filtered & Balanced' = 'data/annotated/reannotated/within_rescored/synth_short_filtered_balanced_rescored.csv'
  )
)

read_and_preserve_types <- function(file) {
  read_csv(file, col_types = cols(.default = "c"), show_col_types = FALSE)
}

combine_files_with_type <- function(raw_files, filtered_files) {
  combined_data <- lapply(names(raw_files), function(label) {
    display_label <- label
    rows <- list()

    raw_path <- raw_files[[label]]
    if (file.exists(raw_path)) {
      rows[[length(rows) + 1]] <- read_and_preserve_types(raw_path) %>%
        select(-any_of("label")) %>%
        mutate(label = display_label, type = "Original")
    }

    if (!is.null(filtered_files[[label]])) {
      for (type_name in names(filtered_files[[label]])) {
        file_path <- filtered_files[[label]][[type_name]]
        if (file.exists(file_path)) {
          rows[[length(rows) + 1]] <- read_and_preserve_types(file_path) %>%
            select(-any_of("label")) %>%
            mutate(label = display_label, type = type_name)
        }
      }
    }

    bind_rows(rows)
  })

  bind_rows(combined_data)
}

combined_within_data <- combine_files_with_type(raw_within_files, filtered_within_files)

line_colors <- c(
  "Original" = "black",
  "Filtered" = "#E69F00",
  "Filtered & Balanced" = "#56B4E9"
)

line_types <- c(
  "Original" = "dotted",
  "Filtered" = "solid",
  "Filtered & Balanced" = "dashed"
)

within_facet_order <- c(
  'Tweets (Rep. Dem.)',
  'Tweets (Populism)',
  'Manifestos',
  'Manifestos Multi',
  'Stance',
  'Stance (Long)',
  'MII',
  'MII (Long)',
  'News',
  'News (Short)',
  'Synthetic',
  'Synthetic (Short)'
)

plot_filtered_metric <- function(
  data,
  mean_col,
  y_label,
  y_limits,
  summary_mode = c("final", "mean"),
  save_path
) {
  summary_mode <- match.arg(summary_mode)

  metric_data <- data %>%
    group_by(label, type, iteration) %>%
    summarise(mean_intra_pss = mean(as.numeric(.data[[mean_col]]), na.rm = TRUE), .groups = "drop") %>%
    mutate(
      iteration = as.integer(iteration),
      run_count = iteration + 1,
      type = factor(type, levels = c("Original", "Filtered", "Filtered & Balanced"))
    ) %>%
    filter(!is.na(mean_intra_pss))

  plot_data <- metric_data %>%
    mutate(label = factor(label, levels = within_facet_order))

  final_plot <- ggplot(plot_data, aes(x = run_count, y = mean_intra_pss, color = type, linetype = type)) +
    geom_line(linewidth = 1) +
    geom_point(size = 0.8) +
    scale_color_manual(values = line_colors, drop = FALSE, name = "Type") +
    scale_linetype_manual(values = line_types, drop = FALSE, name = "Type") +
    facet_wrap(~ label, ncol = 4) +
    labs(
      x = "Run count",
      y = y_label
    ) +
    coord_cartesian(ylim = y_limits) +
    theme_minimal() +
    theme(
      legend.position = "bottom",
      strip.text = element_text(size = 10)
    )

  print(final_plot)
  ggsave(save_path, plot = final_plot, width = 18, height = 10.5, dpi = 300)
}

plot_filtered_metric(
  combined_within_data,
  mean_col = "cumulative_ka_mean",
  y_label = "Cumulative Intra-PSS",
  y_limits = c(0.75, 1),
  summary_mode = "final",
  save_path = "plots/combined_within_postpro_cumulative.png"
)

plot_filtered_metric(
  combined_within_data,
  mean_col = "adjacent_ka_mean",
  y_label = "Adjacent-Run Intra-PSS",
  y_limits = c(0.6, 1),
  summary_mode = "mean",
  save_path = "plots/combined_within_postpro_adjacent.png"
)
