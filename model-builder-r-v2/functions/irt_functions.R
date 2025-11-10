# ============================================================================
# Helper Functions: Item Response Theory (IRT) Analysis
# ============================================================================
#
# This file contains functions for IRT model fitting and ideology scoring
#

#' Calculate IRT Ideology Scores for a Single Year
#'
#' Fits a 2-parameter logistic (2PL) IRT model to parliamentary voting data
#' for a specified year. Scores MPs based on voting agreement with reference MPs.
#'
#' @param yr Integer. Calendar year to analyse.
#' @param data Tibble. Parliamentary voting data (output from load script).
#' @param reference_candidates List. Candidate reference MPs in priority order.
#'   Each element is c(firstname, surname).
#'
#' @return Tibble with columns: mp_name_id, z_score, year, reference_mp, method
#'   Returns NULL if insufficient data or IRT fails.
#'
calculate_yearly_scores <- function(
    yr,
    data,
    reference_candidates = list(
      c("Jeremy", "Corbyn"),
      c("Nadia", "Whittome"),
      c("Diane", "Abbott"),
      c("John", "McDonnell"),
      c("Keir", "Starmer")
    )) {

  cat("\n  --- Processing year:", yr, "---\n")
  yearly_data <- data %>% filter(year == yr)

  if (nrow(yearly_data) == 0) {
    cat("    ✗ No data for year", yr, "\n")
    return(NULL)
  }

  # Store MP info for this year
  mp_info <- yearly_data %>%
    distinct(mp_name_id, firstname, surname, party_clean)

  cat("    MPs:", nrow(mp_info), "\n")
  cat("    Party distribution:\n")
  party_dist <- table(mp_info$party_clean)
  for (p in names(party_dist)) {
    cat("      ", p, ":", party_dist[p], "\n")
  }

  # Remove uninformative votes (unanimous or near-unanimous)
  vote_variance <- yearly_data %>%
    group_by(voteno) %>%
    summarize(p = mean(vote_binary, na.rm = TRUE), .groups = "drop") %>%
    filter(p > 0.05 & p < 0.95)

  yearly_data <- yearly_data %>% filter(voteno %in% vote_variance$voteno)

  if (nrow(yearly_data) == 0) {
    cat("    ✗ No informative votes after filtering\n")
    return(NULL)
  }

  cat("    Informative votes:", length(unique(yearly_data$voteno)), "\n")

  # Try each reference MP in priority order
  for (ref_candidate in reference_candidates) {
    ref_firstname <- ref_candidate[1]
    ref_surname <- ref_candidate[2]
    ref_name_id <- paste(ref_firstname, ref_surname)

    # Check if reference MP exists in this year
    potential_ref <- mp_info %>% filter(mp_name_id == ref_name_id)

    if (nrow(potential_ref) == 0) {
      cat("    ✗ Reference MP not found:", ref_firstname, ref_surname, "\n")
      next
    }

    cat("    ✓ Trying reference:", ref_firstname, ref_surname,
        "(" %+% potential_ref$party_clean[1] %+% ")\n")

    # Get reference MP's votes
    candidate_mp_id <- potential_ref$mp_name_id[1]
    candidate_votes <- yearly_data %>%
      filter(mp_name_id == candidate_mp_id) %>%
      filter(!is.na(vote_binary))

    cat("      Reference MP votes:", nrow(candidate_votes), "\n")

    # Require minimum votes (Jeremy Corbyn gets lower threshold)
    min_votes <- ifelse(ref_firstname == "Jeremy" && ref_surname == "Corbyn", 5, 10)

    if (nrow(candidate_votes) < min_votes ||
        length(unique(candidate_votes$vote_binary)) <= 1) {
      cat("      ✗ Insufficient votes or no variance\n")
      next
    }

    # Get reference MP's votes on divisions
    reference_votes <- candidate_votes %>%
      distinct(voteno, reference_vote = vote_binary)

    if (nrow(reference_votes) < 5) {
      cat("      ✗ Too few reference votes\n")
      next
    }

    # Build agreement matrix (1 = agreed with reference, 0 = disagreed)
    agreement_matrix <- yearly_data %>%
      inner_join(reference_votes, by = "voteno") %>%
      filter(!is.na(vote_binary)) %>%
      mutate(agreement = as.integer(vote_binary == reference_vote)) %>%
      dplyr::select(mp_name_id, voteno, agreement) %>%
      group_by(mp_name_id, voteno) %>%
      slice(1) %>%
      ungroup()

    # Pivot to wide format (MPs x votes)
    agreement_wide <- agreement_matrix %>%
      pivot_wider(
        names_from = voteno,
        values_from = agreement,
        values_fill = 0
      )

    if (ncol(agreement_wide) < 2) {
      cat("      ✗ Failed to create agreement matrix\n")
      next
    }

    # Convert to matrix format for IRT
    agreement_matrix_final <- agreement_wide %>%
      column_to_rownames("mp_name_id") %>%
      as.matrix()

    cat("      Matrix:", nrow(agreement_matrix_final), "MPs ×",
        ncol(agreement_matrix_final), "votes\n")

    # Clean matrix: ensure binary, handle NAs
    agreement_matrix_final[is.na(agreement_matrix_final)] <- 0
    agreement_matrix_final <- ifelse(agreement_matrix_final > 0.5, 1, 0)

    # Remove items (votes) with no variance
    item_variance <- apply(agreement_matrix_final, 2, function(x) {
      var_x <- var(x)
      !is.na(var_x) && var_x > 0
    })

    keep_items <- which(item_variance)
    if (length(keep_items) < 5) {
      cat("      ✗ Too few variable votes\n")
      next
    }

    agreement_matrix_final <- agreement_matrix_final[, keep_items, drop = FALSE]

    # Remove MPs with no variance
    mp_variance <- apply(agreement_matrix_final, 1, function(x) {
      var_x <- var(x)
      !is.na(var_x) && var_x > 0
    })

    keep_mps <- which(mp_variance)
    if (length(keep_mps) < 10) {
      cat("      ✗ Too few variable MPs\n")
      next
    }

    agreement_matrix_final <- agreement_matrix_final[keep_mps, , drop = FALSE]

    cat("      Filtered matrix:", dim(agreement_matrix_final)[1], "MPs ×",
        dim(agreement_matrix_final)[2], "votes\n")

    # Try IRT model (attempt up to 3 times)
    irt_success <- FALSE
    for (attempt in 1:3) {
      tryCatch({
        cat("      IRT attempt", attempt, "...\n")

        # Ensure all data is binary
        if (any(!unlist(agreement_matrix_final) %in% c(0, 1))) {
          stop("Non-binary values in matrix")
        }

        # Fit 2PL IRT model using EM algorithm
        irt_model <- ltm::ltm(as.data.frame(agreement_matrix_final) ~ z1,
                              IRT.param = TRUE,
                              control = list(
                                iter.em = 30,
                                iter.qN = 100,
                                GHk = 7
                              ))

        # Extract factor scores (θ)
        factor_scores <- ltm::factor.scores(irt_model,
                                            resp.patterns = as.data.frame(agreement_matrix_final))

        result <- tibble(
          mp_name_id = rownames(agreement_matrix_final),
          z_score = as.numeric(factor_scores$score.dat$z1),
          year = yr,
          reference_mp = ref_name_id,
          method = "IRT"
        )

        # Check for reasonable score distribution
        score_sd <- sd(result$z_score, na.rm = TRUE)
        if (score_sd < 10 && score_sd > 0.1) {
          cat("      ✓ IRT successful (SD=", round(score_sd, 3), ")\n")
          cat("    ✓ SUCCESS: Scored", nrow(result), "MPs\n")
          return(result)
        } else {
          stop("Extreme scores (SD=", round(score_sd, 3), ")")
        }

      }, error = function(e) {
        # Silently fail and try again
      })
    }

    cat("      ✗ IRT failed for all attempts\n")
  }

  cat("    ✗ All reference MPs failed for year", yr, "\n")
  return(NULL)
}


