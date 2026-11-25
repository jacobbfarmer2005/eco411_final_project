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
