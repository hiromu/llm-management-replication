suppressMessages({library(data.table); library(nanoparquet)})
setwd("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_im_yDw0Vg")
cat("exports has read_parquet_row_group:", "read_parquet_row_group" %in% getNamespaceExports("nanoparquet"), "\n")
cat("edit_parquet_metadata args:\n"); print(args(nanoparquet:::edit_parquet_metadata))
cat("read_parquet_row_group args:\n"); print(args(nanoparquet:::read_parquet_row_group))
cat("read_parquet_column_chunk args:\n"); print(args(nanoparquet:::read_parquet_column_chunk))
cols <- read_parquet_schema("data/pow.parquet")$name[-1]
for (cc in cols) {
  r <- tryCatch({x <- read_parquet("data/pow.parquet", col_select = cc); "ok"}, error = function(e) conditionMessage(e))
  cat(sprintf("%-25s %s\n", cc, r))
}
cat("== enl SER_NUM\n")
r <- tryCatch({x <- read_parquet("data/enl.parquet", col_select = "SER_NUM"); cat("ok", nrow(x), "\n"); print(head(x$SER_NUM, 10)); print(table(nchar(x$SER_NUM))); "ok"}, error = function(e) conditionMessage(e))
cat(r, "\n")
