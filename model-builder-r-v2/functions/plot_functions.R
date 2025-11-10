# ============================================================================
# Helper Functions: Visualisation & Plots
# ============================================================================
#
# This file contains functions for creating publication-quality visualisations
#

#' Plot Party Ideology Time Series
#'
#' Creates time series plot of major party average ideology scores
#'
plot_party_timeseries <- function(all_scores, save_path = NULL) {

  cat("\nCreating party ideology time series...\n")

  # Calculate party averages by year
  party_data <- all_scores %>%
    group_by(year) %>%
    summarise(
      avg_z = mean(z_score, na.rm = TRUE),
      n = n(),
      .groups = "drop"
    )

  # Define party colours (official UK party colours)
  party_colors <- c(
    "Conservative" = "#0087DC",
    "Labour" = "#DC241f",
    "Liberal Democrat" = "#FAA61A",
    "SNP" = "#3F8428",
    "Green" = "#6AB023",
    "Plaid Cymru" = "#005B54"
  )

  # Create plot
  p <- ggplot(party_data, aes(x = year, y = avg_z)) +
    geom_line(linewidth = 1.2, color = "#0087DC") +
    geom_point(size = 2, color = "#0087DC") +
    labs(
      title = "UK MP Average Ideology Score Over Time",
      subtitle = "Based on IRT Analysis of Parliamentary Votes (1997-2025)",
      x = "Year",
      y = "Average Ideology Score (Left ← → Right)",
      caption = "Higher scores indicate more rightward ideology"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11),
      axis.text = element_text(size = 10),
      axis.title = element_text(size = 11),
      plot.caption = element_text(size = 9, color = "gray50")
    ) +
    scale_x_continuous(breaks = seq(1997, 2025, 2))

  print(p)

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 12, height = 7, dpi = 300)
    cat("✓ Saved to:", save_path, "\n")
  }

  return(invisible(p))
}


#' Plot Distribution of Ideology Scores
#'
#' Histogram of MP ideology scores for a given year
#'
plot_score_distribution <- function(all_scores, year = NULL, save_path = NULL) {

  if (!is.null(year)) {
    data <- all_scores %>% filter(year == !!year)
    title <- paste("Distribution of MP Ideology Scores -", year)
  } else {
    data <- all_scores
    title <- "Distribution of MP Ideology Scores (All Years)"
  }

  p <- ggplot(data, aes(x = z_score)) +
    geom_histogram(bins = 40, fill = "#0087DC", alpha = 0.7, color = "white") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", size = 0.8) +
    geom_vline(xintercept = mean(data$z_score, na.rm = TRUE),
               linetype = "dashed", color = "blue", size = 0.8) +
    labs(
      title = title,
      x = "Ideology Score (Left ← → Right)",
      y = "Number of MPs",
      caption = "Red line = 0 (neutral), Blue line = mean"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.caption = element_text(size = 9, color = "gray50")
    )

  print(p)

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 10, height = 6, dpi = 300)
    cat("✓ Saved to:", save_path, "\n")
  }

  return(invisible(p))
}


#' Plot MP Career Ideological Shifts
#'
#' Scatter plot of ideology change (slope) vs career length
#'
plot_career_vs_slope <- function(mp_slopes, save_path = NULL) {

  cat("\nCreating career vs slope plot...\n")

  p <- ggplot(mp_slopes, aes(x = career_span, y = slope, color = significance, size = abs(slope))) +
    geom_point(alpha = 0.6) +
    geom_smooth(method = "lm", se = TRUE, color = "black", alpha = 0.15, linewidth = 0.5) +
    scale_color_manual(
      values = c("***" = "red", "**" = "orange", "*" = "gold",
                 "." = "lightblue", "ns" = "gray80")
    ) +
    labs(
      title = "MP Ideological Change vs Career Length",
      x = "Career Span (Years)",
      y = "Ideology Slope (Change per Year)",
      color = "Significance",
      size = "|Slope|",
      caption = "Larger points = larger ideological shifts"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.caption = element_text(size = 9, color = "gray50")
    )

  print(p)

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 11, height = 7, dpi = 300)
    cat("✓ Saved to:", save_path, "\n")
  }

  return(invisible(p))
}


#' Plot Slope Distribution
#'
#' Histogram of ideology change slopes
#'
plot_slope_distribution <- function(mp_slopes, save_path = NULL) {

  p <- ggplot(mp_slopes, aes(x = slope)) +
    geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7, color = "white") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", size = 0.8) +
    geom_vline(xintercept = mean(mp_slopes$slope, na.rm = TRUE),
               linetype = "dashed", color = "blue", size = 0.8) +
    labs(
      title = "Distribution of MP Ideology Change Slopes",
      x = "Slope (Ideology Change per Year)",
      y = "Number of MPs",
      caption = "Red = no change, Blue = mean change"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.caption = element_text(size = 9, color = "gray50")
    )

  print(p)

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 10, height = 6, dpi = 300)
    cat("✓ Saved to:", save_path, "\n")
  }

  return(invisible(p))
}
