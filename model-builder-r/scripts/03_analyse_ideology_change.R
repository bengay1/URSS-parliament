# ============================================================================
# Analyse Ideological Change Over MP Careers
# ============================================================================
#
# Purpose:
#   Runs linear regression to identify MPs with significant ideological shifts
#   Generates tables, plots, and detailed analysis
#
# Inputs:
#   - data/all_scores.csv (from script 02)
#
# Outputs:
#   - data/mp_slopes_5years.csv: Regression results - Mps with min 5 years data
#   - data/mp_slopes_15years.csv: Regression results - Mps with min 15 years data
#   - data/most_positive_mps.csv: MPs shifting leftward (positive slope)
#   - data/most_negative_mps.csv: MPs shifting rightward (negative slope)
#   - data/*.png: Visualisations
#
# Duration: ~5 minutes
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

source("scripts/00_setup.R")

cat("STEP 3: ANALYSE IDEOLOGICAL CHANGE\n")

# ============================================================================
# 1. Load scores
# ============================================================================

if (!file.exists("data/all_scores.csv")) {
  stop("✗ all_scores.csv not found. Please run 02_calculate_ideology_scores.R first.\n")
}

cat("Loading ideology scores...\n")
all_scores <- readr::read_csv("data/all_scores.csv", show_col_types = FALSE)

cat("✓ Loaded", nrow(all_scores), "scores for", length(unique(all_scores$mp_name_id)),
    "MPs\n\n")

# ============================================================================
# 2. Calculate slopes for career ideological change
# ============================================================================

cat("CALCULATING IDEOLOGY CHANGE SLOPES\n")

mp_slopes <- calculate_mp_slopes(all_scores, min_years = 15)
mp_slopes_5 <- calculate_mp_slopes(all_scores, min_years = 5)

cat("✓ Calculated slopes for", nrow(mp_slopes_5), "MPs (5+ years data)\n\n")
cat("✓ Calculated slopes for", nrow(mp_slopes), "MPs (15+ years data)\n\n")

# ============================================================================
# 3. Identify key trends
# ============================================================================

cat("IDENTIFYING KEY TRENDS\n")

# Most rightward shift
most_positive <- mp_slopes %>%
  filter(slope > 0) %>%
  arrange(desc(slope)) %>%
  slice(1:15)

cat("\nTop 15 MPs with INCREASING ideology scores (shifting leftward):\n")
print(most_positive %>%
        dplyr::select(mp_name_id, slope, p_value, significance, years_in_parliament))

# Most leftward shift
most_negative <- mp_slopes %>%
  filter(slope < 0) %>%
  arrange(slope) %>%
  slice(1:15)

cat("\nTop 15 MPs with DECREASING ideology scores (shifting rightward):\n")
print(most_negative %>%
        dplyr::select(mp_name_id, slope, p_value, significance, years_in_parliament))

# ============================================================================
# 4. Summary statistics
# ============================================================================

cat("SUMMARY STATISTICS\n")

cat("Total MPs:", nrow(mp_slopes), "\n")
cat("Average slope:", round(mean(mp_slopes$slope, na.rm = TRUE), 4), "per year\n")
cat("SD of slopes:", round(sd(mp_slopes$slope, na.rm = TRUE), 4), "\n")
cat("Range:", round(min(mp_slopes$slope, na.rm = TRUE), 4), "to",
    round(max(mp_slopes$slope, na.rm = TRUE), 4), "\n\n")

# Significant changes
significant <- mp_slopes %>% filter(p_value < 0.05)
sig_increase <- significant %>% filter(slope > 0)
sig_decrease <- significant %>% filter(slope < 0)

cat("MPs with SIGNIFICANT changes (p < 0.05):\n")
cat("  Total:", nrow(significant), "(",
    round(nrow(significant) / nrow(mp_slopes) * 100, 1), "%)\n")
cat("  Increasing:", nrow(sig_increase), "\n")
cat("  Decreasing:", nrow(sig_decrease), "\n\n")

# Most consistent
most_consistent <- mp_slopes %>%
  mutate(abs_slope = abs(slope)) %>%
  arrange(abs_slope) %>%
  slice(1:10)

cat("Top 10 Most IDEOLOGICALLY CONSISTENT MPs (minimal change):\n")
print(most_consistent %>%
        dplyr::select(mp_name_id, slope, years_in_parliament, career_span))

# ============================================================================
# 5. Save results
# ============================================================================

cat("SAVING RESULTS\n")

readr::write_csv(mp_slopes, "data/mp_slopes_15years.csv")
cat("✓ Saved: data/mp_slopes_15years.csv\n")

readr::write_csv(mp_slopes_5, "data/mp_slopes_5years.csv")
cat("✓ Saved: data/mp_slopes_5years.csv\n")

readr::write_csv(most_positive, "data/most_positive_mps.csv")
cat("✓ Saved: data/most_positive_mps.csv\n")

readr::write_csv(most_negative, "data/most_negative_mps.csv")
cat("✓ Saved: data/most_negative_mps.csv\n")

# ============================================================================
# 6. Generate visualisations
# ============================================================================

cat("\nGenerating visualisations...\n")

plot_career_vs_slope(mp_slopes_5, save_path = "data/career_vs_slope.png")

# Histogram of slopes
p_slopes <- ggplot(mp_slopes, aes(x = slope)) +
  geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7, color = "white") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", size = 1) +
  geom_vline(xintercept = mean(mp_slopes$slope), linetype = "dashed", color = "blue", size = 1) +
  annotate("text", x = mean(mp_slopes$slope), y = Inf,
           label = paste("Mean:", round(mean(mp_slopes$slope), 4)),
           vjust = 2, hjust = -0.1, color = "blue") +
  labs(
    title = "Distribution of Ideology Change Slopes (15+ Years Data)",
    subtitle = paste(nrow(mp_slopes), "MPs |",
                     round(mean(mp_slopes$career_span), 1), "year average career"),
    x = "Slope (Ideology Change per Year)",
    y = "Number of MPs"
  ) +
  theme_minimal(base_size = 12)

ggsave("data/slope_histogram.png", p_slopes, width = 12, height = 8, dpi = 300)
cat("✓ Saved: data/slope_histogram.png\n")

# Plot top changers
top_changers <- bind_rows(
  most_positive %>% head(8) %>% mutate(direction = "Increasing"),
  most_negative %>% head(8) %>% mutate(direction = "Decreasing")
)

p_changers <- ggplot(top_changers,
                     aes(x = reorder(mp_name_id, slope), y = slope, fill = direction)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "MPs with Most Extreme Ideology Changes (15+ Years)",
    x = "MP Name",
    y = "Slope (Change per Year)",
    fill = "Direction"
  ) +
  scale_fill_manual(values = c("Increasing" = "red", "Decreasing" = "blue")) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top")

ggsave("data/top_changing_mps.png", p_changers, width = 12, height = 10, dpi = 300)
cat("✓ Saved: data/top_changing_mps.png\n")

cat("✓ STEP 3 COMPLETE\n")
cat("  Review: data/mp_slopes_15years.csv\n")
cat("  Next: Run scripts/04_visualise_trends.R\n")

