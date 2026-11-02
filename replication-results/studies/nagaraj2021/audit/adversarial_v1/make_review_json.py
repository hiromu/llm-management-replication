# Builds review.json for the pre-unsealing adversarial review (adversarial_v1).
import json
A='audit/adversarial_v1/'
T1_common=("Scorer check: r = distance to rounding interval / |published| reproduced (e.g. D Population treated (7324.25-4883.07)/7324.3 = 0.333); A-B agree. "
 "Deposit cannot supply the published quantity: acs5year.dta covers acsyear 2005-2011 only (deposit_data_notes.txt; d06 out: 3,221/3,220 rows per year), while Table 1 defines the change as 2014 minus 2005 (D01 p.8, Table 1 note). "
 "The frozen panel rule carries 2011 to 2014, so the reconstruction is a 2005->2011 change. No deposit year pair reproduces the published group means for all six rows (d13: best joint max relative deviation 0.77). "
 "Consistent with a longer span: scaling the 2005->2011 change by 9/6 gives D Population treated 7,328.8 vs published 7,324.3 and D Households treated 2,184.4 vs 2,186.4 (d06). "
 "The deposit column unemploymentrate (label SE_T033_006) is a count of unemployed persons (2011 median 988.5), matching 'Unemployed Pop.', so there is no rate/count mismatch; its group means peak at acsyear 2009 and fall afterwards, so the 2005->2011 change is positive (+616/+794) while the published 2014-2005 change is negative (-646.1/-543.6), as expected if the series kept falling to 2014. ")
rev=[]
for unit,extra in [
 ("T1|D Population","Reconstructed T 4,883.1 C 4,541.6 vs published 7,324.3 / 6,756.5; p 0.64 vs 0.62."),
 ("T1|D Households","Reconstructed T 1,455.5 C 1,214.5 vs 2,186.4 / 1,899.8."),
 ("T1|D Unemployed Pop.","Reconstructed T +615.6 C +793.3 vs published -646.1 / -543.6 (sign differs because the deposit ends in 2011, near the unemployment peak)."),
 ("T1|D Educ. Population","Reconstructed T 1,246.3 C 1,099.5 vs 1,995.9 / 1,884.8."),
 ("T1|D Male Population (18-45)","Both readings (popyoungmales, popmales) fail; popyoungmales 2005->2011 T 215.9 C 140.6 vs 555.3 / 410.5; young-male counts fall to 2009 then rise (d06), so the 2014 endpoint matters most here. Label-to-column pairing also unresolved (axis_ledger control_set)."),
 ("T1|D Income per Capita","Reconstructed T 2,258.5 C 1,997.5 vs 3,152.7 / 2,773.7; the difference is significant in both (p 0.001 vs 0.01)."),
]:
    rev.append({"unit":unit,"verdict":"overturned","reason_code":"source_vintage","evidence":T1_common+extra,
                "diagnostics_files":[A+"d06_table1_controls.py",A+"d06_table1_controls.out",A+"d13_table1_yearpairs.py",A+"d13_table1_yearpairs.out"]})
t2_common=("Scorer check correct for the frozen mapping (high_own = totaloldfocused1, low_own = focused5 - focused1 or focused5). "
 "The published Table 2 rows identify the deposit columns exactly: the Low Ownership max 20,595 is the maximum of totaloldfocused1, and the High Ownership max 1,268,382 is the maximum of totaloldfocused5 in the whole file, reached in county 25017 (Massachusetts) in 2009q1 (d01, d02). "
 "Table 7 (D01 p.19) labels the same columns the other way: published High -0.00847 (0.00574) matches focused1 (-0.0094, se 0.0061, S00051) and published Low -0.0357 (0.0173) matches focused5 (-0.0385, se 0.0185, S00338) or focused5-focused1 (-0.0303, S00052). The two published tables therefore assign the labels inconsistently. "
 "Table 2 statistics also include Massachusetts although its note says 'excluding Massachusetts' (D01 p.12): a balanced panel of all 3,109 county_lookup counties gives focused1 mean 2.003 sd 87.44 (published 2.00/87.47) and focused5 mean 123.44 sd 6,409.8 max 1,268,382 (published 123.52/6,411.82/1,268,382), and moves Total Contributions to 2,865.6 (published 2,867.80; frozen U 2,746.7) (d03). ")
