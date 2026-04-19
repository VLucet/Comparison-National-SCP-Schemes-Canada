# Targets paper full analysis
# This code uses a targets pipeline to produce intermediate outputs
# Some operations would not run inside the pipeline and therefore, after
# running targets::tar_make(), move on to the scripts in the scripts folder.

# Needed packages
library(targets)
library(tarchetypes)
library(geotargets)

# Load needed functions
tar_source("functions.R")

# Packages to load within pipepline
tar_option_set(packages = c(
  "here", 
  "curl",
  "readr",
  "tidyr",
  "ggplot2",
  "ggnewscale",
  "ggrepel",
  "patchwork",
  "pheatmap",
  "stringr",
  "dplyr",
  "terra",
  "tidyterra",
  "sf",
  "png",
  "grid"
  )
)

list(

  ## INPUTS

  ## Canada boundaries
  # Zipped file
  tar_target(
    canada_archive_path,
    here("data", "canada", "canada.zip")
  ),
  # Download if doesn't exist
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
    karimi_archive_results, 
    here("data", "archives", "karimi", "3-final_result.zip")
  ),
  # Extract them
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
  # Filter down to locked scenarios
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
  # Find correct files
  tar_file(
    eckert_all_sce,
    {
      eckert_all_tif <- eckert_all_files[!str_detect(eckert_all_files, fixed(".xml"))]
      eckert_all_sce <- eckert_all_tif[!str_detect(eckert_all_tif, fixed("__MACOSX"))]
      eckert_all_sce[str_detect(eckert_all_sce, fixed("Binary Run Maps"))]
    }
  ),
  # Load the scenarios
  # Protected area identification
  tar_terra_rast(
    eckert_PA, 
    {
      eckert <- rast(eckert_all_sce)[[1]]
      eckert <- eckert == 2
      names(eckert) <- "PA"
      eckert
    }
  ),
  # Reproj said PAs
  tar_terra_rast(
    eckert_PA_rj, 
    {
      resample(
          project(eckert_PA, karimi_scenarios_locked_scaled, method = "near"),
          karimi_scenarios_locked_scaled, method = "near"
        )
    }
  ),
  # All scenarios
  tar_terra_rast(
    eckert_scenarios, 
    {
      eckert <- rast(eckert_all_sce)
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
  # Reproj
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
  ## From downloaded archive
  tar_file(
    currie_archive,    
    here("data", "archives", "currie", "28255109.zip")
  ),
  # File list
  tar_target(
    currie_all_files,
    {
      the_list <- as.list(unzip(currie_archive, exdir = here("data", "analyses", "currie")))
      names(the_list) <- sapply(the_list, basename)
      return(the_list)
    }
  ),
  # Read as sf
  tar_target(
    currie_sf,
    st_read(currie_all_files["pu_100km_alltargets_1sol.shp"])
  ),
  # Deal with duplicated features
  tar_target(
    currie_sf_clean,
    currie_sf |> group_by(OBJECTID_1) |> slice(1) |> ungroup()
  ),
  # Convert to rast
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

  ## Protected areas (from Karimi's, combined with Eckert's for comparison in figure 3)
  # File
  tar_file(
    protected_areas_file,
    here("data", "analyses", "karimi", "PA.tif")
  ),
  # Load as raster
  tar_terra_rast(
    protected_areas,
    {
      protected_areas <- rast(protected_areas_file)
      protected_areas[eckert_PA_rj==1] <- 1
      protected_areas
    }
  ),
  # Have an NA option
  tar_terra_rast(
    protected_areas_mask,
    {
      temp <- protected_areas
      temp[temp!=1] <- NA
      temp
    }
  ),
  # Extract values
  tar_qs(
    protected_areas_values,
    values(protected_areas)
  ),

  ## ALL SCENARIOS FROM ALL STUDIES STACK
  tar_terra_rast(
    all_scenarios,
    c(karimi_stack, eckert_stack, currie_stack)
  ),

  ## Figure F4
  tar_terra_rast(
    all_scenarios_sum,
    sum(all_scenarios[[c("karimi_sum", "eckert_sum", "targetsum")]], na.rm = T)
  ),
  # Without PA
  tar_terra_rast(
    all_scenarios_sum_no_PA,
    {
      temp <- all_scenarios_sum
      temp[protected_areas==1] <- NA
      temp
    }
  ),
  # Make plot now
  tar_target(
    scenarios_sum_plot,
    {
      temp <- protected_areas_mask
      temp <- as.factor(temp)
      levels(temp) <- data.frame(ID=1, CPCAD="Protected \nArea")

      # P1
      p1 <- ggplot() +
        
        geom_spatraster(data=all_scenarios_sum_no_PA) +
        scale_fill_whitebox_c("soft") +

        labs(fill="Selection \nFrequency") +

        new_scale_fill() +

        geom_spatraster(data=temp) +
        scale_fill_manual(values=c(`Protected \nArea` = "grey75"), na.translate = F) +
        
        theme_minimal() +
        labs(fill="")
      ggsave(here("plots/Fig3_sum_plot.png"), p1)
      
      # P2
      # 5 is the cuttoff for about 30%
      # See:
      # as.data.frame(freq(all_scenarios_sum_no_PA)) |> 
      #   arrange(desc(value)) |> 
      #   mutate(prop = round((count/sum(count))*100, 2), cumprop = cumsum(prop))

      all_scenarios_sum_no_PA_30 <- as.numeric(all_scenarios_sum_no_PA>=5)
      all_scenarios_sum_no_PA_30 <- as.factor(all_scenarios_sum_no_PA_30)
      levels(all_scenarios_sum_no_PA_30) <- 
        data.frame(ID = c(0,1), sum = c("Unselected", "Selected (30%)"))

      p2 <- ggplot() +
        
        geom_spatraster(data=all_scenarios_sum_no_PA_30) +
        scale_fill_manual(
          values=c(`Unselected` = "#CC8656", 
                  `Selected (30%)` = "#83A961"), 
          na.translate = F
        ) +

        labs(fill="") +

        new_scale_fill() +

        geom_spatraster(data=temp) +
        scale_fill_manual(values=c(`Protected \nArea` = "grey75"), na.translate = F) +
        
        theme_minimal() +
        labs(fill="")
      ggsave(here("plots/Fig3_selection.png"), p2)

      p <- p1/p2 + plot_annotation(tag_levels = list(c("a)", "b)")))
      ggsave(here("plots/Fig3_complete.png"), p, height = 12, width = 8)
      p
    }
  ),


  ## Figures S1 & F5

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
  # Remove Protected areas
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
    {
      cors <- cor(all_scenarios_values_clean[,3:ncol(all_scenarios_values_clean)])
      rownames(cors) <- get_scenarios_in_order()
      colnames(cors) <- get_scenarios_in_order()
      cors
    }
  ),
  # Heatmap (Fig S1)
  tar_target(
    cor_heatmap,
    {
      png(here("plots", "S1_correlation_heatmap.png"), width = 1000, height = 1000)
      pheatmap(scenarios_cor, symm = T, treeheight_row = 0, treeheight_col = 0)
      dev.off()
    }
  ),

  ## Scenario Centroids
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
  # Figure 4
  tar_target(
    scenario_centroid_plot,
    {
      p <- scenarios_centroids_clean |>
            ggplot(aes(x, y, color = study)) +
            theme_bw() +
            geom_point(position = position_jitter(width = 0.1, seed = 123)) +
            geom_text_repel(
              aes(label = name, color = study),
              fontface = "bold",
              position = position_jitter(width = 0.1, seed = 123),
              box.padding = unit(0.5, "lines"),
              segment.color = 'grey', show.legend = FALSE) +
            scale_color_discrete(palette=c("#83A961", "#CC8656", "#467592")) +
            coord_fixed() +
            labs(x="Centroid Longitude (Scaled & Centered)", 
                 y="Centroid Latitude (Scaled & Centered)", 
          color = "Scenario \nOrigin")
      ggsave(here("plots", "Fig4_centroid_plot.png"), p, width = 8, height = 10)
      p
    }
  ),

  # Figure 2
  # Load data
  tar_target(
    fig2a_data,
    read_csv(here("data", "T_Fig2_Data.csv"))
  ),
  # Manipulate data
  tar_target(
    t_hist_long,
    process_hist_data(fig2a_data)
  ),
  # make the cpcad figure
  tar_target(
    cpcad,
    {
      img <- readPNG(here("plots","CPCAD.png"))
      img <- rasterGrob(img, interpolate = TRUE)
      ggplot() + 
        geom_blank() + 
        annotation_custom(img, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
        theme_minimal()
    }
  ),
  # Make figure
  tar_target(
    histogram_progress,
    {
      # Code contributed by M. Brochu
      fig <- ggplot(t_hist_long, aes(x = Region, y = Value, fill = Metric)) +
        # A. Reverse stacked bars so baseline is on the bottom
        geom_col(width = 0.8, position = position_stack(reverse = TRUE)) +
        # B. Facet: provinces & territories in left panel, national totals in right panel
        facet_grid(
          . ~ Group,
          scales = "free_x",
          space  = "free_x",
          switch = "x"          # strip labels at bottom
        ) +
        # C. Colours
        scale_fill_manual(
          values = c(
            "2020-2024 Increase" = "#83A961",
            "2020 Baseline"      = "#CC8656"
          )
        ) +
        # D. Y-axis: 0 to 25%, ticks every 5%
        scale_y_continuous(
          limits = c(0, 25),
          expand = expansion(mult = c(0, 0.02)),
          breaks = seq(0, 25, 5)
        ) +
        # E. Axis & legend labels
        labs(
          x    = NULL,
          y    = "Percentage",
          fill = NULL
        ) +
        # F. Aesthetics
        # Base theme: classic
        theme_classic(base_size = 12) +
        theme(
          # Panel border visible on all sides
          panel.grid   = element_blank(),
          panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.4),
          
          # Strip label styling
          strip.placement  = "outside",
          strip.background = element_blank(),
          strip.text       = element_text(face = "bold", size = 12),
          
          # Axis lines & ticks
          axis.line    = element_line(colour = "black", linewidth = 0.4),
          axis.ticks   = element_line(colour = "black", linewidth = 0.4),
          axis.text.x  = element_text(angle = 45, hjust = 1, vjust = 1, size = 10),
          axis.text.y  = element_text(size = 10),
          axis.title.y = element_text(size = 12, face = "bold", margin = margin(r = 8)),
          
          # Legend: horizontal, above the plot
          legend.position  = "top",
          legend.box       = "horizontal",
          legend.key.width = unit(1.4, "lines"),
          legend.spacing.x = unit(6, "pt"),
          legend.text      = element_text(size = 11),
          legend.margin    = margin(b = 6),
          
          # No in-figure title
          plot.title = element_blank()
        )
      fig_tot <- fig/cpcad + 
        plot_annotation(tag_levels = list(c("a)", "b)")))  +
        plot_layout(heights = c(2, 5))
      ggsave(here("plots", "Fig2a_protection_progress.png"), fig_tot, width = 9, height = 12)
      fig_tot
    }
  )
)
