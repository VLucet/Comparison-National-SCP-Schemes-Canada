library(targets)
library(tarchetypes)
library(geotargets)
library(dplyr)
library(ggplot2)
library(ggrepel)

tar_source("functions.R")

tar_option_set(packages = c(
  "here", 
  "ggplot2",
  "stringr",
  "dplyr",
  "terra",
  "sf")
)

list(

  ## INPUTS

  ## Canada boundaries
  tar_target(
    canada_archive_path,
    here("data", "canada", "canada.zip")
  ),
  tar_target(
    canada_archive, 
    {
      if (!file.exists(canada_archive_path)) {
        download.file(
          "https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/boundary-limites/files-fichiers/lpr_000b21a_e.zip",
          canada_archive_path
        )
      }
      canada_archive_path
    }
  ),
  # Unzip
  tar_file(
    canada_shp,
    unzip(canada_archive, exdir = here("data", "canada"))
  ),
  # Load as sf
  tar_target(
    canada_sf,
    st_read(canada_shp[str_detect(canada_shp, fixed(".shp"))]) |> st_union()
  ),
  # Simplify
  tar_target(
    canada_sf_simp, 
    st_simplify(canada_sf, dTolerance = 1000)
  ),

  # ## Make canada raster based off KARIMI
  # tar_terra_rast(
  #   canada_rast,
  #   {
  #     as_sf <- st_as_sf(canada_sf_simp) |> st_transform(st_crs(karimi_scenarios))
  #     as_sf["can"] <- 1
  #     rasterize(as_sf, karimi_scenarios, field = "can")
  #   }
  # ),

  ## PAs (from karimi)
  # File
  tar_file(
    protected_areas_file,
    here("data", "analyses", "karimi", "PA.tif")
  ),
  # Raster
  tar_terra_rast(
    protected_areas,
    rast(protected_areas_file)
  ),
  # Values
  tar_qs(
    protected_areas_values,
    values(protected_areas)
  ),

  ## Karimi
  ## shared by the author
  tar_file(
    karimi_archive_analysis, 
    here("data", "archives", "karimi", "Canada wide prioritization.zip")
  ),
  tar_file(
    karimi_archive_results, 
    here("data", "archives", "karimi", "3-final_result.zip")
  ),
  # Extract them
  tar_file(
    karimi_analysis,
    unzip(karimi_archive_analysis, exdir = here("data", "analyses", "karimi"))
  ),
   tar_file(
    karimi_results,
    unzip(karimi_archive_results, exdir = here("data", "analyses", "karimi"))
  ),
  # Load all scenarios
  tar_terra_rast(
    karimi_scenarios,
    {
      no_penalty <- karimi_results[!str_detect(karimi_results, "[Pp]enalty")]
      no_ind_only <- no_penalty[!str_detect(no_penalty, fixed("with_Indigenous_lands"))]
      rast(no_ind_only)
    }
  ),
  # Filter down to locked
  tar_terra_rast(
    karimi_scenarios_locked, 
    karimi_scenarios[[which(str_detect(names(karimi_scenarios), "_L(ockedin|okedin)_"))]]
  ),
  # Sum them
  tar_terra_rast(
    karimi_scenarios_locked_sum,
    {
      temp <- sum(karimi_scenarios_locked, na.rm = T)
      names(temp) <- "karimi_sum"
      temp
    }
  ),
  # Scale them
  tar_terra_rast(
    karimi_scenarios_locked_scaled, 
    {
      r_min <- global(karimi_scenarios_locked_sum, "min", na.rm=TRUE)[,1]
      r_max <- global(karimi_scenarios_locked_sum, "max", na.rm=TRUE)[,1]
      r_scaled <- (karimi_scenarios_locked_sum - r_min) / (r_max - r_min)
      names(r_scaled) <- "karimi_scaled"
      r_scaled
    }
  ),
  # Stack
  tar_terra_rast(
    karimi_stack,
    c(karimi_scenarios_locked, karimi_scenarios_locked_sum, karimi_scenarios_locked_scaled)
  ),

  ## Eckert, downloaded from figshare
  ## https://figshare.com/ndownloader/articles/21732722?private_link=0551e56687ba119c7bb8
  ## Private link, so automation is not possible
  tar_file(
    eckert_archive,    
    here("data", "archives", "eckert", "21732722.zip")
  ),
  # Extract sub-archives (it's an archive of archives)
  tar_file(
    eckert_sub_archives,
    unzip(eckert_archive, exdir = here("data", "analyses", "eckert"))
  ),
  # Extract all subarchives
  tar_file(
    eckert_all_files,
    unlist(lapply(X = eckert_sub_archives, 
      FUN = unzip, exdir = here("data", "analyses", "eckert")))
  ),
  # Load the scenarios
  tar_terra_rast(
    eckert_scenarios, 
    {
      eckert_all_tif <- eckert_all_files[!str_detect(eckert_all_files, fixed(".xml"))]
      eckert_all_sce <- eckert_all_tif[!str_detect(eckert_all_tif, fixed("__MACOSX"))]
      eckert <- rast(eckert_all_sce[str_detect(eckert_all_sce, fixed("Binary Run Maps"))])
      eckert[eckert != 0] <- 1
      eckert
    }
  ),
  # Sum them
  tar_terra_rast(
    eckert_scenarios_sum, 
    {
      temp <- sum(eckert_scenarios, na.rm = T)
      names(temp) <- "eckert_sum"
      temp
    }
  ),
  # Scale them
  tar_terra_rast(
    eckert_scenarios_scaled,
    {
      r_min <- global(eckert_scenarios_sum, "min", na.rm=TRUE)[,1]
      r_max <- global(eckert_scenarios_sum, "max", na.rm=TRUE)[,1]
      r_scaled <- (eckert_scenarios_sum - r_min) / (r_max - r_min)
      names(r_scaled) <- "eckert_scaled"
      r_scaled
    }
  ),
  tar_terra_rast(
    eckert_scenarios_scaled_rj,
    resample(
          project(eckert_scenarios_scaled, karimi_scenarios_locked_scaled, method = "near"),
          karimi_scenarios_locked_scaled, method = "near"
        )
  ),
  # Stacks and reprojects
  tar_terra_rast(
    eckert_stack,
    c(resample(project(c(eckert_scenarios, eckert_scenarios_sum), 
                     karimi_stack, method = "near"), 
             karimi_scenarios_locked_scaled, method = "near"), eckert_scenarios_scaled_rj)
  ),

  ## Currie
  tar_file(
    currie_archive,    
    here("data", "archives", "currie", "28255109.zip")
  ),
  tar_target(
    currie_all_files,
    {
      the_list <- as.list(unzip(currie_archive, exdir = here("data", "analyses", "currie")))
      names(the_list) <- sapply(the_list, basename)
      return(the_list)
    }
  ),
  tar_target(
    currie_sf,
    st_read(currie_all_files["pu_100km_alltargets_1sol.shp"])
  ),
  # Deal with duplicated features
  tar_target(
    currie_sf_clean,
    currie_sf |> group_by(OBJECTID_1) |> slice(1) |> ungroup()
  ),
  # Comvert to rast
  tar_terra_rast(
    currie_stack_pre, 
    c(
       rasterize(vect(currie_sf_clean), karimi_scenarios_locked_scaled, field = "target20"),
       rasterize(vect(currie_sf_clean), karimi_scenarios_locked_scaled, field = "target30"),
       rasterize(vect(currie_sf_clean), karimi_scenarios_locked_scaled, field = "target40"),
       rasterize(vect(currie_sf_clean), karimi_scenarios_locked_scaled, field = "target50"),
       rasterize(vect(currie_sf_clean), karimi_scenarios_locked_scaled, field = "targetsum")
    )
  ),
  # Rescale
  tar_terra_rast(
    currie_rast_all_sols_scaled,
    {
      r_min <- global(currie_stack_pre[["targetsum"]], "min", na.rm=TRUE)[,1]
      r_max <- global(currie_stack_pre[["targetsum"]], "max", na.rm=TRUE)[,1]
      r_scaled <- (currie_stack_pre[["targetsum"]] - r_min) / (r_max - r_min)
      names(r_scaled) <- "currie_scaled"
      r_scaled
    }
  ),
  # Full stack
  tar_terra_rast(
    currie_stack,
    c(currie_stack_pre, currie_rast_all_sols_scaled)
  ),

  ## Stack all rasters, reproject, run correlations
  ## SEE SCRIPT ( could not do that with targets)

  ## Combine the 3 results, make "consensus map" (redo what olivia did, essentially)
  tar_terra_rast(
    all_scenarios,
    c(karimi_stack, eckert_stack, currie_stack)
  ),
  # Get Values
  tar_qs(
    all_scenarios_values,
    as.data.frame(values(all_scenarios))
  ),
  # Get coords
  tar_qs(
    all_scenarios_coords,
    as.data.frame(crds(all_scenarios[[1]], na.rm = FALSE))
  ),
  # Remove PAs
  tar_qs(
    all_scenarios_values_clean_pre,
    {
      temp <- all_scenarios_values
      temp[which(protected_areas_values==1),] <- NA
      temp
    }
  ),
  # Align NAs
  tar_qs(
    all_scenarios_values_clean,
    {  
      to_include <- rowSums(is.na(all_scenarios_values_clean_pre)) != 
          ncol(all_scenarios_values_clean_pre)
      
      temp_coords <- all_scenarios_coords[to_include, ]
      temp <- all_scenarios_values_clean_pre[to_include, ]
      temp[is.na(temp)] <- 0
      
      cbind(temp_coords, temp)
    }
  ),
  # Correlations
  tar_target(
    scenarios_cor,
    cor(all_scenarios_values_clean[,3:ncol(all_scenarios_values_clean)])
  ),
  # Heatmap
  tar_target(
    cor_heatmap,
    heatmap(scenarios_cor, symm = T)
  ),


  # Centroids
  tar_target(
    scenarios_centroids,
    {
      xy_mat_scaled <- scale(all_scenarios_values_clean[,1:2]) |> 
        as.matrix()
      values_mat <- all_scenarios_values_clean[,3:ncol(all_scenarios_values_clean)] |> 
        as.matrix()
      values_mat_norm <- sweep(values_mat, 2, colSums(values_mat), "/")
      centroids <- t(xy_mat_scaled) %*% values_mat_norm 

      t(centroids) |> 
        as.data.frame() |>
        tibble::rownames_to_column("scenario") 
    }
  ),
  # Scanario LUT
  tar_target(
    scenario_LUT,
    get_scenario_LUT(scenarios_centroids)
  ),
  # clean
  tar_target(
    scenarios_centroids_clean, 
    scenarios_centroids |>
      left_join(scenario_LUT)
  ),
  # Plot
  tar_target(
    scenario_centroid_plot,
    {
      p <- scenarios_centroids_clean |>
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
            labs(x="Centroid Longitude (Scaled & Centered)", 
                 y="Centroid Latitude (Scaled & Centered)", 
          color = "Scenario \nOrigin")
      ggsave("centroid_plot.png", p, width = 8, height = 10)
      p
    }
  ),
  
  ## Old way to look at it, see later

  ## Create hexes
  ## OLD: my grid
  # tar_target(
  #   all_hexes,
  #   st_make_grid(canada_sf_simp, cellsize = 10000, square = FALSE)
  # ),
  ## NEW: use Currie's hexes
   tar_target(
    all_hexes,
    currie_sf_clean |> select(OBJECTID_1)
  ),
  tar_target(
    canada_sf_simp_reproj, 
    st_transform(canada_sf_simp, st_crs(all_hexes))
  ),
  # Crop to file
  tar_target(
    canada_hexes,
    {
      inter <- st_intersection(all_hexes, canada_sf_simp_reproj)
      st_write(inter, here("data", "canada", "canada_hexes.shp"))
      inter
    }
  ),
  # Transform to each
  tar_target(
    canada_hexes_eckert,
    st_transform(canada_hexes, crs(eckert_scenarios)) |> 
      st_as_sf() 
      |> mutate(hex_id = 1:nrow(canada_hexes))
  ),
  tar_target(
    canada_hexes_karimi,
    st_transform(canada_hexes, crs(karimi_scenarios)) |> 
      st_as_sf() 
      |> mutate(hex_id = 1:nrow(canada_hexes))
  ),

  ## Mean of rasters
  tar_terra_rast(
    eckert_prob, 
    {
      res <- mean(eckert_scenarios, na.rm = T)
      writeRaster(res, here("results", "eckert_prob.tif"), overwrite = T)
      res
    }
  ),
  # Filter down to locked only + prob of selection 
  tar_terra_rast(
    karimi_prob,
    {
      res <- mean(karimi_scenarios_locked)
      writeRaster(res, here("results", "karimi_prob.tif"), overwrite = T)
      res
    }
  ),
  # vect extract
  tar_target(
    eckert_prob_extract,
    {
      ext <- terra::extract(eckert_prob, canada_hexes_eckert, fun = my_mean)
      mod <- canada_hexes_eckert |> 
        bind_cols(ext) |>
        st_transform(st_crs(canada_hexes_karimi)) |>
        rename(mean_eckert = mean)
      stopifnot(all(mod$ID == mod$hex_id))
      mod
    }
  ),
  tar_target(
    karimi_prob_extract,
    {
      ext <- terra::extract(karimi_prob, canada_hexes_karimi, fun = my_mean)
      mod <- canada_hexes_karimi |> 
        bind_cols(ext) |>
        rename(mean_karimi = mean)
      stopifnot(all(mod$ID == mod$hex_id))
      mod
    }
  ),
  tar_target(
    prob_difference, 
    {
      karimi_prob_extract |>
        st_drop_geometry() |>
        left_join(eckert_prob_extract, by = join_by(hex_id, ID)) |>
        mutate(diff = mean_karimi-mean_eckert) |>
        st_as_sf()
    }
  ),

  ## headings
  tar_target(
    headings_coords,
    {
      headings <- st_centroid(prob_difference) |> 
        rename(geometry = x) |> 
        mutate(x = sapply(geometry, \(x)x[1])) |>
        mutate(y = sapply(geometry, \(x)x[2])) |>
        st_drop_geometry() |>
        # mutate(x = scale(x), y = scale(y)) |>
        mutate(x_w_eckert = x * mean_eckert, 
               y_w_eckert = y * mean_eckert) |>
        mutate(x_c_eckert = sum(x_w_eckert)/sum(mean_eckert), 
               y_c_eckert = sum(y_w_eckert)/sum(mean_eckert)) |>
        
        mutate(x_w_karimi = x * mean_karimi, 
               y_w_karimi = y * mean_karimi) |>
        mutate(x_c_karimi = sum(x_w_karimi)/sum(mean_karimi), 
               y_c_karimi = sum(y_w_karimi)/sum(mean_karimi)) |>
        select(x_c_eckert, y_c_eckert, x_c_karimi, y_c_karimi) |>
        unique()
      pts <- data.frame(
        study = c("eckert", "karimi"),
        x = c(headings$x_c_eckert, headings$x_c_karimi),
        y = c(headings$y_c_eckert, headings$y_c_karimi)) |>
        st_as_sf(coords = c("x", "y"))
      st_crs(pts) <- st_crs(prob_difference)
      pts
    }
  ),
  tar_target(
    headings_coords_nudged,
    {
      headings_coords_nudged <- 
        headings_coords |> 
        mutate(geometry = geometry + c(-250000, 0)) |>
        st_set_crs(st_crs(headings_coords))
    }
  ),

  # PLOT
  tar_target(
    main_plot, 
    {
      p <- ggplot() + 
        geom_sf(data = prob_difference, aes(fill = diff), color = NA) +
        scale_fill_gradient2() +
        geom_sf(data = headings_coords, col = "red", pch = 3, size = 5) +
        geom_sf_label(data = headings_coords_nudged,
                      aes(label = study)) +
        theme_minimal()
      ggsave("results/main_plot.png", p, height = 12, width = 14)
      p
    }
  )
)
