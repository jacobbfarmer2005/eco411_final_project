# Shared file locations, built from the repo root so the code runs on any
# teammate's computer. Set the ACS_DAT environment variable to read the raw
# IPUMS .dat(.gz) from somewhere other than replication_files/data/raw/.

project_paths <- function() {
  raw_dir <- here::here("replication_files", "data", "raw")
  raw_candidates <- file.path(raw_dir, c("usa_00001.dat.gz", "usa_00001.dat"))
  raw_default <- raw_candidates[file.exists(raw_candidates)][1]
  if (is.na(raw_default)) raw_default <- raw_candidates[1]

  author <- here::here("original_files", "data")
  clean  <- here::here("replication_files", "data", "clean")

  list(
    raw_ddi   = here::here("replication_files", "usa_00001.xml"),
    raw_dat   = Sys.getenv("ACS_DAT", raw_default),
    bartik    = file.path(author, "final_bartik_acs_cpuma0010_updated.dta"),
    cw        = file.path(author, "cw_cpuma2010_czone.dta"),
    policy    = file.path(author, "policy_pop_cz_5_13_22.dta"),
    acs_clean = file.path(clean, "acs_person.rds"),
    cz_panel  = file.path(clean, "cz_panel.rds"),
    output    = here::here("replication_files", "output")
  )
}

check_inputs <- function(paths) {
  absent <- paths[!file.exists(paths)]
  if (length(absent)) stop("missing input files:\n", paste(absent, collapse = "\n"))
  invisible(TRUE)
}
