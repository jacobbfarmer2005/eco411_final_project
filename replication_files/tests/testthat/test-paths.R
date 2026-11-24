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
