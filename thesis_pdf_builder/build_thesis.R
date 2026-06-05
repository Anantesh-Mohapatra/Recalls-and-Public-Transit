# =============================================================================
# build_thesis.R
# Purpose : Assemble the thesis PDF from `BPE Thesis.md` (the single source of
#           prose) by replacing each figure/table placeholder with the real
#           artifact from output/, then rendering to PDF via Quarto.
# Source  : BPE Thesis.md  (prose; never edited by this script)
# Outputs : thesis_pdf_builder/thesis.qmd          (generated; do not hand-edit)
#           thesis_pdf_builder/_frontmatter.tex     (generated title page + TOC)
#           thesis_pdf_builder/thesis.pdf
# Run     : Rscript thesis_pdf_builder/build_thesis.R   (from the repo root)
#
# How it stays in sync with prose edits:
#   Placeholders are matched by their *number* ("Figure N" / "Table N"); the
#   FIGURES / TABLES maps are the single source of wiring (which file + caption
#   go to each number). Reword or move prose freely; as long as the
#   `[Figure N: ...]` / `[Table N ...]` line is present, the right artifact lands
#   there on rebuild. To rewire an artifact or caption, edit FIGURES / TABLES.
# =============================================================================

suppressWarnings(suppressMessages(library(here)))
here::i_am("_quarto.yml")

# -----------------------------------------------------------------------------
# Title-page metadata. Title and author are read verbatim from the first two
# lines of BPE Thesis.md; everything else is set here. Edit the institutional
# lines if the program/school differs.
# -----------------------------------------------------------------------------
DOC_DATE        <- "June 2026"
SUBMISSION_LINE <- "A thesis submitted in partial fulfillment of the requirements of the degree:"
DEGREE_LINES    <- c("Bachelor of Science",
                     "Undergraduate College",
                     "Leonard N. Stern School of Business",
                     "New York University")

# Sections that overflow by ~1 line onto a near-empty page; give them a little
# extra text height so the orphan line is pulled back. Value = # of \baselineskip.
ENLARGE_SECTIONS <- c("Literature Review"                     = 1L,
                      "Theoretical Argument and Hypotheses"   = 1L)

# -----------------------------------------------------------------------------
# ARTIFACT MANIFEST  -- the one place to rewire artifacts / edit captions.
# Keyed by kind + number (placeholders are inconsistent: some name a file, e.g.
# Table 9 names none). Figures get an authored caption (descriptive, no
# interpretation). Tables reuse the title + footer baked into their .tex.
# -----------------------------------------------------------------------------
FIGURES <- list(
  `1` = list(file = "fig_petitions_by_year.png", width = "\\linewidth",
             caption = "Petition-filing agency-city-years per calendar year."),
  `2` = list(file = "fig_outcome_dist.png", width = "\\linewidth",
             caption = "Distribution of transit capital spending, raw and logged."),
  `3` = list(file = "fig_coverage_heatmap.png", width = "\\linewidth",
             caption = "NTD reporting coverage by year and group."),
  `4` = list(file = "fig_capital_by_tier.png", width = "\\linewidth",
             caption = "Mean log(transit capital) by coverage tier and calendar year."),
  `5` = list(file = "fig_eventstudy_A_extended.png", width = "\\linewidth",
             caption = "Model A – extended-coverage event-study."),
  `6` = list(file = "fig_eventstudy.png", width = "\\linewidth",
             caption = "Model A – HQ-anchored event-study."),
  `7` = list(file = "fig_eventstudy_A_restricted.png", width = "\\linewidth",
             caption = "Model A – restricted-coverage event-study."),
  `8` = list(file = "fig_modelB_coef.png", width = "\\linewidth",
             caption = "Model B – petition effect on transit capital by coverage tier.")
)

