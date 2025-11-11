# UK Parliament Ideology Analysis

Analysis of UK Member of Parliament (MP) ideological positions using Item Response Theory (IRT) on parliamentary voting patterns (1997-2025).

## Overview

This collection of R scripts analyses voting data from the UK Parliament using IRT scaling. It positions MPs on a left-right ideological spectrum based on their voting agreement with reference MPs. The analysis spans 8 parliamentary periods from 1997 to 2025.

## Key Features

- **IRT Scaling**: Uses 2-parameter logistic (2PL) IRT model to estimate MP ideology scores
- **Multi-period Analysis**: Processes voting data across 1997, 2001, 2005, 2010, 2015, 2017, 2019, 2024
- **Trend Analysis**: Tracks ideological shifts within individual MP careers
- **Visualisation**: Generates time series plots of party and MP ideology trends
- **Regression Analysis**: Identifies MPs with statistically significant ideological shifts

## Quick Start

```r
# Run all analyses in order
source("scripts/00_setup.R")          # Load libraries & functions
source("scripts/01_load_election_data.R")  # Download & prepare data
source("scripts/02_calculate_ideology_scores.R")  # Calculate IRT scores
source("scripts/03_analyse_ideology_change.R")    # Identify trends
source("scripts/04_visualise_trends.R")           # Create visualisations
```

See **QUICK_START.md** for detailed instructions.

## Dependencies

- `tidyverse` (>= 1.3.0)
- `ltm` (>= 1.2.0) - Item Response Theory models
- `lubridate` (>= 1.8.0) - Date handling
- `dplyr` (>= 1.0.0) - Data manipulation
- `ggplot2` (>= 3.3.0) - Visualisation
- `knitr` (>= 1.30) - R Markdown support

## Data Source

