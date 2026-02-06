# =============================================================================
# 03_outputs.R
# Charts and maps for Malawi education analysis
# =============================================================================

library(tidyverse)
library(sf)

# Run analysis first (or comment out if already run)
# source("scripts/02_analysis.R")

output_dir <- "outputs"
dir.create(file.path(output_dir, "figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(output_dir, "maps"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. PLOTS
# =============================================================================

# Wealth, Sex and Foundational Learning - weighted average across urban/rural
education_gender_summary <- education_df %>%
  group_by(sex, wealth_quintile) %>%
  summarise(
    pct_can_read = weighted.mean(pct_can_read, n_reading, na.rm = TRUE),
    .groups = "drop"
  )

ggplot(education_gender_summary, aes(x = wealth_quintile, y = pct_can_read, fill = sex)) +
  geom_col(position = "dodge") +
  geom_text(
    aes(label = round(pct_can_read, 1)),
    position = position_dodge(width = 0.9),
    vjust = -0.5,
    size = 3
  ) +
  labs(
    title = "Foundational Learning by Sex and Household Wealth Quintile",
    x = "Wealth Quintile",
    y = "% of 6-13 year olds who can read",
    fill = "Sex"
  ) +
  scale_fill_manual(
    values = c("#00AEEF", "#FFC20E"),
    labels = c("Female", "Male")
  ) +
  theme_minimal() +
  theme(
    legend.box.background = element_rect(colour = "grey80"),
    panel.grid.major.x = element_blank()
  )

ggsave(file.path(output_dir, "figures/foundational_sex_chart.png"), width = 6, height = 4, dpi = 300)


# Wealth, Area and Foundational Learning - weighted average across urban/rural
education_area_summary <- education_df %>%
  group_by(area, wealth_quintile) %>%
  summarise(
    pct_can_read = weighted.mean(pct_can_read, n_reading, na.rm = TRUE),
    .groups = "drop"
  )

ggplot(education_area_summary, aes(x = wealth_quintile, y = pct_can_read, fill = area)) +
  geom_col(position = "dodge") +
  geom_text(
    aes(label = round(pct_can_read, 1)),
    position = position_dodge(width = 0.9),
    vjust = -0.5,
    size = 3
  ) +
  labs(
    title = "Foundational Learning by Urban/Rural and Household Wealth Quintile",
    x = "Wealth Quintile",
    y = "% of 6-13 year olds who can read",
    fill = "Area"
  ) +
  scale_fill_manual(
    values = c("#EE3224", "#A5cF4D")
  ) +
  theme_minimal() +
  theme(
    legend.box.background = element_rect(colour = "grey80"),
    panel.grid.major.x = element_blank()
  )

ggsave(file.path(output_dir, "figures/foundational_area_chart.png"), width = 6, height = 4, dpi = 300)

# =============================================================================
# 2. DISTRICT MAPS
# =============================================================================

# Join stats to district boundaries
map_data <- district_boundaries %>%
  mutate(district_code = as.numeric(GEOCODES)) %>%
  left_join(district_stats, by = "district_code")

# --- Map 1: Out-of-school rate ---
ggplot(map_data) +
  geom_sf(aes(fill = oosr_pct), colour = "white", linewidth = 0.3) +
  scale_fill_distiller(
    palette = "YlGn", direction = 1,
    name = "Out of School Rate (%)"
  ) +
  labs(title = "Out-of-School Rate by District (ages 6-13)") +
  theme_void(base_size = 12) +
  theme(legend.position = "right")

ggsave(file.path(output_dir, "maps/oosr.png"), width = 7, height = 9, dpi = 300)

# --- Map 2: % cannot read ---
ggplot(map_data) +
  geom_sf(aes(fill = pct_cannot_read), colour = "white", linewidth = 0.3) +
  scale_fill_distiller(
    palette = "YlGnBu", direction = 1,
    name = "Cannot\nRead (%)"
  ) +
  labs(title = "Percentage of Children Who Cannot Read by District (ages 7-14)") +
  theme_void(base_size = 12) +
  theme(legend.position = "right")

ggsave(file.path(output_dir, "maps/cannot_read.png"), width = 7, height = 9, dpi = 300)

message("\nAll outputs saved to 'outputs/' directory")

