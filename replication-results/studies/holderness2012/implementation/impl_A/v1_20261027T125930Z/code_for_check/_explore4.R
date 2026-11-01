suppressMessages({library(data.table); library(nanoparquet)})
setwd("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_im_yDw0Vg")

# ---- Thrift compact protocol walker to strip STRING annotations from BYTE_ARRAY leaves ----
read_varint <- function(b, pos) {  # returns list(value, pos_after)
  val <- 0; shift <- 0
  repeat {
    byte <- as.integer(b[pos]); pos <- pos + 1
    val <- val + bitwAnd(byte, 127L) * 2^shift
    shift <- shift + 7
    if (byte < 128) break
  }
  list(val = val, pos = pos)
}
zigzag <- function(u) if (u %% 2 == 0) u / 2 else -(u + 1) / 2
skip_value <- function(b, pos, type) {
  if (type %in% c(1L, 2L)) return(pos)
  if (type == 3L) return(pos + 1)
  if (type %in% c(4L, 5L, 6L)) return(read_varint(b, pos)$pos)
  if (type == 7L) return(pos + 8)
  if (type == 8L) { v <- read_varint(b, pos); return(v$pos + v$val) }
  if (type %in% c(9L, 10L)) {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    size <- bitwShiftR(hdr, 4); etype <- bitwAnd(hdr, 15L)
    if (size == 15L) { v <- read_varint(b, pos); size <- v$val; pos <- v$pos }
    for (i in seq_len(size)) pos <- skip_value(b, pos, etype)
    return(pos)
  }
  if (type == 11L) {
    v <- read_varint(b, pos); size <- v$val; pos <- v$pos
    if (size > 0) {
      kv <- as.integer(b[pos]); pos <- pos + 1
      kt <- bitwShiftR(kv, 4); vt <- bitwAnd(kv, 15L)
      for (i in seq_len(size)) { pos <- skip_value(b, pos, kt); pos <- skip_value(b, pos, vt) }
    }
    return(pos)
  }
  if (type == 12L) return(skip_struct(b, pos))
  stop("unknown thrift type ", type)
}
skip_struct <- function(b, pos) {
  last_id <- 0L
  repeat {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) return(pos)
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- read_varint(b, pos); pos <- v$pos; fid <- v$val } else fid <- last_id + delta
    last_id <- fid
    pos <- skip_value(b, pos, type)
  }
}
# Walk a SchemaElement struct; return patch instructions
patch_schema_element <- function(b, pos) {
  last_id <- 0L; start <- pos
  info <- list(type = NA, conv_hdr_pos = NA, conv_val = NA, conv_hdr = NA, lt_hdr_pos = NA, lt_hdr = NA, lt_is_string = NA, fields = integer(0), name = NA)
  repeat {
    hdr_pos <- pos
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- read_varint(b, pos); pos <- v$pos; fid <- v$val } else fid <- last_id + delta
    last_id <- fid
    info$fields <- c(info$fields, fid)
    if (fid == 1L) { v <- read_varint(b, pos); info$type <- zigzag(v$val) }
    if (fid == 4L) { v <- read_varint(b, pos); info$name <- rawToChar(b[v$pos:(v$pos + v$val - 1)]) }
    if (fid == 6L) { v <- read_varint(b, pos); info$conv_val <- zigzag(v$val); info$conv_hdr_pos <- hdr_pos; info$conv_hdr <- hdr; info$conv_delta <- delta }
    if (fid == 10L) {
      info$lt_hdr_pos <- hdr_pos; info$lt_hdr <- hdr; info$lt_delta <- delta
      # LogicalType union: first field header byte tells which member
      m <- as.integer(b[pos]); info$lt_is_string <- (m == 0x1CL)  # field 1 (STRING), type struct
    }
    pos <- skip_value(b, pos, type)
  }
  info$end <- pos
  info
}
patch_parquet_strings <- function(src, dst) {
  sz <- file.size(src)
  con <- file(src, "rb"); on.exit(close(con))
  seek(con, sz - 8); tail <- readBin(con, "raw", 8)
  if (rawToChar(tail[5:8]) != "PAR1") stop("not a parquet file")
  flen <- sum(as.integer(tail[1:4]) * 256^(0:3))
  fstart <- sz - 8 - flen  # 0-based offset of footer
  seek(con, fstart); b <- readBin(con, "raw", flen)
  # FileMetaData struct
  pos <- 1; last_id <- 0L; patches <- list(); names_patched <- character(0)
  repeat {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- read_varint(b, pos); pos <- v$pos; fid <- v$val } else fid <- last_id + delta
    last_id <- fid
    if (fid == 2L) {  # schema list
      lh <- as.integer(b[pos]); pos <- pos + 1
      size <- bitwShiftR(lh, 4); etype <- bitwAnd(lh, 15L)
      if (size == 15L) { v <- read_varint(b, pos); size <- v$val; pos <- v$pos }
      stopifnot(etype == 12L)
      for (i in seq_len(size)) {
        info <- patch_schema_element(b, pos)
        cat("elem", i, info$name, "type", info$type, "fields", info$fields, "conv", info$conv_val, "\n")
        if (!is.na(info$type) && info$type == 6 && !is.na(info$conv_hdr_pos) && info$conv_val == 0) {
          # Leaf BYTE_ARRAY with converted_type UTF8. Require field layout 1,3,4,6,(10)
          stopifnot(identical(info$fields, c(1L, 3L, 4L, 6L)) || identical(info$fields, c(1L, 3L, 4L, 6L, 10L)))
          stopifnot(info$conv_delta == 2L)
          # converted_type (id 6, delta 2 from name) -> relabel as scale (id 7, delta 3, value 0: harmless)
          patches[[length(patches) + 1]] <- list(pos = info$conv_hdr_pos, byte = as.raw(0x35))
          if (!is.na(info$lt_hdr_pos)) {
            stopifnot(info$lt_delta == 4L, isTRUE(info$lt_is_string))
            # logicalType (id 10, delta 4 from 6) now resolves to id 11 relative to 7 -> unknown field, skipped
          }
          names_patched <- c(names_patched, info$name)
        }
        pos <- info$end
      }
    } else {
      pos <- skip_value(b, pos, type)
    }
  }
  file.copy(src, dst, overwrite = TRUE)
  out <- file(dst, "r+b")
  for (p in patches) { seek(out, fstart + p$pos - 1, rw = "write"); writeBin(p$byte, out) }
  close(out)
  names_patched
}

