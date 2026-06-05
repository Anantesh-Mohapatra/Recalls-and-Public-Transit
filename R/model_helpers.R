#' Shared model-fitting + extraction helpers used by Stages 7, 8, and 9.
#'
#' Fit helpers (`fit_*`) take an agency-city-year data frame already filtered
#' to the relevant sample (e.g., `panel |> filter(in_modelA_hq)`) and return
#' a fixest model object. Each helper drops rows with missing DV or controls
#' internally, so callers only pass the sample selector.
#'
#' Extract helpers take a `fixest` model object and return tibbles suitable
#' for table assembly or plotting. Each accepts an optional `label` argument
#' so multi-spec rows can be stacked with `bind_rows()` and distinguished by
#' the `spec` column.

suppressMessages({
  library(dplyr)
  library(stringr)
  library(tibble)
})

# Term-pattern regexes shared by Stages 7 and 8 headline summaries.
# `extract_one()` greps these against rownames of fixest's coeftable.
PETITION_PAT <- "^any_petition_this_year(?:TRUE)?$"
COVID_INT_PAT <- ":.*covid_period|covid_period.*:"
RECALL_T0_PAT <- "et_for_reg::0\\b"

# Model A event-study: i(et_for_reg, ref = -1) + controls | agency_city + year.
fit_modelA <- function(df) {
  fixest::feols(
    log_transit_cap ~ i(et_for_reg, ref = -1) + log_pop_density + unemp_rate
    | agency_city + year, cluster = ~ city_id,
    data = df |> filter(!is.na(log_transit_cap),
                        !is.na(log_pop_density), !is.na(unemp_rate)))
}

# Model B static petition DiD: petition + controls | agency_city + year.
fit_modelB_static <- function(df) {
  fixest::feols(
    log_transit_cap ~ any_petition_this_year + log_pop_density + unemp_rate
    | agency_city + year, cluster = ~ city_id,
    data = df |> filter(!is.na(log_transit_cap),
                        !is.na(log_pop_density), !is.na(unemp_rate)))
}

# Model B × COVID interaction.
fit_modelB_covid <- function(df) {
  fixest::feols(
    log_transit_cap ~ any_petition_this_year * covid_period +
                      log_pop_density + unemp_rate
    | agency_city + year, cluster = ~ city_id,
    data = df |> filter(!is.na(log_transit_cap),
                        !is.na(log_pop_density), !is.na(unemp_rate)))
}

# Event-time coefficients from a Model A i(et_for_reg, ref = -1) spec.
# Returns one row per event-time bin + a synthetic est=0 row at the
# reference period (-1).
extract_es <- function(mod, label = NA_character_) {
  co  <- coef(mod); vc <- vcov(mod)
  idx <- grep("^et_for_reg::", names(co))
  if (length(idx) == 0) return(tibble())
  tibble(spec = label,
         et   = as.integer(str_extract(names(co)[idx], "-?\\d+")),
         est  = as.numeric(co[idx]),
         se   = sqrt(diag(vc))[idx]) |>
    mutate(lo = est - 1.96 * se, hi = est + 1.96 * se) |>
    bind_rows(tibble(spec = label, et = -1, est = 0,
                     se = NA, lo = NA, hi = NA))
}

# Joint Wald test against a regex pattern matching the terms to test.
# `wald()` returns a list in some fixest versions and a named numeric vector
# in others; pluck_num handles both.
pretrend_wald <- function(mod, term_pattern, label = NA_character_) {
  pre_terms <- grep(term_pattern, names(coef(mod)), value = TRUE)
  if (length(pre_terms) == 0) {
    return(tibble(spec = label, n_pre_terms = 0L,
                  F_stat = NA_real_, p_value = NA_real_))
  }
  pluck_num <- function(x, key) {
    if (is.null(x))                         return(NA_real_)
    if (is.list(x) && key %in% names(x))    return(as.numeric(x[[key]]))
    if (is.atomic(x) && key %in% names(x))  return(unname(as.numeric(x[[key]])))
    NA_real_
  }
  w <- tryCatch(fixest::wald(mod, pre_terms, print = FALSE),
                error = function(e) NULL)
  tibble(spec = label, n_pre_terms = length(pre_terms),
         F_stat  = pluck_num(w, "stat"),
         p_value = pluck_num(w, "p"))
}

# Single-coefficient extractor for summary tables. `term_pattern` is matched
# against rownames of the coef table; the first match is returned.
extract_one <- function(mod, label, term_pattern, term_label = NULL) {
  if (is.null(mod)) return(NULL)
  ct <- summary(mod)$coeftable
  rn <- grep(term_pattern, rownames(ct), value = TRUE)
  if (length(rn) == 0) return(NULL)
  r <- unname(ct[rn[1], ])
  n_clusters <- tryCatch(
    if (!is.null(mod$cov.scaled) && !is.null(attr(mod$cov.scaled, "G")))
      attr(mod$cov.scaled, "G")[[1]] else NA_integer_,
    error = function(e) NA_integer_)
  tibble(spec  = label,
         term  = if (!is.null(term_label)) term_label else rn[1],
         est   = r[1], se = r[2], p = r[4],
         n_obs = mod$nobs, n_clusters = n_clusters)
}
