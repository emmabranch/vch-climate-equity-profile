# =============================================================================
# 02_build_index.R
# Project: Climate resilience and equity profile of VCH communities
# Purpose: Clean the raw data, build a transparent social vulnerability index
#          (SVI) for dissemination areas (DAs) in the VCH region, compare it with
#          Statistics Canada's CISV and CIMD, add vegetation cover, and
#          summarise by Community Health Service Area (CHSA).
# Inputs:  data/raw/ (created by R/01_download_data.R)
# Outputs: data/processed/ (small files, committed to GitHub)
# Note:    Independent portfolio project, not affiliated with Vancouver Coastal Health
# =============================================================================

library(here)
library(dplyr)
library(tidyr)
library(readr)
library(sf)

raw_dir <- here("data", "raw")
out_dir <- here("data", "processed")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)


# -----------------------------------------------------------------------------
# 1. Read the boundaries and census data (all reprojected to BC Albers, EPSG:3005)
# -----------------------------------------------------------------------------
chsa <- st_read(file.path(raw_dir, "chsa_vch.gpkg"), quiet = TRUE) |>
  st_transform(3005) |>
  select(
    chsa_code = CMNTY_HLTH_SERV_AREA_CODE,
    chsa_name = CMNTY_HLTH_SERV_AREA_NAME,
    lha_name  = LOCAL_HLTH_AREA_NAME
  )

da <- st_read(file.path(raw_dir, "census_da_bc_2021.gpkg"), quiet = TRUE) |>
  st_transform(3005) |>
  mutate(DAUID = as.character(DAUID))


# -----------------------------------------------------------------------------
# 2. Assign each DA to a CHSA
#    Rule: the CHSA containing the DA's point-on-surface (a point guaranteed
#    to fall inside the DA). DAs outside all VCH CHSAs are dropped.
# -----------------------------------------------------------------------------
da_lookup <- suppressWarnings(st_point_on_surface(da)) |>
  select(DAUID) |>
  st_join(chsa, join = st_within) |>
  st_drop_geometry() |>
  filter(!is.na(chsa_code))

da_vch <- da |>
  inner_join(da_lookup, by = "DAUID")

message("DAs in the VCH region: ", nrow(da_vch))
message("CHSAs with at least one DA: ", n_distinct(da_vch$chsa_code), " of ", nrow(chsa))


# -----------------------------------------------------------------------------
# 3. Calculate the five indicators (percentages)
# -----------------------------------------------------------------------------
safe_pct <- function(num, den) {
  if_else(!is.na(den) & den > 0, pmin(100 * num / den, 100), NA_real_)
}

da_vch <- da_vch |>
  mutate(
    pct_65plus = safe_pct(age_65plus, age_total),
    pct_alone  = safe_pct(hh_one_person, hh_total_size),
    pct_lowinc = lim_at_pct,
    pct_renter = safe_pct(hh_renter, hh_total_tenure),
    pct_nolang = safe_pct(lang_neither, lang_total)
  )


# -----------------------------------------------------------------------------
# 4. Indicator definitions and weights (saved to data/processed for the README)
#    Equal weights: no indicator is assumed to matter more than another.
# -----------------------------------------------------------------------------
indicators <- tribble(
  ~indicator,   ~label,                                    ~weight, ~rationale,
  "pct_65plus", "Population aged 65 and over (%)",         0.2,     "Greater physiological sensitivity to heat and wildfire smoke",
  "pct_alone",  "One-person households (%)",               0.2,     "Social isolation; fewer people to notice illness during heat or smoke events",
  "pct_lowinc", "Low income, LIM-AT (%)",                  0.2,     "Less ability to afford cooling, air filtration, or temporary relocation",
  "pct_renter", "Renter households (%)",                   0.2,     "Less control over cooling, ventilation, and building upgrades",
  "pct_nolang", "No knowledge of English or French (%)",   0.2,     "Barriers to receiving heat, smoke, and emergency alerts"
)
write_csv(indicators, file.path(out_dir, "index_indicators_weights.csv"))


