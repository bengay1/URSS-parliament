# Create Time Series Plot for Major Party Averages Over Time
cat("Creating time series plot for major party average ideology scores...\n")

# Calculate party average scores per year for major parties only
party_timeseries_data <- all_scores %>%
  left_join(combined_data %>% 
              distinct(mp_name_id, party_clean) %>%
              group_by(mp_name_id) %>%
              slice(1),  
            by = "mp_name_id") %>%
  filter(!is.na(party_clean)) %>%
  filter(party_clean %in% c("Conservative", "Labour", "Liberal Democrat")) %>%
  group_by(party_clean, year) %>%
  summarise(
    avg_z_score = mean(z_score, na.rm = TRUE),
    n_mps = n(),
    .groups = "drop"
  ) %>%
  filter(n_mps >= 5)  # Only include years with at least 5 MPs

# Define colors for major parties
party_colors <- c(
  "Conservative" = "#0087DC",    
  "Labour" = "#DC241f",           
  "Liberal Democrat" = "#FAA61A"  
)

# Create the time series plot for party averages
party_time_series_plot <- ggplot(party_timeseries_data, 
                                 aes(x = year, y = avg_z_score, 
                                     color = party_clean, group = party_clean)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  labs(
    title = "Major Party Ideology Scores Over Time",
    subtitle = "Based on IRT Scaling of Parliamentary Votes (1997-2025)",
    x = "Year",
    y = "Average Ideology Score (Left ← → Right)",
    color = "Party"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 12),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    legend.position = "bottom"
  ) +
  scale_x_continuous(breaks = seq(1997, 2025, 2)) +
  scale_color_manual(values = party_colors)

# Print the plot
print(party_time_series_plot)

# Save the plot
ggsave("major_party_ideology_time_series.png", party_time_series_plot, width = 14, height = 8, dpi = 300)
cat("Major party time series plot saved as 'major_party_ideology_time_series.png'\n")

# Show summary of the data
cat("\nParty data summary:\n")
party_summary <- party_timeseries_data %>%
  group_by(party_clean) %>%
  summarise(
    years = n(),
    first_year = min(year),
    last_year = max(year),
    overall_avg_score = mean(avg_z_score),
    min_avg_score = min(avg_z_score),
    max_avg_score = max(avg_z_score),
    .groups = "drop"
  ) %>%
  arrange(overall_avg_score)


print(party_summary)
