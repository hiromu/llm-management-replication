# test_coding.R -- hand-built rows for every coding rule and axis level.
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), "helpers.R"))
suppressPackageStartupMessages(library(jsonlite))

data_dir <- file.path(tests_dir, "..", "..", "data")
mis <- parse_metadata(fromJSON(file.path(data_dir, "survey_metadata.json"), simplifyVector = FALSE))
cwp <- parse_crosswalk(read.csv(file.path(data_dir, "industry_crosswalk.csv"), colClasses = "character"))

ORIGIN <- list(records = "L0", market_sample = "L0", market_requires_pop = "L0", case_scope = "L0",
               item_rule = "L0", staff_coding = "L0", z_reference = "L0", train_log = "L0",
               no_training = "L0", decision_map = "L0", union_items = "L0", subsidiary = "L0",
               age = "L0", hierarchy = "L0", employment = "L0", pct_managers = "L0",
               competition = "L0", neither = "L0", industry = "L0", weights = "L0", centering = "L0")
S <- function(...) { s <- ORIGIN; o <- list(...); for (k in names(o)) s[[k]] <- o[[k]]; s }

# A fully valid default record; override fields per test.
base_row <- function(...) {
  r <- list(V1 = 1, V3 = 1, V8 = 1, V9 = 4, V16 = 1981, V17 = 2, V21 = NA, V23 = 20, V32 = 5, NEWTOTAL = 25,
            V41 = 1, V43 = 10, V62 = 10, V97 = 20, V131 = 30, V67 = 1, V76 = 2, V102 = 1, V111 = 2, V136 = 1,
            V79 = 1, V114 = 1, V115 = 5, V145 = 1, V157 = 50, V172 = 1, V166 = NA, V209 = 1, V222 = 2, V235 = 3,
            V220 = 1, V233 = 3, V300 = 2, V261 = 5, V270 = 1, V328 = 4, WEIGHT = 1.5)
  for (j in 1:8) { r[[paste0("V", 270 + j)]] <- NA; r[[paste0("V", 278 + j)]] <- 1 }
  for (j in 289:299) r[[paste0("V", j)]] <- 2
  o <- list(...); for (k in names(o)) r[[k]] <- o[[k]]
  r
}
rows <- function(...) { lst <- list(...); d <- do.call(rbind, lapply(lst, function(r) as.data.frame(r))); d$V1 <- seq_len(nrow(d)); d }
bf <- function(d, s = ORIGIN, check = NULL) build_frame(d, s, mis, cwp, check)

# ---------------- general helpers ----------------
check_equal(reverse_item(c(1, 2, 3, 4, 0, 5, NA), 4), c(4, 3, 2, 1, NA, NA, NA), "reverse_item 1..4 (out of range -> NA)")
check_equal(make_index(rbind(c(1, NA, 3), c(NA, NA, NA), c(2, 2, 2)), "L0"), c(2, NA, 2), "index L0: mean of valid, >=1 valid")
check_equal(make_index(rbind(c(1, NA, 3), c(NA, NA, NA), c(2, 2, 2)), "L1"), c(NA, NA, 2), "index L1: all items required")
check_equal(make_index(rbind(c(1, NA, 3), c(2, 2, 2)), "L2"), c(2, 2), "index L2: as L0 after copy")
check_equal(safe_log(c(1, exp(1), 0, -1, NA)), c(0, 1, NA, NA, NA), "safe_log: <= 0 is missing")
check_equal(apply_missing(c(1, 2, 7, 8, 9), "V289", mis), c(1, 2, NA, NA, NA), "declared missing codes 7/8/9 applied from metadata")
check_equal(apply_missing(c(1, 995, 997, 998, 999), "V62", mis, keep = 995, extra = 997), c(1, 995, NA, NA, NA), "keep/extra codes override")
check_equal(apply_missing(c(0, 1.5), "WEIGHT", mis), c(NA, 1.5), "WEIGHT declared missing 0")

# ---------------- POP / PMP ----------------
d <- rows(base_row(V289 = 1, V290 = 2, V291 = 3, V292 = 4, V293 = 7, V294 = 8, V295 = 9),
          base_row(V289 = 7, V290 = 7, V291 = 7, V292 = 7, V293 = 7, V294 = 8, V295 = 9),
          base_row(V296 = 1, V297 = 4, V298 = 7, V299 = 9))
check_equal(bf(d)$POP, c(2.5, NA, 3), "POP: reversed items, L0 mean of valid, all-missing -> NA")
check_equal(bf(d, S(item_rule = "L1"))$POP, c(NA, NA, 3), "POP: item_rule L1 requires all seven")
check_equal(bf(d)$PMP[3], 2.5, "PMP: reversed 4 items, mean of valid")
check_equal(bf(d, S(item_rule = "L1"))$PMP[3], NA, "PMP: L1 all four required")

