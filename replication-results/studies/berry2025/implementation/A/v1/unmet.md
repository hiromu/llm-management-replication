# Unmet manifest items

None. Every quantity, sample level, composite level, bootstrap, leave-one-out
estimand and output file in the manifest is implemented, and on the synthetic
run (`--boot 200`) every result row has status `ok`.

Data-dependent failures (for example a subgroup with fewer than two
observations, a zero-variance item set, a logistic model that does not converge,
or a bias-corrected bound whose z0 is infinite) are not unmet items; they are
written to results.csv / influence.csv with status `failed` and a reason, and
the run continues.