TABLES <- list(
  `1`  = list(file = "tab_cascade.tex"),
  `2`  = list(file = "tab_sample_stats_A.tex"),
  `3`  = list(file = "tab_sample_stats_B.tex"),
  `4`  = list(file = "modelA_cascade.tex"),
  `5`  = list(file = "tab_robust_modelA.tex"),
  `6`  = list(file = "tab_robust_operating_A.tex"),
  `7`  = list(file = "modelB_cascade.tex"),
  `8`  = list(file = "modelB_margins.tex"),
  `9`  = list(file = "tab_robust_modelB.tex"),
  `10` = list(file = "tab_robust_operating_B.tex")
)

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
MD_PATH   <- here("BPE Thesis.md")
BUILD_DIR <- here("thesis_pdf_builder")
QMD_PATH  <- file.path(BUILD_DIR, "thesis.qmd")
FM_PATH   <- file.path(BUILD_DIR, "_frontmatter.tex")
PRE_PATH  <- file.path(BUILD_DIR, "_preamble.tex")
FIG_DIR   <- here("output", "figures")
TAB_DIR   <- here("output", "tables")

stopifnot(file.exists(MD_PATH))
abs_fwd   <- function(p) normalizePath(p, winslash = "/", mustWork = TRUE)
raw_latex <- function(...) c("```{=latex}", c(...), "```")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Decode the exact LaTeX embedded in a CodeCogs equation URL (lossless).
decode_codecogs <- function(url) {
  s <- url
  if (grepl("latex=", s, fixed = TRUE)) {
    s <- sub("^.*?latex=", "", s)
  } else if (grepl("svg.image?", s, fixed = TRUE)) {
    s <- sub("^.*?svg\\.image\\?", "", s)
  } else {
    s <- sub("^[^?]*\\?", "", s)
  }
  s <- sub("#.*$", "", s)
  s <- gsub("&space;", " ", s, fixed = TRUE)
  s <- gsub("&plus;",  "+", s, fixed = TRUE)
  s <- gsub("&minus;", "-", s, fixed = TRUE)
  s <- gsub("&amp;",   "&", s, fixed = TRUE)
  s <- utils::URLdecode(s)
  s <- gsub("\\\\", "\\", s, fixed = TRUE)
  s <- gsub("\\(", "(", s, fixed = TRUE)
  s <- gsub("\\)", ")", s, fixed = TRUE)
  trimws(s)
}

# Escape bare % and _ for LaTeX inside inlined .tex, preserving tabularray's %%
# comments and anything already escaped (\% or \_). & is a column separator.
sanitize_tex <- function(x) {
  x <- gsub("\\%", "@@PESC@@", x, fixed = TRUE)
  x <- gsub("\\_", "@@UESC@@", x, fixed = TRUE)
  x <- gsub("%%",  "@@PCOM@@", x, fixed = TRUE)
  x <- gsub("%",   "\\%",      x, fixed = TRUE)
  x <- gsub("_",   "\\_",      x, fixed = TRUE)
  x <- gsub("@@PCOM@@", "%%",  x, fixed = TRUE)
  x <- gsub("@@PESC@@", "\\%", x, fixed = TRUE)
  x <- gsub("@@UESC@@", "\\_", x, fixed = TRUE)
  x
}

# Keep tables within the page.
#  - talltblr (modelsummary/tinytable) regression tables can be tall enough to
#    run into the footer; \footnotesize shrinks them (and their inside caption)
#    to fit, and also narrows them as a width guard.
#  - kableExtra threeparttable tables are narrow and already fit; they are left
#    as-is so threeparttable can size its footnote to the table width (wrapping
#    them in a box defeats that measurement and makes the note span full width).
#  - a bare tabular (no footnote) gets an adjustbox max-width guard.
wrap_fit <- function(tex) {
  if (any(grepl("\\begin{talltblr}", tex, fixed = TRUE))) {
    bi <- grep("\\begin{talltblr}", tex, fixed = TRUE)[1]
    tex[bi] <- sub("\\begin{talltblr}", "\\footnotesize\\begin{talltblr}", tex[bi], fixed = TRUE)
    return(tex)
  }
  if (any(grepl("\\begin{threeparttable}", tex, fixed = TRUE))) return(tex)
  bi <- grep("\\begin{tabular}", tex, fixed = TRUE)[1]
  ei <- grep("\\end{tabular}",   tex, fixed = TRUE)
  if (is.na(bi) || !length(ei)) return(tex)
  ei <- ei[length(ei)]
  tex[bi] <- sub("\\begin{tabular}", "\\adjustbox{max width=\\linewidth}{\\begin{tabular}",
                 tex[bi], fixed = TRUE)
  tex[ei] <- sub("\\end{tabular}", "\\end{tabular}}", tex[ei], fixed = TRUE)
  tex
}

