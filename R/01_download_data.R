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
# 2. 2021 Census of Population, dissemination area (DA) level
#    Source: Statistics Canada, Census Profile 2021 comprehensive download,
#            "Canada, provinces, territories, census divisions (CDs), census
#            subdivisions (CSDs) and dissemination areas (DAs) - British
#            Columbia only" (catalogue 98-401-X2021006), CSV.
#    Downloaded by hand and saved as data/raw/census_profile_bc.zip
#    (Used instead of cancensus because the free CensusMapper quota was too small.)
# -----------------------------------------------------------------------------
library(tidyr)

# 2a. Unzip and find the English data file
unzip(file.path(raw_dir, "census_profile_bc.zip"),
      exdir = file.path(raw_dir, "census_profile"))
profile_csv <- list.files(file.path(raw_dir, "census_profile"),
                          pattern = "English_CSV_data.*\\.csv$",
                          full.names = TRUE)
profile_csv # should print one file path

# 2b. Peek at the column names (the next step expects these names)
read_csv(profile_csv, n_max = 5, locale = locale(encoding = "latin1")) |>
  names()

# 2c. Census Profile characteristic IDs (from the 98-401-X2021006 metadata)
char_ids <- c(
  pop_total       = 1,    # Population, 2021
  age_total       = 8,    # Total - Age groups of the population - 100% data
  age_65plus      = 24,   #   65 years and over
  hh_total_size   = 50,   # Total - Private households by household size
  hh_one_person   = 51,   #   1 person
  lim_at_pct      = 345,  # Prevalence of low income, LIM-AT (%)
  lang_total      = 383,  # Total - Knowledge of official languages
  lang_neither    = 387,  #   Neither English nor French
  hh_total_tenure = 1414, # Total - Private households by tenure - 25% sample
  hh_renter       = 1416  #   Renter
)

# 2d. Read only the columns we need (large file: allow a few minutes)
profile <- read_csv(
  profile_csv,
  col_select = c(GEO_LEVEL, ALT_GEO_CODE, CHARACTERISTIC_ID,
                 CHARACTERISTIC_NAME, C1_COUNT_TOTAL),
  col_types  = cols(.default = col_character()),
  locale     = locale(encoding = "latin1")
) |>
  filter(as.integer(CHARACTERISTIC_ID) %in% char_ids)

# 2e. Check the IDs point to the right variables (read the names column)
profile |>
  filter(GEO_LEVEL == "Province") |>
  distinct(CHARACTERISTIC_ID, CHARACTERISTIC_NAME)

# 2f. One row per DA, one column per variable.
#     Suppressed values (symbols such as "x" or "..") become NA.
census_data <- profile |>
  filter(GEO_LEVEL == "Dissemination area") |>
  mutate(
    var   = names(char_ids)[match(as.integer(CHARACTERISTIC_ID), char_ids)],
    value = suppressWarnings(as.numeric(C1_COUNT_TOTAL))
  ) |>
  select(DAUID = ALT_GEO_CODE, var, value) |>
  pivot_wider(names_from = var, values_from = value)

summary(census_data) # lim_at_pct should be 0 to 100

# 2g. DA shapes from Statistics Canada's 2021 cartographic boundary file
da_zip <- file.path(raw_dir, "lda_000b21a_e.zip")
if (!file.exists(da_zip)) {
  download.file(
    "https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/boundary-limites/files-fichiers/lda_000b21a_e.zip",
    da_zip,
    mode = "wb"
  )
}
unzip(da_zip, exdir = file.path(raw_dir, "da_boundaries"))
da_shp <- list.files(file.path(raw_dir, "da_boundaries"),
                     pattern = "\\.shp$", full.names = TRUE)

# 2h. Join numbers to shapes, keep BC only, and save
census_da <- st_read(da_shp) |>
  filter(PRUID == "59") |>
  select(DAUID) |>
  left_join(census_data, by = "DAUID")

message("BC DAs: ", nrow(census_da))
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
# 5. Canadian Index of Multiple Deprivation 2021, BC file
#    Archived by Statistics Canada but still downloadable.
# -----------------------------------------------------------------------------

cimd_zip <- file.path(raw_dir, "cimd_bc_2021.zip")
download.file(
  "https://www150.statcan.gc.ca/pub/45-20-0001/2023001/csv/bc_scores_quintiles_csv-eng.zip",
  cimd_zip, mode = "wb"
)
unzip(cimd_zip, exdir = file.path(raw_dir, "cimd"))


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
