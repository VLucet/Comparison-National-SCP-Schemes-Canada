library(targets)
library(tarchetypes)
library(geotargets)
library(dplyr)

tar_source()

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
      temp <- sum(karimi_scenarios_locked)
      names(temp) <- "sum"
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
      names(r_scaled) <- "scaled"
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
      temp <- sum(eckert_scenarios)
      names(temp) <- "sum"
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
      names(r_scaled) <- "scaled"
      r_scaled
    }
  ),
  # Stacks and reprojects
  tar_terra_rast(
    eckert_stack,
    resample(project(c(eckert_scenarios, eckert_scenarios_sum, eckert_scenarios_scaled), 
                     karimi_stack, method = "near"), 
             karimi_stack, method = "near")
  ),

  ## Currie: NOW AVAILABLE, code does not reproduces the results
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
    currie_rast_all_sols, 
    rasterize(vect(currie_sf_clean), karimi_stack, field = "targetsum")
  ),
  # Rescale
  tar_terra_rast(
    currie_rast_all_sols_scaled, 
    {
      r_min <- global(currie_rast_all_sols, "min", na.rm=TRUE)[,1]
      r_max <- global(currie_rast_all_sols, "max", na.rm=TRUE)[,1]
      r_scaled <- (currie_rast_all_sols - r_min) / (r_max - r_min)
    }
  ),

  ## Stack all rasters, reproject, run correlations
  tar_terra_rast(
    all_scenarios,
    c(karimi_stack, eckert_stack, currie_rast_all_sols)
  ),
  tar_qs(
    all_scenarios_values,
    as.data.frame(values(all_scenarios))
  ),
  tar_qs(
    all_scenarios_values_clean,
    {
      temp <- all_scenarios_values[rowSums(is.na(all_scenarios_values)) != ncol(all_scenarios_values), ]
      temp[is.na(temp)] <- 0
      temp
    }
  ),
  tar_target(
    all_scenarios_cor,
    cor(all_scenarios_values_clean)
  ),

  ## Combine the 3 results, make "consensus map" (redo what olivia did, essentially)


  ## Old way to look at it, see later

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