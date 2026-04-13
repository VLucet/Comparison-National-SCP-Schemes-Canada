library(targets)
library(terra)
library(dplyr)
library(tidyr)
library(ggplot2)

# Consensus
# NOT 0s, should be NAs

tar_load(karimi_scenarios_locked_scaled)
tar_load(eckert_scenarios_scaled_rj)
tar_load(currie_rast_all_sols_scaled)

karimi_scenarios_locked_scaled[is.na(karimi_scenarios_locked_scaled) & (!is.na(eckert_scenarios_scaled_rj) | !is.na(currie_rast_all_sols_scaled))] <- 0
eckert_scenarios_scaled_rj[is.na(eckert_scenarios_scaled_rj) & !is.na(karimi_scenarios_locked_scaled)] <- 0
currie_rast_all_sols_scaled[is.na(currie_rast_all_sols_scaled) & !is.na(karimi_scenarios_locked_scaled)] <- 0

k_nas <- values(is.na(karimi_scenarios_locked_scaled)) |> sum(na.rm=T)
e_nas <- values(is.na(eckert_scenarios_scaled_rj)) |> sum(na.rm=T) 
c_nas <- values(is.na(currie_rast_all_sols_scaled)) |> sum(na.rm=T) 

stopifnot((k_nas == e_nas) == (e_nas == c_nas))

consensus <- sum(c(karimi_scenarios_locked_scaled, eckert_scenarios_scaled_rj, currie_rast_all_sols_scaled), na.rm=T)
plot(consensus)


# Correlations

tar_load(all_scenarios_values_clean)

xy_mat <- scale(all_scenarios_values_clean[,1:2]) |> as.matrix()
values_mat <- all_scenarios_values_clean[,3:ncol(all_scenarios_values_clean)] |> as.matrix()

# A <- xy_mat[10000:10010, ]
# B <- values_mat[10000:10010, ]
# t(A) %*% B # ??
# t(B) %*% A[,1] + t(B) %*% A[,2]

# heatmap(cor(values_mat), symm = T)

all_scenarios_values_clean

values_mat_norm <- sweep(values_mat, 2, colSums(values_mat), "/")
centroids <- t(xy_mat) %*% values_mat_norm 

tar_load(scenarios_centroids_clean)

library(ggrepel)

scenarios_centroids_clean |>
  ggplot(aes(x, y)) +
   theme_bw() +
   geom_point(position = position_jitter(width = 0.1, seed = 123)) +
  geom_text_repel(
    aes(label = name, color = study),
    fontface = "bold",
    position = position_jitter(width = 0.1, seed = 123),
    box.padding = unit(0.5, "lines"),
    segment.color = 'grey') +
  # scale_color_discrete() +
   coord_fixed() +
  labs(x="Centroid Longitude (Scaled & Centered)", y="Centroid Latitude (Scaled & Centered)", 
color = "Scenario \nOrigin")

plot(1:23, scale(log(1:23), center = F), type = "l")
points(1:10, scale(log(1:10), center = F), type = "l")

# my_scale <- function(k, n) {
#   log(k + 1) / log(n + 1)
# }

my_scale <- function(p, b) {
 (log(1+p*b) / log(1+b))
}

# my_scale <- function(p, b) {
#  asin(sqrt(p))/(pi/2)
# }

plot(1:23, my_scale(1:23, 23), type = "l")
points(1:10, my_scale(1:10, 10), type = "l", col=2)
