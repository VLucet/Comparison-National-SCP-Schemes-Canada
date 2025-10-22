# load packages
library(sf)
library(raster)
library(fasterize)
library(tidyverse)
#library(here)
library(prioritizr)
library(gurobi)
library(Matrix)

setwd("/prioritization/")

# Planning unit. 1km * 1km raster. All pixels' value == 1
pu <- raster("03_other_layers/PU.tif")

# human footprint 1km * 1km raster and Indigenous lands

HF <- raster("03_other_layers/HF.tif")

indi <- st_read("03_other_layers/Indiginous/indiginious.shp") %>%
  st_transform(crs = st_crs(pu))

indi_rast <- pu
indi_rast <- raster::rasterize(indi,indi_rast, field = 1)

#need to run compute intensive stuff only once
#FIRST <- FALSE

#if(FIRST){
  # reading features 
  SAR <- list.files("02_species/SAR_noduplicate/", pattern = ".tif$",
                    full.names = TRUE)  %>%
    stack()
  
  
  amph <- list.files("02_species/Amph/", full.names = TRUE)   %>%
    stack()
  
  bird <- list.files("02_species/bird/",full.names = TRUE)  %>%
    stack()
  
  
  bee <- list.files("02_species/bee/",full.names = TRUE)   %>%
    stack()
  
  butterfly <- list.files("02_species/butterflies/",full.names = TRUE)   %>%
    stack()
  
  tree <- list.files("02_species/Tree_combine/",full.names = TRUE)   %>%
    stack()
  
  mamm <- list.files("02_species/Mamm/", full.names = TRUE)   %>%
    stack()
  
  rept <- list.files("02_species/Rept/", full.names = TRUE)   %>%
    stack()
  
  
  # creating rij matrix for each group of features
  
  rij_SAR <- rij_matrix(pu, SAR)
  rij_amph <- rij_matrix(pu, amph)
  rij_bird <- rij_matrix(pu, bird)
  rij_mamm <- rij_matrix(pu, mamm)
  rij_rept <- rij_matrix(pu, rept)
  rij_bee <- rij_matrix(pu, bee)
  rij_butterfly <- rij_matrix(pu, butterfly)
  rij_tree <- rij_matrix(pu, tree)
  
  # writing rij matrices
  rij_SAR %>% saveRDS("04_rij_matrix/rij_SAR.rds", compress = FALSE) 
  rij_amph %>% saveRDS( "04_rij_matrix/rij_amph.rds", compress = FALSE) 
  rij_bird %>% saveRDS( "04_rij_matrix/rij_bird.rds", compress = FALSE) 
  rij_mamm %>% saveRDS( "04_rij_matrix/rij_mamm.rds", compress = FALSE) 
  rij_rept %>% saveRDS( "04_rij_matrix/rij_rept.rds", compress = FALSE) 
  rij_bee %>% saveRDS( "04_rij_matrix/rij_bee.rds", compress = FALSE) 
  rij_butterfly %>% saveRDS( "04_rij_matrix/rij_butterfly.rds", compress = FALSE) 
  rij_tree %>% saveRDS( "04_rij_matrix/rij_tree.rds", compress = FALSE) 
  
  

  # define function for rbinding rij matrices
  bind_rij_rows <- function(x, y, verbose = TRUE) {
    ## if file paths supplied, then import
    if (inherits(x, "character")) {
      x <- readRDS(x)
    }
    if (inherits(y, "character")) {
      if (verbose) {
        message("rbinding: ", y)
      }
      y <- readRDS(y)
    }
    # if needed, coerce to dgtMatrix
    if (!inherits(x, "dgTMatrix")) {
      x <- as(x, "TsparseMatrix")
    }
    if (!inherits(y, "dgTMatrix")) {
      y <- as(y, "TsparseMatrix")
    }
    # create dgCMatrix
    out <- Matrix::sparseMatrix(
      i = c(x@i, y@i + nrow(x)),
      j = c(x@j, y@j),
      x = c(x@x, y@x),
      index1 = FALSE,
      repr = "T",
      dims = c(nrow(x) + nrow(y), max(ncol(x), ncol(y)))
    )
    # remove temporary objects
    rm(x, y)
    invisible(gc())
    # return result
    out
  }
  
  
  setwd("/04_rij_matrix")
  # rbind rij matrices togeather
  rij <-
    "rij_SAR.rds" %>%
    bind_rij_rows("rij_amph.rds") %>%
    bind_rij_rows("rij_bird.rds") %>%
    bind_rij_rows("rij_mamm.rds") %>%
    bind_rij_rows("rij_rept.rds") %>%
    bind_rij_rows("rij_bee.rds") %>%
    bind_rij_rows("rij_butterfly.rds") %>%
    bind_rij_rows("rij_tree.rds")
  
  # convert to CsparseMatrix for prioritizr
  rij <- as(rij, "CsparseMatrix")
  setwd("..")
  getwd()
  rij %>% saveRDS("04_rij_matrix/rij.rds", compress = FALSE) 
  
