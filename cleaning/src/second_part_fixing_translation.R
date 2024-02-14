source("src/init.R")

## read raw.data

raw.main <- read_excel(strings['filename.data'], sheet = "main", col_types = "text")
raw.hh_roster <- read_excel(strings['filename.data'], sheet = "hh_roster", col_types = "text")
raw.ind_health <- read_excel(strings['filename.data'], sheet = "ind_health", col_types = "text")
raw.water_count_loop <- read_excel(strings['filename.data'], sheet = "water_count_loop", col_types = "text")
raw.child_nutrition <- read_excel(strings['filename.data'], sheet = "child_nutrition", col_types = "text")
raw.women <- read_excel(strings['filename.data'], sheet = "women", col_types = "text")
raw.died_member <- read_excel(strings['filename.data'], sheet = "died_member", col_types = "text")

tool.survey <- read_excel(strings['filename.tool'], sheet = "survey", col_types = "text")
tool.choices <- read_excel(strings['filename.tool'], sheet = "choices", col_types = "text")
label_colname <- load.label_colname(strings['filename.tool'])

##-----------------------------------------------------------------------------
#  Start cleaning of other process

cleaning.log <- data.frame() 

or.request <- load.requests(dir.requests,  "other_requests", sheet = "Sheet2") 
or.edited  <- load.requests(dir.responses, "other_requests",
                            sheet = "Sheet2", validate = T) 



cleaning.log.other <- data.frame()
or.true.and.recode <- filter(or.edited, check == 1)
if (nrow(or.true.and.recode) > 0){
  cat(paste0("Multiple columns selected in ", nrow(or.true.and.recode)," or.edited entries:\n",
             paste0(or.true.and.recode %>% pull(uuid), collapse = "\n")), sep = "\n")
  if(any(or.true.and.recode$ref.type != "select_multiple")) stop("One of those is not a select_multiple!!!")
  # if(any(!is.na(or.true.and.recode$loop_index))) stop("Deal with loop code INSTEAD of UUID-LOOP-INDEX")
  issue <- "Recoding other response"
  for(r in 1:nrow(or.true.and.recode)){
    x <- or.true.and.recode[r,]
    # get list of choices from other response
    if (str_detect(x$existing.v, ";")) {
      choices <- str_trim(str_split(x$existing.v, ";")[[1]])
    } else {
      choices <- str_trim(str_split(x$existing.v, "\r\n")[[1]])
    }
    choices <- choices[choices!=""]
    if(is.na(x$loop_index)){
      old.value <- as.character(raw.main[raw.main$uuid==x$uuid[1], x$ref.name[1]])
    } else if(str_starts(x$loop_index,"loop_hh_roster")) {
      old.value <- as.character(raw.hh_roster[raw.hh_roster$loop_index==x$loop_index[1], x$ref.name[1]])
    } else if(str_starts(x$loop_index,"loop_ind_health")) {
      old.value <- as.character(raw.ind_health[raw.ind_health$loop_index==x$loop_index[1], x$ref.name[1]])
    } else if(str_starts(x$loop_index,"loop_child_nutrition")) {
      old.value <- as.character(raw.child_nutrition[raw.child_nutrition$loop_index==x$loop_index[1], x$ref.name[1]])
    } else {
      old.value <- as.character(raw.died_member[raw.died_member$loop_index==x$loop_index[1], x$ref.name[1]])
    }
    
    l <- str_split(old.value, " ")[[1]]
    # add to the cleaning log each choice in the other response
    for (choice in choices){
      # set corresponding variable to "1" if not already "1"
      list.name <- get.choice.list.from.name(x$ref.name)
      new.code <- filter(tool.choices, list_name==list.name & !!sym(label_colname)==choice)
      if (nrow(new.code)!=1){
        warning(paste0("Choice is not in the list. UUID: ", x$uuid,"; recode.into: ", choice))
        return("err")
      }
      variable.name <- paste0(x$ref.name, "/", new.code$name)
      if(is.na(x$loop_index)){
        if (variable.name %in% colnames(raw.main)){
          old.boolean <- raw.main[[variable.name]][raw.main$uuid==x$uuid[1]]
        } else warning("Column not found")
      } else if(str_starts(x$loop_index,"loop_hh_roster")) {
        if (variable.name %in% colnames(raw.hh_roster)){
          old.boolean <- raw.hh_roster[[variable.name]][raw.hh_roster$loop_index==x$loop_index[1]]
        } else warning("Column not found")
      } else if(str_starts(x$loop_index,"loop_ind_health")) {
        if (variable.name %in% colnames(raw.ind_health)){
          old.boolean <- raw.ind_health[[variable.name]][raw.ind_health$loop_index==x$loop_index[1]]
        } else warning("Column not found")
      } else if(str_starts(x$loop_index,"loop_child_nutrition")) {
        if (variable.name %in% colnames(raw.child_nutrition)){
          old.boolean <- raw.child_nutrition[[variable.name]][raw.child_nutrition$loop_index==x$loop_index[1]]
        } else warning("Column not found")
      } else {
        if (variable.name %in% colnames(raw.died_member)){
          old.boolean <- raw.died_member[[variable.name]][raw.died_member$loop_index==x$loop_index[1]]
        } else warning("Column not found")
      }
      df <- data.frame(uuid=x$uuid, loop_index=x$loop_index, variable=variable.name, issue=issue,
                       old.value=old.boolean, new.value="1")
      cleaning.log.other <<- rbind(cleaning.log.other, df)
      l <- unique(c(l, new.code$name))
    }
    # update cumulative variable
    new.value <- paste(sort(l), collapse=" ")
    df <- data.frame(uuid=x$uuid, loop_index=x$loop_index, variable=x$ref.name, issue=issue,
                     old.value=old.value, new.value=new.value)
    cleaning.log.other <<- rbind(cleaning.log.other, df)
  }
  or.edited <- or.edited %>% filter(check == 2)
}

