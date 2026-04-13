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