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

test_that("the full pipeline on toy data yields the panel-step columns", {
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
