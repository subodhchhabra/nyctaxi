library(readr)
library(dplyr)
library(lubridate)
library(tidyr)
library(httr)
library(rgdal)
library(broom)

get_nyc_neighborhoods <- function(){
  r <- GET('http://data.beta.nyc//dataset/0ff93d2d-90ba-457c-9f7e-39e47bf2ac5f/resource/35dd04fb-81b3-479b-a074-a27a37888ce7/download/d085e2f8d0b54d4590b1e7d1f35594c1pediacitiesnycneighborhoods.geojson')
  return(readOGR(content(r,'text'), 'OGRGeoJSON', verbose = F))
}
    

###########################################
# read in the files and create a data frame 
###########################################
load("one_week_taxi.Rdata")

# get nyc boundaries
nyc_neighborhoods <- get_nyc_neighborhoods()

nyc_df <- tidy(nyc_neighborhoods)
min_lat <- min(nyc_df$lat)
max_lat <- max(nyc_df$lat)
min_lng <- min(nyc_df$long)
max_lng <- max(nyc_df$long)

# filter out pickups and dropoffs outside of nyc boundaries
taxi_clean <- filter(taxi,  pickup_longitude >= min_lng & pickup_longitude <= max_lat & pickup_latitude >= min_lat & pickup_latitude <= max_lat &
                      dropoff_longitude >= min_lng & dropoff_longitude <= max_lat & dropoff_latitude >= min_lat & dropoff_latitude <= max_lat)

# join the neighborhood info for pickup
spdf <- taxi_clean
coordinates(spdf) <- ~pickup_longitude +pickup_latitude
proj4string(spdf) <- proj4string(nyc_neighborhoods)
matches <- over(spdf, nyc_neighborhoods)
taxi_clean <- cbind(taxi_clean, matches)

# rename fields created for pickup neighborhoods
taxi_clean <- rename(taxi_clean, pickup_neighborhood = neighborhood,pickup_borough=borough, pickup_boroughCode = boroughCode, pickup_X.id = X.id)

#  join the neighborhood info for dropoff
spdf <- taxi_clean
coordinates(spdf) <- ~dropoff_longitude +dropoff_latitude
proj4string(spdf) <- proj4string(nyc_neighborhoods)
matches <- over(spdf, nyc_neighborhoods)
taxi_clean <- cbind(taxi_clean, matches)

# rename dropoff neighborhood field
taxi_clean <- rename(taxi_clean, dropoff_neighborhood = neighborhood,dropoff_borough=borough, dropoff_boroughCode = boroughCode, dropoff_X.id = X.id)

# display stats by day of week, hour, pickup neighborhood, and dropoff neighborhood
taxi_clean %>% group_by(ymd_pickup, hour, pickup_neighborhood, dropoff_neighborhood) %>% 
         summarize(count=n(), avg_distance = mean(trip_distance), sd_distance = sd(trip_distance),
                    avg_tip = mean(tip_amount), sd_tip = sd(tip_amount), 
                    avg_fare = mean(fare_amount), sd_fare = sd(fare_amount),
                    avg_time_in_sec = mean(trip_time_in_secs), sd_time_in_sec = sd(trip_time_in_secs)) %>% 
  View()