or.true <- filter(or.edited, !is.na(true.v))
or.recode <- filter(or.edited, !is.na(existing.v))
or.remove <- filter(or.edited, !is.na(invalid.v))



# 1) handle invalid
print(paste("Number of responses to be deleted:", nrow(or.remove)))
if (nrow(or.remove)>0){
  for (r in 1:nrow(or.remove)) {
    if(is.na(or.remove$loop_index[r])){
      add.to.cleaning.log.other.remove.LOOP(raw.main, or.remove[r,])
    } else if(str_starts(or.remove$loop_index[r], "loop_hh_roster")){
      add.to.cleaning.log.other.remove.LOOP(raw.hh_roster, or.remove[r,])
    } else if(str_starts(or.remove$loop_index[r], "loop_ind_health")){
      add.to.cleaning.log.other.remove.LOOP(raw.ind_health, or.remove[r,])
    } else if(str_starts(or.remove$loop_index[r], "loop_child_nutrition")){
      add.to.cleaning.log.other.remove.LOOP(raw.child_nutrition, or.remove[r,])
    } else {
      add.to.cleaning.log.other.remove.LOOP(raw.died_member, or.remove[r,])
    }
  }
} 


# 2) handle recoding
print(paste("Number of responses to be recoded:", nrow(or.recode)))
if (nrow(or.recode)>0){
  for (r in 1:nrow(or.recode)) {
    if(is.na(or.recode$loop_index[r])){
      add.to.cleaning.log.other.recode.LOOP(raw.main, or.recode[r,])
    } else if(str_starts(or.recode$loop_index[r], "loop_hh_roster")){
      add.to.cleaning.log.other.recode.LOOP(raw.hh_roster, or.recode[r,])
    } else if(str_starts(or.recode$loop_index[r], "loop_ind_health")){
      add.to.cleaning.log.other.recode.LOOP(raw.ind_health, or.recode[r,])
    } else if(str_starts(or.recode$loop_index[r], "loop_child_nutrition")){
      add.to.cleaning.log.other.recode.LOOP(raw.child_nutrition, or.recode[r,])
    } else{
      add.to.cleaning.log.other.recode.LOOP(raw.died_member, or.recode[r,])
    }
  }
}


