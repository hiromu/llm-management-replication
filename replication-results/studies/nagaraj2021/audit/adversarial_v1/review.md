# Adversarial review v1 (pre-unsealing)

Reviewer: a Claude Code subagent running Claude Opus 5.5, the same model family as implementation A and Reader A. No family-independent review was available, and no human reviewed this. The author package and sealed/setup_exposure_detail.txt were not opened. All reruns are pre-unsealing adversarial diagnostics, run with network access denied (Python 3.13.16 with pandas 2.3.3; R 4.6.1 with fixest 0.14.2). Scripts and outputs are in this folder (d01 to d15). Frozen files were not changed, and the diagnostics cannot change frozen scores.

Result: 12 overturned (6 source_vintage, 6 inconsistent_targets) and 8 survive. The details for each unit are in review.json.

## Table 1 change-in-control rows (6 units): overturned, source_vintage

I recomputed every frozen value, and the scorer applied the descriptive rule correctly. The article defines each change as 2014 minus 2005, but acs5year.dta ends at acsyear 2011, so the reconstruction measures a 2005 to 2011 change. No pair of deposit years reproduces all six published rows (d13). Three patterns point to the shorter span as the cause. Scaling the 2005 to 2011 change by 9/6 gives treated population 7,328.8 against a published 7,324.3, and treated households 2,184.4 against 2,186.4 (d06). The unemployment column is a count of unemployed people, which matches the label "Unemployed Pop." Its group means peak at acsyear 2009, so a 2005 to 2011 change is positive, while the published 2014 minus 2005 change is negative. It is still uncertain what the deposit's acsyear labels mean and how Male Population (18-45) maps to a deposit column, but neither question changes the verdict.

## Table 2 ownership rows (2 units): overturned, inconsistent_targets (secondary measurement_mapping)

The published maxima identify the deposit columns exactly. The Low Ownership maximum, 20,595, is the maximum of totaloldfocused1. The High Ownership maximum, 1,268,382, is the maximum of totaloldfocused5, and it comes from a Massachusetts county-quarter (25017, 2009q1). Table 7 labels the same two columns the other way round: its High estimate matches focused1 and its Low estimate matches focused5. The article is therefore inconsistent with itself. Table 2 also includes Massachusetts although its note excludes it. Using all 3,109 counties reproduces both rows: means 2.003 and 123.44 against published 2.00 and 123.52, and the maximum matches exactly (d03). The same Massachusetts inclusion explains why Total Contributions sits in the measurement-indeterminate group. That claim was not a candidate and was not re-scored.

## Figure 1(a) and Figure 2(a) county counts (2 units): overturned, inconsistent_targets

Figure 1(a): the published 3,107 counties (1,851 treated, 1,256 control) are the 3,093 counties in the Table 1 header plus the 14 Massachusetts counties counted as controls. Adding Massachusetts as controls reproduces the Table 1 outcome means and p-values: control Contributions 3,589.5 against 3,593.3 (d10). Against either definition, the reconstruction is off by one county per group.

Figure 2(a): the text says the boundary sample has 1,820 counties, but Table 5 Panel B, and Table 6 implicitly, give it 2,218. The deposit supports 2,218. The boundary rule yields 2,214 counties with exactly 1,228 treated, and the published Table 6 boundary N of 58,715 is matched exactly once Massachusetts is included (d11). Under that labelling the count is within 1%.

## Figure 2(b) timing count: survives

The reconstruction finds 1,568 counties (589 treated). That matches neither published size: 2,218 (1,228 treated) or 1,820 (1,096 treated). The only date column is "Sch SB Delivery", which fits the article's description of the scheduled delivery date, and the frozen calendar-year 2005-2006 rule follows the text. No window with a textual basis comes close (d05). An undocumented different vintage of timing.xlsx cannot be ruled out.

## Table 5 Panel A columns 6-8

An independent rerun reproduces the frozen estimates exactly. The published panel contradicts itself. The N row gives each sample label two different Ns, and the printed SEs follow the N row, not the column headers. Read together with the N row and Panel B, the columns are: boundary follow-on, timing follow-on, boundary contributors, timing contributors. The reconstructed SEs (0.052, 0.062, 0.016, 0.020) track the published ones (0.056, 0.063, 0.019, 0.023) under that layout.

- Columns 6 and 7: overturned, inconsistent_targets. Under that layout, z is 1.66 for column 6 and 0.33 for column 7.
- Column 8 (timing contributors): survives. It fails under both the printed headers and the N-implied layout (z 2.93, p 0.51 against ***). It passes only under the text-based labelling, which the deposit contradicts. It probably shares its root cause with Figure 2(b), the timing sample that could not be reproduced.

## Table 6 Treat and Distance, columns 1-3 (6 units): survive

An independent rerun reproduces every frozen estimate. Three checks rule out the data and the sample as explanations:
- The distance data are the ones the paper used: the Table 1 Error-Score means, 2,312 counties and 98,711 pairs all match.
- Including Massachusetts reproduces the published N exactly (81,007 full; 58,715 boundary), and Treat stays negative (-0.086 to -0.112).
- Every reading with a textual basis keeps Treat negative or null. That covers all 35 frozen uncertain rows, raw and partial models, percent-male controls, ACS 2008 controls, county-mean logged error and a signed log ratio (d08, d11, d15).

The Distance coefficient (0.049 to 0.052 per km) fails in both kilometres and miles. Every other construction I tried also fails (d12).

A sign-reversed treatment coding would put Treat close to the published values for columns 1-2. It has no textual basis, so I report it only as a hypothesis for the post-unsealing comparison. If it were the cause, the error would be in the published pipeline, not in the reconstruction.
