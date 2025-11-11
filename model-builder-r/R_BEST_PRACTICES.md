# R Best Practices: Code Style Guide

This document outlines the coding conventions and best practices used in this project.

## Naming Conventions

### Files
- Use lowercase with underscores: `load_functions.R`, `irt_functions.R`
- Scripts: `01_load_election_data.R`, `02_calculate_ideology_scores.R`
- Avoid spaces in filenames

### Functions
- Use `snake_case`: `calculate_yearly_scores()`, `plot_party_timeseries()`
- Action verb first: `load_`, `calculate_`, `plot_`
- Descriptive but concise

### Variables
- Use `snake_case`: `mp_name_id`, `z_score`, `party_clean`
- Avoid single letters except in loops: `i`, `j`
- Use full words for clarity: `score` not `s`, `mp_id` not `mid`

### Constants
- Use UPPER_CASE: `REFERENCE_YEARS <- c(1997, 2001, ...)`
- Define at top of script for easy modification

## Code Style

### Assignment
```r
# Good: use <- for assignment
x <- 10
df <- read_csv("file.csv")

# Avoid: = assignment
x = 10
```

### Spacing
```r
# Good: spaces around operators
result <- mean(x, na.rm = TRUE)
if (n > 10) { ... }

# Avoid: no spaces
result<-mean(x,na.rm=TRUE)
if(n>10){...}
```

### Line Length
- Aim for maximum 80 characters per line
- Break long lines at logical points

```r
# Good: break long pipeline
data <- all_scores %>%
  filter(year > 2010) %>%
  group_by(party_clean) %>%
  summarise(mean_score = mean(z_score))

# Avoid: one long line (hard to read)
data <- all_scores %>% filter(year > 2010) %>% group_by(party_clean) %>% summarise(mean_score = mean(z_score))
```

### Indentation
- Use 2 spaces for indentation (not tabs)
- Consistent indentation for readability

```r
# Good
for (i in 1:10) {
  if (i > 5) {
    cat("Large number:", i, "\n")
  }
}

# Avoid: 4 spaces or tabs
for (i in 1:10) {
    if (i > 5) {
        cat("Large number:", i, "\n")
    }
}
```

## Function Guidelines

### Function Documentation
```r
#' Short one-line description
#'
#' Longer explanation of what the function does, spanning
#' multiple lines if needed. Explain the purpose and usage.
#'
#' @param input1 Character. Description of first parameter
#' @param input2 Numeric. Description of second parameter
#'
#' @return Data frame/vector. Description of output
#'
#' @examples
#' # Simple example showing how to use
#' result <- my_function("example", 42)
#'
my_function <- function(input1, input2) {
  # Function body
  return(result)
}
```

### Function Design
- Single responsibility: one function should do one thing
- Input validation: check parameter types and ranges
- Informative error messages

```r
# Good: validates input and gives clear error
calculate_slope <- function(data, min_years = 5) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }
  if (min_years < 1) {
    stop("min_years must be >= 1")
  }
  # ... continue with function
}

# Avoid: no validation
calculate_slope <- function(data, min_years = 5) {
  # ... proceeds regardless of input quality
}
```

### Default Parameters
```r
# Good: sensible defaults
plot_trends <- function(data, years = NULL, color_scheme = "Set1") {
  if (is.null(years)) {
    years <- unique(data$year)
  }
  # ...
}

# Avoid: confusing defaults
plot_trends <- function(data, years, color_scheme) {
  # User must always specify these
}
```

## Pipelines (dplyr)

```r
# Good: clear pipeline with line breaks
result <- data %>%
  filter(year > 2010) %>%
  mutate(new_var = x + y) %>%
  group_by(group) %>%
  summarise(
    mean_value = mean(value),
    count = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_value))

# Avoid: cramped or unclear
result <- data %>% filter(year > 2010) %>% mutate(new_var = x + y) %>% group_by(group) %>% summarise(mean_value = mean(value), count = n(), .groups = "drop") %>% arrange(desc(mean_value))
```

## Control Flow

### if/else
```r
# Good: clear conditions
if (score > threshold) {
  category <- "high"
} else if (score > 0) {
  category <- "medium"
} else {
  category <- "low"
}

# Also good: case_when for multiple conditions
category <- case_when(
  score > threshold ~ "high",
  score > 0 ~ "medium",
  TRUE ~ "low"
)

# Avoid: nested if/else (hard to read)
if (score > threshold) {
  if (other_condition) {
    category <- "high"
  } else {
    category <- "medium"
  }
}
```

### Loops
```r
# Good: vectorised operations (preferred)
result <- map_dfr(years, ~calculate_scores(.x, data))

# Also good: loop with clear structure
results <- list()
for (year in years) {
  results[[as.character(year)]] <- calculate_scores(year, data)
}
result <- bind_rows(results)

# Avoid: unclear variable names
for (i in 1:length(x)) {
  y[[i]] <- some_function(x[[i]])
}
```

