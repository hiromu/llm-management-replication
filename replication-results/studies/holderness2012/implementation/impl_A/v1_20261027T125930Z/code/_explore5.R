suppressMessages({library(data.table); library(nanoparquet)})
setwd("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_im_yDw0Vg")
cols <- c("record_seq","CARD_NUM","HEIGHT","ERC_HEIGHT","YR_BIRTH","ERC_YR_BIRTH","EDUCATION","ERC_EDUCATION","MARITAL_STATUS","ERC_MARITAL_STATUS")
for (cc in cols) {
  t0 <- Sys.time()
  r <- tryCatch({x <- read_parquet("data/enl.parquet", col_select = cc);
    if (cc != "record_seq") { cat(cc, ": "); print(head(sort(table(x[[1]]), decreasing = TRUE), 15)) } else { cat("record_seq range", range(x[[1]]), "\n") }
    "ok"}, error = function(e) conditionMessage(e))
  cat(sprintf("%-20s %s  (%s)\n", cc, r, format(Sys.time() - t0)))
}
