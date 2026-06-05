# Pharmacy Access NYC: Chain vs. Independent Pharmacy Distribution, 2019–2024

## Project Overview

This project analyzes changes in pharmaceutical access across New York City between 2019 and 2024, with a focus on whether pharmacy closures fell disproportionately on chain pharmacies or independent/community pharmacies — and how those closures mapped onto neighborhood poverty and racial composition.

The analysis was conducted during a Pipeline to Preparedness Fellowship at the NYC Department of Health and Mental Hygiene (DOHMH), Bureau of Mental Health. Findings were accepted for oral presentation at the Council of State and Territorial Epidemiologists (CSTE) Annual Conference, 2026, following CDC review and approval.

## Data Sources

- NYC DOHMH administrative pharmacy permit records (2019 baseline)
- NYC OpenData pharmacy dataset (2024 snapshot)
- Both datasets filtered to active NYS pharmacy permits (PH_TYPE = 17) within NYC

## Methods

### Closure Identification (SQL)
Pharmacies present in the 2019 dataset but absent from 2024 were classified as closed using a dual-key LEFT JOIN on registration number and geocoded coordinates (rounded to 4 decimal places, ~11m precision). Using both keys guards against false positives from pharmacies that relocated or were re-licensed under a new permit number.

Pharmacy types were reclassified from the raw `CD_CAT_DESC` field into three groups:
- **Chain** — large chain and small chain pharmacies (CVS, Walgreens, Duane Reade, Rite Aid, etc.)
- **Independent** — community pharmacies
- **Other** — hospital affiliates, HMOs, infusion pharmacies, correctional facilities (excluded from closure analysis)

### Spatial Analysis (R + ArcGIS)
Downstream spatial analysis was conducted in R and ArcGIS Online, including:
- Average Nearest Neighbor (ANN) for clustering assessment
- Moran's I for global spatial autocorrelation
- Lee's L bivariate autocorrelation (pharmacy type × neighborhood poverty/race)
- Spatial lag regression to account for neighborhood spillover effects
- Kernel density estimation and interactive dashboard mapping in ArcGIS Online

## Repository Contents

| File | Description |

|------|-------------|
| `pharmacy_closures_2019_2024.sql` | SQL pipeline: data cleaning, dual-key closure identification, aggregation by pharmacy type and borough, community district export for spatial analysis |
| `pharmacy_spatial_analysis.Rmd` | R Markdown: bivariate spatial correlation analysis (Lee's L) testing the relationship between neighborhood poverty rates and chain vs. independent pharmacy presence across NYC |

## Tools

SQL · R · ArcGIS Online · ArcGIS Dashboards · QGIS · NYC OpenData
