library(shiny)
library(leaflet)
library(raster)
library(sf)

ui <- fluidPage(
  titlePanel("TIFF File Toggle Map"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("tiff_files", "Upload TIFF Files", 
                multiple = TRUE, 
                accept = c('.tif', '.tiff')),
      
      hr(),
      
      uiOutput("layer_controls"),
      
      sliderInput("opacity", "Layer Opacity", 
                  min = 0, max = 1, value = 0.7, step = 0.1)
    ),
    
    mainPanel(
      leafletOutput("map", height = "600px")
    )
  )
)

server <- function(input, output, session) {
  
  # Store uploaded rasters
  raster_data <- reactiveValues(layers = list())
  
  # Process uploaded files
  observeEvent(input$tiff_files, {
    req(input$tiff_files)
    
    # Keep existing layers and add new ones
    for(i in 1:nrow(input$tiff_files)) {
      file_path <- input$tiff_files$datapath[i]
      file_name <- input$tiff_files$name[i]
      
      # Skip if already loaded
      if(file_name %in% names(raster_data$layers)) {
        next
      }
      
      tryCatch({
        r <- raster(file_path)
        raster_data$layers[[file_name]] <- r
      }, error = function(e) {
        showNotification(paste("Error loading", file_name), type = "error")
      })
    }
  })
  
  # Create checkboxes for each layer
  output$layer_controls <- renderUI({
    req(length(raster_data$layers) > 0)
    
    checkboxes <- lapply(names(raster_data$layers), function(name) {
      checkboxInput(paste0("show_", make.names(name)), 
                    label = name, 
                    value = TRUE)
    })
    
    do.call(tagList, checkboxes)
  })
  
  # Initialize map
  output$map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -95, lat = 60, zoom = 4)  # Centered on Canada
  })
  
  # Update map when layers change
  observe({
    req(length(raster_data$layers) > 0)
    
    leafletProxy("map") %>%
      clearImages()
    
    for(name in names(raster_data$layers)) {
      checkbox_id <- paste0("show_", make.names(name))
      
      if(!is.null(input[[checkbox_id]]) && input[[checkbox_id]]) {
        r <- raster_data$layers[[name]]
        
        # Get extent
        ext <- extent(r)
        
        # Add raster to map
        leafletProxy("map") %>%
          addRasterImage(r, 
                        colors = colorNumeric("Spectral", 
                                            values(r), 
                                            na.color = "transparent"),
                        opacity = input$opacity,
                        layerId = name) %>%
          fitBounds(lng1 = ext@xmin, lat1 = ext@ymin,
                   lng2 = ext@xmax, lat2 = ext@ymax)
      }
    }
  })
}

shinyApp(ui = ui, server = server)