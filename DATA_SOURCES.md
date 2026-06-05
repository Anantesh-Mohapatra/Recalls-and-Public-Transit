# Data Sources

External datasets used by this thesis. One catalog entry per source with the canonical URL, identifier, coverage window, and the date the local copy was last refreshed. All downloaded files live under `data/raw/`; cleaned derivatives live under `data/cleaned/`; the analysis-ready panel is at `data/final/panel.rds`.

When refreshing, the per-stage `.qmd` files (`01a` through `01d`, `03c`) hold the actual download logic and URL tables. This file is the index — refer to the named qmd for the runnable acquisition code.

---

## 1. Mayoral recall events — Ballotpedia

- **Source:** Ballotpedia (community-edited wiki of US elections)
- **Pages:** `https://ballotpedia.org/Political_recall_efforts,_YYYY` (year-summary pages, 2014-2024) + per-recall pages linked from those
- **Coverage:** all mayoral / mayor+council recall attempts 2014-2024
- **Local copy:** `data/raw/ballotpedia/html/*.html` (402 individual recall pages + 11 year summaries) → parsed to `data/raw/ballotpedia/recalls_raw.rds`
- **Acquisition script:** `01a_scrape_ballotpedia.qmd` (scrape), `01b_parse_ballotpedia.qmd` (parse)
- **Last refreshed:** 2026-02-28 (HTML cache); 2026-04-14 (parse rebuild)
- **Notes:** Ballotpedia's `robots.txt` permits scraping `/Political_recall_efforts,_*`. The HTML cache is the expensive artifact — do not re-scrape unless necessary.

## 2. Transit capital expenses — FTA NTD

Two parallel sources cover the full 2014-2024 window.

### 2a. Pre-2022: per-year xlsx from FTA
- **Source:** Federal Transit Administration, National Transit Database (NTD) Annual Database
- **Data product pages:** `https://www.transit.dot.gov/ntd/data-product/YYYY-annual-database-capital-expenses-capital-use` for each year 2014-2021
- **File URL pattern:** varies by year (`...files/YYYY%20Capital%20Use.xlsx`, `...files/YYYY-MM/YYYY%20Capital%20Use.xlsx`); URL tribble in `01c_collect_ntd.qmd`
- **Coverage:** 2014-2021
- **Local copy:** `data/raw/ntd/capital_use_YYYY.xlsx` (8 files)
- **Acquisition script:** `01c_collect_ntd.qmd`
- **Last refreshed:** 2026-04-14

### 2b. 2022-2024: Socrata view
- **Source:** Federal Transit Administration via `data.transportation.gov`
- **Dataset:** "2022 - 2024 NTD Annual Data - Capital Expenses (by Capital Use)"
- **Socrata ID:** `fphd-jyyj`
- **CSV endpoint:** `https://data.transportation.gov/resource/fphd-jyyj.csv?$limit=5000000`
- **Coverage:** 2022-2024 (FTA migrated data products to Socrata starting 2022; pre-2022 data is not back-filled on Socrata — use 2a)
- **Local copy:** `data/raw/ntd/ntd_capital_socrata_raw.csv`
- **Acquisition script:** `01c_collect_ntd.qmd`
- **Last refreshed:** 2026-03-01

## 3. Transit operating expenses — FTA NTD

### 3a. Pre-2022: per-year xlsx
- **Source:** FTA NTD Annual Database — Operating Expenses
- **Data product pages:** `https://www.transit.dot.gov/ntd/data-product/YYYY-annual-database-operating-expenses` for each year
- **File URL pattern:** varies by year; URL tribble in `01d_collect_ntd_operating.qmd`
- **Coverage:** 2014-2021
- **Local copy:** `data/raw/ntd/operating_expenses_YYYY.xlsx` (8 files)
- **Acquisition script:** `01d_collect_ntd_operating.qmd`
- **Last refreshed:** 2026-05-09

### 3b. 2022-2024: Socrata view
- **Socrata ID:** `i5ki-dc58`
- **CSV endpoint:** `https://data.transportation.gov/resource/i5ki-dc58.csv?$limit=500000`
- **Coverage:** 2022-2024
- **Local copy:** `data/raw/ntd/ntd_operating_socrata_raw.csv`
- **Acquisition script:** `01d_collect_ntd_operating.qmd`
- **Last refreshed:** 2026-05-09

## 4. NTD agency directory (city + state per agency-year)

- **Source:** FTA NTD Annual Database — Agency Information
- **Data product pages:** `https://www.transit.dot.gov/ntd/data-product/YYYY-annual-database-agency-information` (or `-1` / `-0` slug variants per year)
- **File URL pattern:** varies; URL tribble in `01c_collect_ntd.qmd`
- **Coverage:** 2014-2024 (one xlsx per year)
- **Local copy:** `data/raw/ntd/agency_info_YYYY.xlsx` (11 files, ~6.5 MB total)
- **Acquisition script:** `01c_collect_ntd.qmd` (URL table + integrity check)
- **Last refreshed:** 2026-05-17
- **Used for:** building the `(year, ntd_id) → city, state` crosswalk used in `03b_extract_ntd.qmd`. Without this, pre-2022 capital_use rows have no city/state attached and are unmatchable to recall cities. The xlsx also carries `organization_type`, the basis for the binary `local_controlled` flag in the panel (TRUE for the "City, County or Local Government Unit or DOT" category).
- **Notes:** `ntd_id` column reads as numeric in some years (notably 2020), which drops Reduced/Rural Reporters whose IDs are strings like `0R02-00308`. Force `col_types = "text"` when reading.