# Escape LaTeX specials in a plain-text title-page field.
tex_escape <- function(s) {
  s <- gsub("\\", "\\textbackslash{}", s, fixed = TRUE)
  for (p in list(c("&","\\&"), c("%","\\%"), c("#","\\#"), c("_","\\_"),
                 c("$","\\$"), c("{","\\{"), c("}","\\}"),
                 c("~","\\textasciitilde{}"), c("^","\\textasciicircum{}"))) {
    s <- gsub(p[1], p[2], s, fixed = TRUE)
  }
  s
}

# Figures cap height at 0.42\textheight so a tall figure can't dominate a page;
# keepaspectratio prevents distortion. [ht] floats keep them near the reference,
# and same-type float order preserves the placeholder numbering (1..8).
figure_block <- function(num) {
  spec <- FIGURES[[as.character(num)]]
  if (is.null(spec)) stop("No manifest entry for Figure ", num)
  path <- abs_fwd(file.path(FIG_DIR, spec$file))
  c("```{=latex}",
    "\\begin{figure}[ht]",
    "\\centering",
    sprintf("\\includegraphics[width=%s,height=0.42\\textheight,keepaspectratio]{%s}",
            spec$width, path),
    sprintf("\\caption{%s}", spec$caption),
    "\\end{figure}",
    "```")
}

table_block <- function(num) {
  spec <- TABLES[[as.character(num)]]
  if (is.null(spec)) stop("No manifest entry for Table ", num)
  tex_path <- file.path(TAB_DIR, spec$file)
  if (!file.exists(tex_path)) stop("Missing table file: ", tex_path)
  tex <- readLines(tex_path, encoding = "UTF-8", warn = FALSE)
  tex <- sub("\\begin{table}", "\\begin{table}[ht]", tex, fixed = TRUE)
  tex <- sanitize_tex(tex)
  tex <- wrap_fit(tex)
  c("```{=latex}", tex, "```")
}

# Regexes
EQ_RE      <- "^\\[!\\[\\]\\[image[0-9]+\\]\\]\\((.*)\\)\\s*$"
IMGDEF_RE  <- "^\\s*\\[image[0-9]+\\]:"
PH_RE      <- "^\\s*\\\\?\\[\\s*(Figure|Table)\\s+([0-9]+).*?\\\\?\\]\\s*$"
HEADING_RE <- "^#\\s+(.*?)\\s*$"

splittable <- function(ln) {
  st <- trimws(ln)
  nzchar(st) && !grepl("^#", st) && !grepl("^\\[\\^", st) &&
    !grepl(IMGDEF_RE, ln) && !grepl(EQ_RE, ln) && !grepl(PH_RE, ln)
}

# -----------------------------------------------------------------------------
# Read source, split off title/author, transform body
# -----------------------------------------------------------------------------
lines <- readLines(MD_PATH, encoding = "UTF-8", warn = FALSE)
heading_idx <- which(grepl("^#\\s", lines))[1]
if (is.na(heading_idx)) stop("No '# ' heading found in ", MD_PATH)

pre  <- lines[seq_len(heading_idx - 1L)]
body <- lines[heading_idx:length(lines)]

pre_nonempty <- trimws(pre[nzchar(trimws(pre))])
if (length(pre_nonempty) < 2L) stop("Could not find title + author lines.")
DOC_TITLE  <- pre_nonempty[1]
DOC_AUTHOR <- pre_nonempty[2]

