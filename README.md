# The Impact of Recall Activity on Public Transit Investment

Public transit investments take years to bear results, but ask the public to bear their cost up front. By letting citizens remove a leader between elections, the recall can exacerbate the political danger of that timing mismatch. An official may find it harder to absorb the early backlash over a project's cost and stay in office long enough for the benefits to arrive. If the threat of removal steers officials away from long-term investment, an institutional tool meant to empower voters may instead leave cities under-investing in the infrastructure they need.

This is replication code for a thesis on mayoral recall activity and municipal transit capital spending in US municipalities, 2014-2024. The analysis links recall events (Ballotpedia) to transit agency finances (National Transit Database) and estimates an event study (Model A) and a petition difference-in-differences (Model B) on an agency-city-year panel.

## Requirements

- R and the [Quarto CLI](https://quarto.org).
- Package versions are pinned with [renv](https://rstudio.github.io/renv/) (`renv.lock`). Opening the project activates the environment through `.Rprofile`. On a fresh clone, reproduce the environment with:
  ```r
  renv::restore()
  ```
  (`00_setup.R` is the original one-time bootstrap that built the environment; `renv::restore()` is the path for replication.)
- A free [Census API key](https://api.census.gov/data/key_signup.html), needed only for stage 04 (population density):
  ```r
  tidycensus::census_api_key("YOUR_KEY", install = TRUE)
  ```
- A LaTeX engine, needed only to build the thesis PDF (the analysis stages do not require it):
  ```bash
  quarto install tinytex
  ```

## Reproducing the results

All inputs are committed under `data/raw/`, and the cleaned intermediate data and the final analysis panel (`data/final/panel.rds`) are committed as well, so the results can be regenerated without re-running data acquisition.

**Everything, one command.** Rebuilds from the raw data in dependency order, then assembles the thesis PDF:

```bash
Rscript run_all.R
```

**Just the analysis tables and figures**, regenerated from the committed panel:

```bash
quarto render 06_eda.qmd 07_models.qmd 08_extended.qmd 09_robustness.qmd
```

**Just the thesis PDF**, assembled from the committed figures and tables:

```bash
Rscript thesis_pdf_builder/build_thesis.R
```

`run_all.R` renders the stages in the order listed below, then runs the thesis builder. Outputs: rendered HTML in `docs/`, LaTeX tables in `output/tables/`, figures in `output/figures/`, the analysis panel at `data/final/panel.rds`, and the thesis at `thesis_pdf_builder/thesis.pdf`.

## Pipeline

Stages run in filename order. Each reads the file(s) the earlier stages wrote.

| Stage | Produces |
|-------|----------|
| `00_setup.R` | installs packages (run once; not part of the render) |
| `01a_scrape_ballotpedia` | Ballotpedia recall-page HTML cache (`data/raw/ballotpedia/html/`) |
| `01b_parse_ballotpedia` | parsed recalls -> `data/raw/ballotpedia/recalls_raw.rds` |
| `01c_collect_ntd` | validates the NTD capital + agency-information raw files |
| `01d_collect_ntd_operating` | validates the NTD operating-expense raw files |
| `02a_clean_recalls` | cleaned recall panel -> `data/cleaned/recalls_clean.rds` |
| `02b_manual_recode_outcomes` | recodes multi-outcome / underway rows in place (+ v1 backup) |
| `03b_extract_ntd` | NTD capital panel + agency directory -> `ntd_transit.rds`, `agency_directory.rds` |
| `03c_match_roster` | recall-city to NTD-agency match roster -> `roster_ntd.rds` |
| `03d_sample_construction` | Model A / Model B samples -> `sample_model{A,B}_pairs.rds` |
| `03f_extract_ntd_operating` | NTD operating panel -> `ntd_operating.rds` |
| `04_build_controls` | population density + county unemployment -> `controls.rds` (needs Census API key) |
| `05_build_panel` | agency-city-year analysis panel -> `data/final/panel.rds` |
| `06_eda` | descriptive figures, coverage diagnostics, sample and cascade tables |
| `07_models` | headline Model A (event study) and Model B (petition DiD) |
| `08_extended` | extended- and restricted-coverage models, COVID interaction, cascade tables |
| `09_robustness` | pre-trend, event-window, operating-expense, and local-government checks |

Two stages reach the network on a fresh run and cache locally: stage 04 (Census Population Estimates via the API; BLS and Census crosswalk downloads) and the county map in stage 06 (Census boundary shapefiles via `tigris`). Stages 07-09 read only the committed panel and need no network.

## Building the thesis PDF

`thesis_pdf_builder/build_thesis.R` assembles the final document. It reads `BPE Thesis.md` (the prose), replaces each `[Figure N]` / `[Table N]` placeholder with the matching artifact from `output/figures/` and `output/tables/`, and renders to `thesis_pdf_builder/thesis.pdf`. Those artifacts must exist first; they are committed, and the analysis stages above regenerate them. The PDF step also needs a LaTeX engine. `run_all.R` runs this builder as its final step, so the one-command build produces the thesis along with the analysis output.

## Data sources

Every external dataset (URL, Socrata ID, coverage window, last-pulled date) is cataloged in `DATA_SOURCES.md`. The acquisition stages (`01*`) validate or read the cached raw files under `data/raw/`; some sources cannot be re-downloaded programmatically, so the raw files are shipped with the repository.

*AI coding agents helped to write the code in this repository and to draft this README. The thesis is my own writing.*
