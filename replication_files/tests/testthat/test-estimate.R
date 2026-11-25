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