rev.append({"unit":"T2|Low Ownership Contributions","verdict":"overturned","reason_code":"inconsistent_targets","secondary_reason_code":"measurement_mapping",
 "evidence":t2_common+"Under the Table 2 labelling the frozen-universe focused1 series gives mean 1.983 (r = 0.006, near) and median 0 (match), so the frozen-rule comparison would be consistent; the mismatch arises only from the label assignment, which Table 7 contradicts.",
 "diagnostics_files":[A+"d01_table2_columns.py",A+"d01_table2_columns.out",A+"d02_table2_sample.py",A+"d02_table2_sample.out",A+"d03_table2_alt_samples.py",A+"d03_table2_alt_samples.out"]})
rev.append({"unit":"T2|High Ownership Contributions","verdict":"overturned","reason_code":"inconsistent_targets","secondary_reason_code":"measurement_mapping",
 "evidence":t2_common+"Under the Table 2 labelling with the frozen universe the focused5 mean is 81.27 (still a mismatch); the remaining gap comes from the Massachusetts rows, which the stated sample excludes. With Massachusetts the mean is 123.44 (r < 0.001).",
 "diagnostics_files":[A+"d01_table2_columns.py",A+"d01_table2_columns.out",A+"d02_table2_sample.py",A+"d02_table2_sample.out",A+"d03_table2_alt_samples.py",A+"d03_table2_alt_samples.out"]})
rev.append({"unit":"F1|a","verdict":"overturned","reason_code":"inconsistent_targets",
 "evidence":("Scorer check: control 1,243 vs 1,256 = 1.04% > 1%, so discrepant_candidate under the frozen counts rule (treated 0.05%, all 0.39%). "
  "The published counts are internally inconsistent: Figure 1 / text give 1,851 treated and 1,256 control = 3,107 (D01 p.5), while the Table 1 header gives 1,851 and 1,242 = 3,093 (D01 p.8) and the text observation count 120,627 = 3,093 x 39 (D01 p.11) (Opus forensics). "
  "3,107 - 3,093 = 1,256 - 1,242 = 14 = the number of Massachusetts counties in county_lookup.csv. Adding the 14 Massachusetts counties as controls reproduces the Table 1 outcome rows (control Contributions 3,589.5 vs 3,593.3; difference -1,215.2 vs -1,217.7; Contributors 7.957 vs 7.966; Owner 203.5 vs 203.6; p values 0.000/0.053/0.265/0.207 vs 0.00/0.05/0.26/0.21), whereas the frozen non-MA universe gives control Contributions 3,301.6 (d10). "
  "So the published 3,107/1,256 counts include Massachusetts, contradicting the Figure 1 note and text that exclude it. Against the stated non-MA definition (Table 1 header 1,851/1,242) the reconstruction 1,852/1,243 is within 0.1%; against the MA-as-control universe it is 1,852/1,257 (d14). Either way the residual is one county per group (near), not a 1% discrepancy."),
 "diagnostics_files":[A+"d10_universe_MA.py",A+"d10_universe_MA.out",A+"d14_counts_MA.py",A+"d14_counts_MA.out"]})
rev.append({"unit":"F2|a","verdict":"overturned","reason_code":"inconsistent_targets",
 "evidence":("Scorer check correct: reconstructed boundary sample 2,214 (1,228 T, 986 C) vs text/Figure 2 note 1,820 (1,096 T, 724 C) (D01 p.8-9). "
  "The article assigns the two sample sizes inconsistently: Table 5 Panel B labels the 2,218-county columns 'Boundary sample' and the 1,820-county columns 'Timing sample' (D01 p.17), the reverse of the text and Figure 2 note (Opus forensics, Table 5 Panel B N vs text). "
  "The deposit supports the Panel B assignment: the boundary rule gives 2,214 counties with exactly 1,228 treated (published 2,218 = 1,228 T + 990 C), and Table 6 boundary N is 58,470 pairs vs published 58,715, which is reproduced exactly (58,715) when the 14 Massachusetts counties are kept with their lookup coding (d11). "
  "Under the Panel B / Table 6 labelling the count is within 1% (treated exact, control 986 vs 990, all 2,214 vs 2,218), which the frozen rule would score indeterminate: near."),
 "diagnostics_files":[A+"d04_sample_counts.py",A+"d04_sample_counts.out",A+"d11_table6_MA.R",A+"d11_table6_MA.out",A+"d14_counts_MA.py",A+"d14_counts_MA.out"]})