#' Calculate MP Ideological Slopes Over Career
#'
#' Performs linear regression of ideology scores on years for each MP
#'
#' @param all_scores Tibble. IRT scores
#' @param min_years Numeric. Minimum years required
#'
#' @return Tibble with slopes, p-values, significance
#'
calculate_mp_slopes <- function(all_scores, min_years = 15) {

  cat("\nCalculating ideology change slopes...\n")

  # Get MPs with enough data
  mp_years <- all_scores %>%
    group_by(mp_name_id) %>%
    summarise(
      n_years = n(),
      first_year = min(year),
      last_year = max(year),
      .groups = "drop"
    ) %>%
    filter(n_years >= min_years) %>%
    mutate(career_span = last_year - first_year)

  # Calculate slopes for each MP
  slopes_list <- list()

  for (mp in mp_years$mp_name_id) {
    mp_data <- all_scores %>%
      filter(mp_name_id == mp) %>%
      arrange(year)

    if (nrow(mp_data) >= min_years) {
      model <- lm(z_score ~ year, data = mp_data)
      coef_summary <- summary(model)$coefficients

      slope <- coef_summary["year", "Estimate"]
      std_error <- coef_summary["year", "Std. Error"]
      p_value <- coef_summary["year", "Pr(>|t|)"]

      # Significance stars
      significance <- case_when(
        p_value < 0.001 ~ "***",
        p_value < 0.01 ~ "**",
        p_value < 0.05 ~ "*",
        p_value < 0.1 ~ ".",
        TRUE ~ "ns"
      )

      slopes_list[[mp]] <- tibble(
        mp_name_id = mp,
        slope = slope,
        std_error = std_error,
        p_value = p_value,
        significance = significance
      )
    }
  }

  result <- bind_rows(slopes_list) %>%
    left_join(mp_years, by = "mp_name_id") %>%
    dplyr::select(
      mp_name_id, slope, std_error, p_value, significance,
      years_in_parliament = n_years, career_span, first_year, last_year
    ) %>%
    arrange(desc(abs(slope)))

  cat("✓ Calculated slopes for", nrow(result), "MPs\n")

  return(result)
}
