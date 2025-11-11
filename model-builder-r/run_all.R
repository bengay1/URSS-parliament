scripts <- c(
  "scripts/00_setup.R",
  "scripts/01_load_election_data.R",
  "scripts/02_calculate_ideology_scores.R",
  "scripts/03_analyse_ideology_change.R",
  "scripts/04_visualise_trends.R"
)

for (script in scripts) {
  cat("\n" %+% strrep("=", 80) %+% "\n")
  cat("Running:", script, "\n")
  cat(strrep("=", 80) %+% "\n")
  source(script)
}
