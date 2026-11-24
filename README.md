Final Project for ECO 411 - Taught by James Flynn

## Running the replication code

1. Get the raw IPUMS extract `usa_00001.dat` (or `.dat.gz`) and put it in
   `replication_files/data/raw/`, or set `Sys.setenv(ACS_DAT = "path/to/usa_00001.dat")`.
   The codebook `replication_files/usa_00001.xml` is already in the repo.
2. Knit `replication_files/01_clean_acs.Rmd`. This writes `data/clean/acs_person.rds`.
3. Knit `replication_files/02_build_panel.Rmd`. This writes `data/clean/cz_panel.rds`
   and prints a comparison with the paper's Table 3/4 means.
4. Tests: `testthat::test_dir("replication_files/tests/testthat")` from the repo root.

Functions live in `replication_files/R/`; the `.Rmd` files only call them.
Data files under `replication_files/data/` are not committed.