#} else {
#  rij <- readRDS("04_rij_matrix/rij.rds")
#}
  ############################################
  #############################################

#if(FIRST){
  # features
  spec_SAR <- tibble(id2 = 1000:(999 + nlayers(SAR)),
                     name = names(SAR),
                     group = "SAR",
                     row_sum = rowSums(rij_SAR))
  
  spec_amph <- tibble(id2 = 2000:(1999 + nlayers(amph)),
                      name = names(amph),
                      group = "amph",
                      row_sum = rowSums(rij_amph))
  
  
  spec_mamm <- tibble(id2 = 3000:(2999 + nlayers(mamm)),
                      name = names(mamm),
                      group = "mamm",
                      row_sum = rowSums(rij_mamm))
  
  spec_rept <- tibble(id2 = 4000:(3999 + nlayers(rept)),
                      name = names(rept),
                      group = "rept",
                      row_sum = rowSums(rij_rept))
  
  
  spec_bee <- tibble(id2 = 6000:(5999 + nlayers(bee)),
                     name = names(bee),
                     group = "bee",
                     row_sum = rowSums(rij_bee))
  
  spec_butterfly <- tibble(id2 = 7000:(6999 + nlayers(butterfly)),
                           name = names(butterfly),
                           group = "butterfly",
                           row_sum = rowSums(rij_butterfly))
  
  spec_tree <- tibble(id2 = 8000:(7999 + nlayers(tree)),
                      name = names(tree),
                      group = "tree",
                      row_sum = rowSums(rij_tree))
  
  spec_bird <- tibble(id2 = 9000:(8999 + nlayers(bird)),
                      name = names(bird),
                      group = "bird",
                      row_sum = rowSums(rij_bird))
  ###################################################
  spec <- bind_rows(spec_SAR,
                    spec_amph,
                    spec_bird,
                    spec_mamm,
                    spec_rept,
                    spec_bee,
                    spec_butterfly,
                    spec_tree
                    
                    
  )
  
  spec$id <- 1:nrow(spec)
  spec %>% saveRDS("04_rij_matrix/spec.RDS")
  ###################################################
#} else {
#  spec <- readRDS("04_rij_matrix/spec.RDS")
#}

# Protected
CPCAD <- raster("/PA/CPCAD.tif")


CPCAD_lock <- ifelse(!is.na(CPCAD[][!is.na(pu[])]), TRUE, FALSE)

NCC_direct <- raster("/PA/NCC_direct.tif")
NCC_indirect <- raster("/PA/NCC_indirect.tif")

