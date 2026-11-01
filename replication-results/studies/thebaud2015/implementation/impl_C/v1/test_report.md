# Test report for run.jl (manifest P-7Q3) on the synthetic files

All tests used the files in `synthetic/` (gem_extract.csv: 26,400 rows, 24 countries,
years 2000-2008, 165 surveys of 160 rows; country_year_inputs.csv: 264 rows). The
synthetic roster coverage is incomplete by design: 111 of the 143 origin roster surveys
are present in gem_extract.csv. The real data will differ. No raw data rows were printed.

Machine: Apple arm64, Julia 1.12.6 single-threaded, MixedModels 5.9.1. Test scripts are
in `tests/` (they `include` run.jl or read its outputs; they are not needed to run the
deliverable). The outputs of the timed run are in `test_output/`.

## 1. Timed run (the required minimum)

Command:

```
julia run.jl synthetic <out_dir> "ORIGIN,U09,U23,U25,influence:M5"
```

| Item | Result |
| --- | --- |
| Wall time | 920 s (15.3 min), under the 25-minute limit |
| Rows in results.csv | 1,032, all status ok |
| ORIGIN fits | M1-M8, R1-R3: 11 of 11 ok, all converged |
| Deviations | U09 (M4), U23 (M6), U25 (M5, REML): ok |
| Influence M5 | 24 refits, one per country, all ok, 23 countries each |
| constants.json | entries ORIGIN, U09, U23, U25, influence |
| session_info.txt | written (versions, routines, work-around notice) |

Per-fit times: M1 55 s, M2 109 s, M3 188 s, R1 132 s, R2 332 s, R3 42 s; the stage-2
logit models 5-12 s each; the linear model under a second. Almost all of the time is the
manifest's `fast = false` Laplace optimisation (about 17,000-28,000 objective evaluations
per stage-1 fit; see IMPLEMENTATION_NOTES.md on run time).

The deviations were chosen to keep the timed run inside the limit (each fits a single
stage-2 model). The remaining deviations were exercised in section 4.

## 2. Sample counts against the manifest rules

`tests/check_counts.jl` recomputes the ORIGIN estimation samples directly from the raw codes
(no function of run.jl is used) and compares with results.csv. All counts agree exactly:

| Model | n_obs | countries | surveys | Independent recount |
| --- | --- | --- | --- | --- |
| M1, M2, M3, R1 (S1) | 6,579 | 24 | 111 | 6,579 / 111 |
| R2 (steps 1-2, no employment step) | 9,634 | 24 | 111 | 9,634 |
| R3 (S1 + skill, fear, knows) | 2,197 | 24 | 111 | 2,197 |
| M4 (S2, planb) | 365 | 24 | 107 | 365 |
| M5 (S2, size) | 372 | 24 | 107 | 372 |
| M6 (S2, growth) | 372 | 24 | 107 | 372 |
| M7 (S2, newprod, 2002-2008) | 332 | 24 | 96 | 332 |
| M8 (S2, newtech, 2005-2008) | 179 | 22 | 51 | 179 / 22 countries |

Checks implied by these numbers: roster restriction (111 present surveys, none outside
the roster), age 19-54, employed = 1, complete cases per model (M1 has the same n as M3
here only because every present survey has complete survey-level values), owner = 1 and
completeness on sole and bage for stage 2, the year windows of M7 and M8 (M8 loses two
countries that have no 2005-2008 surveys), and n_surveys counted on the estimation sample.
The recount also reproduced the ORIGIN standardization constants for leave (mean 26.311,
SD 13.851) and status (mean 0.4991, SD 0.0534) including the carry-back of status from
later years (57 surveys received a carried-back value; listed in constants.json).

Branch sample behaviour (`tests/harness.jl`, which includes run.jl and prepares every
deviation without fitting the slow models): U01 enlarges S1 to 6,784 (age 18 admitted);
U02 to 7,177 (GEMWORK 6 admitted); U03/U04 change activity missingness (6,512 / 6,639);
U05 uses 151 surveys (all 2001-2008 surveys present) with 150 in the standardization set;
U07 shrinks stage 2 (established owners only, M4 n = 315); U08 leaves it unchanged on these
data; U11 enlarges it (bage defined at zero years, M4 n = 392); U22 changes which surveys
have a status value (109 surveys; M5 loses one country); N01 removes 2001-2002 (roster
110, 84 surveys in the set, M3 n = 4,967, no carry-back) and the year reference falls back
to 2003 for M3-M7 as documented; U09, U10, U12-U20, U23-U26 leave sample sizes unchanged,
as they should.