# -----------------------------------------------------------------------------
# 5. Build the index
#    a) Percentile-rank each indicator across VCH DAs (0 = lowest, 1 = highest).
#    b) SVI score = weighted mean of the available ranks (0 to 1).
#    c) DAs need a population > 0 and at least 4 of 5 indicators. This keeps
#       DAs where one value is suppressed (for example, low income is not
#       published for First Nations reserves) instead of dropping them.
#    d) Quintiles are relative to the VCH region (5 = most vulnerable fifth).
# -----------------------------------------------------------------------------
ind_cols  <- indicators$indicator
rank_cols <- paste0("rank_", ind_cols)
weights   <- setNames(indicators$weight, rank_cols)

ranked <- da_vch |>
  st_drop_geometry() |>
  mutate(n_indicators = rowSums(!is.na(across(all_of(ind_cols))))) |>
  filter(pop_total > 0, n_indicators >= 4) |>
  mutate(across(all_of(ind_cols), percent_rank, .names = "rank_{.col}"))

rank_mat <- as.matrix(ranked[rank_cols])
w_mat    <- matrix(weights, nrow = nrow(rank_mat), ncol = length(weights), byrow = TRUE)
ranked$svi_score <- rowSums(rank_mat * w_mat, na.rm = TRUE) /
  rowSums((!is.na(rank_mat)) * w_mat)

ranked <- ranked |>
  mutate(svi_quintile = ntile(svi_score, 5)) |>
  select(DAUID, n_indicators, all_of(rank_cols), svi_score, svi_quintile)

da_index <- da_vch |>
  left_join(ranked, by = "DAUID") |>
  mutate(in_index = !is.na(svi_score))

message("DAs included in the index: ", sum(da_index$in_index),
        " (excluded: ", sum(!da_index$in_index), ")")


# -----------------------------------------------------------------------------
# 6. Add the Statistics Canada benchmarks and vegetation cover
# -----------------------------------------------------------------------------
find_file <- function(folder, pattern) {
  path <- list.files(file.path(raw_dir, folder), pattern = pattern,
                     recursive = TRUE, full.names = TRUE)
  stopifnot("File not found" = length(path) == 1)
  path
}

# Canadian Index of Social Vulnerability, 2021 (national scores and quintiles)
cisv <- read_csv(
  find_file("cisv", "cisv_scores_quintiles-eng\\.csv$"),
  col_types = cols(`Dissemination Area (DA)` = col_character()),
  show_col_types = FALSE
) |>
  transmute(
    DAUID              = `Dissemination Area (DA)`,
    cisv_score         = `CISV Scores`,
    cisv_quintile      = `CISV Quintiles`,
    cisv_top_dimension = `CISV Most Vulnerable Dimension`
  )

# Canadian Index of Multiple Deprivation, 2021 (BC index, quintiles)
cimd <- read_csv(
  find_file("cimd", "bc_scores_quintiles_EN\\.csv$"),
  col_types = cols(`Dissemination Area (DA)` = col_character()),
  show_col_types = FALSE
) |>
  transmute(
    DAUID                 = `Dissemination Area (DA)`,
    cimd_residential_q    = `Residential instability Quintiles`,
    cimd_ethnocultural_q  = `Ethno-cultural composition Quintiles`,
    cimd_economic_q       = `Economic dependency Quintiles`,
    cimd_situational_q    = `Situational vulnerability Quintiles`
  )

# Fraction of vegetation cover (%), averaged over 2019 to 2024
veg <- read_csv(
  file.path(raw_dir, "vegetation_cover_bc_da.csv"),
  col_types = cols(GeoUID = col_character(), DGUID = col_character()),
  show_col_types = FALSE
) |>
  filter(`Urban vegetation cover` == "Fraction of vegetation cover") |>
  group_by(DAUID = GeoUID) |>
  summarise(
    fvc_pct   = mean(VALUE, na.rm = TRUE),
    fvc_years = n_distinct(REF_DATE),
    .groups   = "drop"
  )

da_index <- da_index |>
  left_join(cisv, by = "DAUID") |>
  left_join(cimd, by = "DAUID") |>
  left_join(veg,  by = "DAUID")

message("VCH DAs with vegetation cover data: ", sum(!is.na(da_index$fvc_pct)))


# -----------------------------------------------------------------------------
# 7. Validation: how closely does our index agree with established indices?
#    Spearman rank correlations across VCH DAs in the index.
# -----------------------------------------------------------------------------
idx <- st_drop_geometry(da_index) |> filter(in_index)
rho <- function(x, y) cor(x, y, method = "spearman", use = "complete.obs")

