# =============================================================================
# 01_data_preparation.R
# Loads and merges MICS, GIS, and IHS household survey data
# =============================================================================

packages <- c(
  "tidyverse",
  "haven",
  "labelled",
  "sf",
  "survey",
  "summarytools",
  "readxl",
  "ggrepel",
  "broom"
)


for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}


# Paths


###CHANGE THIS TO SET THE WORKING DIRECTORY TO THE MALAWI_EDUCATION Folder
# setwd()


#Leave these
raw_dir <- "data/raw"
ihs_dir <- file.path(raw_dir, "IHS_5")
mics_dir <- file.path(raw_dir, "MICS_6", "Malawi MICS6 SPSS Datasets")
gps_dir <- file.path(raw_dir, "MICS_6_GPS")
output_dir <-file.path("data/processed")


# =============================================================================
# 1. LOAD IHS-5 DATA (Integrated Household Survey)
# =============================================================================


# Household identifiers and demographics
ihs_hh <- read.csv(file.path(ihs_dir, "hh_mod_a_filt.csv"))
ihs_roster <- read.csv(file.path(ihs_dir, "HH_MOD_B.csv"))

# Education module
ihs_education <- read.csv(file.path(ihs_dir, "HH_MOD_C.csv"))

# Consumption/poverty aggregates
ihs_consumption <- read.csv(file.path(ihs_dir, "ihs5_consumption_aggregate.csv"))

# Geospatial variables
ihs_geo <- read.csv(file.path(ihs_dir, "householdgeovariables_ihs5.csv"))

# Merge IHS data at household level
# Drop columns from consumption/geo that already exist in hh to avoid duplicates
cons_new_cols <- c("case_id", setdiff(names(ihs_consumption), names(ihs_hh)))
geo_new_cols  <- c("case_id", setdiff(names(ihs_geo), names(ihs_hh)))

ihs_merged <- ihs_hh |>
  left_join(ihs_consumption[, cons_new_cols], by = "case_id") |>
  left_join(ihs_geo[, geo_new_cols], by = "case_id")

# Education data stays at individual level - merge household context
ihs_education_full <- ihs_education |>
  left_join(
    ihs_merged |>
      select(case_id, region, district, ea_id, hh_wgt, ea_lat_mod, ea_lon_mod) |>
      distinct(),
    by = "case_id"
  )

message(sprintf("  IHS households: %s", format(n_distinct(ihs_merged$case_id), big.mark = ",")))
message(sprintf("  IHS individuals with education data: %s", format(nrow(ihs_education_full), big.mark = ",")))

# =============================================================================
# 2. LOAD MICS-6 DATA (Multiple Indicator Cluster Survey)
# =============================================================================
message("\nLoading MICS-6 data...")

# Core MICS files
mics_hh <- read_sav(file.path(mics_dir, "hh.sav"))
mics_hl <- read_sav(file.path(mics_dir, "hl.sav"))  # Household listing
mics_ch <- read_sav(file.path(mics_dir, "ch.sav"))  # Children under 5
mics_fs <- read_sav(file.path(mics_dir, "fs.sav"))  # Foundational learning skills

# Select key household variables for merging
hh_merge <- mics_hh %>%
  select(
    HH1, HH2,                           # Cluster and household number (merge keys)
    HH6,                                 # Area (urban/rural)
    HH7,                                 # Region
    DISTRICT,                            # District
    starts_with("windex"),               # Wealth indices
    wscore,                              # Wealth score
    hhweight                             # Household weight
  ) %>%
  mutate(
    area = as_factor(HH6),
    region = as_factor(HH7),
    wealth_quintile = as_factor(windex5)
  )

# Merge household context into each MICS dataset
mics_merged <- mics_hl %>%
  left_join(hh_merge, by = c("HH1", "HH2"))

mics_children <- mics_ch %>%
  left_join(hh_merge, by = c("HH1", "HH2"))

mics_skills <- mics_fs %>%
  left_join(hh_merge, by = c("HH1", "HH2"))