# ---------------- STAFF coding ----------------
d <- rows(base_row(V62 = 10, V97 = 0, V131 = 995), base_row(V62 = 997, V97 = 998, V131 = 999), base_row(V62 = 1, V97 = 2, V131 = 3))
f0 <- bf(d, S(staff_coding = "L0")); f1 <- bf(d, S(staff_coding = "L1")); f2 <- bf(d, S(staff_coding = "L2"))
check_equal(c(f0$staff_i1[1], f0$staff_i2[1], f0$staff_i3[1]), c(log(10), NA, NA), "STAFF L0: ln(x) for x>=1; 0 and 995 missing")
check_equal(c(f1$staff_i1[1], f1$staff_i2[1], f1$staff_i3[1]), c(log(11), 0, NA), "STAFF L1: ln(1+x) for x>=0; 995 missing")
check_equal(c(f2$staff_i1[1], f2$staff_i2[1], f2$staff_i3[1]), c(log(10), NA, log(995)), "STAFF L2: as L0 but 995 kept as ln 995")
check(all(is.na(c(f0$staff_i1[2], f0$staff_i2[2], f0$staff_i3[2], f1$staff_i1[2], f2$staff_i1[2]))), "STAFF: 997/998/999 missing under all levels")
check_equal(c(f0$staff_i1[3], f0$staff_i2[3], f0$staff_i3[3]), log(1:3), "STAFF: counts logged")
# standard scores and index (sample SD, L0 reference)
fz <- add_z_indices(f0, "L0")
v <- f0$staff_i1; z <- (v - mean(v, na.rm = TRUE)) / sd(v, na.rm = TRUE)
check_equal(fz$staff_z1, z, "z-score: sample SD over valid rows of frame")
check_equal(fz$STAFF, rowMeans(cbind(fz$staff_z1, fz$staff_z2, fz$staff_z3), na.rm = TRUE), "STAFF = mean of valid z-scores")
fz3 <- add_z_indices(f0, "L0", NULL, pop_sd = TRUE)
zp <- (v - mean(v, na.rm = TRUE)) / (sd(v, na.rm = TRUE) * sqrt(1 / 2))  # n=2 valid: pop sd = sample sd * sqrt((n-1)/n)
check_equal(fz3$staff_z1, zp, "z_reference L3: population SD (n)")
# reference-sample standardization: rows outside keep L0 values
f4 <- rbind(f0, f0); f4$staff_i1 <- c(1, 2, 3, 4, 5, 6)
ref <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
fr <- add_z_indices(f4, "L0", ref)
check_equal(fr$staff_z1[1:3], (1:3 - 2) / 1, "z within reference sample uses reference mean/SD")
check_equal(fr$staff_z1[4:6], add_z_indices(f4, "L0")$staff_z1[4:6], "rows outside the reference sample keep L0 values")
check_equal(add_z_indices(f0, "L1")$STAFF, c(NA, NA, NA), "STAFF under item_rule L1: items with < 2 valid values give NA z-scores, so the index is NA")
f5 <- rbind(f0, f0, f0)[1:6, ]; f5$staff_i1 <- 1:6; f5$staff_i2 <- c(2, 4, NA, 8, 10, 12); f5$staff_i3 <- c(1, NA, NA, 1, 2, 3)
z5 <- add_z_indices(f5, "L1")
check_equal(z5$STAFF, ifelse(c(TRUE, FALSE, FALSE, TRUE, TRUE, TRUE), rowMeans(cbind(z5$staff_z1, z5$staff_z2, z5$staff_z3)), NA), "STAFF under item_rule L1 requires all three z-scores")
check_equal(add_z_indices(f5, "L0")$STAFF, rowMeans(cbind(z5$staff_z1, z5$staff_z2, z5$staff_z3), na.rm = TRUE), "STAFF under item_rule L0 averages the valid z-scores")

# ---------------- TRAIN ----------------
d <- rows(base_row(V145 = 1, V157 = 99996, V172 = 1),   # yes, top code, highly effective
          base_row(V145 = 1, V157 = 0, V172 = 4),       # yes, zero participants, "varies"
          base_row(V145 = 2, V157 = NA, V172 = NA),     # no training (skipped)
          base_row(V145 = 1, V157 = 99998, V172 = 3))