- **Public Whip** (https://www.publicwhip.org.uk/): UK parliamentary voting records in standardised format
- Data files: `votematrix-YEAR.txt` (MP metadata) and `votematrix-YEAR.dat` (voting matrix)

## Quick Start

### Load & Analyse Voting Data

```r
library(tidyverse)
library(ltm)

# Load election data across multiple parliaments
election_years <- c(1997, 2001, 2005, 2010, 2015, 2017, 2019, 2024)
all_parliaments <- map_dfr(election_years, load_election_data)

# Calculate IRT ideology scores for each year
all_scores <- map_dfr(
  unique(all_parliaments$year),
  ~calculate_yearly_scores(.x, all_parliaments)
)

# Save results
write_csv(all_scores, "mp_ideology_scores.csv")
```

### Visualise Party Trends

```r
# Plot major party ideological trajectories
party_timeseries_data <- all_scores %>%
  left_join(combined_data %>% distinct(mp_name_id, party_clean), by = "mp_name_id") %>%
  filter(party_clean %in% c("Conservative", "Labour", "Liberal Democrat")) %>%
  group_by(party_clean, year) %>%
  summarise(
    avg_z_score = mean(z_score, na.rm = TRUE),
    n_mps = n(),
    .groups = "drop"
  ) %>%
  filter(n_mps >= 5)

ggplot(party_timeseries_data, aes(x = year, y = avg_z_score, color = party_clean)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  labs(title = "UK Party Ideology Scores (1997-2025)",
       x = "Year", y = "Average Ideology Score",
       color = "Party") +
  theme_minimal()
```

### Analyse Ideological Change

```r
# Run regression to identify MPs with significant ideological shifts
mp_slopes <- all_scores %>%
  group_by(mp_name_id) %>%
  summarise(
    n_years = n(),
    slope = coef(lm(z_score ~ year))[2],
    p_value = summary(lm(z_score ~ year))$coef[2, 4],
    .groups = "drop"
  ) %>%
  filter(n_years >= 5)

# Find MPs shifting rightwards or leftwards significantly
significant_changes <- mp_slopes %>% filter(p_value < 0.05)
```

## Methodology

### IRT Model

The analysis uses a 2-parameter logistic (2PL) Item Response Theory model:

**Model equation:**
```
P(yij = 1 | θi, aj, bj) = exp(aj(θi - bj)) / (1 + exp(aj(θi - bj)))
```

Where:
- **θi**: MP ideology score (left-right spectrum, θ ≈ N(0,1))
- **aj**: Item discrimination (how well vote distinguishes ideology)
- **bj**: Item difficulty (average agreement threshold)
- **yij**: MP i's vote on division j (1=agreed with reference, 0=disagreed)

**Scoring interpretation:**
- **Positive scores**: MPs agreeing with left-wing reference MPs → **LEFT ideology**
- **Negative scores**: MPs disagreeing with left-wing reference MPs → **RIGHT ideology**

**Reference MPs** (selected in order):
1. Jeremy Corbyn (Labour left)
2. Nadia Whittome (Labour left)
3. Diane Abbott (Labour left)
4. John McDonnell (Labour left)
5. Keir Starmer (Labour centre)

### Data Processing Pipeline

```
01_load_election_data.R
  ├─ Download from publicwhip.org.uk (or local 2019 file)
  ├─ Filter: Remove Lords, unopposed votes, missing data
  ├─ Standardise party names & vote codes
  ├─ Deduplicate same-named MPs
  └─ Output: combined_data_raw.csv

02_calculate_ideology_scores.R
  ├─ For each year:
  │  ├─ Select reference MP (with sufficient votes)
  │  ├─ Create binary agreement matrix (MPs × votes)
  │  ├─ Filter uninformative votes (< 5% or > 95% agreement)
  │  ├─ Fit 2PL IRT model using ltm package (EM algorithm)
  │  └─ Extract factor scores (θ)
  └─ Output: all_scores.csv

03_analyse_ideology_change.R
  ├─ For each MP with 5+ years data:
  │  ├─ Fit linear regression: z_score ~ year
  │  ├─ Extract slope (annual change), p-value, significance
  │  └─ Identify significant shifters
  └─ Output: mp_slopes_5years.csv

04_visualise_trends.R
  ├─ Party-level trends (Conservative, Labour, Lib Dem)
  ├─ Individual MP trajectories
  ├─ Score distributions by year
  └─ Output: PNG files + CSV summaries
```

### Output Files

Located in `data/` directory:

- **combined_data_raw.csv**: Cleaned voting records
- **all_scores.csv**: IRT ideology scores (z_scores)
- **mp_slopes_5years.csv**: Regression results (slopes, p-values)
- **most_positive_mps.csv**: Top rightward shifters
- **most_negative_mps.csv**: Top leftward shifters
- **party_summary.csv**: Party-level statistics
- **yearly_statistics.csv**: Descriptive stats by year
- **\*.png**: Visualisations (party trends, distributions, MP trajectories)

## Project Structure

```
model-builder-r/
├── scripts/
│   ├── 00_setup.R                      # Load libraries & functions
│   ├── 01_load_election_data.R         # Download & prepare data
│   ├── 02_calculate_ideology_scores.R  # Fit IRT models
│   ├── 03_analyse_ideology_change.R    # Regression analysis
│   └── 04_visualise_trends.R           # Create visualisations
├── functions/
│   ├── load_functions.R                # Data loading helpers
│   ├── irt_functions.R                 # IRT & regression functions
│   └── plot_functions.R                # Plotting helpers
├── data/                               # Output directory (created automatically)
├── README.md                           # This file
├── QUICK_START.md                      # Step-by-step guide
├── R_BEST_PRACTICES.md                 # Style guide
├── R_STANDARDS_COMPLIANCE.md           # Full analysis report
└── .gitignore
```

## Output Examples

- `ideology_scores_final.csv`: Complete IRT scores for all MPs and years
- `mp_ideology_slopes_*years.csv`: Regression results with slope coefficients
- `major_party_ideology_time_series.png`: Party trends visualisation
- `slope_distribution_*.png`: Distribution of ideological change rates

## Known Limitations

- **Reference MP bias**: Scores reflect alignment with reference MP; different reference changes scaling
- **Missing votes**: MPs absent from parliament don't contribute to scaling
- **Vote quality**: Assumes all votes equally informative; actual political salience varies
- **Party changes**: MPs changing parties treated as single entity (identified by name+year)
- **2019 data**: Local file path required; online source limited

## Citation

If using this analysis, please cite:
- Public Whip data source: https://www.publicwhip.org.uk/
- IRT methodology: Battari et al. (2015) DW-NOMINATE or standard IRT references

## Licence

[Specify licence - GPL-3, MIT, etc.]

## Contributing

Issues & pull requests welcome. Please follow R style guide:
- Use `<-` for assignment
- Function names: `snake_case`, variable names: `snake_case`
- Maximum line length: 80 characters

## Authors

Benjamin Gay (original author), URSS project