CPCAD_NCC <- sum(CPCAD, NCC_direct, NCC_indirect, na.rm = TRUE)
CPCAD_NCC[] <- ifelse(CPCAD_NCC[] > 0, 1, NA)
CPCAD_NCC_lock <- ifelse(!is.na(CPCAD_NCC[][!is.na(pu[])]), TRUE, FALSE)
plot(CPCAD_NCC)

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 1: 
# Cost = equal 
# target: loglinear
# protected areas: locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
  p1 <- problem(rep(1, ncol(rij)),
                features = spec,
                rij_matrix = rij) %>%
    add_min_set_objective() %>%
    #add_relative_targets("prop_Jeff") %>%
    #add_absolute_targets("absul_jeff") %>%
    add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
    add_binary_decisions() %>% 
    add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)


p1 <- p1 %>%
    add_locked_in_constraints(CPCAD_NCC_lock)
  

s1 <- solve(p1, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r1 <- pu
r1_val <- r1[][!is.na(pu[])]
r1_val <- s1
r1[][!is.na(pu[])] <- r1_val

#plot(r1)
r1 %>% writeRaster("05_final_result/S1.tif", overwrite = TRUE)

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 2: 
# Cost = equal 
# target: loglinear
# protected areas: NOT locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p2 <- problem(rep(1, ncol(rij)),
              features = spec,
              rij_matrix = rij) %>%
  add_min_set_objective() %>%
  #add_relative_targets("prop_Jeff") %>%
  #add_absolute_targets("absul_jeff") %>%
  add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)


s2 <- solve(p2, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r2 <- pu
r2_val <- r2[][!is.na(pu[])]
r2_val <- s2
r2[][!is.na(pu[])] <- r2_val

plot(r2)
r2 %>% writeRaster("05_final_result/S2.tif", overwrite = TRUE)

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 3: 
# Cost = equal 
# target: loglinear
# protected areas: locked-in
# penalty = HF   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
HF_val <- HF[][!is.na(pu[])]
HF_val <- ifelse(is.na(HF_val), 0, HF_val)

p3 <- p1 %>% 
  add_linear_penalties(1, HF_val)

s3 <- solve(p3, run_checks = FALSE, force = TRUE)

r3_prot_HF <- pu
r3_prot_HF_val <- r3_prot_HF[][!is.na(pu[])]
r3_prot_HF_val <- s3
r3_prot_HF[][!is.na(pu[])] <- r3_prot_HF_val

plot(r3_prot_HF)
r3_prot_HF %>% writeRaster("05_final_result/S3.tif", overwrite = TRUE)
#removed from results

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 4: 
# Cost = equal 
# target: loglinear
# protected areas: Not locked-in
# penalty = HF   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p4 <- p2 %>% 
  add_linear_penalties(1, HF_val)

s4 <- solve(p4, run_checks = FALSE, force = TRUE)

r4_prot_HF <- pu
r4_prot_HF_val <- r4_prot_HF[][!is.na(pu[])]
r4_prot_HF_val <- s4
r4_prot_HF[][!is.na(pu[])] <- r4_prot_HF_val

plot(r4_prot_HF)
r4_prot_HF %>% writeRaster("05_final_result/S4.tif", overwrite = TRUE)
#removed from analysis

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 5: 
# Cost = HF 
# target: loglinear
# protected areas: locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p5 <- problem(HF_val + 0.001,
                 features = spec,
                 rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)

p5 <- p5 %>%
  add_locked_in_constraints(CPCAD_NCC_lock)

s5 <- solve(p5, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)

r5_HF <- pu
r5_HF_val <- r5_HF[][!is.na(pu[])]
r5_HF_val <- s5
r5_HF[][!is.na(pu[])] <- r5_HF_val

plot(r5_HF)
r5_HF %>% writeRaster("05_final_result/S5.tif", overwrite = TRUE)


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 6: 
# Cost = HF 
# target: loglinear
# protected areas: NOT locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p6 <- problem(HF_val + 0.001,
                 features = spec,
                 rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)



s6 <- solve(p6, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)

r6_HF <- pu
r6_HF_val <- r6_HF[][!is.na(pu[])]
r6_HF_val <- s6
r6_HF[][!is.na(pu[])] <- r6_HF_val

