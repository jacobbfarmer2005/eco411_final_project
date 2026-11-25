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
