# =============================================================================
# run_all.R
# Purpose : Rebuild everything end to end. Render the analysis pipeline in
#           dependency order, then assemble the thesis PDF.
# Run     : Rscript run_all.R    (or source("run_all.R") in an R session)
# Needs   : the pinned renv environment (renv::restore()), a Census API key for
#           stage 04 (tidycensus::census_api_key(...)), and a LaTeX engine for
#           the thesis PDF (e.g. quarto install tinytex). Raw inputs under
#           data/raw/ must be present; the acquisition stages read/validate
#           them rather than re-downloading.
# Output  : rendered HTML in docs/; LaTeX tables in output/tables/; figures in
#           output/figures/; the analysis panel at data/final/panel.rds; the
#           thesis at thesis_pdf_builder/thesis.pdf.
# =============================================================================

if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("The 'quarto' R package is required. Run renv::restore() first.")
}

stages <- c(
  "01a_scrape_ballotpedia.qmd",
  "01b_parse_ballotpedia.qmd",
  "01c_collect_ntd.qmd",
  "01d_collect_ntd_operating.qmd",
  "02a_clean_recalls.qmd",
  "02b_manual_recode_outcomes.qmd",
  "03b_extract_ntd.qmd",
  "03c_match_roster.qmd",
  "03d_sample_construction.qmd",
  "03f_extract_ntd_operating.qmd",
  "04_build_controls.qmd",
  "05_build_panel.qmd",
  "06_eda.qmd",
  "07_models.qmd",
  "08_extended.qmd",
  "09_robustness.qmd"
)

for (s in stages) {
  message("\n=== Rendering ", s, " ===")
  quarto::quarto_render(s)
}

# Assemble the thesis PDF from the prose + the figures/tables just produced.
builder <- "thesis_pdf_builder/build_thesis.R"
if (file.exists(builder)) {
  message("\n=== Building thesis PDF ===")
  status <- system2("Rscript", builder)
  if (status != 0) {
    warning("Thesis PDF build returned a non-zero status (the analysis stages ",
            "completed). The PDF step needs a LaTeX engine; see ",
            "'quarto install tinytex'.")
  }
} else {
  message("\nThesis builder (", builder, ") not found; skipping the PDF step.")
}

message("\nDone. Analysis HTML in docs/; thesis (if built) at ",
        "thesis_pdf_builder/thesis.pdf.")
