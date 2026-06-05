#' Standardize a city name for cross-source joins.
#'
#' Lowercases, collapses whitespace, strips a leading
#' "City of / Town of / Village of / Borough of" prefix, and strips one or
#' more trailing place-type suffixes from a fixed alternation. Consolidated
#' city-counties (e.g., "Athens-Clarke County") are returned unchanged so
#' the legal "County" suffix is preserved.
#'
#' @param x character vector of city names (any case).
#' @return lowercased character vector.
std_city <- function(x) {
  consolidated_ccs <- c(
    "athens-clarke county", "augusta-richmond county",
    "columbus-muscogee county", "macon-bibb county",
    "louisville jefferson county", "nashville davidson county"
  )

  out <- x |>
    stringr::str_replace_all("\\s+", " ") |>
    stringr::str_trim() |>
    stringr::str_to_lower() |>
    stringr::str_remove(stringr::regex("^(city|town|village|borough) of\\s+"))

  suf_re <- stringr::regex("(\\s+(city|town|village|borough|township|municipality|cdp))+$")
  is_cc <- out %in% consolidated_ccs
  ifelse(is_cc, out, stringr::str_remove(out, suf_re))
}