message(sprintf("  MICS households: %s", format(n_distinct(paste(mics_hh$HH1, mics_hh$HH2)), big.mark = ",")))
message(sprintf("  MICS individuals: %s", format(nrow(mics_merged), big.mark = ",")))
message(sprintf("  MICS children (under 5): %s", format(nrow(mics_children), big.mark = ",")))
message(sprintf("  MICS foundational skills: %s", format(nrow(mics_skills), big.mark = ",")))

# =============================================================================
# 3. LOAD GIS DATA
# =============================================================================
message("\nLoading GIS data...")

# MICS cluster GPS coordinates
gps_clusters <- st_read(
  file.path(gps_dir, "GPS Datasets", "MalawiMICS2019-20GPS.shp"),
  quiet = TRUE
)

# Survey boundaries
boundaries <- st_read(
  file.path(gps_dir, "Survey Boundaries", "Shapefiles", "mics_boundaries.shp"),
  quiet = TRUE
)

# District boundaries (for mapping)
district_boundaries <- st_read(
  file.path(gps_dir, "Survey Boundaries", "Shapefiles", "mics_boundaries3.shp"),
  quiet = TRUE
)

# Geospatial covariates (environmental variables by cluster)
geo_covariates <- read_excel(
  file.path(gps_dir, "Geospatial Covariates", "MalawiMICS2019-20GeoCov.xlsx"),
  sheet = "Data - Cluster"
)

message(sprintf("  GPS clusters: %d", nrow(gps_clusters)))
message(sprintf("  Survey boundaries: %d", nrow(boundaries)))
message(sprintf("  Geospatial covariate records: %d", nrow(geo_covariates)))

# =============================================================================
# 4. MERGE MICS WITH GIS
# =============================================================================
message("\nMerging MICS with GIS data...")

# Join geo covariates to skills data via cluster number
mics_skills_geo <- mics_skills |>
  left_join(geo_covariates, by = c("HH1" = "cluster"))

message(sprintf("  MICS skills with geo covariates: %s", format(nrow(mics_skills_geo), big.mark = ",")))

# =============================================================================
# 5. CONSTRUCT ANALYSIS DATASETS
# =============================================================================
message("\nConstructing analysis datasets...")

# Get DISTRICT and hhweight from household file for merging
hh_extra <- mics_hh %>%
  select(HH1, HH2, DISTRICT, hhweight) %>%
  distinct()

# --- Out-of-school rate data (primary school age 6-13) ---
# ED9: attended school current year (1 = Yes, 2 = No)
# HL4: sex (1 = Male, 2 = Female)
# HL12: mother alive (2 = No), HL16: father alive (2 = No)
# helevel: HH head education (0 = none, 1 = primary, 2+ = secondary or higher)
# fsdisability: 1 = has functional difficulty



oosr_data <- mics_hl %>%
  filter(schage >= 6, schage <= 13) %>%
  select(-any_of("hhweight")) %>%  # Remove if it exists in mics_hl
  left_join(hh_extra, by = c("HH1", "HH2")) %>%
  left_join(
    mics_fs %>% select(HH1, HH2, LN, fsdisability),
    by = c("HH1", "HH2", "HL1" = "LN")
  ) %>%
  transmute(
    HH1, HH2,
    weight = hhweight,
    HH1, HH2,
    weight = hhweight,
    out_of_school = if_else(as.numeric(ED9) == 1, 0L, 1L),
    sex = as_factor(HL4),
    age = as.numeric(schage),
    area = as_factor(HH6),
    wealth_quintile = as_factor(windex5),
    orphan = as.integer(
      coalesce(as.numeric(HL12) == 2, FALSE) |
      coalesce(as.numeric(HL16) == 2, FALSE)
    ),
    disabled = if_else(as.numeric(fsdisability) == 1, 1L, 0L, missing = 0L),
    hh_head_completed_primary = if_else(as.numeric(helevel) >= 2, 1L, 0L, missing = 0L),
    district_code = as.numeric(DISTRICT),
    district_name = trimws(as_factor(DISTRICT))
  )

