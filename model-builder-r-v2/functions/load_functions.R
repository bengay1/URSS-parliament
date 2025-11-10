# ============================================================================
# Helper Functions: Data Loading & Preparation
# ============================================================================
#
# This file contains utility functions for loading and preparing data
#

# String concatenation helper (for readability)
"%+%" <- function(x, y) paste0(x, y)

# Load data with error handling
safe_read <- function(file_path, skip_rows = 0) {
  tryCatch({
    read.delim(file_path, skip = skip_rows, stringsAsFactors = FALSE)
  }, error = function(e) {
    stop("Failed to read file: ", file_path, "\n  Error: ", e$message)
  })
}

# Check if year has available data
check_year_availability <- function(year) {
  available <- c(1997, 2001, 2005, 2010, 2015, 2017, 2019, 2024)
  year %in% available
}

# Get parliament period label
get_parliament_label <- function(year) {
  case_when(
    year == 1997 ~ "1997-2001",
    year == 2001 ~ "2001-2005",
    year == 2005 ~ "2005-2010",
    year == 2010 ~ "2010-2015",
    year == 2015 ~ "2015-2017",
    year == 2017 ~ "2017-2019",
    year == 2019 ~ "2019-2024",
    year == 2024 ~ "2024-2029",
    TRUE ~ NA_character_
  )
}

# Standardise party names
standardise_party <- function(party_raw) {
  case_when(
    grepl("Con|Conservative", party_raw) ~ "Conservative",
    grepl("Lab|Labour", party_raw) ~ "Labour",
    grepl("LD|Lib Dem", party_raw) ~ "Liberal Democrat",
    grepl("SNP", party_raw) ~ "SNP",
    grepl("PC|Plaid", party_raw) ~ "Plaid Cymru",
    grepl("Green", party_raw) ~ "Green",
    TRUE ~ "Other"
  )
}

# Convert vote codes to binary
vote_code_to_binary <- function(vote_code) {
  case_when(
    vote_code == 2 ~ 1,      # Aye
    vote_code == 4 ~ 0,      # No
    TRUE ~ NA_real_          # Missing
  )
}