t0 <- Sys.time()
tmp <- tempfile(fileext = ".parquet")
np <- patch_parquet_strings("data/pow.parquet", tmp)
cat("patched:", np, "\n")
sch <- as.data.frame(read_parquet_schema(tmp)); print(sch[1:6, c("name","type","logical_type","converted_type","r_type")])
x <- read_parquet(tmp, col_select = c("record_seq","SERIAL_NO","CAMP","STA"), options = parquet_options(use_arrow_metadata = FALSE, class = "data.frame"))
cat("read ok; classes:\n"); print(sapply(x, class)); print(x$SERIAL_NO[1:3]); print(table(lengths(x$CAMP)))
cat("nulls (NULL entries):", sum(vapply(x$CAMP, is.null, TRUE)), "\n")
raw_to_chr <- function(x) {
  lens <- lengths(x)
  r <- unlist(x, use.names = FALSE)
  if (is.null(r)) r <- raw(0)
  r[r == as.raw(0)] <- as.raw(0x20)
  r[r > as.raw(0x7f)] <- as.raw(0x3f)
  s <- rawToChar(r)
  ends <- cumsum(lens); starts <- ends - lens + 1
  substring(s, starts, ends)
}
camp <- raw_to_chr(x$CAMP); print(head(camp)); print(table(nchar(camp)))
ser <- raw_to_chr(x$SERIAL_NO); print(head(ser, 20))
cat("time:", format(Sys.time() - t0), "\n")
print(table(trimws(camp))[1:10])