f <- bf(d)
check_equal(c(f$train_i1[1], f$train_i2[1], f$train_i3[1]), c(log(2), log(100000), log(3)), "TRAIN L0: yes=2, 99996->100000, reversed effectiveness, all logged")
check_equal(c(f$train_i2[2], f$train_i3[2]), c(NA, NA), "TRAIN: V157=0 missing under ln(x) rule; V172=4 missing")
check_equal(c(f$train_i1[3], f$train_i2[3], f$train_i3[3]), c(0, NA, NA), "no_training L0: V157 and V172 missing for V145=no (V145 logged = ln 1 = 0)")
check_equal(f$train_i2[4], NA, "V157 declared missing 99998")
check_equal(f$train_i3[4], log(1), "V172=3 reversed to 1")
f <- bf(d, S(no_training = "L1"))
check_equal(c(f$train_i1[3], f$train_i2[3], f$train_i3[3]), c(0, 0, 0), "no_training L1: V157=0 -> ln(1+0)=0, V172=1 -> ln 1 = 0")
check_equal(f$train_i2[2], 0, "no_training L1: ln(1+x) applies to all rows (V157=0 for a yes row -> 0)")
check_equal(f$train_i2[1], log1p(100000), "no_training L1: ln(1+x) on top code")
f <- bf(d, S(no_training = "L2"))
check_equal(c(f$train_i1[3], f$train_i2[3], f$train_i3[3]), c(0, 0, NA), "no_training L2: V157=0, V172 missing")
f <- bf(d, S(train_log = "L1"))
check_equal(c(f$train_i1[1], f$train_i2[1], f$train_i3[1]), c(2, log(100000), 3), "train_log L1: only V157 logged")
f <- bf(d, S(train_log = "L2"))
check_equal(c(f$train_i1[1], f$train_i2[1], f$train_i3[1]), c(2, 100000, 3), "train_log L2: no logs")
f <- bf(d, S(train_log = "L2", no_training = "L1"))
check_equal(c(f$train_i1[3], f$train_i2[3], f$train_i3[3]), c(1, 0, 1), "train_log L2 + no_training L1: raw 1, 0, 1")

# ---------------- INCENT / GRIEV / ILM ----------------
d <- rows(base_row(V209 = 1, V222 = 2, V235 = 3), base_row(V209 = 7, V222 = 8, V235 = 2), base_row(V209 = 9, V222 = 9, V235 = 7))
check_equal(bf(d)$INCENT, c(2, 2, NA), "INCENT: reversed 4-x, mean of valid; 7/8/9 missing")
check_equal(bf(d, S(item_rule = "L1"))$INCENT, c(2, NA, NA), "INCENT: L1 all three required")
d <- rows(base_row(V270 = 1), base_row(V270 = 2), base_row(V270 = 7), base_row(V270 = 9))
check_equal(bf(d)$GRIEV, c(1, 0, NA, NA), "GRIEV: yes=1, no=0, 7/9 missing")
d <- rows(base_row(V67 = 1, V76 = 1, V102 = 2, V111 = 2, V136 = 9), base_row(V67 = 2, V76 = 2, V102 = 2, V111 = 2, V136 = 2))
check_equal(bf(d)$ILM, c(1.5, 1), "ILM: 3-x (yes=2), 9 missing, mean of valid")
check_equal(bf(d, S(item_rule = "L1"))$ILM, c(NA, 1), "ILM: L1 all five required")

# ---------------- DECENT ----------------
dec1 <- base_row(V17 = 1); for (j in 1:8) dec1[[paste0("V", 270 + j)]] <- c(1, 2, 3, 4, 5, 6, 7, 9)[j]
dec2 <- base_row(V17 = 2); for (j in 1:8) { dec2[[paste0("V", 278 + j)]] <- c(3, 3, 5, 1, 2, 4, 6, 8)[j]; dec2[[paste0("V", 270 + j)]] <- 1 }
d <- rows(dec1, dec2)
f <- bf(d, S(decision_map = "L0"))
check_equal(f$DECENT[1], mean(c(3, 5, 1, 4, 2)), "DECENT L0 map (3->1,5->2,1->3,4->4,2->5) on V271-V278 when V17==1; 6/7/9 missing")
check_equal(f$DECENT[2], mean(c(1, 1, 2, 3, 5, 4)), "DECENT uses V279-V286 when V17==2")
f <- bf(d, S(decision_map = "L1"))
check_equal(f$DECENT[1], mean(c(1, 5, 3, 4, 2)), "DECENT L1 map (1->1,5->2,3->3,4->4,2->5)")
check_equal(bf(d, S(item_rule = "L1"))$DECENT, c(NA, NA), "DECENT: L1 all eight required")
check_equal(bf(rows(base_row(V17 = NA)))$DECENT, NA, "DECENT missing when V17 missing")

# ---------------- Copy rule (item_rule L2) ----------------
d <- rows(base_row(V79 = 2, V62 = 10, V97 = 50, V67 = 1, V102 = 2, V76 = 2, V111 = 1, V222 = 1, V235 = 3),   # GSS = CORE
          base_row(V79 = NA, V62 = 10, V97 = 50),                                                        # sysmis V79, CORE valid
          base_row(V79 = NA, V62 = 999, V97 = 50),                                                       # sysmis V79, CORE missing
          base_row(V79 = 1, V62 = 10, V97 = 50),                                                         # no copy
          base_row(V79 = 2, V62 = 999, V97 = 50))                                                        # V79==2, CORE missing