rev.append({"unit":"F2|b","verdict":"survives","reason_code":None,
 "evidence":("Scorer check correct: reconstructed timing sample 1,568 (589 T, 979 C) vs published 2,218 (1,228 T, 990 C) in the text (D01 p.9). "
  "Labelling is inconsistent (Table 5 Panel B gives the timing sample 1,820 counties), but the reconstruction matches neither: vs 1,820 (1,096 T, 724 C) it is also off by more than 1% in every count. "
  "The deposit has one date column, 'Sch SB Delivery', which matches the article's 'date on which a particular county was scheduled to be sent to Harris' (D01 p.10); 1,841 of 1,852 treated counties are scheduled by the end of 2005, as the text says, but only 589 treated counties fall in calendar 2005-2006 (d04). "
  "No calendar or fiscal-year window with a textual basis reproduces either published split; the closest arbitrary window (June 2004 to June 2006) gives 1,097 T / 712 C, with no textual basis (d05). Adding Massachusetts changes counts by 13 (d14). "
  "Remaining uncertainty: the deposit has no dictionary for timing.xlsx, and the file came from the Census Bureau by personal communication, so a different vintage of the schedule cannot be excluded; this is not documented anywhere."),
 "diagnostics_files":[A+"d04_sample_counts.py",A+"d04_sample_counts.out",A+"d05_timing_windows.py",A+"d05_timing_windows.out",A+"d14_counts_MA.py",A+"d14_counts_MA.out"]})
t5_common=("Independent re-implementation (fixest, d09) reproduces the frozen A/B estimates to 1e-10 (boundary FO -0.11756, boundary contributors -0.03995, timing FO -0.17598, timing contributors -0.01296). "
 "Published Panel A is internally inconsistent: the two 'Boundary sample' columns have different N (86,502 = 2,218 x 39 for follow-on; 70,980 = 1,820 x 39 for contributors), and so do the two 'Timing sample' columns (D01 p.17; Opus forensics). "
 "The published SEs follow the N row, not the headers: col 5 0.0563 and col 6 0.0634 are follow-on-sized, col 7 0.0194 and col 8 0.0227 are contributor-sized (full-sample DTT: follow-on 0.0469, contributors 0.0144). "
 "Reading the N row together with Panel B and Table 6 (boundary = 2,218, timing = 1,820), the columns are boundary FO, timing FO, boundary contributors, timing contributors (layout L1). The reconstructed CR1 SEs follow L1 closely (0.0516, 0.0620, 0.0156, 0.0198 vs published 0.0563, 0.0634, 0.0194, 0.0227); under the printed headers col 6 and col 7 SEs differ by factors of about 4 and 3. "
 "z under L1 (with controls / without): col 5 0.30/0.15, col 6 1.66/1.04, col 7 0.33/0.22, col 8 2.93/2.65. Under the text labelling (L2: boundary = 1,820) z is 0.72, 2.59, 1.06, 1.74 (d09). ")
rev.append({"unit":"T5A|(6)","verdict":"overturned","reason_code":"inconsistent_targets",
 "evidence":"Scorer check: z = (0.282-0.0005-0.03995)/0.0634 = 3.81, band CR1 1 vs published 0; no uncertain row within z 2; rule applied correctly. "+t5_common+
  "Col 6 is labelled boundary contributors but its N (1,820 x 39) and SE identify the timing follow-on model; against that model the reconstruction is in the grey zone (z 1.66, p 0.005, same band), so the frozen comparison is with a mislabelled target.",
 "diagnostics_files":[A+"d09_table5A.R",A+"d09_table5A.out",A+"d09_table5A_layouts.csv",A+"d09_table5A_estimates.csv"]})