## 5. NTD agency service area — Counties and Places (RY2024)

- **Source:** FTA NTD via `data.transportation.gov` — "2024 NTD Annual Data - Demand Response Geographic Area Coverage (Counties and Places)"
- **Socrata ID:** `qifj-zz6e`
- **CSV endpoint:** `https://data.transportation.gov/resource/qifj-zz6e.csv?$limit=200000`
- **Coverage:** RY2024 only. (RY2023 equivalent is `3kum-6vpd`; not currently used.) Service-area collection is a Bipartisan Infrastructure Law reporting requirement introduced in RY2023; no earlier years exist.
- **Local copy:** `data/raw/ntd/service_area_places_2024.csv`
- **Acquisition script:** `01c_collect_ntd.qmd` (validated, source URL documented)
- **Last refreshed:** 2026-05-17
- **Used for:** building the agency-served-Place and agency-served-County lookups in `03c_match_roster.qmd`. The dataset is reported for agencies running demand-response (DR) mode; per ADA paratransit rules, DR coverage approximates fixed-route bus coverage for the same agency.

## 6. Census Place ↔ County crosswalk

- **Source:** US Census Bureau, 2020 ANSI/FIPS reference codes
- **File URL:** `https://www2.census.gov/geo/docs/reference/codes2020/national_place_by_county2020.txt`
- **Coverage:** 2020 vintage (Census Places by County, 33,618 rows nationwide)
- **Local copy:** `data/raw/census/national_place_by_county2020.txt`
- **Acquisition:** download triggered in `04_build_controls.qmd` if file missing
- **Last refreshed:** 2026-04-14
- **Used for:** (a) BLS LAUS join in `04_build_controls.qmd` (city → county for unemployment lookup); (b) FTA service-area county-level matching in `03c_match_roster.qmd`.

## 6b. Census County Subdivision (MCD) ↔ County crosswalk

- **Source:** US Census Bureau, 2020 ANSI/FIPS reference codes
- **File URL:** `https://www2.census.gov/geo/docs/reference/codes2020/national_cousub2020.txt`
- **Coverage:** 2020 vintage (Census County Subdivisions by County, 36,640 rows nationwide)
- **Local copy:** `data/raw/census/national_cousub2020.txt`
- **Acquisition:** download triggered in `04_build_controls.qmd` if file missing
- **Last refreshed:** 2026-05-18
- **Used for:** FTA service-area county-level matching in `03c_match_roster.qmd`, as a fallback when a recall city is an MCD (township/borough/town) rather than a Census Place. The Place file excludes MCDs by definition, which costs coverage for recall cities in strong-MCD states (NJ, MI, PA, MA, …). The crosswalks are combined with Place-priority + Cousub-fallback semantics — Cousub is only consulted for recall cities the Place file can't resolve, to avoid name collisions induced by `std_city()` stripping trailing place-type suffixes.

## 7. Population — Census Population Estimates Program (PEP)

- **Source:** US Census Bureau PEP via the `tidycensus` R package
- **API base:** `https://api.census.gov/data/{vintage}/pep/...`
- **API key required:** Census API key, stored via `tidycensus::census_api_key("KEY", install = TRUE)` (writes to `~/.Renviron`)
- **Coverage:** 2014-2024 — V2019 vintage covers 2010-2019, V2024 vintage covers 2020-2024; the two are unioned in `04_build_controls.qmd`
- **Local copy:** intermediate joins in `04_build_controls.qmd` cache; final values flow into `data/cleaned/controls.rds`
- **Acquisition script:** `04_build_controls.qmd`
- **Last refreshed:** 2026-05-09
- **Notes:** vintage-switching is intentional — PEP releases revise back several years each vintage, so V2024 carries the best estimate for 2020-2024 and V2019 carries the best for 2010-2019.

## 8. Unemployment — BLS Local Area Unemployment Statistics

- **Source:** US Bureau of Labor Statistics, LAUS county-level series
- **File URL:** `https://download.bls.gov/pub/time.series/la/la.data.64.County` (flat file, ~70 MB)
- **Coverage:** all available years (we keep 2014-2024)
- **Local copy:** `data/raw/bls/la.data.64.County`
- **Acquisition script:** `04_build_controls.qmd` (download chunk)
- **Last refreshed:** 2026-05-09
- **Notes:** No API key required. Series ID structure: `LAUCN{state_fips}{county_fips}0000000003` for unemployment rate. Joined to city via the Census Place ↔ County crosswalk (source 6).

---

## Rebuilding the data

Render the pipeline in order (see the README) or run `Rscript run_all.R`. A few
data-specific notes:

- A Census API key is required for `04_build_controls.qmd` (population density).
- The Ballotpedia HTML cache under `data/raw/ballotpedia/html/` is the expensive
  artifact; skip `01a` / `01b` if it is already present.
- The `01c` / `01d` integrity-check chunks stop the render if any expected raw
  file is missing or malformed, printing the source URL.