f2 <- bf(d, S(item_rule = "L2")); f0 <- bf(d, S(item_rule = "L0"))
check_equal(f2$staff_i2, c(log(10), log(10), log(50), log(50), NA), "copy rule: V97 <- V62 when V79==2 or (V79 sysmis & CORE valid); copied NA when V79==2 and CORE missing")
check_equal(f0$staff_i2, rep(log(50), 5), "no copy under item_rule L0")
check_equal(f2$ILM[1], mean(c(2, 1, 2, 1, 2)), "copy rule: V102 <- V67, V111 <- V76 (ILM)")
check_equal(f2$INCENT[1], mean(c(3, 3, 3)), "copy rule: V235 <- V222 (INCENT), V209 untouched when V114==1")
d <- rows(base_row(V114 = 2, V62 = 10, V97 = 50, V131 = 70, V67 = 1, V102 = 2, V136 = 2, V222 = 1, V235 = 3, V209 = 3),
          base_row(V114 = 2, V62 = 999, V97 = 50, V131 = 70, V67 = 9, V102 = 2, V136 = 1, V222 = 9, V235 = 3, V209 = 1),
          base_row(V114 = NA, V62 = 10, V131 = 70),
          base_row(V114 = 1, V62 = 10, V131 = 70))
f2 <- bf(d, S(item_rule = "L2"))
check_equal(f2$staff_i3, c(log(10), log(50), log(10), log(70)), "manager copy: V131 <- V62, or V97 when V62 missing; V114==2 or sysmis")
check_equal(f2$ILM[1:2], c(mean(c(2, 1, 1, 1, 2)), mean(c(NA, 1, 1, 1, 1), na.rm = TRUE)), "manager copy: V136 <- V67 / V102")
check_equal(f2$INCENT[1:2], c(mean(c(3, 3, 1)), mean(c(1, 1))), "manager copy: V209 <- V222 / V235")
# manager copy uses the GSS value after the GSS copy
d <- rows(base_row(V79 = 2, V114 = 2, V62 = 999, V97 = 50, V131 = 70))
check_equal(bf(d, S(item_rule = "L2"))$staff_i3, NA, "manager copy sees GSS item after GSS copy (CORE missing -> GSS copied NA -> manager NA)")

# ---------------- A7: validity used by the copy rule ----------------
# A source item is valid only after every exclusion at the current axis level.
d <- rows(base_row(V79 = NA, V62 = 0,   V97 = 20),    # CORE 0: invalid under L0 -> no GSS=CORE flag, V97 keeps 20
          base_row(V79 = 2,  V62 = 0,   V97 = 20),    # V79 == 2: copy anyway -> V97 gets the invalid 0 -> missing
          base_row(V79 = NA, V62 = 995, V97 = 20),    # 995 invalid under L0, valid under L2
          base_row(V79 = NA, V62 = 998, V97 = 20),    # declared missing: never valid
          base_row(V79 = NA, V62 = 996, V97 = 20),    # 996 is missing at every level (A9)
          base_row(V79 = NA, V62 = 5,   V97 = 20))    # valid CORE -> copied
f0 <- bf(d, S(item_rule = "L2", staff_coding = "L0"))
check_equal(f0$staff_i2, c(log(20), NA, log(20), log(20), log(20), log(5)), "A7 (staff L0): CORE 0/995/998/996 are not valid sources, so V79-sysmis rows keep their own V97; V79==2 copies the invalid value (missing)")
f1 <- bf(d, S(item_rule = "L2", staff_coding = "L1"))
check_equal(f1$staff_i2, c(log1p(0), log1p(0), log1p(20), log1p(20), log1p(20), log1p(5)), "A7 (staff L1): 0 is a valid source and is copied; 995 is not")
f2 <- bf(d, S(item_rule = "L2", staff_coding = "L2"))
check_equal(f2$staff_i2, c(log(20), NA, log(995), log(20), log(20), log(5)), "A7 (staff L2): 995 is a valid source and is copied as ln 995; 996/998 are not")
# manager fallback: CORE invalid at this level -> GSS used, even though the CORE cell is not blank
d <- rows(base_row(V114 = 2, V62 = 0,   V97 = 20, V131 = 70),
          base_row(V114 = 2, V62 = 995, V97 = 20, V131 = 70),
          base_row(V114 = 2, V62 = 0,   V97 = 0,  V131 = 70),
          base_row(V114 = 2, V62 = 999, V97 = 998, V131 = 70))
check_equal(bf(d, S(item_rule = "L2", staff_coding = "L0"))$staff_i3, c(log(20), log(20), NA, NA), "A7: manager item falls back to the GSS item when the CORE item is invalid at the level (0 / 995 under L0); both invalid -> missing")
check_equal(bf(d, S(item_rule = "L2", staff_coding = "L2"))$staff_i3, c(log(20), log(995), NA, NA), "A7: under staff L2 the CORE 995 is valid and is the manager source")
check_equal(bf(d, S(item_rule = "L2", staff_coding = "L1"))$staff_i3, c(0, log1p(20), 0, NA), "A7: under staff L1 the CORE 0 is valid and is the manager source")
# ILM / INCENT items: declared missing or out-of-range CORE items are not valid sources
d <- rows(base_row(V79 = NA, V67 = 9, V102 = 2, V222 = 7, V235 = 1),
          base_row(V79 = NA, V67 = 1, V102 = 2, V222 = 3, V235 = 1),
          base_row(V114 = 2, V67 = 8, V102 = 2, V136 = 1, V222 = 0, V235 = 2, V209 = 1))