rev.append({"unit":"T5A|(7)","verdict":"overturned","reason_code":"inconsistent_targets",
 "evidence":"Scorer check: z = (0.17598-0.00005-0.0335)/0.0194 = 7.34; uncertain rows -0.163 to -0.347 all fail; rule applied correctly. "+t5_common+
  "Col 7 is labelled timing follow-on but its N (2,218 x 39) and contributor-sized SE identify the boundary contributors model; against it the reconstruction matches (-0.0400 vs -0.0335, z 0.33, p 0.010 stronger than published *).",
 "diagnostics_files":[A+"d09_table5A.R",A+"d09_table5A.out",A+"d09_table5A_layouts.csv",A+"d09_table5A_estimates.csv"]})
rev.append({"unit":"T5A|(8)","verdict":"survives","reason_code":None,
 "evidence":"Scorer check: z = (0.0795-0.00005-0.01296)/0.0227 = 2.93; CR1 p 0.51 (band 3) vs published *** (band 0); HC1 p 0.054; uncertain rows -0.0067 to -0.0193 all fail. "+t5_common+
  "Col 8 is timing contributors under both the printed headers and the N/SE-implied layout L1, and fails under both (z 2.93, three bands weaker). Only the text-based layout L2, which the deposit contradicts (the boundary rule gives 2,214, not 1,820 counties), puts it in the grey zone. The likely root cause is the unreproduced timing sample (F2|b: 1,568 vs 1,820/2,218 counties), so this candidate is not independent of F2|b. The N gap (56,365 vs 70,980) partly reflects missing income_medianearnings in deposit acsyear 2011; the no-controls fit (N 61,152) still fails (z 2.65).",
 "diagnostics_files":[A+"d09_table5A.R",A+"d09_table5A.out",A+"d09_table5A_layouts.csv",A+"d09_table5A_estimates.csv",A+"d04_sample_counts.out"]})
t6_common=("Independent re-implementation (d08) reproduces the frozen estimates exactly (full -0.10794 / dist 0.05202; boundary -0.08980 / 0.05090; timing -0.09216 / 0.04932). "
 "The deposited distance data are the published ones: Table 1 Error-Score treated mean 1,830.18 vs published 1,830.2; 2,312 counties (1,325 T / 987 C) and 98,711 pairs match D01 p.11 exactly (d07). Distances are in metres (Google/geodesic-km ratio 1,349). "
 "Adding the 14 Massachusetts counties (which have 685 pairs in distance.csv) reproduces the published N exactly: full 81,007 and boundary 58,715 (with lookup coding), so the author's sample, including its control missingness pattern (deposit acsyear 2011 income_medianearnings), is reproduced; the estimates stay negative (full -0.103 to -0.112, boundary -0.086 to -0.090, timing -0.086 to -0.099) (d11). "
 "No reading with a textual basis gives a positive Treat: raw difference -0.053, FE only -0.107, controls only -0.081, all 35 frozen uncertain rows negative (max -0.0005), percent-male controls ('percent of males', D01 p.18) -0.091 to -0.099, ACS 2008 controls -0.107 to -0.109, county-mean logged error (D01 p.11 wording; non-equivalent W2) -0.135 (d08, d15). The signed log ratio ln(OSRM/Google) gives 0.001 (n.s.). "
 "Diagnostic only (no textual basis, not a legitimate reading): a reversed treatment coding would give +0.103 to +0.112 (full) and +0.086 to +0.090 (boundary), close to the published values; this cannot be checked before unsealing and, if it were the cause, would be an error in the published pipeline, not a reconstruction error. ")
for col,pub,est,z,N,Np in [("1","0.126 (0.0708) *","-0.1079 (CR1 0.0333, p 0.001)","3.30","80,370","81,007"),
                           ("2","0.149 (0.0800) *","-0.0898 (CR1 0.0370, p 0.015)","2.98","58,470","58,715"),
                           ("3","0.297 (0.0915) ***","-0.0922 (CR1 0.0425, p 0.030)","4.25","43,404","49,095")]:
    extra = " The timing sample itself is not reproduced (F2|b), which adds to the N gap, but the sign also flips in columns 1-2 where the sample is reproduced." if col=="3" else ""
    rev.append({"unit":f"T6|({col}) Treat","verdict":"survives","reason_code":None,
      "evidence":f"Scorer check: published {pub} vs reconstructed {est}; sign opposite, z {z}; N {N} vs {Np}; rule applied correctly. "+t6_common+extra,
      "diagnostics_files":[A+"d07_distance_units.py",A+"d07_distance_units.out",A+"d08_table6.R",A+"d08_table6.out",A+"d08_table6_results.csv",A+"d11_table6_MA.R",A+"d11_table6_MA.out",A+"d15_table6_pctmales.R",A+"d15_table6_pctmales.out"]})