## Error Handling

```r
# Good: informative error messages
tryCatch(
  {
    model <- ltm::ltm(data ~ z1, IRT.param = TRUE)
  },
  error = function(e) {
    stop("IRT model failed for year ", year, ": ", e$message)
  }
)

# Good: progress messages
cat("Processing year:", year, "\n")
result <- some_function(data)
cat("✓ Completed year:", year, "\n")

# Avoid: silent failures
result <- tryCatch(some_function(data), error = function(e) NULL)
```

## Comments

```r
# Good: explain WHY, not WHAT
# Filter to votes with sufficient variance for IRT model
# (IRT assumes item difficulty, which requires variance)
data <- data %>% filter(p_vote > 0.05, p_vote < 0.95)

# Avoid: comments that restate code
# Create a tibble with x and y
tbl <- tibble(x = 1:10, y = 20:11)

# Section headers for clarity
# ============================================================================
# 1. Load and prepare data
# ============================================================================
```

## String Concatenation

```r
# Good: use paste0 or glue for clarity
message <- paste0("Processed ", n_rows, " rows in ", n_years, " years")
cat("Year:", year, "| MP count:", n_mps, "\n")

# Also good (more modern)
library(glue)
message <- glue("Processed {n_rows} rows in {n_years} years")

# Avoid: %+% operator (though used in this project for brevity)
message <- "Year: " %+% year %+% " | MPs: " %+% n_mps
```

## Common Patterns

### Reading CSVs
```r
# Good: specify column types
data <- read_csv("file.csv", show_col_types = FALSE)

# Also good: explicit column types
data <- read_csv(
  "file.csv",
  col_types = cols(
    year = col_integer(),
    score = col_double(),
    name = col_character()
  )
)
```

### Creating Functions for Repeated Tasks
```r
# Bad: repeated code
plot1 <- ggplot(data, aes(x = x, y = y)) + geom_point() + ...
plot2 <- ggplot(data, aes(x = x, y = z)) + geom_point() + ...
plot3 <- ggplot(data, aes(x = a, y = b)) + geom_point() + ...

# Good: extract into function
create_scatter <- function(data, x_var, y_var, title) {
  ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]])) +
    geom_point() +
    labs(title = title)
}

plot1 <- create_scatter(data, "x", "y", "Plot 1")
plot2 <- create_scatter(data, "x", "z", "Plot 2")
```

## Performance Considerations

### Vectorisation
```r
# Good: vectorised operations are faster
result <- x + y  # Element-wise operations

# Avoid: loops when vectorisation possible
result <- numeric(length(x))
for (i in 1:length(x)) {
  result[i] <- x[i] + y[i]
}
```

### Memory
```r
# Good: use data.table or tibble for large datasets
data <- read_csv("large_file.csv")

# Filter early to reduce data size
data <- data %>%
  filter(year > 2010) %>%  # Reduce size early
  select(needed_columns)   # Keep only needed columns
```

## Reproducibility

```r
# Set seed for reproducible results
set.seed(42)

# Include library versions in comments
# Tested with: tidyverse (1.3.0), ltm (1.2.0), lubridate (1.8.0)

# Document any external dependencies or data sources
# Data from: https://www.publicwhip.org.uk/
# Downloaded: 2025-11-09

# Use here::here() for relative paths (if using projects)
# data <- read_csv(here::here("data", "mydata.csv"))
```

## Security & Best Practices

### Avoid hardcoded paths
```r
# Good: relative paths
data_file <- "data/input.csv"
result <- read_csv(data_file)

# Good: use Sys.getenv() for sensitive paths
data_path <- Sys.getenv("DATA_PATH", default = "data/")

# Avoid: hardcoded absolute paths
data <- read_csv("C:/Users/benau/Downloads/data.csv")
```

### Handle missing data explicitly
```r
# Good: explicit NA handling
mean_score <- mean(z_score, na.rm = TRUE)

# Also good: check for missing before operations
if (any(is.na(data$value))) {
  cat("Warning: found NA values, removing...\n")
  data <- data %>% filter(!is.na(value))
}
```

## Testing & Quality

### Add assertions
```r
# Good: check assumptions
stopifnot(nrow(data) > 0, ncol(data) > 0)
stopifnot(all(!is.na(data$z_score)))

# Good: informative assertions
if (nrow(result) == 0) {
  warning("No results returned for year ", year)
  return(NULL)
}
```

---

## Quick Reference Checklist

- [ ] Function names: snake_case
- [ ] Variable names: snake_case
- [ ] File names: lowercase_underscore.R
- [ ] Assignment: `<-` not `=`
- [ ] Indentation: 2 spaces
- [ ] Line length: < 80 characters
- [ ] Functions documented with comments
- [ ] Error messages are informative
- [ ] Pipes use line breaks for clarity
- [ ] NAs handled explicitly
- [ ] No hardcoded paths
- [ ] Reproducibility ensured (seeds, versions)
