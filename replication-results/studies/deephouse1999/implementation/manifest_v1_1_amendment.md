# Manifest amendment v1.1 (clarifications; applies to every implementer)

Issued before any empirical model fit, after pre-execution checks showed that the following manifest items were ambiguous or under-documented. No results were seen by anyone. manifest.md v1 is unchanged and preserved; these clarifications take precedence where they apply.

C1. Inputs. `data/county_fips_mn_wi.parquet` is an input (county names); code must still run if only name lookups depend on it.

C2. R02.no_special. RSSD9425 (bank type analysis code) values from the Federal Reserve MDRM dictionary (supplied as `docs/rssd9425_codes.txt`): 0 not applicable; 1 bankers' bank subject to reserve requirements; 2 bankers' bank not subject to reserve requirements; 3 grandfathered nonbank bank; 4 primarily credit card activities; 5 wholesale bank; 6 standalone internet bank; 7 workout entity; 8 DINB; 9 depository trust company; 10 bridge entity; 11-12 Edge/agreement corporations; 13 data processing services; 14 trust preferred securities subsidiary; 15 cash management bank; 16 Farm Credit System institution; 17 10(l) election; 18 grandfathered SLHC. R02.no_special excludes records with RSSD9425 in {1, 2, 4, 9} (bankers' banks, credit-card banks, trust-only banks); missing RSSD9425 counts as 0.

C3. R02.add_savings. Admit RSSD9048 == 300 records that satisfy every other part of the active origin's R02 rule (CALL8786 in {1,2}; at O_A also RSSD9331 == 1). If no record qualifies, the specification is still run and the log says so.

C4. R06.rck_days. Requires all four quarterly item-3368 values of year t (RCFD, else RCON per quarter) regardless of the R05 level; days per quarter of year t (leap years counted); no RCFD2170 fallback.

C5. R09.analytic. Reference population for year t in 1985..1992 = the first-pass estimation rows of year t. For 1984 (needed for 1985 lags and 1985 market growth) = the 1984 bank-years whose relative ROA is the lag of a first-pass 1985 estimation row. Rebuild variables on these references and refit on the first-pass rows; a row whose rebuilt variables are undefined is dropped and counted in the log (not a failure of the whole specification).

C6. R26.centered applies to M3 only (the model with both SD and SD^2). For M2 report the centred fit (SD - mean) back-transformed; for M3_SQ, which has no first-order term, the centred re-expression is not defined: write status `not_applicable` for M3_SQ under R26.centered.

C7. Market growth and lags must use calendar year t-1 explicitly; never the previous available year.

C8. `unavailable` is used when a level cannot be built from the supplied inputs; `failed` is used for runtime errors. Report every fitted coefficient, including fixed-effect indicators.
