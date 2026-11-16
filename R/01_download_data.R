# =============================================================================
# 01_download_data.R
# Project: Climate resilience and equity profile of VCH communities
# Purpose: Download all raw inputs into data/raw/ (gitignored; re-run to rebuild)
# Needs:   A free CensusMapper API key stored in ~/.Renviron (see README)
# Note:    Independent portfolio project, not affiliated with Vancouver Coastal Health
# =============================================================================

library(here)
library(dplyr)
library(readr)
library(sf)
library(bcdata)
library(cancensus)
library(cansim)

raw_dir <- here("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 900) # Statistics Canada files can be slow


# -----------------------------------------------------------------------------
# 1. Community Health Service Area (CHSA) boundaries, 2022 configuration
#    Source:  BC Ministry of Health, via the BC Data Catalogue
#    Record:  68f2f577-28a7-46b4-bca9-7e9770f2f357
#    Returned in BC Albers (EPSG:3005)
# -----------------------------------------------------------------------------
chsa_all <- bcdc_query_geodata("68f2f577-28a7-46b4-bca9-7e9770f2f357") |>
  collect()

# Check field names and health authority labels before filtering.
# If the column below has a different name, edit the filter() line.
glimpse(chsa_all)
chsa_all |>
  st_drop_geometry() |>
  count(HLTH_AUTHORITY_NAME)

chsa_vch <- chsa_all |>
  filter(HLTH_AUTHORITY_NAME == "Vancouver Coastal")

message("VCH CHSAs found: ", nrow(chsa_vch))
st_write(chsa_vch, file.path(raw_dir, "chsa_vch.gpkg"), delete_dsn = TRUE)


# -----------------------------------------------------------------------------
# 2. 2021 Census of Population, dissemination area (DA) level, via cancensus
#
#    Fill in each "v_CA21_XXXX" before running this section. Two quick ways:
#      a) https://censusmapper.ca/api : choose CA21, click variables, copy IDs
#      b) In the console, for example:
#         find_census_vectors("65 years and over", dataset = "CA21",
#                             type = "total", query_type = "exact")
#         find_census_vectors("Renter", dataset = "CA21",
#                             type = "total", query_type = "exact")
#         find_census_vectors("Neither English nor French", dataset = "CA21",
#                             type = "total", query_type = "exact")
#         find_census_vectors("LIM-AT", dataset = "CA21",
#                             type = "total", query_type = "keyword")
#    Several tables share labels (e.g. "65 years and over"), so pick the one
#    whose parent is the table named in each comment.
# -----------------------------------------------------------------------------
census_vectors <- c(
  pop_total       = "v_CA21_1",    # Population, 2021 (check)
  age_total       = "v_CA21_XXXX", # Total - Age groups of the population (100% data)
  age_65plus      = "v_CA21_XXXX", #   65 years and over (child of the row above)
  hh_total_size   = "v_CA21_XXXX", # Total - Private households by household size
  hh_one_person   = "v_CA21_XXXX", #   1 person
  hh_total_tenure = "v_CA21_XXXX", # Total - Private households by tenure (25% sample)
  hh_renter       = "v_CA21_XXXX", #   Renter
  lang_total      = "v_CA21_XXXX", # Total - Knowledge of official languages
  lang_neither    = "v_CA21_XXXX", #   Neither English nor French
  lim_at_pct      = "v_CA21_XXXX"  # Prevalence of low income, LIM-AT (%)
)

stopifnot(
  "Replace every v_CA21_XXXX placeholder first" = !any(grepl("XXXX", census_vectors))
)

# Confirm each ID is the variable you intended (worth a screenshot for the README)
list_census_vectors("CA21") |>
  filter(vector %in% census_vectors) |>
  select(vector, label, details) |>
  print(n = Inf)

census_da <- get_census(
  dataset    = "CA21",
  regions    = list(PR = "59"), # all of BC; trimmed to VCH spatially in step 02
  vectors    = census_vectors,
  level      = "DA",
  geo_format = "sf",
  labels     = "short"
)

message("BC DAs downloaded: ", nrow(census_da))
st_write(census_da, file.path(raw_dir, "census_da_bc_2021.gpkg"), delete_dsn = TRUE)


# -----------------------------------------------------------------------------
# 3. Canadian Index of Social Vulnerability (CISV), 2021, DA level
#    Source:  Statistics Canada, catalogue 45-20-0001 (released May 2025)
#    Used as an external benchmark for our own transparent index.
#    If this URL fails, download "CISV CSV" manually from:
#    https://www150.statcan.gc.ca/n1/pub/45-20-0001/452000012025001-eng.htm
#    and save the zip as data/raw/cisv-eng.zip
# -----------------------------------------------------------------------------
cisv_zip <- file.path(raw_dir, "cisv-eng.zip")
if (!file.exists(cisv_zip)) {
  download.file(
    "https://www150.statcan.gc.ca/pub/45-20-0001/2025001/csv/cisv-eng.zip",
    cisv_zip,
    mode = "wb"
  )
}
unzip(cisv_zip, exdir = file.path(raw_dir, "cisv"))
list.files(file.path(raw_dir, "cisv"), recursive = TRUE)


# -----------------------------------------------------------------------------
# 4. Fraction of vegetation cover (FVC) by DA, large urban areas, 2019 to 2024
#    Source:  Statistics Canada Table 38-10-0187-01 (Census of Environment)
#    Covers DAs in the Vancouver contiguously settled area only.
#    DA DGUIDs look like "2021S0512" + 8-digit DAUID; BC DAUIDs start with 59.
# -----------------------------------------------------------------------------
veg <- get_cansim("38-10-0187-01")
glimpse(veg) # check the dimension columns and units

veg_bc_da <- veg |>
  filter(startsWith(DGUID, "2021S051259"))

message("BC DA vegetation rows: ", nrow(veg_bc_da))
write_csv(veg_bc_da, file.path(raw_dir, "vegetation_cover_bc_da.csv"))


# -----------------------------------------------------------------------------
# 5. OPTIONAL: Canadian Index of Multiple Deprivation 2021, BC file
#    Archived by Statistics Canada but still downloadable. Uncomment if wanted.
# -----------------------------------------------------------------------------
# cimd_zip <- file.path(raw_dir, "cimd_bc_2021.zip")
# download.file(
#   "https://www150.statcan.gc.ca/pub/45-20-0001/2023001/csv/bc_scores_quintiles_csv-eng.zip",
#   cimd_zip, mode = "wb"
# )
# unzip(cimd_zip, exdir = file.path(raw_dir, "cimd"))


# -----------------------------------------------------------------------------
# Provenance log
# -----------------------------------------------------------------------------
writeLines(
  c(
    paste("Downloaded on:", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
    paste("R version:", R.version.string),
    paste("cancensus:", packageVersion("cancensus")),
    paste("bcdata:", packageVersion("bcdata")),
    paste("cansim:", packageVersion("cansim"))
  ),
  file.path(raw_dir, "download_log.txt")
)

message("Done. Raw files are in ", raw_dir)
