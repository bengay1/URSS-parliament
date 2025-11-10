# ============================================================================
# Setup: Load Libraries & Initialise Environment
# ============================================================================
#
# Purpose:
#   Load all required R packages and source helper functions
#
# Usage:
#   source("scripts/00_setup.R")
#
# Author: Benjamin Gay
# Date: 2025-11-09
# ============================================================================

# Install missing packages (uncomment if needed)
# required_packages <- c("tidyverse", "ltm", "lubridate", "dplyr", "ggplot2", "knitr")
# for (pkg in required_packages) {
#   if (!require(pkg, character.only = TRUE)) {
#     install.packages(pkg)
#     library(pkg, character.only = TRUE)
#   }
# }

# Load libraries
library(tidyverse)
library(ltm)
library(lubridate)
library(dplyr)
library(ggplot2)

# Source helper functions
source("functions/load_functions.R")
source("functions/irt_functions.R")
source("functions/plot_functions.R")

# Set options
options(
  scipen = 999,           # Avoid scientific notation
  stringsAsFactors = FALSE
)

# Create output directory if needed
if (!dir.exists("data")) {
  dir.create("data")
}

cat("✓ Setup complete. Libraries and functions loaded.\n")
