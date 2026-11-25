# Figure 2: distributed-lag event studies, styled after East et al. (2023).
library(ggplot2)

# Figure 2 panels, in the paper's order.
FIG2_PANELS <- c(
  emp_share_lefb = "A. LEFB employment share",
  lnw_lefb       = "B. LEFB log hourly wage",
  emp_share_usb  = "C. US-born employment share",
  lnw_usb        = "D. US-born log hourly wage"
)

# One panel: point estimates, dashed 95% intervals, zero line, a vertical line
# between event times -1 and 0, and a gray line over 0-2 at the DD estimate
# (Table 3 / Table 4 Panel B).
plot_event_study <- function(es, dd, title) {
  ggplot(es, aes(event_time, beta)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_vline(xintercept = -0.5, linetype = "dotted") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15,
                  linetype = "dashed", colour = "grey40") +
    geom_point(size = 2) +
    geom_segment(data = data.frame(x = 0, xend = 2, y = dd),
                 aes(x = x, xend = xend, y = y, yend = y),
                 inherit.aes = FALSE, colour = "grey50", linewidth = 0.8) +
    scale_x_continuous(breaks = -3:2) +
    labs(title = title, x = "Event time (years)", y = "Effect of SC") +
    theme_classic(base_size = 10)
}

# The four panels in a 2 x 2 grid. `dd` is a named vector of DD estimates,
# keyed by outcome.
figure2 <- function(es_all, dd) {
  missing <- setdiff(names(FIG2_PANELS), unique(es_all$outcome))
  if (length(missing)) stop("event studies missing for: ", paste(missing, collapse = ", "))
  panels <- lapply(names(FIG2_PANELS), function(y) {
    plot_event_study(es_all[es_all$outcome == y, ], dd[[y]], FIG2_PANELS[[y]])
  })
  cowplot::plot_grid(plotlist = panels, ncol = 2)
}