plot(r6_HF)
r6_HF %>% writeRaster("05_final_result/S6.tif", overwrite = TRUE)


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 7: 
# Cost = 1 
# target: 30%
# protected areas: locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p7 <- problem(rep(1, ncol(rij)),
              features = spec,
              rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_relative_targets(0.3) %>%
  #add_absolute_targets("absul_jeff") %>%
  #add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)

p7 <- p7 %>%
  add_locked_in_constraints(CPCAD_NCC_lock)

s7 <- solve(p7, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r7 <- pu
r7_val <- r7[][!is.na(pu[])]
r7_val <- s7
r7[][!is.na(pu[])] <- r7_val

plot(r7)
r7 %>% writeRaster("05_final_result/S7.tif", overwrite = TRUE)


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 8: 
# Cost = 1 
# target: 30%
# protected areas: NOTlocked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p8 <- problem(rep(1, ncol(rij)),
               features = spec,
               rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_relative_targets(0.3) %>%
  #add_absolute_targets("absul_jeff") %>%
  #add_loglinear_targets(1000,1,250000,0.1,1000000,100000) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)


s8 <- solve(p8, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r8 <- pu
r8_val <- r8[][!is.na(pu[])]
r8_val <- s8
r8[][!is.na(pu[])] <- r8_val

plot(r8)
r8 %>% writeRaster("05_final_result/S8.tif", overwrite = TRUE)


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 9: 
# Cost = 1 
# target: 30%
# protected areas: locked-in
# penalty = HF   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p9 <- p7 %>% 
  add_linear_penalties(1, HF_val)


s9 <- solve(p9, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r9 <- pu
r9_val <- r9[][!is.na(pu[])]
r9_val <- s9
r9[][!is.na(pu[])] <- r9_val

plot(r9)
r9 %>% writeRaster("05_final_result/S9.tif", overwrite = TRUE)
#removed from results

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 10: 
# Cost = 1 
# target: 30%
# protected areas: NOT locked-in
# penalty = HF   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p10 <- p8 %>% 
  add_linear_penalties(1, HF_val)


s10 <- solve(p10, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)
#f1 <- eval_ferrier_importance(p1, s1)

r10 <- pu
r10_val <- r10[][!is.na(pu[])]
r10_val <- s10
r10[][!is.na(pu[])] <- r10_val

plot(r10)
r10 %>% writeRaster("05_final_result/S10.tif", overwrite = TRUE)
#removed from results

##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 11: 
# Cost = HF 
# target: 30%
# protected areas: locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p11 <- problem(HF_val + 0.001,
              features = spec,
              rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_relative_targets(0.3) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)

p11 <- p11 %>%
  add_locked_in_constraints(CPCAD_NCC_lock)


s11 <- solve(p11, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)

r11_HF <- pu
r11_HF_val <- r11_HF[][!is.na(pu[])]
r11_HF_val <- s11
r11_HF[][!is.na(pu[])] <- r11_HF_val

plot(r11_HF)
r11_HF %>% writeRaster("05_final_result/S11.tif", overwrite = TRUE)


##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
# Scenario 12: 
# Cost = HF 
# target: 30%
# protected areas: NOT locked-in
# penalty = NA   
##################################################################
##################################################################
##################################################################
##################################################################
##################################################################
p12 <- problem(HF_val + 0.001,
               features = spec,
               rij_matrix = rij) %>%
  add_min_set_objective() %>%
  add_relative_targets(0.3) %>%
  add_binary_decisions() %>% 
  add_gurobi_solver(gap = 0.01, threads = parallel::detectCores() - 1)



s12 <- solve(p12, run_checks = FALSE, force = TRUE)
# fr1 <- eval_feature_representation_summary(p1, s1)

r12_HF <- pu
r12_HF_val <- r12_HF[][!is.na(pu[])]
r12_HF_val <- s12
r12_HF[][!is.na(pu[])] <- r12_HF_val

plot(r12_HF)
r12_HF %>% writeRaster("05_final_result/S12.tif", overwrite = TRUE)
















