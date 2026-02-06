# Exclusion from Education in Malawi

Exploratory analysis of learning poverty and out-of-school children in Malawi using MICS 6 and IHS 5 survey data.

## Overview

This analysis examines two dimensions of educational exclusion in Malawi:

1. **Out-of-school children** — Which children are not attending school, and what factors predict non-attendance?
2. **Foundational learning** — Among children in school, who is failing to acquire basic reading skills?

## Data Sources

| Dataset | Description | Source |
|---------|-------------|--------|
| MICS 6 | Multiple Indicator Cluster Survey (2019-20) — child development, education, foundational learning assessments | [UNICEF MICS](https://mics.unicef.org/surveys) |
| IHS 5 | Integrated Household Survey (2019-20) — household socioeconomic data, education module | [World Bank Microdata](https://microdata.worldbank.org/index.php/catalog/3818) |

**Note:** Raw data files are included as zipped archives in `data/raw/`. Users must unzip these before running the analysis.


## Repository Structure

```
├── data/
│   ├── raw/                  # Original survey data (zipped)
│   │   ├── IHS_5.zip
│   │   ├── MICS_6.zip
│   │   └── MICS_6_GPS.zip
│   ├── processed/            # Cleaned analysis-ready datasets
│   │   ├── mics_children.csv
│   │   ├── mics_individuals.csv
│   │   ├── mics_skills_geo.csv
│   │   ├── ihs_education.csv
│   │   ├── ihs_households.csv
│   │   ├── oosr_data.csv
│   │   ├── reading_data.csv
│   │   ├── mics_clusters.geojson
│   │   ├── district_boundaries.geojson
│   │   └── survey_boundaries.geojson
│   └── downloads/            # Temporary download folder (not tracked)
│
├── scripts/
│   ├── 01_data_preparation.R # Load raw data, clean, merge, export
│   ├── 02_analysis.R         # Descriptive stats and regression models
│   └── 03_outputs.R          # Generate figures, maps, and tables
│
├── outputs/
│   ├── figures/              # Charts and visualizations
│   │   ├── foundational_area_chart.png
│   │   └── foundational_sex_chart.png
│   ├── maps/                 # Geographic visualizations
│   │   ├── cannot_read.png
│   │   ├── combined_district_maps.png
│   │   └── oosr.png
│   └── tables/               # Summary statistics and model results
│       ├── district_stats.csv
│       ├── education_indicators.csv
│       ├── oosr_regression.csv
│       ├── reading_regression.csv
│       ├── summary_table_foundational_reading.csv
│       └── summary_table_oosr.csv
│
└── Exclusion from Education in Malawi.docx  # Final report
```
## Requirements

### Software
- R (version 4.0 or higher)
- RStudio (recommended)
- Required packages are installed in 01_data_preparation.R


## How to Reproduce the Analysis

### Step 1: Clone the repository

```bash
git clone https://github.com/lulu9661/Malawi_Education_Analysis.git
cd Malawi_Education_Analysis
```

### Step 2: Unzip raw data

```bash
cd data/raw
unzip IHS_5.zip
unzip MICS_6.zip
unzip MICS_6_GPS.zip
cd ../..
```

Or unzip manually using your file explorer.

### Step 3: Run the scripts in order

Open RStudio and run each script sequentially:

```r
source("scripts/01_data_preparation.R")  # ~5 min
source("scripts/02_analysis.R")          # ~2 min
source("scripts/03_outputs.R")           # ~1 min
```

Alternatively, open each script and run interactively to inspect intermediate outputs.

### Step 4: View outputs

Results are saved to the `outputs/` folder:
- `outputs/tables/` — CSV files with summary statistics and regression results
- `outputs/figures/` — PNG charts
- `outputs/maps/` — Geographic visualizations by district

## Key Outputs

| File | Description |
|------|-------------|
| `summary_table_oosr.csv` | Out-of-school rates by age, sex, region, wealth |
| `summary_table_foundational_reading.csv` | Foundational reading proficiency by demographics |
| `oosr_regression.csv` | Regression model (odds ratios): predictors of being out of school |
| `reading_regression.csv` | Regression model (odds ratios): predictors of reading proficiency |
| `district_stats.csv` | District-level education indicators |
| `combined_district_maps.png` | Map of OOSR and reading outcomes by district |


## License

Code: MIT License

