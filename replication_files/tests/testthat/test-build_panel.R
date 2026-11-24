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