f2 <- bf(d, S(item_rule = "L2"))
check_equal(f2$ILM[1:2], c(mean(c(NA, 1, 1, 1, 2), na.rm = TRUE), mean(c(2, 1, 2, 1, 2))), "A7: V102 keeps its own value when the CORE V67 is declared missing; copied when valid")
check_equal(f2$INCENT[1:2], c(mean(c(3, 3)), mean(c(3, 1, 1))), "A7: V235 keeps its own value when the CORE V222 is declared missing (7); copied when valid")
check_equal(c(f2$ILM[3], f2$INCENT[3]), c(mean(c(NA, 1, 1, 1, 1), na.rm = TRUE), mean(c(2, NA, 2), na.rm = TRUE)), "A7: manager items fall back to the GSS item when the CORE item is declared missing / out of range")

# ---------------- A9: STAFF special codes ----------------
d <- rows(base_row(V62 = 996), base_row(V62 = 997), base_row(V62 = 995), base_row(V62 = 0), base_row(V62 = -1))
check_equal(bf(d, S(staff_coding = "L0"))$staff_i1, c(NA, NA, NA, NA, NA), "A9 staff L0: 995/996/997, 0 and negative are missing")
check_equal(bf(d, S(staff_coding = "L1"))$staff_i1, c(NA, NA, NA, 0, NA), "A9 staff L1: 995/996/997 missing, 0 -> ln 1, negative missing")
check_equal(bf(d, S(staff_coding = "L2"))$staff_i1, c(NA, NA, log(995), NA, NA), "A9 staff L2: only 995 is a value")

# ---------------- A2: spec-level assignments take precedence over declared missing codes ----------------
mis2 <- mis
mis2$V157$values <- c(mis2$V157$values, 99996); mis2$V261$values <- c(mis2$V261$values, 96)
d <- rows(base_row(V157 = 99996, V261 = 96, V62 = 995))
fA <- build_frame(d, S(train_log = "L2"), mis2, cwp)
check_equal(fA$train_i2, 100000, "A2: V157 99996 -> 100000 even if 99996 were declared missing")
check_equal(fA$VHIER, log(100), "A2: V261 96 -> 100 under hierarchy L0 even if 96 were declared missing")
check_equal(build_frame(d, S(hierarchy = "L2"), mis2, cwp)$VHIER, 100, "A2: V261 96 -> 100 under hierarchy L2")
check_equal(build_frame(d, S(hierarchy = "L1"), mis2, cwp)$VHIER, NA, "hierarchy L1: 96 missing")
check_equal(build_frame(d, S(staff_coding = "L2"), mis, cwp)$staff_i1, log(995), "A2: 995 kept under staff L2 although declared missing in the metadata")
check_equal(build_frame(d, S(staff_coding = "L0"), mis, cwp)$staff_i1, NA, "995 missing under staff L0")

# ---------------- A3: CHK_hierarchy_log10 ----------------
d <- rows(base_row(V261 = 96), base_row(V261 = 10), base_row(V261 = 1))
fH <- bf(d, check = "hierarchy_log10"); fL <- bf(d)
check_equal(fH$VHIER, c(2, 1, 0), "A3: CHK_hierarchy_log10 = log10 of the recoded count (96 -> 100)")
check_equal(fH$VHIER, fL$VHIER / log(10), "A3: equals ln(count)/ln(10), not log10 of the logged value")

# ---------------- A4 / A9: system-missing routing and identifier inputs ----------------
d <- rows(base_row(V17 = NA, V21 = 2), base_row(V17 = NA, V21 = 1), base_row(V17 = 2, V21 = 2))
check_equal(bf(d, S(subsidiary = "L0"))$SUBSID, c(NA, NA, 0), "A4: SUBSID L0 missing when V17 is system-missing")
check_equal(bf(d, S(subsidiary = "L1"))$SUBSID, c(NA, NA, 0), "A4: SUBSID L1 missing when V17 is system-missing, whatever V21 says")
check_equal(bf(d, S(subsidiary = "L2"))$SUBSID, c(NA, NA, 0), "A4: SUBSID L2 missing when V17 is system-missing")
check_equal(bf(d)$DECENT, c(NA, NA, 3), "A4: DECENT missing when V17 is system-missing")
d <- rows(base_row(V17 = 2, V21 = 8), base_row(V17 = 2, V21 = 9), base_row(V17 = 2, V21 = 1))
check_equal(bf(d, S(subsidiary = "L1"))$SUBSID, c(0, 0, 0), "A9: SUBSID L1/L2 V17 == 2 gives 0 whatever V21 says (also 8/9)")
check_equal(bf(d, S(subsidiary = "L2"))$SUBSID, c(0, 0, 0), "A9: SUBSID L2 V17 == 2 gives 0")
d <- rows(base_row(V8 = NA), base_row(V8 = 1))
check_equal(bf(d)$NONPROF, c(NA, 0), "A9: V8 system-missing gives NONPROF missing")
check(identical(family_filter(add_z_indices(bf(d), "L0"), "mkt", ORIGIN), c(FALSE, TRUE)), "A9: V8 system-missing row is not in the market family")
# declared missing codes on V8 / V17 / V43 are honoured generically (none declared in the supplied metadata)
mis3 <- mis; mis3$V43 <- list(values = 999, ranges = list()); mis3$V17 <- list(values = 9, ranges = list()); mis3$V8 <- list(values = 9, ranges = list())
d <- rows(base_row(V43 = 999, V17 = 9, V8 = 9), base_row(V43 = 156, V17 = 2, V8 = 2))
fM <- build_frame(d, S(subsidiary = "L1"), mis3, cwp)
check(identical(fM$IND, c(NA, "UNCL")), "A4/checker 1: a declared-missing V43 is missing on industry (not UNCL); a non-missing code absent from the crosswalk is UNCL")
check(identical(build_frame(d, S(industry = "L1"), mis3, cwp)$IND, c(NA_character_, NA_character_)), "A4: declared-missing V43 missing under industry L1 too")
check_equal(c(fM$SUBSID, fM$DECENT, fM$NONPROF), c(NA, 0, NA, 3, NA, 1), "A4/A9: declared-missing V17 and V8 give missing SUBSID/DECENT/NONPROF")

