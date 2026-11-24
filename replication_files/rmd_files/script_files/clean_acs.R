# Step 1 of the pipeline: clean the person-level ACS extract.
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

# Employed = working, outside group quarters and military/public admin, and
# in an occupation from the 2005 reference set, as in the Stata code.
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

# Sanity checks on the cleaned data. Comparisons with the paper's means are
# made at the commuting-zone level in the panel step (compare_to_paper).
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
