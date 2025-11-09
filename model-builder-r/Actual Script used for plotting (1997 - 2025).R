# Load libraries

library(tidyverse)
library(ltm)
library(lubridate)
library(dplyr)


# Define election years

election_years <- c(1997, 2001, 2005, 2010, 2015, 2017, 2019, 2024)


# Function to load election data

load_election_data <- function(election_year) {
  
  if(election_year == 2019) {
    mps_file <- "C:/Users/benau/Downloads/votematrix-2019.txt"
    vm_file <- "C:/Users/benau/Downloads/votematrix-2019.dat"
  } else {
    mps_file <- paste0("https://www.publicwhip.org.uk/data/votematrix-", election_year, ".txt")
    vm_file <- paste0("https://www.publicwhip.org.uk/data/votematrix-", election_year, ".dat")
  }
  
  mps <- read.delim(mps_file, skip = 19)
  
  vm <- read.delim(vm_file,
                   quote = "",
                   na.strings = c("", "NA", "-9"),
                   stringsAsFactors = FALSE)
  
  vm <- vm %>%
    mutate(date = as.Date(substr(as.character(date), 1, 10)))
  
  vm <- vm %>%
    mutate(across(starts_with("mpid"), as.character))
  
  # Pivot vote matrix to long format
  vm_long <- vm %>%
    pivot_longer(cols = starts_with("mpid"),
                 names_to = "mpid",
                 values_to = "vote_code") %>%
    mutate(
      mpid = as.integer(sub("mpid", "", mpid)),
      vote_code = as.integer(vote_code)
    ) %>%
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


# Load all parliaments

cat("Loading election data...\n")
all_parliaments <- map_dfr(election_years, load_election_data, .progress = TRUE)


# Prepare combined data

combined_data <- all_parliaments %>%
  filter(!vote_code %in% c(-9, 3), !grepl("\\[Lords\\]", Bill)) %>%
  mutate(
    vote_binary = case_when(
      vote_code == 2 ~ 1,   # Aye
      vote_code == 4 ~ 0,   # No
      TRUE ~ NA_real_
    ),
    # Create MP identifier
  
    firstname_clean = str_squish(firstname),
    surname_clean = str_squish(surname),
    mp_name_id = paste(firstname_clean, surname_clean),
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
  dplyr::select(mp_name_id, firstname = firstname_clean, surname = surname_clean, party_clean, year, parliament, vote_binary, voteno)

# Remove duplicates
cat("Removing duplicate MP-vote combinations and combining same-name MPs...\n")
combined_data <- combined_data %>%
  group_by(mp_name_id, year, voteno) %>%
  summarize(
    # If multiple MPs with same name vote on same division, take the most common vote
    vote_binary = ifelse(sum(vote_binary == 1, na.rm = TRUE) >= sum(vote_binary == 0, na.rm = TRUE), 1, 0),
    firstname = first(firstname),
    surname = first(surname),
    # If same-named MPs have different parties, take the most common party
    party_clean = names(sort(table(party_clean), decreasing = TRUE))[1],
    parliament = first(parliament),
    .groups = "drop"
  )

# Verify
name_year_counts <- combined_data %>%
  group_by(mp_name_id, year) %>%
  summarise(n_votes = n(), .groups = "drop") %>%
  group_by(mp_name_id, year) %>%
  summarise(n_occurrences = n(), .groups = "drop")

duplicate_names <- name_year_counts %>% filter(n_occurrences > 1)
if(nrow(duplicate_names) > 0) {
  cat("WARNING: Still found", nrow(duplicate_names), "MP names with duplicates in same year\n")
  print(duplicate_names %>% head(10))
} else {
  cat("SUCCESS: No duplicate MP names in same year after combining\n")
}

# Check if Jeremy Corbyn exists in the data
corbyn_check <- combined_data %>% 
  filter(mp_name_id == "Jeremy Corbyn") %>%
  distinct(year, mp_name_id, party_clean)

if(nrow(corbyn_check) > 0) {
  cat("Jeremy Corbyn found in data for years:", toString(unique(corbyn_check$year)), "\n")
  cat("Parties:", toString(unique(corbyn_check$party_clean)), "\n")
} else {
  cat("WARNING: Jeremy Corbyn not found in combined data\n")
  # Check for similar names
  similar_names <- combined_data %>% 
    filter(grepl("Jeremy", firstname) & grepl("Corbyn", surname)) %>%
    distinct(mp_name_id, year)
  if(nrow(similar_names) > 0) {
    cat("Similar names found:\n")
    print(similar_names)
  }
}

available_years <- sort(unique(combined_data$year))
cat("Available years:", toString(available_years), "\n")


# scoring function with ALTERNATE REFERENCE MPs
calculate_yearly_scores <- function(yr, data) {
  
  cat("\n=== Processing year:", yr, "===\n")
  yearly_data <- data %>% filter(year == yr)
  if(nrow(yearly_data) == 0) {
    cat("  No data for year", yr, "\n")
    return(NULL)
  }
  
  # Store MP info
  mp_info <- yearly_data %>% 
    distinct(mp_name_id, firstname, surname, party_clean)
  
  cat("  Total unique MP names:", nrow(mp_info), "\n")
  cat("  Party distribution:\n")
  print(table(mp_info$party_clean))
  
  # Remove uninformative votes (0 or 100% agreement)
  vote_variance <- yearly_data %>%
    group_by(voteno) %>%
    summarize(p = mean(vote_binary, na.rm = TRUE), .groups = "drop") %>%
    filter(p > 0.05 & p < 0.95)
  
  yearly_data <- yearly_data %>% filter(voteno %in% vote_variance$voteno)
  if(nrow(yearly_data) == 0) {
    cat("  No informative votes after filtering\n")
    return(NULL)
  }
  
  cat("  Informative votes:", length(unique(yearly_data$voteno)), "\n")
  
  # Function to try IRT with a given reference MP
  try_irt_with_reference <- function(ref_firstname, ref_surname, yearly_data, mp_info) {
    ref_name_id <- paste(ref_firstname, ref_surname)
    
    # Find MP with matching name
    potential_ref <- mp_info %>% 
      filter(mp_name_id == ref_name_id)
    
    if(nrow(potential_ref) == 0) {
      cat("  Reference MP not found:", ref_firstname, ref_surname, "\n")
      return(list(success = FALSE, message = "MP not found"))
    }
    
    cat("  Trying reference MP:", ref_firstname, ref_surname, "\n")
    cat("    Party:", potential_ref$party_clean[1], "\n")
    
    candidate_mp_id <- potential_ref$mp_name_id[1]
    candidate_votes <- yearly_data %>% 
      filter(mp_name_id == candidate_mp_id) %>%
      filter(!is.na(vote_binary))
    
    cat("    Total votes:", nrow(candidate_votes), "\n")
    cat("    Unique vote values:", toString(unique(candidate_votes$vote_binary)), "\n")
    
    # Lower threshold for Jeremy Corbyn
    min_votes_needed <- ifelse(ref_firstname == "Jeremy" && ref_surname == "Corbyn", 5, 10)
    
    if(nrow(candidate_votes) < min_votes_needed || length(unique(candidate_votes$vote_binary)) <= 1) {
      cat("    REJECTED - insufficient votes or no variance\n")
      return(list(success = FALSE, message = "Insufficient votes or no variance"))
    }
    
    reference_votes <- candidate_votes %>% 
      distinct(voteno, reference_vote = vote_binary)
    
    if(nrow(reference_votes) < 5) {
      cat("    REJECTED - insufficient votes after filtering\n")
      return(list(success = FALSE, message = "Insufficient votes after filtering"))
    }
    
    # Build agreement matrix
    agreement_matrix <- yearly_data %>%
      inner_join(reference_votes, by = "voteno") %>%
      filter(!is.na(vote_binary)) %>%
      mutate(agreement = as.integer(vote_binary == reference_vote)) %>%
      dplyr::select(mp_name_id, voteno, agreement) %>%
      group_by(mp_name_id, voteno) %>%
      slice(1) %>%
      ungroup()
    
    # Pivot to wide format
    agreement_matrix_wide <- agreement_matrix %>%
      pivot_wider(
        names_from = voteno, 
        values_from = agreement, 
        values_fill = 0
      )
    
    if(ncol(agreement_matrix_wide) < 2) {
      cat("    REJECTED - pivoting failed\n")
      return(list(success = FALSE, message = "Pivoting failed"))
    }
    
    # Convert to matrix
    agreement_matrix_final <- agreement_matrix_wide %>%
      column_to_rownames("mp_name_id") %>%
      as.matrix()
    
    cat("    Agreement matrix dimensions:", dim(agreement_matrix_final), "\n")
    
    # Clean data
    agreement_matrix_final[is.na(agreement_matrix_final)] <- 0
    agreement_matrix_final <- ifelse(agreement_matrix_final > 0.5, 1, 0)
    
    # Remove items with no variance
    item_variance <- apply(agreement_matrix_final, 2, function(x) {
      var_x <- var(x)
      !is.na(var_x) && var_x > 0
    })
    
    keep_items <- which(item_variance)
    if(length(keep_items) < 5) {
      cat("    REJECTED - insufficient items with variance\n")
      return(list(success = FALSE, message = "Insufficient items with variance"))
    }
    
    agreement_matrix_final <- agreement_matrix_final[, keep_items, drop = FALSE]
    cat("    After item filtering:", dim(agreement_matrix_final), "\n")
    
    # Remove MPs with insufficient data
    mp_keep <- apply(agreement_matrix_final, 1, function(x) {
      var_x <- var(x)
      !is.na(var_x) && var_x > 0
    })
    
    keep_mps <- which(mp_keep)
    if(length(keep_mps) < 10) {
      cat("    REJECTED - insufficient MPs with variance\n")
      return(list(success = FALSE, message = "Insufficient MPs with variance"))
    }
    
    agreement_matrix_final <- agreement_matrix_final[keep_mps, , drop = FALSE]
    cat("    Final matrix dimensions:", dim(agreement_matrix_final), "\n")
    
    # Try IRT
    max_attempts <- 3
    for(attempt in 1:max_attempts) {
      cat("    IRT attempt", attempt, "of", max_attempts, "...\n")
      
      tryCatch({
        agreement_df <- as.data.frame(agreement_matrix_final)
        
        # Verify data is binary
        if(any(!unlist(agreement_df) %in% c(0, 1))) {
          stop("Data contains non-binary values")
        }
        
        model <- ltm(agreement_df ~ z1, 
                     IRT.param = TRUE,
                     control = list(
                       iter.em = 30,
                       iter.qN = 100,
                       GHk = 7
                     ))
        
        factor_scores <- factor.scores(model, resp.patterns = agreement_df)
        
        result <- tibble(
          mp_name_id = rownames(agreement_matrix_final),
          z_score = as.numeric(factor_scores$score.dat$z1),
          year = yr,
          reference_mp = ref_name_id,
          method = "IRT"
        )
        
        # Check for reasonable scores
        score_sd <- sd(result$z_score, na.rm = TRUE)
        if(score_sd < 10 && score_sd > 0.1) {
          cat("    IRT successful on attempt", attempt, "(SD =", round(score_sd, 3), ")\n")
          return(list(success = TRUE, scores = result))
        } else {
          stop(paste("Extreme scores (SD =", round(score_sd, 3), ")"))
        }
        
      }, error = function(e) {
        cat("    IRT failed on attempt", attempt, ":", e$message, "\n")
        if(attempt == max_attempts) {
          return(list(success = FALSE, message = paste("IRT failed:", e$message)))
        }
      })
    }
    
    return(list(success = FALSE, message = "All IRT attempts failed"))
  }
  
  # Try reference MPs in order
  reference_candidates <- list(
    c("Jeremy", "Corbyn"),
    c("Nadia", "Whittome"),
    c("Diane", "Abbott"),
    c("John", "McDonnell"),
    c("Keir", "Starmer")
  )
  
  for(ref_candidate in reference_candidates) {
    ref_firstname <- ref_candidate[1]
    ref_surname <- ref_candidate[2]
    
    result <- try_irt_with_reference(ref_firstname, ref_surname, yearly_data, mp_info)
    
    if(result$success) {
      cat("  SUCCESS with reference MP:", ref_firstname, ref_surname, "\n")
      cat("  Successfully scored", nrow(result$scores), "MPs\n")
      return(result$scores)
    } else {
      cat("  FAILED with reference MP:", ref_firstname, ref_surname, "-", result$message, "\n")
    }
  }
  
  cat("  All reference MPs failed for year", yr, "\n")
  return(NULL)
}


# Calculate scores 

cat("Calculating ideology scores from most recent to oldest...\n")

# Process years
available_years_rev <- rev(sort(unique(combined_data$year)))
cat("Processing order:", toString(available_years_rev), "\n")

all_scores <- map_dfr(available_years_rev, ~{
  result <- calculate_yearly_scores(.x, combined_data)
  if(is.null(result)) {
    cat("No scores calculated for year", .x, "\n")
    return(NULL)
  }
  return(result)
}, .progress = TRUE)


# Save results

if(!is.null(all_scores) && nrow(all_scores) > 0) {
  write_csv(all_scores, "ideology_scores_final.csv")
  cat("\n=== RESULTS SUMMARY ===\n")
  cat("Total scores calculated:", nrow(all_scores), "\n")
  cat("Years covered:", toString(sort(unique(all_scores$year))), "\n")
  
  # Summary by year and reference MP
  score_summary <- all_scores %>%
    group_by(year, reference_mp) %>%
    summarise(
      n_mps = n(),
      mean_score = mean(z_score, na.rm = TRUE),
      sd_score = sd(z_score, na.rm = TRUE),
      .groups = "drop"
    )
  print(score_summary)
  
} else {
  cat("No scores were calculated\n")

}
