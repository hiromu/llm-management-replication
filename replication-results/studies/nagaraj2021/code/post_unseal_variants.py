"""Post-unsealing diagnostics: frozen implementation A changed one author-code difference at a time.
Writes post_unseal/diagnostics/<variant>/A_variant.R and grid_subset.csv. Nothing here revises a frozen result.
Variants:
  D01 Massachusetts kept with treat = 0 (merge_covar.ado: 'MA was never treated'); article says excluded
  D02 Hawaii (state 15) dropped (merge_covar.ado); not stated in the article
  D03 controls by per-county linear interpolation and extrapolation over years (ipolate ..., epolate)
  D04 D03 plus cross-section controls and quartile variables at 2014 values (reg_crossec.ado uses yq==219 rows)
  D06 Table 6 outcome signed: sign(osrm - google) x ln|osrm - google| (make_directions.ado)
  D08 timing sample = scheduled month within 12 months of 2005m6 (add_bordertiming.ado)
  D10 cumulative: D01 + D02 + D04 + D06 + D08
"""
import csv, json, os

STUDY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(STUDY, "runs/run_20261101_v1/code/A_run_analysis.R")).read()
OUT = os.path.join(STUDY, "post_unseal/diagnostics")

MA_OLD = 'Udt <- cl_raw[is.na(STATE_NAME) | STATE_NAME != "Massachusetts"]'
W1_OLD = 'y <- log(abs(p$osrm_distance - p$ggl_distance))'
W1_NEW = 'y <- sign(p$osrm_distance - p$ggl_distance) * log(abs(p$osrm_distance - p$ggl_distance))'
TD_OLD = 'tdt <- data.table(fips = tfips, year = tyear)'
TD_NEW = 'tdt <- data.table(fips = tfips, year = tyear, mon = (tyear - 1960L) * 12L + as.integer(format(tdate, "%m")) - 1L)'
TM_OLD = 'TIMING <- sort(intersect(U_fips, tdt[!is.na(year) & year %in% c(2005L, 2006L), fips]))'
TM_NEW = 'TIMING <- sort(intersect(U_fips, tdt[!is.na(mon) & abs(mon - 545L) <= 12L, fips]))'
P6_START = "# Panel rule: county-year -> ACS values"
P6_END = "y3 <- acs[fips %in% U_fips"


def interp_block(y1_target):
    return f'''# Panel rule (post-unsealing variant): per-county linear interpolation and extrapolation of each control
ipo <- function(yrs, vals, target) {{
  ok <- !is.na(vals); x <- yrs[ok]; v <- vals[ok]
  if (length(x) == 0) return(rep(NA_real_, length(target)))
  o <- order(x); x <- x[o]; v <- v[o]
  if (length(x) == 1) return(ifelse(target == x, v, NA_real_))
  out <- approx(x, v, xout = target, rule = 1)$y
  n <- length(x)
  lo <- target < x[1]; hi <- target > x[n]
  out[lo] <- v[1] + (target[lo] - x[1]) * (v[2] - v[1]) / (x[2] - x[1])
  out[hi] <- v[n] + (target[hi] - x[n]) * (v[n] - v[n - 1]) / (x[n] - x[n - 1])
  out
}}
ITGT <- 2005:2014
ip <- acs[fips %in% U_fips, c(list(year = ITGT), lapply(.SD, function(col) ipo(acsyear, col, ITGT))), by = fips, .SDcols = CTRL]
pc <- merge(CJ(fips = U_fips, year = 2005:2014), ip, by = c("fips", "year"), all.x = TRUE)
setorder(pc, fips, year)
n_U_no_acs <- length(setdiff(U_fips, unique(acs$fips)))
n_cy_nearest <- NA_integer_
pan <- merge(pan, pc[, c("fips", "year", CTRL), with = FALSE], by = c("fips", "year"), all.x = TRUE)
setorder(pan, fips, t)
PCTRL <- list(L1 = ltrans(pan, "L1"), L2 = ltrans(pan, "L2"))
cs_raw <- list()
cs_near <- list(Y1 = NA, Y2 = NA)
for (Y in c("Y1", "Y2")) {{
  tgt <- if (Y == "Y1") {y1_target}L else 2008L
  z <- ip[year == tgt][match(U_fips, fips)]
  z[, fips := U_fips]
  cs_raw[[Y]] <- z[, c("fips", CTRL), with = FALSE]
}}
'''


def replace_p6(src, y1_target):
    a, b = src.index(P6_START), src.index(P6_END)
    return src[:a] + interp_block(y1_target) + src[b:]


def sub(src, old, new):
    assert src.count(old) == 1, old
    return src.replace(old, new)


V = {
    "D01_MA_as_controls": lambda s: sub(s, MA_OLD, 'Udt <- copy(cl_raw); Udt[STATE_NAME == "Massachusetts", treat := 0L]'),
    "D02_drop_Hawaii": lambda s: sub(s, MA_OLD, 'Udt <- cl_raw[(is.na(STATE_NAME) | STATE_NAME != "Massachusetts") & as.integer(STATE_FIPS) != 15L]'),
    "D03_interpolated_controls": lambda s: replace_p6(s, 2011),
    "D04_interpolated_controls_xs2014": lambda s: replace_p6(s, 2014),
    "D06_signed_log_error": lambda s: sub(s, W1_OLD, W1_NEW),
    "D08_timing_window": lambda s: sub(sub(s, TD_OLD, TD_NEW), TM_OLD, TM_NEW),
}
V["D10_cumulative"] = lambda s: V["D08_timing_window"](V["D06_signed_log_error"](replace_p6(
    sub(s, MA_OLD, 'Udt <- copy(cl_raw)[as.integer(STATE_FIPS) != 15L]; Udt[STATE_NAME == "Massachusetts", treat := 0L]'), 2014)))

claims = json.load(open(os.path.join(STUDY, "scoring/claims_v1.json")))
keep = {"S00001", "S00003"}
for c in claims:
    if c["kind"] in ("regression", "regression_nuisance_unit", "placebo"):
        keep.add(c["origin_spec"])
        keep.update(x for x in c.get("uncertain_specs_extra", []) if x)
grid = list(csv.DictReader(open(os.path.join(STUDY, "manifest/grid_v1.csv"))))
sub_rows = [g for g in grid if g["spec_id"] in keep]
for name, f in V.items():
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "A_variant.R"), "w").write(f(SRC))
    with open(os.path.join(d, "grid_subset.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(grid[0]))
        w.writeheader()
        w.writerows(sub_rows)
print(len(sub_rows), "grid rows;", list(V))
