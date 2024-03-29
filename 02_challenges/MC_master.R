### BCI-challenges repo/Rproj needs to be at the same level as ebird-datasets 
### for (relative) file paths to work!

library(tidyverse)
library(lubridate)
library(magrittr)
library(glue)
library(writexl) # to save results
library(readxl)

# function to get summary stats
source("https://raw.githubusercontent.com/birdcountindia/bci-functions/main/summaries.R")

###### automated parameters ####

# paths to latest versions of user & GA info, and sensitive species data
load(url("https://github.com/birdcountindia/ebird-datasets/raw/main/EBD/latest_non-EBD_paths.RData"))
userspath <- glue("../ebird-datasets/{userspath}")
groupaccspath <- glue("../ebird-datasets/{groupaccspath}")
senspath <- glue("../ebird-datasets/{senspath}")

cur_year <- today() %>% year()
cur_month_num <- today() %>% month()
cur_month_lab <- today() %>% month(label = T, abbr = T)

rel_year <- (today() - months(1)) %>% year()
rel_month_num <- (today() - months(1)) %>% month()
rel_month_lab <- (today() - months(1)) %>% month(label = T, abbr = T) 

mcdatapath <-  glue("../ebird-datasets/EBD/ebd_IN_rel{rel_month_lab}-{rel_year}_{toupper(rel_month_lab)}.RData")
mcresultspath <- glue("{rel_year}/MC_results_{rel_year}_{str_pad(rel_month_num, width=2, pad='0')}.xlsx")
# each monthly challenge script different---the only thing that changes each time master script run
mcpath <- glue("{rel_year}/MC_{rel_year}_{str_pad(rel_month_num, width=2, pad='0')}.R")

ycdatapath <-  glue("../ebird-datasets/EBD/ebd_IN_rel{rel_month_lab}-{rel_year}_{rel_year}.RData")
ycresultspath <- glue("{rel_year}/YC_results_{rel_year}.xlsx")
ycpath <- glue("{rel_year}/YC_{rel_year}.R")

###### loading data ####

# month's data
load(mcdatapath)

# year's data for yearly challenge
if (cur_month_num == 1) {
  load(ycdatapath)
}

# user info
eBird_users <- read.delim(userspath, sep = "\t", header = T, quote = "", 
                          stringsAsFactors = F, na.strings = c(""," ",NA)) %>% 
  transmute(OBSERVER.ID = observer_id,
            FULL.NAME = paste(first_name, last_name, sep = " "))

# list of group accounts to be filtered
groupaccs <- read_csv(groupaccspath) %>%
  mutate(CATEGORY = case_when(GA.1 == 1 ~ "GA.1", GA.2 == 1 ~ "GA.2", TRUE ~ "NG"))
filtGA <- groupaccs %>% 
  # both categories need to be filtered because this is birder-related 
  filter(CATEGORY == "GA.1" | CATEGORY == "GA.2") %>% 
  select(OBSERVER.ID)


###### monthly stats ####

stats <- basic_stats(data_mc)

###### monthly challenge winners/results ####

source(mcpath)

###### saving results into excel sheet ####

write_xlsx(x = list("Monthly stats" = stats, 
                    "Challenge results" = results, 
                    "Challenge winner" = winner),
           path = mcresultspath)


###### yearly stats (if January) ####

if (cur_month_num == 1 & exists("data_yc")) {
  
  stats <- basic_stats(data_yc)
  
} else if (cur_month_num == 1 & !exists("data_yc")) {
  
  print("Yearly data needed but not loaded.")
  
}

###### yearly challenge winners/results ####

if (cur_month_num == 1 & exists("data_yc")) {
  
  source(ycpath)
  
  
  ###### eBirder of the Year (eBirder of the Month >=8 months in 2021) ###
  
  # selection of final excludes the category winners
  yc_cat_w <- bind_rows(prolific_w, consistent_w, adventurous_w, 
                        faithful_w, dedicated_w) 
  
  
  # excel files separately
  temp <- list.files(path = glue("{rel_year}/"),
                     pattern = "MC_results_",
                     full.names = T)[9:12] %>% 
    map(~ read_xlsx(., sheet = 2)) %>% 
    bind_rows(.id = "MONTH") %>% 
    mutate(MONTH = case_when(MONTH == 1 ~ 9,
                             MONTH == 2 ~ 10,
                             MONTH == 3 ~ 11,
                             MONTH == 4 ~ 12))
  
  eBoY_r <- list.files(path = glue("{rel_year}/"),
                       pattern = "MC_results_",
                       full.names = T)[1:8] %>% 
    lapply(read_csv) %>% 
    bind_rows(.id = "MONTH") %>% 
    mutate(MONTH = as.numeric(MONTH)) %>% 
    bind_rows(temp) %>% 
    group_by(OBSERVER.ID, FULL.NAME) %>% 
    summarise(NO.MONTHS = n_distinct(MONTH)) %>% 
    filter(NO.MONTHS >= 8) %>% 
    arrange(desc(NO.MONTHS)) %>% 
    ungroup()
  
  # random selection 
  a <- eBoY_r %>% 
    # removing category winners
    anti_join(yc_cat_w) %>% 
    filter(FULL.NAME != "MetalClicks Ajay Ashok") # removes NAs too
  set.seed(6)
  eBoY_w <- a %>% slice_sample(n = 1) %>% select(FULL.NAME)
  print(glue("eBirder of the Year winner is {eBoY_w}"))

  
}

###### saving results into excel sheet ####

if (cur_month_num == 1 & exists("data_yc")) {
  
  write_xlsx(x = list("Yearly stats" = stats, 
                      "Prolific results" = prolific_r, 
                      "Prolific winner" = prolific_w, 
                      "Consistent results" = consistent_r, 
                      "Consistent winner" = consistent_w, 
                      "Adventurous results" = adventurous_r, 
                      "Adventurous winner" = adventurous_w, 
                      "Faithful results" = faithful_r, 
                      "Faithful winner" = faithful_w, 
                      "Dedicated results" = dedicated_r, 
                      "Dedicated winner" = dedicated_w, 
                      "eBoY results" = eBoY_r, 
                      "eBoY winner" = eBoY_w),
             path = ycresultspath)
  
}