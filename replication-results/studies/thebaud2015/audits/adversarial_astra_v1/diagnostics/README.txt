All work is POST HOC and diagnostic. Run from the audit directory. All scripts read only within the study root and write only within this audit directory. No published values are used as regression inputs. Source-document extracts and printed-value transcriptions are comparison material only.

Interpreters:
  ~/.venv/bin/python -B
  /opt/homebrew/bin/Rscript
Every numerical launch uses OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1. At most two numerical processes ran concurrently; data.table is also limited to one thread.

Preparation and read-only checks:
  /opt/homebrew/bin/Rscript diagnostics/prepare.R
  /opt/homebrew/bin/Rscript diagnostics/prepare_lag.R
  ~/.venv/bin/python -B diagnostics/raw_audit.py
  ~/.venv/bin/python -B diagnostics/source_documents.py
Use the absolute interpreters above, not system aliases.

Independent fits:
  /opt/homebrew/bin/Rscript diagnostics/refits.R M4_common_U09_U14,M4_common_U09_U14_nochildcare,M4_common_U09_U14_altleave
  /opt/homebrew/bin/Rscript diagnostics/refits.R M4_common_U18_U14,M4_common_U09_U18_U14
  /opt/homebrew/bin/Rscript diagnostics/refit_default.R M6_common_U14_default
  /opt/homebrew/bin/Rscript diagnostics/refit_bounded.R M6_common_U14_altleave_default,M6_FAULT_missing1_U14_default
The M4 fits use bobyqa with maxfun=100000. The M6 fits use default lme4 optimization, as in the frozen implementations. The bounded driver permits up to 900 CPU seconds/1200 elapsed seconds per fit. Mixed models use ML, logit, Laplace, independent random intercepts and female slopes at country and survey levels, unweighted. Standardization anchor: the corresponding stage-1 sample, not the owner common sample.

FAULT_missing1 is deliberately incorrect coding, not an eligible alternative: it replaces unavailable growth with one, including missing current or future counts. It is intended to challenge a claim of numerical impossibility, not to suggest that the article made this mistake. The descriptive fault injection in prepare.R uses the size-complete sample; the fitted fault injection has the full covariate-complete owner sample. validation.csv reports the fitted outcome prevalence and N; do not conflate these samples.

Additional attempted run:
  /opt/homebrew/bin/Rscript diagnostics/refits.R M6_common_U14,M6_common_U14_altleave,M6_FAULT_missing1_U14
This bobyqa run was interrupted during its first fit after approximately 12 elapsed minutes, before any fitted model or result was accepted. The remaining two specifications in that launch were not started. Its log is retained as refits_M6.log. Default-optimizer runs replace it for diagnostic reporting.

The first three-model M4 launch completed and saved all three fits, then its driver exited with a parse error because the script had been edited while R was still reading it. No fitted-model result was lost. The log is retained in refits_M4.log. Later verification reparses all R scripts and independently checks each saved fit against its CSV, observations, convergence and finite standard errors. The final driver file parses successfully and the subsequent two-year-lag launch exits successfully.

Verification and algebra:
  /opt/homebrew/bin/Rscript diagnostics/basis_check.R
  /opt/homebrew/bin/Rscript diagnostics/verify.R
  ~/.venv/bin/python -B diagnostics/final_checks.py
basis_check.R transforms both coefficients and their full covariance and asserts identical fixed linear predictors and joint leave-interaction Wald tests. verify.R creates all_refits.csv and validation.csv, keeping warnings, singularity and convergence information. No benchmark p values or revised frozen scores are generated.

Data provenance:
raw_audit.py deliberately reads SAV user-defined missing values as numbers to audit extraction. The raw_extract_check.csv unequal column includes conversion of declared missing codes to empty CSV cells; unexplained is the relevant preservation check. The codebook and metadata document these missing values. This corrects the overbroad construction-notes claim that every labelled code was retained.
