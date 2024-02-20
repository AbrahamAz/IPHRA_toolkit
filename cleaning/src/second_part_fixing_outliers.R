source("src/init.R")

#-------------------------------------------------------------------------------
# Recoding and changing data after outliers follow ups

# RUN ONLY IF Anything need to be changed

outlier.recode <- load.requests(dir.responses, "outliers", sheet = "Sheet2")
outlier.check <- load.requests(dir.requests, "outliers", sheet = "Sheet2")

if (nrow(outlier.check) != nrow(outlier.recode)) warning("Number of rows are not matching")

cleaning.log.outliers <- outlier.recode %>%
  select(uuid,loop_index,variable,issue,old.value,new.value) %>%
  filter(is.na(new.value) | old.value != new.value)

raw.main <- raw.main %>% 
  apply.changes(cleaning.log.outliers)

raw.water_count_loop <- raw.water_count_loop %>% 
  apply.changes(cleaning.log.outliers, is.loop = T)


raw.child_nutrition <- raw.child_nutrition %>% 
  apply.changes(cleaning.log.outliers, is.loop = T)
  

if(!is.null(raw.women)){
  raw.women <- raw.women %>% 
    apply.changes(cleaning.log.outliers, is.loop = T)
}

if(!is.null(raw.died_member)){
  raw.died_member <- raw.died_member %>% 
    apply.changes(cleaning.log.outliers, is.loop = T)
}

save.image("output/data_log/final_outliers.RData")
svDialogs::dlg_message("All deletions/changes/checks were done. Please proceed to the last part to finalize and package your whole cleaning files.", type = "ok")