validation <- tibble(
  comparison = c(
    "SVI vs CISV score (Statistics Canada social vulnerability)",
    "SVI vs CIMD economic dependency quintile",
    "SVI vs CIMD situational vulnerability quintile",
    "SVI vs CIMD residential instability quintile",
    "SVI vs vegetation cover (%)"
  ),
  spearman_rho = c(
    rho(idx$svi_score, idx$cisv_score),
    rho(idx$svi_score, idx$cimd_economic_q),
    rho(idx$svi_score, idx$cimd_situational_q),
    rho(idx$svi_score, idx$cimd_residential_q),
    rho(idx$svi_score, idx$fvc_pct)
  ),
  n_da = c(
    sum(complete.cases(idx$svi_score, idx$cisv_score)),
    sum(complete.cases(idx$svi_score, idx$cimd_economic_q)),
    sum(complete.cases(idx$svi_score, idx$cimd_situational_q)),
    sum(complete.cases(idx$svi_score, idx$cimd_residential_q)),
    sum(complete.cases(idx$svi_score, idx$fvc_pct))
  )
) |>
  mutate(spearman_rho = round(spearman_rho, 2))

print(validation)
write_csv(validation, file.path(out_dir, "index_validation.csv"))


# -----------------------------------------------------------------------------
# 8. Priority flag: high vulnerability AND low vegetation
#    Priority = SVI quintile 5 AND vegetation cover in the lowest third of VCH
#    DAs that have vegetation data. DAs without vegetation data cannot be flagged.
# -----------------------------------------------------------------------------
fvc_low_cut <- quantile(idx$fvc_pct, 1 / 3, na.rm = TRUE)
message("Low vegetation threshold (lowest third): ", round(fvc_low_cut, 1), "%")

da_index <- da_index |>
  mutate(priority = coalesce(svi_quintile == 5 & fvc_pct <= fvc_low_cut, FALSE))

message("Priority DAs: ", sum(da_index$priority))


# -----------------------------------------------------------------------------
# 9. CHSA summary (population-weighted where relevant)
# -----------------------------------------------------------------------------
wmean <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok)) NA_real_ else sum(x[ok] * w[ok]) / sum(w[ok])
}

chsa_summary <- da_index |>
  st_drop_geometry() |>
  group_by(chsa_code, chsa_name, lha_name) |>
  summarise(
    n_da             = n(),
    population       = sum(pop_total, na.rm = TRUE),
    svi_mean         = wmean(svi_score, pop_total),
    pct_pop_svi_q5   = 100 * sum(pop_total[svi_quintile %in% 5], na.rm = TRUE) / population,
    fvc_mean         = wmean(fvc_pct, pop_total),
    pct_pop_priority = 100 * sum(pop_total[priority], na.rm = TRUE) / population,
    across(all_of(ind_cols), ~ wmean(.x, pop_total)),
    .groups = "drop"
  ) |>
  mutate(svi_rank = min_rank(desc(svi_mean))) |>
  arrange(svi_rank)

print(select(chsa_summary, svi_rank, chsa_name, population, svi_mean,
             pct_pop_svi_q5, fvc_mean), n = 15)


# -----------------------------------------------------------------------------
# 10. Save outputs (simplified shapes in WGS84 for the web map)
# -----------------------------------------------------------------------------
da_out <- da_index |>
  st_simplify(dTolerance = 5, preserveTopology = TRUE) |>
  st_transform(4326)
st_write(da_out, file.path(out_dir, "vch_da_index.gpkg"), delete_dsn = TRUE, quiet = TRUE)

chsa_out <- chsa |>
  left_join(chsa_summary, by = c("chsa_code", "chsa_name", "lha_name")) |>
  st_simplify(dTolerance = 20, preserveTopology = TRUE) |>
  st_transform(4326)
st_write(chsa_out, file.path(out_dir, "vch_chsa_summary.gpkg"), delete_dsn = TRUE, quiet = TRUE)

write_csv(chsa_summary, file.path(out_dir, "vch_chsa_summary.csv"))

message("Done. Outputs saved in ", out_dir)
list.files(out_dir)
