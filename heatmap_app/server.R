library(shiny)
library(dplyr)
library(httr)
library(rgdal)
library(leaflet)
library(tigris)
library(RColorBrewer)
#load("../Rdata/one_month_taxi.Rdata")

log_transform <- function(x) { if (x < 1) { 10^(x) } else { as.integer(10^(x))}}
log_transform <- Vectorize(log_transform)
range <- round(as.numeric(difftime(max(taxi_clean$pickup_datetime),
                                   min(taxi_clean$pickup_datetime), 
                                   unit="days")))

get_nyc_neighborhoods <- function()
{
  r <- GET('http://data.beta.nyc//dataset/0ff93d2d-90ba-457c-9f7e-39e47bf2ac5f/resource/35dd04fb-81b3-479b-a074-a27a37888ce7/download/d085e2f8d0b54d4590b1e7d1f35594c1pediacitiesnycneighborhoods.geojson')
  return(readOGR(content(r,'text'), 'OGRGeoJSON', verbose = F))
}

nyc_neighborhoods <- get_nyc_neighborhoods()
data <- taxi_clean

pal <- colorBin(palette = rev(brewer.pal(11, "Spectral")),
                domain = -2:5, na.color = "#808080")

shinyServer(function(input, output) {
  
  filtered_data <- reactive({
    if(input$neighborhood != "Entire NYC")
    {
      if (input$type == "pickup"){
        data <- data %>% filter(dropoff_neighborhood == input$neighborhood)
      } else {
        data <- data %>% filter(pickup_neighborhood == input$neighborhood)
      }
    }
    if (input$type == "pickup")
    {
      data <- data %>% 
        mutate(neighborhood = pickup_neighborhood,
               hour = pickup_hour)
    } else {
      data <- data %>% mutate(neighborhood = dropoff_neighborhood,
                              hour = dropoff_hour)
    }   
    
    data <- data %>%
      filter(hour >= input$hour[1] & hour <= input$hour[2]) %>%
      group_by(neighborhood) %>% 
      summarize(num_trips = log10(n()/range))
    
    map_data <- geo_join(nyc_neighborhoods, data, 
                         "neighborhood", "neighborhood")
    return(map_data)
  })
  output$map <- renderLeaflet({
    
    leaflet(nyc_neighborhoods) %>%
      addProviderTiles("CartoDB.Positron") %>%
      setView(-73.85, 40.71, zoom = 10) 
  })
  
  observe({
    leafletProxy("map", data = filtered_data())  %>% 
      clearShapes() %>% clearControls() %>%
      addPolygons(fillColor = ~pal(num_trips), 
                  popup = ~neighborhood,
                  weight = 1, 
                  fillOpacity = 0.4,
                  color="darkblue") %>% 
      addLegend(pal = pal, 
                title = "number of trips", 
                values = filtered_data()$num_trips,
                opacity = 0.4, 
                labFormat = labelFormat(transform = log_transform), 
                position = "bottomright")
  })
  
})