# ---------------- A8: validity-based index flags and reference sample ----------------
check(identical(index_valid(rbind(c(1, NA, 3), c(NA, NA, NA), c(2, 2, 2)), "L0"), c(TRUE, FALSE, TRUE)), "A8: index valid under L0 iff >= 1 valid item")
check(identical(index_valid(rbind(c(1, NA, 3), c(NA, NA, NA), c(2, 2, 2)), "L1"), c(FALSE, FALSE, TRUE)), "A8: index valid under L1 iff all items valid")
d <- rows(base_row(V62 = 10, V97 = 10, V131 = 10, V157 = 50), base_row(V62 = 10, V97 = 10, V131 = 10, V157 = 50), base_row(V62 = 999, V97 = 998, V131 = 997, V157 = 50))
f8 <- bf(d)
check(identical(f8$STAFF_valid, c(TRUE, TRUE, FALSE)) && identical(f8$TRAIN_valid, c(TRUE, TRUE, TRUE)), "A8: STAFF/TRAIN validity flags follow item validity")
f8z <- add_z_indices(f8, "L0")
check(all(is.na(f8z$STAFF)), "A8 fixture: constant items give no standard score (degenerate SD), so STAFF itself is NA")
check(identical(family_sample_L0(f8z, "org", ORIGIN), c(TRUE, TRUE, FALSE)), "A8: sample membership comes from validity, not from standardized values")

# ---------------- VHIER ----------------
d <- rows(base_row(V261 = 96), base_row(V261 = 98), base_row(V261 = 5), base_row(V261 = 99))
check_equal(bf(d, S(hierarchy = "L0"))$VHIER, c(log(100), NA, log(5), NA), "VHIER L0: ln, 96 -> 100, 98/99 missing")
check_equal(bf(d, S(hierarchy = "L1"))$VHIER, c(NA, NA, log(5), NA), "VHIER L1: 96 missing")
check_equal(bf(d, S(hierarchy = "L2"))$VHIER, c(100, NA, 5, NA), "VHIER L2: raw count, 96 -> 100")
check_equal(bf(d, check = "hierarchy_log10")$VHIER, c(2, NA, log10(5), NA), "CHK hierarchy_log10: log10 of the L0 count")

# ---------------- Controls ----------------
d <- rows(base_row(V8 = 2), base_row(V8 = 1))
check_equal(bf(d)$NONPROF, c(1, 0), "NONPROF")
d <- rows(base_row(V17 = 1, V21 = 2), base_row(V17 = 1, V21 = 1), base_row(V17 = 1, V21 = 3), base_row(V17 = 1, V21 = 4),
          base_row(V17 = 1, V21 = 8), base_row(V17 = 2, V21 = NA), base_row(V17 = 2, V21 = 2), base_row(V17 = 1, V21 = NA))
