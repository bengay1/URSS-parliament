# Quick Start Guide: UK Parliament Ideology Analysis

Run the analysis step-by-step using these simple instructions.

## Prerequisites

Install required R packages (run once):

```r
packages <- c("tidyverse", "ltm", "lubridate", "dplyr", "ggplot2")
install.packages(packages)
```

Or paste this into R console:
```r
install.packages(c("tidyverse", "ltm", "lubridate", "dplyr", "ggplot2"))
```

## Running the Analysis

Execute scripts in order by copy-pasting into R console or RStudio:

### Step 1: Setup (2 minutes)

```r
source("scripts/00_setup.R")
```

**What it does:**
- Loads all required libraries
- Sources helper functions
- Creates `data/` directory

**Output:** Console message "✓ Setup complete"

---

### Step 2: Load & Prepare Data (5-10 minutes)

```r
source("scripts/01_load_election_data.R")
```

**What it does:**
- Downloads voting data from Public Whip for 1997-2024
- Cleans and standardises data
- Removes duplicate MPs with same name
- Saves cleaned data

**Output:**
- `data/combined_data_raw.csv` (cleaned voting records)
- Console summary showing data dimensions

**Note:** First run may take longer as it downloads from the internet. Subsequent runs will re-download fresh data.

---

### Step 3: Calculate Ideology Scores (15-30 minutes)

```r
source("scripts/02_calculate_ideology_scores.R")
```

**What it does:**
- Fits IRT models for each year
- Calculates MP ideology scores
- Generates summary statistics
- Creates quick visualisations

**Outputs:**
- `data/all_scores.csv` (main results with z-scores)
- `data/score_summary.csv` (summary by year)
- `data/score_distribution_all.png` (histogram)
- `data/party_timeseries.png` (party trends)

**Note:** This is the most time-consuming step (10-30 min depending on computer). IRT models may take several attempts per year, which is normal.

---

### Step 4: Analyse Ideological Change (5 minutes)

```r
source("scripts/03_analyse_ideology_change.R")
```

**What it does:**
- Runs linear regression for each MP
- Identifies MPs with significant ideological shifts
- Creates tables of "shifters" (left and right)
- Generates visualisations

**Outputs:**
- `data/mp_slopes_5years.csv` (main results: slopes + p-values)
- `data/most_positive_mps.csv` (MPs shifting rightward)
- `data/most_negative_mps.csv` (MPs shifting leftward)
- `data/slope_histogram.png` (distribution of slopes)
- `data/career_vs_slope.png` (career length vs change)
- `data/top_changing_mps.png` (most extreme shifters)

---

### Step 5: Visualise Trends (5 minutes)

```r
source("scripts/04_visualise_trends.R")
```

**What it does:**
- Creates party-level trend analysis
- Plots individual MP trajectories
- Generates distribution plots by year
- Produces summary statistics

**Outputs:**
- `data/party_ideology_trends.png` (Conservative, Labour, Lib Dem over time)
- `data/selected_mp_trends.png` (featured MPs: Blair, Cameron, Corbyn, etc.)
- `data/distribution_by_year.png` (box plots of score distributions)
- `data/party_summary.csv` (party-level statistics)
- `data/yearly_statistics.csv` (year-by-year summary)

---

## Complete Analysis (One Command)

Run all scripts sequentially:

```r
source("scripts/00_setup.R")
source("scripts/01_load_election_data.R")
source("scripts/02_calculate_ideology_scores.R")
source("scripts/03_analyse_ideology_change.R")
source("scripts/04_visualise_trends.R")
```

Or create a loop script `run_all.R`:

```r
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
```

Then run:
```r
source("run_all.R")
```

---

## Exploring Results

After completing all scripts, examine the results:

### View Scores
```r
library(tidyverse)

# Load scores
all_scores <- read_csv("data/all_scores.csv")

# Top 10 leftward-oriented MPs in 2024 (highest positive scores)
all_scores %>%
  filter(year == 2024) %>%
  arrange(desc(z_score)) %>%
  head(10)

# Top 10 rightward-oriented MPs in 2024 (lowest/most negative scores)
all_scores %>%
  filter(year == 2024) %>%
  arrange(z_score) %>%
  head(10)
```

### View Ideological Changes
```r
# Load slopes
mp_slopes <- read_csv("data/mp_slopes_5years.csv")

# MPs shifting leftward most significantly (positive slope = increasing score)
mp_slopes %>%
  filter(p_value < 0.05, slope > 0) %>%
  arrange(desc(slope))

# MPs shifting rightward most significantly (negative slope = decreasing score)
mp_slopes %>%
  filter(p_value < 0.05, slope < 0) %>%
  arrange(slope)
```

### View Party Trends
```r
party_summary <- read_csv("data/party_summary.csv")
print(party_summary)
```

---

## Troubleshooting

### Error: "File not found"
- Ensure you're running scripts from the project root directory
- Check that `functions/` directory exists with helper files
- Use `getwd()` to check current directory; use `setwd()` if needed

### Error: "Could not download from publicwhip.org.uk"
- Check internet connection
- For 2019 data, ensure local file path is correct (see script 01)
- Try running again; servers may be temporarily unavailable

### IRT Model Fails
- This is normal; script tries multiple reference MPs
- If all reference MPs fail for a year, that year is skipped
- Requires minimum 10 informative votes and 10 MPs

### Plots not displaying
- Plots are automatically saved to `data/*.png`
- Use `plot(ggplot_object)` to display previously created plots
- Check file names in console output

### Computer running slowly
- Step 2 (data loading) is fastest (5-10 min)
- Step 3 (IRT calculation) is slowest (15-30 min)
- Close other applications to speed up
- Check console for progress messages with ✓ symbols

---

## Output Summary

After running all scripts, `data/` folder contains:

| File | Size | Description |
|------|------|-------------|
| combined_data_raw.csv | ~50 MB | Cleaned voting records |
| all_scores.csv | ~5 MB | IRT ideology scores |
| mp_slopes_5years.csv | ~1 MB | Regression results |
| most_positive_mps.csv | <100 KB | Rightward shifters |
| most_negative_mps.csv | <100 KB | Leftward shifters |
| party_summary.csv | <50 KB | Party statistics |
| yearly_statistics.csv | <50 KB | Year summaries |
| *.png files | ~200 KB each | Visualisations (8 files) |

**Total:** ~100 MB of analysis outputs

---

## Next Steps

- **Understand methodology:** See README.md section "Methodology"
- **Follow best practices:** See R_BEST_PRACTICES.md for code style
- **Full compliance report:** See R_STANDARDS_COMPLIANCE.md for detailed analysis
- **Modify analysis:** Edit scripts to change thresholds, reference MPs, or years
- **Extend analysis:** Use helper functions in `functions/` to create custom analyses

---

## Questions & Issues

- Check R_STANDARDS_COMPLIANCE.md for limitations
- Review function documentation in `functions/*.R` files
- Examine script comments for technical details
- Original data from: https://www.publicwhip.org.uk/
