
<!-- 
#### Code contributors

Valentin Lucet
Melanie Brochu -->


# Comparison of National Systematic Conservation Prioritizations Schemes in Canada: Implications for Federal Policy and the Implementation of the 30x30 Conservation Targets 

[![R](https://img.shields.io/badge/R-%3E%3D4.6-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![targets](https://img.shields.io/badge/pipeline-targets-blue)](https://books.ropensci.org/targets/)
[![renv](https://img.shields.io/badge/dependencies-renv-informational)](https://rstudio.github.io/renv/)

## Abstract

Canada is less than halfway towards its commitment of allocating 30% of its land and waters to biodiversity conservation, with only four years left to meet this goal. In theory, systematic prioritization can help to achieve conservation targets more efficiently. Multiple prioritization schemes have been devised for Canada, relying on different assumptions, scenarios, constraints, and approaches, and leading to differing results. Here we review  the existing federal protected area establishment policy, with the goal of highlighting existing policy gaps, using this as a background to evaluate Canada’s progress toward its 30×30 goals. We then compare the approaches taken by different studies, contrast their results and summarize their recommendations. We find that consensus among schemes is limited and is unlikely to align with Canada’s governance system, particularly the limited control of the federal government over Canada’s lands. Ultimately, while systematic prioritizations are not prescriptions, they are useful for starting points to define areas of interest. They can also illuminate the limitations of policy, and thus help to guide refinement towards clearer implementation goals.

---

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
    - [Data](#data)
    - [Plots](##plots)
    - [Outputs](##outputs)
    - [Quarto](##quarto)
- [Requirements](#requirements)
- [Installation](#installation)
- [Reproducing the Analysis](#reproducing-the-analysis)
- [Pipeline Overview](#pipeline-overview)
- [Reproducibility Notes](#reproducibility-notes)
- [License](#license)

---

## Overview

**Summary.**

**Motivation.** 

**Research questions.**

---

## Repository Structure

```
.├── data
│   ├── analyses
│   │   ├── currie
│   │   ├── eckert
│   │   └── karimi
│   ├── archives
│   │   ├── currie
│   │   ├── eckert
│   │   └── karimi
│   ├── canada
│   └── protected_areas
│       ├── archive
│       └── ProtectedConservedArea_2025
├── plots
└── _targets
```

---

### Data



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
    
    See the data description section above.

---

## Reproducing the Analysis

The full analysis is orchestrated with the [`targets`](https://books.ropensci.org/targets/) package, which tracks dependencies between data, functions, and outputs and only re-runs what has changed. 

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

Outputs (cleaned data, model objects, figures, tables) are cached in `_targets/` and reconstructed on demand — they do not need to be committed to version control.

---

## Reproducibility Notes

- All package versions are pinned via `renv.lock`; use `renv::restore()` rather than manually installing packages.
- The `targets` pipeline is fully declarative — re-running `tar_make()` after any code or data change will only recompute affected targets, ensuring outputs stay in sync with inputs.
- Random seeds (where applicable, e.g., for bootstrapping or model fitting) are set within the relevant functions or scripts to ensure deterministic results.
- Session information can be captured at any time with `sessionInfo()` or `renv::diagnostics()`.

---
 
## License
 
This project's **code** is licensed under the [MIT License](LICENSE) unless otherwise noted.

---
