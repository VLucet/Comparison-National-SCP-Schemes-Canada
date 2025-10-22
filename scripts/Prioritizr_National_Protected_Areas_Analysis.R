# WWF-Canada - Beyond Targets Analysis
# Ecological Representation
# Nov 25 2024

Sys.time()

##### Set-up #####
# install packages

# install.packages("raster")
# install.packages("sf")
# install.packages("prioritizr", repos = "https://cran.rstudio.com/")
# install.packages("prioritizrdata")
# install.packages("crayon")
# install.packages("highs", repos = "https://cran.rstudio.com/")
# install.packages("RColorBrewer")
# install.packages("exactextractr")

library(raster)
library(sf)
library(prioritizr)
library(prioritizrdata)
library(crayon)
library(terra)
library(highs)
library(RColorBrewer)
library(exactextractr)

# Define max cells for exact extract
# max_cells <- 3e+10

# set working directory to folder with data
# setwd("Z:/GIS_PRODUCTION/PROJECT/7.WPA/WPA_2023/Data/Inputs")
# getwd()

##### data pre-processing #####
# read in template data
tempr <- terra::rast("analyses/currie/SpeciesAOH_v3/Rangifer_tarandus.tif")

##### PA processing #####
pas <- terra::rast("analyses/currie/Protected_Areas_2022_proj.tif")
pas <- subst(pas, NA, 0)
plot(pas)
pas[pas < 0] <- 0
pas[pas > 0] <- 1

##### management unit processing #####
# not needed
# ecodist <- st_read("Z:/GIS_PRODUCTION/PROJECT/7.WPA/WPA_2023/Results/WPA_2023_2022_EDprop_v2.shp")
# ecodist_code <- terra::rast("./Ecodist_code.tif")
# eco_p <- projectRaster(ecodist_code, crs = crs(pas), res = 250)
# eco_r <- resample(ecodist_code, pas, method = 'near')

##### planning unit processing #####

# ecodist
# ecodist <- ecodist[, c("ECODISTRIC", "ED_AREA_HA", "TOTPA_ED", "TOTPA_PROP", "geometry")]
# ecodist$cost <- 1
# ecodist$lockedin <- ifelse(ecodist$TOTPA_PROP >= 0.3, TRUE, FALSE)
# plot(ecodist[, "lockedin"], main = "Protected area coverage > 30%")
# plot(ecodist[, "ED_AREA_HA"])
# plot(ecodist[, "TOTPA_PROP"])

# 100km2 hexbins (computational limit)
pu <- st_read("analyses/currie/Hexbins_100km_EA_ED.shp")
pu$lockedin <- ifelse(pu$pa_perc >= 0.5, TRUE, FALSE)

# 10km2 hexbins
# pu <- st_read("./Hexbins_10km_EA_ED.shp")
# pu$lockedin <- ifelse(pu$pa_perc >= 0.5, TRUE, FALSE)

# extract landcover for lock-out
# lc2020 <- terra::rast("./CAN_NALCMS_landcover_2020_30m.tif")
# lc2020[(lc2020 == 0) | (lc2020 > 19)] <- NA
# lc2020[(lc2020 >= 1) & (lc2020 <= 16)] <- 0
# lc2020[(lc2020 == 18) | (lc2020 == 19)] <- 0
# lc2020[(lc2020 == 17)] <- 1
# 
# pu_lc <- exact_extract(lc2020, pu, 'frac')
# rf <- raster::writeRaster(lc2020, filename="./lc2020_urb.tif", overwrite=TRUE)
lc2020 <- terra::rast("analyses/currie/lc2020_urb.tif")
lc20202 <- resample(lc2020, tempr, threads = TRUE)

pu_lc <- exact_extract(lc2020, pu, 'frac')

# write.csv(pu_lc, "analyses/currie/pu_lc_100km2.csv")
pu_lc <- read.csv("analyses/currie/pu_lc_100km2.csv")

pu$urb <- pu_lc$frac_1
pu$lockedout <- ifelse(pu$urb >= 0.5, TRUE, FALSE)
pu$lockedout[(pu$lockedin == TRUE) & (pu$lockedout == TRUE)] <- FALSE

# plot(pu_100[, "lockedin"], main = "Protected area coverage > 30%")

##### features processing #####
# species ranges
splist <- list.files(path = "analyses/currie/SpeciesAOH_v3", pattern='.tif$', all.files= T, full.names= T)
spstack <- terra::rast(splist)

# kbas
kba <- terra::rast("analyses/currie/KBA_proj.tif")
kba_r <- resample(kba, tempr)

# parc-connectedness indicator (avg by ecodist)
parc <- terra::rast("analyses/currie/PARC_proj.tif")
parc_r <- resample(parc, tempr)

# protconn indicator (avg by ecodist)
prot <- terra::rast("analyses/currie/ProtConn_proj.tif")
prot_r <- resample(prot, tempr)
prot_r <- prot_r/100

