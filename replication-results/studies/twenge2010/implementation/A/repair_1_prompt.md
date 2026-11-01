# Repair round 1

An independent checker compared your code with MANIFEST.md and listed the items below as unmet. Fix each item in code/ (edit in place; the coordinator has preserved your previous version), or, if an item cannot be implemented, record it as unavailable with the reason in the output. Do not change anything else. Re-run your synthetic tests and the affected specifications, update README.md and code/TESTS.md, and print a short summary of what you changed.

## Checker list
- **§4.4 and §5, S04:** `d_obs` uses means of available items and excludes respondents missing every item of a factor, changing both the scale definition and SD sample/divisor. See `code/lib_models.R:349–357` and `code/lib_specs.R:247`.
- **§5, S06, and §7:** S06 explicitly passes `information = "expected"` while its recorded explanation claims MLR defaults with observed information. See `code/lib_specs.R:21–29,249–250` and `code/lib_models.R:141`.
- **§3 and §7:** Influence analyses do not record sample V4 hashes or per-deletion analysis sample sizes; their metadata records only full-sample group counts. See `code/lib_influence.R:70,83–97`.
- **§7:** Specification status starts as `"ok"` and changes only for an escaping exception. Internally captured model failures, nonconvergence, and fit-index errors are not propagated to specification status or reason. See `code/lib_specs.R:89–94,155–172,205,244`.
- **§7:** Output identifiers depart from the required IDs: CHK1 uses model ID `M4_CHK1` instead of `M4`, and S08 alpha uses `S08_one_factor` instead of `C1`. See `code/lib_specs.R:227,243`.
- **Manifest opening requirement and §5, S06:** The code adds scaled chi-square difference tests beyond the requested ordinary differences and scaled model chi-square. See `code/lib_specs.R:184` and `code/lib_models.R:260–265`.