check_equal(bf(d, S(subsidiary = "L0"))$SUBSID, c(1, 1, 1, 1, 1, 0, 0, 1), "SUBSID L0: V17==1")
check_equal(bf(d, S(subsidiary = "L1"))$SUBSID, c(1, 0, 0, 0, NA, 0, 0, NA), "SUBSID L1: V21==2; other V21 0; V17==2 0; V21 8/9 missing")
check_equal(bf(d, S(subsidiary = "L2"))$SUBSID, c(1, 1, 1, 0, NA, 0, 0, NA), "SUBSID L2: V21 in {1,2,3}")
d <- rows(base_row(V23 = 20, V32 = 5, NEWTOTAL = 30), base_row(V23 = 20, V32 = 99999, NEWTOTAL = 30), base_row(V23 = 0, V32 = 0, NEWTOTAL = NA), base_row(V23 = 99998, V32 = 1, NEWTOTAL = 2))
check_equal(bf(d, S(employment = "L0"))$LOGEMP, c(log(25), NA, NA, NA), "LOGEMP L0: ln(V23+V32), 99998/99999 missing, 0 missing")
check_equal(bf(d, S(employment = "L1"))$LOGEMP, c(log(30), log(30), NA, log(2)), "LOGEMP L1: ln(NEWTOTAL)")
check_equal(bf(d, S(employment = "L2"))$LOGEMP, c(log(20), log(20), NA, NA), "LOGEMP L2: ln(V23)")
d <- rows(base_row(V16 = 1981), base_row(V16 = 1991), base_row(V16 = 1992), base_row(V16 = 9998), base_row(V16 = 9999))
check_equal(bf(d, S(age = "L0"))$LOGAGE, c(log(10), NA, NA, NA, NA), "LOGAGE L0: ln(1991-V16), age<=0 missing")
check_equal(bf(d, S(age = "L1"))$LOGAGE, c(log(11), 0, NA, NA, NA), "LOGAGE L1: ln(1+age), age<0 missing")
check_equal(bf(d, S(age = "L2"))$LOGAGE, c(10, 0, -1, NA, NA), "LOGAGE L2: age in years")
d <- rows(base_row(V114 = 1, V115 = 5, V23 = 20, V32 = 5, NEWTOTAL = 50), base_row(V114 = 3, V115 = NA, V23 = 20, V32 = 5, NEWTOTAL = 50),
          base_row(V114 = 2, V115 = 5), base_row(V114 = 1, V115 = 99999), base_row(V114 = 1, V115 = 5, V23 = 0, V32 = 0, NEWTOTAL = 0),
          base_row(V114 = 1, V115 = 5, V23 = 99999, V32 = 5, NEWTOTAL = 50))
check_equal(bf(d, S(pct_managers = "L0"))$PCTMGR, c(20, 0, NA, NA, NA, NA), "PCTMGR L0: 100*num/(V23+V32); V114==3 -> 0; denominator 0/missing -> NA")
check_equal(bf(d, S(pct_managers = "L1"))$PCTMGR, c(20, NA, NA, NA, NA, NA), "PCTMGR L1: V114==3 missing")
check_equal(bf(d, S(pct_managers = "L2"))$PCTMGR, c(10, 0, NA, NA, NA, 10), "PCTMGR L2: denominator NEWTOTAL")
check_equal(bf(d, check = "pct_proportion")$PCTMGR, c(0.2, 0, NA, NA, NA, NA), "CHK pct_proportion: PCTMGR/100")
d <- rows(base_row(V220 = 1, V233 = 3, V300 = 2, V166 = 1), base_row(V220 = 1, V233 = 0, V300 = 7, V166 = 2), base_row(V220 = 9, V233 = 7, V300 = 3, V166 = 8))
check_equal(bf(d, S(union_items = "L0"))$UNION, c(2, 3, NA), "UNION L0: V220, V233 reversed; out-of-range 0 missing; 7/9 missing")
check_equal(bf(d, S(union_items = "L1"))$UNION, c(2, 3, 1), "UNION L1: + V300")
check_equal(bf(d, S(union_items = "L2"))$UNION, c(2.25, 2, 1), "UNION L2: + V166 (yes=3, no=1)")
check_equal(bf(d, S(union_items = "L1", item_rule = "L1"))$UNION, c(2, NA, NA), "UNION under item_rule L1")
d <- rows(base_row(V41 = 1), base_row(V41 = 2), base_row(V41 = 3), base_row(V41 = 4), base_row(V41 = 8))
f <- bf(d, S(neither = "L0"))
check_equal(f$PRODUCT, c(1, 0, 0, NA, NA), "PRODUCT: V41==1; both omitted; neither L0 missing; 8 missing")
check_equal(f$SERVICE, c(0, 1, 0, NA, NA), "SERVICE: V41==2")
f <- bf(d, S(neither = "L1"))
check_equal(c(f$PRODUCT[4], f$SERVICE[4]), c(0, 0), "neither L1: PRODUCT=SERVICE=0 for V41==4")
d <- rows(base_row(V328 = 4), base_row(V328 = 3), base_row(V328 = 1), base_row(V328 = 7))
check_equal(bf(d, S(competition = "L0"))$COMPET, c(4, 3, 1, NA), "COMPET L0: as is, 7 missing")
check_equal(bf(d, S(competition = "L1"))$COMPET, c(1, 0, 0, NA), "COMPET L1: ==4")
check_equal(bf(d, S(competition = "L2"))$COMPET, c(1, 1, 0, NA), "COMPET L2: >=3")