Standardization checks in the same harness: every standardized survey-level variable has
mean 0 and SD 1 over the surveys of the origin M3 set (each survey once); leave_sq equals
the square of standardized leave; under U14 leave_sq itself has mean 0 / SD 1 over the
set; under U15 the 24 country means of standardized leave have mean 0 / SD 1; under U16
the individual rows of the M3 sample have mean 0 / SD 1.

## 3. M3 female:childcare against the generating value

ORIGIN M3 (status ok, converged, not singular; 26 terms with the exact manifest names):

| Term | Estimate | SE | Generating value | distance in SE |
| --- | --- | --- | --- | --- |
| (Intercept) | -1.991 | 0.155 | -2.0 | 0.06 |
| female | -0.646 | 0.119 | -0.5 | 1.22 |
| childcare | 0.091 | 0.061 | 0.1 | 0.14 |
| female:leave | 0.110 | 0.085 | 0.2 | 1.05 |
| female:childcare | -0.323 | 0.097 | -0.25 | 0.75 |
| female:parttime | 0.090 | 0.086 | 0.0 | 1.04 |

The female:childcare estimate is within one standard error of its generating value, and
every generating coefficient lies within about 1.2 SE of its estimate. Benchmark
(pooled, CR1 country-clustered) standard errors are smaller (female:childcare 0.062,
p = 1.6e-7 versus model-based 0.097, p = 0.0008), as expected when the pooled model
ignores the survey design.

Variance components: the fitted M3 SDs are close to zero (country intercept 0.001,
country female 0.000, survey intercept 0.020, survey female 0.005) although the generating
values are 0.3, 0.1, 0.2, 0.1. M1, which has no survey-level covariates, gives 0.146 and
0.075 for the intercept SDs. `tests/crosscheck_m3.jl` refitted the same M1 and M3 frames
with MixedModels' other optimisation path (`fast = true`, used only as a check): the
Laplace deviances agree (M3: 4216.807 vs 4216.806; M1: 4245.304 vs 4245.356), the
variance components agree, and the M3 coefficients agree to within 0.004. The collapse of
the variance components with the full covariate set is therefore a property of these
synthetic data (10 survey-level covariates and 7 year indicators fitted to 111 surveys in
24 countries), not a convergence failure of the script's fits.

## 4. Code paths exercised beyond the timed run

- `tests/harness.jl` fitted 22 cheap stage-2 models under branches U01, U02, U05, U07,
  U08, U09, U10, U11, U12, U13, U14, U15, U16, U17, U18, U19, U20, U22, U23, U24 and N01.
  All returned status ok and converged. U20 (unstructured covariance) produced the same
  term list and non-zero SDs; N01 produced year2004-year2008 indicators only and the
  reference-year note in the error column with status ok.
- Failure path: a forced impossible fit (constant outcome) produced one row with status
  `failed`, the error text ("The response is constant ..."), the sample counts and hash,
  and execution continued.
- Earlier development runs covered ORIGIN twice (identical results, deterministic) and
  `U25,influence:M5` separately; the full ORIGIN run alone takes about 15 minutes here.
- The MixedModels work-around (IMPLEMENTATION_NOTES.md section 0) was verified directly:
  before it, the first objective evaluation of any two-level random-slope GLMM threw
  PosDefException (the off-diagonal cross-product block had norm 1549 instead of 130);
  after it, the block matches the explicit `Z2' W Z1` product to 4e-15 and all fits run.

## 5. Checks on the output format

- results.csv has exactly the 26 columns of manifest section 8, in order; one row per
  (run_id, model, term), deleted_country filled only for influence rows; missing values
  as empty cells; booleans as true/false; wild_p filled only for the four F x X terms of
  M5 (ORIGIN M5: female:leave 0.015, female:leave_sq 0.099, female:childcare 0.471,
  female:parttime 0.412, each from 999 Rademacher draws with seed 20261028).
- Term names are exactly those of the manifest; year indicators are year2002-year2008 for
  reference 2001, year2003-year2008 for M7, year2005-year2007 for M8.
- sample_hash is a 64-character SHA-256 hex string and differs across models/samples.
- The run-id parser accepts a list, `all`, `influence` and `influence:<model>`; unknown
  IDs raise an error before any data are read.

## 6. Not tested on real data

Run time on the real files will be much longer than on the synthetic files (see
IMPLEMENTATION_NOTES.md). Nothing else in the script depends on the synthetic data.
