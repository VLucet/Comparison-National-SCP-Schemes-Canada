# Comparison of National Systematic Conservation Prioritizations Schemes in Canada: Implications for Federal Policy and the Implementation of the 30x30 Conservation Targets 

[![R](https://img.shields.io/badge/R-%3E%3D4.6-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![targets](https://img.shields.io/badge/pipeline-targets-blue)](https://books.ropensci.org/targets/)
[![renv](https://img.shields.io/badge/dependencies-renv-informational)](https://rstudio.github.io/renv/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22084293.svg)](https://doi.org/10.5281/zenodo.22084293)

#### Authors:

Sarah Green (1), Valentin Lucet (1), Olivia Demetrakopoulos (2), Mélanie Brochu (1), Tea Falzata (1), Marion Morissette (1), Taryn Muldoon (1), Sahebeh Karimi (3), Federico Riva (1), Richard Schuster (1) (3), Joseph R. Bennett (1)

#### Affiliations

(1) Department of Biology, Carleton University, Ottawa, ON, Canada
(2) Department of Biology, University of Ottawa, Ottawa, ON, Canada
(3) Nature Conservancy of Canada, Toronto, ON, Canada

### Summary

Canada has committed to protecting 30% of its lands and waters by 2030 but remains less than halfway to that target. This repository supports an analysis that reviews federal protected-area policy to identify gaps, then compares four existing national-scale systematic conservation prioritization (SCP) schemes for Canada to assess how their approaches, assumptions, and spatial recommendations align — or fail to align — with one another and with Canada's 30×30 commitments.licy.

---

## Table of Contents

- [Abstract](#abstract)
- [Repository Structure](#repository-structure)
- [Data sources](#data)
- [Requirements](#requirements)
- [Installation](#installation)
- [Reproducibility](#Reproducibility)
- [License](#license)

---

## Abstract

Canada is less than halfway towards its commitment of allocating 30% of its land and waters to biodiversity conservation, with only four years left to meet this goal. In theory, systematic prioritization can help to achieve conservation targets more efficiently. Multiple prioritization schemes have been devised for Canada, relying on different assumptions, scenarios, constraints, and approaches, and leading to differing results. Here we review  the existing federal protected area establishment policy, with the goal of highlighting existing policy gaps, using this as a background to evaluate Canada’s progress toward its 30×30 goals. We then compare the approaches taken by different studies, contrast their results and summarize their recommendations. We find that consensus among schemes is limited and is unlikely to align with Canada’s governance system, particularly the limited control of the federal government over Canada’s lands. Ultimately, while systematic prioritizations are not prescriptions, they are useful for starting points to define areas of interest. They can also illuminate the limitations of policy, and thus help to guide refinement towards clearer implementation goals.

---

## Repository Structure

```
.
├── data             -> All data (archived and decompressed)
│   ├── analyses     -> Results of each SCP analysis (decompressed)
│   │   ├── currie   -> Data for Currie et al. 2023
│   │   ├── eckert   -> Data for Eckert et al. 2023
│   │   └── karimi   -> Data for Karimi et al. 2025
│   ├── archives     -> Archives of each SCP analysis results
│   │   ├── currie   -> Data for Currie et al. 2023
│   │   ├── eckert   -> Data for Eckert et al. 2023
│   │   └── karimi   -> Data for Karimi et al. 2025
│   └── canada       -> Canada cnesus boundary files
├── plots            -> All plots and figures
├── _targets         -> Targets R package folder (do not modify)
└── renv             -> Renv R package folder (do not modify)
```

---

## Data sources

1. Currie et al. 2023: the data from the [paper](https://conbio.onlinelibrary.wiley.com/doi/10.1111/csp2.12924) must be downloaded manually from [figshare](https://figshare.com/articles/dataset/Data/28255109).

2. Eckert et al. 2023: the data from the [paper](https://www.nature.com/articles/s41467-023-42737-x) must be downloaded manually from [figshare](https://figshare.com/s/0551e56687ba119c7bb8).

3. Karimi et al. 2025: the data from the [paper](https://www.facetsjournal.com/doi/10.1139/facets-2024-0295) can be requested from the authors.

4. Canada boundary files:the pipeline automatically downloads the [2021 Provinces and Territories boundary file](https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/boundary-limites/files-fichiers/lpr_000b21a_e.zip).

5. Protected areas database: we used the Canadian Protected and Conserved Areas Database (CPCAD) 2025, which can be downloaded from [OpenCanada](https://open.canada.ca/data/en/dataset/6c343726-1e92-451a-876a-76e17d398a1c). 

## Requirements

- **R** ≥ `4.6.0`
- **[renv](https://rstudio.github.io/renv/)** for package version management
- **[targets](https://books.ropensci.org/targets/)** for pipeline orchestration
- Standard build tools if any packages compile from source (e.g., a C/C++ toolchain, GDAL/GEOS/PROJ for spatial packages such as `sf`/`terra`, depending on your OS)

All R package dependencies and their exact versions are recorded in `renv.lock` and will be installed automatically via `renv::restore()` (see below).

---

## Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/VLucet/Comparison-National-SCP-Schemes-Canada
   cd Comparison-National-SCP-Schemes-Canada
   ```

2. **Restore the R environment**

   Open the project in R (e.g., via the `.Rproj` file or by launching R in the repo root). `renv` will bootstrap itself automatically on startup; then run:

   ```r
   renv::restore()
   ```

   This installs the exact package versions recorded in `renv.lock` into a project-local library.

3. **Verify the pipeline is discoverable**

   ```r
   targets::tar_manifest()
   ```

   This should list all targets defined in `_targets.R` without executing them.

4. **Download the necessary data**

    See the [Data](#data) section above.

---

## Reproducibility

The full analysis is orchestrated with the [`targets`](https://books.ropensci.org/targets/) package, which tracks dependencies between data, functions, and outputs and only re-runs what has changed. Outputs (cleaned data, model objects, figures, tables) are cached in `_targets/` and reconstructed on demand — they do not need to be committed to version control.

- All package versions are pinned via `renv.lock`; use `renv::restore()` rather than manually installing packages.
- The `targets` pipeline is fully declarative — re-running `tar_make()` after any code or data change will only recompute affected targets, ensuring outputs stay in sync with inputs.
- Session information can be captured at any time with `sessionInfo()` or `renv::diagnostics()`.

**Run the entire pipeline:**

```r
tar_make()
```

**Load a specific completed target into your R session (e.g., for interactive exploration):**

```r
tar_load(name_of_target)
```

**Check pipeline status / what is out of date:**

```r
tar_outdated()
```

---
 
## License
 
This project's **code** is licensed under the [MIT License](LICENSE) unless otherwise noted.

---