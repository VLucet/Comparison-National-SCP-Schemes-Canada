# Returns the full list of scenario names in fixed display order,
# grouped by study (Karimi: 6, Eckert: 15, Currie: 6)
get_scenarios_in_order <- function() {
  c(
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
}

# Builds a lookup table mapping each scenario (from scenarios_centroids)
# to its source study and display name
get_scenario_LUT <- function(scenarios_centroids) {
  data.frame(
      scenario = scenarios_centroids$scenario,
      study = c(rep("Karimi et al.", 6), rep("Eckert et al.", 15), rep("Currie et al.", 6)),
      name = get_scenarios_in_order()
    )
}

# Mean of x, treating NA values as 0 instead of dropping them
my_mean <- function(x) {
  x[is.na(x)] <- 0
  mean(x)
}

# Reshapes historical region data from wide to long format, cleans up
# metric/region labels, orders regions (provinces alphabetically, then
# Terrestrial/Marine last), and flags rows as "Totals" vs "Province/Territory"
process_hist_data <- function(t_hist) {
  # Code contributed by M. Brochu
  # 3. Reshape from wide to long
  t_hist_long <- t_hist %>%
    tidyr::pivot_longer(
      cols      = -Region,
      names_to  = "Metric",
      values_to = "Value"
    )

  # 4. Recode metric labels
  t_hist_long$Metric <- dplyr::recode(
    t_hist_long$Metric,
    "X2020.2024.Increase" = "2020-2024 Increase",   
    "X2020.Baseline"      = "2020 Baseline"
  )

  # 5. Rename & reorder regions
  t_hist_long$Region <- dplyr::recode(
    t_hist_long$Region,
    "Terrestrial total" = "Terrestrial",
    "Marine total"      = "Marine"
  )

  t_hist_long$Region <- factor(
    t_hist_long$Region,
    levels = c(
      sort(setdiff(unique(t_hist_long$Region), c("Terrestrial", "Marine"))),
      "Terrestrial",
      "Marine"
    )
  )

  # 6. Create grouping variable for totals panel
  t_hist_long$Group <- ifelse(
    t_hist_long$Region %in% c("Terrestrial", "Marine"),
    "Totals",
    "Province/Territory"
  )

  return(t_hist_long)

}

# [Disabled] Computes centroids: standardizes xy coords, column-normalizes
# values, then projects standardized coords through normalized value weights
# compute_centroids <- function(xy_mat, values_mat) {
#   xy_mat_scaled <- scale(xy_mat) |> as.matrix()
#   values_mat_norm <- sweep(values_mat, 2, colSums(values_mat), "/") |> as.matrix()
#   centroids <- t(xy_mat_scaled) %*% values_mat_norm 
# }