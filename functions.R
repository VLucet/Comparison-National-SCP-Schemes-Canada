get_scenario_LUT <- function(scenarios_centroids) {
  data.frame(
      scenario = scenarios_centroids$scenario,
      study = c(rep("Karimi et al.", 6), rep("Eckert et al.", 15), rep("Currie et al.", 6)),
      name = c(
        # 6 Karimi
        "SameCost LogLinear",
        "SameCost 30%",
        "HFCost LogLinear",
        "HFCost 30%",
        "Sum",
        "Scaled",

        # 15 Eckert
        "IUCN",
        "FD",
        "Amphibians/Reptiles",
        "Main",
        "Plants",
        "COSEWIC",
        "Birds",
        "Global",
        "Butterflies",
        "PD",
        "Ecozone",
        "Mammals",
        "Provinces",
        "Sum",
        "Scaled",

        # 6 Currie 
        "20%",
        "30%",
        "40%",
        "50%",
        "Sum",
        "Scaled"
      )
    )
}

# compute_centroids <- function(xy_mat, values_mat) {
#   xy_mat_scaled <- scale(xy_mat) |> as.matrix()
#   values_mat_norm <- sweep(values_mat, 2, colSums(values_mat), "/") |> as.matrix()
#   centroids <- t(xy_mat_scaled) %*% values_mat_norm 
# }