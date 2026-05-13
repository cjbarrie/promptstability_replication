library(dplyr)
library(ggplot2)
library(readr)
library(tidyr)
library(cowplot)
library(grid)

between_files <- list(
  'Tweets (Rep. Dem.)' = 'data/annotated/tweets_rd_between_expanded.csv',
  'Tweets (Populism)' = 'data/annotated/tweets_pop_between_expanded.csv',
  'News' = 'data/annotated/news_between_expanded.csv',
  'News (Short)' = 'data/annotated/news_short_between_expanded.csv',
  'Manifestos' = 'data/annotated/manifestos_between_expanded.csv',
  'Manifestos Multi' = 'data/annotated/manifestos_multi_between_expanded.csv',
  'Stance' = 'data/annotated/stance_between_expanded.csv',
  'Stance (Long)' = 'data/annotated/stance_long_between_expanded.csv',
  'MII' = 'data/annotated/mii_between_expanded.csv',
  'MII (Long)' = 'data/annotated/mii_long_between_expanded.csv',
  'Synthetic' = 'data/annotated/synth_between_expanded.csv',
  'Synthetic (Short)' = 'data/annotated/synth_short_between_expanded.csv'
)

# Define a color palette
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

between_facet_order <- c(
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

col_inter <- "#2A6F97"
col_benchmark <- "#6C757D"
col_grid_x <- "#EAEFF3"
col_grid_y <- "#E2E8EE"
col_strip_bg <- "#F7F8FA"
col_ci_fill <- "#FFF8ED"
col_ci_border <- "#D8C7B5"

read_and_preserve_types <- function(file) {
  data <- read_csv(file, col_types = cols(.default = "c"), show_col_types = FALSE)
  return(data)
}

combine_files_preserve <- function(files) {
  combined_data <- lapply(names(files), function(label) {
    file_path <- files[[label]]
    annotated_data <- read_and_preserve_types(file_path) %>%
      mutate(label = label)
    return(annotated_data)
  })
  combined_data <- bind_rows(combined_data)
  return(combined_data)
}

combined_between_data <- combine_files_preserve(between_files)
summary_file <- "data/annotated/inter_summary_metrics.csv"

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

inter_insets <- summary_metrics %>%
  mutate(
    inset_label = sprintf(
      "Mean: %.3f\nMin@T: %.2f\nRange: %.3f\n< .8: %.2f",
      mean_alpha,
      temperature_at_min_alpha,
      temperature_range_alpha,
      share_temperatures_below_threshold
    )
  ) %>%
  select(label, inset_label)


# Plot overall scores
inter_plot_data <- combined_between_data %>%
  group_by(label, temperature) %>%
  summarise(
    pss = mean(as.numeric(ka_mean), na.rm = TRUE),
    lower = {
      vals <- as.numeric(ka_lower)
      if (all(is.na(vals))) NA_real_ else min(vals, na.rm = TRUE)
    },
    upper = {
      vals <- as.numeric(ka_upper)
      if (all(is.na(vals))) NA_real_ else max(vals, na.rm = TRUE)
    },
    .groups = "drop"
  ) %>%
  mutate(
    temperature = as.numeric(temperature),
    label = factor(label, levels = between_facet_order)
  ) %>%
  filter(!is.na(pss))

make_line_samples <- function(df, x_col = "temperature", y_col = "pss", n = 250) {
  df <- df %>% arrange(.data[[x_col]])
  if (nrow(df) < 2) {
    return(tibble(x = df[[x_col]], y = df[[y_col]]))
  }
  x_seq <- seq(min(df[[x_col]], na.rm = TRUE), max(df[[x_col]], na.rm = TRUE), length.out = n)
  y_seq <- approx(df[[x_col]], df[[y_col]], xout = x_seq, rule = 2)$y
  tibble(x = x_seq, y = y_seq)
}

score_box_between <- function(panel_df, box, benchmark_y = 0.8) {
  avoid_x <- 0.12
  avoid_y <- 0.02
  box <- list(
    xmin = box$xmin - avoid_x,
    xmax = box$xmax + avoid_x,
    ymin = box$ymin - avoid_y,
    ymax = box$ymax + avoid_y
  )

  line_samples <- make_line_samples(panel_df)

  line_hits <- sum(
    line_samples$x >= box$xmin & line_samples$x <= box$xmax &
      line_samples$y >= box$ymin & line_samples$y <= box$ymax
  )

  point_hits <- panel_df %>%
    summarise(
      hits = sum(
        temperature >= box$xmin & temperature <= box$xmax &
          pss >= box$ymin & pss <= box$ymax,
        na.rm = TRUE
      )
    ) %>%
    pull(hits)

  ribbon_hits <- panel_df %>%
    filter(temperature >= box$xmin, temperature <= box$xmax) %>%
    summarise(
      hits = sum(
        !is.na(lower) & !is.na(upper) &
          pmin(upper, 1) >= box$ymin & lower <= box$ymax
      )
    ) %>%
    pull(hits)

  benchmark_hits <- if (benchmark_y >= box$ymin && benchmark_y <= box$ymax) 8 else 0

  (line_hits * 3.0) + (point_hits * 4.0) + (ribbon_hits * 1.2) + benchmark_hits
}

pick_inset_between <- function(panel_df) {
  x_min <- 0.1
  x_max <- 5.0
  y_min <- 0.0
  y_max <- 1.0
  pad_x <- 0.10
  pad_y <- 0.02
  box_w <- 1.60
  box_h <- 0.165

  candidates <- tibble::tribble(
    ~position,       ~xmin,                       ~xmax,                           ~ymin,                         ~ymax,                       ~x,            ~y,             ~hjust, ~vjust,
    "top_right",     x_max - pad_x - box_w,      x_max - pad_x,                   y_max - pad_y - box_h,        y_max - pad_y,               x_max - pad_x, y_max - pad_y,  1,      1,
    "bottom_right",  x_max - pad_x - box_w,      x_max - pad_x,                   y_min + pad_y,                y_min + pad_y + box_h,       x_max - pad_x, y_min + pad_y,  1,      0,
    "top_left",      x_min + pad_x,              x_min + pad_x + box_w,           y_max - pad_y - box_h,        y_max - pad_y,               x_min + pad_x, y_max - pad_y,  0,      1,
    "bottom_left",   x_min + pad_x,              x_min + pad_x + box_w,           y_min + pad_y,                y_min + pad_y + box_h,       x_min + pad_x, y_min + pad_y,  0,      0,
    "mid_right",     x_max - pad_x - box_w,      x_max - pad_x,                   0.42,                          0.42 + box_h,                x_max - pad_x, 0.42,           1,      0,
    "mid_left",      x_min + pad_x,              x_min + pad_x + box_w,           0.42,                          0.42 + box_h,                x_min + pad_x, 0.42,           0,      0,
    "top_center",    1.85,                       3.45,                            y_max - pad_y - box_h,        y_max - pad_y,               3.45,          y_max - pad_y,  1,      1,
    "bottom_center", 1.85,                       3.45,                            y_min + pad_y,                y_min + pad_y + box_h,       3.45,          y_min + pad_y,  1,      0
  ) %>%
    rowwise() %>%
    mutate(score = score_box_between(panel_df, pick(everything()))) %>%
    ungroup() %>%
    arrange(score)

  candidates[1, ]
}

between_inset_positions <- inter_plot_data %>%
  group_by(label) %>%
  group_modify(~ pick_inset_between(.x)) %>%
  ungroup()

between_overlay_insets <- summary_metrics %>%
  mutate(
    label = factor(label, levels = between_facet_order),
    min_temp = ifelse(
      is.na(temperature_at_min_alpha),
      "-",
      sprintf("%.1f", temperature_at_min_alpha)
    ),
    inset_label = sprintf(
      "Mean      %.3f\nMin       %.3f\nMin @ T   %s\nRange     %.3f\n< .8      %.2f",
      mean_alpha,
      min_alpha,
      min_temp,
      temperature_range_alpha,
      share_temperatures_below_threshold
    )
  ) %>%
  left_join(between_inset_positions %>% select(label, x, y, hjust, vjust), by = "label")

between_refined_plot <- ggplot(inter_plot_data, aes(x = temperature, y = pss)) +
  geom_ribbon(
    aes(ymin = lower, ymax = pmin(upper, 1)),
    fill = col_ci_fill,
    alpha = 0.60
  ) +
  geom_line(
    aes(y = lower),
    colour = col_ci_border,
    linewidth = 0.42,
    linetype = "22",
    alpha = 0.95
  ) +
  geom_line(
    aes(y = pmin(upper, 1)),
    colour = col_ci_border,
    linewidth = 0.42,
    linetype = "22",
    alpha = 0.95
  ) +
  geom_line(
    colour = col_inter,
    linewidth = 0.76,
    lineend = "round"
  ) +
  geom_point(
    colour = col_inter,
    size = 0.72,
    alpha = 0.96
  ) +
  geom_hline(yintercept = 0.8, colour = col_benchmark, linetype = "dashed", linewidth = 0.36) +
  geom_label(
    data = between_overlay_insets,
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
  scale_x_continuous(
    breaks = c(0.1, 1, 2, 3, 4, 5),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    breaks = c(0.0, 0.4, 0.8, 1.0),
    labels = c("0.0", "0.4", "0.8", "1.0"),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  coord_cartesian(ylim = c(0, 1.0), xlim = c(0.1, 5.0), expand = FALSE, clip = "off") +
  facet_wrap(~ label, ncol = 4) +
  labs(
    x = "Paraphraser temperature",
    y = "Inter-PSS"
  ) +
  theme_minimal(base_size = 10.8) +
  theme(
    aspect.ratio = 1,
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

print(between_refined_plot)
ggsave("plots/combined_between_expanded.png", plot = between_refined_plot, width = 14.6, height = 12.8, dpi = 320)

mean_pss <- combined_between_data %>%
  group_by(label) %>%
  summarise(mean_pss = mean(as.numeric(ka_mean), na.rm = TRUE), .groups = "drop")

# Plot overall scores and unique counts to check annotation performance

unique_counts <- combined_between_data %>%
  group_by(label, temperature) %>%
  summarise(unique_annotations_count = n_distinct(annotation), .groups = "drop")

inter_pss <- combined_between_data %>%
  group_by(label, temperature) %>%
  summarise(mean_inter_pss = mean(as.numeric(ka_mean), na.rm = TRUE), .groups = "drop")

plot_data <- left_join(unique_counts, inter_pss, by = c("label", "temperature")) %>%
  mutate(temperature = factor(temperature, levels = unique(temperature)))

order_by_pss <- plot_data %>%
  group_by(label) %>%
  summarise(mean_pss = mean(mean_inter_pss, na.rm = TRUE)) %>%
  arrange(desc(mean_pss)) %>%
  pull(label)

plot_data <- plot_data %>%
  mutate(label = factor(label, levels = order_by_pss))

split_data <- plot_data %>%
  group_split(label)

plot_single_dataset <- function(df) {
  this_label <- unique(df$label)
  
  # Safeguard for dividing by zero
  max_unique <- max(df$unique_annotations_count, na.rm = TRUE)
  max_pss    <- max(df$mean_inter_pss, na.rm = TRUE)
  if (max_unique == 0) max_unique <- 1
  if (max_pss == 0)    max_pss    <- 1
  
  # Ratio to align Inter-PSS onto the left axis
  ratio <- max_unique / max_pss
  
  ggplot(df, aes(x = temperature)) +
    geom_bar(
      aes(y = unique_annotations_count, fill = label),
      stat = "identity", alpha = 0.5
    ) +
    geom_line(
      aes(y = mean_inter_pss * ratio, color = "black"),
      size = 1, group = 1
    ) +
    geom_point(
      aes(y = mean_inter_pss * ratio, color = "black"),
      size = 1
    ) +
    scale_y_continuous(
      name = "Unique annotations",         # left-axis label
      sec.axis = sec_axis(
        trans = ~ . / ratio,               # map back to original Inter-PSS
        name = "Inter-PSS"                 # right-axis label
      )
    ) +
    scale_color_manual(values = color_palette) +
    scale_fill_manual(values = color_palette) +
    labs(
      x = "Temperature",
      title = paste(this_label)
    ) +
    theme_minimal() +
    theme(
      strip.text       = element_text(size = 14),
      axis.text.x      = element_text(size = 12, angle = 90, vjust = 0.5, hjust = 1),
      axis.text.y      = element_text(size = 12),
      axis.title       = element_text(size = 16),
      panel.grid.major = element_line(size = 0.1, linetype = 'solid', color = 'grey80'),
      panel.grid.minor = element_line(size = 0.1, linetype = 'solid', color = 'grey80'),
      legend.position  = "none",
      plot.title       = element_text(size = 14, hjust = 0.5)
    )
}

plot_list <- lapply(split_data, plot_single_dataset)

final_plot <- cowplot::plot_grid(plotlist = plot_list, ncol = 4)

print(final_plot)

ggsave("plots/combined_postpro_between_diagnostics.png", plot = final_plot, width = 16, height = 12, dpi = 300)