used_fig <- integer(0); used_tab <- integer(0); out <- character(0)
enlarge_active <- 0L
for (i in seq_along(body)) {
  ln <- body[i]
  if (grepl(IMGDEF_RE, ln)) next                        # drop base64 image defs

  m_eq <- regmatches(ln, regexec(EQ_RE, ln))[[1]]       # equation image -> math
  if (length(m_eq) >= 2L && grepl("codecogs", m_eq[2], ignore.case = TRUE)) {
    out <- c(out, "", "$$", decode_codecogs(m_eq[2]), "$$", ""); next
  }

  m_ph <- regmatches(ln, regexec(PH_RE, ln))[[1]]       # placeholder -> artifact
  if (length(m_ph) >= 3L) {
    kind <- m_ph[2]; num <- as.integer(m_ph[3])
    if (kind == "Figure") { out <- c(out, "", figure_block(num), ""); used_fig <- c(used_fig, num) }
    else                  { out <- c(out, "", table_block(num),  ""); used_tab <- c(used_tab, num) }
    next
  }

  hm <- regmatches(ln, regexec(HEADING_RE, ln))[[1]]    # level-1 "# ..." heading
  if (length(hm) >= 2L) {
    title <- hm[2]
    # Adjust text height BEFORE the section's \clearpage so the new value is in
    # effect when the new page starts (\textheight is read at page start, not
    # mid-page). The prior section's trailing page keeps its own height (its
    # \pagegoal was already locked), so its orphan stays put. A delta to the new
    # target lets adjacent enlarged sections coexist without resetting between.
    desired <- if (title %in% names(ENLARGE_SECTIONS)) ENLARGE_SECTIONS[[title]] else 0L
    if (desired != enlarge_active) {
      out <- c(out, "", raw_latex(sprintf("\\addtolength{\\textheight}{%d\\baselineskip}",
                                          desired - enlarge_active)), "")
      enlarge_active <- desired
    }
    out <- c(out, ln)                                   # the heading
    if (grepl("^Bibliography\\b", title)) {             # hanging-indent references
      # \hangindent via \everypar applies to every entry, including the first
      # after the heading (which \parindent-based indenting would skip).
      out <- c(out, "", raw_latex("\\setlength{\\parindent}{0pt}",
                                  "\\everypar{\\hangindent=0.5in\\hangafter=1}"), "")
    }
    next
  }

  # Prose: strip Google-Docs indentation and trailing hard-break spaces; escape
  # bare $ (currency) so pandoc does not read it as a math delimiter.
  out <- c(out, gsub("$", "\\$", trimws(ln), fixed = TRUE))
  # Google-Docs exports each paragraph as its own hard-break line (no blank
  # between). Insert a blank line between consecutive prose lines so each is a
  # real paragraph and the inter-paragraph spacing applies.
  if (splittable(ln) && i < length(body) && splittable(body[i + 1L])) out <- c(out, "")
}
if (enlarge_active != 0L)
  out <- c(out, "", raw_latex(sprintf("\\addtolength{\\textheight}{%d\\baselineskip}", -enlarge_active)), "")

# -----------------------------------------------------------------------------
# Coverage report + glyph-coverage check
# -----------------------------------------------------------------------------
exp_fig <- as.integer(names(FIGURES)); exp_tab <- as.integer(names(TABLES))
message(sprintf("Figures placed: %d/%d  | Tables placed: %d/%d",
                length(unique(used_fig)), length(exp_fig),
                length(unique(used_tab)), length(exp_tab)))
for (m in setdiff(exp_fig, used_fig)) warning("Figure ", m, " manifest entry has no placeholder.")
for (m in setdiff(used_fig, exp_fig)) warning("Figure ", m, " placeholder has no manifest entry.")
for (m in setdiff(exp_tab, used_tab)) warning("Table ", m, " manifest entry has no placeholder.")
for (m in setdiff(used_tab, exp_tab)) warning("Table ", m, " placeholder has no manifest entry.")

# Warn about any non-ASCII prose char that is neither in _preamble.tex's
# newunicodechar map nor common typographic/Latin text -- it would otherwise
# risk rendering as a blank box. (Mapped set is read from the preamble so the
# two stay in sync.)
mapped <- if (file.exists(PRE_PATH)) {
  pl <- readLines(PRE_PATH, encoding = "UTF-8", warn = FALSE)
  unlist(regmatches(pl, regexpr("(?<=\\\\newunicodechar\\{).", pl, perl = TRUE)))
} else character(0)
prose_for_glyph <- body[!grepl(IMGDEF_RE, body) & !grepl(EQ_RE, body)]
prose_chars <- unique(unlist(strsplit(paste(prose_for_glyph, collapse = ""), "")))
is_safe <- function(cp) (cp >= 0x00A0 && cp <= 0x024F) ||
  cp %in% c(0x2018, 0x2019, 0x201C, 0x201D, 0x2013, 0x2014, 0x2026, 0x2009, 0x202F)
