# Format Table 3 the way East et al. (2023) print it, and compare with the paper.
library(data.table)

stars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
}

# One block per panel: SC estimate with stars, (SE), CZ-year trends, Bartiks,
# Y mean, % effect (employment columns only) and observations.
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