for col,pub,est,zk,zm in [("1","0.0340 (0.00262)","0.05202","6.86","18.95"),("2","0.0339 (0.00292)","0.05090","5.81","16.43"),("3","0.0376 (0.00320)","0.04932","3.65","13.04")]:
    rev.append({"unit":f"T6|({col}) Distance","verdict":"survives","reason_code":None,
      "evidence":(f"Scorer check: published {pub} vs reconstructed {est} per km; z {zk} (km) and {zm} (miles, coefficient x 1.609344); frozen special rule applied correctly. "
        "Units: the text gives a geodesic distance with no unit (D01 p.18). km and miles both fail, and miles is further away. Other constructions, all without a textual basis, also fail: Google route km 0.0411 (z 2.68), haversine with latitude and longitude swapped 0.0404 (z 2.41), log km 0.867, Euclidean degrees 4.87 (d12). The coefficient is stable across controls, universe and samples (0.048-0.052) and does not depend on the units of the error outcome. "
        "The published N is reproduced exactly with Massachusetts included (81,007; boundary 58,715) and the coefficient is unchanged (0.0521, 0.0509), so the sample does not explain it. This is a nuisance coefficient; it survives as a genuine mismatch of the same model that flips the Treat sign."),
      "diagnostics_files":[A+"d07_distance_units.py",A+"d07_distance_units.out",A+"d08_table6.R",A+"d08_table6.out",A+"d11_table6_MA.R",A+"d11_table6_MA.out",A+"d12_table6_distance_constructions.R",A+"d12_table6_distance_constructions.out"]})
meta={"review":"adversarial_v1","status":"pre-unsealing adversarial diagnostic; author package and setup exposure detail not opened",
 "reviewer":"Claude Code subagent, Claude Opus 5.5 (claude-opus-5-5), same model family as implementation A and Reader A; no family-independent review was available",
 "runtime":{"python":"3.13.16, pandas 2.3.3, scipy 1.17.1","R":"4.6.1, fixest 0.14.2","network":"all diagnostics run under sandbox-exec deny network*"},
 "inputs_read":["scoring/scoring_rules_v1.json","scoring/claims_v1.json","reconciliation/axis_ledger_v1.json","manifest/implementation_manifest_v1.md","manifest/grid_v1.csv","runs/run_20261101_v1/scoring/claim_scores.json","runs/run_20261101_v1/out/A/results.csv","runs/run_20261101_v1/out/A/an02_summary.csv","runs/run_20261101_v1/out/A/prep_log.json","runs/run_20261101_v1/code/A_run_analysis.R (P6, P7, AN07 sections)","readers/opus/initial_v1/forensics.json","readers/astra/initial_v1/forensics.json","packet/frozen_v1/D01_article.txt","packet/deposit_data_notes.txt","packet/frozen_v1/D4x column files","data/derived/run_input_v1/*"],
 "verdict_counts":{},
 "note":"Diagnostics cannot change frozen scores. Overturned units become indeterminate with the reason code; surviving units become discrepant with the caveat that no family-independent adversarial review was available. Verdicts give one primary reason code; a secondary code is given where two apply.",
 "out_of_scope_observation":"The Table 2 vs Table 7 ownership labelling conflict and the Massachusetts inclusion in the published 3,107-county universe also bear on non-candidate claims (Table 2 Total Contributions, Distant Follow-on; Table 7 cols 5-6; full-sample N 121,173 = 3,107 x 39). They are not re-scored here."}
from collections import Counter
meta["verdict_counts"]=dict(Counter(r["verdict"] for r in rev)); meta["reason_counts"]=dict(Counter(r["reason_code"] for r in rev if r["reason_code"]))
assert len(rev)==20
json.dump({"meta":meta,"units":rev},open(A+"review.json","w"),indent=1)
print(meta["verdict_counts"],meta["reason_counts"])
