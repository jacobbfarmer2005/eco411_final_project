# Step 3 of the pipeline: estimate the effects of Secure Communities.
# Specification follows the reghdfe calls in 2_EHLMV_results_emp_FINAL.do
# and 3_EHLMV_results_wages_FINAL.do.
library(data.table)

BARTIKS <- c("shift_share_sample_fb", "shift_share_sample_usb")

# Table 3 columns, in the paper's order.
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

# Stata: leads/lags within CZ; lags before 2005 are set to 0 because SC did
# not exist yet. Leads past 2014 stay missing, which drops 2013-2014 from the
# distributed-lag regression, as in Stata.
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

# Equation (1): czone[year] absorbs CZ fixed effects and CZ-specific linear
# trends (Stata: absorb(year czone i.czone#c.year)); weighted by pop2000 and
# clustered by CZ.
fit_sc <- function(p, y, bartik = TRUE) {
  rhs <- c("SC_frac", if (bartik) BARTIKS)
  fixest::feols(sc_formula(y, rhs), data = p,
                weights = ~pop2000, cluster = ~czone)
}

# One Table 3 cell: beta, SE, p-value, pop2000-weighted Y mean over the
# estimation sample, % effect and N.
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

# Panel A: baseline. Panel B: adds the Bartik controls.
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
