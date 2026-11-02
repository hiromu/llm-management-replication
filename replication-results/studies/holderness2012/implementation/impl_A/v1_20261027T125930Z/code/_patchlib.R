# ---- Thrift compact protocol walker to strip STRING annotations from BYTE_ARRAY leaves ----
read_varint <- function(b, pos) {
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
parse_schema_element <- function(b, pos) {
  last_id <- 0L
  info <- list(type = NA, conv_hdr_pos = NA, conv_val = NA, conv_delta = NA, lt_hdr_pos = NA, lt_delta = NA, lt_is_string = NA, fields = integer(0), name = NA)
  repeat {
    hdr_pos <- pos
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- read_varint(b, pos); pos <- v$pos; fid <- v$val } else fid <- last_id + delta
    last_id <- fid
    info$fields <- c(info$fields, as.integer(fid))
    if (fid == 1L) { v <- read_varint(b, pos); info$type <- zigzag(v$val) }
    if (fid == 4L) { v <- read_varint(b, pos); info$name <- rawToChar(b[v$pos:(v$pos + v$val - 1)]) }
    if (fid == 6L) { v <- read_varint(b, pos); info$conv_val <- zigzag(v$val); info$conv_hdr_pos <- hdr_pos; info$conv_delta <- delta }
    if (fid == 10L) { info$lt_hdr_pos <- hdr_pos; info$lt_delta <- delta; info$lt_is_string <- (as.integer(b[pos]) == 0x1CL) }
    pos <- skip_value(b, pos, type)
  }
  info$end <- pos
  info
}
# Copy src to dst and patch the footer so BYTE_ARRAY/UTF8 leaves lose their STRING annotation
# (converted_type field 6 is relabelled as field 7 = scale, value 0; the following logicalType field
# then resolves to the unknown id 11 and is skipped by readers). The reader then returns raw bytes.
patch_parquet_strings <- function(src, dst) {
  sz <- file.size(src)
  con <- file(src, "rb"); on.exit(close(con))
  seek(con, sz - 8); tl <- readBin(con, "raw", 8)
  if (rawToChar(tl[5:8]) != "PAR1") stop("not a parquet file: ", src)
  flen <- sum(as.integer(tl[1:4]) * 256^(0:3))
  fstart <- sz - 8 - flen
  seek(con, fstart); b <- readBin(con, "raw", flen)
  pos <- 1; last_id <- 0L; patches <- list(); names_patched <- character(0)
  repeat {
    hdr <- as.integer(b[pos]); pos <- pos + 1
    if (hdr == 0L) break
    type <- bitwAnd(hdr, 15L); delta <- bitwShiftR(hdr, 4)
    if (delta == 0L) { v <- read_varint(b, pos); pos <- v$pos; fid <- v$val } else fid <- last_id + delta
    last_id <- fid
    if (fid == 2L) {
      lh <- as.integer(b[pos]); pos <- pos + 1
      size <- bitwShiftR(lh, 4); etype <- bitwAnd(lh, 15L)
      if (size == 15L) { v <- read_varint(b, pos); size <- v$val; pos <- v$pos }
      stopifnot(etype == 12L)
      for (i in seq_len(size)) {
        info <- parse_schema_element(b, pos)
        if (!is.na(info$type) && info$type == 6 && !is.na(info$conv_hdr_pos) && info$conv_val == 0) {
          ok_layout <- identical(info$fields, c(1L, 3L, 4L, 6L)) || identical(info$fields, c(1L, 3L, 4L, 6L, 10L))
          if (!ok_layout || info$conv_delta != 2L || (!is.na(info$lt_hdr_pos) && !(info$lt_delta == 4L && isTRUE(info$lt_is_string))))
            stop("unexpected SchemaElement layout for ", info$name)
          patches[[length(patches) + 1]] <- list(pos = info$conv_hdr_pos, byte = as.raw(0x35))
          names_patched <- c(names_patched, info$name)
        }
        pos <- info$end
      }
    } else {
      pos <- skip_value(b, pos, type)
    }
  }
  if (!file.copy(src, dst, overwrite = TRUE)) stop("could not copy ", src)
  out <- file(dst, "r+b")
  for (p in patches) { seek(out, fstart + p$pos - 1, rw = "write"); writeBin(p$byte, out) }
  close(out)
  invisible(names_patched)
}
# list of raw vectors -> character; NUL -> space (removed later by cleaning), non-ASCII -> '?'
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
