# Coverage audit: NOS 1991 (ICPSR 6240 V1) for Delaney and Huselid (1996)

Scope: this audit records which source variables cover each construct in the article's Measures and Controls description. No sample was constructed, no scales were computed and no models were fitted. It contains no frequencies, means or case counts. Where several candidates exist, all are listed and none is chosen.

| Construct | Status | Candidates | Alternatives / related |
|---|---|---|---|
| Perceived organizational performance (7 items) | covered | V289, V290, V291, V292, V293, V294, V295 | - |
| Perceived market performance (4 items) | covered | V296, V297, V298, V299 | - |
| Staffing selectivity (3 occupations) | covered_with_ambiguity | V62, V97, V131 | V50, V85, V119, V79, V114, V63, V98, V132 |
| Training index (3 items) | covered_with_ambiguity | V145, V157, V172 | V158, V159, V160, V154, V156 |
| Incentive compensation (3 items) | covered_with_ambiguity | V209, V222, V235 | V184, V186 |
| Grievance procedure (dummy) | covered | V270 | - |
| Decentralized decision making (8 items) | ambiguous | V271, V272, V273, V274, V275, V276, V277, V278, V279, V280, V281, V282, V283, V284, V285, V286 | - |
| Internal labor market (5 items) | covered_with_ambiguity | V67, V76, V102, V111, V136 | V74, V109, V143, V77, V112 |
| Vertical hierarchy (levels) | covered | V261 | - |
| Nonprofit organization (dummy) / for-profit indicator | covered_with_ambiguity | V8 | V12, V14, V15, V9 |
| Subsidiary (dummy) | ambiguous | V17, V21 | - |
| Log of total employment | ambiguous | V23, V32, NEWFULL, NEWPART, NEWTOTAL | V339, V45 |
| Firm age | covered_with_ambiguity | V16 | V340, V20 |
| Market competition | covered | V328 | V329, V330 |
| Product / service dummies (omitted: both) | covered | V41 | - |
| Union pressure index (multi-item, perceived union influence on management) | ambiguous_partial | V220, V233, V300 | V166, PCTUNION, ORGEFF1, UNFAIR, UNION, MEMUNION |
| Percent managers | ambiguous | V115, V23, V32, NEWTOTAL | V114, V45, V80 |
| Two-digit SIC industry dummies | partial_requires_crosswalk | V43, INDUSTRY | INDUS80, OCC80 |
| Sampling weights | available | WEIGHT, RAWWGT | NEWTOTAL, FORMWT, OVERSAMP |
| Respondent unit and duplicate employer records | ambiguous | V1, V3, DUP, NUMOBS, V6, RSSOC | - |

## Perceived organizational performance (7 items)

Article: Seven items: performance over the past 3 years relative to similar organizations; Likert 1 'worse' to 4 'much better'.

Status: covered

Issues:

- Stored coding runs 1 = much better, 2 = somewhat better, 3 = about the same, 4 = worse, the reverse of the article's stated 1 = worse to 4 = much better. Reversal is a recode, not a source gap.
- Codes 7 (not applicable), 8 (don't know) and 9 (no response) are declared missing.
- Asked of all organizations (Q.75).

Variables:

- V289 (candidate; pos. 929; F1.0): Q.75a  Perform/quality of prodts-service. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V290 (candidate; pos. 930; F1.0): Q.75b  Perform/development of new prodts. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V291 (candidate; pos. 931; F1.0): Q.75c  Perform/ability to attract emplys. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V292 (candidate; pos. 932; F1.0): Q.75d  Perform/ability to retain emplyes. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V293 (candidate; pos. 933; F1.0): Q.75e  Perform/satisfaction of customers. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V294 (candidate; pos. 934; F1.0): Q.75f  Perform/relation btwn mgmnt-emply. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V295 (candidate; pos. 935; F1.0): Q.75g  Perform/relations among employees. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

## Perceived market performance (4 items)

Article: Four items, profit-making organizations only: marketing, growth in sales, profitability, market share relative to competitors over the past 3 years.

Status: covered

Issues:

- Universe: Box F, profit-making organizations only. Q.76 is skipped for others.
- Same reversed stored coding and 7/8/9 declared missing as Q.75.

Variables:

- V296 (candidate; pos. 936; F1.0): Q.76a  Performance/marketing. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V297 (candidate; pos. 937; F1.0): Q.76b  Performance/growth in sales. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V298 (candidate; pos. 938; F1.0): Q.76c  Performance/profitability. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V299 (candidate; pos. 939; F1.0): Q.76d  Performance/market share. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

## Staffing selectivity (3 occupations)

Article: Applications considered per opening in the past 2 years for CORE, GSS-respondent occupation and managers; standardized logged values averaged.

Status: covered_with_ambiguity

Issues:

- Asked only if the organization hired from outside in the past 2 years (V50 CORE, V85 GSS, V119 managers). Otherwise system-missing.
- The GSS block is skipped when the GSS occupation equals CORE (Box A, V79 = 2). The manager block is skipped when CORE or GSS is a manager (Box B, V114 = 2). Treatment of such organizations is not specified by the source.
- Code 995 'large number of applications' is declared missing in the .por but is substantive. Code 997 'not applicable' is not declared missing. Zero values and the log transform need a rule.
- The article says 'applicants considered for each position'. The NOS wording is 'applications considered for each opening'. Related items: applicants interviewed (V63, V98, V132).

Variables:

- V62 (candidate; pos. 702; F3.0): Q.13  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
- V97 (candidate; pos. 737; F3.0): Q.23  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
- V131 (candidate; pos. 771; F3.0): Q.32  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
- V50 (alternative_or_related; pos. 690; F1.0): Q.11a  Hired COREs from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V85 (alternative_or_related; pos. 725; F1.0): Q.21a  Hired GSSs from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V119 (alternative_or_related; pos. 759; F1.0): Q.30a  Hired mngr from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V79 (alternative_or_related; pos. 719; F1.0): Q.19a  GSSs work for ORG on March 1 1991. Declared missing: 8, 9. Codes: 1 = Yes; 2 = Yes but same as core; 3 = No; 8 = Do not know; 9 = No response/refused.
- V114 (alternative_or_related; pos. 754; F1.0): Q.29a  Mngr/admin on payroll on Mar 1 91. Declared missing: 8, 9. Codes: 1 = Yes; 2 = Yes but sam core/gss; 3 = No; 8 = Do not know; 9 = No response/refused.
- V63 (alternative_or_related; pos. 703; F3.0): Q.14a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
- V98 (alternative_or_related; pos. 738; F3.0): Q.24a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
- V132 (alternative_or_related; pos. 772; F3.0): Q.33a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.

## Training index (3 items)

Article: Any formal job training in past 2 years; number of employees receiving formal training; training effectiveness 1 'not at all' to 3 'highly effective'; standardized and averaged.

Status: covered_with_ambiguity

Issues:

- V145 = no or don't know skips Q.38-Q.52, so V157 and V172 are system-missing for organizations without formal training. Treatment of these (e.g. zero or missing) is not specified by the source.
- V157 is a raw count of participants (99996 = top code '100,000+', not declared missing). The article does not say whether a proportion of employment or a log was used.
- V172 stored coding is 1 = highly effective, 2 = somewhat, 3 = not at all, the reverse of the article's scale. Code 4 'varies/depends' is not declared missing. 8 and 9 are declared missing.
- V145 coding is 1 = yes, 2 = no.

Variables:

- V145 (candidate; pos. 785; F1.0): Q.37  Provide formal job training. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V157 (candidate; pos. 797; F5.0): Q.45a  Number of emplys prtcptd training. Declared missing: 99998, 99999. Codes: 99996 = 100,000 employees +; 99998 = Do not know; 99999 = No response/refused.
- V172 (candidate; pos. 812; F1.0): Q.49  Effectiveness of training. Declared missing: 8, 9. Codes: 1 = Highly effective; 2 = Somewhat effective; 3 = Not at all effective; 4 = Varies/depends; 8 = Do not know; 9 = No response/refused.
- V158 (alternative_or_related; pos. 798; F1.0): Q.45b1  Receive formal training / COREs. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V159 (alternative_or_related; pos. 799; F1.0): Q.45b2  Receive formal training / GSSs. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V160 (alternative_or_related; pos. 800; F1.0): Q.45b3  Receive formal training/ mgr-adm. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V154 (alternative_or_related; pos. 794; F7.0): Q.42  Cost ORG spent on training in 2yrs. Declared missing: 9999998, 9999999. Codes: 9999996 = $10,000,000 or more; 9999999 = No response/refused.
- V156 (alternative_or_related; pos. 796; F1.0): Q.44  ORG devt more/less resrc to traing. Declared missing: 8, 9. Codes: 1 = More resources; 2 = Fewer resources; 3 = About the same; 8 = Do not know; 9 = No response/refused.

## Incentive compensation (3 items)

Article: Importance of job performance in determining earnings for the three occupational groups.

Status: covered_with_ambiguity

Issues:

- V209 = managers (Q.61b), V222 = CORE (Q.63c), V235 = GSS (Q.65c). Stored coding 1 = very important, 2 = somewhat, 3 = not important, so higher means less important.
- V209 and V235 declare 7 (not applicable) missing. V222 has no code 7.
- GSS earnings items are skipped by Box D when the GSS occupation equals CORE or manager. Manager items depend on Q.29 routing.

Variables:

- V209 (candidate; pos. 849; F1.0): Q.61b  Importance/job performance. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V222 (candidate; pos. 862; F1.0): Q.63c  Importance/job performance. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
- V235 (candidate; pos. 875; F1.0): Q.65c  Importance/job performance. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V184 (alternative_or_related; pos. 824; F1.0): Q.53h  Benefit/cash/stock bonus fr pfmnc. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V186 (alternative_or_related; pos. 826; F1.0): Q.53j  Benefit/profit-sharing program. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

## Grievance procedure (dummy)

Article: Formal procedure for resolving disputes between employees and supervisors or co-workers; 0 = no, 1 = yes.

Status: covered

Issues:

- Stored 1 = yes, 2 = no. Codes 7 (NA), 8 and 9 are declared missing. A recode to 0/1 is needed.

Variables:

- V270 (candidate; pos. 910; F1.0): Q.71  Formal procedrs for reslvng dispts. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

## Decentralized decision making (8 items)

Article: Who makes final decisions in 8 areas (number employed, hiring, subcontractors/temporaries, evaluation, promotions, wages, discharge/layoff, scheduling/overtime); lowest if CEO, higher if someone lower.

Status: ambiguous

Issues:

- The same 8 decision areas are stored in two sets. Q.72a (V271-V278) is for organizations that are part of a larger organization; its options are head of ORG, someone below, someone at larger org and combinations. Q.72b (V279-V286) is for independent organizations. Combining the two sets is required and not specified by the source.
- Codes 3 (larger org / above), 4 (head and below), 5 (head and larger org / above) and 6 (depends) have no stated position on the article's ordering. Only 'CEO lowest, someone lower higher' is described.
- The codebook's printed Q.72b response codes (1, 2, 3, 4, 7, 8) differ from the .por value labels (3 = someone above, 5 = head and above, 6 = depends).
- Codes 7, 8 and 9 are declared missing.

Variables:

- V271 (candidate; pos. 911; F1.0): Q.72a1  Larger ORG/nmbr of people emplyd. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V272 (candidate; pos. 912; F1.0): Q.72a2  Larger ORG/new employees to hire. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V273 (candidate; pos. 913; F1.0): Q.72a3  Larger ORG/subcntrctrs-temporary. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V274 (candidate; pos. 914; F1.0): Q.72a4  Larger ORG/evaltg wkr perfrmace. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V275 (candidate; pos. 915; F1.0): Q.72a5  Larger ORG/worker promotions. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V276 (candidate; pos. 916; F1.0): Q.72a6  Larger ORG/wage rate-salary lvls. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V277 (candidate; pos. 917; F1.0): Q.72a7  Larger ORG/dischg-layng off wrks. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V278 (candidate; pos. 918; F1.0): Q.72a8  Larger ORG/scheduling - overtime. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V279 (candidate; pos. 919; F1.0): Q.72b1  ORG/number of people employed. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V280 (candidate; pos. 920; F1.0): Q.72b2  ORG/new employees to hire. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V281 (candidate; pos. 921; F1.0): Q.72b3  ORG/subcntrctrs-temporary workrs. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V282 (candidate; pos. 922; F1.0): Q.72b4  ORG/evaluating worker perfrmace. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V283 (candidate; pos. 923; F1.0): Q.72b5  ORG/worker promotions. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V284 (candidate; pos. 924; F1.0): Q.72b6  ORG/wage rate or salary levels. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V285 (candidate; pos. 925; F1.0): Q.72b7  ORG/discharging-laying off wrkrs. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V286 (candidate; pos. 926; F1.0): Q.72b8  ORG/worker scheduling - overtime. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

## Internal labor market (5 items)

Article: Five yes/no items on promotion from within (fill CORE vacancies internally, CORE promotable above CORE, fill GSS vacancies internally, GSS promotable above GSS, fill managerial vacancies internally); coded yes = 2, no = 1.

Status: covered_with_ambiguity

Issues:

- Stored 1 = yes, 2 = no, the reverse of the article's yes = 2, no = 1.
- The GSS items (V102, V111) are skipped when the GSS occupation equals CORE. The manager item (V136) is skipped when managers equal CORE or GSS, or when there are none. Handling of these structural skips is unspecified.
- 8 and 9 are declared missing.

Variables:

- V67 (candidate; pos. 707; F1.0): Q.16a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V76 (candidate; pos. 716; F1.0): Q.18a  Possible to be promtd above COREs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V102 (candidate; pos. 742; F1.0): Q.26a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V111 (candidate; pos. 751; F1.0): Q.28a  Possible to be promtd above GSSs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V136 (candidate; pos. 776; F1.0): Q.35a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V74 (alternative_or_related; pos. 714; F1.0): Q.17a  There are diffrnt levels of COREs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V109 (alternative_or_related; pos. 749; F1.0): Q.27a  There are diffrnt levels of GSSs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V143 (alternative_or_related; pos. 783; F1.0): Q.36a  There are diffrnt levels of mngrs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- V77 (alternative_or_related; pos. 717; F1.0): Q.18b  Freq of promotion above COREs. Declared missing: 8, 9. Codes: 1 = Very often; 2 = Often; 3 = Not very often; 8 = Do not know; 9 = No response/refused.
- V112 (alternative_or_related; pos. 752; F1.0): Q.28b  Freq of promotion above GSSs. Declared missing: 8, 9. Codes: 1 = Very often; 2 = Often; 3 = Not very often; 8 = Do not know; 9 = No response/refused.

## Vertical hierarchy (levels)

Article: Number of occupation levels between highest and lowest jobs (Table 1 note: value is a logarithm).

Status: covered

Issues:

- Code 96 = '100 levels or more' (top code, not declared missing). 98 and 99 are declared missing.

Variables:

- V261 (candidate; pos. 901; F2.0): Q.69  Number of vertcl levels btwn postn. Declared missing: 98, 99. Codes: 96 = 100 levels or more; 98 = Do not know; 99 = No response/refused.

## Nonprofit organization (dummy) / for-profit indicator

Article: Dummy for nonprofit vs. for-profit; market performance available only for profit-making organizations.

Status: covered_with_ambiguity

Issues:

- V8: 1 = for profit, 2 = not for profit, with no declared missing codes.
- Government agencies and public institutions answer V8 = not for profit. Related items V12 (kind of organization), V14 (government level) and V15 (public/private) could distinguish public-sector organizations. Whether to do so is not specified.

Variables:

- V8 (candidate; pos. 649; F1.0): Q.1a  Profit / non - profit organization. Declared missing: none. Codes: 1 = For profit; 2 = Not for profit org.
- V12 (alternative_or_related; pos. 653; F1.0): Q.2a  Kind of ORG. Declared missing: 8, 9. Codes: 1 = Elem/junior/high sch; 2 = Coll/univ/junior col; 3 = Hospital; 4 = Social service agncy; 5 = Governmental agency; 6 = Something else; 8 = Do not know; 9 = No response/refused.
- V14 (alternative_or_related; pos. 655; F1.0): Q.2b  ORG is local/state/federal agency. Declared missing: 8, 9. Codes: 1 = Local; 2 = State; 3 = Federal agency; 8 = Do not know; 9 = No response/refused.
- V15 (alternative_or_related; pos. 656; F1.0): Q.2c  ORG is public / private. Declared missing: 8, 9. Codes: 1 = Public; 2 = Private; 8 = Do not know; 9 = No response/refused.
- V9 (alternative_or_related; pos. 650; F1.0): Q.1b  Legal form of ORG. Declared missing: 8, 9. Codes: 1 = Sole proprietorship; 2 = Partnership; 3 = Franchise; 4 = Corp-publ held stock; 5 = Corp-priv held stock; 6 = Something else; 8 = Do not know; 9 = No response/refused.

## Subsidiary (dummy)

Article: Dummy for whether an organization is a subsidiary of another organization.

Status: ambiguous

Issues:

- V17 (Q.4a) = part of a larger organization vs. completely independent.
- V21 (Q.4e) gives the form of affiliation for affiliated organizations: wholly owned branch, wholly owned subsidiary, locally owned franchise, school in school system, campus, governmental unit, other.
- A 'subsidiary' dummy could be V17 = 1, or V21 = 2 only, or another grouping.

Variables:

- V17 (candidate; pos. 658; F1.0): Q.4a  ORG is part of large ORG/indepndnt. Declared missing: none. Codes: 1 = Part of larger org; 2 = Completely indepndnt.
- V21 (candidate; pos. 662; F1.0): Q.4e  Way ORG is part of larger ORG. Declared missing: 8, 9. Codes: 1 = Whol owned brnch fac; 2 = Whol owned subsdiary; 3 = Locally ownd franchs; 4 = School in schl systm; 5 = Campus higher ed sys; 6 = Governmental unit; 7 = Something else; 8 = Do not know; 9 = No response/refused.

## Log of total employment

Article: Natural log of the number of employees in the organization.

Status: ambiguous

Issues:

- V23 counts full-time and V32 part-time employees at the establishment (ORG) as of 1 March 1991. 99998 and 99999 are declared missing.
- NEWFULL, NEWPART and NEWTOTAL are 'assigned values' created by the NOS team for weighting. The assignment rule is undocumented.
- V339 counts employees of the LARGER ORG, asked only of affiliated organizations. 'Organization' could mean either level.
- Whether part-time employees are included is not stated in the article.

Variables:

- V23 (candidate; pos. 664; F5.0): Q.5a  Number of full time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- V32 (candidate; pos. 673; F5.0): Q.5a  Number of part time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- NEWFULL (candidate; pos. 998; F8.2): ASSIGNED VALUES FOR FULL-TIME WORKERS. Declared missing: 99998, 99999.
- NEWPART (candidate; pos. 999; F8.2): ASSIGNED VALUES FOR PART-TIME WRKERS. Declared missing: 99998, 99999.
- NEWTOTAL (candidate; pos. 1000; F8.2): TOTAL EMPLOYEES BASED ON ASSIGNED. Declared missing: none.
- V339 (alternative_or_related; pos. 979; F7.0): Q.92  Total number of full/part employes. Declared missing: 9999998, 9999999. Codes: 9999998 = Do not know; 9999999 = No response/refused.
- V45 (alternative_or_related; pos. 685; F5.0): Q.9a  Number of total COREs work for ORG. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

## Firm age

Article: 1991 minus founding year.

Status: covered_with_ambiguity

Issues:

- V16 = year the ORG was first established (probe: at any location). 9998 and 9999 are declared missing.
- V340 = year the LARGER ORG was first established (affiliated organizations only). V20 = year (or duration) of affiliation. Which applies to affiliated establishments is not specified.

Variables:

- V16 (candidate; pos. 657; F4.0): Q.3  Year ORG was first established. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.
- V340 (alternative_or_related; pos. 980; F4.0): Q.93  Year larger ORG first establised. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.
- V20 (alternative_or_related; pos. 661; F4.0): Q.4d  Year ORG affiliated w/larger ORG. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.

## Market competition

Article: Amount of competition in primary product/service market, 1 = none to 4 = a great deal.

Status: covered

Issues:

- Stored 1 = none, 2 = very little, 3 = moderate, 4 = a great deal, matching the article's direction. 7 (NA), 8 and 9 are declared missing.

Variables:

- V328 (candidate; pos. 968; F1.0): Q.86  Competition in main mkt/serv area. Declared missing: 7, 8, 9. Codes: 1 = None; 2 = Very little; 3 = Moderate amount; 4 = A great deal; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V329 (alternative_or_related; pos. 969; F1.0): Q.87  Competition in area fm foreign org. Declared missing: 7, 8, 9. Codes: 1 = None; 2 = Very little; 3 = Moderate amount; 4 = A great deal; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V330 (alternative_or_related; pos. 970; F1.0): Q.88  Amount of competition in past 3yrs. Declared missing: 7, 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Stayd about the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

## Product / service dummies (omitted: both)

Article: Dummies for producing a product or delivering a service; omitted category = both.

Status: covered

Issues:

- Stored 1 = produces a product, 2 = delivers a service, 3 = both, 4 = neither. 8 and 9 are declared missing. Code 4 'neither' is not declared missing.

Variables:

- V41 (candidate; pos. 682; F1.0): Q.8a  Kind of work ORG does. Declared missing: 8, 9. Codes: 1 = Produces a product; 2 = Delivers a service; 3 = Both; 4 = Neither; 8 = Do not know; 9 = No response/refused.

## Union pressure index (multi-item, perceived union influence on management)

Article: Index of respondents' perception of the influence of unions on their organization (alpha reported); 'the only measure of union influence available in the NOS'.

Status: ambiguous_partial

Issues:

- No NOS item asks directly about union influence on management. The establishment-level items that mention unions are:
- - V220: importance of union negotiations for CORE earnings (Q.63a).
- - V233: the same for GSS earnings (Q.65a; skipped by Box D).
- - V300: relations with unions as a problem over the next 3 years (Q.77a).
- - V166: whether formal training is offered because of union contracts (Q.47b; training block only).
- Which items formed the article's index, and how many, cannot be determined from the source. Candidate coding directions differ.
- Industry-level union measures (PCTUNION, ORGEFF1, UNFAIR) and the GSS respondent's own union membership (UNION, MEMUNION) are not perceptions of the establishment informant.

Variables:

- V220 (candidate; pos. 860; F1.0): Q.63a  Importance/union negotiations. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
- V233 (candidate; pos. 873; F1.0): Q.65a  Importance/union negotiations. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V300 (candidate; pos. 940; F1.0): Q.77a  Problem/relations with unions. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
- V166 (alternative_or_related; pos. 806; F1.0): Q.47b  Reason/union contract. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
- PCTUNION (alternative_or_related; pos. 38; F8.2): % WORKERS BELONGING TO UNIONS. Declared missing: -999.
- ORGEFF1 (alternative_or_related; pos. 29; F8.2): % ELIGIBLE VOTERS IN NLRB ELECTIONS. Declared missing: -999.
- UNFAIR (alternative_or_related; pos. 30; F8.2): NLRB UNFAIR LABOR PRAC CASES PER EMP. Declared missing: -999.
- UNION (alternative_or_related; pos. 273; F1.0): DOES R OR SPOUSE BELONG TO UNION. Declared missing: 0, 8, 9. Codes: 0 = NAP; 1 = R BELONGS; 2 = SPOUSE BELONGS; 3 = R AND SPOUSE BELONG; 4 = NEITHER BELONGS; 8 = DK; 9 = NA.
- MEMUNION (alternative_or_related; pos. 367; F1.0): MEMBERSHIP IN LABOR UNION. Declared missing: 0, 8, 9. Codes: 0 = NAP; 1 = YES; 2 = NO; 8 = DK; 9 = NA.

## Percent managers

Article: Percentage of employees in managerial occupations (relative managerial employment).

Status: ambiguous

Issues:

- The numerator V115 (number of managers and administrators, Q.29b) is asked only when managers exist and are not the same occupation as CORE or GSS (V114 = 1). When V114 = 2 the managerial count is in V45 (CORE) or V80 (GSS). When V114 = 3 there are none.
- Denominator candidates are the same as for total employment.

Variables:

- V115 (candidate; pos. 755; F5.0): Q.29b  Number of full and part-time mngr. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- V23 (candidate; pos. 664; F5.0): Q.5a  Number of full time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- V32 (candidate; pos. 673; F5.0): Q.5a  Number of part time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- NEWTOTAL (candidate; pos. 1000; F8.2): TOTAL EMPLOYEES BASED ON ASSIGNED. Declared missing: none.
- V114 (alternative_or_related; pos. 754; F1.0): Q.29a  Mngr/admin on payroll on Mar 1 91. Declared missing: 8, 9. Codes: 1 = Yes; 2 = Yes but sam core/gss; 3 = No; 8 = Do not know; 9 = No response/refused.
- V45 (alternative_or_related; pos. 685; F5.0): Q.9a  Number of total COREs work for ORG. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
- V80 (alternative_or_related; pos. 720; F5.0): Q.19b  Number of full and part-time GSSs. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

## Two-digit SIC industry dummies

Article: Dummy variables for two-digit Standard Industrial Classification industries.

Status: partial_requires_crosswalk

Issues:

- The release has no SIC code variable. V43 (main product/service, Q.8c) and INDUSTRY carry 1980 Census of Population industry codes. INDUSTRY is the industry-file key, set equal to V43 in file creation, and is missing (-999 or blank) for some records. V43 is the more complete source.
- A public crosswalk was acquired from the U.S. Census Bureau: the '1980 Census of Population Industry Classification System' with 1972 SIC equivalents (data/raw/census_io_1980_industry_occupation_code_list). It was transcribed to data/derived/census1980_ind_sic1972_v1/census1980_industry_sic1972.csv.
- Some Census categories span several 2-digit SIC groups: 041 (11, 12), 060 (15, 16, 17), 710 (62, 67), 711 (63, 64), 712 (65, 66), 800 (78, 79).
- 'Not specified' categories (122, 301, 332, 350, 382, 392, 472, 522, 571, 691) have no printed SIC. Code 991 (Armed Forces) has none either.
- The source prints code 190 (paints) as SIC 287, probably a typo for 285. Both are SIC major group 28, so the 2-digit mapping is unaffected.
- A small number of V43 values are not in the 1980 code list. The codes are listed in the coordinator-only file.
- The SIC edition the article used (1972 or 1987) is not known. The Census Bureau's 1990 classification with 1987 SIC equivalents was also acquired (not transcribed).
- The technical manual states that the industry-level merge was done 'at the two-digit SIC code level'. The NOS team's own Census-to-SIC mapping is not released.

Variables:

- V43 (candidate; pos. 40; F3.0): Q.8c  Main product / service of ORG. Declared missing: none.
- INDUSTRY (candidate; pos. 1; F8.2): 1980 CENSUS INDUSTRY CODE. Declared missing: -999.
- INDUS80 (alternative_or_related; pos. 50; F3.0): RS INDUSTRY CODE   (1980). Declared missing: 0, 998, 999. Codes: 0 = NAP; 998 = DK; 999 = NA.
- OCC80 (alternative_or_related; pos. 48; F3.0): RS CENSUS OCCUPATION CODE (1980). Declared missing: 0, 998, 999. Codes: 0 = NAP; 998 = DK; 999 = NA.

## Sampling weights

Article: (Not described in the article's Measures; checked for design.)

Status: available

Issues:

- WEIGHT = RAWWGT x 688/83.637. RAWWGT = 1/NEWTOTAL, which inverts the size-proportional selection. No weight is set in the .por header. Whether the article weighted is not stated in the Measures section.
- The GSS weights FORMWT and OVERSAMP refer to persons, not establishments.

Variables:

- WEIGHT (candidate; pos. 1002; F8.2): rawwgt adjusted to n=688. Declared missing: 0.
- RAWWGT (candidate; pos. 1001; F8.2): RECIPROCAL OF SIZE (NEWTOTAL). Declared missing: none.
- NEWTOTAL (alternative_or_related; pos. 1000; F8.2): TOTAL EMPLOYEES BASED ON ASSIGNED. Declared missing: none.
- FORMWT (alternative_or_related; pos. 633; F5.3): POST-STRATIFICATION WEIGHT. Declared missing: none.
- OVERSAMP (alternative_or_related; pos. 636; F6.4): WEIGHTS FOR BLACK OVERSAMPLES. Declared missing: none.

## Respondent unit and duplicate employer records

Article: Article describes 727 organizations.

Status: ambiguous

Issues:

- The release has 727 records, one per GSS nominator-employer pair. V1 is a record-level ID.
- The documentation reports that 39 completions are duplicate employers (V3 = 0), whose data were copied from another nominator's interview. That leaves 688 distinct establishments.
- DUP and NUMOBS are labelled 'cases from the same org' and 'number of cases for org'.
- Whether duplicates are kept, dropped or down-weighted is a sample-construction decision not made here. The article's 727 matches the record count, not the distinct-establishment count.

Variables:

- V1 (candidate; pos. 642; F5.0): SRL Case Identification Number. Declared missing: none.
- V3 (candidate; pos. 644; F1.0): DC Method. Declared missing: none. Codes: 0 = Duplicated by SRL; 1 = Phone; 2 = Mail.
- DUP (candidate; pos. 996; F8.2): CASES FROM THE SAME ORG. Declared missing: none.
- NUMOBS (candidate; pos. 997; F8.2): NUMBER OF CASES FOR ORG. Declared missing: none.
- V6 (candidate; pos. 647; F1.0): R/Spouse Employer. Declared missing: none. Codes: 1 = Respondent; 2 = Spouse Employer.
- RSSOC (candidate; pos. 1007; F8.2): RESPONDENT SPOUSE INDICATOR. Declared missing: -1.