# ---------------- Industry ----------------
d <- rows(base_row(V43 = 10), base_row(V43 = 41), base_row(V43 = 122), base_row(V43 = 156), base_row(V43 = NA), base_row(V43 = 800))
check(identical(bf(d, S(industry = "L0"))$IND, c("01", "11", "UNCL", "UNCL", NA, "78")), "industry L0: first listed; empty or not in crosswalk -> UNCL; V43 missing -> missing")
check(identical(bf(d, S(industry = "L1"))$IND, c("01", NA, NA, NA, NA, NA)), "industry L1: multiple listed / empty / not found -> missing")
check(identical(parse_crosswalk(data.frame(census1980_code = c("001", "002"), sic2_from_printed = c("11, 12", "")))$first, c("1" = "11", "2" = NA)), "crosswalk parser accepts comma separators and empty fields")
check(identical(industry_dummy_groups(c("01", "01", "07", "07", "UNCL")), c("07", "UNCL")), "dummies: omit largest group, ties -> lowest code")
check(identical(industry_dummy_groups(c("UNCL", "UNCL", "05")), c("05")), "dummies: UNCL can be the reference")
check(identical(industry_dummy_groups(c("01", "01", "07", "07", "UNCL"), alt = TRUE), c("01", "07")), "CHK industry_ref_alt: omit smallest group")
check(identical(industry_dummy_groups(c("01", "07", "11", "11"), alt = TRUE), c("01", "11")), "CHK industry_ref_alt: ties -> highest code")

# ---------------- Record frame, family filters, weights ----------------
d <- rows(base_row(V3 = 0), base_row(V3 = 1), base_row(V3 = 2), base_row(V3 = NA))
check_equal(nrow(bf(d, S(records = "L0"))), 4, "records L0 keeps all rows")
check_equal(bf(d, S(records = "L1"))$V1, c(2, 3, 4), "records L1 drops V3 == 0")
d <- rows(base_row(V8 = 1, V9 = 4), base_row(V8 = 1, V9 = 5), base_row(V8 = 2, V9 = 4), base_row(V8 = 1, V9 = 9),
          base_row(V8 = 1, V9 = 4, V289 = 7, V290 = 7, V291 = 7, V292 = 7, V293 = 7, V294 = 7, V295 = 7), base_row(WEIGHT = 0), base_row(WEIGHT = -1))
d$V62 <- c(5, 10, 20, 40, 80, 160, 320); d$V157 <- c(1, 2, 4, 8, 16, 32, 64)   # variation so that z-scores exist
f <- add_z_indices(bf(d), "L0")
check(all(!is.na(f$STAFF)) && all(!is.na(f$TRAIN)), "test frame: STAFF and TRAIN valid on all rows")
check(identical(family_filter(f, "org", ORIGIN), rep(TRUE, 7)), "org family: all rows of the frame")
check(identical(family_filter(f, "mkt", S(market_sample = "L0")), c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE)), "market_sample L0: V8 == 1")
check(identical(family_filter(f, "mkt", S(market_sample = "L1")), c(TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE)), "market_sample L1: V8 == 1 and V9 == 4 (V9 9 missing)")
check(identical(family_filter(f, "mkt", S(market_requires_pop = "L1")), c(TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE)), "market_requires_pop L1: POP must be valid")
check(identical(family_filter(f, "org", S(weights = "L1")), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)), "weights L1: WEIGHT <= 0 or missing excluded")
check(identical(family_sample_L0(f, "org", ORIGIN), c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE)), "common complete cases: row with missing POP leaves the org sample")

# ---------------- Design matrix and centering ----------------
f <- data.frame(V1 = 1:5, STAFF = c(1, 2, 3, 4, 5), TRAIN = c(2, 4, 6, 8, 10), NONPROF = c(0, 1, 0, 1, 0), IND = c("01", "01", "07", "UNCL", "07"))
X0 <- build_design(f, rep(TRUE, 5), c("STAFF", "TRAIN"), "TRAIN_x_STAFF", "NONPROF", c("07", "UNCL"), "L0")
check(identical(colnames(X0), c("(Intercept)", "STAFF", "TRAIN", "TRAIN_x_STAFF", "NONPROF", "IND_07", "IND_UNCL")), "design column names and order")
check_equal(X0[, "TRAIN_x_STAFF"], f$TRAIN * f$STAFF, "centering L0: raw product")
check_equal(X0[, "IND_07"], c(0, 0, 1, 0, 1), "industry dummy IND_07")
X1 <- build_design(f, rep(TRUE, 5), c("STAFF", "TRAIN"), "TRAIN_x_STAFF", "NONPROF", c("07", "UNCL"), "L1")
check_equal(X1[, "TRAIN_x_STAFF"], (f$TRAIN - 6) * (f$STAFF - 3), "centering L1: product of components centered at estimation-sample means")
check_equal(X1[, "STAFF"], f$STAFF, "centering L1: main effects stay uncentered")
X2 <- build_design(f, c(TRUE, TRUE, TRUE, FALSE, FALSE), c("STAFF"), character(0), "NONPROF", c("07", "UNCL"), "L0")
check_equal(X2[, "IND_UNCL"], c(0, 0, 0), "dummy all zero in a sub-sample (dropped later by fit_model)")

res <- test_summary("test_coding")
