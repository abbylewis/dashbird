library(tidyverse)
source("01_collect_data/parse_json.R")

#Load data from 2025 and before
everything <- read_csv("02_extracted_data/Abby_allData.csv", show_col_types = F) %>%
  mutate(Observer = "Abby Lewis") %>%
  bind_rows(read_csv("02_extracted_data/Bjorn_allData.csv", show_col_types = F) %>%
              mutate(Observer = "Bjorn Larson"))  %>%
  bind_rows(read_csv("02_extracted_data/Eric_allData.csv", show_col_types = F) %>%
              mutate(Observer = "Eric Larson"))  %>%
  bind_rows(read_csv("02_extracted_data/Sue_allData.csv", show_col_types = F) %>%
              mutate(Observer = "Susan Lewis")) 

#Now load newer data
#Extract data from json files to append
jsons <- list.files("02_extracted_data", pattern = ".json", recursive = T, full.names = T)
recents <- jsons %>%
  map(parse_json_ebird) %>%
  bind_rows() %>%
  filter(!`Submission ID` %in% everything$`Submission ID`)

comb <- everything %>%
  mutate(Time = as.character(Time)) %>%
  bind_rows(recents) %>%
  mutate(Date = as.Date(Date, format = "%d %b %Y")) %>%
  arrange(Date) %>%
  mutate(check_ID = paste(Date, Time, Latitude, Longitude),
         `Common Name` = sub(" \\(.+\\)", "", `Common Name`)) %>%
  filter(!grepl("sp\\.", `Common Name`),
         !grepl("\\/", `Common Name`)) %>%
  mutate(Observer = ifelse(Observer == "Abigail  Lewis", "Abby Lewis", Observer))

write_csv(comb, "02_extracted_data/for_dashbird.csv")
