# ============================================================================
# Helper Functions: Visualisation & Plots
# ============================================================================
#
# This file contains functions for creating publication-quality visualisations
#

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
