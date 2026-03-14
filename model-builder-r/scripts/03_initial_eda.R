# ============================================================================
# Exploratory & Custom Analysis (Integrated)
# ============================================================================
#
# Purpose:
#   Integrates exploratory tools from legacy RMarkdown files:
#   1. Calculate direct voting agreement rates between MPs (Dot plot of all MPs).
#   2. Compare ideology scores across specific years (Stability Check).
#   3. Visualise trends for custom groups of MPs.
#   4. Generate ICC (Item Characteristic Curve) plots for all votes.
#   5. Plot score distributions for all MPs in a specific year.
#
# Inputs:
#   - data/combined_data_raw.csv (Voting data)
#   - data/all_scores.csv (IRT Scores)
#
# Outputs:
#   - Plots and CSVs for agreement rates, stability checks, ICC curves, and distributions.
#
# Duration: ~5-10 minutes
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

source("scripts/00_setup.R")

cat("STEP 3: EXPLORATORY & CUSTOM DATA ANALYSIS\n")

# ============================================================================
# 1. Load Data & Fix Metadata
# ============================================================================

cat("Loading data...\n")

if (!file.exists("data/combined_data_raw.csv") || !file.exists("data/all_scores.csv")) {
  stop("✗ Required data files not found. Please run scripts 01 and 02 first.\n")
}

# Load raw voting data (contains party info)
vote_data <- readr::read_csv("data/combined_data_raw.csv", show_col_types = FALSE)

# Load calculated scores (missing party info)
scores_data <- readr::read_csv("data/all_scores.csv", show_col_types = FALSE)

cat("✓ Loaded voting data and ideology scores.\n")

# Map parties to scores
cat("Mapping parties to ideology scores...\n")
mp_party_map <- vote_data %>%
  dplyr::select(mp_name_id, year, party_clean) %>%
  distinct() %>%
  group_by(mp_name_id, year) %>%
  slice(1) %>%
  ungroup()

scores_data <- scores_data %>%
  left_join(mp_party_map, by = c("mp_name_id", "year"))

cat("✓ Data preparation complete.\n\n")


# ============================================================================
# 2. MP Agreement Rate Analysis
# ============================================================================

calculate_agreement <- function(data, target_name_pattern, target_year) {
  
  cat(paste0("Calculating agreement with MPs matching '", target_name_pattern, "' in ", target_year, "...\n"))
  
  year_data <- data %>% filter(year == target_year)
  
  if (nrow(year_data) == 0) {
    cat(paste0("  ! No data found for the year ", target_year, "\n"))
    return(NULL)
  }
  
  target_mp <- year_data %>%
    filter(grepl(target_name_pattern, mp_name_id, ignore.case = TRUE)) %>%
    distinct(mp_name_id) %>%
    slice(1) %>%
    pull(mp_name_id)
  
  if (length(target_mp) == 0) {
    cat("  ! Target MP not found in this year.\n")
    return(NULL)
  }
  cat(paste0("  -> Reference MP found: ", target_mp, "\n"))
  
  target_votes <- year_data %>%
    filter(mp_name_id == target_mp) %>%
    dplyr::select(voteno, target_vote = vote_binary)
  
  # Join and Calculate Agreement for ALL MPs
  agreement_stats <- year_data %>%
    filter(mp_name_id != target_mp) %>% 
    inner_join(target_votes, by = "voteno") %>%
    group_by(mp_name_id, party_clean) %>%
    summarise(
      total_shared_votes = n(),
      agreed_votes = sum(vote_binary == target_vote, na.rm = TRUE),
      agreement_rate = agreed_votes / total_shared_votes,
      .groups = "drop"
    ) %>%
    filter(total_shared_votes >= 10) %>% 
    arrange(desc(agreement_rate))
  
  if (nrow(agreement_stats) == 0) return(NULL)
  
  # Plot agreement rates
  p <- ggplot(agreement_stats,
              aes(x = reorder(mp_name_id, agreement_rate),
                  y = agreement_rate, color = party_clean)) +
    geom_point(alpha = 0.7) +
    coord_flip() +
    scale_color_manual(values = c(
      "Conservative" = "#0087DC", "Labour" = "#E4003B", "Liberal Democrat" = "#FAA61A",
      "SNP" = "#FFF95D", "Green" = "#6AB023", "Reform UK" = "#12B6CF", "Other" = "#999999"
    ), na.value = "#999999") +
    labs(
      title = paste("Vote Agreement Rates with", target_mp, "(", target_year, ")"),
      x = "MP",
      y = "Agreement Rate",
      color = "Party"
    ) +
    theme_minimal() +
    theme(
      axis.text.y = element_blank(),  # Hide MP labels on y-axis for clarity
      axis.ticks.y = element_blank()
    )
  
  print(p)
  
  filename <- paste0("data/agreement_",
                     gsub("[^A-Za-z0-9]", "_", target_name_pattern),
                     "_", target_year, ".png")
  ggsave(filename, p, width = 10, height = 8, dpi = 300)
  cat("✓ Saved:", filename, "\n")
  
  return(agreement_stats)
}

