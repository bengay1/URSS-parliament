# ============================================================================
# Visualise Party & MP Ideology Trends
# ============================================================================
#
# Purpose:
#   Creates comprehensive visualisations of party and individual MP trends
#   Demonstrates how ideology has shifted over time
#
# Inputs:
#   - data/all_scores.csv (from script 02)
#   - data/mp_slopes_15years.csv (from script 03)
#
# Outputs:
#   - data/trends_*.png: Various visualisations
#
# Duration: ~5 minutes
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

source("scripts/00_setup.R")

cat("STEP 4: VISUALISE TRENDS\n")

# ============================================================================
# 1. Load data
# ============================================================================

cat("Loading data...\n")

if (!file.exists("data/all_scores.csv")) {
  stop("✗ all_scores.csv not found. Run scripts 01-02 first.\n")
}

all_scores <- readr::read_csv("data/all_scores.csv", show_col_types = FALSE)
cat("✓ Loaded scores\n")

# ============================================================================
# 2. Party-level trends
# ============================================================================

cat("\nCREATING PARTY-LEVEL VISUALISATIONS\n")

# Group by year and calculate party means
if (file.exists("data/combined_data_raw.csv")) {
  combined_data <- readr::read_csv("data/combined_data_raw.csv", show_col_types = FALSE)

  # Join scores with party information
  party_trends <- all_scores %>%
    left_join(
      combined_data %>% distinct(mp_name_id, party_clean),
      by = "mp_name_id"
    ) %>%
    filter(!is.na(party_clean)) %>%
    filter(party_clean %in% c("Conservative", "Labour", "Liberal Democrat")) %>%
    group_by(party_clean, year) %>%
    summarise(
      avg_z_score = mean(z_score, na.rm = TRUE),
      n_mps = n(),
      .groups = "drop"
    ) %>%
    filter(n_mps >= 5)

  # Plot party trends
  p_party <- ggplot(party_trends,
                    aes(x = year, y = avg_z_score, color = party_clean, group = party_clean)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2) +
    labs(
      title = "Major Party Ideology Scores Over Time",
      subtitle = "Based on IRT Scaling of Parliamentary Votes (1997-2025)",
      x = "Year",
      y = "Average Ideology Score (Left ← → Right)",
      color = "Party",
      caption = "Higher scores = more rightward ideology"
    ) +
    scale_color_manual(
      values = c(
        "Conservative" = "#0087DC",
        "Labour" = "#DC241f",
        "Liberal Democrat" = "#FAA61A"
      )
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11),
      legend.position = "bottom"
    ) +
    scale_x_continuous(breaks = seq(1997, 2025, 2))

  print(p_party)
  ggsave("data/party_ideology_trends.png", p_party, width = 13, height = 7, dpi = 300)
  cat("✓ Saved: data/party_ideology_trends.png\n")

  # Party summary table
  party_summary <- party_trends %>%
    group_by(party_clean) %>%
    summarise(
      years = n(),
      first_year = min(year),
      last_year = max(year),
      overall_avg = mean(avg_z_score),
      min_avg = min(avg_z_score),
      max_avg = max(avg_z_score),
      .groups = "drop"
    ) %>%
    arrange(overall_avg)

  cat("\nParty Summary:\n")
  print(party_summary)

  readr::write_csv(party_summary, "data/party_summary.csv")
  cat("✓ Saved: data/party_summary.csv\n")
}

# ============================================================================
# 3. Individual MP trends
# ============================================================================

cat("\nCREATING MP-LEVEL VISUALISATIONS\n")

# Select prominent MPs for trending
featured_mps <- c("Jeremy Corbyn", "Keir Starmer", "David Cameron", "Theresa May",
                  "Tony Blair", "Gordon Brown", "Boris Johnson")

mp_trends_data <- all_scores %>%
  filter(mp_name_id %in% featured_mps) %>%
  arrange(year)

if (nrow(mp_trends_data) > 0) {
  p_mp <- ggplot(mp_trends_data,
                 aes(x = year, y = z_score, color = mp_name_id, group = mp_name_id)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    labs(
      title = "Ideology Scores for Selected MPs Over Time",
      subtitle = "Tracking individual ideological positions (1997-2025)",
      x = "Year",
      y = "Ideology Score (Left ← → Right)",
      color = "MP",
      caption = "Higher scores = more rightward ideology"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      legend.position = "bottom",
      legend.text = element_text(size = 9)
    ) +
    scale_x_continuous(breaks = seq(1997, 2025, 2)) +
    scale_color_brewer(palette = "Set1")

  print(p_mp)
  ggsave("data/selected_mp_trends.png", p_mp, width = 13, height = 8, dpi = 300)
  cat("✓ Saved: data/selected_mp_trends.png\n")
}

# ============================================================================
# 4. Score distribution over time
# ============================================================================

cat("\nCREATING DISTRIBUTION VISUALISATIONS\n")

# Box plots by year (selected years for clarity)
selected_years <- seq(1997, 2024, 3)
dist_data <- all_scores %>% filter(year %in% selected_years)

if (nrow(dist_data) > 0) {
  p_dist <- ggplot(dist_data, aes(x = factor(year), y = z_score)) +
    geom_boxplot(fill = "steelblue", alpha = 0.7) +
    geom_jitter(width = 0.2, alpha = 0.3, size = 1) +
    labs(
      title = "Distribution of MP Ideology Scores Over Time",
      x = "Year",
      y = "Ideology Score (Left ← → Right)",
      caption = "Box = IQR, line = median, points = individual MPs"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

  print(p_dist)
  ggsave("data/distribution_by_year.png", p_dist, width = 12, height = 7, dpi = 300)
  cat("✓ Saved: data/distribution_by_year.png\n")
}

# ============================================================================
# 5. Summary statistics table
# ============================================================================

cat("\nGENERATING SUMMARY STATISTICS\n")

yearly_stats <- all_scores %>%
  group_by(year) %>%
  summarise(
    n_mps = n(),
    mean = mean(z_score, na.rm = TRUE),
    sd = sd(z_score, na.rm = TRUE),
    min = min(z_score, na.rm = TRUE),
    q25 = quantile(z_score, 0.25, na.rm = TRUE),
    median = median(z_score, na.rm = TRUE),
    q75 = quantile(z_score, 0.75, na.rm = TRUE),
    max = max(z_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

cat("\nYearly Summary Statistics:\n")
print(yearly_stats)

readr::write_csv(yearly_stats, "data/yearly_statistics.csv")
cat("✓ Saved: data/yearly_statistics.csv\n")

# ============================================================================
# Summary
# ============================================================================

cat("✓ STEP 4 COMPLETE\n")
cat("\nGenerated visualisations:\n")
cat("  • data/party_ideology_trends.png\n")
cat("  • data/selected_mp_trends.png\n")
cat("  • data/distribution_by_year.png\n")
cat("  • data/party_summary.csv\n")
cat("  • data/yearly_statistics.csv\n")
cat("\nAll analysis outputs saved to: data/\n")
