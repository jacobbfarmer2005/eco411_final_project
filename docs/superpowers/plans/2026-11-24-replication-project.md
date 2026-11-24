# ECO 411 Replication Project (East et al. 2023): Full Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicate Table 3 and Figure 2 of East et al. (2023) and deliver the 5–7 page replication paper due **December 4, 2026**. Along the way, improve the existing Section 2 (ACS cleaning) and Section 3 (CZ panel) code so it is tested, portable and faithful to the authors' Stata code.

**Architecture:** Every analysis step is a function in `replication_files/R/*.R`, tested with `testthat` on toy or simulated data. Thin R Markdown runners call those functions in order: `section 2 R.Rmd` (clean ACS) → `section 3 R.Rmd` (CZ panel) → `section 4 R.Rmd` (regressions, Table 3, Figure 2). Results are written to `replication_files/output/`. The paper (`paper/paper.Rmd` → Word) reads only those output files, so it can be knitted without the microdata. All file locations come from one `project_paths()` function built on `here::here()`.

**Tech Stack:** R 4.6.1, dplyr (Section 2), data.table (Sections 3–4), ipumsr, haven, here, fixest, ggplot2, cowplot, testthat 3e, withr, rmarkdown/knitr with pandoc citeproc (Word output; no LaTeX is installed).

**Timeline (deadline Dec 4, 2026):**
- Tasks 1–5 (data and panel): by Nov 27.
- Tasks 6–10 (estimates, table, figure): by Nov 29.
- Task 11 (paper scaffold): Nov 29.
- Task 12 (group writes the prose): Nov 29 – Dec 2.
- Task 13 (final checks): Dec 3.

**Spec:** There is no separate spec document. Requirements come from:
- The user's requests: plan the entire project, and include the improvements to the existing Section 2 and 3 code. The group's agreed target (with Prof. Flynn) is **Table 3 and Figure 2**.
- `Replication Project Assignment.pdf`:
  - About 2,000 words (5–7 pages), 1–2 figures, 1–2 tables, at least 5 references.
  - Sections: Introduction, Background, Data, Empirical Strategy (*in your own words*), Results (including discrepancies), Conclusion.
  - Follow the authors' data and empirical strategy as closely as possible.
- Fidelity reference: `original_files/code/0_EHLMV_clean_emp_data_FINAL.do`, `1_EHLMV_clean_wage_data_FINAL.do`, `2_EHLMV_results_emp_FINAL.do` (lines ~300–520) and `3_EHLMV_results_wages_FINAL.do` (lines ~25–130).
- Existing code being improved: `replication_files/section 3 R.Rmd` and the code embedded in `replication_files/Section 2.html`. The Section 2 `.Rmd` source is missing from the repo, so it is recovered from the knitted HTML in Task 2.

## Background for the implementer

- **Paper:** East, Hines, Luck, Mansour & Velásquez (2023), "The Labor Market Effects of Immigration Enforcement," *JOLE* 41(4). PDF: `original_files/immigration_paper.pdf`.
- **Table 3:** effect of Secure Communities (SC) on LEFB workers (likely undocumented: **L**ow-**E**ducated, **F**oreign-**B**orn, high school or less). Columns 1–3 are the employment share (all / female / male). Columns 4–6 are the log hourly wage (all / female / male). Unit: commuting zone (CZ) × year, 2005–2014, 740 CZs, so 7,400 rows.
- **Figure 2:** distributed-lag event studies for LEFB (panels A, B) and US-born (panels C, D) employment share and log wage. So the panel also needs **US-born** employment share and **US-born** log wage.
- **Employment share** = 100 × (group employment in CZ-year) / (all people aged 20–64 in the CZ in 2005).
- **CZ wage** = log of the af-weighted mean, across the CZ's CPUMAs, of the *unweighted* mean across industry×occupation cells, of the perwt-weighted mean full-time winsorized hourly wage within each cell. The existing code already follows this; keep it.
- **Paper targets the panel should come close to** (Table 3 / Table 4, "Y mean", pop2000-weighted):

  | variable | paper mean | paper non-missing N |
  |---|---|---|
  | emp_share_lefb | 6.75 | 7,400 |
  | emp_share_lefb_f | 2.55 | 7,400 |
  | emp_share_lefb_m | 4.21 | 7,400 |
  | emp_share_usb | 58.61 | 7,400 |
  | lnw_lefb | 2.74 | 7,383 |
  | lnw_lefb_f | 2.59 | 7,331 |
  | lnw_lefb_m | 2.81 | 7,367 |
  | lnw_usb | 3.18 | 7,400 |

### What is wrong with the current code (what this plan fixes)