# Run agreement examples
avail_years <- sort(unique(vote_data$year))
latest_year <- max(avail_years)

cat("\n--- Running Agreement Analysis ---\n")
tryCatch({
  mp_name <- if(latest_year >= 2024) "Starmer" else "Corbyn"
  result <- calculate_agreement(vote_data, mp_name, latest_year)
  
  if (is.null(result) && length(avail_years) > 1) {
    prev_year <- avail_years[length(avail_years)-1]
    cat(paste0("  ! Retrying with previous year: ", prev_year, "...\n"))
    calculate_agreement(vote_data, mp_name, prev_year)
  }
}, error = function(e) cat(paste("  ! Skipped example:", e$message, "\n")))


# ============================================================================
# 3. Year-on-Year Stability Analysis (Z-Score Comparison)
# ============================================================================

compare_years <- function(scores, year1, year2) {
  
  cat(paste0("\nComparing Ideology Scores: ", year1, " vs ", year2, "\n"))
  
  comparison <- scores %>%
    filter(year %in% c(year1, year2)) %>%
    dplyr::select(mp_name_id, party = party_clean, year, z_score) %>% 
    pivot_wider(names_from = year, values_from = z_score, names_prefix = "score_") %>%
    na.omit() 
  
  if (nrow(comparison) < 5) return(NULL)
  
  col1 <- paste0("score_", year1)
  col2 <- paste0("score_", year2)
  
  cor_val <- cor(comparison[[col1]], comparison[[col2]])
  
  p <- ggplot(comparison, aes(x = .data[[col1]], y = .data[[col2]], color = party)) +
    geom_point(alpha = 0.6) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey") +
    scale_color_manual(values = c(
      "Conservative" = "#0087DC", "Labour" = "#E4003B", "Liberal Democrat" = "#FAA61A",
      "SNP" = "#FFF95D", "Green" = "#6AB023", "Reform UK" = "#12B6CF", "Other" = "#999999"
    ), na.value = "#999999") +
    labs(
      title = paste0("Ideology Stability: ", year1, " vs ", year2),
      subtitle = paste0("Pearson Correlation: ", round(cor_val, 3)),
      x = paste0("Ideology Score (", year1, ")"),
      y = paste0("Ideology Score (", year2, ")")
    ) +
    theme_minimal()
  
  print(p)
  ggsave(paste0("data/stability_", year1, "_vs_", year2, ".png"), p,
         width = 8, height = 6, dpi = 300)
}

if (length(avail_years) >= 2) {
  compare_years(scores_data, avail_years[length(avail_years)-1], avail_years[length(avail_years)])
}


# ============================================================================
# 4. Custom MP Groups Trends
# ============================================================================

cat("\nVisualising Custom MP Groups...\n")

# Using full exact names to prevent plotting multiple different MPs with same surname
custom_mps <- c("Michael Fabricant", "Jeremy Corbyn", "Theresa May", 
                "Keir Starmer", "Boris Johnson", "Angela Rayner", "Nigel Farage")

custom_trends <- scores_data %>%
  filter(mp_name_id %in% custom_mps)

