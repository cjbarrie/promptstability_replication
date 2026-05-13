library(dplyr)
library(ggplot2)
library(readr)
library(tidyr)
library(cowplot)
library(grid)

within_files <- list(
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

color_palette <- c(
  'Tweets (Rep. Dem.)' = 'darkcyan',
  'Tweets (Populism)' = 'cyan',
  'News' = 'orange',
  'News (Short)' = 'darkorange',
  'Manifestos' = 'green',
  'Manifestos Multi' = 'red',
  'Stance' = 'hotpink',
  'Stance (Long)' = 'deeppink',
  'MII' = 'mediumseagreen',
  'MII (Long)' = 'seagreen',
  'Synthetic' = 'indianred',
  'Synthetic (Short)' = 'brown'
)

col_cumulative <- "#2A6F97"
col_adjacent <- "#D77A61"
col_benchmark <- "#6C757D"
col_grid_x <- "#EAEFF3"
col_grid_y <- "#E2E8EE"
col_strip_bg <- "#F7F8FA"
col_ci_fill <- "#FFF8ED"
col_ci_border <- "#D8C7B5"

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

read_and_preserve_types <- function(file) {
  read_csv(file, col_types = cols(.default = "c"), show_col_types = FALSE)
}

combine_files_preserve <- function(files) {
  combined_data <- lapply(names(files), function(label) {
    file_path <- files[[label]]
    annotated_data <- read_and_preserve_types(file_path) %>%
      mutate(label = label)
    return(annotated_data)
  })
  bind_rows(combined_data)
}

combined_within_data <- combine_files_preserve(within_files)
summary_file <- "data/annotated/rescored_intra/intra_summary_metrics.csv"

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

if (file.exists(summary_file)) {
  summary_metrics <- read_csv(summary_file, show_col_types = FALSE) %>%
    left_join(dataset_key, by = "dataset")
} else {
  warning(sprintf("Summary file not found at %s. Insets will be omitted.", summary_file))
  summary_metrics <- tibble::tibble(label = character())
}

make_line_samples <- function(df, x_col = "run_count", y_col = "pss", n = 250) {
  df <- df %>% arrange(.data[[x_col]])
  if (nrow(df) < 2) {
    return(tibble(x = df[[x_col]], y = df[[y_col]]))
  }
  x_seq <- seq(min(df[[x_col]], na.rm = TRUE), max(df[[x_col]], na.rm = TRUE), length.out = n)
  y_seq <- approx(df[[x_col]], df[[y_col]], xout = x_seq, rule = 2)$y
  tibble(x = x_seq, y = y_seq)
}

score_box_within <- function(panel_df, box, benchmark_y = 0.8) {
  avoid_x <- 0.65
  avoid_y <- 0.012
  box <- list(
    xmin = box$xmin - avoid_x,
    xmax = box$xmax + avoid_x,
    ymin = box$ymin - avoid_y,
    ymax = box$ymax + avoid_y
  )

  cumulative_line <- panel_df %>% filter(metric == "Cumulative")
  adjacent_line <- panel_df %>% filter(metric == "Adjacent")

  line_c <- make_line_samples(cumulative_line)
  line_a <- make_line_samples(adjacent_line)

  line_hits_c <- sum(line_c$x >= box$xmin & line_c$x <= box$xmax & line_c$y >= box$ymin & line_c$y <= box$ymax)
  line_hits_a <- sum(line_a$x >= box$xmin & line_a$x <= box$xmax & line_a$y >= box$ymin & line_a$y <= box$ymax)

  point_hits <- adjacent_line %>%
    summarise(
      hits = sum(
        run_count >= box$xmin & run_count <= box$xmax &
          pss >= box$ymin & pss <= box$ymax,
        na.rm = TRUE
      )
    ) %>%
    pull(hits)

  ribbon_hits <- cumulative_line %>%
    filter(run_count >= box$xmin, run_count <= box$xmax) %>%
    summarise(
      hits = sum(
        !is.na(lower) & !is.na(upper) &
          pmin(upper, 1) >= box$ymin & lower <= box$ymax
      )
    ) %>%
    pull(hits)

  benchmark_hits <- if (benchmark_y >= box$ymin && benchmark_y <= box$ymax) 8 else 0

  (line_hits_c * 3.0) + (line_hits_a * 2.5) + (point_hits * 4.0) + (ribbon_hits * 1.2) + benchmark_hits
}

pick_inset_within <- function(panel_df) {
  x_min <- 1
  x_max <- 30
  y_min <- 0.75
  y_max <- 1.0
  pad_x <- 0.45
  pad_y <- 0.008
  box_w <- 8.0
  box_h <- 0.108

  candidates <- tibble::tribble(
    ~position,       ~xmin,                       ~xmax,                           ~ymin,                         ~ymax,                       ~x,            ~y,             ~hjust, ~vjust,
    "top_right",     x_max - pad_x - box_w,      x_max - pad_x,                   y_max - pad_y - box_h,        y_max - pad_y,               x_max - pad_x, y_max - pad_y,  1,      1,
    "bottom_right",  x_max - pad_x - box_w,      x_max - pad_x,                   y_min + pad_y,                y_min + pad_y + box_h,       x_max - pad_x, y_min + pad_y,  1,      0,
    "top_left",      x_min + pad_x,              x_min + pad_x + box_w,           y_max - pad_y - box_h,        y_max - pad_y,               x_min + pad_x, y_max - pad_y,  0,      1,
    "bottom_left",   x_min + pad_x,              x_min + pad_x + box_w,           y_min + pad_y,                y_min + pad_y + box_h,       x_min + pad_x, y_min + pad_y,  0,      0,
    "mid_right",     x_max - pad_x - box_w,      x_max - pad_x,                   0.82,                          0.82 + box_h,                x_max - pad_x, 0.82,           1,      0,
    "mid_left",      x_min + pad_x,              x_min + pad_x + box_w,           0.82,                          0.82 + box_h,                x_min + pad_x, 0.82,           0,      0,
    "top_center",    11.5,                       19.5,                            y_max - pad_y - box_h,        y_max - pad_y,               19.5,          y_max - pad_y,  1,      1,
    "bottom_center", 11.5,                       19.5,                            y_min + pad_y,                y_min + pad_y + box_h,       19.5,          y_min + pad_y,  1,      0
  ) %>%
    rowwise() %>%
    mutate(score = score_box_within(panel_df, pick(everything()))) %>%
    ungroup() %>%
    arrange(score)

  candidates[1, ]
}

cumulative_overlay_data <- combined_within_data %>%
  group_by(label, iteration) %>%
  summarise(
    pss = mean(as.numeric(cumulative_ka_mean), na.rm = TRUE),
    lower = {
      vals <- as.numeric(cumulative_ka_lower)
      if (all(is.na(vals))) NA_real_ else min(vals, na.rm = TRUE)
    },
    upper = {
      vals <- as.numeric(cumulative_ka_upper)
      if (all(is.na(vals))) NA_real_ else max(vals, na.rm = TRUE)
    },
    .groups = "drop"
  ) %>%
  mutate(
    iteration = as.integer(iteration),
    run_count = iteration + 1,
    metric = "Cumulative"
  ) %>%
  filter(!is.na(pss))

adjacent_overlay_data <- combined_within_data %>%
  group_by(label, iteration) %>%
  summarise(
    pss = mean(as.numeric(adjacent_ka_mean), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    iteration = as.integer(iteration),
    run_count = iteration + 1,
    metric = "Adjacent"
  ) %>%
  filter(!is.na(pss))

within_overlay_plot_data <- bind_rows(
  cumulative_overlay_data %>% select(label, iteration, run_count, metric, pss, lower, upper),
  adjacent_overlay_data %>%
    mutate(lower = NA_real_, upper = NA_real_) %>%
    select(label, iteration, run_count, metric, pss, lower, upper)
) %>%
  mutate(label = factor(label, levels = within_facet_order))

within_inset_positions <- within_overlay_plot_data %>%
  group_by(label) %>%
  group_modify(~ pick_inset_within(.x)) %>%
  ungroup()

within_overlay_insets <- summary_metrics %>%
  mutate(
    label = factor(label, levels = within_facet_order),
    stable_at = ifelse(
      is.na(cumulative_run_count_to_estimate_stability),
      "-",
      as.character(round(cumulative_run_count_to_estimate_stability))
    ),
    inset_label = sprintf(
      "Cum final  %.3f\nCum CIw    %.3f\nStable@    %s\nAdj mean   %.3f\nAdj SD     %.3f\nAdj < .8   %.2f",
      cumulative_final_alpha,
      cumulative_final_ci_width,
      stable_at,
      adjacent_mean_alpha,
      adjacent_sd_alpha,
      adjacent_share_below_threshold
    )
  ) %>%
  left_join(within_inset_positions %>% select(label, x, y, hjust, vjust), by = "label")

within_overlay_plot <- ggplot() +
  geom_ribbon(
    data = filter(within_overlay_plot_data, metric == "Cumulative"),
    aes(x = run_count, ymin = lower, ymax = pmin(upper, 1)),
    fill = col_ci_fill,
    alpha = 0.60
  ) +
  geom_line(
    data = filter(within_overlay_plot_data, metric == "Cumulative"),
    aes(x = run_count, y = lower),
    colour = col_ci_border,
    linewidth = 0.42,
    linetype = "22",
    alpha = 0.95
  ) +
  geom_line(
    data = filter(within_overlay_plot_data, metric == "Cumulative"),
    aes(x = run_count, y = pmin(upper, 1)),
    colour = col_ci_border,
    linewidth = 0.42,
    linetype = "22",
    alpha = 0.95
  ) +
  geom_line(
    data = filter(within_overlay_plot_data, metric == "Cumulative"),
    aes(x = run_count, y = pss, colour = metric),
    linewidth = 0.76,
    lineend = "round"
  ) +
  geom_line(
    data = filter(within_overlay_plot_data, metric == "Adjacent"),
    aes(x = run_count, y = pss, colour = metric, linetype = metric),
    linewidth = 0.76,
    alpha = 0.98,
    lineend = "round"
  ) +
  geom_point(
    data = filter(within_overlay_plot_data, metric == "Adjacent"),
    aes(x = run_count, y = pss, colour = metric),
    size = 0.62,
    stroke = 0.35,
    shape = 1,
    alpha = 0.98
  ) +
  geom_hline(yintercept = 0.8, colour = col_benchmark, linetype = "dashed", linewidth = 0.36) +
  geom_label(
    data = within_overlay_insets,
    aes(x = x, y = y, label = inset_label, hjust = hjust, vjust = vjust),
    label.size = 0.12,
    label.r = unit(0.12, "lines"),
    size = 2.18,
    fill = "white",
    alpha = 0.94,
    lineheight = 0.88,
    family = "mono",
    inherit.aes = FALSE
  ) +
  scale_colour_manual(
    name = NULL,
    values = c("Cumulative" = col_cumulative, "Adjacent" = col_adjacent),
    breaks = c("Cumulative", "Adjacent")
  ) +
  scale_linetype_manual(
    name = NULL,
    values = c("Cumulative" = "solid", "Adjacent" = "22"),
    breaks = c("Cumulative", "Adjacent")
  ) +
  scale_x_continuous(
    breaks = c(1, 10, 20, 30),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    breaks = c(0.75, 0.8, 0.9, 1.0),
    labels = c("0.75", "0.8", "0.9", "1.0"),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  coord_cartesian(ylim = c(0.75, 1.0), xlim = c(1, 30), expand = FALSE, clip = "off") +
  facet_wrap(~ label, ncol = 4) +
  labs(
    x = "Run count",
    y = "Intra-PSS"
  ) +
  theme_minimal(base_size = 10.8) +
  theme(
    aspect.ratio = 1,
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.margin = margin(t = 1, r = 0, b = -1, l = 0),
    legend.spacing.x = unit(12, "pt"),
    legend.key.width = unit(24, "pt"),
    legend.key.height = unit(12, "pt"),
    legend.text = element_text(size = 10.2, face = "bold"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = col_grid_x, linewidth = 0.28),
    panel.grid.major.y = element_line(colour = col_grid_y, linewidth = 0.30),
    panel.spacing = unit(0.62, "lines"),
    strip.background = element_rect(fill = col_strip_bg, colour = NA),
    strip.text = element_text(size = 9.9, face = "bold", margin = margin(t = 2, b = 3)),
    axis.title.x = element_text(size = 10.8, margin = margin(t = 6)),
    axis.title.y = element_text(size = 10.8, margin = margin(r = 6)),
    axis.text = element_text(size = 8.25, colour = "#41505F"),
    plot.margin = margin(t = 4, r = 4, b = 1, l = 2)
  )

print(within_overlay_plot)
ggsave(
  "plots/combined_within_overlay.png",
  plot = within_overlay_plot,
  width = 14.6,
  height = 12.8,
  dpi = 320
)

cumulative_insets <- summary_metrics %>%
  mutate(
    inset_label = sprintf(
      "Final: %.3f\nStable@: %s\nCIw: %.3f",
      cumulative_final_alpha,
      ifelse(is.na(cumulative_run_count_to_estimate_stability), "-", as.character(round(cumulative_run_count_to_estimate_stability))),
      cumulative_final_ci_width
    )
  ) %>%
  select(label, inset_label)

adjacent_insets <- summary_metrics %>%
  mutate(
    inset_label = sprintf(
      "Mean: %.3f\nSD: %.3f\n< .8: %.2f",
      adjacent_mean_alpha,
      adjacent_sd_alpha,
      adjacent_share_below_threshold
    )
  ) %>%
  select(label, inset_label)

plot_intra_metric <- function(
  data,
  mean_col,
  lower_col,
  upper_col,
  y_label,
  summary_mode = c("final", "mean"),
  y_limits = c(0, 1),
  inset_df = NULL,
  save_path
) {
  summary_mode <- match.arg(summary_mode)

  metric_data <- data %>%
    group_by(label, iteration) %>%
    summarise(
      mean_intra_pss = mean(as.numeric(.data[[mean_col]]), na.rm = TRUE),
      ka_upper = max(as.numeric(.data[[upper_col]]), na.rm = TRUE),
      ka_lower = min(as.numeric(.data[[lower_col]]), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      iteration = as.integer(iteration),
      run_count = iteration + 1,
      plot_ka_upper = pmin(ka_upper, 1)
    ) %>%
    filter(!is.na(mean_intra_pss))

  if (summary_mode == "final") {
    summary_scores <- metric_data %>%
      group_by(label) %>%
      slice_max(order_by = iteration, n = 1, with_ties = FALSE) %>%
      ungroup() %>%
      transmute(label, summary_pss = mean_intra_pss)
  } else {
    summary_scores <- metric_data %>%
      group_by(label) %>%
      summarise(summary_pss = mean(mean_intra_pss, na.rm = TRUE), .groups = "drop")
  }

  plot_data <- metric_data %>%
    left_join(summary_scores, by = "label") %>%
    mutate(label = factor(label, levels = within_facet_order))

  split_data <- plot_data %>% group_split(label)

  plot_single_dataset <- function(df) {
    this_label <- unique(df$label)
    this_summary <- unique(df$summary_pss)
    inset_label <- NULL

    if (!is.null(inset_df) && nrow(inset_df) > 0) {
      inset_label <- inset_df %>%
        filter(label == as.character(this_label)) %>%
        pull(inset_label)
      if (length(inset_label) == 0) {
        inset_label <- NULL
      } else {
        inset_label <- inset_label[[1]]
      }
    }

    plot_obj <- ggplot(df) +
      geom_line(
        aes(x = run_count, y = mean_intra_pss, color = label),
        size = 1, group = 1
      ) +
      geom_point(
        aes(x = run_count, y = mean_intra_pss, color = label),
        size = 1
      ) +
      geom_errorbar(
        aes(x = run_count, y = mean_intra_pss, ymin = ka_lower, ymax = plot_ka_upper, alpha = 0.1),
        width = 0.2
      ) +
      geom_hline(yintercept = this_summary, color = "gray40", linetype = "dashed", size = 0.8) +
      geom_hline(yintercept = 0.8, color = "black", linetype = "dashed", size = 0.8) +
      geom_text(
        aes(x = Inf, y = this_summary, label = round(this_summary, 2)),
        hjust = 1.1, vjust = -0.5, size = 6, inherit.aes = FALSE
      ) +
      scale_color_manual(values = color_palette) +
      labs(
        x = "Run count",
        y = y_label,
        title = paste(this_label)
      ) +
      ylim(y_limits[1], y_limits[2]) +
      theme_minimal() +
      theme(
        legend.position = "none",
        strip.text = element_text(size = 10)
      )

    if (!is.null(inset_label)) {
      inset_y <- y_limits[1] + 0.03 * (y_limits[2] - y_limits[1])
      plot_obj <- plot_obj +
        annotate(
          "label",
          x = Inf,
          y = inset_y,
          label = inset_label,
          hjust = 1.05,
          vjust = -0.1,
          size = 3.0,
          label.size = 0.2,
          fill = "white",
          alpha = 0.9
        )
    }

    plot_obj
  }

  plot_list <- lapply(split_data, plot_single_dataset)
  final_plot <- cowplot::plot_grid(plotlist = plot_list, ncol = 4)
  print(final_plot)
  ggsave(save_path, plot = final_plot, width = 18, height = 10, dpi = 300)
}

plot_intra_metric(
  combined_within_data,
  mean_col = "cumulative_ka_mean",
  lower_col = "cumulative_ka_lower",
  upper_col = "cumulative_ka_upper",
  y_label = "Cumulative Intra-PSS",
  summary_mode = "final",
  y_limits = c(0.75, 1),
  inset_df = cumulative_insets,
  save_path = "plots/combined_within_cumulative.png"
)

plot_intra_metric(
  combined_within_data,
  mean_col = "adjacent_ka_mean",
  lower_col = "adjacent_ka_lower",
  upper_col = "adjacent_ka_upper",
  y_label = "Adjacent-Run Intra-PSS",
  summary_mode = "mean",
  y_limits = c(0.6, 1),
  inset_df = adjacent_insets,
  save_path = "plots/combined_within_adjacent.png"
)

# Plot annotation-format diagnostics
unique_counts <- combined_within_data %>%
  group_by(label, iteration) %>%
  summarise(unique_annotations_count = n_distinct(annotation), .groups = "drop") %>%
  mutate(iteration = as.integer(iteration))

cumulative_scores <- combined_within_data %>%
  group_by(label, iteration) %>%
  summarise(mean_intra_pss = mean(as.numeric(cumulative_ka_mean), na.rm = TRUE), .groups = "drop") %>%
  mutate(
    iteration = as.integer(iteration),
    run_count = iteration + 1
  ) %>%
  filter(!is.na(mean_intra_pss))

plot_data <- left_join(unique_counts, cumulative_scores, by = c("label", "iteration")) %>%
  mutate(run_count = as.integer(iteration) + 1)

order_by_pss <- cumulative_scores %>%
  group_by(label) %>%
  slice_max(order_by = iteration, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(desc(mean_intra_pss)) %>%
  pull(label)

plot_data <- plot_data %>%
  mutate(label = factor(label, levels = order_by_pss))

split_data <- plot_data %>% group_split(label)

plot_single_dataset_diagnostic <- function(df) {
  this_label <- unique(df$label)
  max_unique <- max(df$unique_annotations_count, na.rm = TRUE)
  max_pss <- max(df$mean_intra_pss, na.rm = TRUE)
  if (max_unique == 0) max_unique <- 1
  if (max_pss == 0) max_pss <- 1
  ratio <- max_unique / max_pss

  ggplot(df, aes(x = run_count)) +
    geom_bar(
      aes(y = unique_annotations_count, fill = label),
      stat = "identity", alpha = 0.5
    ) +
    geom_line(
      aes(y = mean_intra_pss * ratio, color = "black"),
      size = 1, group = 1
    ) +
    geom_point(
      aes(y = mean_intra_pss * ratio, color = "black"),
      size = 1
    ) +
    scale_y_continuous(
      name = "Unique annotations",
      sec.axis = sec_axis(
        trans = ~ . / ratio,
        name = "Cumulative Intra-PSS"
      )
    ) +
    scale_color_manual(values = color_palette) +
    scale_fill_manual(values = color_palette) +
    labs(
      x = "Run count",
      title = paste(this_label)
    ) +
    theme_minimal() +
    theme(
      legend.position = "none",
      strip.text = element_text(size = 10)
    )
}

plot_list <- lapply(split_data, plot_single_dataset_diagnostic)
final_plot <- cowplot::plot_grid(plotlist = plot_list, ncol = 4)
print(final_plot)
ggsave("plots/combined_postpro_within_diagnostics.png", plot = final_plot, width = 18, height = 10, dpi = 300)
