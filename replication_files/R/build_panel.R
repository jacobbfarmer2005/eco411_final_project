# Step 2 of the pipeline: build the commuting-zone-by-year panel.
# Rules follow original_files/code/2_EHLMV_results_emp_FINAL.do and
# 3_EHLMV_results_wages_FINAL.do.
library(data.table)

# Counts summed across CPUMAs with the crosswalk's afactor weights.
cnt <- c("emp_lefb_m", "emp_lefb_f", "emp_usb", "pop_all",
         "shift_share_sample_fb", "shift_share_sample_usb")

# Wages averaged across CPUMAs with afactor weights: all LEFB, LEFB women,
# LEFB men (Table 3) and US-born (Figure 2).
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

# Weighted employment counts and working-age population by CPUMA and year.
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
# `keep` selects the group's rows (one logical per row of acs).
cell_wage_mean <- function(acs, keep) {
  rows <- which(keep & !is.na(acs$wage_ft))
  if (!length(rows)) {
    return(data.table(cpuma0010 = integer(), year = integer(), w = numeric()))
  }
  cells <- acs[rows, .(w = weighted.mean(wage_ft, perwt)),
               by = .(cpuma0010, year, ind1990, occ2010)]
  cells[, .(w = mean(w)), by = .(cpuma0010, year)]
}

# One wage column per group; a group with no full-time workers in a
# CPUMA-year gets NA.
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

# Weighted mean over non-missing values; NA (not NaN) when all are missing,
# like Stata's collapse (mean) [pweight=af].
wmean_na <- function(x, w) {
  ok <- !is.na(x)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

# Stata: collapse (sum) counts (mean) wages [pweight=af], by(czone year).
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

# Stata: keep 2005-2014, drop CZ-years without SC data, and drop CZ 34701,
# which has no ACS respondents.
trim_panel <- function(p) {
  p[year >= 2005 & year <= 2014 & !is.na(SC_frac) & czone != 34701]
}

# Employment share = 100 x group employment / CZ working-age population in
# 2005 (Stata's efixpop_*); wages enter in logs (Stata's lw2w_ft_*).
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
