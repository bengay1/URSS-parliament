# ============================================================================
# Calculate IRT Ideology Scores for All Years
# ============================================================================
#
# Purpose:
#   Fits 2-parameter logistic IRT models to parliamentary voting data
#   for each year. Estimates MP ideology scores on left-right spectrum.
#
# Inputs:
#   - data/combined_data_raw.csv (from script 01)
#
# Outputs:
#   - data/all_scores.csv: Complete IRT scores
#   - data/score_summary.csv: Summary statistics by year
#
# Duration: ~15-30 minutes (depends on number of years)
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

source("scripts/00_setup.R")

cat("STEP 2: CALCULATE IRT IDEOLOGY SCORES\n")

# ============================================================================
# 1. Load prepared data
# ============================================================================

if (!file.exists("data/combined_data_raw.csv")) {
  stop("✗ combined_data_raw.csv not found. Please run 01_load_election_data.R first.\n")
}

cat("Loading combined data from script 01...\n")
combined_data <- readr::read_csv("data/combined_data_raw.csv", show_col_types = FALSE)

cat("✓ Loaded", nrow(combined_data), "voting records\n")
cat("  MPs:", length(unique(combined_data$mp_name_id)), "\n")
cat("  Years:", toString(sort(unique(combined_data$year))), "\n\n")

# ============================================================================
# 2. Calculate IRT scores for each year
# ============================================================================

cat("CALCULATING IDEOLOGY SCORES FOR EACH YEAR\n")

# Process years from most recent to oldest (for stability)
available_years <- sort(unique(combined_data$year))
available_years_rev <- rev(available_years)

cat("Processing order (newest first):", toString(available_years_rev), "\n\n")

# Calculate scores using purrr::map_dfr to combine results
all_scores <- purrr::map_dfr(available_years_rev, ~{
  result <- calculate_yearly_scores(.x, combined_data)
  if (is.null(result)) {
    return(NULL)
  }
  return(result)
}, .progress = TRUE)

if (is.null(all_scores) || nrow(all_scores) == 0) {
  stop("✗ Failed to calculate any scores. Check data quality.\n")
}

cat("\n✓ Calculated", nrow(all_scores), "ideology scores\n")

# ============================================================================
# 3. Verify & summarise results
# ============================================================================

cat("RESULTS SUMMARY\n")

cat("Total scores:", nrow(all_scores), "\n")
cat("Unique MPs:", length(unique(all_scores$mp_name_id)), "\n")
cat("Years covered:", toString(sort(unique(all_scores$year))), "\n\n")

# Summary by year
score_summary <- all_scores %>%
  group_by(year, reference_mp) %>%
  summarise(
    n_mps = n(),
    mean_score = mean(z_score, na.rm = TRUE),
    sd_score = sd(z_score, na.rm = TRUE),
    min_score = min(z_score, na.rm = TRUE),
    max_score = max(z_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

cat("SCORE SUMMARY BY YEAR\n")

print(score_summary)

# ============================================================================
# 4. Save results
# ============================================================================

cat("SAVING RESULTS\n")

readr::write_csv(all_scores, "data/all_scores.csv")
cat("✓ Saved: data/all_scores.csv\n")

readr::write_csv(score_summary, "data/score_summary.csv")
cat("✓ Saved: data/score_summary.csv\n")

cat("✓ STEP 2 COMPLETE\n")
cat("  Next: Run scripts/03_analyse_ideology_change.R\n")
