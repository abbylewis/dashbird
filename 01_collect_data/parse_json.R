install.packages("jsonlite")
install.packages("rebird")
library(jsonlite)
library(rebird)

ebirdregion_asl <- function (loc,
          key = NULL, ...) 
{
  url <- paste0("https://api.ebird.org/v2/ref/region/info/", loc)
  tt <- httr::GET(url, httr:::add_headers(`X-eBirdApiToken` = rebird:::get_key(key)))
  ss <- httr::content(tt, as = "text", encoding = "UTF-8")
  out <- fromJSON(ss)
  loc_data <- data.frame(lat = out$latitude, lng = out$longitude, locName = out$result)
  return(loc_data)
}

parse_json_ebird <- function(file) {
  json_data <- fromJSON(file)
  birds <- json_data$obs
  message(file)
  #Build in re-tries because sometime this fails (rate limiting API??)
  loc_data <- NULL
  
  for (i in 1:3) {
    
    # First try ebirdregion()
    loc_data <- tryCatch(
      ebirdregion(json_data$locId, key = Sys.getenv("ebird_key"), provisional = T, hotspot = F),
      error = function(e) {
        message(sprintf("Attempt %d: ebirdregion failed: %s", i, e$message))
        NULL
      }
    )
    
    # If that failed, try my version
    if (is.null(loc_data)) {
      loc_data <- tryCatch(
        ebirdregion_asl(json_data$locId, key = Sys.getenv("ebird_key")),
        error = function(e) {
          message(sprintf("Attempt %d: ebirdregioninfo failed: %s", i, e$message))
          NULL
        }
      )
    }
    
    # Success
    if (!is.null(loc_data)) break
    
    Sys.sleep(1)
  }

  out <- tibble(
    `Submission ID` = json_data$subId,
    `Common Name` = identify_common_name(birds$speciesCode),
    `Scientific Name` = identify_scientific_name(birds$speciesCode),
    Count = birds$howManyStr,
    `Location ID` = json_data$locId,
    Location = ifelse(!is.null(loc_data), 
                      unique(loc_data$locName),
                      NA),
    Latitude = ifelse(!is.null(loc_data), 
                      unique(loc_data$lat),
                      NA),
    Longitude = ifelse(!is.null(loc_data), 
                       unique(loc_data$lng),
                       NA),
    Date = as.Date(json_data$obsDt),
    Time = format(as.POSIXct(json_data$obsDt), "%H:%M:%S"),
    `Duration (Min)` = ifelse("durationHrs" %in% names(json_data), 
                              json_data$durationHrs*60,
                              NA),
    Observer = json_data$userDisplayName,
    `All Obs Reported` = json_data$allObsReported,
    `Distance Traveled (km)` = ifelse("effortDistanceKm" %in% names(json_data), 
                                      json_data$effortDistanceKm,
                                      NA),
    `Number of Observers` = json_data$numObservers
  )
  return(out)
}

tax <- ebirdtaxonomy()
identify_common_name <- function(species_codes){
  out <- c()
  for(code in species_codes){
    cn <- tax$comName[tax$speciesCode==code]
    out <- c(out, cn)
  }
  return(out)
}

identify_scientific_name <- function(species_codes){
  out <- c()
  for(code in species_codes){
    sn <- tax$sciName[tax$speciesCode==code]
    out <- c(out, sn)
  }
  return(out)
}