# --- Foundational reading data (from MICS foundational skills module) ---
# FL20A/B: English story words attempted/wrong
# FL22A-E: English comprehension
# FLB20A/B, FLB22A-E: Chichewa equivalents
# Foundational reading = >= 90% words correct AND >= 3/5 comprehension

reading_data <- mics_fs %>%
  left_join(
    mics_hh %>% select(HH1, HH2, DISTRICT, helevel, hhweight) %>% distinct(),
    by = c("HH1", "HH2")
  ) %>%
  filter(as.numeric(FL28) == 1, schage >= 5, schage <= 17) %>%
  mutate(
    # English story reading
    eng_attempted = na_if(as.numeric(FL20A), 99),
    eng_wrong     = na_if(as.numeric(FL20B), 99),
    eng_pct_correct = if_else(
      !is.na(eng_attempted) & eng_attempted > 0,
      (eng_attempted - replace_na(eng_wrong, 0)) / eng_attempted, 0
    ),
    eng_comp = rowSums(across(
      c(FL22A, FL22B, FL22C, FL22D, FL22E),
      ~ coalesce(as.numeric(.) == 1, FALSE)
    )),

    # Chichewa story reading
    chi_attempted = na_if(as.numeric(FLB20A), 99),
    chi_wrong     = na_if(as.numeric(FLB20B), 99),
    chi_pct_correct = if_else(
      !is.na(chi_attempted) & chi_attempted > 0,
      (chi_attempted - replace_na(chi_wrong, 0)) / chi_attempted, 0
    ),
    chi_comp = rowSums(across(
      c(FLB22A, FLB22B, FLB22C, FLB22D, FLB22E),
      ~ coalesce(as.numeric(.) == 1, FALSE)
    )),

    # Can read = meets criteria in either language
    can_read = as.integer(
      (eng_pct_correct >= 0.9 & eng_comp >= 3) |
      (chi_pct_correct >= 0.9 & chi_comp >= 3)
    )
  ) %>%
  transmute(
    HH1, HH2,
    weight = hhweight,
    can_read,
    sex = as_factor(HL4),
    age = as.numeric(schage),
    area = as_factor(HH6),
    wealth_quintile = as_factor(windex5),
    disabled = if_else(as.numeric(fsdisability) == 1, 1L, 0L, missing = 0L),
    district_code = as.numeric(DISTRICT),
    district_name = trimws(as_factor(DISTRICT))
  )

message(sprintf("  OOSR data: %s children aged 6-13", format(nrow(oosr_data), big.mark = ",")))
message(sprintf("  Reading data: %s children aged 5-17", format(nrow(reading_data), big.mark = ",")))

# =============================================================================
# 6. SAVE PROCESSED DATA
# =============================================================================
message("\nSaving processed data...")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# IHS datasets
write_csv(ihs_merged, file.path(output_dir, "ihs_households.csv"))
write_csv(ihs_education_full, file.path(output_dir, "ihs_education.csv"))

# MICS datasets
write_csv(mics_merged, file.path(output_dir, "mics_individuals.csv"))
write_csv(mics_children, file.path(output_dir, "mics_children.csv"))
write_csv(mics_skills_geo, file.path(output_dir, "mics_skills_geo.csv"))

# Analysis datasets
write_csv(oosr_data, file.path(output_dir, "oosr_data.csv"))
write_csv(reading_data, file.path(output_dir, "reading_data.csv"))

# GIS data
st_write(gps_clusters, file.path(output_dir, "mics_clusters.geojson"), delete_dsn = TRUE, quiet = TRUE)
st_write(boundaries, file.path(output_dir, "survey_boundaries.geojson"), delete_dsn = TRUE, quiet = TRUE)
st_write(district_boundaries, file.path(output_dir, "district_boundaries.geojson"), delete_dsn = TRUE, quiet = TRUE)

message("\nDone - Data preparation complete")
