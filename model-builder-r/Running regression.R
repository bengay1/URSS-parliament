library(dplyr)

# Increasing ideology
positive_table_optimal <- most_positive_optimal %>%
  dplyr::select(MPName, slope, std_error, p_value, significance, years_in_parliament, career_span) %>%
  kable(
    caption = paste("Top MPs with Increasing Ideology Scores (", optimal_threshold, "+ Years Data)"),
    col.names = c("MP Name", "Slope", "Std Error", "P-value", "Signif", "Years", "Career Span")
  ) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed"))

# Decreasing ideology
negative_table_optimal <- most_negative_optimal %>%
  dplyr::select(MPName, slope, std_error, p_value, significance, years_in_parliament, career_span) %>%
  kable(
    caption = paste("Top MPs with Decreasing Ideology Scores (", optimal_threshold, "+ Years Data)"),
    col.names = c("MP Name", "Slope", "Std Error", "P-value", "Signif", "Years", "Career Span")
  ) %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed"))

# Save tables
tryCatch({
  save_kable(positive_table_optimal, paste0("most_positive_", optimal_threshold, "years.png"), zoom = 2)
  cat("Saved most_positive_", optimal_threshold, "years.png\n")
}, error = function(e) {
  cat("Error saving positive table:", e$message, "\n")
})

tryCatch({
  save_kable(negative_table_optimal, paste0("most_negative_", optimal_threshold, "years.png"), zoom = 2)
  cat("Saved most_negative_", optimal_threshold, "years.png\n")
}, error = function(e) {
  cat("Error saving negative table:", e$message, "\n")
})

cat("\nTop 15 MPs with Increasing Ideology Scores (", optimal_threshold, "+ years):\n")
print(most_positive_optimal)

cat("\nTop 15 MPs with Decreasing Ideology Scores (", optimal_threshold, "+ years):\n")
print(most_negative_optimal)

cat("\n=== ENHANCED REGRESSION ANALYSIS SUMMARY ===\n")
cat("Threshold: MPs with", optimal_threshold, "+ years of data\n")
cat("Total MPs analyzed:", nrow(mp_slopes_optimal), "\n")
cat("Average career span:", round(mean(mp_slopes_optimal$career_span), 1), "years\n")
cat("Average slope (ideology change):", round(mean(mp_slopes_optimal$slope, na.rm = TRUE), 4), "\n")
cat("SD of slopes:", round(sd(mp_slopes_optimal$slope, na.rm = TRUE), 4), "\n")
cat("Range of slopes:", round(min(mp_slopes_optimal$slope, na.rm = TRUE), 4), "to", 
    round(max(mp_slopes_optimal$slope, na.rm = TRUE), 4), "\n")

# Significance breakdown
sig_breakdown <- mp_slopes_optimal %>%
  count(significance) %>%
  mutate(percentage = round(n / nrow(mp_slopes_optimal) * 100, 1))

cat("\nSignificance levels:\n")
print(sig_breakdown)

# Significant changes
significant_changes_optimal <- mp_slopes_optimal %>% filter(p_value < 0.05)
sig_increases_optimal <- significant_changes_optimal %>% filter(slope > 0)
sig_decreases_optimal <- significant_changes_optimal %>% filter(slope < 0)

cat("\nMPs with statistically significant ideology changes (p < 0.05):", 
    nrow(significant_changes_optimal), "(", 
    round(nrow(significant_changes_optimal) / nrow(mp_slopes_optimal) * 100, 1), "%)\n")
cat("  - Significant increases:", nrow(sig_increases_optimal), "\n")
cat("  - Significant decreases:", nrow(sig_decreases_optimal), "\n")

# Save full results
write_csv(mp_slopes_optimal, paste0("mp_ideology_slopes_", optimal_threshold, "years.csv"))
cat("\nFull results saved to: mp_ideology_slopes_", optimal_threshold, "years.csv\n", sep = "")

