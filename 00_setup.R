# =============================================================================
# 00_setup.R
# Purpose  : One-time project setup. Installs renv and all project packages.
# Inputs   : None (run once on a new machine before anything else).
# Outputs  : renv/ directory + renv.lock (pinned package versions).
# Run      : source("00_setup.R") in an R session, or Rscript 00_setup.R.
# =============================================================================

# Step 1: bootstrap renv itself.
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Step 2: initialize renv for this project. Creates renv/ and the .Rprofile that
# activates the environment on project open. bare = TRUE skips package install.
renv::init(bare = TRUE)

# Step 3: install project packages.

# Core data wrangling and plotting (dplyr, ggplot2, readr, stringr, tidyr,
# purrr, lubridate, tibble, forcats).
renv::install("tidyverse")

# File I/O.
renv::install("readxl")      # Read .xlsx (NTD data ships as Excel)
renv::install("here")        # Project-root-relative paths, cross-platform

# Web acquisition.
renv::install("rvest")       # HTML parsing
renv::install("httr2")       # HTTP requests

# Census and government data APIs.
renv::install("tidycensus")  # Census Bureau API (PEP, decennial)
# Requires a free API key from api.census.gov/data/key_signup.html.
# Set once with: tidycensus::census_api_key("YOUR_KEY", install = TRUE)

# Panel regression.
renv::install("fixest")      # Panel FE regression with clustered SEs (feols)

# Fuzzy string matching for the city-name crosswalk.
renv::install("stringdist")  # Levenshtein / Jaro-Winkler distance

# Table and output formatting.
renv::install("modelsummary") # Regression tables from model objects
renv::install("kableExtra")   # Styled HTML/LaTeX tables in Quarto

# Data cleaning.
renv::install("janitor")     # clean_names() and friends

# Quarto rendering (usually bundled with the Quarto CLI).
renv::install("quarto")

# Step 4: snapshot exact versions to renv.lock. Commit the lockfile.
renv::snapshot()

# Step 5: post-setup notes.
message("
Setup complete.
1. Census API key (free): https://api.census.gov/data/key_signup.html
   tidycensus::census_api_key('YOUR_KEY', install = TRUE)
2. Restore this environment on another machine: renv::restore()
3. Render the pipeline in order, or run 'quarto render' from the project root.
")
