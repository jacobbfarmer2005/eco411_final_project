# Source every analysis file, so later tasks can add files to R/ without
# editing this helper.
for (f in list.files(here::here("replication_files", "R"), pattern = "\\.R$",
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