if(require(ggplot2) && nrow(mp_slopes_optimal) > 1) {
  # Histogram of slopes
  slope_plot_optimal <- ggplot(mp_slopes_optimal, aes(x = slope)) +
    geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7, color = "white") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", size = 1) +
    geom_vline(xintercept = mean(mp_slopes_optimal$slope), linetype = "dashed", color = "blue", size = 1) +
    annotate("text", x = mean(mp_slopes_optimal$slope), y = Inf, 
             label = paste("Mean:", round(mean(mp_slopes_optimal$slope), 4)), 
             vjust = 2, hjust = -0.1, color = "blue") +
    labs(
      title = paste("Distribution of Ideology Change Slopes (", optimal_threshold, "+ Years Data)"),
      subtitle = paste(nrow(mp_slopes_optimal), "MPs |", 
                       round(mean(mp_slopes_optimal$career_span), 1), "year average career"),
      x = "Slope (Ideology Change per Year)",
      y = "Number of MPs"
    ) +
    theme_minimal(base_size = 12)
  
  ggsave(paste0("slope_distribution_", optimal_threshold, "years.png"), 
         slope_plot_optimal, width = 12, height = 8)
  cat("Slope distribution plot saved\n")
  
  # Top changing MPs
  top_changers_optimal <- bind_rows(
    most_positive_optimal %>% head(8) %>% mutate(direction = "Increasing"),
    most_negative_optimal %>% head(8) %>% mutate(direction = "Decreasing")
  )
  
  changer_plot_optimal <- ggplot(top_changers_optimal, 
                                 aes(x = reorder(MPName, slope), y = slope, fill = direction)) +
    geom_col() +
    coord_flip() +
    labs(
      title = paste("MPs with Most Extreme Ideology Changes (", optimal_threshold, "+ Years)"),
      x = "MP Name",
      y = "Slope (Change per Year)",
      fill = "Direction"
    ) +
    scale_fill_manual(values = c("Increasing" = "red", "Decreasing" = "blue")) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "top")
  
  ggsave(paste0("top_changing_mps_", optimal_threshold, "years.png"), 
         changer_plot_optimal, width = 12, height = 10)
  cat("Top changing MPs plot saved\n")
  
  # Career span vs slope
  career_plot <- ggplot(mp_slopes_optimal, 
                        aes(x = career_span, y = slope, color = significance, size = abs(slope))) +
    geom_point(alpha = 0.6) +
    geom_smooth(method = "lm", se = TRUE, color = "black", alpha = 0.3) +
    scale_color_manual(values = c("***" = "red", "**" = "orange", "*" = "yellow", 
                                  "." = "lightblue", "ns" = "gray")) +
    labs(
      title = paste("Ideology Change vs Career Length (", optimal_threshold, "+ Years)"),
      x = "Career Span (Years)",
      y = "Slope (Ideology Change per Year)",
      color = "Significance",
      size = "|Slope|"
    ) +
    theme_minimal()
  
  ggsave(paste0("career_vs_slope_", optimal_threshold, "years.png"), 
         career_plot, width = 12, height = 8)
  cat("Career vs slope plot saved\n")
}

cat("\n=== COMPARISON WITH ORIGINAL 5+ YEARS ANALYSIS ===\n")
cat("5+ years threshold:\n")
cat("  - MPs analyzed:", nrow(mp_slopes), "\n")
cat("  - Significant changes:", nrow(significant_changes), "(", 
    round(nrow(significant_changes) / nrow(mp_slopes) * 100, 1), "%)\n")
cat("  - Average slope:", round(mean(mp_slopes$slope, na.rm = TRUE), 4), "\n")

cat("\n", optimal_threshold, "+ years threshold:\n")
cat("  - MPs analyzed:", nrow(mp_slopes_optimal), "\n")
cat("  - Significant changes:", nrow(significant_changes_optimal), "(", 
    round(nrow(significant_changes_optimal) / nrow(mp_slopes_optimal) * 100, 1), "%)\n")
cat("  - Average slope:", round(mean(mp_slopes_optimal$slope, na.rm = TRUE), 4), "\n")

cat("\n=== EXTREME CASES ANALYSIS ===\n")

most_consistent <- mp_slopes_optimal %>%
  mutate(abs_slope = abs(slope)) %>%
  arrange(abs_slope) %>%
  head(10)

cat("\nTop 10 Most Ideologically Consistent MPs (smallest changes):\n")
print(most_consistent %>% dplyr::select(MPName, slope, p_value, years_in_parliament))

# MPs with most dramatic changes
most_dramatic <- mp_slopes_optimal %>%
  mutate(abs_slope = abs(slope)) %>%
  arrange(desc(abs_slope)) %>%
  head(10)

cat("\nTop 10 Most Ideologically Dramatic MPs (largest changes):\n")
print(most_dramatic %>% dplyr::select(MPName, slope, p_value, years_in_parliament))

cat("\n=== ANALYSIS BY CAREER ERA ===\n")

# Categorize MPs by when they started their careers
era_analysis <- mp_slopes_optimal %>%
  mutate(
    career_era = case_when(
      first_year < 2000 ~ "Pre-2000",
      first_year < 2010 ~ "2000s", 
      first_year < 2020 ~ "2010s",
      TRUE ~ "2020s"
    )
  ) %>%
  group_by(career_era) %>%
  summarise(
    n_mps = n(),
    mean_slope = mean(slope),
    sd_slope = sd(slope),
    prop_sig = sum(p_value < 0.05) / n(),
    .groups = "drop"
  )

cat("Ideology changes by career era:\n")
print(era_analysis)


cat("\n=== ANALYSIS WITH HIGHER THRESHOLD COMPLETE ===\n")
