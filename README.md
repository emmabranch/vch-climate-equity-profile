# Climate resilience and equity profile of VCH communities

**Which communities in the Vancouver Coastal Health (VCH) region are most socially vulnerable to extreme heat and wildfire smoke, and do they also have less green cover?**

- **Project site and interactive map:** https://emmabranch.github.io/vch-climate-equity-profile/
- **Two-page briefing note** (for Medical Health Officers and local government planners), with recommendations informed by VCH's CLEAR lived-experience report: [web](https://emmabranch.github.io/vch-climate-equity-profile/briefing.html) | [PDF](https://emmabranch.github.io/vch-climate-equity-profile/briefing.pdf)

> **Disclaimer:** This is an independent portfolio project by Emma Branch, built with open data. It is not affiliated with, commissioned by, or endorsed by Vancouver Coastal Health. Findings are illustrative and should not be used for operational decisions without further validation.

## Key findings

- **Vulnerability is concentrated.** Across 1,773 dissemination areas (DAs) in 45 Community Health Service Areas (CHSAs), the highest average vulnerability was in the Downtown Eastside, Richmond City Centre, and the West End.
- **More vulnerable neighbourhoods have less green cover.** In the urban area, vegetation covers about 25% of land in the most vulnerable fifth of neighbourhoods, compared with 35% in the least vulnerable fifth (population-weighted; Spearman's rho = -0.36, n = 1,599 urban DAs).
- **166 DAs, home to about 138,000 people, face both risks:** they are in the most vulnerable fifth of the region *and* the lowest third for vegetation cover.
- **Vulnerability has different drivers in different places**, for example older adults living alone in some communities, and low income, renting, or language barriers in others.
- **The index is consistent with national measures:** it agrees closely with Statistics Canada's Canadian Index of Social Vulnerability (rho = 0.74).

## Methods

### Geography

- **Unit of analysis:** 2021 Census dissemination areas (DAs), the smallest areas with full census data (usually 400 to 700 people).
- **Health geography:** BC Ministry of Health Community Health Service Areas (CHSAs, 2022 configuration), filtered to the Vancouver Coastal Health authority.
- **DA to CHSA assignment:** each DA is assigned to the CHSA that contains its point-on-surface (a point guaranteed to fall inside the DA).

### Social vulnerability index

Five 2021 Census indicators, chosen because each is linked to greater harm from extreme heat or wildfire smoke. The BC Coroners Service review of the 2021 heat dome identified older adults and people living alone among the groups most at risk, and VCH's CLEAR engagement found that renters, people on low incomes, and people facing language barriers had difficulty staying cool and getting usable health information.

| Indicator | Weight | Rationale |
|---|---|---|
| Population aged 65 and over (%) | 0.2 | Greater physiological sensitivity to heat and smoke |
| One-person households (%) | 0.2 | Social isolation; fewer people to notice illness during an event |
| Low income, LIM-AT (%) | 0.2 | Less ability to afford cooling, air filtration, or relocation |
| Renter households (%) | 0.2 | Less control over cooling, ventilation, and building upgrades |
| No knowledge of English or French (%) | 0.2 | Barriers to receiving alerts and health messaging |

**Construction:**

1. Each indicator is percentile-ranked across VCH DAs (0 = lowest, 1 = highest).
2. The index score is the weighted mean of the available ranks (0 to 1). Weights are equal, as a transparent default.
3. DAs need a population above zero and at least 4 of 5 indicators. This keeps DAs where one value is suppressed (for example, low income is not published for First Nations reserves) instead of excluding them.
4. DAs are grouped into quintiles within the VCH region (5 = most vulnerable fifth).
5. CHSA results are population-weighted means of their DAs.

### Validation

The index was compared with two established Statistics Canada indices using Spearman rank correlations (see [`data/processed/index_validation.csv`](data/processed/index_validation.csv)):

| Comparison | Spearman's rho |
|---|---|
| Canadian Index of Social Vulnerability (CISV) score | 0.74 |
| CIMD residential instability | 0.53 |
| CIMD situational vulnerability | 0.30 |
| CIMD economic dependency | 0.25 |

Strong agreement with the CISV, which is designed for natural hazards, supports the index. Weaker agreement with the CIMD dimensions is expected, because the CIMD measures deprivation rather than hazard vulnerability.

### Green cover and priority areas

- **Vegetation cover:** Statistics Canada's fraction of vegetation cover (trees, shrubs, and grass, from Sentinel-2 imagery), averaged over 2019 to 2024. It is published only for DAs in large urban areas.
- **Priority areas:** DAs in the most vulnerable quintile *and* the lowest third of vegetation cover among VCH DAs with data.

## Data sources, citations, and licences

| Data | Citation | Licence |
|---|---|---|
| 2021 Census Profile, DA level (BC comprehensive file, 98-401-X2021006) | Statistics Canada. 2022. *Census Profile. 2021 Census.* Catalogue no. 98-316-X2021001. Ottawa. | [Statistics Canada Open Licence](https://www.statcan.gc.ca/en/reference/licence) |
| 2021 dissemination area cartographic boundary file | Statistics Canada. 2022. *2021 Census Boundary Files.* Catalogue no. 92-160-X. | Statistics Canada Open Licence |
| Canadian Index of Social Vulnerability, 2021 | Statistics Canada. 2025. *The Canadian Index of Social Resilience and the Canadian Index of Social Vulnerability, 2021.* Catalogue no. 45-20-00012025002. | Statistics Canada Open Licence |
| Canadian Index of Multiple Deprivation, 2021 (BC) | Statistics Canada. 2023. *The Canadian Index of Multiple Deprivation: Dataset, 2021.* Catalogue no. 45-20-0001. | Statistics Canada Open Licence |
| Vegetation cover in large urban areas | Statistics Canada. Table 38-10-0187-01, *Vegetation cover in large urban areas.* | Statistics Canada Open Licence |
| Community Health Service Area boundaries (2022) | BC Ministry of Health. *Community Health Service Areas Boundaries.* BC Data Catalogue. | Open Government Licence (British Columbia) |
| Basemap | Esri World Light Gray Canvas (Esri, HERE, Garmin, © OpenStreetMap contributors) | Esri terms of use |

No BC Centre for Disease Control data were used.

### Related evidence

- Vancouver Coastal Health Public Health. (2025). *Climate, Lived Experience and Resilience (the CLEAR project): Listening to communities to enhance the public health response to extreme weather events for priority populations.* Vancouver, BC: Vancouver Coastal Health.
- BC Coroners Service. (2022). *Extreme heat and human mortality: A review of heat-related deaths in B.C. in summer 2021.*

The CLEAR findings informed the indicator rationale and the recommendations in the briefing. This analysis complements CLEAR: CLEAR describes the lived experience of priority populations, while the index shows where people with the same characteristics are concentrated, including rural areas that the CLEAR engagement did not reach.

## Limitations

- **Area-level data:** results describe neighbourhoods, not individuals (ecological fallacy), and may hide variation within areas.
- **Data currency:** census data are from 2021, collected during the COVID-19 pandemic.
- **Missing risk factors:** chronic health conditions and disability, key heat risk factors identified by the BC Coroners Service, are not available in the census at the neighbourhood level.
- **Index design:** equal weights are a transparent default, not evidence-based weights. Quintiles are relative to the VCH region, so they cannot be compared with other regions.
- **Vulnerability, not risk:** the index measures social vulnerability only. It does not include heat or smoke exposure, or health outcomes, and has not been validated against outcomes.
- **Green cover:** the vegetation measure includes grass and shrubs as well as tree canopy, and is not available for rural and remote communities (for example, the Sunshine Coast, Sea-to-Sky, and Central Coast).
- **Missing and suppressed data:** low income is not published for First Nations reserves, and small DAs may have suppressed values. These DAs are scored on the indicators available.
- **Boundary assignment:** DAs are assigned to a single CHSA by location, so DAs crossing CHSA boundaries are assigned to one CHSA only.

## Repository structure

```
vch-climate-equity-profile/
├── R/
│   ├── 01_download_data.R    # Download boundaries, census, CISV, CIMD, vegetation
│   └── 02_build_index.R      # Clean data, build index, validate, summarise by CHSA
├── data/
│   ├── raw/                  # Raw downloads (not committed; recreate with 01)
│   └── processed/            # Analysis outputs used by the map and briefing
├── index.qmd                 # Home page: banner, key figures, interactive map, CHSA table
├── briefing.qmd              # Two-page briefing note (HTML and PDF)
├── _quarto.yml               # Website settings
├── theme.scss                # Site styling (fonts, colours, banner, stat boxes)
├── favicon.svg               # Browser tab icon
├── docs/                     # Rendered website (GitHub Pages)
└── renv.lock                 # R package versions
```

## How to reproduce

1. Clone the repository and open `vch-climate-equity-profile.Rproj` in RStudio.
2. Restore the R packages: `renv::restore()`
3. Download two large Statistics Canada files by hand into `data/raw/`:
   - **Census Profile 2021**, comprehensive download for "Canada, provinces, territories, census divisions (CDs), census subdivisions (CSDs) and dissemination areas (DAs) – British Columbia only" (CSV), saved as `census_profile_bc.zip`
   - **2021 dissemination area cartographic boundary file** (shapefile), saved as `lda_000b21a_e.zip`
4. Run `R/01_download_data.R`, then `R/02_build_index.R`.
5. Build the website and briefing: run `quarto render` in the Terminal (Quarto 1.4 or later).

## Built with

R (sf, dplyr, tidyr, readr, bcdata, cansim, leaflet, htmltools, knitr), Quarto with a custom SCSS theme, Typst (for the PDF briefing), renv, and GitHub Pages.

## Author

**Emma Branch**, epidemiologist and PhD candidate in epidemiology, University of British Columbia.
GitHub: [@emmabranch](https://github.com/emmabranch)
