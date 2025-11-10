# ============================================================================
# Load & Prepare UK Parliamentary Voting Data
# ============================================================================
#
# Purpose:
#   Downloads voting data from Public Whip for multiple parliaments (1997-2024)
#   Cleans, standardises, and combines data for analysis
#
# Outputs:
#   - combined_data: Processed voting data in long format
#   - Saved to: data/combined_data_raw.csv
#
# Duration: ~5-10 minutes (downloads from internet)
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

source("scripts/00_setup.R")

cat("STEP 1: LOAD & PREPARE PARLIAMENTARY VOTING DATA\n")

# Define election years to analyse
election_years <- c(1997, 2001, 2005, 2010, 2015, 2017, 2019, 2024)

# ============================================================================
# 1. Load election data from Public Whip
# ============================================================================

cat("Loading election data from Public Whip...\n")

load_election_data <- function(election_year) {

  # 2019 data needs local file; others from publicwhip.org.uk
  if (election_year == 2019) {
    mps_file <- "../read-parliament-python/output/votematrix-2019.txt"
    vm_file <- "../read-parliament-python/output/votematrix-2019.dat"
  } else {
    mps_file <- paste0("https://www.publicwhip.org.uk/data/votematrix-", election_year, ".txt")
    vm_file <- paste0("https://www.publicwhip.org.uk/data/votematrix-", election_year, ".dat")
  }

  cat("  Fetching", election_year, "data...\n")

  mps <- read.delim(mps_file, skip = 19)
  vm <- read.delim(vm_file,
                   quote = "",
                   na.strings = c("", "NA", "-9"),
                   stringsAsFactors = FALSE)

  # Standardise date format
  vm <- vm %>%
    mutate(date = as.Date(substr(as.character(date), 1, 10)))

  # Convert mpid columns to character (for pivot_longer)
  vm <- vm %>%
    mutate(across(starts_with("mpid"), as.character))

  # Pivot vote matrix to long format: each row = one MP's vote on one division
  vm_long <- vm %>%
    pivot_longer(cols = starts_with("mpid"),
                 names_to = "mpid",
                 values_to = "vote_code") %>%
    mutate(
      mpid = as.integer(sub("mpid", "", mpid)),
      vote_code = as.integer(vote_code)
    ) %>%
    # Join with MP metadata (name, party, etc.)
    left_join(mps %>% rename(mpid = 1), by = "mpid") %>%
    mutate(
      election_period = election_year,
      year = lubridate::year(date),
      parliament = case_when(
        election_year == 1997 ~ "1997-2001",
        election_year == 2001 ~ "2001-2005",
        election_year == 2005 ~ "2005-2010",
        election_year == 2010 ~ "2010-2015",
        election_year == 2015 ~ "2015-2017",
        election_year == 2017 ~ "2017-2019",
        election_year == 2019 ~ "2019-2024",
        election_year == 2024 ~ "2024-2029"
      )
    )

  return(vm_long)
}

all_parliaments <- map_dfr(election_years, load_election_data, .progress = TRUE)

cat("\n✓ Loaded", nrow(all_parliaments), "voting records\n")
cat("  Years covered:", toString(sort(unique(all_parliaments$year))), "\n")

# ============================================================================
# 2. Clean & standardise data
# ============================================================================

cat("\nCleaning & standardising voting data...\n")

combined_data <- all_parliaments %>%
  # Remove: Lords votes, unopposed votes (code 3), missing data (code -9)
  filter(!vote_code %in% c(-9, 3), !grepl("\\[Lords\\]", Bill)) %>%
  mutate(
    # Convert vote codes to binary (1=Aye, 0=No)
    # Codes: 1=tellaye→2, 2=aye, 4=no, 5=tellno→4
    vote_binary = case_when(
      vote_code == 2 ~ 1,    # Aye
      vote_code == 4 ~ 0,    # No
      TRUE ~ NA_real_        # All others = missing
    ),

    # Clean name fields
    firstname_clean = str_squish(firstname),
    surname_clean = str_squish(surname),
    mp_name_id = paste(firstname_clean, surname_clean),

    # Standardise party names (handle variations)
    party_clean = case_when(
      grepl("Con|Conservative", party) ~ "Conservative",
      grepl("Lab|Labour", party) ~ "Labour",
      grepl("LD|Lib Dem", party) ~ "Liberal Democrat",
      grepl("SNP", party) ~ "SNP",
      grepl("PC|Plaid", party) ~ "Plaid Cymru",
      grepl("Green", party) ~ "Green",
      TRUE ~ "Other"
    )
  ) %>%
  filter(!is.na(year)) %>%
  dplyr::select(mp_name_id, firstname = firstname_clean, surname = surname_clean,
         party_clean, year, parliament, vote_binary, voteno, date, Bill)

cat("✓ Cleaned to", nrow(combined_data), "records\n")
cat("  Parties:", toString(sort(unique(combined_data$party_clean))), "\n")

# ============================================================================
# 3. Deduplicate: Handle MPs with same name in same year
# ============================================================================

cat("\nRemoving duplicate MP-vote combinations...\n")

# Fast-path deduplication: only apply expensive table() logic to actual duplicates
duplicates <- combined_data %>%
  group_by(mp_name_id, year, voteno) %>%
  filter(n() > 1) %>%
  ungroup() %>%
  group_by(mp_name_id, year, voteno) %>%
  summarize(
    # If multiple MPs with same name vote on same division, take majority vote
    vote_binary = ifelse(
      sum(vote_binary == 1, na.rm = TRUE) >= sum(vote_binary == 0, na.rm = TRUE),
      1, 0
    ),
    firstname = first(firstname),
    surname = first(surname),
    # If same-named MPs have different parties, take most common
    party_clean = names(sort(table(party_clean), decreasing = TRUE))[1],
    parliament = first(parliament),
    date = first(date),
    Bill = first(Bill),
    .groups = "drop"
  )

# Keep non-duplicates as-is (much faster than processing through expensive logic)
non_duplicates <- combined_data %>%
  group_by(mp_name_id, year, voteno) %>%
  filter(n() == 1) %>%
  ungroup()

# Combine both sets
combined_data <- bind_rows(non_duplicates, duplicates)

cat("✓ Deduplicated to", nrow(combined_data), "unique votes\n")

# Verify no duplicate MP names within same year
name_year_counts <- combined_data %>%
  group_by(mp_name_id, year) %>%
  summarise(n_votes = n(), .groups = "drop") %>%
  group_by(mp_name_id, year) %>%
  summarise(n_occurrences = n(), .groups = "drop")

duplicate_names <- name_year_counts %>% filter(n_occurrences > 1)
if (nrow(duplicate_names) > 0) {
  cat("\n⚠ WARNING: Found", nrow(duplicate_names), "MP names with duplicates:\n")
  print(duplicate_names %>% head(10))
} else {
  cat("✓ No duplicate MP names in same year\n")
}

# ============================================================================
# 4. Save cleaned data
# ============================================================================

readr::write_csv(combined_data, "data/combined_data_raw.csv")
cat("\n✓ Saved to: data/combined_data_raw.csv\n")

# Quick summary

cat("SUMMARY\n")
cat("Total MPs:", length(unique(combined_data$mp_name_id)), "\n")
cat("Total votes:", length(unique(combined_data$voteno)), "\n")
cat("Years:", toString(sort(unique(combined_data$year))), "\n")
cat("Data ready for IRT analysis.\n")