# 3) handle true\
or.true <- rbind(or.true, or.true.and.recode)
response.col <- colnames(or.true)[str_detect(colnames(or.true), "response.\\S{2}.")]
print(paste("Number of responses to be translated:", nrow(or.true)))
t <- or.true %>%
  mutate(issue = "Translating other responses") %>%
  rename(variable=name, old.value=response.col, new.value=true.v) %>%
  select(uuid,loop_index, variable,issue, old.value, new.value)
cleaning.log.other <- rbind(cleaning.log.other, t)


## if you have more sheets use the following format


raw.main <- raw.main %>% 
  apply.changes(cleaning.log.other)

raw.hh_roster <- raw.hh_roster %>% 
  apply.changes(cleaning.log.other, is.loop = T)

raw.ind_health <- raw.ind_health %>% 
  apply.changes(cleaning.log.other, is.loop = T)

raw.child_nutrition <- raw.child_nutrition %>% 
  apply.changes(cleaning.log.other, is.loop = T)

raw.died_member <- raw.died_member %>% 
  apply.changes(cleaning.log.other, is.loop = T)


cleaning.log <- bind_rows(cleaning.log, cleaning.log.other) 


##-----------------------------------------------------------------------------
#  Start cleaning of translation process

## TRANSLATION SECTION (RUN THIS SECTION ONCE TRANSLATION IS BACK)
trans <- load.requests(dir.responses,  "translate_requests", sheet = "Sheet2") 
colnames(trans)[str_starts(colnames(trans), "true.v")] <- "true.trans"
colnames(trans)[str_starts(colnames(trans), "invalid.v")] <- "invalid.trans"
trans$check <- rowSums(is.na(select(trans, true.trans, invalid.trans)))
t.trans <- filter(trans, check!=1)
if (nrow(t.trans)>0) stop("Missing entries or multiple columns selected")
trans.true <- filter(trans, !is.na(true.trans))
trans.remove <- filter(trans, !is.na(invalid.trans))
# if (nrow(bind_rows(trans.true, trans.recode, trans.remove))!=nrow(trans)) stop()

cleaning.log.trans <- data.frame()

# 1) handle invalid
print(paste("Number of responses to be deleted:", nrow(trans.remove)))
if (nrow(trans.remove)>0){
  for (r in 1:nrow(trans.remove)) {
    add.to.cleaning.log.trans.remove.LOOP(raw.died_member, trans.remove[r,])
  }
} 

# 3) handle true
print(paste("Number of responses to be translated:", nrow(trans.true)))
response.col <- colnames(trans.true)[str_detect(colnames(trans.true), "response.\\S{2}.")]
t.trans <- trans.true %>%
  mutate(issue = "Translating text responses") %>%
  rename(variable=name, old.value=response.col, new.value=true.trans) %>%
  select(uuid, loop_index, variable,issue, old.value, new.value)
cleaning.log.trans <- rbind(cleaning.log.trans, t.trans)


raw.died_member <- raw.died_member %>% 
  apply.changes(cleaning.log.trans, is.loop = T)

#BIND TO CLEANING LOG
cleaning.log <- rbind(cleaning.log, cleaning.log.trans)

## Finish the translation of both of the Other and the translation

sheets <- list("main" = raw.main,
               "hh_roster" = raw.hh_roster,
               "ind_health" = raw.ind_health,
               "water_count_loop" = raw.water_count_loop,
               "child_nutrition" = raw.child_nutrition,
               "women" = raw.women ,
               "died_member" = raw.died_member)

writexl::write_xlsx(sheets, paste0("output/data_log/data/", strings['dataset.name.short'],"_data_translation_part_done.xlsx"))
write_xlsx(cleaning.log,"output/data_log/cleaning/cleaning.translation.log.xlsx")
svDialogs::dlg_message("Fixing the recoding of the others and the translations is done. Next step is running logical checks.", type = "ok")