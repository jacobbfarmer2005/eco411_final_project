# Source every analysis file, so later tasks can add files to script_files/ without
# editing this helper.
for (f in list.files(here::here("replication_files", "rmd_files", "script_files"), pattern = "\\.R$",
                     full.names = TRUE)) {
  source(f)
}

# One toy ACS person per element; any argument overrides that column.
toy_person <- function(...) {
  base <- list(
    year = 2005, statefip = 1, cpuma0010 = 1, gq = 1, perwt = 10,
    sex = 1, age = 30, bpl = 1, educ = 6, educd = 63, empstat = 1,
    classwkr = 2, classwkrd = 22, occ2010 = 4700, ind1990 = 591,
    wkswork2 = 6, uhrswork = 40, incwage = 30000, school = 1, cpi99 = 0.8
  )
  args <- list(...)
  base[names(args)] <- args
  tibble::as_tibble(base)
}

# Balanced CZ x year panel with staggered SC adoption and a known effect.
sim_panel <- function(n_cz = 80, beta = -0.5, seed = 1) {
  set.seed(seed)
  years <- 2005:2014
  adopt <- sample(2008:2013, n_cz, replace = TRUE)
  pop   <- runif(n_cz, 1e4, 1e6)
  a     <- rnorm(n_cz, 5)
  g     <- rnorm(n_cz, 0, 0.1)
  yfe   <- rnorm(length(years))
  p <- data.table::CJ(czone = seq_len(n_cz), year = years)
  p[, `:=`(
    SC_frac = as.numeric(year >= adopt[czone]),
    pop2000 = pop[czone],
    shift_share_sample_fb  = rnorm(.N, 100, 10),
    shift_share_sample_usb = rnorm(.N, 100, 10)
  )]
  p[, y := a[czone] + g[czone] * (year - 2005) + yfe[year - 2004] +
         beta * SC_frac + 0.01 * shift_share_sample_fb + rnorm(.N, 0, 0.05)]
  p[]
}