1. **Not portable.** Paths are hard-coded to one teammate's computer (`C:/Users/Kuthn/...`), and `section 3 R.Rmd` points at `data/data`, which no longer exists after the move to `original_files/`.
2. **The Section 2 source is lost.** Only `Section 2.html` exists.
3. **The raw data is unusable.** `replication_files/ipums_data.RData` is truncated: R fails with `lzma decoding result 10`. The raw `usa_00001.dat` is not in the repo.
4. **Memory.** `read_acs` loads every person of every age before filtering.
5. **Fidelity gaps compared with the Stata code:**
   - Employment does not drop workers whose `occ2010` falls outside the 2005 reference set of occupations (Stata's `temp_ACS_occ_edu_dropmilpa` merge, which also drops `occ2010 == 9920`).
   - The military/public-administration cut is `ind1990 900–940`. Stata's is `893 < ind1990 <= 940`.
6. **False-alarm check.** `check_means()` compares *person-level* wage means with the paper's *CZ-level* means and always warns. The real comparison belongs at CZ level in Section 3.
7. **Missing outcomes.** Section 3 builds only the all-LEFB wage. Table 3 also needs female and male LEFB wages, and Figure 2 needs the US-born wage.
8. **NaN wages.** `weighted.mean(..., na.rm = TRUE)` returns `NaN` for a CZ-year with no workers in a group. This should be `NA`.
9. **No tests.**

## Global Constraints

- R 4.6.1. Use only packages already installed: dplyr, data.table, ipumsr, haven, here, fixest, ggplot2, cowplot, testthat, withr, tibble, knitr, rmarkdown. Do not install new packages.
- The paper renders to Word (`word_document`) because no LaTeX is installed. Citations use pandoc citeproc with `paper/references.bib`.
- Estimation must match the Stata specification: `reghdfe y SC_frac [bartiks] [aweight=pop2000], absorb(year czone i.czone#c.year) vce(cluster czone)`. In fixest this is `feols(y ~ SC_frac [+ bartiks] | czone[year] + year, weights = ~pop2000, cluster = ~czone)`. The Bartik controls are `shift_share_sample_fb` and `shift_share_sample_usb`, used for every outcome.
- The paper's prose is written by the group (Task 12). The assignment requires the Empirical Strategy section to be in the students' own words. The plan supplies structure, facts, numbers, tables, figures and references, not finished prose.
- Run all commands from the repo root `eco411_final_project/`. `Rscript` means `Rscript` on Windows. In the WSL shell it is `"/mnt/c/Program Files/R/R-4.6.1/bin/Rscript.exe"`. Windows R cannot read WSL-only paths such as `/tmp`.
- To knit outside RStudio, set `RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'`.
- Never commit raw or cleaned microdata: `replication_files/data/raw/`, `replication_files/data/clean/`, `*.dat`, `*.dat.gz`.
- Keep each file's existing idiom: dplyr pipes in Section 2 code, data.table in Section 3 code.
- Do not delete teammates' files (`data conversion.Rmd`, `ipums_data.RData`, `load_data.Rmd`, `Section 2.html`, `section 3.html`). Deleting them is the group's call.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`

## Review Focus

1. **A CZ-year with no full-time workers in a group** (common for LEFB women in small CZs). The wage must be `NA`, never `NaN` or `-Inf`, so non-missing counts land near 7,383 / 7,331 / 7,367. Pinned in Task 4 (`wmean_na`, `wage_cpuma`, `make_outcomes` tests).
2. **Distributed-lag leads at the end of the panel and lags before 2005.**
   - `F1` is missing for 2014 and `F2` for 2013–2014. These must stay `NA`, so those rows drop from the event-study regression exactly as in Stata. They must not be filled with 0 or 1.
   - `L1` and `L2` are filled with 0 for 2005 and for 2005–2006 respectively (SC did not exist before 2008).
   - Pinned in Task 6 (`add_sc_leads_lags` tests).
3. **Raw ACS file missing, or only the truncated `ipums_data.RData` present.** The code must stop immediately with a message naming the missing path, not fail deep inside ipumsr. Pinned in Task 1 (`check_inputs` test). The `ACS_DAT` override is pinned there too.
4. **Table 3 column order.** The paper's order is All / Females / Males for both employment and wages. Swapping female and male columns is an easy, silent mistake. Pinned in Task 8 (`format_table3` test checks each column against its outcome).
5. **Workers in occupations first seen after 2005, or in military/public administration.** They must not count as employed, matching Stata. Pinned in Task 2 (`flag_employment`, `flag_milpa` tests).

`compare_to_paper()` must also not mutate the shared `PAPER_TARGETS` table by reference; that is pinned in Task 5.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `.gitignore` | modify | Ignore raw and clean microdata |
| `replication_files/R/paths.R` | create | `project_paths()`, `check_inputs()` |
| `replication_files/R/clean_acs.R` | create | Section 2 functions: read → flag → wages → checks → slim |
| `replication_files/R/build_panel.R` | create | Section 3 functions: CPUMA aggregates → CZ panel → outcomes → paper comparison |
| `replication_files/tests/testthat/helper-setup.R` | create | Sources the `R/` files; `toy_person()` builder |
| `replication_files/tests/testthat/test-paths.R` | create | Tests for paths.R |
| `replication_files/tests/testthat/test-clean_acs.R` | create | Tests for clean_acs.R |
| `replication_files/tests/testthat/test-build_panel.R` | create | Tests for build_panel.R |
| `replication_files/section 2 R.Rmd` | create | Thin Section 2 runner (restores the lost source) |
| `replication_files/section 3 R.Rmd` | modify | Thin Section 3 runner |
| `README.md` | modify | How to get the data and run everything |
| `replication_files/R/estimate.R` | create | Leads/lags, two-way fixed effects SC model, Table 3 estimates, distributed-lag event study |
| `replication_files/R/tables.R` | create | Paper-style Table 3 and the comparison with the paper |
| `replication_files/R/figures.R` | create | Figure 2 (4-panel event study) |
| `replication_files/tests/testthat/test-estimate.R` | create | Simulated-panel tests for estimate.R |
| `replication_files/tests/testthat/test-tables.R` | create | Tests for tables.R |
| `replication_files/tests/testthat/test-figures.R` | create | Tests for figures.R |
| `replication_files/section 4 R.Rmd` | create | Thin results runner that writes `output/` |
| `replication_files/output/` | create (committed) | `table3_estimates.csv`, `table3_compare.csv`, `event_study.csv`, `figure2.png` |
| `paper/paper.Rmd` | create | The replication paper (Word output) |
| `paper/references.bib` | create | Bibliography (at least 5 entries) |

---

### Task 1: Commit the reorganization, ignore data, add shared paths and test harness

**Files:**
- Modify: `.gitignore`
- Create: `replication_files/R/paths.R`
- Create: `replication_files/tests/testthat/helper-setup.R`
- Test: `replication_files/tests/testthat/test-paths.R`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `project_paths()` returns a named list of character paths: `raw_ddi`, `raw_dat`, `bartik`, `cw`, `policy`, `acs_clean`, `cz_panel`, `output`.
  - `check_inputs(paths)`, where `paths` is a character vector. It returns `invisible(TRUE)`, or stops with `"missing input files:\n<path>\n<path>"`.
  - `toy_person(...)` (test helper) returns a tibble with one row per element. Every ACS column has a default value; any argument overrides that column.

- [ ] **Step 1: Commit the existing file reorganization on its own**

The working tree already has the user's move of files into `original_files/` and `replication_files/`. Commit it unchanged, so later diffs show only this plan's work.

```bash
git add -A .
git status --short | head -40
git commit -m "Reorganize repo into original_files/ and replication_files/

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 2: Append data ignores to `.gitignore`**

Append these lines to the end of `.gitignore` and keep the existing four lines:

```
replication_files/data/raw/
replication_files/data/clean/
*.dat
*.dat.gz
```

- [ ] **Step 3: Write the test helper**

Create `replication_files/tests/testthat/helper-setup.R`:

```r
# Source every analysis file, so later tasks can add files to R/ without
# editing this helper.
for (f in list.files(here::here("replication_files", "R"), pattern = "\\.R$",
                     full.names = TRUE)) {
  source(f)
}

# One toy ACS person per element; any argument overrides that column.
toy_person <- function(...) {
  base <- list(
    year = 2005, statefip = 1, cpuma0010 = 1, gq = 1, perwt = 10,
    sex = 1, age = 30, bpl = 1, educ = 6, educd = 63, empstat = 1,
    classwkr = 2, classwkrd = 22, occ2010 = 4700, ind1990 = 591,
    wkswork2 = 6, uhrswork = 40, incwage = 30000, school = 1, cpi99 = 0.8
  )
  args <- list(...)
  base[names(args)] <- args
  tibble::as_tibble(base)
}
```

Create the `R/` folder: `mkdir -p replication_files/R`.

- [ ] **Step 4: Write the failing tests**

Create `replication_files/tests/testthat/test-paths.R`:

```r
test_that("project_paths points at author files that exist in the repo", {
  p <- project_paths()
  expect_true(file.exists(p$raw_ddi))
  expect_true(file.exists(p$bartik))
  expect_true(file.exists(p$cw))
  expect_true(file.exists(p$policy))
})

test_that("ACS_DAT overrides the raw data location", {
  withr::local_envvar(ACS_DAT = "D:/elsewhere/usa_00001.dat")
  expect_equal(project_paths()$raw_dat, "D:/elsewhere/usa_00001.dat")
})

test_that("check_inputs names every missing file", {
  err <- expect_error(check_inputs(c("nope1.dat", "nope2.dta")), "nope1.dat")
  expect_match(conditionMessage(err), "nope2.dta")
})

test_that("check_inputs passes when files exist", {
  expect_true(check_inputs(project_paths()$raw_ddi))
})
```

- [ ] **Step 5: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: FAIL with `could not find function "project_paths"`.

- [ ] **Step 6: Write `paths.R`**

Create `replication_files/R/paths.R`:

```r
# Shared file locations, built from the repo root so the code runs on any
# teammate's computer. Set the ACS_DAT environment variable to read the raw
# IPUMS .dat(.gz) from somewhere other than replication_files/data/raw/.

project_paths <- function() {
  raw_dir <- here::here("replication_files", "data", "raw")
  raw_candidates <- file.path(raw_dir, c("usa_00001.dat.gz", "usa_00001.dat"))
  raw_default <- raw_candidates[file.exists(raw_candidates)][1]
  if (is.na(raw_default)) raw_default <- raw_candidates[1]

  author <- here::here("original_files", "data")
  clean  <- here::here("replication_files", "data", "clean")

  list(
    raw_ddi   = here::here("replication_files", "usa_00001.xml"),
    raw_dat   = Sys.getenv("ACS_DAT", raw_default),
    bartik    = file.path(author, "final_bartik_acs_cpuma0010_updated.dta"),
    cw        = file.path(author, "cw_cpuma2010_czone.dta"),
    policy    = file.path(author, "policy_pop_cz_5_13_22.dta"),
    acs_clean = file.path(clean, "acs_person.rds"),
    cz_panel  = file.path(clean, "cz_panel.rds"),
    output    = here::here("replication_files", "output")
  )
}

check_inputs <- function(paths) {
  absent <- paths[!file.exists(paths)]
  if (length(absent)) stop("missing input files:\n", paste(absent, collapse = "\n"))
  invisible(TRUE)
}
```

- [ ] **Step 7: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `[ FAIL 0 | ... | PASS 7 ]` (the exact PASS count may differ; there must be 0 failures).

- [ ] **Step 8: Commit**

```bash
git add .gitignore replication_files/R replication_files/tests
git commit -m "Add shared project paths, data ignores, and test harness

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Section 2 cleaning functions, restored and fixed

**Files:**
- Create: `replication_files/R/clean_acs.R`
- Test: `replication_files/tests/testthat/test-clean_acs.R`

**Interfaces:**
- Consumes: `toy_person()` from Task 1.
- Produces (every function takes and returns a tibble unless noted):
  - `ACS_VARS` (character, 20 lowercase IPUMS names); `PANEL_VARS` (character, 10 names).
  - `read_acs(ddi_path, dat_path, chunk_size = 500000)` reads people aged 20–64 for 2005–2014 and keeps only `ACS_VARS`.
  - `check_acs_vars(acs)` stops if any `ACS_VARS` column is missing.
  - `flag_nativity_education(acs)` adds logicals `usb`, `fb`, `ls`, `lefb` and `male`.
  - `flag_milpa(acs)` adds logical `milpa`.
  - `occ_reference_set(acs)` returns a numeric vector of `occ2010` codes. It requires `milpa`.
  - `flag_employment(acs)` adds `milpa` and `emp`.
  - `restrict_wage_sample`, `convert_weeks`, `deflate_income`, `hourly_wage`, `winsorize_wage`, `flag_fulltime_wage`: same names as the existing code, adding `incwage`→NA, `weeks`, `real_inc`, `wage_raw`, `wage` and `wage_ft`.
  - `check_clean(acs)` returns `invisible(acs)` or stops.
  - `summarise_clean(acs)` returns a tibble with one row per year.
  - `slim_for_panel(acs)` keeps `PANEL_VARS`.
  - `save_clean(acs, path)` writes an RDS file.

- [ ] **Step 1: Write the failing tests**

Create `replication_files/tests/testthat/test-clean_acs.R`:

```r
test_that("check_acs_vars names a missing variable", {
  expect_error(check_acs_vars(dplyr::select(toy_person(), -cpi99)), "cpi99")
  expect_silent(check_acs_vars(toy_person()))
})

test_that("flag_nativity_education splits by birthplace and education", {
  a <- toy_person(bpl = c(1, 120, 121, 300), educ = c(6, 7, 6, 7)) |>
    flag_nativity_education()
  expect_equal(a$usb,  c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(a$lefb, c(FALSE, FALSE, TRUE, FALSE))
})

test_that("flag_milpa matches Stata sectors 11-12 (893 < ind1990 <= 940)", {
  a <- toy_person(ind1990 = c(893, 894, 920, 940, 941, NA)) |> flag_milpa()
  expect_equal(a$milpa, c(FALSE, TRUE, TRUE, TRUE, FALSE, FALSE))
})

test_that("occ_reference_set keeps only valid 2005 civilian occupations", {
  a <- toy_person(
    year    = c(2005, 2005, 2005, 2005, 2005, 2006),
    occ2010 = c(100,  9920, 200,  300,  400,  500),
    gq      = c(1,    1,    3,    1,    1,    1),
    educd   = c(63,   63,   63,   1,    63,   63),
    ind1990 = c(591,  591,  591,  591,  910,  591)
  ) |> flag_milpa()
  expect_equal(occ_reference_set(a), 100)
})

test_that("flag_employment drops group quarters, mil/pa, and post-2005 occupations", {
  a <- toy_person(
    year    = c(2005, 2006, 2006, 2006, 2006, 2006),
    occ2010 = c(100,  100,  100,  100,  999,  100),
    empstat = c(1,    1,    2,    1,    1,    1),
    gq      = c(1,    2,    1,    3,    1,    1),
    ind1990 = c(591,  591,  591,  591,  591,  920)
  ) |> flag_employment()
  expect_equal(a$emp, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE))
})

test_that("restrict_wage_sample applies each Stata exclusion", {
  a <- toy_person(
    wkswork2  = c(6,     0,     6,     6,     6,     6,     6,      6),
    uhrswork  = c(40,    40,    0,     40,    40,    40,    40,     40),
    school    = c(1,     1,     1,     2,     1,     1,     1,      1),
    classwkr  = c(2,     2,     2,     2,     1,     2,     2,      2),
    classwkrd = c(22,    22,    22,    22,    10,    29,    22,     22),
    incwage   = c(30000, 30000, 30000, 30000, 30000, 30000, 999999, 0)
  ) |> restrict_wage_sample()
  expect_equal(!is.na(a$incwage), c(TRUE, rep(FALSE, 7)))
})

test_that("convert_weeks uses interval midpoints", {
  a <- toy_person(wkswork2 = 0:6) |> convert_weeks()
  expect_equal(a$weeks, c(NA, 8.0, 20.8, 33.1, 42.4, 48.3, 51.9))
})

test_that("deflate_income converts to 2014 dollars", {
  a <- toy_person(year = c(2005, 2014), cpi99 = c(1.2, 0.9), incwage = 1000) |>
    deflate_income()
  expect_equal(a$real_inc, c(1000 * 1.2 / 0.9, 1000))
})

test_that("winsorize_wage clips at the 2.5th and 97.5th percentiles and keeps NA", {
  a <- tibble::tibble(wage_raw = c(1:100, NA)) |> winsorize_wage()
  expect_equal(range(a$wage, na.rm = TRUE), c(3, 98))
  expect_true(is.na(a$wage[101]))
})

test_that("flag_fulltime_wage needs employment and 30+ usual hours", {
  a <- tibble::tibble(emp = c(TRUE, TRUE, FALSE), uhrswork = c(30, 29, 40), wage = 20) |>
    flag_fulltime_wage()
  expect_equal(a$wage_ft, c(20, NA, NA))
})

test_that("check_clean catches missing years and bad wages", {
  good <- toy_person(year = 2005:2014) |> dplyr::mutate(wage_ft = 20)
  expect_silent(check_clean(good))
  expect_error(check_clean(dplyr::filter(good, year != 2014)), "2005-2014")
  expect_error(check_clean(dplyr::mutate(good, wage_ft = 0)), "non-positive")
})

test_that("the full pipeline on toy data yields the Section 3 columns", {
  out <- toy_person(year = 2005:2014, bpl = 300) |>
    flag_nativity_education() |>
    flag_employment() |>
    restrict_wage_sample() |>
    convert_weeks() |>
    deflate_income() |>
    hourly_wage() |>
    winsorize_wage() |>
    flag_fulltime_wage() |>
    check_clean() |>
    slim_for_panel()
  expect_equal(names(out), PANEL_VARS)
  expect_true(all(out$lefb & out$emp))
  expect_true(all(out$wage_ft > 0))
})

test_that("summarise_clean reports one row per year", {
  s <- toy_person(year = c(2005, 2005, 2006)) |>
    flag_nativity_education() |> flag_employment() |>
    dplyr::mutate(wage_ft = c(20, NA, 25)) |> summarise_clean()
  expect_equal(s$n, c(2, 1))
  expect_equal(s$ft_wage_obs, c(1, 1))
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'clean_acs')"`
Expected: FAIL with `could not find function "check_acs_vars"` (and similar errors for the other functions).

- [ ] **Step 3: Write `clean_acs.R`**

Create `replication_files/R/clean_acs.R`. Functions kept from `Section 2.html` are unchanged except where a comment notes a fix.

```r
# Section 2: clean the person-level ACS extract.
# Rules follow original_files/code/0_EHLMV_clean_emp_data_FINAL.do and
# 1_EHLMV_clean_wage_data_FINAL.do.
library(dplyr)

ACS_VARS <- c("year", "statefip", "cpuma0010", "gq", "perwt", "sex", "age",
              "bpl", "educ", "educd", "empstat", "classwkr", "classwkrd",
              "occ2010", "ind1990", "wkswork2", "uhrswork", "incwage",
              "school", "cpi99")

PANEL_VARS <- c("cpuma0010", "year", "perwt", "emp", "lefb", "usb", "male",
                "wage_ft", "ind1990", "occ2010")

# Read in chunks and keep ages 20-64 in 2005-2014 as we go, so the full
# all-ages extract never has to fit in memory at once.
read_acs <- function(ddi_path, dat_path, chunk_size = 500000) {
  ddi <- ipumsr::read_ipums_ddi(ddi_path, lower_vars = TRUE)
  keep_rows <- function(x, pos) {
    filter(x, age >= 20, age <= 64, year >= 2005, year <= 2014)
  }
  acs <- ipumsr::read_ipums_micro_chunked(
    ddi,
    callback   = ipumsr::IpumsDataFrameCallback$new(keep_rows),
    chunk_size = chunk_size,
    vars       = any_of(ACS_VARS),
    data_file  = dat_path,
    var_attrs  = NULL,
    verbose    = FALSE
  )
  check_acs_vars(acs)
}

check_acs_vars <- function(acs) {
  missing <- setdiff(ACS_VARS, names(acs))
  if (length(missing)) {
    stop("ACS extract is missing variables: ", paste(missing, collapse = ", "))
  }
  invisible(acs)
}

flag_nativity_education <- function(acs) {
  acs |>
    mutate(
      usb  = bpl <= 120,
      fb   = bpl > 120,
      ls   = educ <= 6,
      lefb = fb & ls,
      male = sex == 1
    )
}

# Stata sectors 11 (public administration) and 12 (military): 893 < ind1990 <= 940.
flag_milpa <- function(acs) {
  acs |> mutate(milpa = !is.na(ind1990) & ind1990 > 893 & ind1990 <= 940)
}

# Stata's temp_ACS_occ_edu_dropmilpa.dta: occupations held in 2005 by people
# outside group quarters, with known education, outside military/public admin.
occ_reference_set <- function(acs) {
  acs |>
    filter(year == 2005, gq %in% c(1, 2), educd != 1, !milpa,
           !is.na(occ2010), occ2010 != 9920) |>
    distinct(occ2010) |>
    pull(occ2010)
}

# Fix: Stata drops employed people whose occupation is not in the 2005
# reference set, and its mil/pa range starts at 894, not 900.
flag_employment <- function(acs) {
  acs <- flag_milpa(acs)
  occ_ok <- occ_reference_set(acs)
  acs |>
    mutate(emp = empstat == 1 & gq %in% c(1, 2) & !milpa & occ2010 %in% occ_ok)
}

restrict_wage_sample <- function(acs) {
  bad_inc <- with(acs,
    (wkswork2 == 0) | (uhrswork == 0) | is.na(uhrswork) | (school == 2) |
    (classwkr == 1) | (classwkrd == 29) | (incwage %in% c(0, 999998, 999999)))
  bad_inc[is.na(bad_inc)] <- FALSE

  acs |> mutate(incwage = if_else(bad_inc, NA_real_, as.numeric(incwage)))
}

convert_weeks <- function(acs) {
  acs |>
    mutate(weeks = c(8.0, 20.8, 33.1, 42.4, 48.3, 51.9)[match(wkswork2, 1:6)])
}

deflate_income <- function(acs) {
  cpi99_2014 <- mean(acs$cpi99[acs$year == 2014])
  stopifnot(is.finite(cpi99_2014))

  acs |> mutate(real_inc = incwage * cpi99 / cpi99_2014)
}

hourly_wage <- function(acs) {
  acs |> mutate(wage_raw = real_inc / (weeks * uhrswork))
}

winsorize_wage <- function(acs) {
  q <- quantile(acs$wage_raw, c(0.025, 0.975),
                na.rm = TRUE, type = 2, names = FALSE)

  acs |> mutate(wage = pmin(pmax(wage_raw, q[1]), q[2]))
}

flag_fulltime_wage <- function(acs) {
  acs |> mutate(wage_ft = if_else(emp & uhrswork >= 30, wage, NA_real_))
}

# Replaces check_means(): the paper's $15.60 / $24.39 are CZ-level means, so
# that comparison now lives in Section 3 (compare_to_paper).
check_clean <- function(acs) {
  yrs <- sort(unique(acs$year))
  if (!identical(as.numeric(yrs), as.numeric(2005:2014))) {
    stop("expected years 2005-2014, found: ", paste(yrs, collapse = " "))
  }
  if (any(acs$age < 20 | acs$age > 64)) stop("ages outside 20-64")
  w <- acs$wage_ft[!is.na(acs$wage_ft)]
  if (any(!is.finite(w) | w <= 0)) stop("wage_ft has non-positive or infinite values")
  invisible(acs)
}

summarise_clean <- function(acs) {
  acs |>
    group_by(year) |>
    summarise(
      n           = n(),
      pop         = sum(perwt),
      lefb_emp    = sum(perwt[which(emp & lefb)]),
      usb_emp     = sum(perwt[which(emp & usb)]),
      ft_wage_obs = sum(!is.na(wage_ft))
    )
}

slim_for_panel <- function(acs) select(acs, all_of(PANEL_VARS))

save_clean <- function(acs, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(acs, path)
  invisible(acs)
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add replication_files/R/clean_acs.R replication_files/tests/testthat/test-clean_acs.R
git commit -m "Restore Section 2 cleaning functions with tests and Stata fidelity fixes

Recovers the code from Section 2.html, reads the ACS in filtered chunks,
matches Stata's mil/pa and 2005-occupation employment rules, and replaces
the person-level wage check that always warned.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Restore the Section 2 runner and produce `acs_person.rds`

**Files:**
- Create: `replication_files/section 2 R.Rmd`

**Interfaces:**
- Consumes: `project_paths()`, `check_inputs()` (Task 1); all of `clean_acs.R` (Task 2).
- Produces: `replication_files/data/clean/acs_person.rds`, a tibble with columns `PANEL_VARS`. Task 5 reads it.

- [ ] **Step 1: Get the raw IPUMS data**

`ipums_data.RData` is truncated and cannot be loaded, so the raw fixed-width file is needed. The team member who knitted `Section 2.html` had it at `C:/Users/Kuthn/Downloads/usa_00002.dat/usa_00001.dat.dat`. The alternative is to download extract #1 again from the IPUMS USA account that created it (My Data → extract 1 → Download .DAT). Do one of:
- Put it at `replication_files/data/raw/usa_00001.dat.gz` (or `.dat`), or
- Set the environment variable: `Sys.setenv(ACS_DAT = "C:/path/to/usa_00001.dat")`.

Check it:

Run: `Rscript -e "source('replication_files/R/paths.R'); p <- project_paths(); print(p$raw_dat); check_inputs(c(p$raw_ddi, p$raw_dat))"`
Expected: prints the path and no error.

**If the file cannot be found, stop here and ask the user.** Do not continue with a fabricated or partial file.

- [ ] **Step 2: Write the runner**

Create `replication_files/section 2 R.Rmd`:

````markdown
---
title: "01_clean"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = TRUE)
source(here::here("replication_files", "R", "paths.R"))
source(here::here("replication_files", "R", "clean_acs.R"))
paths <- project_paths()
```

Functions live in `R/clean_acs.R` and are tested in `tests/testthat/`.
Set `ACS_DAT` to read the raw IPUMS file from a non-default location.

```{r inputs}
check_inputs(c(paths$raw_ddi, paths$raw_dat))
```

```{r run}
acs <- read_acs(paths$raw_ddi, paths$raw_dat) |>
  flag_nativity_education() |>
  flag_employment() |>
  restrict_wage_sample() |>
  convert_weeks() |>
  deflate_income() |>
  hourly_wage() |>
  winsorize_wage() |>
  flag_fulltime_wage() |>
  check_clean()

summarise_clean(acs)
```

```{r save}
save_clean(slim_for_panel(acs), paths$acs_clean)
```
````

- [ ] **Step 3: Knit it**

Run: `Rscript -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('replication_files/section 2 R.Rmd')"`

Expected:
- The render finishes.
- The `summarise_clean` table has 10 rows (2005–2014), each with n in the low millions.
- `replication_files/data/clean/acs_person.rds` exists.

For the sanity check, compare the 2005 `ft_wage_obs` to the old HTML: the LEFB plus US-born full-time wage counts were 696,811 and 7,345,606 across all years. Totals should be similar but slightly lower, because of the new occupation rule.

- [ ] **Step 4: Confirm the RDS is not tracked, then commit**

Run: `git status --short`
Expected: `section 2 R.Rmd` and `section 2 R.html` are listed. Nothing under `data/clean/` is listed.

```bash
git add "replication_files/section 2 R.Rmd" "replication_files/section 2 R.html"
git commit -m "Restore Section 2 R Markdown as a thin runner

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Section 3 panel functions with all Table 3 / Figure 2 outcomes

**Files:**
- Create: `replication_files/R/build_panel.R`
- Test: `replication_files/tests/testthat/test-build_panel.R`

**Interfaces:**
- Consumes: the column names in `PANEL_VARS` (Task 2). `cpuma0010` and `year` are integers after `load_acs`.
- Produces (data.table in, data.table out):
  - `cnt` (character): count columns summed with `afactor`. `WAGE_VARS = c("w_lefb", "w_lefb_f", "w_lefb_m", "w_usb")`.
  - `read_dta_dt(path)`, `load_acs(path)`, `save_panel(p, path)`: unchanged from the existing Section 3.
  - `count_cpuma(acs)` returns one row per (cpuma0010, year) with `emp_lefb_m`, `emp_lefb_f`, `emp_usb` and `pop_all`.
  - `cell_wage_mean(acs, keep)`: `keep` is a logical vector with one element per row of `acs`. Returns (cpuma0010, year, w).
  - `wage_cpuma(acs)` returns (cpuma0010, year) plus `WAGE_VARS`. A group missing from a CPUMA-year gets `NA`.
  - `add_bartik(cp, bart)`, `join_crosswalk(cp, cw)`, `add_policy(cz, pol)`, `trim_panel(p)`, `diagnose_merges(cp, cw)`, `check_panel(p)`: unchanged.
  - `wmean_na(x, w)` returns a numeric of length 1, `NA_real_` when every `x` is `NA`.
  - `collapse_cz(pan)` returns (czone, year) plus `cnt`, `WAGE_VARS` and `emp_lefb`.
  - `make_outcomes(p)` adds `pop05`, `emp_share_lefb`, `emp_share_lefb_f`, `emp_share_lefb_m`, `emp_share_usb`, `lnw_lefb`, `lnw_lefb_f`, `lnw_lefb_m` and `lnw_usb`.

- [ ] **Step 1: Write the failing tests**

Create `replication_files/tests/testthat/test-build_panel.R`:

```r
library(data.table)

test_that("count_cpuma sums person weights by group", {
  acs <- data.table(cpuma0010 = 1L, year = 2005L, perwt = c(10, 20, 30, 40),
                    emp  = c(TRUE, TRUE, TRUE, FALSE),
                    lefb = c(TRUE, TRUE, FALSE, TRUE),
                    usb  = c(FALSE, FALSE, TRUE, FALSE),
                    male = c(TRUE, FALSE, TRUE, TRUE))
  out <- count_cpuma(acs)
  expect_equal(out$emp_lefb_m, 10)
  expect_equal(out$emp_lefb_f, 20)
  expect_equal(out$emp_usb, 30)
  expect_equal(out$pop_all, 100)
})

test_that("cell_wage_mean is perwt-weighted within cells, unweighted across cells", {
  acs <- data.table(cpuma0010 = 1L, year = 2005L, ind1990 = c(1, 1, 2),
                    occ2010 = 10, perwt = c(1, 3, 5), wage_ft = c(10, 20, 30))
  expect_equal(cell_wage_mean(acs, rep(TRUE, 3))$w, mean(c(17.5, 30)))
  expect_equal(cell_wage_mean(acs, c(TRUE, NA, TRUE))$w, 20)
  expect_equal(nrow(cell_wage_mean(acs, rep(FALSE, 3))), 0)
})

test_that("wage_cpuma gives NA, not a dropped row, for a group with no workers", {
  acs <- data.table(cpuma0010 = 1L, year = 2005L, ind1990 = 1, occ2010 = 10,
                    perwt = 1, lefb = c(TRUE, TRUE, FALSE),
                    usb = c(FALSE, FALSE, TRUE), male = c(TRUE, TRUE, FALSE),
                    wage_ft = c(10, 20, 40))
  out <- wage_cpuma(acs)
  expect_equal(nrow(out), 1)
  expect_equal(out$w_lefb, 15)
  expect_equal(out$w_lefb_m, 15)
  expect_true(is.na(out$w_lefb_f))
  expect_equal(out$w_usb, 40)
})

test_that("wmean_na returns NA (not NaN) and renormalizes weights", {
  expect_identical(wmean_na(c(NA_real_, NA_real_), c(0.5, 0.5)), NA_real_)
  expect_equal(wmean_na(c(10, NA), c(0.3, 0.7)), 10)
  expect_equal(wmean_na(c(10, 20), c(0.25, 0.75)), 17.5)
})

test_that("collapse_cz splits counts by afactor and averages wages", {
  pan <- data.table(
    cpuma0010 = c(1L, 1L, 2L), year = 2005L,
    czone = c(100, 200, 100), afactor = c(0.25, 0.75, 1),
    emp_lefb_m = c(40, 40, 0), emp_lefb_f = c(8, 8, 0),
    emp_usb = c(400, 400, 100), pop_all = c(1000, 1000, 500),
    shift_share_sample_fb = 4, shift_share_sample_usb = 8,
    w_lefb = c(10, 10, 20), w_lefb_f = NA_real_,
    w_lefb_m = c(12, 12, NA), w_usb = 20
  )
  cz <- collapse_cz(pan)
  expect_equal(cz[czone == 100, pop_all], 750)
  expect_equal(cz[czone == 200, emp_lefb], 36)
  expect_equal(cz[czone == 100, w_lefb], 18)
  expect_equal(cz[czone == 100, w_lefb_m], 12)
  expect_true(is.na(cz[czone == 100, w_lefb_f]))
  expect_false(is.nan(cz[czone == 100, w_lefb_f]))
})

test_that("make_outcomes uses 2005 population and keeps missing wages NA", {
  p <- data.table(czone = 1L, year = 2005:2006,
                  emp_lefb = c(5, 4), emp_lefb_m = c(3, 3), emp_lefb_f = c(2, 1),
                  emp_usb = c(50, 49), pop_all = c(100, 120),
                  w_lefb = c(15, NA), w_lefb_f = NA_real_, w_lefb_m = 15, w_usb = 25)
  o <- make_outcomes(p)
  expect_equal(o$emp_share_lefb, c(5, 4))
  expect_equal(o$emp_share_lefb_f, c(2, 1))
  expect_equal(o$lnw_lefb, c(log(15), NA))
  expect_equal(o$lnw_usb, rep(log(25), 2))
  expect_false(any(is.nan(o$lnw_lefb_f)))
})

test_that("trim_panel keeps 2005-2014, non-missing SC, and drops CZ 34701", {
  p <- data.table(czone = c(1L, 34701L, 2L, 3L),
                  year = c(2005L, 2005L, 2015L, 2006L),
                  SC_frac = c(0, 0, 1, NA))
  expect_equal(trim_panel(p)$czone, 1L)
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'build_panel')"`
Expected: FAIL with `could not find function "count_cpuma"`.

- [ ] **Step 3: Write `build_panel.R`**

Create `replication_files/R/build_panel.R`. Functions kept from `section 3 R.Rmd` are unchanged unless a comment says otherwise.

```r
# Section 3: build the commuting-zone-by-year panel.
# Rules follow original_files/code/2_EHLMV_results_emp_FINAL.do and
# 3_EHLMV_results_wages_FINAL.do.
library(data.table)

cnt <- c("emp_lefb_m", "emp_lefb_f", "emp_usb", "pop_all",
         "shift_share_sample_fb", "shift_share_sample_usb")

WAGE_VARS <- c("w_lefb", "w_lefb_f", "w_lefb_m", "w_usb")

read_dta_dt <- function(path) {
  as.data.table(haven::zap_labels(haven::read_dta(path)))
}

load_acs <- function(path) {
  keep <- c("cpuma0010", "year", "perwt", "emp", "lefb", "usb", "male",
            "wage_ft", "ind1990", "occ2010")
  acs <- as.data.table(readRDS(path))
  stopifnot(all(keep %in% names(acs)))
  acs <- acs[, ..keep]
  acs[, `:=`(cpuma0010 = as.integer(cpuma0010), year = as.integer(year))]
  acs[]
}

save_panel <- function(p, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(p, path)
  invisible(p)
}

count_cpuma <- function(acs) {
  acs[, .(
    emp_lefb_m = sum(perwt[which(emp & lefb & male)]),
    emp_lefb_f = sum(perwt[which(emp & lefb & !male)]),
    emp_usb    = sum(perwt[which(emp & usb)]),
    pop_all    = sum(perwt)
  ), by = .(cpuma0010, year)]
}

# Stata: perwt-weighted mean within cpuma x year x industry x occupation
# cells, then the unweighted mean of those cells within cpuma x year.
cell_wage_mean <- function(acs, keep) {
  rows <- which(keep & !is.na(acs$wage_ft))
  if (!length(rows)) {
    return(data.table(cpuma0010 = integer(), year = integer(), w = numeric()))
  }
  cells <- acs[rows, .(w = weighted.mean(wage_ft, perwt)),
               by = .(cpuma0010, year, ind1990, occ2010)]
  cells[, .(w = mean(w)), by = .(cpuma0010, year)]
}

# Extended: Table 3 needs female/male LEFB wages and Figure 2 the US-born wage.
wage_cpuma <- function(acs) {
  groups <- list(
    w_lefb   = acs$lefb,
    w_lefb_f = acs$lefb & !acs$male,
    w_lefb_m = acs$lefb & acs$male,
    w_usb    = acs$usb
  )
  parts <- Map(function(nm, keep) setnames(cell_wage_mean(acs, keep), "w", nm),
               names(groups), groups)
  Reduce(function(a, b) merge(a, b, by = c("cpuma0010", "year"), all = TRUE), parts)
}

add_bartik <- function(cp, bart) {
  bart <- bart[, .(cpuma0010 = as.integer(cpuma0010), year = as.integer(year),
                   shift_share_sample_fb, shift_share_sample_usb)]
  merge(cp, bart, by = c("cpuma0010", "year"), all.x = TRUE)
}

join_crosswalk <- function(cp, cw) {
  stopifnot(all(c("cpuma0010", "czone", "afactor") %in% names(cw)))
  merge(cp, cw, by = "cpuma0010", allow.cartesian = TRUE)
}

# Fix: weighted.mean(na.rm = TRUE) gives NaN when every value is missing.
wmean_na <- function(x, w) {
  ok <- !is.na(x)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

collapse_cz <- function(pan) {
  counts <- pan[, lapply(.SD, function(x) sum(x * afactor)),
                by = .(czone, year), .SDcols = cnt]
  wages  <- pan[, lapply(.SD, wmean_na, w = afactor),
                by = .(czone, year), .SDcols = WAGE_VARS]
  cz <- merge(counts, wages, by = c("czone", "year"))
  cz[, czone := as.integer(czone)]
  cz[, emp_lefb := emp_lefb_m + emp_lefb_f]
  cz[]
}

add_policy <- function(cz, pol) {
  stopifnot("policy file needs czone, year, SC_frac, pop2000" =
              all(c("czone", "year", "SC_frac", "pop2000") %in% names(pol)))
  pol <- pol[, .(czone = as.integer(czone), year = as.integer(year),
                 SC_frac, pop2000)][!is.na(czone)]
  stopifnot(!anyDuplicated(pol, by = c("czone", "year")))
  merge(cz, pol, by = c("czone", "year"), all.x = TRUE)
}

trim_panel <- function(p) {
  p[year >= 2005 & year <= 2014 & !is.na(SC_frac) & czone != 34701]
}

make_outcomes <- function(p) {
  p <- copy(p)
  p[, pop05 := {
    v <- pop_all[year == 2005]
    if (length(v) == 1) v else NA_real_
  }, by = czone]
  p[, `:=`(
    emp_share_lefb   = 100 * emp_lefb   / pop05,
    emp_share_lefb_m = 100 * emp_lefb_m / pop05,
    emp_share_lefb_f = 100 * emp_lefb_f / pop05,
    emp_share_usb    = 100 * emp_usb    / pop05,
    lnw_lefb         = log(w_lefb),
    lnw_lefb_f       = log(w_lefb_f),
    lnw_lefb_m       = log(w_lefb_m),
    lnw_usb          = log(w_usb)
  )]
  setorder(p, czone, year)
  p[]
}

diagnose_merges <- function(cp, cw) {
  c(
    cpuma_not_in_crosswalk     = length(setdiff(cp$cpuma0010, cw$cpuma0010)),
    cpuma_years_missing_bartik = cp[is.na(shift_share_sample_fb), .N],
    cpuma_afactor_not_one      = cw[, .(s = sum(afactor)), by = cpuma0010][abs(s - 1) > 0.001, .N]
  )
}

check_panel <- function(p) {
  n_cz  <- uniqueN(p$czone)
  n2005 <- p[year == 2005, .N, by = czone]
  print(c(rows = nrow(p), czs = n_cz, years = uniqueN(p$year)))
  if (nrow(p) != 7400) warning("panel has ", nrow(p), " rows, expected 7,400")
  if (nrow(n2005) != n_cz || any(n2005$N != 1)) {
    warning("not every CZ has exactly one 2005 row")
  }
  p
}
```

- [ ] **Step 4: Run all tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add replication_files/R/build_panel.R replication_files/tests/testthat/test-build_panel.R
git commit -m "Move Section 3 panel functions to R/ with tests; add Table 3 and Figure 2 wages

Adds female/male LEFB and US-born wages, and keeps CZ-years with no
workers as NA rather than NaN.

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Paper comparison, thin Section 3 runner, README

**Files:**
- Modify: `replication_files/R/build_panel.R` (append)
- Modify: `replication_files/tests/testthat/test-build_panel.R` (append)
- Modify: `replication_files/section 3 R.Rmd` (replace its contents)
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1, 2 and 4, plus `acs_person.rds` from Task 3.
- Produces:
  - `PAPER_TARGETS`: a data.table with columns `var`, `paper_mean` and `paper_n`.
  - `compare_to_paper(p, targets = PAPER_TARGETS)` returns a new data.table with columns `var`, `paper_mean`, `ours_mean`, `diff_mean`, `paper_n` and `ours_n`. It never modifies `targets`.
  - `replication_files/data/clean/cz_panel.rds`, which the next (regression) plan uses.

- [ ] **Step 1: Write the failing tests**

Append to `replication_files/tests/testthat/test-build_panel.R`:

```r
test_that("compare_to_paper uses pop2000 weights and skips missing values", {
  tg <- data.table(var = "lnw_lefb", paper_mean = 2.74, paper_n = 7383)
  p  <- data.table(lnw_lefb = c(2, 3, NA), pop2000 = c(1, 3, 100))
  out <- compare_to_paper(p, tg)
  expect_equal(out$ours_mean, 2.75)
  expect_equal(out$ours_n, 2L)
  expect_equal(out$diff_mean, 0.01)
})

test_that("compare_to_paper does not modify its targets table", {
  tg <- data.table(var = "lnw_lefb", paper_mean = 2.74, paper_n = 7383)
  p  <- data.table(lnw_lefb = 2, pop2000 = 1)
  compare_to_paper(p, tg)
  compare_to_paper(p, tg)
  expect_equal(names(tg), c("var", "paper_mean", "paper_n"))
  expect_equal(names(PAPER_TARGETS), c("var", "paper_mean", "paper_n"))
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'build_panel')"`
Expected: FAIL with `could not find function "compare_to_paper"`.

- [ ] **Step 3: Append the implementation to `build_panel.R`**

```r
# "Y mean" and observation counts from Tables 3 and 4 of East et al. (2023).
PAPER_TARGETS <- data.table(
  var = c("emp_share_lefb", "emp_share_lefb_f", "emp_share_lefb_m", "emp_share_usb",
          "lnw_lefb", "lnw_lefb_f", "lnw_lefb_m", "lnw_usb"),
  paper_mean = c(6.75, 2.55, 4.21, 58.61, 2.74, 2.59, 2.81, 3.18),
  paper_n    = c(7400, 7400, 7400, 7400, 7383, 7331, 7367, 7400)
)

compare_to_paper <- function(p, targets = PAPER_TARGETS) {
  out <- copy(targets)
  out[, `:=`(
    ours_mean = vapply(var, function(v) {
      ok <- !is.na(p[[v]])
      weighted.mean(p[[v]][ok], p$pop2000[ok])
    }, numeric(1), USE.NAMES = FALSE),
    ours_n = vapply(var, function(v) sum(!is.na(p[[v]])), integer(1),
                    USE.NAMES = FALSE)
  )]
  out[, diff_mean := round(ours_mean - paper_mean, 3)]
  out[, .(var, paper_mean, ours_mean, diff_mean, paper_n, ours_n)]
}
```

- [ ] **Step 4: Run all tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Replace `section 3 R.Rmd` with the thin runner**

````markdown
---
title: "02_panel"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = TRUE)
source(here::here("replication_files", "R", "paths.R"))
source(here::here("replication_files", "R", "build_panel.R"))
paths <- project_paths()
```

Functions live in `R/build_panel.R` and are tested in `tests/testthat/`.

```{r inputs}
check_inputs(c(paths$acs_clean, paths$bartik, paths$cw, paths$policy))

acs <- load_acs(paths$acs_clean)
cw  <- read_dta_dt(paths$cw)

cp <- count_cpuma(acs) |>
  merge(wage_cpuma(acs), by = c("cpuma0010", "year"), all.x = TRUE) |>
  add_bartik(read_dta_dt(paths$bartik))

diagnose_merges(cp, cw)
```

```{r panel}
panel <- join_crosswalk(cp, cw) |>
  collapse_cz() |>
  add_policy(read_dta_dt(paths$policy)) |>
  trim_panel() |>
  make_outcomes() |>
  check_panel()
```

```{r compare}
knitr::kable(compare_to_paper(panel), digits = 3)
```

```{r save}
save_panel(panel, paths$cz_panel)
```
````

- [ ] **Step 6: Knit it on the real data**

Run: `Rscript -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('replication_files/section 3 R.Rmd')"`

Expected:
- `diagnose_merges` prints three zeros.
- `check_panel` prints `rows 7400 czs 740 years 10` with no warning.
- The comparison table shows `ours_n` equal or close to `paper_n` (the wage rows must be below 7,400, never above).

A close replication means employment-share means within about ±0.15 of the paper and log-wage means within about ±0.05. These are not hard failures, but record the table output in the commit message. If `ours_n` is 7,400 for `lnw_lefb_f`, the NaN→NA fix did not take effect, so investigate before committing.

- [ ] **Step 7: Add run instructions to `README.md`**

Append:

```markdown

## Running the replication code (Sections 2–3)

1. Get the raw IPUMS extract `usa_00001.dat` (or `.dat.gz`) and put it in
   `replication_files/data/raw/`, or set `Sys.setenv(ACS_DAT = "path/to/usa_00001.dat")`.
   `replication_files/ipums_data.RData` is truncated and cannot be loaded.
2. Knit `replication_files/section 2 R.Rmd`. This writes `data/clean/acs_person.rds`.
3. Knit `replication_files/section 3 R.Rmd`. This writes `data/clean/cz_panel.rds`
   and prints a comparison with the paper's Table 3/4 means.
4. Tests: `testthat::test_dir("replication_files/tests/testthat")` from the repo root.

Functions live in `replication_files/R/`; the `.Rmd` files only call them.
Data files under `replication_files/data/` are not committed.
```

- [ ] **Step 8: Commit**

```bash
git add replication_files/R/build_panel.R replication_files/tests/testthat/test-build_panel.R \
  "replication_files/section 3 R.Rmd" "replication_files/section 3 R.html" README.md
git commit -m "Make Section 3 a thin runner with a CZ-level comparison to the paper

<paste the compare_to_paper table here>

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Treatment timing variables and the Table 3 regression model

**Files:**
- Create: `replication_files/R/estimate.R`
- Modify: `replication_files/tests/testthat/helper-setup.R` (append `sim_panel()`)
- Test: `replication_files/tests/testthat/test-estimate.R`

**Interfaces:**
- Consumes: the panel columns from Tasks 4–5: `czone`, `year` (integer), `SC_frac`, `pop2000`, `shift_share_sample_fb`, `shift_share_sample_usb`, and the outcome columns `emp_share_*` and `lnw_*`.
- Produces:
  - `BARTIKS = c("shift_share_sample_fb", "shift_share_sample_usb")`.
  - `TABLE3_OUTCOMES`: a named character vector of column labels, in paper column order: `emp_share_lefb`, `emp_share_lefb_f`, `emp_share_lefb_m`, `lnw_lefb`, `lnw_lefb_f`, `lnw_lefb_m`.
  - `add_sc_leads_lags(p)` returns a copy of the panel with `F2_SC_frac`, `F1_SC_frac`, `L0_SC_frac`, `L1_SC_frac` and `L2_SC_frac`.
  - `fit_sc(p, y, bartik = TRUE)` returns a `fixest` object.
  - `sc_row(fit, p, y)` returns a one-row data.table with columns `outcome`, `beta`, `se`, `pval`, `ymean`, `pct`, `n`.
  - `run_table3(p)` returns a 12-row data.table: the `sc_row` columns plus `panel`, where `"A"` is baseline and `"B"` adds Bartiks.
  - Test helper `sim_panel(n_cz = 80, beta = -0.5, seed = 1)` returns a balanced data.table with columns `czone`, `year`, `SC_frac`, `pop2000`, both Bartiks, and `y`.

- [ ] **Step 1: Add the simulation helper**

Append to `replication_files/tests/testthat/helper-setup.R`:

```r
# Balanced CZ x year panel with staggered SC adoption and a known effect.
sim_panel <- function(n_cz = 80, beta = -0.5, seed = 1) {
  set.seed(seed)
  years <- 2005:2014
  adopt <- sample(2008:2013, n_cz, replace = TRUE)
  pop   <- runif(n_cz, 1e4, 1e6)
  a     <- rnorm(n_cz, 5)
  g     <- rnorm(n_cz, 0, 0.1)
  yfe   <- rnorm(length(years))
  p <- data.table::CJ(czone = seq_len(n_cz), year = years)
  p[, `:=`(
    SC_frac = as.numeric(year >= adopt[czone]),
    pop2000 = pop[czone],
    shift_share_sample_fb  = rnorm(.N, 100, 10),
    shift_share_sample_usb = rnorm(.N, 100, 10)
  )]
  p[, y := a[czone] + g[czone] * (year - 2005) + yfe[year - 2004] +
         beta * SC_frac + 0.01 * shift_share_sample_fb + rnorm(.N, 0, 0.05)]
  p[]
}
```

- [ ] **Step 2: Write the failing tests**

Create `replication_files/tests/testthat/test-estimate.R`:

```r
library(data.table)

test_that("add_sc_leads_lags leaves end-of-panel leads NA and zero-fills early lags", {
  p <- data.table(czone = 1L, year = 2005:2014,
                  SC_frac = c(0, 0, 0, 0.5, 1, 1, 1, 1, 1, 1))
  o <- add_sc_leads_lags(p)
  expect_equal(o$F1_SC_frac, c(p$SC_frac[2:10], NA))
  expect_equal(o$F2_SC_frac, c(p$SC_frac[3:10], NA, NA))
  expect_equal(o$L0_SC_frac, p$SC_frac)
  expect_equal(o$L1_SC_frac, c(0, p$SC_frac[1:9]))
  expect_equal(o$L2_SC_frac, c(0, 0, p$SC_frac[1:8]))
  expect_false("F1_SC_frac" %in% names(p))   # input not modified
})

test_that("add_sc_leads_lags matches on year, not row position", {
  p <- data.table(czone = c(1L, 1L, 2L, 2L), year = c(2006L, 2005L, 2005L, 2006L),
                  SC_frac = c(1, 0, 0.2, 0.4))
  o <- add_sc_leads_lags(p)
  expect_equal(o[czone == 1L & year == 2005L, F1_SC_frac], 1)
  expect_equal(o[czone == 2L & year == 2006L, L1_SC_frac], 0.2)
})

test_that("fit_sc recovers a known SC effect with CZ trends", {
  p <- sim_panel(beta = -0.5)
  fit <- fit_sc(p, "y", bartik = TRUE)
  expect_equal(unname(coef(fit)["SC_frac"]), -0.5, tolerance = 0.03)
  expect_true(all(BARTIKS %in% names(coef(fit))))
  expect_false("shift_share_sample_fb" %in% names(coef(fit_sc(p, "y", bartik = FALSE))))
})

test_that("sc_row reports a pop2000-weighted Y mean over the estimation sample", {
  p <- sim_panel()
  p[1:5, y := NA]
  fit <- fit_sc(p, "y")
  r <- sc_row(fit, p, "y")
  ok <- !is.na(p$y)
  expect_equal(r$n, sum(ok))
  expect_equal(r$ymean, weighted.mean(p$y[ok], p$pop2000[ok]))
  expect_equal(r$pct, 100 * r$beta / r$ymean)
  expect_true(r$pval < 0.01)
})

test_that("run_table3 returns 12 rows in paper column order", {
  p <- sim_panel()
  for (v in names(TABLE3_OUTCOMES)) p[, (v) := y + rnorm(.N, 0, 0.01)]
  t3 <- run_table3(p)
  expect_equal(nrow(t3), 12)
  expect_equal(t3[panel == "A", outcome], names(TABLE3_OUTCOMES))
  expect_equal(t3[panel == "B", outcome], names(TABLE3_OUTCOMES))
})
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'estimate')"`
Expected: FAIL with `could not find function "add_sc_leads_lags"`.

- [ ] **Step 4: Write `estimate.R`**

Create `replication_files/R/estimate.R`:

```r
# Section 4: estimate the effects of Secure Communities.
# Specification follows the reghdfe calls in 2_EHLMV_results_emp_FINAL.do
# and 3_EHLMV_results_wages_FINAL.do.
library(data.table)

BARTIKS <- c("shift_share_sample_fb", "shift_share_sample_usb")

TABLE3_OUTCOMES <- c(
  emp_share_lefb   = "All",
  emp_share_lefb_f = "Females",
  emp_share_lefb_m = "Males",
  lnw_lefb         = "All",
  lnw_lefb_f       = "Females",
  lnw_lefb_m       = "Males"
)

# SC_frac of the same CZ in year `yr`; NA when that year is not in the panel.
sc_at <- function(p, cz, yr) {
  p[data.table(czone = cz, year = yr), on = .(czone, year), x.SC_frac]
}

# Stata: leads/lags by row shift within CZ; lags before 2005 are set to 0
# because SC did not exist yet. Leads past 2014 stay missing, which drops
# 2013-2014 from the distributed-lag regression, as in Stata.
add_sc_leads_lags <- function(p) {
  p <- copy(p)
  f2 <- sc_at(p, p$czone, p$year + 2L)
  f1 <- sc_at(p, p$czone, p$year + 1L)
  l1 <- sc_at(p, p$czone, p$year - 1L)
  l2 <- sc_at(p, p$czone, p$year - 2L)
  p[, `:=`(F2_SC_frac = f2, F1_SC_frac = f1, L0_SC_frac = SC_frac,
           L1_SC_frac = l1, L2_SC_frac = l2)]
  p[year == 2005 & is.na(L1_SC_frac), L1_SC_frac := 0]
  p[year <= 2006 & is.na(L2_SC_frac), L2_SC_frac := 0]
  p[]
}

sc_formula <- function(y, rhs) {
  as.formula(paste(y, "~", paste(rhs, collapse = " + "), "| czone[year] + year"))
}

# czone[year] absorbs CZ fixed effects and CZ-specific linear trends.
fit_sc <- function(p, y, bartik = TRUE) {
  rhs <- c("SC_frac", if (bartik) BARTIKS)
  fixest::feols(sc_formula(y, rhs), data = p,
                weights = ~pop2000, cluster = ~czone)
}

sc_row <- function(fit, p, y) {
  used  <- fixest::obs(fit)
  beta  <- unname(coef(fit)["SC_frac"])
  ymean <- weighted.mean(p[[y]][used], p$pop2000[used])
  data.table(
    outcome = y,
    beta    = beta,
    se      = unname(fixest::se(fit)["SC_frac"]),
    pval    = unname(fixest::pvalue(fit)["SC_frac"]),
    ymean   = ymean,
    pct     = 100 * beta / ymean,
    n       = nobs(fit)
  )
}

run_table3 <- function(p) {
  rows <- list()
  for (panel in c("A", "B")) {
    for (y in names(TABLE3_OUTCOMES)) {
      fit <- fit_sc(p, y, bartik = panel == "B")
      rows[[length(rows) + 1]] <- cbind(panel = panel, sc_row(fit, p, y))
    }
  }
  rbindlist(rows)
}
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`. fixest may print notes about removed NA observations; those are fine.

- [ ] **Step 6: Commit**

```bash
git add replication_files/R/estimate.R replication_files/tests/testthat/test-estimate.R \
  replication_files/tests/testthat/helper-setup.R
git commit -m "Add SC leads/lags and the Table 3 two-way fixed effects model

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Distributed-lag event study (Figure 2 estimates)

**Files:**
- Modify: `replication_files/R/estimate.R` (append)
- Modify: `replication_files/tests/testthat/test-estimate.R` (append)

**Interfaces:**
- Consumes: `add_sc_leads_lags()`, `sc_formula()`, `BARTIKS` (Task 6).
- Produces:
  - `DL_TERMS` (character, 5 names). `DL_WEIGHTS`: a 6×5 matrix with one row per event time −3…2.
  - `cumulate_dl(b, V)`, where `b` is a length-5 numeric vector in `DL_TERMS` order and `V` is a 5×5 matrix. Returns a data.table with columns `event_time` (−3:2), `beta`, `se`, `ci_lo` and `ci_hi`.
  - `dl_event_study(p, y)`: `p` must already have leads and lags. Returns the `cumulate_dl` output plus an `outcome` column.

- [ ] **Step 1: Write the failing tests**

Append to `replication_files/tests/testthat/test-estimate.R`:

```r
test_that("cumulate_dl follows Schmidheiny-Siegloch with -1 as reference", {
  es <- cumulate_dl(b = 1:5, V = diag(5))
  expect_equal(es$event_time, -3:2)
  expect_equal(es$beta, c(-3, -2, 0, 3, 7, 12))
  expect_equal(es$se, sqrt(c(2, 1, 0, 1, 2, 3)))
  expect_equal(es$ci_hi - es$beta, 1.96 * es$se)
})

test_that("cumulate_dl uses covariances, not just variances", {
  V <- diag(5); V[1, 2] <- V[2, 1] <- 0.5
  expect_equal(cumulate_dl(rep(0, 5), V)$se[1], sqrt(1 + 1 + 2 * 0.5))
})

test_that("dl_event_study shows flat pre-trends and the effect afterwards", {
  p <- add_sc_leads_lags(sim_panel(n_cz = 150, beta = -0.5))
  es <- dl_event_study(p, "y")
  expect_true(all(abs(es[event_time < 0, beta]) < 0.06))
  expect_true(all(abs(es[event_time >= 0, beta] + 0.5) < 0.06))
  expect_equal(unique(es$outcome), "y")
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'estimate')"`
Expected: FAIL with `could not find function "cumulate_dl"`.

- [ ] **Step 3: Append to `estimate.R`**

```r
DL_TERMS <- c("F2_SC_frac", "F1_SC_frac", "L0_SC_frac", "L1_SC_frac", "L2_SC_frac")

# Rows are event times -3..2; columns are DL_TERMS. Event time -1 is the
# reference (0). Leads cumulate negatively, lags positively, matching the
# lincom statements in the Stata code.
DL_WEIGHTS <- rbind(
  `-3` = c(-1, -1, 0, 0, 0),
  `-2` = c( 0, -1, 0, 0, 0),
  `-1` = c( 0,  0, 0, 0, 0),
  `0`  = c( 0,  0, 1, 0, 0),
  `1`  = c( 0,  0, 1, 1, 0),
  `2`  = c( 0,  0, 1, 1, 1)
)

cumulate_dl <- function(b, V) {
  est <- as.vector(DL_WEIGHTS %*% b)
  se  <- sqrt(rowSums((DL_WEIGHTS %*% V) * DL_WEIGHTS))
  data.table(event_time = -3:2, beta = est, se = se,
             ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se)
}

dl_event_study <- function(p, y) {
  fit <- fixest::feols(sc_formula(y, c(DL_TERMS, BARTIKS)), data = p,
                       weights = ~pop2000, cluster = ~czone)
  es <- cumulate_dl(coef(fit)[DL_TERMS], vcov(fit)[DL_TERMS, DL_TERMS])
  es[, outcome := y][]
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add replication_files/R/estimate.R replication_files/tests/testthat/test-estimate.R
git commit -m "Add distributed-lag event study with cumulated effects

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Paper-style Table 3 and the comparison with the paper

**Files:**
- Create: `replication_files/R/tables.R`
- Test: `replication_files/tests/testthat/test-tables.R`

**Interfaces:**
- Consumes: `run_table3()` output (columns `panel`, `outcome`, `beta`, `se`, `pval`, `ymean`, `pct`, `n`) and `TABLE3_OUTCOMES` (Task 6).
- Produces:
  - `stars(p)` returns a character vector.
  - `format_table3(res)` returns a 14-row × 7-column data.frame: a label column plus columns (1)–(6). Seven rows per panel: SC estimate, (se), CZ-year trends, Bartiks, Y mean, % effect, Observations.
  - `PAPER_TABLE3`: a data.table with `panel`, `outcome`, `paper_beta`, `paper_se`.
  - `compare_table3(res)` returns a data.table with `panel`, `outcome`, `paper_beta`, `ours_beta`, `diff`, `paper_se`, `ours_se`.

- [ ] **Step 1: Write the failing tests**

Create `replication_files/tests/testthat/test-tables.R`:

```r
library(data.table)

fake_res <- function() {
  data.table(
    panel   = rep(c("A", "B"), each = 6),
    outcome = rep(names(TABLE3_OUTCOMES), 2),
    beta    = c(-0.398, -0.062, -0.336, -0.013, -0.007, -0.016,
                -0.387, -0.061, -0.326, -0.014, -0.006, -0.018),
    se      = c(0.113, 0.041, 0.085, 0.009, 0.015, 0.012,
                0.093, 0.032, 0.075, 0.009, 0.015, 0.012),
    pval    = c(0.001, 0.13, 0.0001, 0.15, 0.6, 0.2,
                0.0001, 0.06, 0.0001, 0.13, 0.7, 0.14),
    ymean   = rep(c(6.75, 2.55, 4.21, 2.74, 2.59, 2.81), 2),
    pct     = NA_real_,
    n       = rep(c(7400L, 7400L, 7400L, 7383L, 7331L, 7367L), 2)
  )[, pct := 100 * beta / ymean][]
}

test_that("stars follow the paper's thresholds", {
  expect_equal(stars(c(0.005, 0.03, 0.07, 0.2)), c("***", "**", "*", ""))
})

test_that("format_table3 puts each outcome in its paper column", {
  t <- format_table3(fake_res())
  expect_equal(dim(t), c(14L, 7L))
  expect_equal(names(t)[2:7], c("(1) All", "(2) Females", "(3) Males",
                                "(4) All", "(5) Females", "(6) Males"))
  expect_equal(t[1, 2], "-0.398***")   # A, all LEFB employment
  expect_equal(t[1, 3], "-0.062")      # A, female employment (p = .13)
  expect_equal(t[2, 4], "(0.085)")     # A, male employment se
  expect_equal(t[8, 3], "-0.061*")     # B, female employment
  expect_equal(t[13, 2], "-5.73")      # B, % effect, employment
  expect_equal(t[13, 5], "...")        # B, % effect not shown for wages
  expect_equal(t[14, 6], "7,331")      # B, female wage observations
  expect_equal(t[4, 2], "")            # A has no Bartiks
  expect_equal(t[11, 2], "Yes")        # B has Bartiks
})

test_that("compare_table3 lines up our estimates with the paper's", {
  cmp <- compare_table3(fake_res())
  expect_equal(nrow(cmp), 12)
  expect_equal(cmp[panel == "B" & outcome == "emp_share_lefb", paper_beta], -0.387)
  expect_equal(cmp[panel == "B" & outcome == "emp_share_lefb", diff], 0)
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'tables')"`
Expected: FAIL with `could not find function "stars"`.

- [ ] **Step 3: Write `tables.R`**

Create `replication_files/R/tables.R`:

```r
# Format Table 3 the way the paper prints it, and compare with the paper.
library(data.table)

stars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
}

format_table3 <- function(res) {
  one_panel <- function(pan) {
    r <- res[panel == pan][match(names(TABLE3_OUTCOMES), outcome)]
    is_emp <- grepl("^emp_share", r$outcome)
    cells <- rbind(
      paste0(sprintf("%.3f", r$beta), stars(r$pval)),
      sprintf("(%.3f)", r$se),
      rep("Yes", 6),
      rep(if (pan == "B") "Yes" else "", 6),
      sprintf("%.2f", r$ymean),
      ifelse(is_emp, sprintf("%.2f", r$pct), "..."),
      format(r$n, big.mark = ",", trim = TRUE)
    )
    label <- c(if (pan == "A") "A. Baseline: SC" else "B. Add Bartiks: SC",
               "", "CZ-year trends", "Bartiks", "Y mean", "% effect", "Observations")
    out <- data.frame(label, cells, stringsAsFactors = FALSE)
    names(out) <- c(" ", sprintf("(%d) %s", 1:6, TABLE3_OUTCOMES))
    out
  }
  out <- rbind(one_panel("A"), one_panel("B"))
  rownames(out) <- NULL
  out
}

# East et al. (2023), Table 3.
PAPER_TABLE3 <- data.table(
  panel      = rep(c("A", "B"), each = 6),
  outcome    = rep(names(TABLE3_OUTCOMES), 2),
  paper_beta = c(-0.398, -0.062, -0.336, -0.013, -0.007, -0.016,
                 -0.387, -0.061, -0.326, -0.014, -0.006, -0.018),
  paper_se   = c(0.113, 0.041, 0.085, 0.009, 0.015, 0.012,
                 0.093, 0.032, 0.075, 0.009, 0.015, 0.012)
)

compare_table3 <- function(res) {
  cmp <- merge(PAPER_TABLE3, res[, .(panel, outcome, ours_beta = beta, ours_se = se)],
               by = c("panel", "outcome"), sort = FALSE)
  cmp[, diff := round(ours_beta - paper_beta, 3)]
  cmp[, .(panel, outcome, paper_beta, ours_beta, diff, paper_se, ours_se)]
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add replication_files/R/tables.R replication_files/tests/testthat/test-tables.R
git commit -m "Add paper-style Table 3 formatting and comparison with the paper

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Figure 2

**Files:**
- Create: `replication_files/R/figures.R`
- Test: `replication_files/tests/testthat/test-figures.R`

**Interfaces:**
- Consumes: `dl_event_study()` output (columns `event_time`, `beta`, `se`, `ci_lo`, `ci_hi`, `outcome`), from Task 7.
- Produces:
  - `FIG2_PANELS`: named character vector `c(emp_share_lefb = "A. LEFB employment share", lnw_lefb = "B. LEFB log hourly wage", emp_share_usb = "C. US-born employment share", lnw_usb = "D. US-born log hourly wage")`.
  - `plot_event_study(es, dd, title)` returns a ggplot.
  - `figure2(es_all, dd)`: `es_all` is the stacked event studies; `dd` is a named numeric vector of the Panel-B difference-in-differences betas, keyed by outcome. Returns a ggplot (cowplot grid).

- [ ] **Step 1: Write the failing tests**

Create `replication_files/tests/testthat/test-figures.R`:

```r
library(data.table)

fake_es <- function(y) {
  data.table(event_time = -3:2, beta = c(0.05, 0.02, 0, -0.2, -0.3, -0.4),
             se = 0.1, outcome = y)[, `:=`(ci_lo = beta - 0.196, ci_hi = beta + 0.196)][]
}

test_that("plot_event_study draws six estimates and the DD line after adoption", {
  g <- plot_event_study(fake_es("emp_share_lefb"), dd = -0.387, title = "A")
  expect_s3_class(g, "ggplot")
  b <- ggplot2::ggplot_build(g)
  pts <- b$data[[which(vapply(g$layers, function(l) inherits(l$geom, "GeomPoint"), logical(1)))]]
  expect_equal(nrow(pts), 6)
  seg <- b$data[[which(vapply(g$layers, function(l) inherits(l$geom, "GeomSegment"), logical(1)))]]
  expect_equal(c(seg$x, seg$xend, seg$y), c(0, 2, -0.387))
})

test_that("figure2 builds all four panels", {
  es_all <- rbindlist(lapply(names(FIG2_PANELS), fake_es))
  dd <- setNames(c(-0.387, -0.014, -0.300, -0.006), names(FIG2_PANELS))
  g <- figure2(es_all, dd)
  expect_s3_class(g, "ggplot")
  expect_error(figure2(es_all[outcome != "lnw_usb"], dd), "lnw_usb")
})
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat', filter = 'figures')"`
Expected: FAIL with `could not find function "plot_event_study"`.

- [ ] **Step 3: Write `figures.R`**

Create `replication_files/R/figures.R`:

```r
# Figure 2: distributed-lag event studies, styled after the paper.
library(ggplot2)

FIG2_PANELS <- c(
  emp_share_lefb = "A. LEFB employment share",
  lnw_lefb       = "B. LEFB log hourly wage",
  emp_share_usb  = "C. US-born employment share",
  lnw_usb        = "D. US-born log hourly wage"
)

plot_event_study <- function(es, dd, title) {
  ggplot(es, aes(event_time, beta)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_vline(xintercept = -0.5, linetype = "dotted") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15,
                  linetype = "dashed", colour = "grey40") +
    geom_point(size = 2) +
    geom_segment(data = data.frame(x = 0, xend = 2, y = dd),
                 aes(x = x, xend = xend, y = y, yend = y),
                 inherit.aes = FALSE, colour = "grey50", linewidth = 0.8) +
    scale_x_continuous(breaks = -3:2) +
    labs(title = title, x = "Event time (years)", y = "Effect of SC") +
    theme_classic(base_size = 10)
}

figure2 <- function(es_all, dd) {
  missing <- setdiff(names(FIG2_PANELS), unique(es_all$outcome))
  if (length(missing)) stop("event studies missing for: ", paste(missing, collapse = ", "))
  panels <- lapply(names(FIG2_PANELS), function(y) {
    plot_event_study(es_all[es_all$outcome == y, ], dd[[y]], FIG2_PANELS[[y]])
  })
  cowplot::plot_grid(plotlist = panels, ncol = 2)
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 5: Commit**

```bash
git add replication_files/R/figures.R replication_files/tests/testthat/test-figures.R
git commit -m "Add Figure 2 event-study plots

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Results runner on the real data

**Files:**
- Create: `replication_files/section 4 R.Rmd`
- Create (generated, committed): `replication_files/output/table3_estimates.csv`, `table3_compare.csv`, `event_study.csv`, `figure2.png`

**Interfaces:**
- Consumes:
  - `cz_panel.rds` (Task 5).
  - `add_sc_leads_lags`, `run_table3`, `fit_sc`, `dl_event_study` (Tasks 6–7).
  - `format_table3`, `compare_table3` (Task 8); `figure2`, `FIG2_PANELS` (Task 9).
- Produces the four output files. The paper (Task 11) reads them by these exact names. `table3_estimates.csv` has the `run_table3()` columns. `event_study.csv` has the `dl_event_study()` columns for the four `FIG2_PANELS` outcomes.

- [ ] **Step 1: Write the runner**

Create `replication_files/section 4 R.Rmd`:

````markdown
---
title: "03_results"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = TRUE)
for (f in list.files(here::here("replication_files", "R"), pattern = "\\.R$",
                     full.names = TRUE)) source(f)
paths <- project_paths()
dir.create(paths$output, showWarnings = FALSE)
```

```{r panel}
check_inputs(paths$cz_panel)
panel <- add_sc_leads_lags(readRDS(paths$cz_panel))
```

## Table 3

```{r table3}
t3 <- run_table3(panel)
knitr::kable(format_table3(t3))
knitr::kable(compare_table3(t3), digits = 3)
fwrite(t3, file.path(paths$output, "table3_estimates.csv"))
fwrite(compare_table3(t3), file.path(paths$output, "table3_compare.csv"))
```

## Figure 2

```{r figure2, fig.width=8, fig.height=6}
es_all <- rbindlist(lapply(names(FIG2_PANELS), function(y) dl_event_study(panel, y)))
dd <- vapply(names(FIG2_PANELS),
             function(y) unname(coef(fit_sc(panel, y, bartik = TRUE))["SC_frac"]),
             numeric(1))
fig <- figure2(es_all, dd)
fig
fwrite(es_all, file.path(paths$output, "event_study.csv"))
ggplot2::ggsave(file.path(paths$output, "figure2.png"), fig,
                width = 8, height = 6, dpi = 300)
```
````

- [ ] **Step 2: Knit it**

Run: `Rscript -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('replication_files/section 4 R.Rmd')"`

Expected:
- All four files appear in `replication_files/output/`.
- In `table3_compare.csv`, every `ours_beta` has the same sign as `paper_beta`, and Panel B column 1 is within about 0.1 of −0.387.
- `figure2.png` shows pre-period points near 0 and negative post-period points in panel A.

If a coefficient differs by more than 2 paper standard errors, do not change the specification to force a match. Record it for the Results section (Task 12). The assignment asks for discrepancies to be discussed.

- [ ] **Step 3: Commit (outputs are small, contain no microdata, and the paper needs them)**

```bash
git add "replication_files/section 4 R.Rmd" "replication_files/section 4 R.html" replication_files/output
git commit -m "Run Table 3 and Figure 2 on the real panel

<paste the compare_table3 table here>

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Paper scaffold, bibliography and render

**Files:**
- Create: `paper/paper.Rmd`
- Create: `paper/references.bib`
- Generated: `paper/paper.docx` (committed for the group to review)

**Interfaces:**
- Consumes: the four files in `replication_files/output/` (Task 10), plus `format_table3()` and `TABLE3_OUTCOMES` (sourced from `R/`).
- Produces: a Word document with six section headings and the content checklists hidden in HTML comments (pandoc does not render them). It includes Table 1 (replicated Table 3), Table 2 (comparison with the paper), Figure 1 (replicated Figure 2), inline numbers and a bibliography.

- [ ] **Step 1: Write `references.bib`**

Every entry was checked against the reference list of `original_files/immigration_paper.pdf`.

```bibtex
@article{east2023,
  author  = {East, Chloe N. and Hines, Annie L. and Luck, Philip and Mansour, Hani and Vel{\'a}squez, Andrea},
  title   = {The Labor Market Effects of Immigration Enforcement},
  journal = {Journal of Labor Economics},
  year    = {2023},
  volume  = {41},
  number  = {4},
  pages   = {957--996},
  doi     = {10.1086/721152}
}
@techreport{alsan2018,
  author      = {Alsan, Marcella and Yang, Crystal},
  title       = {Fear and the Safety Net: Evidence from Secure Communities},
  institution = {National Bureau of Economic Research},
  type        = {NBER Working Paper},
  number      = {24731},
  year        = {2018}
}
@article{cox2013,
  author  = {Cox, Adam B. and Miles, Thomas J.},
  title   = {Policing Immigration},
  journal = {University of Chicago Law Review},
  year    = {2013},
  volume  = {80},
  number  = {1},
  pages   = {87--136}
}
@article{miles2014,
  author  = {Miles, Thomas J. and Cox, Adam B.},
  title   = {Does Immigration Enforcement Reduce Crime? Evidence from Secure Communities},
  journal = {Journal of Law and Economics},
  year    = {2014},
  volume  = {57},
  number  = {4},
  pages   = {937--973}
}
@article{autor2013,
  author  = {Autor, David H. and Dorn, David},
  title   = {The Growth of Low-Skill Service Jobs and the Polarization of the US Labor Market},
  journal = {American Economic Review},
  year    = {2013},
  volume  = {103},
  number  = {5},
  pages   = {1553--1597}
}
@article{bartik1992,
  author  = {Bartik, Timothy},
  title   = {The Effects of State and Local Taxes on Economic Development: A Review of Recent Research},
  journal = {Economic Development Quarterly},
  year    = {1992},
  volume  = {6},
  number  = {1},
  pages   = {102--110}
}
@techreport{schmidheiny2020,
  author      = {Schmidheiny, Kurt and Siegloch, Sebastian},
  title       = {On Event Studies and Distributed-Lags in Two-Way Fixed Effects Models: Identification, Equivalence, and Generalization},
  institution = {Centre for Economic Policy Research},
  type        = {CEPR Discussion Paper},
  number      = {13477},
  year        = {2020}
}
@techreport{watson2013,
  author      = {Watson, Tara},
  title       = {Enforcement and Immigrant Location Choice},
  institution = {National Bureau of Economic Research},
  type        = {NBER Working Paper},
  number      = {19626},
  year        = {2013}
}
@misc{ruggles2017,
  author       = {Ruggles, Steven and Genadek, Katie and Goeken, Ronald and Grover, Josiah and Sobek, Matthew},
  title        = {Integrated Public Use Microdata Series: Version 7.0},
  howpublished = {Minneapolis: University of Minnesota},
  year         = {2017}
}
```

The group's own extract came from a newer IPUMS USA version. In Task 12, the Data-section writer should add the citation that IPUMS shows on the extract's page (My Data → extract 1) in addition to `ruggles2017`.

- [ ] **Step 2: Write `paper.Rmd`**

````markdown
---
title: "Replicating \"The Labor Market Effects of Immigration Enforcement\""
subtitle: "ECO 411 Replication Project"
author: "Jacob Farmer, Cam Townswick, and group members"
date: "December 4, 2026"
output: word_document
bibliography: references.bib
nocite: '@*'
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE, message = FALSE, warning = FALSE)
library(data.table)
for (f in list.files(here::here("replication_files", "R"), pattern = "\\.R$",
                     full.names = TRUE)) source(f)
out <- here::here("replication_files", "output")
t3  <- fread(file.path(out, "table3_estimates.csv"))
cmp <- fread(file.path(out, "table3_compare.csv"))
es  <- fread(file.path(out, "event_study.csv"))
b   <- function(pan, y) sprintf("%.3f", t3[panel == pan & outcome == y, beta])
pct <- function(pan, y) sprintf("%.1f", abs(t3[panel == pan & outcome == y, pct]))
```

# Introduction

<!-- Writer checklist (about 300 words):
- The paper: East, Hines, Luck, Mansour & Velásquez [@east2023]. Question: how did Secure Communities (SC), a police-based enforcement program rolled out county by county in 2008-13, affect the employment and wages of likely undocumented immigrants (LEFB) and US-born workers?
- Their main findings (abstract, p. 957): SC lowered LEFB employment, which they attribute both to deportations and to changes among immigrants who stay. It also lowered US-born employment and wages.
- Why we found it interesting (your own reasons).
- Related work: SC and the safety net [@alsan2018]; SC and crime [@miles2014]; enforcement and where immigrants live [@watson2013].
- What we replicate: Table 3 and Figure 2.
-->

# Background

<!-- Writer checklist (about 350 words):
- How SC worked (paper pp. 963-964): fingerprints taken at arrest were checked against DHS's IDENT database; ICE could issue a detainer (hold up to 48 hours); no conviction was needed. Of about 454,000 people removed, 21% had no conviction (Table 1).
- Rollout (pp. 965-966): a federal program; counties could not opt out. Activated county by county from 2008 until nationwide in 2013; later mass activations made timing closer to random [@cox2013].
- Replaced by the Priority Enforcement Program (PEP) at the end of 2014, which is why the sample stops in 2014.
- Table 2 of the paper: changes in CZ characteristics from 2005 to 2007 barely predict adoption year.
-->

# Data

<!-- Writer checklist (about 350 words):
- ACS 2005-2014 1% samples via IPUMS USA [@ruggles2017; add the IPUMS citation from our extract]. Who collects it: the Census Bureau. Why 2005: it is the first year with the needed geography.
- Geography: Consistent PUMAs mapped to 740 commuting zones (CZs) with the authors' crosswalk [@autor2013].
- Samples: ages 20-64. LEFB = foreign-born with high school or less (no citizenship condition, because of misreporting). Excludes military, public administration and group quarters.
- Outcomes: employment share = 100 x employed / 2005 working-age CZ population. Hourly wage = annual earnings / (weeks x usual hours) for full-time workers (30+ hours), in 2014 dollars, winsorized at the 2.5th and 97.5th percentiles.
- Authors' files we used: SC exposure by CZ-year (SC_frac), pop2000 weights, Bartik shift-share controls [@bartik1992].
- Strengths: nationally representative, large, has local geography. Weaknesses: undocumented status is not observed; undercount of undocumented immigrants; weeks worked reported in intervals.
- Our differences: report the Table A1 comparison from section 3 R.html (our means vs. the paper's).
-->

# Empirical Strategy

<!-- Writer checklist (about 350 words). The assignment says this section MUST be in your own words:
- Equation (1): Y_jt = a + b*SC_jt + X'_jt g + CZ fixed effects + year fixed effects + CZ-specific linear trends + e. SC_jt runs from 0 to 1 (share of the CZ population covered, times the share of the year). Weighted by 2000 CZ population; standard errors clustered by CZ.
- Panel A: no controls. Panel B: adds Bartik labor-demand controls for foreign-born and US-born workers.
- Identifying assumption: no time-varying CZ factors correlated with the timing of SC adoption.
- Equation (2), the distributed-lag event study [@schmidheiny2020]: two leads and lags 0-2, cumulated, with event time -1 as the reference. Pre-period estimates near zero support parallel trends.
- Our implementation: R and fixest, czone[year] for the CZ trends. Same specification as the authors' reghdfe code.
-->

# Results

```{r table1}
knitr::kable(format_table3(t3),
             caption = "Table 1. Replication of East et al. (2023) Table 3: effects of SC on LEFB employment share and log hourly wages")
```

```{r table2}
knitr::kable(cmp[panel == "B"], digits = 3,
             caption = "Table 2. Our estimates vs. the original (Panel B, with Bartik controls)")
```

```{r figure1, fig.cap="Figure 1. Replication of East et al. (2023) Figure 2: distributed-lag estimates (95% CIs dashed; gray line = DD estimate)"}
knitr::include_graphics(file.path(out, "figure2.png"))
```

<!-- Writer checklist (about 450 words):
- Headline: we estimate that SC lowered the LEFB employment share by `r b("B", "emp_share_lefb")` points (`r pct("B", "emp_share_lefb")`% of the mean), compared with -0.387 (5.74%) in the paper.
- Males vs. females: `r b("B", "emp_share_lefb_m")` vs. `r b("B", "emp_share_lefb_f")` (paper: -0.326 vs. -0.061).
- Wages: `r b("B", "lnw_lefb")` (paper: -0.014, p = .13).
- Figure 1: are pre-trends flat? Do the post-period estimates match the DD line? How do the US-born panels compare (paper Table 4: -0.300 employment, -0.006 log wage)?
- Discrepancies and likely causes: the IPUMS sample/version, the occupation and industry rules, winsorization details, and the treatment of CZ-years with no full-time LEFB workers.
-->

# Conclusion

<!-- Writer checklist (about 250 words):
- What we did, how close we got, what we learned (e.g., why the 2005 population denominator captures both deportation and employment effects).
- Next steps: Callaway-Sant'Anna robustness, Table 4 (US-born), dropping early adopters.
-->

# References
````

- [ ] **Step 3: Render it**

Run: `Rscript -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('paper/paper.Rmd')"`

Expected:
- `paper/paper.docx` opens in Word.
- It has six headings, two tables, one figure and a References section with all 9 entries. `nocite: '@*'` lists every `.bib` entry, even while the citations are still inside comments.

- [ ] **Step 4: Commit**

```bash
git add paper/paper.Rmd paper/references.bib paper/paper.docx
git commit -m "Add paper scaffold with replicated tables, figure, and bibliography

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Group writes the prose (human task, Nov 29 – Dec 2)

This task is for the group, not an agent. The assignment grades the students' writing and requires the Empirical Strategy section to be in their own words. If an agent executes this plan, it stops here, reports the Task 10 comparison table and hands off.

- [ ] **Step 1: Split the sections.** Suggested split:
  - Introduction + Conclusion: one person.
  - Background: one person.
  - Data: one person (whoever handled IPUMS).
  - Empirical Strategy: one person.
  - Results: one person (whoever ran Tasks 5 and 10).
- [ ] **Step 2: Write each section below its heading in `paper/paper.Rmd`.** Use the hidden checklist and cite with `[@key]` so the references appear. Delete each checklist comment when the section is done. Keep inline `` `r b(...)` `` numbers instead of typing numbers by hand, so the text updates if results change.
- [ ] **Step 3: Write up every discrepancy** in `replication_files/output/table3_compare.csv` larger than one paper standard error in Results, with a likely cause.
- [ ] **Step 4: Commit each section as it is finished.** For example: `git commit -m "Draft Data section"`.

---

### Task 13: Final checks before submission (Dec 3)

**Files:**
- Modify: `README.md` (run instructions for Sections 4 and paper)

- [ ] **Step 1: Run the full test suite**

Run: `Rscript -e "testthat::test_dir('replication_files/tests/testthat')"`
Expected: `FAIL 0`.

- [ ] **Step 2: Render the paper and count words**

Run:

```bash
Rscript -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('paper/paper.Rmd'); rmarkdown::pandoc_convert(here::here('paper','paper.docx'), to = 'plain', output = here::here('paper','paper.txt')); cat('words:', length(scan(here::here('paper','paper.txt'), what = '', quiet = TRUE)), '\n')"
```

Expected: `words:` between about 1,800 and 2,600. This count includes tables and references. If it is far outside that range, adjust the sections.

- [ ] **Step 3: Check the assignment requirements in `paper.docx`:**
  - Six sections in order.
  - 1–2 tables (Table 1, Table 2).
  - 1–2 figures (Figure 1).
  - References list with at least 5 entries.
  - No leftover `<!--` checklists: `grep -c "<!--" paper/paper.Rmd` → `0`.
  - 5–7 pages in Word.
- [ ] **Step 4: Add run instructions to `README.md`.** Append:

```markdown
5. Knit `replication_files/section 4 R.Rmd`. This writes Table 3 and Figure 2 to `replication_files/output/`.
6. Knit `paper/paper.Rmd` to produce `paper/paper.docx` (needs only `replication_files/output/`).
```

- [ ] **Step 5: Commit**

```bash
rm -f paper/paper.txt
git add README.md paper/paper.Rmd paper/paper.docx
git commit -m "Final paper render and run instructions

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Not in this plan

- Deleting `data conversion.Rmd`, `ipums_data.RData` and `load_data.Rmd`. The group decides.
- Robustness checks beyond Table 3 and Figure 2 (Callaway–Sant'Anna, Table 4). They can be mentioned as next steps in the Conclusion.