# total PA coverage
ecod <- terra::rast("analyses/currie/Ecodist_proj.tif")
ecod_r <- resample(ecod, tempr)
ecod_r[ecod_r > 0] <- 1

# remove features with inf values
featranges <- minmax(spstack)
feat_rem <- rownames(apply(featranges, 1, function(x) {x[x!= 1]}))
spstack2 <- subset(spstack, feat_rem, negate=TRUE)

# remove features not represented in planning units
norep <- c("Ambystoma_texanum", "Photinus_indictus")
spstack3 <- subset(spstack2, norep, negate=TRUE)

# stack features
feat <- c(spstack2, ecod_r, kba_r, prot_r, parc_r)

# define/get targets
sp_targets <- read.csv("analyses/currie/WPA2024_2022_SPI_species_taxon_targets_2.csv")
spn <- names(spstack2)
spn_filter <- sp_targets[sp_targets$Species %in% spn,]

# remove missing targets (if any)
missing <- spn[!spn %in% spn_filter$Species]
feat2 <- subset(feat, missing, negate=TRUE)

target10 <- c(spn_filter$Thr, 0.1, 0.1, 0.1, 0.1)
target20 <- c(spn_filter$Thr, 0.2, 0.2, 0.2, 0.2)
target30 <- c(spn_filter$Thr, 0.3, 0.3, 0.3, 0.3)
target40 <- c(spn_filter$Thr, 0.4, 0.4, 0.4, 0.4)
target50 <- c(spn_filter$Thr, 0.5, 0.5, 0.5, 0.5)

featweights <- c(rep(1/742, 742), 1, 1, 1, 1)

#plot(feat[[prot_r]])

##### build conservation problem #####
# create problem with chosen parameters 
Sys.time()
p1 <- problem(pu, feat2, cost_column = 'cost') %>%
  add_max_features_objective(100000) %>%  
  add_locked_in_constraints("lockedin") %>% 
  add_locked_out_constraints("lockedout") %>%
  add_binary_decisions() %>%
  add_top_portfolio(number_solutions = 5) %>% #, remove_duplicates = TRUE) %>%
  add_default_solver(threads = 12) %>%
  add_feature_weights(featweights) %T>%
  run_calculations()
Sys.time()

#print(p1)
saveRDS(p1, "analyses/currie/p1_maxfeat30_5sol.rds")
Sys.time()
p2 <- p1 %>% add_relative_targets(targets = target20)
p3 <- p1 %>% add_relative_targets(targets = target30)
p4 <- p1 %>% add_relative_targets(targets = target40)
p5 <- p1 %>% add_relative_targets(targets = target50)
Sys.time()

##### solve using optimizer #####
Sys.time()
s2 <- solve(p2, force = TRUE)
Sys.time()
s3 <- solve(p3, force = TRUE)
Sys.time()
s4 <- solve(p4, force = TRUE)
Sys.time()
s5 <- solve(p5, force = TRUE)
Sys.time()

st_write(s2, "analyses/currie/Results/PrioritizR/pu_100km_target20_5sol.shp", delete_dsn = TRUE)
st_write(s3, "analyses/currie/Results/PrioritizR/pu_100km_target30_5sol.shp", delete_dsn = TRUE)
st_write(s4, "analyses/currie/Results/PrioritizR/pu_100km_target40_5sol.shp", delete_dsn = TRUE)
st_write(s5, "analyses/currie/Results/PrioritizR/pu_100km_target50_5sol.shp", delete_dsn = TRUE)

Sys.time()

# plot solutions 
# plot(s1[,'solution_1'], main = "Solution", axes = FALSE)
# nrow(s1[s1$solution_1 == TRUE, ])

######### build conservation problem - minimum set ###########
# create problem with chosen parameters 
# p2 <- problem(pu, feat2, cost_column = 'cost') %>%
#   add_min_set_objective() %>%  
#   add_relative_targets(targets = target20) %>%  
#   add_locked_in_constraints("lockedin") %>% 
#   #add_locked_out_constraints("lockedout") %>%
#   add_binary_decisions() %>%
#   add_top_portfolio(number_solutions = 5) %>% #, remove_duplicates = TRUE) %>%
#   add_default_solver()
# 
# print(p2)

##### solve using optimizer #####
# s1 <- solve(p1, force = TRUE)
# st_write(s1, "./Results/pu_10km_target20_5sol.shp")

##### TEST CODE BELOW #####

##### feature importance scores #####
# calculate importance scores using Ferrier et al 2000 method 
# and extract the total importance scores  
# ir2 <- eval_ferrier_importance(p1, s1[,"solution_1"])

#plot importance scores 
# plot(ir2, axes = FALSE)

# ir3 <- sf::st_drop_geometry(ir2)
# write.csv(ir3, "analyses/currie/feat_importance_100km2_target30_sol5.csv")