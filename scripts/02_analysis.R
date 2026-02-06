# =============================================================================
# 02_analysis.R
# Analysis: summary tables, regressions, and district aggregates
# =============================================================================

library(tidyverse)
library(broom)

# Run data prep first (or comment out if already run and loading from CSVs)
# source("scripts/01_data_preparation.R")

output_dir <- "outputs"
dir.create(file.path(output_dir, "tables"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. SUMMARY TABLE: OOSR and Foundational Learning by group and wealth quintile
# =============================================================================

#
# 1.1 OOSR Summary Table
#

# Weighted OOSR for a filtered subset
calc_oosr <- function(data) {
  if (nrow(data) == 0) return(NA_real_)
  weighted.mean(data$out_of_school, data$weight, na.rm = TRUE) * 100
}

# Build one row of the summary table
oosr_row <- function(data, label) {
  tibble(
    group     = label,
    oosr_pct  = calc_oosr(data),
    oosr_q1   = calc_oosr(filter(data, wealth_quintile == "Poorest")),
    oosr_q5   = calc_oosr(filter(data, wealth_quintile == "Richest")),
    n         = nrow(data)
  )
}

summary_table <- bind_rows(
  oosr_row(filter(oosr_data, area == "Rural", sex == "Male"),   "Rural Boys"),
  oosr_row(filter(oosr_data, area == "Rural", sex == "Female"), "Rural Girls"),
  oosr_row(filter(oosr_data, area == "Urban", sex == "Male"),   "Urban Boys"),
  oosr_row(filter(oosr_data, area == "Urban", sex == "Female"), "Urban Girls"),
  oosr_row(filter(oosr_data, disabled == 1),                    "Disabled"),
  oosr_row(filter(oosr_data, orphan == 1),                      "Orphaned"),
  oosr_row(filter(oosr_data, hh_head_completed_primary == 1),   "HH Head Completed School")
) %>%
  mutate(across(where(is.numeric) & !c(n), ~ round(., 1)))

cat("\n=== Out-of-School Rate (%) by Group ===\n\n")
print(as.data.frame(summary_table), row.names = FALSE)

write_csv(summary_table, file.path(output_dir, "tables/summary_table_oosr.csv"))


#
# 1.2 Foundational Reading Summary Table
#

# Weighted Foundational Reading rate for a filtered subset
calc_reading <- function(data) {
  if (nrow(data) == 0) return(NA_real_)
  weighted.mean(data$can_read, data$weight, na.rm = TRUE) * 100
}

# Build one row of the summary table
reading_row <- function(data, label) {
  tibble(
    group       = label,
    reading_pct = calc_reading(data),
    reading_q1  = calc_reading(filter(data, wealth_quintile == "Poorest")),
    reading_q5  = calc_reading(filter(data, wealth_quintile == "Richest")),
    n           = nrow(data)
  )
}

reading_summary_table <- bind_rows(
  reading_row(reading_data,                                        "Overall"),
  reading_row(filter(reading_data, area == "Rural", sex == "Male"),   "Rural Boys"),
  reading_row(filter(reading_data, area == "Rural", sex == "Female"), "Rural Girls"),
  reading_row(filter(reading_data, area == "Urban", sex == "Male"),   "Urban Boys"),
  reading_row(filter(reading_data, area == "Urban", sex == "Female"), "Urban Girls"),
  reading_row(filter(reading_data, disabled == 1),                    "Disabled"),
  reading_row(filter(reading_data, disabled == 1, sex == "Male"),     "Disabled Boys"),
  reading_row(filter(reading_data, disabled == 1, sex == "Female"),   "Disabled Girls")
) %>%
  mutate(across(where(is.numeric) & !c(n), ~ round(., 1)))

cat("\n=== Foundational Reading (%) by Group ===\n\n")
print(as.data.frame(reading_summary_table), row.names = FALSE)
write_csv(reading_summary_table, file.path(output_dir, "tables/summary_table_foundational_reading.csv"))

# =============================================================================
# 2. Summary Dataframes
# =============================================================================

# OOSR by sex, area, wealth quintile
oosr_by_group <- oosr_data %>%
  group_by(sex, area, wealth_quintile) %>%
  summarise(
    oosr_pct = weighted.mean(out_of_school, weight, na.rm = TRUE) * 100,
    n = n(),
    .groups = "drop"
  )

# Foundational reading by sex, area, wealth quintile (ages 7-14)
reading_by_group <- reading_data %>%
  filter(age >= 7, age <= 14) %>%
  group_by(sex, area, wealth_quintile) %>%
  summarise(
    pct_can_read = weighted.mean(can_read, weight, na.rm = TRUE) * 100,
    n = n(),
    .groups = "drop"
  )

# Combined dataframe
education_df <- oosr_by_group %>%
  full_join(reading_by_group,
            by = c("sex", "area", "wealth_quintile"),
            suffix = c("_oosr", "_reading"))

write_csv(education_df, file.path(output_dir, "tables/education_indicators.csv"))

# =============================================================================
# 3. DISTRICT-LEVEL AGGREGATES
# =============================================================================

district_oosr <- oosr_data %>%
  group_by(district_code, district_name) %>%
  summarise(
    oosr_pct = weighted.mean(out_of_school, weight, na.rm = TRUE) * 100,
    n_oosr = n(),
    .groups = "drop"
  )

district_reading <- reading_data %>%
  filter(age >= 7, age <= 14) %>%
  group_by(district_code, district_name) %>%
  summarise(
    pct_can_read = weighted.mean(can_read, weight, na.rm = TRUE) * 100,
    n_reading = n(),
    .groups = "drop"
  )

district_stats <- district_oosr %>%
  inner_join(district_reading, by = c("district_code", "district_name")) %>%
  mutate(pct_cannot_read = 100 - pct_can_read)

write_csv(district_stats, file.path(output_dir, "tables/district_stats.csv"))


# =============================================================================
# 4. REGRESSIONS
# =============================================================================


#
# 4.1 OOSR Regression
#

oosr_data_clean <- oosr_data %>%
  mutate(
    # Outcome as factor (0 = not out of school, 1 = out of school)
    out_of_school = factor(out_of_school, levels = c(0, 1)),

    # Categorical predictors
    sex   = factor(sex),
    area  = factor(area),

    wealth_quintile = factor(
      wealth_quintile,
      levels = c("Poorest", "Second", "Middle", "Fourth", "Richest")
    ),

    orphan  = factor(orphan, levels = c(0, 1)),
    disabled = factor(disabled, levels = c(0, 1)),
    hh_head_completed_primary = factor(hh_head_completed_primary,
                                       levels = c(0, 1))
  )

#Setting Reference Values
oosr_data_clean <- oosr_data_clean %>%
  mutate(
    sex = relevel(sex, ref = "Male"),
    area = relevel(area, ref = "Urban"),
    wealth_quintile = relevel(wealth_quintile, ref = "Poorest"),
    orphan = relevel(orphan, ref = "0"),
    disabled = relevel(disabled, ref = "0"),
    hh_head_completed_primary = relevel(hh_head_completed_primary, ref = "0")
  )

#Running Logistic Regression
oos_model <- glm(
  out_of_school ~ age +
    sex +
    area +
    wealth_quintile +
    orphan +
    disabled +
    hh_head_completed_primary,
  data = oosr_data_clean,
  family = binomial(link = "logit")
)

write_csv(
  tidy(oos_model, exponentiate = TRUE, conf.int = TRUE) %>%
    filter(term != "(Intercept)") %>%
    mutate(
      OR = round(estimate, 2),
      CI = paste0(round(conf.low, 2), " – ", round(conf.high, 2)),
      p.value = round(p.value, 3)
    ) %>%
    select(term, OR, CI, p.value),
  file.path(output_dir, "tables/oosr_regression.csv")
)

 #
 # 4.2 Foundational Reading Regression
 #


 reading_data_clean <- reading_data %>%
   mutate(
     # Outcome as factor (0 = can't read, 1 = can read)
     out_of_school = factor(can_read, levels = c(0, 1)),

     # Categorical predictors
     sex   = factor(sex),
     area  = factor(area),

     wealth_quintile = factor(
       wealth_quintile,
       levels = c("Poorest", "Second", "Middle", "Fourth", "Richest")
     ),

     disabled = factor(disabled, levels = c(0, 1))
   )

 #Setting Reference Values
 reading_data_clean  <-  reading_data_clean %>%
   mutate(
     sex = relevel(sex, ref = "Male"),
     area = relevel(area, ref = "Urban"),
     wealth_quintile = relevel(wealth_quintile, ref = "Poorest"),
     disabled = relevel(disabled, ref = "0")
   )

 #Running Regression
 reading_model <- glm(
   can_read ~ age +
     sex +
     area +
     wealth_quintile +
     disabled
    ,
   data = reading_data_clean,
   family = binomial(link = "logit")
 )

 write_csv(
   tidy(reading_model, exponentiate = TRUE, conf.int = TRUE) %>%
   filter(term != "(Intercept)") %>%
   mutate(
     OR = round(estimate, 2),
     CI = paste0(round(conf.low, 2), " – ", round(conf.high, 2)),
     p.value = round(p.value, 3)
   ) %>%
   select(term, OR, CI, p.value),
   file.path(output_dir, "tables/reading_regression.csv")
   )

message("\nAnalysis complete - tables saved to 'outputs/tables/'")
