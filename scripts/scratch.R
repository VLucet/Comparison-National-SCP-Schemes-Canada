  # ## Make canada raster based off KARIMI
  # tar_terra_rast(
  #   canada_rast,
  #   {
  #     as_sf <- st_as_sf(canada_sf_simp) |> st_transform(st_crs(karimi_scenarios))
  #     as_sf["can"] <- 1
  #     rasterize(as_sf, karimi_scenarios, field = "can")
  #   }
  # ),

  tar_file(
    karimi_analysis,
    unzip(karimi_archive_analysis, exdir = here("data", "analyses", "karimi"))
  )
  tar_file(
    karimi_archive_analysis, 
    here("data", "archives", "karimi", "Canada wide prioritization.zip")
  )

list(
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