if (nrow(custom_trends) > 0) {
  p_custom <- ggplot(custom_trends, aes(x = year, y = z_score, color = mp_name_id)) +
    geom_line(linewidth = 1) +
    geom_point() +
    labs(
      title = "Ideology Trajectories: Selected MPs",
      y = "Ideology Score",
      x = "Year",
      color = "MP"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  print(p_custom)
  ggsave("data/custom_mp_trends.png", p_custom, width = 10, height = 6, dpi = 300)
  cat("✓ Saved: data/custom_mp_trends.png\n")
} else {
  cat("  ! No matching MPs found for custom plot.\n")
}


# ============================================================================
# 5. ICC (Item Characteristic Curve) Plot
# ============================================================================

plot_icc_for_year <- function(data, year_select, ref_mp_name = "Corbyn") {
  
  cat(paste0("\nGenerating ICC Plot for ", year_select, " (Ref: ", ref_mp_name, ")\n"))
  
  yearly_data <- data %>% filter(year == year_select)
  if (nrow(yearly_data) == 0) return(NULL)
  
  ref_mp_id <- yearly_data %>%
    filter(grepl(ref_mp_name, mp_name_id, ignore.case = TRUE)) %>%
    distinct(mp_name_id) %>% slice(1) %>% pull(mp_name_id)
  
  if (length(ref_mp_id) == 0) {
    ref_mp_id <- yearly_data %>%
      group_by(mp_name_id) %>%
      summarise(n = n()) %>%
      arrange(desc(n)) %>%
      slice(1) %>%
      pull(mp_name_id)
  }
  
  ref_votes <- yearly_data %>%
    filter(mp_name_id == ref_mp_id) %>%
    dplyr::select(voteno, ref_vote = vote_binary)
  
  agreement_matrix <- yearly_data %>%
    inner_join(ref_votes, by = "voteno") %>%
    mutate(agreement = ifelse(vote_binary == ref_vote, 1, 0)) %>%
    dplyr::select(mp_name_id, voteno, agreement) %>%
    distinct() %>%
    pivot_wider(names_from = voteno, values_from = agreement) %>%
    column_to_rownames("mp_name_id") %>%
    as.matrix()
  
  agreement_clean <- agreement_matrix[
    rowSums(is.na(agreement_matrix)) < ncol(agreement_matrix) * 0.5, 
    colSums(is.na(agreement_matrix)) < nrow(agreement_matrix) * 0.5
  ]
  agreement_clean[is.na(agreement_clean)] <- 0
  
  keep_items <- which(apply(agreement_clean, 2, var) > 0)
  agreement_clean <- agreement_clean[, keep_items, drop = FALSE]
  
  cat(paste0("  -> Fitting IRT model on all ", ncol(agreement_clean), " valid votes...\n"))
  
  irt_model <- tryCatch({
    ltm(agreement_clean ~ z1, IRT.param = TRUE)
  }, error = function(e) return(NULL))
  
  if (is.null(irt_model)) return(NULL)
  
  filename <- paste0("data/icc_plot_", year_select, ".png")
  png(filename, width = 800, height = 600)
  
  # Disable legend so it can plot 100+ items cleanly
  plot(irt_model, type = "ICC", legend = FALSE,
       main = paste0("ICC Plot: ", year_select,
                     " (Agreement with ", ref_mp_id, ")"))
  
  dev.off()
  cat(paste0("✓ Saved ICC plot: ", filename, "\n"))
}

# Run ICC example
if (length(avail_years) >= 2) {
  plot_icc_for_year(vote_data, avail_years[length(avail_years)-1], ref_mp_name = "Corbyn") 
} else {
  plot_icc_for_year(vote_data, latest_year, ref_mp_name = "Starmer")
}


# ============================================================================
# 6. MP Ideology Score Distribution (Dot Plot)
# ============================================================================

plot_score_distribution <- function(scores, target_year) {
  
  cat(paste0("\nGenerating Ideology Distribution Plot for ", target_year, "...\n"))
  
  year_scores <- scores %>%
    filter(year == target_year)
  
  if (nrow(year_scores) == 0) {
    cat(paste0("  ! No scores found for the year ", target_year, "\n"))
    return(NULL)
  }
  
  # Order MPs by score to create a diagonal line of ranked dots
  year_scores <- year_scores %>%
    arrange(z_score) %>%
    mutate(mp_factor = factor(mp_name_id, levels = mp_name_id))
  
  p <- ggplot(year_scores, aes(x = z_score, y = mp_factor, color = party_clean)) +
    geom_point(alpha = 0.8, size = 2) +
    scale_color_manual(values = c(
      "Conservative" = "#0087DC", "Labour" = "#E4003B", "Liberal Democrat" = "#FAA61A",
      "SNP" = "#FFF95D", "Green" = "#6AB023", "Reform UK" = "#12B6CF", "Other" = "#999999"
    ), na.value = "#999999") +
    labs(
      title = paste0("MP Ideology Scores Distribution (", target_year, ")"),
      x = "Ideology Score (Right ← → Left)",
      y = "MPs (Ranked by Score)",
      color = "Party"
    ) +
    theme_minimal() +
    theme(
      axis.text.y = element_blank(),  # Hide the hundreds of MP names for a clean plot
      axis.ticks.y = element_blank(),
      legend.position = "bottom"
    )
  
  print(p)
  
  filename <- paste0("data/ideology_distribution_", target_year, ".png")
  ggsave(filename, p, width = 10, height = 7, dpi = 300)
  cat("✓ Saved:", filename, "\n")
}

# Run distribution example (defaults to latest year if 2012 unavailable)
if (2012 %in% unique(scores_data$year)) {
  plot_score_distribution(scores_data, 2012)
} else if (nrow(scores_data) > 0) {
  cat("  ! 2012 data not found. Plotting latest year instead.\n")
  plot_score_distribution(scores_data, max(scores_data$year))
}

cat("\n✓ STEP 3 COMPLETE\n")