for (ch in prose_chars) {
  cp <- utf8ToInt(ch)
  if (length(cp) != 1L || cp <= 127L) next
  if (ch %in% mapped || is_safe(cp)) next
  warning(sprintf("Unmapped glyph U+%04X (%s) in prose; add a \\newunicodechar to _preamble.tex.", cp, ch))
}

# -----------------------------------------------------------------------------
# Title page + TOC (front matter, injected after \begin{document})
# -----------------------------------------------------------------------------
deg <- c(sprintf("{%s\\par}", tex_escape(DEGREE_LINES[1])),
         sprintf("\\vspace{2pt}{%s\\par}", vapply(DEGREE_LINES[-1], tex_escape, character(1))))
frontmatter <- c(
  "\\begin{titlepage}",
  "\\centering",
  "\\thispagestyle{empty}",
  "\\singlespacing",
  "\\setlength{\\parskip}{0pt}",
  "\\vspace*{1.5in}",
  sprintf("{\\LARGE\\bfseries %s\\par}", tex_escape(DOC_TITLE)),
  "\\vspace{0.8in}",
  sprintf("{\\large %s\\par}", tex_escape(DOC_AUTHOR)),
  "\\vspace{0.5in}",
  sprintf("{%s\\par}", tex_escape(DOC_DATE)),
  "\\vspace{0.8in}",
  sprintf("{%s\\par}", tex_escape(SUBMISSION_LINE)),
  "\\vspace{0.2in}",
  deg,
  "\\vfill",
  "\\end{titlepage}",
  "\\clearpage",
  "\\pagenumbering{roman}",
  "\\tableofcontents",
  "\\clearpage",
  "\\pagenumbering{arabic}",
  "% Lock in body spacing after the front matter (single source of spacing).",
  "\\setstretch{1.5}",
  "\\setlength{\\parindent}{0pt}",
  "\\setlength{\\parskip}{10pt plus 2pt minus 1pt}"
)
con <- file(FM_PATH, open = "w", encoding = "UTF-8"); writeLines(frontmatter, con); close(con)

# -----------------------------------------------------------------------------
# Assemble and write thesis.qmd
# -----------------------------------------------------------------------------
yaml <- c(
  "---",
  "format:",
  "  pdf:",
  "    documentclass: article",
  "    fontsize: 12pt",
  "    geometry: margin=1in",
  "    number-sections: true",
  "    toc: false",
  "    colorlinks: true",
  "    linkcolor: black",
  "    urlcolor: blue",
  "    toccolor: black",
  "    keep-tex: false",
  "    fig-pos: 'ht'",
  "    include-in-header: _preamble.tex",
  "    include-before-body: _frontmatter.tex",
  "---",
  ""
)
con <- file(QMD_PATH, open = "w", encoding = "UTF-8"); writeLines(c(yaml, out), con); close(con)
message("Wrote ", QMD_PATH)

# -----------------------------------------------------------------------------
# Render to PDF. The website project's `output-dir: docs` routes the PDF into
# docs/; pull the fresh copy back next to the qmd and remove the stray copy.
# -----------------------------------------------------------------------------
if (!requireNamespace("quarto", quietly = TRUE)) {
  stop("The 'quarto' R package is required. install.packages('quarto')")
}
quarto::quarto_render(input = QMD_PATH, output_format = "pdf")

want_pdf <- file.path(BUILD_DIR, "thesis.pdf")
docs_pdf <- here("docs", "thesis_pdf_builder", "thesis.pdf")
nrm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)
src <- NULL
if (file.exists(docs_pdf)) {
  src <- docs_pdf
} else {
  cand <- list.files(here(), pattern = "^thesis\\.pdf$", recursive = TRUE, full.names = TRUE)
  cand <- cand[nrm(cand) != nrm(want_pdf)]
  if (length(cand)) src <- cand[which.max(file.mtime(cand))]
}
if (!is.null(src) && nrm(src) != nrm(want_pdf)) {
  file.copy(src, want_pdf, overwrite = TRUE)
  message("Copied ", src, " -> ", want_pdf)
}
docs_out <- here("docs", "thesis_pdf_builder")
if (dir.exists(docs_out)) unlink(docs_out, recursive = TRUE)

if (file.exists(want_pdf)) message("DONE: ", want_pdf) else
  warning("Render finished but thesis.pdf was not found next to the qmd.")
