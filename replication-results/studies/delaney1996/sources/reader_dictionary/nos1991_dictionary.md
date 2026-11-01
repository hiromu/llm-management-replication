# NOS 1991 reader dictionary (ICPSR 6240 V1, DS0002)

## General notes

- Source: National Organizations Survey (NOS), 1991, ICPSR 6240, version V1, dataset DS0002 (SPSS portable file). 727 records, 1016 variables, all numeric.
- This dictionary contains question wording, value codes and labels, declared missing-value codes and skip/universe notes only. It contains no frequencies, percentages, means, ranges or case counts.
- Declared missing values are those declared in the SPSS portable file (the ICPSR release). The NOS technical manual states that the original archived SPSS-X file declared no missing values and that users should decide which codes to treat as missing; the declarations in this file may therefore differ from what a given analysis treats as missing (for example, code 995 'large number of applications' is declared missing; codes 997 and 4 'varies/depends' are not).
- System-missing (blank) values arise mainly from questionnaire skips; the universe notes describe the skip routing printed in the codebook.
- (ORG) = the establishment at the nominated address; (LARGER ORG) = the larger organization it belongs to, if any; (CORE) = the job most directly involved with the main product or service; (GSS) = the occupation of the GSS respondent or spouse who nominated the establishment.
- Positions 1-641 are mainly the GSS 1991 individual-level record of the nominating respondent (or spouse) and merged industry-level variables; positions 642-993 (V1-V353) are the NOS establishment interview; positions 994-1016 are file-construction, size-assignment and weight variables.
- Embedded DOCUMENT text in the .por file was inherited from a GSS 1972-1991 cumulative file and refers to GSS conventions; it does not describe this file.

## Topic sections

### Record identification, nomination and duplicates

Each record is one GSS-nominated employer (establishment) matched to a GSS respondent or the respondent's spouse. Where several GSS nominators named the same establishment, the informant was interviewed once and the data were transferred to the other nominators' records (documented as 'Duplicate Employers'; these records carry DC Method = 0).

- Variables: V1
  - Wording: SRL case identification number (Survey Research Laboratory).
  - Notes: One value per record in this file.
  - V1 (pos. 642, F5.0): SRL Case Identification Number. Declared missing: none.

- Variables: V3
  - Wording: Data-collection method.
  - Notes: 0 = 'Duplicated by SRL': data copied from the interview of another nominator of the same establishment; 1 = telephone; 2 = mail questionnaire. The file-creation documentation records that six cases were re-designated as duplicates (V3 set to 0) late in processing.
  - V3 (pos. 644, F1.0): DC Method. Declared missing: none. Codes: 0 = Duplicated by SRL; 1 = Phone; 2 = Mail.

- Variables: V5
  - Wording: GSS identification number of the nominating person.
  - V5 (pos. 646, F6.0): GSS Identification Number. Declared missing: none.

- Variables: V6
  - Wording: Whether the establishment is the employer of the GSS respondent or of the respondent's spouse.
  - V6 (pos. 647, F1.0): R/Spouse Employer. Declared missing: none. Codes: 1 = Respondent; 2 = Spouse Employer.

- Variables: RSSOC
  - Wording: Respondent/spouse indicator created in file merging (1 = GSS respondent's employer, 2 = spouse's employer, per file-creation syntax).
  - RSSOC (pos. 1007, F8.2): RESPONDENT SPOUSE INDICATOR. Declared missing: -1.

- Variables: ID, YEAR
  - Wording: GSS respondent ID number and GSS year. For spouse-employer records the GSS individual-level variables were reassigned to describe the spouse where available (file-creation step 15), and many spouse items are missing by design.
  - ID (pos. 42, F4.0): RESPONDENT ID NUMBER. Declared missing: none.
  - YEAR (pos. 41, F2.0): GSS YEAR FOR THIS RESPONDENT. Declared missing: none.

- Variables: DUP, NUMOBS
  - Wording: File-level variables labelled 'cases from the same org' and 'number of cases for org'.
  - Notes: No further documentation in the codebook.
  - DUP (pos. 996, F8.2): CASES FROM THE SAME ORG. Declared missing: none.
  - NUMOBS (pos. 997, F8.2): NUMBER OF CASES FOR ORG. Declared missing: none.

- Variables: SRLID, NOSID, INNOS, GSSID, SGSSID, SNOSID, RNOSID, IDGSS, SAMPID, RGSSID, MATCH1, MATCH2, MATCH3, MATCH4, MATCH5, MATCH6, MATCH7
  - Wording: Identifier copies and match-verification flags created when merging the NOS, GSS and geographic files (file-creation steps 1-15).
  - SRLID (pos. 1003, F8.2): SRL ASSIGNED ID. Declared missing: -1.
  - NOSID (pos. 1004, F8.2): None. Declared missing: none.
  - INNOS (pos. 1005, F8.2): None. Declared missing: none.
  - GSSID (pos. 1006, F8.2): NORC ASSIGNED NUMBER. Declared missing: -1.
  - SGSSID (pos. 1014, F8.2): None. Declared missing: none.
  - SNOSID (pos. 1013, F8.2): None. Declared missing: none.
  - RNOSID (pos. 1010, F8.2): None. Declared missing: none.
  - IDGSS (pos. 637, F8.2): None. Declared missing: none.
  - SAMPID (pos. 639, F8.2): None. Declared missing: none.
  - RGSSID (pos. 641, F8.2): None. Declared missing: none.
  - MATCH1 (pos. 1008, F8.2): None. Declared missing: none.
  - MATCH2 (pos. 1009, F8.2): None. Declared missing: none.
  - MATCH3 (pos. 640, F8.2): None. Declared missing: none.
  - MATCH4 (pos. 1011, F8.2): None. Declared missing: none.
  - MATCH5 (pos. 1012, F8.2): None. Declared missing: none.
  - MATCH6 (pos. 1015, F8.2): None. Declared missing: none.
  - MATCH7 (pos. 1016, F8.2): None. Declared missing: none.

### Weights and size variables used for weighting

The NOS is a probability-proportional-to-size sample of establishments (each employed GSS respondent/spouse nominates an employer). File-creation documentation: RAWWGT is the reciprocal of size (NEWTOTAL); WEIGHT = RAWWGT x (688/83.637), labelled 'rawwgt adjusted to n=688' (688 = documented number of non-duplicated establishments). An earlier step set WEIGHT = 0 for duplicate records, but the final step recomputed WEIGHT for all records. The .por declares WEIGHT = 0 as missing. No weight variable is set in the .por file header.

- Variables: WEIGHT
  - Wording: Design weight: RAWWGT rescaled (label 'rawwgt adjusted to n=688').
  - WEIGHT (pos. 1002, F8.2): rawwgt adjusted to n=688. Declared missing: 0.

- Variables: RAWWGT
  - Wording: Reciprocal of establishment size (NEWTOTAL).
  - RAWWGT (pos. 1001, F8.2): RECIPROCAL OF SIZE (NEWTOTAL). Declared missing: none.

- Variables: NEWFULL, NEWPART, NEWTOTAL
  - Wording: Assigned numbers of full-time and part-time workers and their total, used for the weights.
  - Notes: Labels: 'assigned values for full-time workers', 'assigned values for part-time workers', 'total employees based on assigned'. The assignment rule is not documented in the codebook.
  - NEWFULL (pos. 998, F8.2): ASSIGNED VALUES FOR FULL-TIME WORKERS. Declared missing: 99998, 99999.
  - NEWPART (pos. 999, F8.2): ASSIGNED VALUES FOR PART-TIME WRKERS. Declared missing: 99998, 99999.
  - NEWTOTAL (pos. 1000, F8.2): TOTAL EMPLOYEES BASED ON ASSIGNED. Declared missing: none.

- Variables: FORMWT, OVERSAMP, SAMPCODE, SAMPCODS, SAMPLE, BALLOT, FORM
  - Wording: GSS individual-level design variables carried over from the GSS 1991 record (post-stratification weight, black-oversample weight, sampling error codes, ballot/form). These refer to the GSS person sample, not to the establishment sample.
  - FORMWT (pos. 633, F5.3): POST-STRATIFICATION WEIGHT. Declared missing: none.
  - OVERSAMP (pos. 636, F6.4): WEIGHTS FOR BLACK OVERSAMPLES. Declared missing: none.
  - SAMPCODE (pos. 634, F3.0): SAMPLING ERROR CODE. Declared missing: 0. Codes: 0 = NAP.
  - SAMPCODS (pos. 638, F8.2): SAMPLING ERROR CODE. Declared missing: -1.
  - SAMPLE (pos. 635, F1.0): SAMPLING FRAME AND METHOD. Declared missing: none. Codes: 1 = 1960 BQ; 2 = 1970 BQ; 3 = 1970 FP; 4 = 1970 FP BLK OVERSAMP; 5 = 1980 BFP BLK OVERSAMP; 6 = 1980 FP; 7 = 1980 FP BLK OVERSAMP.
  - BALLOT (pos. 632, F1.0): BALLOT USED FOR INTERVIEW. Declared missing: 0. Codes: 0 = NAP; 1 = BALLOT A; 2 = BALLOT B; 3 = BALLOT C.
  - FORM (pos. 337, F1.0): FORM OF SPLIT QUESTIONNAIRE ASKED. Declared missing: 0. Codes: 0 = NO SPLIT QUES; 1 = STANDARD <X>; 2 = ALTERNATE <Y>; 3 = ALTERNATE <Z>.

### Organization type, ownership and age (Q.1-Q.4)

- Variables: V8
  - Wording: Q.1a The following questions are about (NAME) at (ADDRESS). Is (NAME) at (ADDRESS) a ... For profit, or Not for profit organization?
  - Universe/skip: All. Not for profit: skip to Q.2a.
  - V8 (pos. 649, F1.0): Q.1a  Profit / non - profit organization. Declared missing: none. Codes: 1 = For profit; 2 = Not for profit org.

- Variables: V9
  - Wording: Q.1b What is the legal form of (ORG)? Is it a ... Sole proprietorship, Partnership or limited partnership, Franchise, Corporation with publicly held stock, Corporation with privately held stock, Something else? (specify)
  - Universe/skip: For-profit organizations. Corporations and 'something else' skip to Q.3.
  - V9 (pos. 650, F1.0): Q.1b  Legal form of ORG. Declared missing: 8, 9. Codes: 1 = Sole proprietorship; 2 = Partnership; 3 = Franchise; 4 = Corp-publ held stock; 5 = Corp-priv held stock; 6 = Something else; 8 = Do not know; 9 = No response/refused.

- Variables: V11
  - Wording: Q.1c Are you (the owner / a partner)?
  - Universe/skip: Sole proprietorships, partnerships, franchises. Then skip to Q.3.
  - V11 (pos. 652, F1.0): Q.1c  R is the owner/the partner. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V12
  - Wording: Q.2a Is it ... An elementary, junior, or high school; A college, university, or junior college; A hospital; A social service agency; A governmental agency; or Something else? (specify)
  - Universe/skip: Not-for-profit organizations. School, college, hospital, social service agency and 'something else' skip to Q.2c; governmental agency continues to Q.2b; don't know skips to Q.3.
  - V12 (pos. 653, F1.0): Q.2a  Kind of ORG. Declared missing: 8, 9. Codes: 1 = Elem/junior/high sch; 2 = Coll/univ/junior col; 3 = Hospital; 4 = Social service agncy; 5 = Governmental agency; 6 = Something else; 8 = Do not know; 9 = No response/refused.

- Variables: V14
  - Wording: Q.2b Is it a ... Local, State, or Federal agency?
  - Universe/skip: Governmental agencies (Q.2a). Then skip to Q.3.
  - V14 (pos. 655, F1.0): Q.2b  ORG is local/state/federal agency. Declared missing: 8, 9. Codes: 1 = Local; 2 = State; 3 = Federal agency; 8 = Do not know; 9 = No response/refused.

- Variables: V15
  - Wording: Q.2c Is it public or private?
  - Universe/skip: Not-for-profit organizations routed from Q.2a.
  - V15 (pos. 656, F1.0): Q.2c  ORG is public / private. Declared missing: 8, 9. Codes: 1 = Public; 2 = Private; 8 = Do not know; 9 = No response/refused.

- Variables: V16
  - Wording: Q.3 In what year was (ORG) first established? (PROBE: At any location)
  - Universe/skip: All.
  - V16 (pos. 657, F4.0): Q.3  Year ORG was first established. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.

- Variables: V17
  - Wording: Q.4a Is (ORG) in any way part of a larger organization or is it completely independent?
  - Universe/skip: All. Completely independent: skip to Q.5a.
  - V17 (pos. 658, F1.0): Q.4a  ORG is part of large ORG/indepndnt. Declared missing: none. Codes: 1 = Part of larger org; 2 = Completely indepndnt.

- Variables: V20
  - Wording: Q.4d How long has (ORG) been affiliated with that organization?
  - Universe/skip: Part of a larger organization.
  - Notes: Variable label says 'Year ORG affiliated w/larger ORG'; declared missing codes are year-style (9998, 9999).
  - V20 (pos. 661, F4.0): Q.4d  Year ORG affiliated w/larger ORG. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.

- Variables: V21
  - Wording: Q.4e In what way is (ORG) part of the larger organization? Is it ... A wholly owned branch facility, A wholly owned subsidiary, A locally owned franchise, A school in a school system, A campus in a higher education system, A governmental unit, or Something else? (specify)
  - Universe/skip: Part of a larger organization.
  - V21 (pos. 662, F1.0): Q.4e  Way ORG is part of larger ORG. Declared missing: 8, 9. Codes: 1 = Whol owned brnch fac; 2 = Whol owned subsdiary; 3 = Locally ownd franchs; 4 = School in schl systm; 5 = Campus higher ed sys; 6 = Governmental unit; 7 = Something else; 8 = Do not know; 9 = No response/refused.

- Variables: V18, V19, V22, V10, V13
  - Wording: Q.4b name and Q.4c address of the larger organization; 'other specify' texts for Q.1b, Q.2a and Q.4e.
  - Notes: Name/address items are not released as data.
  - V18 (pos. 659, F1.0): Q.4b  Name of the larger ORG. Declared missing: none.
  - V19 (pos. 660, F1.0): Q.4c  Address of the larger ORG. Declared missing: none.
  - V22 (pos. 663, F2.0): Q.4e  Other Specify. Declared missing: 98, 99. Codes: 1 = Verbatim resp listed; 98 = Do not know; 99 = No response/refused.
  - V10 (pos. 651, F2.0): Q.1b  Other Specify. Declared missing: 98, 99. Codes: 1 = Verbatim resp listed; 98 = Do not know; 99 = No response/refused.
  - V13 (pos. 654, F2.0): Q.2a  Other Specify. Declared missing: 98, 99. Codes: 1 = Verbatim resp listed; 98 = Do not know; 99 = No response/refused.

### Employment counts (Q.5-Q.7, Q.9, Q.19, Q.29)

Interviewer instruction before Q.5: (IF THERE IS A LARGER ORG) The following questions refer to (ORG), not to (LARGER ORG). Q.5a-7c are asked for full-time employees and then repeated for part-time employees.

- Variables: V23
  - Wording: Q.5a In total, how many full time employees worked at (ORG) as of March 1, 1991? By full time we mean 35 or more hours per week.
  - Universe/skip: All.
  - V23 (pos. 664, F5.0): Q.5a  Number of full time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

- Variables: V32
  - Wording: Q.5a (part-time) In total, how many part-time employees worked at (ORG) as of March 1, 1991? (IF 'NONE', SKIP TO Q.8a)
  - Universe/skip: All.
  - V32 (pos. 673, F5.0): Q.5a  Number of part time employees. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

- Variables: V24, V25, V33, V34
  - Wording: Q.5b About what percentage were women? Q.5c And about what percentage were white? (full-time; part-time)
  - V24 (pos. 665, F3.0): Q.5b  Percentage of women / full time. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V25 (pos. 666, F3.0): Q.5c  Percentage of white / full time. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V33 (pos. 674, F3.0): Q.5b  Percentage of women / part time. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V34 (pos. 675, F3.0): Q.5c  Percentage of white / part time. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V26, V27, V28, V29, V30, V31, V35, V36, V37, V38, V39, V40
  - Wording: Q.6a/Q.7a Compared to 1 year ago / 3 years ago, has the number of (full/part) time employees working at (ORG) increased, decreased, or remained the same? Q.6b-c/Q.7b-c By about what percentage has the (full/part) time workforce increased / decreased?
  - Notes: The codebook text for Q.7a reads '9 years ago' (scan); the variable label and questionnaire say 3 years.
  - V26 (pos. 667, F1.0): Q.6a  Number of inc/dec - full - 1 yrs. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V27 (pos. 668, F3.0): Q.6b  Percentage of wrkplace incrsd/full. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V28 (pos. 669, F3.0): Q.6c  Percentage of wrkplace decrsd/full. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V29 (pos. 670, F1.0): Q.7a  Number of inc/dec - full - 3 yrs. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V30 (pos. 671, F3.0): Q.7b  Percentage of wrkplace incrsd/full. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V31 (pos. 672, F3.0): Q.7c  Percentage of wrkplace decrsd/full. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V35 (pos. 676, F1.0): Q.6a  Number of inc/dec - part - 1 yrs. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V36 (pos. 677, F3.0): Q.6b  Percentage of wrkplace incrsd/part. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V37 (pos. 678, F3.0): Q.6c  Percentage of wrkplace decrsd/part. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V38 (pos. 679, F1.0): Q.7a  Number of inc/dec - part - 3 yrs. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V39 (pos. 680, F3.0): Q.7b  Percentage of wrkplace incrsd/part. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V40 (pos. 681, F3.0): Q.7c  Percentage of wrkplace decrsd/part. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V45
  - Wording: Q.9a First, we would like to find out about (COREs). In total, how many full-time and part-time (COREs) worked for (ORG) as of March 1, 1991?
  - Universe/skip: All (CORE = job title most directly involved with the main product/service, Q.8d).
  - V45 (pos. 685, F5.0): Q.9a  Number of total COREs work for ORG. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

- Variables: V80
  - Wording: Q.19b How many full and part-time (GSSs) were there?
  - Universe/skip: Q.19a = yes (GSS occupation present and different from CORE).
  - V80 (pos. 720, F5.0): Q.19b  Number of full and part-time GSSs. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

- Variables: V115
  - Wording: Q.29b How many [managers and other administrators] were there (including full and part time)?
  - Universe/skip: Q.29a = yes (managers present and not the same as CORE or GSS).
  - V115 (pos. 755, F5.0): Q.29b  Number of full and part-time mngr. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

- Variables: V46, V47, V48, V81, V82, V83, V116, V117, V118
  - Wording: Percentage of (COREs / GSSs / managers) who were women; temporaries; worked primarily at home.
  - V46 (pos. 686, F3.0): Q.9b  Percentage of women. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V47 (pos. 687, F3.0): Q.9c  Percentage of temporaries. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V48 (pos. 688, F3.0): Q.9d  Percentage of wkd primarily at hm. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V81 (pos. 721, F3.0): Q.19c  Percentage of women. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V82 (pos. 722, F3.0): Q.19d  Percentage of temporaries. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V83 (pos. 723, F3.0): Q.19e  Percentage of wkd primarily at hm. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V116 (pos. 756, F3.0): Q.29c  Percentage of women. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V117 (pos. 757, F3.0): Q.29d  Percentage of temporaries. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V118 (pos. 758, F3.0): Q.29e  Percentage of wkd primarily at hm. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V339
  - Wording: Q.92 Counting all locations, about how many full- and part-time employees did (LARGER ORG) have as of March 1, 1991?
  - Universe/skip: Box H: organizations that are part of a larger organization.
  - V339 (pos. 979, F7.0): Q.92  Total number of full/part employes. Declared missing: 9999998, 9999999. Codes: 9999998 = Do not know; 9999999 = No response/refused.

- Variables: V340
  - Wording: Q.93 In what year was (LARGER ORG) first established?
  - Universe/skip: Box H: organizations that are part of a larger organization.
  - V340 (pos. 980, F4.0): Q.93  Year larger ORG first establised. Declared missing: 9998, 9999. Codes: 9998 = Do not know; 9999 = No response/refused.

- Variables: V335, V336, V337, V338
  - Wording: Q.91a What is the total number of operating sites in (LARGER ORG)? Q.91b How many different physical locations does (LARGER ORG) have in 1) this state, 2) the rest of the United States, 3) outside the U.S.?
  - Universe/skip: Box H.
  - V335 (pos. 975, F5.0): Q.91a  Total number of operating sites. Declared missing: 99998, 99999. Codes: 99996 = 100,000 or more sites; 99998 = Do not know; 99999 = No response/refused.
  - V336 (pos. 976, F5.0): Q.91b1  Number of physcl lctn/this state. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
  - V337 (pos. 977, F5.0): Q.91b2  Number of physcl lctn/rest of US. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.
  - V338 (pos. 978, F5.0): Q.91b3  Number of physcl lctn/outside US. Declared missing: 99998, 99999. Codes: 99998 = Do not know; 99999 = No response/refused.

### Kind of work, main product/service and industry codes (Q.8)

- Variables: V41
  - Wording: Q.8a We would like to know about the kind of work that takes place at (ORG). Does (ORG) produce a product, deliver a service, or both?
  - Universe/skip: All. Product/service/both skip to Q.8c; 'neither' and DK go to Q.8b.
  - V41 (pos. 682, F1.0): Q.8a  Kind of work ORG does. Declared missing: 8, 9. Codes: 1 = Produces a product; 2 = Delivers a service; 3 = Both; 4 = Neither; 8 = Do not know; 9 = No response/refused.

- Variables: V42
  - Wording: Q.8b What does (ORG) do?
  - Notes: Open-ended; not released as data.
  - V42 (pos. 683, F3.0): Q.8b  What ORG does. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V43
  - Wording: Q.8c What is the main (product produced / service provided) here?
  - Notes: Coded numerically with no value labels in the file. The file-creation syntax (step 17) matches the industry-level file by setting V43 = INDUSTRY, so V43 holds a 1980 Census industry code (codebook label of INDUSTRY: '1980 Census industry code').
  - V43 (pos. 40, F3.0): Q.8c  Main product / service of ORG. Declared missing: none.

- Variables: V44
  - Wording: Q.8d What is the job title for the employees who are most directly involved with (description from Q.8c)? IF MORE THAN ONE TITLE, ASK: Which has the most employees? ***THIS IS THE CORE JOB REFERRED TO THROUGHOUT THE QUESTIONNAIRE. WHEN YOU SEE (CORE), FILL IN THIS JOB TITLE.
  - Notes: Coded as an occupation code (no value labels).
  - V44 (pos. 684, F3.0): Q.8d  Job title for most invlvd w/main. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: INDUSTRY
  - Wording: 1980 Census industry code of the establishment, carried on the merged industry-level file.
  - Notes: Declared missing -999. The technical manual states that industry-level variables from published government sources were merged 'at the two-digit SIC code level'; no SIC code variable is present in the release.
  - INDUSTRY (pos. 1, F8.2): 1980 CENSUS INDUSTRY CODE. Declared missing: -999.

- Variables: PCTWOMEN, PCTPRODW, WKWAGE, HRWAGE, WKHOUR, TOTUNEM, MALEUNEM, FEMAUNEM, CONCASS1, CONCASS2, CONCREC1, CONCREC2, CPROFBT, CPROFUN, PROFBEMP, PROFUEMP, LABSHAR1, LABSHAR2, ASSTSIZE, SALESIZE, PROFSIZE, PROFASST, PROFSALE, INVSALES, SECOND, AVGWS, AVGCOMP, ORGEFF1, UNFAIR, VATWORK, VAPWORK, CAPINT1, CAPINT2, CAPINT3, CAPINT4, AVGESTAB, PCTUNION, CAPUTIL
  - Wording: Industry-level characteristics merged from published government sources (see each label; e.g., PCTUNION = percent of workers belonging to unions in the industry).
  - Notes: Industry-level, not establishment-reported.
  - PCTWOMEN (pos. 2, F8.2): PERCENT OF EMPLOYEES WOMEN. Declared missing: -999.
  - PCTPRODW (pos. 3, F8.2): PERCENT OF PROD/NON-SUPERV WORKERS. Declared missing: -999.
  - WKWAGE (pos. 4, F8.2): AVG WEEKLY WAGE OF P/N-S WORKERS. Declared missing: -999.
  - HRWAGE (pos. 5, F8.2): AVG HOURLY WAGE OF P/N-S WORKERS. Declared missing: -999.
  - WKHOUR (pos. 6, F8.2): AVG WEEKLY HOURS OF P/N-S WORKERS. Declared missing: -999.
  - TOTUNEM (pos. 7, F8.2): UNEMPLOYMENT RATE - ALL WORKERS. Declared missing: -999.
  - MALEUNEM (pos. 8, F8.2): UNEMPLOYMENT RATE - MALES. Declared missing: -999.
  - FEMAUNEM (pos. 9, F8.2): UNEMPLOYMENT RATE - FEMALES. Declared missing: -999.
  - CONCASS1 (pos. 10, F8.2): % ASSETS HELD BY >$250 MIL ASSET FIRMS. Declared missing: -999.
  - CONCASS2 (pos. 11, F8.2): % ASSETS HELD BY >$100 MIL ASSET FIRMS. Declared missing: -999.
  - CONCREC1 (pos. 12, F8.2): % SALES BY >$50 MIL RECEIPTS FIRMS. Declared missing: -999.
  - CONCREC2 (pos. 13, F8.2): % SALES BY >$100 MIL RECEIPTS FIRMS. Declared missing: -999.
  - CPROFBT (pos. 14, F8.2): % CHANGE IN CORP PROFITS BEFORE TAXES. Declared missing: -999.
  - CPROFUN (pos. 15, F8.2): % CHANGE IN UNDISTRIBUTED CORP PROFITS. Declared missing: -999.
  - PROFBEMP (pos. 16, F8.2): BEFORE TAX PROFITS PER EMPLOYEE. Declared missing: -999.
  - PROFUEMP (pos. 17, F8.2): UNDISTRIBUTED PROFITS PER EMPLOYEE. Declared missing: -999.
  - LABSHAR1 (pos. 18, F8.2): WAGES AS PERCENT OF INCOME. Declared missing: -999.
  - LABSHAR2 (pos. 19, F8.2): COMPENSATION AS PERCENT OF INCOME. Declared missing: -999.
  - ASSTSIZE (pos. 20, F8.2): AVERAGE ASSET SIZE OF CORPORATIONS. Declared missing: -999.
  - SALESIZE (pos. 21, F8.2): AVERAGE SALES SIZE OF CORPORATIONS. Declared missing: -999.
  - PROFSIZE (pos. 22, F8.2): AVERAGE PROFITS PER FIRM. Declared missing: -999.
  - PROFASST (pos. 23, F8.2): CORP PROFITS AS PERCENT OF CORP ASSETS. Declared missing: -999.
  - PROFSALE (pos. 24, F8.2): CORP PROFITS AS PERCENT OF CORP SALES. Declared missing: -999.
  - INVSALES (pos. 25, F8.2): CORPORATE SALES-TO-INVENTORY RATIO. Declared missing: -999.
  - SECOND (pos. 26, F8.2): SECONDARY LABOR MARKET INDEX. Declared missing: -999.
  - AVGWS (pos. 27, F8.2): AVG WAGES AND SALARIES PER WORKER. Declared missing: -999.
  - AVGCOMP (pos. 28, F8.2): AVG COMPENSATION PER WORKER. Declared missing: -999.
  - ORGEFF1 (pos. 29, F8.2): % ELIGIBLE VOTERS IN NLRB ELECTIONS. Declared missing: -999.
  - UNFAIR (pos. 30, F8.2): NLRB UNFAIR LABOR PRAC CASES PER EMP. Declared missing: -999.
  - VATWORK (pos. 31, F8.2): VALUE ADDED PER EMPLOYEE (ALL EMPS). Declared missing: -999.
  - VAPWORK (pos. 32, F8.2): VALUE ADDED PER PRODUCTION WORKER. Declared missing: -999.
  - CAPINT1 (pos. 33, F8.2): TOTAL EXPENDITURES PER EMP (ALL EMPS). Declared missing: -999.
  - CAPINT2 (pos. 34, F8.2): TOTAL EXPENDITURES PER PROD WORKER. Declared missing: -999.
  - CAPINT3 (pos. 35, F8.2): TOTAL EXPENDITURES/TOTAL PAYROLL. Declared missing: -999.
  - CAPINT4 (pos. 36, F8.2): TOTAL EXPENDITURES/TOT PROD WAGES. Declared missing: -999.
  - AVGESTAB (pos. 37, F8.2): AVG ESTABLISHMENT EMPLOYMENT SIZE. Declared missing: -999.
  - PCTUNION (pos. 38, F8.2): % WORKERS BELONGING TO UNIONS. Declared missing: -999.
  - CAPUTIL (pos. 39, F8.2): CAPACITY UTILIZATION RATE. Declared missing: -999.

- Variables: OCC80, INDUS80, V349
  - Wording: GSS respondent's (or, for spouse records, spouse's) 1980 Census occupation and industry codes; V349 'GSS occupation code' on the NOS record (the GSS occupation used to define the (GSS) job in Q.19-Q.28 and Q.64-Q.65).
  - OCC80 (pos. 48, F3.0): RS CENSUS OCCUPATION CODE (1980). Declared missing: 0, 998, 999. Codes: 0 = NAP; 998 = DK; 999 = NA.
  - INDUS80 (pos. 50, F3.0): RS INDUSTRY CODE   (1980). Declared missing: 0, 998, 999. Codes: 0 = NAP; 998 = DK; 999 = NA.
  - V349 (pos. 989, F3.0): GSS occupation code. Declared missing: 998, 999. Codes: 999 = No response/refused.

### Staffing and internal mobility: CORE occupation (Q.9-Q.18)

CORE = the job title most directly involved with the organization's main product or service (Q.8d). Box A after Q.18: IF GSS R'S OCCUPATION = CORE OCCUPATION, SKIP TO BOX B.

- Variables: V50
  - Wording: Q.11a In the past 2 years, have you hired any (COREs) from outside (ORG)?
  - Universe/skip: All. No: skip to Q.16a.
  - V50 (pos. 690, F1.0): Q.11a  Hired COREs from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V51, V52, V53, V54, V55, V56
  - Wording: Q.11b How often do you use each of the following methods to find them? What about ... 1) Newspaper advertisements? 2) Signs posted outside the building? 3) Referrals from current employees? 4) Referrals from business or professional contacts? 5) Employment agencies or placement services? 6) Unsolicited inquiries by telephone, mail, or in person? (Frequently / Sometimes / Never)
  - V51 (pos. 691, F1.0): Q.11b1  Freq of mthd/newspaper advtsmnt. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V52 (pos. 692, F1.0): Q.11b2  Freq of mthd/signs posted. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V53 (pos. 693, F1.0): Q.11b3  Freq of mthd/referral frm emplys. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V54 (pos. 694, F1.0): Q.11b4  Freq of mthd/refrl frm pro cntct. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V55 (pos. 695, F1.0): Q.11b5  Freq of mthd/emplymnt agency. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V56 (pos. 696, F1.0): Q.11b6  Freq of mthd/unsolicited inquiry. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V57, V58, V59, V60, V61
  - Wording: Q.12 When you are selecting new employees for (COREs) positions, do you require ... a. Intelligence tests or other psychological tests? b. Skills or proficiency tests? c. Letters of reference? d. A physical examination? e. Drug or alcohol tests?
  - V57 (pos. 697, F1.0): Q.12a  Require/intelligence-psycho tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V58 (pos. 698, F1.0): Q.12b  Require/skills-proficiency tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V59 (pos. 699, F1.0): Q.12c  Require/letters of reference. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V60 (pos. 700, F1.0): Q.12d  Require/physical examination. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V61 (pos. 701, F1.0): Q.12e  Require/drug-alcohol tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V62
  - Wording: Q.13 In the past 2 years, about how many applications have you considered for each opening?
  - Universe/skip: Hired from outside in the past 2 years.
  - Notes: Codes 995 'large number of applications' (declared missing in the .por), 997 'not applicable' (not declared missing), 998 don't know, 999 no response.
  - V62 (pos. 702, F3.0): Q.13  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.

- Variables: V63, V64, V65, V66
  - Wording: Q.14a About how many applicants do you usually interview before making an offer? (IF 'NONE', skip) Q.14b For this job, about how long does a typical applicant interview take? (minutes / days) Q.15 How many offers do you usually have to make before filling this position?
  - V63 (pos. 703, F3.0): Q.14a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
  - V64 (pos. 704, F3.0): Q.14b  Period of typical interview/ min. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V65 (pos. 705, F1.0): Q.14b  Period of typical interview/ dys. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.
  - V66 (pos. 706, F1.0): Q.15  Number of offers to fill position. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.

- Variables: V67
  - Wording: Q.16a Do you sometimes fill (CORE) vacancies with people already employed at (ORG)?
  - Universe/skip: No: skip to Q.17a.
  - V67 (pos. 707, F1.0): Q.16a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V68, V69, V70, V71, V72, V73
  - Wording: Q.16b Do these people need additional training? Q.16c When you fill this job with a person already in the organization, how often do you ... 1) Consult a seniority list? 2) Inform current employees by posting or circulating a vacancy notice? 3) Ask the person leaving the job to recommend other current employees? 4) Ask others at your workplace for recommendations? 5) Go directly to specific employees and encourage them to apply?
  - V68 (pos. 708, F1.0): Q.16b  People need additional training. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 3 = Sometimes/depends; 8 = Do not know; 9 = No response/refused.
  - V69 (pos. 709, F1.0): Q.16c1  Freq/consult a seniority list. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V70 (pos. 710, F1.0): Q.16c2  Freq/infrm emplys by post notice. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V71 (pos. 711, F1.0): Q.16c3  Freq/ask person to recommnd othr. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V72 (pos. 712, F1.0): Q.16c4  Freq/ask othrs at wkplc fr recom. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V73 (pos. 713, F1.0): Q.16c5  Freq/go to spec emplys to encorg. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V74, V75
  - Wording: Q.17a Are there different levels of (COREs)? Q.17b Are the procedures for promoting them to a higher level ... formal, or informal?
  - Universe/skip: Q.17a No: skip to next block.
  - V74 (pos. 714, F1.0): Q.17a  There are diffrnt levels of COREs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V75 (pos. 715, F1.0): Q.17b  Procedure fr promtng-formal/infml. Declared missing: 8, 9. Codes: 1 = Formal; 2 = Informal; 8 = Do not know; 9 = No response/refused.

- Variables: V76
  - Wording: Q.18a Is it possible for a (CORE) to be promoted to a level above (CORE)?
  - Universe/skip: All asked the CORE block. No: skip to Box A.
  - V76 (pos. 716, F1.0): Q.18a  Possible to be promtd above COREs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V77, V78
  - Wording: Q.18b How often does this happen? Would you say ... very often, often, or not very often? Q.18c Are the procedures for this kind of promotion ... formal, or informal?
  - V77 (pos. 717, F1.0): Q.18b  Freq of promotion above COREs. Declared missing: 8, 9. Codes: 1 = Very often; 2 = Often; 3 = Not very often; 8 = Do not know; 9 = No response/refused.
  - V78 (pos. 718, F1.0): Q.18c  Procedure fo promtn-formal/infoml. Declared missing: 8, 9. Codes: 1 = Formal; 2 = Informal; 8 = Do not know; 9 = No response/refused.

### Staffing and internal mobility: GSS occupation (Q.19-Q.28)

(GSS) = the occupation of the GSS respondent (or spouse) who nominated the establishment. Box B after Q.28: IF CORE OR GSS = MANAGER, SKIP TO Q.37.

- Variables: V79
  - Wording: Q.19a Now I'd like to ask about (GSSs). Did any (GSSs) work for (ORG) on March 1, 1991?
  - Universe/skip: Box A: asked unless the GSS respondent's occupation equals the CORE occupation. 'Yes, but same as CORE' and 'No': skip to Box B.
  - V79 (pos. 719, F1.0): Q.19a  GSSs work for ORG on March 1 1991. Declared missing: 8, 9. Codes: 1 = Yes; 2 = Yes but same as core; 3 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V84
  - Wording: Q.20 Is any of the work of (GSSs) done by subcontracting, that is, performed by people not regularly on ORG's payroll?
  - V84 (pos. 724, F1.0): Work of GSSs done by subcontracting. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V85
  - Wording: Q.21a In the past 2 years, have you hired any (GSSs) from outside (ORG)?
  - Universe/skip: GSS occupation present. No: skip to Q.26a.
  - V85 (pos. 725, F1.0): Q.21a  Hired GSSs from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V86, V87, V88, V89, V90, V91
  - Wording: Q.21b How often do you use each of the following methods to find them? What about ... 1) Newspaper advertisements? 2) Signs posted outside the building? 3) Referrals from current employees? 4) Referrals from business or professional contacts? 5) Employment agencies or placement services? 6) Unsolicited inquiries by telephone, mail, or in person? (Frequently / Sometimes / Never)
  - V86 (pos. 726, F1.0): Q.21b1  Freq of mthd/newspaper advtsmnt. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V87 (pos. 727, F1.0): Q.21b2  Freq of mthd/signs posted. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V88 (pos. 728, F1.0): Q.21b3  Freq of mthd/referral frm emplys. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V89 (pos. 729, F1.0): Q.21b4  Freq of mthd/refrl frm pro cntct. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V90 (pos. 730, F1.0): Q.21b5  Freq of mthd/emplymnt agency. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V91 (pos. 731, F1.0): Q.21b6  Freq of mthd/unsolicited inquiry. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V92, V93, V94, V95, V96
  - Wording: Q.22 When you are selecting new employees for (GSSs) positions, do you require ... a. Intelligence tests or other psychological tests? b. Skills or proficiency tests? c. Letters of reference? d. A physical examination? e. Drug or alcohol tests?
  - V92 (pos. 732, F1.0): Q.22a  Require/intelligence-psycho tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V93 (pos. 733, F1.0): Q.22b  Require/skills-proficiency tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V94 (pos. 734, F1.0): Q.22c  Require/letters of reference. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V95 (pos. 735, F1.0): Q.22d  Require/physical examination. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V96 (pos. 736, F1.0): Q.22e  Require/drug-alcohol tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V97
  - Wording: Q.23 In the past 2 years, about how many applications have you considered for each opening?
  - Universe/skip: Hired from outside in the past 2 years.
  - Notes: Codes 995 'large number of applications' (declared missing in the .por), 997 'not applicable' (not declared missing), 998 don't know, 999 no response.
  - V97 (pos. 737, F3.0): Q.23  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.

- Variables: V98, V99, V100, V101
  - Wording: Q.24a About how many applicants do you usually interview before making an offer? (IF 'NONE', skip) Q.24b For this job, about how long does a typical applicant interview take? (minutes / days) Q.25 How many offers do you usually have to make before filling this position?
  - V98 (pos. 738, F3.0): Q.24a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
  - V99 (pos. 739, F3.0): Q.24b  Period of typical interview/ min. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V100 (pos. 740, F1.0): Q.24b  Period of typical interview/ dys. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.
  - V101 (pos. 741, F1.0): Q.25  Number of offers to fill position. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.

- Variables: V102
  - Wording: Q.26a Do you sometimes fill (GSS) vacancies with people already employed at (ORG)?
  - Universe/skip: No: skip to Q.27a.
  - V102 (pos. 742, F1.0): Q.26a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V103, V104, V105, V106, V107, V108
  - Wording: Q.26b Do these people need additional training? Q.26c When you fill this job with a person already in the organization, how often do you ... 1) Consult a seniority list? 2) Inform current employees by posting or circulating a vacancy notice? 3) Ask the person leaving the job to recommend other current employees? 4) Ask others at your workplace for recommendations? 5) Go directly to specific employees and encourage them to apply?
  - V103 (pos. 743, F1.0): Q.26b  People need additional training. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 3 = Sometimes/depends; 8 = Do not know; 9 = No response/refused.
  - V104 (pos. 744, F1.0): Q.26c1  Freq/consult a seniority list. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V105 (pos. 745, F1.0): Q.26c2  Freq/infrm emplys by post notice. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V106 (pos. 746, F1.0): Q.26c3  Freq/ask person to recommnd othr. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V107 (pos. 747, F1.0): Q.26c4  Freq/ask othrs at wkplc fr recom. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V108 (pos. 748, F1.0): Q.26c5  Freq/go to spec emplys to encorg. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V109, V110
  - Wording: Q.27a Are there different levels of (GSSs)? Q.27b Are the procedures for promoting them to a higher level ... formal, or informal?
  - Universe/skip: Q.27a No: skip to next block.
  - V109 (pos. 749, F1.0): Q.27a  There are diffrnt levels of GSSs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V110 (pos. 750, F1.0): Q.27b  Procedure fr promtng-formal/infml. Declared missing: 8, 9. Codes: 1 = Formal; 2 = Informal; 8 = Do not know; 9 = No response/refused.

- Variables: V111
  - Wording: Q.28a Is it possible for a (GSS) to be promoted to a level above (GSS)?
  - Universe/skip: No: skip to Box B.
  - V111 (pos. 751, F1.0): Q.28a  Possible to be promtd above GSSs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V112, V113
  - Wording: Q.28b How often does this happen? Would you say ... very often, often, or not very often? Q.28c Are the procedures for this kind of promotion ... formal, or informal?
  - V112 (pos. 752, F1.0): Q.28b  Freq of promotion above GSSs. Declared missing: 8, 9. Codes: 1 = Very often; 2 = Often; 3 = Not very often; 8 = Do not know; 9 = No response/refused.
  - V113 (pos. 753, F1.0): Q.28c  Procedure fo promtn-formal/infoml. Declared missing: 8, 9. Codes: 1 = Formal; 2 = Informal; 8 = Do not know; 9 = No response/refused.

### Staffing and internal mobility: managers and administrators (Q.29-Q.36)

- Variables: V114
  - Wording: Q.29a The last group I'd like to ask you about is managers and other administrators. Were there any on the payroll as of March 1, 1991?
  - Universe/skip: Box B: skipped if CORE or GSS is a manager. 'Yes, but the same as CORE or GSS' and 'No': skip to Q.37.
  - V114 (pos. 754, F1.0): Q.29a  Mngr/admin on payroll on Mar 1 91. Declared missing: 8, 9. Codes: 1 = Yes; 2 = Yes but sam core/gss; 3 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V119
  - Wording: Q.30a In the past 2 years, have you hired any managers or other administrators from outside (ORG)?
  - Universe/skip: No: skip to Q.35a.
  - V119 (pos. 759, F1.0): Q.30a  Hired mngr from outside ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V120, V121, V122, V123, V124, V125
  - Wording: Q.30b How often do you use each of the following methods to find them? (same six methods as Q.11b)
  - V120 (pos. 760, F1.0): Q.30b1  Freq of mthd/newspaper advtsmnt. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V121 (pos. 761, F1.0): Q.30b2  Freq of mthd/signs posted. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V122 (pos. 762, F1.0): Q.30b3  Freq of mthd/referral frm emplys. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V123 (pos. 763, F1.0): Q.30b4  Freq of mthd/refrl frm pro cntct. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V124 (pos. 764, F1.0): Q.30b5  Freq of mthd/emplymnt agency. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V125 (pos. 765, F1.0): Q.30b6  Freq of mthd/unsolicited inquiry. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V126, V127, V128, V129, V130
  - Wording: Q.31 When you are selecting new employees as managers or other administrators, do you require ... a. Intelligence tests or other psychological tests? b. Skills or proficiency tests? c. Letters of reference? d. A physical examination? e. Drug or alcohol tests?
  - V126 (pos. 766, F1.0): Q.31a  Require/intelligence-psycho tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V127 (pos. 767, F1.0): Q.31b  Require/skills-proficiency tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V128 (pos. 768, F1.0): Q.31c  Require/letters of reference. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V129 (pos. 769, F1.0): Q.31d  Require/physical examination. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V130 (pos. 770, F1.0): Q.31e  Require/drug-alcohol tests. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V131
  - Wording: Q.32 In the past 2 years, about how many applications have you considered for each opening?
  - Universe/skip: Hired managers from outside in the past 2 years.
  - Notes: Codes 995 'large number of applications' (declared missing in the .por), 997 'not applicable' (not declared missing), 998, 999.
  - V131 (pos. 771, F3.0): Q.32  Number of applicatns fr a opening. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.

- Variables: V132, V133, V134, V135
  - Wording: Q.33a About how many applicants do you usually interview before making an offer? Q.33b For this job, about how long does a typical applicant interview take? Q.34 How many offers do you usually have to make before filling this position?
  - V132 (pos. 772, F3.0): Q.33a  Number of applicants interviewed. Declared missing: 995, 998, 999. Codes: 995 = Large number of appl; 997 = Not applicable; 998 = Do not know; 999 = No response/refused.
  - V133 (pos. 773, F3.0): Q.33b  Period of typical interview/ min. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V134 (pos. 774, F1.0): Q.33b  Period of typical interview/ dys. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.
  - V135 (pos. 775, F1.0): Q.34  Number of offers to fill position. Declared missing: 8, 9. Codes: 8 = Do not know; 9 = No response/refused.

- Variables: V136
  - Wording: Q.35a Do you sometimes fill managerial or administrative vacancies with people already employed at (ORG)?
  - Universe/skip: No: skip to Q.36a.
  - V136 (pos. 776, F1.0): Q.35a  Fill vacancies with people at ORG. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V137, V138, V139, V140, V141, V142
  - Wording: Q.35b Do these people need additional training? Q.35c When you fill a management position with a person already in the organization, how often do you ... (same five methods as Q.16c)
  - V137 (pos. 777, F1.0): Q.35b  People need additional training. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 3 = Sometimes/depends; 8 = Do not know; 9 = No response/refused.
  - V138 (pos. 778, F1.0): Q.35c1  Freq/consult a seniority list. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V139 (pos. 779, F1.0): Q.35c2  Freq/infrm emplys by post notice. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V140 (pos. 780, F1.0): Q.35c3  Freq/ask person to recommnd othr. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V141 (pos. 781, F1.0): Q.35c4  Freq/ask othrs at wkplc fr recom. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.
  - V142 (pos. 782, F1.0): Q.35c5  Freq/go to spec emplys to encorg. Declared missing: 8, 9. Codes: 1 = Frequently; 2 = Sometimes; 3 = Never; 8 = Do not know; 9 = No response/refused.

- Variables: V143, V144
  - Wording: Q.36a Are there different levels of managers and administrators at (ORG)? Q.36b Are the procedures for promoting them to a higher level ... formal, or informal?
  - V143 (pos. 783, F1.0): Q.36a  There are diffrnt levels of mngrs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V144 (pos. 784, F1.0): Q.36b  Procedure fr promtng-formal/infml. Declared missing: 8, 9. Codes: 1 = Formal; 2 = Informal; 8 = Do not know; 9 = No response/refused.

### Formal job training (Q.37-Q.52)

- Variables: V145
  - Wording: Q.37 Apart from on-the-job training, in the past 2 years did (ORG) provide any employees with formal job training, either on or off the premises?
  - Universe/skip: All. No / don't know: skip to Q.53.
  - V145 (pos. 785, F1.0): Q.37  Provide formal job training. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V146, V147, V148
  - Wording: Q.38a Was any of the training conducted by staff on the premises? Q.38b About how many persons provided this training? Q.38c In the past 2 years, would you say that the size of the training staff has increased, decreased, or stayed the same?
  - Universe/skip: Q.37 = yes. Q.38a no/DK: skip to Box C.
  - V146 (pos. 786, F1.0): Q.38a  Training condctd by stff on prmss. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V147 (pos. 787, F3.0): Q.38b  Number of persons prvding trainng. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V148 (pos. 788, F1.0): Q.38c  Size of training staff -inc/dec. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Stayed the same; 8 = Do not know; 9 = No response/refused.

- Variables: V149
  - Wording: Q.39 Was any of this training conducted by staff from the (LARGER ORG), either on (ORG's) premises or by sending employees to (LARGER ORG)?
  - Universe/skip: Box C: part of a larger organization.
  - V149 (pos. 789, F1.0): Q.39  Training condctd by largr ORG stff. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V150, V151, V152, V153
  - Wording: Q.40 Was any formal job training conducted on (ORG's) premises by outside agencies, consultants, or schools? Q.41a Did any employees participate in training courses off the premises that were paid for by (ORG)? Q.41b For these employees, did (ORG) provide either tuition benefits or reimbursements? Q.41c Did (ORG) provide paid release time?
  - V150 (pos. 790, F1.0): Q.40  Training condctd by outsd agencies. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V151 (pos. 791, F1.0): Q.41a  Particpt in training off premises. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V152 (pos. 792, F1.0): Q.41b  ORG provide tuition/reimbursemts. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 3 = Varies/depends; 8 = Do not know; 9 = No response/refused.
  - V153 (pos. 793, F1.0): Q.41c  ORG provide paid release time. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 3 = Varies/depends; 8 = Do not know; 9 = No response/refused.

- Variables: V154
  - Wording: Q.42 In total, including staff time and all other costs, about how much money has (ORG) spent on training in the past 2 years?
  - V154 (pos. 794, F7.0): Q.42  Cost ORG spent on training in 2yrs. Declared missing: 9999998, 9999999. Codes: 9999996 = $10,000,000 or more; 9999999 = No response/refused.

- Variables: V155, V156
  - Wording: Q.43 Compared to 2 years ago, would you say that the amount of resources that (ORG) has devoted to training has increased, decreased, or remained about the same? Q.44 Compared to other places of roughly the same size, would you say that (ORG) devotes more or fewer resources to training?
  - V155 (pos. 795, F1.0): Q.43  Amt of resrcs ORG devotd to traing. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remaind abt the same; 8 = Do not know; 9 = No response/refused.
  - V156 (pos. 796, F1.0): Q.44  ORG devt more/less resrc to traing. Declared missing: 8, 9. Codes: 1 = More resources; 2 = Fewer resources; 3 = About the same; 8 = Do not know; 9 = No response/refused.

- Variables: V157
  - Wording: Q.45a Within the last 2 years, how many employees participated in formal training?
  - Universe/skip: Q.37 = yes.
  - Notes: Code 99996 = '100,000 employees +' (top code; not declared missing).
  - V157 (pos. 797, F5.0): Q.45a  Number of emplys prtcptd training. Declared missing: 99998, 99999. Codes: 99996 = 100,000 employees +; 99998 = Do not know; 99999 = No response/refused.

- Variables: V158, V159, V160
  - Wording: Q.45b Did any (READ CATEGORY) receive formal training? 1) (COREs) 2) (GSSs) 3) Managers or administrators. (IF GSS, CORE, OR MANAGER ARE SAME, CIRCLE '7'.)
  - V158 (pos. 798, F1.0): Q.45b1  Receive formal training / COREs. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V159 (pos. 799, F1.0): Q.45b2  Receive formal training / GSSs. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V160 (pos. 800, F1.0): Q.45b3  Receive formal training/ mgr-adm. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V161, V162, V163, V164
  - Wording: Q.46 To what extent is formal training used to ... a. Teach remedial skills in literacy or arithmetic? b. Train employees to use computers and other new equipment? c. Train employees on the safe use of equipment or tools? d. Provide or improve management skills? (To a great extent / To some extent / Very little / Not at all)
  - V161 (pos. 801, F1.0): Q.46a  Extent/teach remedial skills. Declared missing: 8, 9. Codes: 1 = To a great extent; 2 = To some extent; 3 = Very little; 4 = Not at all; 8 = Do not know; 9 = No response/refused.
  - V162 (pos. 802, F1.0): Q.46b  Extent/train emplys to use cmptrs. Declared missing: 8, 9. Codes: 1 = To a great extent; 2 = To some extent; 3 = Very little; 4 = Not at all; 8 = Do not know; 9 = No response/refused.
  - V163 (pos. 803, F1.0): Q.46c  Extent/train emply safe use equip. Declared missing: 8, 9. Codes: 1 = To a great extent; 2 = To some extent; 3 = Very little; 4 = Not at all; 8 = Do not know; 9 = No response/refused.
  - V164 (pos. 804, F1.0): Q.46d  Extent/provide/improve mgt skills. Declared missing: 8, 9. Codes: 1 = To a great extent; 2 = To some extent; 3 = Very little; 4 = Not at all; 8 = Do not know; 9 = No response/refused.

- Variables: V165, V166, V167
  - Wording: Q.47 Is any of the formal training offered ... a. Because of legal requirements? b. Because of union contracts? c. To keep up with the training practices of organizations that do work like yours?
  - V165 (pos. 805, F1.0): Q.47a  Reason/legal requirements. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V166 (pos. 806, F1.0): Q.47b  Reason/union contract. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V167 (pos. 807, F1.0): Q.47c  Reason/to keep up w/traing practc. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V168, V169, V170, V171
  - Wording: Q.48 Is any of the formal training evaluated using ... a. Formal testing of the trainees? b. Trainee opinions? c. Employee supervisor's evaluation of employee performance? d. The program director's assessment?
  - V168 (pos. 808, F1.0): Q.48a  Evaluation/formal testing. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V169 (pos. 809, F1.0): Q.48b  Evaluation/trainee opinions. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V170 (pos. 810, F1.0): Q.48c  Evaluation/supervisrs evaluation. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V171 (pos. 811, F1.0): Q.48d  Evaluation/prgm dirctrs assessmt. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V172
  - Wording: Q.49 Overall, how effective would you say your employee training is? Would you say ... Highly effective, Somewhat effective, or Not at all effective?
  - Universe/skip: Q.37 = yes.
  - Notes: Stored codes: 1 highly effective, 2 somewhat effective, 3 not at all effective, 4 varies/depends (volunteered; not declared missing), 8 don't know, 9 no response.
  - V172 (pos. 812, F1.0): Q.49  Effectiveness of training. Declared missing: 8, 9. Codes: 1 = Highly effective; 2 = Somewhat effective; 3 = Not at all effective; 4 = Varies/depends; 8 = Do not know; 9 = No response/refused.

- Variables: V173
  - Wording: Q.50 Apart from formal education, how important is formal training as a factor in employees' promotion chances? Is it ... Essential, Very important, Somewhat important, or Not at all important?
  - V173 (pos. 813, F1.0): Q.50  Imprtnce of trng fr promotn chance. Declared missing: 7, 8, 9. Codes: 1 = Essential; 2 = Very important; 3 = Somewhat important; 4 = Not at all important; 5 = Varies/depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V174, V175, V176
  - Wording: Q.51 Is any of the formal training paid for by federal, state, or local government agencies? Q.52a Is any training funded by JTPA, the Job Training Program Act? (as printed) Q.52b What types of training are funded by JTPA?
  - V174 (pos. 814, F1.0): Q.51  Paid for by fed/state/local govmnt. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V175 (pos. 815, F1.0): Q.52a  Any training funded by JTPA. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V176 (pos. 816, F2.0): Q.52b  Types of training funded by JTPA. Declared missing: 98, 99. Codes: 1 = Verbatim resp listed; 98 = Do not know; 99 = No response/refused.

### Benefits (Q.53-Q.59)

- Variables: V177, V178, V179, V180, V181, V182, V183, V184, V185, V186, V187, V188
  - Wording: Q.53 Now I'd like to ask you about the kinds of benefits (ORG) provides to its employees. For each benefit, please tell me whether or not (ORG) offers it to [any] of its employees. Does (ORG) offer ... a. Medical or hospital insurance; b. Dental care benefits; c. Life insurance; d. Sick leave with full pay; e. Maternity leave with full re-employment rights; f. Assistance for elderly family members; g. Flexible hours or flextime scheduling; h. Cash or stock bonuses for performance or merit; i. A pension or retirement program; j. A profit-sharing or stock option program; k. Drug or alcohol abuse program; l. Long-term disability insurance.
  - Notes: Item wording abbreviated from variable labels where the scanned table is illegible; the bracketed word is partly illegible in the scan.
  - V177 (pos. 817, F1.0): Q.53a  Benefit/medical hospitl insurance. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V178 (pos. 818, F1.0): Q.53b  Benefit/dental care benefits. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V179 (pos. 819, F1.0): Q.53c  Benefit/life insurance. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V180 (pos. 820, F1.0): Q.53d  Benefit/sick leave with full pay. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V181 (pos. 821, F1.0): Q.53e  Benefit/matrnty leav w/re-emplymt. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V182 (pos. 822, F1.0): Q.53f  Benefit/assistnc fr elderly membr. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V183 (pos. 823, F1.0): Q.53g  Benefit/flexible hours/schedule. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V184 (pos. 824, F1.0): Q.53h  Benefit/cash/stock bonus fr pfmnc. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V185 (pos. 825, F1.0): Q.53i  Benefit/pension/retirement progrm. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V186 (pos. 826, F1.0): Q.53j  Benefit/profit-sharing program. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V187 (pos. 827, F1.0): Q.53k  Benefit/drug/alcohol abuse progrm. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V188 (pos. 828, F1.0): Q.53l  Benefit/long-term disabilty insrc. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V189, V190, V191, V192, V193, V194, V195, V196, V197, V198, V199, V200, V201, V202, V203, V204
  - Wording: Q.54-Q.59 Rating of the benefit package, changes in benefits and wages, child-care and parental-leave provisions (see variable labels).
  - V189 (pos. 829, F1.0): Q.54  Rate of benefit package. Declared missing: 8, 9. Codes: 1 = Better than most; 2 = About average; 3 = Not as good as most; 8 = Do not know; 9 = No response/refused.
  - V190 (pos. 830, F1.0): Q.55  ORG has increased fringe benefits. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V191 (pos. 831, F1.0): Q.56a  ORG/cut medical benefits. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V192 (pos. 832, F1.0): Q.56b  ORG/incd contrbtn to help pay/med. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V193 (pos. 833, F1.0): Q.56c  ORG/cut other fringe benefits. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V194 (pos. 834, F1.0): Q.56d  ORG/incd contrbtn to help pay/frg. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V195 (pos. 835, F1.0): Q.56e  ORG/lowered salaries/wages. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V196 (pos. 836, F1.0): Q.57  Problem of emplys w/young children. Declared missing: 8, 9. Codes: 1 = A great problem; 2 = Somewhat of a problm; 3 = No problem at all; 8 = Do not know; 9 = No response/refused.
  - V197 (pos. 837, F1.0): Q.58a1  ORG provide a day care program. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V198 (pos. 838, F1.0): Q.58b1  ORG considering program in 2 yrs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V199 (pos. 839, F1.0): Q.58a2  ORG help to cover day care cost. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V200 (pos. 840, F1.0): Q.58b2  ORG considering program in 2 yrs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V201 (pos. 841, F1.0): Q.58a3  ORG provide day care servc info. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V202 (pos. 842, F1.0): Q.58b3  ORG considering program in 2 yrs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V203 (pos. 843, F1.0): Q.59a  ORG provide paid parental leaves. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V204 (pos. 844, F1.0): Q.59b  ORG allow emply to take unpaid lv. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

### Earnings and pay criteria (Q.60-Q.67)

Box D before Q.64: IF GSS R'S OCCUPATION = CORE OR MANAGER, SKIP TO Q.66.

- Variables: V205, V206, V207
  - Wording: Q.60a Approximately what is the range of annual earnings (from all sources) for managers and other administrators at (ORG)? Q.60b About what are the annual earnings of most managers and administrators?
  - V205 (pos. 845, F7.0): Q.60a  Annual earnings Mgr - lowest. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.
  - V206 (pos. 846, F7.0): Q.60a  Annual earnings Mgr - highest. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.
  - V207 (pos. 847, F7.0): Q.60b  Annual earnings of most managers. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.

- Variables: V208, V209, V210, V211, V212, V213, V214, V215, V216
  - Wording: Q.61 How important are each of the following criteria for determining the earnings of managers and administrators at (ORG)? What about ... a. Experience acquired in this organization? b. Job performance? c. What other employers are paying? d. Amount of formal education? e. Relevant experience? f. Difficulty of the work? g. Supervisory responsibilities? h. Shortage of qualified people? i. What other managers and administrators are being paid at (ORG)? (If only 1 manager or administrator, skip to Q.62a.) (Very important / Somewhat important / Not important)
  - V208 (pos. 848, F1.0): Q.61a  Importance/experience in org. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V209 (pos. 849, F1.0): Q.61b  Importance/job performance. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V210 (pos. 850, F1.0): Q.61c  Importance/what othr emplyr payng. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V211 (pos. 851, F1.0): Q.61d  Importance/amt of formal educatin. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V212 (pos. 852, F1.0): Q.61e  Importance/relevant experience. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V213 (pos. 853, F1.0): Q.61f  Importance/difficulty of the work. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V214 (pos. 854, F1.0): Q.61g  Importance/supervisry responsblty. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V215 (pos. 855, F1.0): Q.61h  Importance/shrtg of qualfd people. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V216 (pos. 856, F1.0): Q.61i  Importance/othr mgrs are paid. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.

- Variables: V217, V218, V219
  - Wording: Q.62a Now I'd like to ask about (COREs). Approximately what is their range of annual earnings (from all sources) at (ORG)? Q.62b About what are the annual earnings of most (COREs)?
  - V217 (pos. 857, F7.0): Q.62a  Annual earnings CORE - lowest. Declared missing: 9999998, 9999999. Codes: 9999998 = Do not know; 9999999 = No response/refused.
  - V218 (pos. 858, F7.0): Q.62a  Annual earnings CORE - highest. Declared missing: 9999998, 9999999. Codes: 9999998 = Do not know; 9999999 = No response/refused.
  - V219 (pos. 859, F7.0): Q.62b  Annual earnings of most COREs. Declared missing: 9999998, 9999999. Codes: 9999998 = Do not know; 9999999 = No response/refused.

- Variables: V220, V221, V222, V223, V224, V225, V226, V227, V228, V229
  - Wording: Q.63 How important are each of the following for determining the earnings of (COREs) here? What about ... a. Union negotiations? Are they ... b. Experience acquired in this organization? c. Job performance? d. What other employers are paying? e. Amount of formal education? f. Relevant experience? g. Difficulty of the work? h. Supervisory responsibilities? i. Shortage of qualified people? j. What other (COREs) are being paid at ORG? (If only 1 CORE, skip.) (Very important / Somewhat important / Not important)
  - V220 (pos. 860, F1.0): Q.63a  Importance/union negotiations. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V221 (pos. 861, F1.0): Q.63b  Importance/experience in org. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V222 (pos. 862, F1.0): Q.63c  Importance/job performance. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V223 (pos. 863, F1.0): Q.63d  Importance/what othr emplyr payng. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V224 (pos. 864, F1.0): Q.63e  Importance/amt of formal educatin. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V225 (pos. 865, F1.0): Q.63f  Importance/relevant experience. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V226 (pos. 866, F1.0): Q.63g  Importance/difficulty of the work. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V227 (pos. 867, F1.0): Q.63h  Importance/supervisry responsblty. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V228 (pos. 868, F1.0): Q.63i  Importance/shrtg of qualfd people. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.
  - V229 (pos. 869, F1.0): Q.63j  Importance/othr COREs are paid. Declared missing: 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 8 = Do not know; 9 = No response/refused.

- Variables: V230, V231, V232
  - Wording: Q.64a Approximately what is the range of annual earnings (from all sources) of (GSSs) at (ORG)? Q.64b About what are the annual earnings of most (GSSs)?
  - Universe/skip: Box D.
  - V230 (pos. 870, F7.0): Q.64a  Annual earnings GSS - lowest. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.
  - V231 (pos. 871, F7.0): Q.64a  Annual earnings GSS - highest. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.
  - V232 (pos. 872, F7.0): Q.64b  Annual earnings of most GGSs. Declared missing: 9999997, 9999998, 9999999. Codes: 9999997 = Not applicable; 9999998 = Do not know; 9999999 = No response/refused.

- Variables: V233, V234, V235, V236, V237, V238, V239, V240, V241, V242
  - Wording: Q.65 How important are each of the following criteria for determining the earnings of (GSSs) here? What about ... a. Union negotiations? Are they ... b. Experience acquired in this organization? c. Job performance? d. What other employers are paying? e. Amount of formal education? f. Relevant experience? g. Difficulty of the work? h. Supervisory responsibilities? i. Shortage of qualified people? j. What other (GSSs) are being paid at ORG? (Very important / Somewhat important / Not important)
  - Universe/skip: Box D.
  - V233 (pos. 873, F1.0): Q.65a  Importance/union negotiations. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V234 (pos. 874, F1.0): Q.65b  Importance/experience in org. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V235 (pos. 875, F1.0): Q.65c  Importance/job performance. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V236 (pos. 876, F1.0): Q.65d  Importance/what othr emplyr payng. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V237 (pos. 877, F1.0): Q.65e  Importance/amt of formal educatin. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V238 (pos. 878, F1.0): Q.65f  Importance/relevant experience. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V239 (pos. 879, F1.0): Q.65g  Importance/difficulty of the work. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V240 (pos. 880, F1.0): Q.65h  Importance/supervisry responsblty. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V241 (pos. 881, F1.0): Q.65i  Importance/shrtg of qualfd people. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V242 (pos. 882, F1.0): Q.65j  Importance/othr GSSs are paid. Declared missing: 7, 8, 9. Codes: 1 = Very important; 2 = Somewhat important; 3 = Not important; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V243
  - Wording: Q.66 Now I'd like you to think about all of the positions at (ORG). Would you say that the variability of earnings among these positions is ... very great, great, moderate, small, or very small?
  - V243 (pos. 883, F1.0): Q.66  Variablty of earnings amg ORG pstn. Declared missing: 7, 8, 9. Codes: 1 = Very great; 2 = Great; 3 = Moderate; 4 = Small; 5 = Very small; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V244
  - Wording: Q.67 The overall performance of (ORG) would be improved if people in different jobs were paid more equally than they are now. Do you ... agree, or disagree?
  - V244 (pos. 884, F1.0): Q.67  Improved if people paid equally. Declared missing: 7, 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

### Work organization, hierarchy, formalization and disputes (Q.68-Q.71)

- Variables: V245, V246, V247, V248, V249, V250, V251, V252, V253, V254, V255, V256, V257, V258, V259, V260
  - Wording: Q.68a Now I'd like to ask you about how work is organized at (ORG). Is there at least one employee whose main responsibility is ... 1) Finance? 2) Accounting? 3) Health and safety? 4) Public relations? 5) Personnel or labor relations? 6) Research and development? 7) Long-range planning? 8) Marketing or sales? (IF YES) Q.68b Is there a separate department or section responsible for (ITEM)?
  - V245 (pos. 885, F1.0): Q.68a1  Main resp/finance. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V246 (pos. 886, F1.0): Q.68b1  Separate Finance Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V247 (pos. 887, F1.0): Q.68a2  Main resp/accounting. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V248 (pos. 888, F1.0): Q.68b2  Separate Accounting Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V249 (pos. 889, F1.0): Q.68a3  Main resp/health and safety. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V250 (pos. 890, F1.0): Q.68b3  Separate Health and Safety Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V251 (pos. 891, F1.0): Q.68a4  Main resp/public relations. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V252 (pos. 892, F1.0): Q.68b4  Separate Public Relations Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V253 (pos. 893, F1.0): Q.68a5  Main resp/personnel-labor reltns. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V254 (pos. 894, F1.0): Q.68b5  Separate Personnel Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V255 (pos. 895, F1.0): Q.68a6  Main resp/research and develpmnt. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V256 (pos. 896, F1.0): Q.68b6  Separate R and D Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V257 (pos. 897, F1.0): Q.68a7  Main resp/long-range planning. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V258 (pos. 898, F1.0): Q.68b7  Separate Long Range Plng Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V259 (pos. 899, F1.0): Q.68a8  Main resp/marketing or sales. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V260 (pos. 900, F1.0): Q.68b8  Separate Mktg - Sales Dept. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V261
  - Wording: Q.69 About how many vertical levels are there between the highest and lowest positions at (ORG), including both the highest and lowest levels?
  - Notes: Code 96 = '100 levels or more' (not declared missing).
  - V261 (pos. 901, F2.0): Q.69  Number of vertcl levels btwn postn. Declared missing: 98, 99. Codes: 96 = 100 levels or more; 98 = Do not know; 99 = No response/refused.

- Variables: V262, V263, V264, V265, V266, V267, V268, V269
  - Wording: Q.70 Do each of the following documents exist at (ORG)? What about ... a. A 'rules and procedures' manual? b. Written job descriptions for most jobs? c. A written record of nearly everyone's job performance? d. Employment contracts? e. Documents telling how personnel evaluations are carried out? f. Documents outlining hiring and firing procedures? g. Documents describing safety and hygiene practices? h. Documents describing fringe benefits available to employees?
  - V262 (pos. 902, F1.0): Q.70a  Exist/rules and procedures manual. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V263 (pos. 903, F1.0): Q.70b  Exist/written job description. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V264 (pos. 904, F1.0): Q.70c  Exist/writtn record of job perfmc. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V265 (pos. 905, F1.0): Q.70d  Exist/employment contracts. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V266 (pos. 906, F1.0): Q.70e  Exist/personnel evaltn documents. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V267 (pos. 907, F1.0): Q.70f  Exist/hire-fire procedr documents. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V268 (pos. 908, F1.0): Q.70g  Exist/safety-hygiene practc docmt. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V269 (pos. 909, F1.0): Q.70h  Exist/fringe benefit documents. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.

- Variables: V270
  - Wording: Q.71 Are there formal procedures for resolving disputes between employees and their supervisors or coworkers?
  - Universe/skip: All.
  - V270 (pos. 910, F1.0): Q.71  Formal procedrs for reslvng dispts. Declared missing: 7, 8, 9. Codes: 1 = Yes; 2 = No; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

### Decision-making (Q.72)

Box E: IF PART OF LARGER ORG, ASK Q.72a, THEN SKIP TO Q.73. IF NOT PART OF LARGER ORG, ASK Q.72b. The same eight decision areas are therefore stored in two variable sets according to Q.4a.

- Variables: V271, V272, V273, V274, V275, V276, V277, V278
  - Wording: Q.72a We are interested in who is responsible for making different kinds of decisions in your workplace. I am going to read a list of decision areas, and ask you to tell me who actually makes the final decision in each area. Is it the head of (ORG), someone below that, or someone at (LARGER ORG)? (CIRCLE ALL THAT APPLY.) Who actually makes the final decision about ... 1) The number of people employed here? 2) Which new employees to hire? 3) Using subcontractors or temporary workers? 4) Evaluating worker performance? 5) Worker promotions? 6) Wage rates or salary levels? 7) Discharging or laying off workers? 8) Worker scheduling and overtime?
  - Universe/skip: Part of a larger organization (Q.4a = 1).
  - Notes: Printed response codes: 1 head of ORG; 2 someone below; 3 someone at larger org; 4 head and below; 5 head and larger org; 6 depends; 7 not applicable; 9 no response.
  - V271 (pos. 911, F1.0): Q.72a1  Larger ORG/nmbr of people emplyd. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V272 (pos. 912, F1.0): Q.72a2  Larger ORG/new employees to hire. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V273 (pos. 913, F1.0): Q.72a3  Larger ORG/subcntrctrs-temporary. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V274 (pos. 914, F1.0): Q.72a4  Larger ORG/evaltg wkr perfrmace. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V275 (pos. 915, F1.0): Q.72a5  Larger ORG/worker promotions. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V276 (pos. 916, F1.0): Q.72a6  Larger ORG/wage rate-salary lvls. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V277 (pos. 917, F1.0): Q.72a7  Larger ORG/dischg-layng off wrks. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V278 (pos. 918, F1.0): Q.72a8  Larger ORG/scheduling - overtime. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone at largr org; 4 = Head and below; 5 = Head and larger org; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V279, V280, V281, V282, V283, V284, V285, V286
  - Wording: Q.72b We are interested in who is responsible for making different kinds of decisions in your workplace. I am going to read a list of decision areas, and ask you to tell me who actually makes the final decision in each area. Is it the head of (ORG) or someone below? Who actually makes the final decision about ... 1) The number of people employed here? 2) Which new employees to hire? 3) Using subcontractors or temporary workers? 4) Evaluating worker performance? 5) Worker promotions? 6) Wage rates or salary levels? 7) Discharging or laying off workers? 8) Worker scheduling and overtime?
  - Universe/skip: Completely independent organizations (Q.4a = 2).
  - Notes: Codebook printed response codes: 1 head of ORG; 2 someone below; 3 someone at larger org; 4 head and below; 7 not applicable; 8 don't know. The .por value labels instead read 3 'someone above', 5 'head and above', 6 'depends'.
  - V279 (pos. 919, F1.0): Q.72b1  ORG/number of people employed. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V280 (pos. 920, F1.0): Q.72b2  ORG/new employees to hire. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V281 (pos. 921, F1.0): Q.72b3  ORG/subcntrctrs-temporary workrs. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V282 (pos. 922, F1.0): Q.72b4  ORG/evaluating worker perfrmace. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V283 (pos. 923, F1.0): Q.72b5  ORG/worker promotions. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V284 (pos. 924, F1.0): Q.72b6  ORG/wage rate or salary levels. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V285 (pos. 925, F1.0): Q.72b7  ORG/discharging-laying off wrkrs. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V286 (pos. 926, F1.0): Q.72b8  ORG/worker scheduling - overtime. Declared missing: 7, 8, 9. Codes: 1 = The head of org; 2 = Someone below; 3 = Someone above; 4 = Head and below; 5 = Head and above; 6 = Depends; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

### Performance assessments (Q.73-Q.76)

- Variables: V287, V288
  - Wording: Q.73 Compared to 1 year ago, is (ORG's) current performance in producing its main product or service ... much better, somewhat better, about the same, or worse? Q.74 Compared to 3 years ago, ... (same)
  - V287 (pos. 927, F1.0): Q.73  ORGs current performance-1 yr ago. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V288 (pos. 928, F1.0): Q.74  ORGs current performance-3 yr ago. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V289, V290, V291, V292, V293, V294, V295
  - Wording: Q.75 How would you compare (ORG's) performance over the past 3 years to that of other organizations that do the same kind of work? What about ... a. Quality of products, services, or programs b. Development of new products, services, or programs c. Ability to attract essential employees d. Ability to retain essential employees e. Satisfaction of customers or clients f. Relations between management and other employees g. Relations among employees in general
  - Universe/skip: All.
  - Notes: Response categories: much better, somewhat better, about the same, worse; not applicable, don't know, no response. The V293 label reads 'Q.74e' in the codebook header but the item is Q.75e.
  - V289 (pos. 929, F1.0): Q.75a  Perform/quality of prodts-service. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V290 (pos. 930, F1.0): Q.75b  Perform/development of new prodts. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V291 (pos. 931, F1.0): Q.75c  Perform/ability to attract emplys. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V292 (pos. 932, F1.0): Q.75d  Perform/ability to retain emplyes. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V293 (pos. 933, F1.0): Q.75e  Perform/satisfaction of customers. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V294 (pos. 934, F1.0): Q.75f  Perform/relation btwn mgmnt-emply. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V295 (pos. 935, F1.0): Q.75g  Perform/relations among employees. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V296, V297, V298, V299
  - Wording: Q.76 Compared to other organizations that do the same kind of work, how would you compare (ORG's) performance over the past 3 years in terms of ... a. Marketing? b. Growth in sales? c. Profitability? d. Market share?
  - Universe/skip: Box F: IF ORGANIZATION IS PROFIT-MAKING CONTINUE. OTHERWISE, SKIP TO Q.77.
  - Notes: Response categories: much better, somewhat better, about the same, worse; not applicable, don't know, no response.
  - V296 (pos. 936, F1.0): Q.76a  Performance/marketing. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V297 (pos. 937, F1.0): Q.76b  Performance/growth in sales. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V298 (pos. 938, F1.0): Q.76c  Performance/profitability. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V299 (pos. 939, F1.0): Q.76d  Performance/market share. Declared missing: 7, 8, 9. Codes: 1 = Much better; 2 = Somewhat better; 3 = About the same; 4 = Worse; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

### Environment, problems, unions and competition (Q.77-Q.89)

- Variables: V300, V301, V302, V303, V304, V305, V306, V307
  - Wording: Q.77 Over the next 3 years, how big a problem will each of the following be for (ORG)? What about ... a. Relations with unions? b. Government regulations? c. Hiring enough qualified workers? d. Retaining qualified employees? e. Improving employee compensation and benefits? f. Improving the quality of your products, services, or programs? g. Developing new products, services, or programs? h. Increasing productivity? (A major problem / A minor problem / Not a problem at all)
  - V300 (pos. 940, F1.0): Q.77a  Problem/relations with unions. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V301 (pos. 941, F1.0): Q.77b  Problem/government regulations. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V302 (pos. 942, F1.0): Q.77c  Problem/hiring enough qualfd wrks. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V303 (pos. 943, F1.0): Q.77d  Problem/retaining qualfd employee. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V304 (pos. 944, F1.0): Q.77e  Problem/improving compensation. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V305 (pos. 945, F1.0): Q.77f  Problem/improving quality of prod. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V306 (pos. 946, F1.0): Q.77g  Problem/developing new prod-servc. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V307 (pos. 947, F1.0): Q.77h  Problem/increasing productivity. Declared missing: 7, 8, 9. Codes: 1 = A major problem; 2 = A minor problem; 3 = Not a problem at all; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V308, V309, V310, V311, V312, V313, V314
  - Wording: Q.78 For each of the following statements, please tell me if you agree or disagree. a. The techniques, skills, and information needed by (ORG) are changing very rapidly. b. To achieve our goals, it is essential to work cooperatively with many other organizations. c. The political climate of the country right now is very favorable to our goals. d. Our relations with other organizations are sometimes marked by conflict. e. (ORG) concentrates on doing what it does well and takes few risks. f. (ORG) mostly reacts to outside pressures. g. Making long-range plans for this organization is hindered by the difficulty of predicting future events.
  - V308 (pos. 948, F1.0): Q.78a  Techniques changing rapidly. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V309 (pos. 949, F1.0): Q.78b  Essential to wk cooperatvly. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V310 (pos. 950, F1.0): Q.78c  Politcl climate is favorble. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V311 (pos. 951, F1.0): Q.78d  Relation w/org is conflict. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V312 (pos. 952, F1.0): Q.78e  Concentrate do well/few risk. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V313 (pos. 953, F1.0): Q.78f  Reacts to outside pressures. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V314 (pos. 954, F1.0): Q.78g  Making long-range plan. Declared missing: 8, 9. Codes: 1 = Agree; 2 = Disagree; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V315, V316, V317
  - Wording: Q.79 Is (ORG) subject to a periodic review by an outside accreditation or licensing organization? Q.80 Does (ORG) belong to an association of organizations like it? Q.81 In evaluating (ORG's) performance, to what extent do you pay attention to the practices of other organizations like (ORG)?
  - V315 (pos. 955, F1.0): Q.79  ORG is subject to periodic review. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V316 (pos. 956, F1.0): Q.80  ORG belongs to association of orgs. Declared missing: 8, 9. Codes: 1 = Yes; 2 = No; 8 = Do not know; 9 = No response/refused.
  - V317 (pos. 957, F1.0): Q.81  Pay attention to othr org practice. Declared missing: 8, 9. Codes: 1 = Very much; 2 = Somewhat; 3 = Very little; 8 = Do not know; 9 = No response/refused.

- Variables: V318, V319, V320, V321, V322, V323, V324, V325
  - Wording: Q.82a In the past 12 months, have (ORG's) sales increased, decreased, or remained the same? Q.82b-c By about what percentage? Q.83a In the past 12 months, have (ORG's) profits increased, decreased, or remained the same? Q.83b-c By about what percentage? Q.84a What would you consider to be (ORG's) main market area? Q.84b What percentage of (ORG's) sales are located outside of the U.S.?
  - Universe/skip: Box G: IF ORGANIZATION IS PROFIT-MAKING CONTINUE. OTHERWISE, SKIP TO Q.85a.
  - V318 (pos. 958, F1.0): Q.82a  ORGs sales changes - past 12 mos. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 8 = Do not know; 9 = No response/refused.
  - V319 (pos. 959, F3.0): Q.82b  Percentage increased. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V320 (pos. 960, F3.0): Q.82c  Percentage decreased. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V321 (pos. 961, F1.0): Q.83a  ORGs profits changes - past 12mts. Declared missing: 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Remained the same; 8 = Do not know; 9 = No response/refused.
  - V322 (pos. 962, F3.0): Q.83b  Percentage increased. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V323 (pos. 963, F3.0): Q.83c  Percentage decreased. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.
  - V324 (pos. 964, F1.0): Q.84a  ORGs main market area. Declared missing: 8, 9. Codes: 1 = Nghbrhd/part of city; 2 = City/cnty/metro area; 3 = State; 4 = Region; 5 = Entire U.S.; 6 = Beyond the U.S.; 8 = Do not know; 9 = No response/refused.
  - V325 (pos. 965, F3.0): Q.84b  Percentage of outside U.S. sales. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V326, V327
  - Wording: Q.85a What would you consider to be the main area served by (ORG)? Q.85b What percentage of (ORG's) operations are located outside of the U.S.?
  - Universe/skip: Not-for-profit organizations (Box G).
  - V326 (pos. 966, F1.0): Q.85a  Main area served by ORG. Declared missing: 8, 9. Codes: 1 = Nghbrhd/part of city; 2 = City/cnty/metro area; 3 = State; 4 = Region; 5 = Entire U.S.; 6 = Beyond the U.S.; 8 = Do not know; 9 = No response/refused.
  - V327 (pos. 967, F3.0): Q.85b  Percentage of operations outsd US. Declared missing: 998, 999. Codes: 998 = Do not know; 999 = No response/refused.

- Variables: V328
  - Wording: Q.86 How much competition would you say there is in (ORG's) main market or service area? Would you say ... None (SKIP TO Q.88), Very little, A moderate amount, or A great deal? NOT APPLICABLE (SKIP TO Q.89)
  - Universe/skip: All.
  - V328 (pos. 968, F1.0): Q.86  Competition in main mkt/serv area. Declared missing: 7, 8, 9. Codes: 1 = None; 2 = Very little; 3 = Moderate amount; 4 = A great deal; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V329, V330
  - Wording: Q.87 How much competition would you say there is in (ORG's) main market or service area from foreign organizations? Q.88 In the past 3 years, has the amount of competition in (ORG's) market or service area increased, or decreased?
  - V329 (pos. 969, F1.0): Q.87  Competition in area fm foreign org. Declared missing: 7, 8, 9. Codes: 1 = None; 2 = Very little; 3 = Moderate amount; 4 = A great deal; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.
  - V330 (pos. 970, F1.0): Q.88  Amount of competition in past 3yrs. Declared missing: 7, 8, 9. Codes: 1 = Increased; 2 = Decreased; 3 = Stayd about the same; 7 = Not applicable; 8 = Do not know; 9 = No response/refused.

- Variables: V331
  - Wording: Q.89 How much are (ORG's) operations regulated by government agencies? Would you say ... almost completely, very much, somewhat, very little, or not at all?
  - V331 (pos. 971, F1.0): Q.89  Operation regultd by govt agencies. Declared missing: 7, 8, 9. Codes: 1 = Almost completely; 2 = Very much; 3 = Somewhat; 4 = Very little; 5 = Not at all; 8 = Do not know; 9 = No response/refused.

- Variables: V332, V333
  - Wording: Q.90a Approximately what is (ORG's) total operating budget for this fiscal year? (IF 'DON'T KNOW', ASK FOR R'S BEST ESTIMATE) Q.90b (Interviewer: indicate how confident of estimate R was)
  - V332 (pos. 972, F10.0): Q.90a  Total operating budget fr fisc yr. Declared missing: 9999999998, 9999999999. Codes: 9999999998 = Do not know; 9999999999 = No response/refused.
  - V333 (pos. 973, F1.0): Q.90b  Confident of estimate. Declared missing: 4, 9. Codes: 1 = Very confident; 2 = Somewhat confident; 3 = Not very confident; 4 = Not applicable/DK; 9 = No response/refused.

### Informant and interview (Q.94-Q.100)

- Variables: V341, V342, V344, V346
  - Wording: Q.94 How many years have you worked for (ORG/LARGER ORG)? Q.95a What is your job title? Q.96 In what year were you born? Q.98 (Interviewer: gender of respondent)
  - V341 (pos. 981, F2.0): Q.94  Years R has worked for ORG. Declared missing: 98, 99. Codes: 98 = Do not know; 99 = No response/refused.
  - V342 (pos. 982, F2.0): Q.95a  Rs job title. Declared missing: 98, 99. Codes: 1 = Owner/partner; 2 = Head of Personnel; 3 = Asst in Personnel; 4 = Director-Gen Dept; 5 = Head-General Dept; 6 = Gen Administrator; 7 = Mgr of establishment; 8 = Mgr of operations; 9 = Business Manager; 10 = Office Manager; 11 = General Manager; 12 = Assistant Manager; 13 = Administrative Asst; 14 = Clerk/Bookkeeper/Sec; 15 = Accountnt/Comptrollr; 16 = Occup title-Profssnl; 17 = Occ titl-Blue Collar; 18 = President; 19 = Vice-President; 20 = Treasurer; 21 = Chancellor/Provost; 22 = Asst Chncllr/Provost; 23 = Dean; 24 = Assistant Dean; 25 = Principal; 26 = Assistant Principal; 27 = Superintendent; 28 = Asst Superintendent; 29 = Board member/Trustee; 30 = CEO government unit; 31 = Othr governmnt title; 32 = Training coord/mgr; 33 = Indus rels/publ rels; 34 = Statistical analyst; 35 = Asst Dir-Gen/Nonpers; 90 = Has no job title; 98 = Do not know; 99 = No response/refused.
  - V344 (pos. 984, F2.0): Q.96  Year R was born. Declared missing: 98, 99. Codes: 98 = Do not know; 99 = No response/refused.
  - V346 (pos. 986, F1.0): Q.98  Gender of R. Declared missing: 8, 9. Codes: 1 = Male; 2 = Female; 9 = No response/refused.

- Variables: V347, V348
  - Wording: Q.99 Was (major) respondent from ORG or LARGER ORG? Q.100 Was second respondent from ORG or LARGER ORG? (answer only if there was a second respondent)
  - V347 (pos. 987, F1.0): Q.99  Major R from ORG or LARGER ORG. Declared missing: 8, 9. Codes: 1 = Org; 2 = Larger org; 9 = No response/refused.
  - V348 (pos. 988, F1.0): Q.100  Second R from ORG or LARGER ORG. Declared missing: 8, 9. Codes: 1 = Org; 2 = Larger org; 9 = No response/refused.

- Variables: V2, V4, V7, V345, V350, V351, V352, V353, GSSBUCKS, COMBMOST
  - Wording: Administrative items: study number, interviewer ID, interview start/end time, telephone area code and prefix, ZIP code, coder ID, and two undocumented items.
  - V2 (pos. 643, F3.0): Study Number. Declared missing: none. Codes: 666 = Study number.
  - V4 (pos. 645, F3.0): Interviewer Identification Number. Declared missing: none. Codes: 0 = No phone.
  - V7 (pos. 648, F4.0): Time Interview Begin. Declared missing: 9998, 9999. Codes: 9999 = No response/refused.
  - V345 (pos. 985, F4.0): Time interview ended. Declared missing: 9998, 9999. Codes: 9999 = No response/refused.
  - V350 (pos. 990, F3.0): Telephone number area code. Declared missing: 998, 999. Codes: 999 = No response/refused.
  - V351 (pos. 991, F3.0): Telephone number prefix. Declared missing: 998, 999. Codes: 999 = No response/refused.
  - V352 (pos. 992, F5.0): Zip code. Declared missing: 99998, 99999. Codes: 99999 = No response/refused.
  - V353 (pos. 993, F3.0): Coder identification number. Declared missing: none.
  - GSSBUCKS (pos. 994, F8.2): None. Declared missing: none.
  - COMBMOST (pos. 995, F8.2): None. Declared missing: none.

## All variables (compact list)

Value labels for every variable are in nos1991_dictionary.json (all_variables_compact).

| Pos. | Name | Label | Format | Declared missing |
|---|---|---|---|---|
| 1 | INDUSTRY | 1980 CENSUS INDUSTRY CODE | F8.2 | -999 |
| 2 | PCTWOMEN | PERCENT OF EMPLOYEES WOMEN | F8.2 | -999 |
| 3 | PCTPRODW | PERCENT OF PROD/NON-SUPERV WORKERS | F8.2 | -999 |
| 4 | WKWAGE | AVG WEEKLY WAGE OF P/N-S WORKERS | F8.2 | -999 |
| 5 | HRWAGE | AVG HOURLY WAGE OF P/N-S WORKERS | F8.2 | -999 |
| 6 | WKHOUR | AVG WEEKLY HOURS OF P/N-S WORKERS | F8.2 | -999 |
| 7 | TOTUNEM | UNEMPLOYMENT RATE - ALL WORKERS | F8.2 | -999 |
| 8 | MALEUNEM | UNEMPLOYMENT RATE - MALES | F8.2 | -999 |
| 9 | FEMAUNEM | UNEMPLOYMENT RATE - FEMALES | F8.2 | -999 |
| 10 | CONCASS1 | % ASSETS HELD BY >$250 MIL ASSET FIRMS | F8.2 | -999 |
| 11 | CONCASS2 | % ASSETS HELD BY >$100 MIL ASSET FIRMS | F8.2 | -999 |
| 12 | CONCREC1 | % SALES BY >$50 MIL RECEIPTS FIRMS | F8.2 | -999 |
| 13 | CONCREC2 | % SALES BY >$100 MIL RECEIPTS FIRMS | F8.2 | -999 |
| 14 | CPROFBT | % CHANGE IN CORP PROFITS BEFORE TAXES | F8.2 | -999 |
| 15 | CPROFUN | % CHANGE IN UNDISTRIBUTED CORP PROFITS | F8.2 | -999 |
| 16 | PROFBEMP | BEFORE TAX PROFITS PER EMPLOYEE | F8.2 | -999 |
| 17 | PROFUEMP | UNDISTRIBUTED PROFITS PER EMPLOYEE | F8.2 | -999 |
| 18 | LABSHAR1 | WAGES AS PERCENT OF INCOME | F8.2 | -999 |
| 19 | LABSHAR2 | COMPENSATION AS PERCENT OF INCOME | F8.2 | -999 |
| 20 | ASSTSIZE | AVERAGE ASSET SIZE OF CORPORATIONS | F8.2 | -999 |
| 21 | SALESIZE | AVERAGE SALES SIZE OF CORPORATIONS | F8.2 | -999 |
| 22 | PROFSIZE | AVERAGE PROFITS PER FIRM | F8.2 | -999 |
| 23 | PROFASST | CORP PROFITS AS PERCENT OF CORP ASSETS | F8.2 | -999 |
| 24 | PROFSALE | CORP PROFITS AS PERCENT OF CORP SALES | F8.2 | -999 |
| 25 | INVSALES | CORPORATE SALES-TO-INVENTORY RATIO | F8.2 | -999 |
| 26 | SECOND | SECONDARY LABOR MARKET INDEX | F8.2 | -999 |
| 27 | AVGWS | AVG WAGES AND SALARIES PER WORKER | F8.2 | -999 |
| 28 | AVGCOMP | AVG COMPENSATION PER WORKER | F8.2 | -999 |
| 29 | ORGEFF1 | % ELIGIBLE VOTERS IN NLRB ELECTIONS | F8.2 | -999 |
| 30 | UNFAIR | NLRB UNFAIR LABOR PRAC CASES PER EMP | F8.2 | -999 |
| 31 | VATWORK | VALUE ADDED PER EMPLOYEE (ALL EMPS) | F8.2 | -999 |
| 32 | VAPWORK | VALUE ADDED PER PRODUCTION WORKER | F8.2 | -999 |
| 33 | CAPINT1 | TOTAL EXPENDITURES PER EMP (ALL EMPS) | F8.2 | -999 |
| 34 | CAPINT2 | TOTAL EXPENDITURES PER PROD WORKER | F8.2 | -999 |
| 35 | CAPINT3 | TOTAL EXPENDITURES/TOTAL PAYROLL | F8.2 | -999 |
| 36 | CAPINT4 | TOTAL EXPENDITURES/TOT PROD WAGES | F8.2 | -999 |
| 37 | AVGESTAB | AVG ESTABLISHMENT EMPLOYMENT SIZE | F8.2 | -999 |
| 38 | PCTUNION | % WORKERS BELONGING TO UNIONS | F8.2 | -999 |
| 39 | CAPUTIL | CAPACITY UTILIZATION RATE | F8.2 | -999 |
| 40 | V43 | Q.8c  Main product / service of ORG | F3.0 | none |
| 41 | YEAR | GSS YEAR FOR THIS RESPONDENT | F2.0 | none |
| 42 | ID | RESPONDENT ID NUMBER | F4.0 | none |
| 43 | WRKSTAT | LABOR FORCE STATUS | F1.0 | 0, 9 |
| 44 | HRS1 | NUMBER OF HOURS WORKED LAST WEEK | F2.0 | -1, 98, 99 |
| 45 | HRS2 | NUMBER OF HOURS USUALLY WORK A WEEK | F2.0 | -1, 98, 99 |
| 46 | EVWORK | EVER WORK AS LONG AS ONE YEAR | F1.0 | 0, 8, 9 |
| 47 | WRKSLF | R SELF-EMP OR WORKS FOR SOMEBODY | F1.0 | 0, 8, 9 |
| 48 | OCC80 | RS CENSUS OCCUPATION CODE (1980) | F3.0 | 0, 998, 999 |
| 49 | PRESTG80 | RS OCCUPATIONAL PRESTIGE SCORE  (1980) | F2.0 | 0 |
| 50 | INDUS80 | RS INDUSTRY CODE   (1980) | F3.0 | 0, 998, 999 |
| 51 | MARITAL | MARITAL STATUS | F1.0 | 9 |
| 52 | AGEWED | AGE WHEN FIRST MARRIED | F2.0 | 0, 98, 99 |
| 53 | DIVORCE | EVER BEEN DIVORCED OR SEPARATED | F1.0 | 0, 8, 9 |
| 54 | WIDOWED | EVER BEEN WIDOWED | F1.0 | 0, 8, 9 |
| 55 | SPWRKSTA | SPOUSE LABOR FORCE STATUS | F1.0 | 0, 9 |
| 56 | SPHRS1 | NUMBER OF HRS SPOUSE WORKED LAST WEEK | F2.0 | -1, 98, 99 |
| 57 | SPHRS2 | NO. OF HRS SPOUSE USUALLY WORKS A WEEK | F2.0 | -1, 98, 99 |
| 58 | SPEVWORK | SPOUSE EVER WORK AS LONG AS A YEAR | F1.0 | 0, 8, 9 |
| 59 | SPWRKSLF | SPOUSE SELF-EMP. OR WORKS FOR SOMEBODY | F1.0 | 0, 8, 9 |
| 60 | SPOCC80 | SPOUSE CENSUS OCCUPATION CODE (1980) | F3.0 | 0, 998, 999 |
| 61 | SPPRES80 | SPOUSES OCCUPATIONAL PRESTIGE SCORE (1980) | F2.0 | 0 |
| 62 | SPIND80 | SPOUSES INDUSTRY CODE (1970) | F3.0 | 0, 998, 999 |
| 63 | PAWRKSLF | FATHER SELF-EMP. OR WORKED FOR SOMEBODY | F1.0 | 0, 8, 9 |
| 64 | PAOCC80 | FATHERS CENSUS OCCUPATION CODE (1980) | F3.0 | none |
| 65 | PAPRES80 | FATHERS OCCUPATIONAL PRESTIGE SCORE (1980) | F2.0 | 0 |
| 66 | PAIND80 | FATHERS INDUSTRY CODE (1980) | F3.0 | 0, 998, 999 |
| 67 | SIBS | NUMBER OF BROTHERS AND SISTERS | F2.0 | 98, 99 |
| 68 | CHILDS | NUMBER OF CHILDREN | F1.0 | 9 |
| 69 | AGE | AGE OF RESPONDENT | F2.0 | 0, 98, 99 |
| 70 | BIRTHMO | MONTH IN WHICH R WAS BORN | F2.0 | 0, 98, 99 |
| 71 | ZODIAC | RESPONDENTS ASTROLOGICAL SIGN | F2.0 | 0, 98, 99 |
| 72 | EDUC | HIGHEST YEAR OF SCHOOL COMPLETED | F2.0 | 97, 98, 99 |
| 73 | PAEDUC | HIGHEST YEAR SCHOOL COMPLETED, FATHER | F2.0 | 97, 98, 99 |
| 74 | MAEDUC | HIGHEST YEAR SCHOOL COMPLETED, MOTHER | F2.0 | 97, 98, 99 |
| 75 | SPEDUC | HIGHEST YEAR SCHOOL COMPLETED, SPOUSE | F2.0 | 97, 98, 99 |
| 76 | DEGREE | RS HIGHEST DEGREE | F1.0 | 7, 8, 9 |
| 77 | PADEG | FATHERS HIGHEST DEGREE | F1.0 | 7, 8, 9 |
| 78 | MADEG | MOTHERS HIGHEST DEGREE | F1.0 | 7, 8, 9 |
| 79 | SPDEG | SPOUSES HIGHEST DEGREE | F1.0 | 7, 8, 9 |
| 80 | SEX | RESPONDENTS SEX | F1.0 | none |
| 81 | RACE | RACE OF RESPONDENT | F1.0 | none |
| 82 | RES16 | TYPE OF PLACE LIVED IN WHEN 16 YRS OLD | F1.0 | 8, 9 |
| 83 | REG16 | REGION OF RESIDENCE, AGE 16 | F1.0 | none |
| 84 | MOBILE16 | GEOGRAPHIC MOBILITY SINCE AGE 16 | F1.0 | 8, 9 |
| 85 | FAMILY16 | LIVING WITH PARENTS WHEN 16 YRS OLD | F1.0 | 9 |
| 86 | FAMDIF16 | REASON NOT LIVING WITH PARENTS | F1.0 | 0, 8, 9 |
| 87 | MAWORK | MOTHERS EMPLOYMENT SINCE MARRIAGE | F1.0 | 0, 8, 9 |
| 88 | MAWKBORN | MOTHERS EMPLOYMENT AFTER R WAS BORN | F1.0 | 0, 8, 9 |
| 89 | INCOM16 | RS FAMILY INCOME WHEN 16 YRS OLD | F1.0 | 0, 8, 9 |
| 90 | BORN | WAS R BORN IN THIS COUNTRY | F1.0 | 0, 8, 9 |
| 91 | PARBORN | WERE RS PARENTS BORN IN THIS COUNTRY | F2.0 | -1, 9 |
| 92 | GRANBORN | HOW MANY GRANDPARENTS BORN OUTSIDE U.S. | F2.0 | -1, 8, 9 |
| 93 | HOMPOP | NUMBER OF PERSONS IN HOUSEHOLD | F2.0 | 0, 98, 99 |
| 94 | BABIES | HOUSEHOLD MEMBERS LESS THAN 6 YRS OLD | F1.0 | 9 |
| 95 | PRETEEN | HOUSEHOLD MEMBERS 6 THRU 12 YRS OLD | F1.0 | 9 |
| 96 | TEENS | HOUSEHOLD MEMBERS 13 THRU 17 YRS OLD | F1.0 | 9 |
| 97 | ADULTS | HOUSEHOLD MEMBERS 18 YRS AND OLDER | F1.0 | 9 |
| 98 | UNRELAT | NUMBER IN HOUSEHOLD NOT RELATED | F2.0 | -1, 9 |
| 99 | EARNRS | HOW MANY IN FAMILY EARNED MONEY | F1.0 | 9 |
| 100 | INCOME | TOTAL FAMILY INCOME | F2.0 | 0, 98, 99 |
| 101 | RINCOME | RESPONDENTS INCOME | F2.0 | 0, 98, 99 |
| 102 | INCOME91 | TOTAL FAMILY INCOME | F2.0 | 0, 98, 99 |
| 103 | RINCOM91 | RESPONDENTS INCOME | F2.0 | 0, 98, 99 |
| 104 | REGION | REGION OF INTERVIEW | F1.0 | 0 |
| 105 | XNORCSIZ | EXPANDED N.O.R.C. SIZE CODE | F2.0 | none |
| 106 | SRCBELT | SRC BELTCODE | F1.0 | none |
| 107 | SIZE | SIZE OF PLACE IN 1000S | F4.0 | 0 |
| 108 | PARTYID | POLITICAL PARTY AFFILIATION | F1.0 | 8, 9 |
| 109 | VOTE88 | DID R VOTE IN 1988 ELECTION | F1.0 | 0, 8, 9 |
| 110 | PRES88 | VOTE FOR DUKAKIS OR BUSH | F1.0 | 0, 8, 9 |
| 111 | IF88WHO | WHO WOULD R HAVE VOTED FOR-1988 ELECTION | F1.0 | 0, 8, 9 |
| 112 | POLVIEWS | THINK OF SELF AS LIBERAL OR CONSERVATIVE | F1.0 | 0, 8, 9 |
| 113 | NATSPAC | SPACE EXPLORATION PROGRAM | F1.0 | 0, 8, 9 |
| 114 | NATENVIR | IMPROVING & PROTECTING ENVIRONMENT | F1.0 | 0, 8, 9 |
| 115 | NATHEAL | IMPROVING & PROTECTING NATIONS HEALTH | F1.0 | 0, 8, 9 |
| 116 | NATCITY | SOLVING PROBLEMS OF BIG CITIES | F1.0 | 0, 8, 9 |
| 117 | NATCRIME | HALTING RISING CRIME RATE | F1.0 | 0, 8, 9 |
| 118 | NATDRUG | DEALING WITH DRUG ADDICTION | F1.0 | 0, 8, 9 |
| 119 | NATEDUC | IMPROVING NATIONS EDUCATION SYSTEM | F1.0 | 0, 8, 9 |
| 120 | NATRACE | IMPROVING THE CONDITIONS OF BLACKS | F1.0 | 0, 8, 9 |
| 121 | NATARMS | MILITARY, ARMAMENTS, AND DEFENSE | F1.0 | 0, 8, 9 |
| 122 | NATAID | FOREIGN AID | F1.0 | 0, 8, 9 |
| 123 | NATFARE | WELFARE | F1.0 | 0, 8, 9 |
| 124 | NATROAD | HIGHWAYS AND BRIDGES | F1.0 | 0, 8, 9 |
| 125 | NATSOC | SOCIAL SECURITY | F1.0 | 0, 8, 9 |
| 126 | NATMASS | MASS TRANSPORTATION | F1.0 | 0, 8, 9 |
| 127 | NATPARK | PARKS AND RECREATION | F1.0 | 0, 8, 9 |
| 128 | NATSPACY | SPACE EXPLORATION -- VERSION Y | F1.0 | 0, 8, 9 |
| 129 | NATENVIY | THE ENVIRONMENT -- VERSION Y | F1.0 | 0, 8, 9 |
| 130 | NATHEALY | HEALTH -- VERSION Y | F1.0 | 0, 8, 9 |
| 131 | NATCITYY | ASSISTANCE TO BIG CITIES -- VERSION Y | F1.0 | 0, 8, 9 |
| 132 | NATCRIMY | LAW ENFORCEMENT -- VERISON Y | F1.0 | 0, 8, 9 |
| 133 | NATDRUGY | DRUG REHABILITATION -- VERSION Y | F1.0 | 0, 8, 9 |
| 134 | NATEDUCY | EDUCATION -- VERSION Y | F1.0 | 0, 8, 9 |
| 135 | NATRACEY | ASSISTANCE TO BLACKS -- VERSION Y | F1.0 | 0, 8, 9 |
| 136 | NATARMSY | NATIONAL DEFENSE -- VERSION Y | F1.0 | 0, 8, 9 |
| 137 | NATAIDY | ASSISTANCE TO OTHER COUNTRIES -- VER Y | F1.0 | 0, 8, 9 |
| 138 | NATFAREY | ASSISTANCE TO THE POOR -- VERSION Y | F1.0 | 0, 8, 9 |
| 139 | EQWLTH | SHOULD GOVT REDUCE INCOME DIFFERENCES | F1.0 | 0, 8, 9 |
| 140 | TAX | RS FEDERAL INCOME TAX | F1.0 | 0, 8, 9 |
| 141 | SPKATH | ALLOW ANTI-RELIGIONIST TO SPEAK | F1.0 | 0, 8, 9 |
| 142 | COLATH | ALLOW ANTI-RELIGIONIST TO TEACH | F1.0 | 0, 8, 9 |
| 143 | LIBATH | ALLOW ANTI-RELIGIOUS BOOK IN LIBRARY | F1.0 | 0, 8, 9 |
| 144 | SPKRAC | ALLOW RACIST TO SPEAK | F1.0 | 0, 8, 9 |
| 145 | COLRAC | ALLOW RACIST TO TEACH | F1.0 | 0, 8, 9 |
| 146 | LIBRAC | ALLOW RACISTS BOOK IN LIBRARY | F1.0 | 0, 8, 9 |
| 147 | SPKCOM | ALLOW COMMUNIST TO SPEAK | F1.0 | 0, 8, 9 |
| 148 | COLCOM | SHOULD COMMUNIST TEACHER BE FIRED | F1.0 | 0, 8, 9 |
| 149 | LIBCOM | ALLOW COMMUNISTS BOOK IN LIBRARY | F1.0 | 0, 8, 9 |
| 150 | SPKMIL | ALLOW MILITARIST TO SPEAK | F1.0 | 0, 8, 9 |
| 151 | COLMIL | ALLOW MILITARIST TO TEACH | F1.0 | 0, 8, 9 |
| 152 | LIBMIL | ALLOW MILITARISTS BOOK IN LIBRARY | F1.0 | 0, 8, 9 |
| 153 | SPKHOMO | ALLOW HOMOSEXUAL TO SPEAK | F1.0 | 0, 8, 9 |
| 154 | COLHOMO | ALLOW HOMOSEXUAL TO TEACH | F1.0 | 0, 8, 9 |
| 155 | LIBHOMO | ALLOW HOMOSEXUALS BOOK IN LIBRARY | F1.0 | 0, 8, 9 |
| 156 | CAPPUN | FAVOR OR OPPOSE DEATH PENALTY FOR MURDER | F1.0 | 0, 8, 9 |
| 157 | GUNLAW | FAVOR OR OPPOSE GUN PERMITS | F1.0 | 0, 8, 9 |
| 158 | COURTS | COURTS DEALING WITH CRIMINALS | F1.0 | 0, 8, 9 |
| 159 | WIRTAP | WIRETAPPING | F1.0 | 0, 8, 9 |
| 160 | GRASS | SHOULD MARIJUANA BE MADE LEGAL | F1.0 | 0, 8, 9 |
| 161 | USWARY | EXPECT U.S. IN WORLD WAR IN 10 YEARS | F1.0 | 0, 8, 9 |
| 162 | USINTL | TAKE ACTIVE PART IN WORLD AFFAIRS | F1.0 | 0, 8, 9 |
| 163 | USUN | REMAIN IN U.N. OR PULL OUT | F1.0 | 0, 8, 9 |
| 164 | COMMUN | FEELINGS ABOUT COMMUNISM | F1.0 | 0, 8, 9 |
| 165 | RUSSIA | LIKING FOR RUSSIA | F2.0 | -1 |
| 166 | JAPAN | LIKING FOR JAPAN | F2.0 | -1 |
| 167 | CANADA | LIKING FOR CANADA | F2.0 | -1 |
| 168 | CHINA | LIKING FOR CHINA | F2.0 | -1 |
| 169 | ISRAEL | LIKING FOR ISRAEL | F2.0 | -1 |
| 170 | EGYPT | LIKING FOR EGYPT | F2.0 | -1 |
| 171 | RELIG | RS RELIGIOUS PREFERENCE | F1.0 | 8, 9 |
| 172 | DENOM | SPECIFIC DENOMINATION | F2.0 | 0, 98, 99 |
| 173 | OTHER | OTHER PROTESTANT DENOMINATIONS | F3.0 | 0, 998, 999 |
| 174 | JEW | WHAT SORT OF JEW R IS | F1.0 | 0, 8, 9 |
| 175 | FUND | HOW FUNDAMENTALIST IS R CURRENTLY | F1.0 | 0, 8, 9 |
| 176 | ATTEND | HOW OFTEN R ATTENDS RELIGIOUS SERVICES | F1.0 | 9 |
| 177 | RELITEN | STRENGTH OF AFFILIATION | F1.0 | 0, 8, 9 |
| 178 | POSTLIFE | BELIEF IN LIFE AFTER DEATH | F1.0 | 0, 8, 9 |
| 179 | RELIG16 | RELIGION IN WHICH RAISED | F1.0 | 0, 8, 9 |
| 180 | DENOM16 | DENOMINATION IN WHICH R WAS RAISED | F2.0 | 0, 98, 99 |
| 181 | OTH16 | OTHER PROTESTANT DENOMINATIONS | F3.0 | 0, 998, 999 |
| 182 | JEW16 | WHAT SORT OF JEW R WAS AT AGE 16 | F1.0 | 0, 8, 9 |
| 183 | FUND16 | HOW FUNDAMENTALIST WAS R AT AGE 16 | F1.0 | 0, 8, 9 |
| 184 | SPREL | SPOUSES RELIGIOUS PREFERENCE | F1.0 | 0, 8, 9 |
| 185 | SPDEN | SPECIFIC DENOMINATION, SPOUSE | F2.0 | 0, 98, 99 |
| 186 | SPOTHER | OTHER PROTESTANT DENOMINATIONS | F3.0 | 0, 998, 999 |
| 187 | SPJEW | WHAT SORT OF JEW IS RS SPOUSE CURRENTLY | F1.0 | 0, 8, 9 |
| 188 | SPFUND | HOW FUNDAMENTALIST IS SPOUSE CURRENTLY | F1.0 | 0, 8, 9 |
| 189 | SPREL16 | RELIGION IN WHICH SPOUSE RAISED | F1.0 | 0, 8, 9 |
| 190 | SPDEN16 | DENOMINATION IN WHICH SPOUSE RAISED | F2.0 | 0, 98, 99 |
| 191 | SPOTH16 | OTHER PROTESTANT DENOMINATIONS | F3.0 | 0, 998, 999 |
| 192 | SPJEW16 | WHAT SORT OF JEW WAS RS SPOUSE AT 16 | F1.0 | 0, 8, 9 |
| 193 | SPFUND16 | HOW FUNDAMENTALIST WAS SPOUSE AT 16 | F1.0 | 0, 8, 9 |
| 194 | PRAYER | BIBLE PRAYER IN PUBLIC SCHOOLS | F1.0 | 0, 8, 9 |
| 195 | BIBLE | FEELINGS ABOUT THE BIBLE | F1.0 | 0, 8, 9 |
| 196 | RACMAR | FAVOR LAW AGAINST RACIAL INTERMARRIAGE | F1.0 | 0, 8, 9 |
| 197 | RACSEG | WHITES HAVE RIGHT TO SEG. NEIGHBORHOOD | F1.0 | 0, 8, 9 |
| 198 | RACOPEN | VOTE ON OPEN HOUSING LAW | F1.0 | 0, 8, 9 |
| 199 | RACLIVE | ANY OPP. RACE IN NEIGHBORHOOD | F1.0 | 0, 8, 9 |
| 200 | RACCLOS | ANY OPP. RACE LIVING CLOSE TO R | F1.0 | 0, 8, 9 |
| 201 | RACDIS | HOW FAR ARE CLOSEST OPP. RACE | F1.0 | 0, 8, 9 |
| 202 | RACINTEG | WILL NEIGHBORHOOD BECOME ALL BLACK | F1.0 | 0, 8, 9 |
| 203 | RACHOME | OPP. RACE HOME FOR DINNER RECENTLY | F1.0 | 0, 8, 9 |
| 204 | RACFEW | CHILDREN TO SCHOOL WITH OPPOSITE RACE | F1.0 | 0, 8, 9 |
| 205 | RACHAF | CHILDREN TO SCHOOL HALF OPPOSITE RACE | F1.0 | 0, 8, 9 |
| 206 | RACMOST | CHILDREN TO SCHOOL MOSTLY OPPOSITE RACE | F1.0 | 0, 8, 9 |
| 207 | BUSING | ATTITUDE TOWARD RACIAL BUSING | F1.0 | 0, 8, 9 |
| 208 | RACPRES | WOULD VOTE FOR BLACK PRESIDENT | F1.0 | 0, 8, 9 |
| 209 | RACCHURH | ATTEND CHURCH WITH OTHER RACE | F1.0 | 0, 3 thru HI |
| 210 | HAPPY | GENERAL HAPPINESS | F1.0 | 0, 8, 9 |
| 211 | HAPMAR | HAPPINESS OF MARRIAGE | F1.0 | 0, 8, 9 |
| 212 | HEALTH | CONDITION OF HEALTH | F1.0 | 0, 8, 9 |
| 213 | LIFE | IS LIFE EXCITING OR DULL | F1.0 | 0, 8, 9 |
| 214 | HELPFUL | PEOPLE HELPFUL OR LOOKING OUT FOR SELVES | F1.0 | 0, 8, 9 |
| 215 | FAIR | PEOPLE FAIR OR TRY TO TAKE ADVANTAGE | F1.0 | 0, 8, 9 |
| 216 | TRUST | CAN PEOPLE BE TRUSTED | F1.0 | 0, 8, 9 |
| 217 | SATCITY | CITY OR PLACE R LIVES IN | F1.0 | 0, 8, 9 |
| 218 | SATHOBBY | NON-WORKING ACTIVITIES,HOBBIES | F1.0 | 0, 8, 9 |
| 219 | SATFAM | FAMILY LIFE | F1.0 | 0, 8, 9 |
| 220 | SATFRND | FRIENDSHIPS | F1.0 | 0, 8, 9 |
| 221 | SATHEALT | HEALTH AND PHYSICAL CONDITION | F1.0 | 0, 8, 9 |
| 222 | CONFINAN | CONFID IN BANKS & FINANCIAL INSTITUTIONS | F1.0 | 0, 8, 9 |
| 223 | CONBUS | CONFIDENCE IN MAJOR COMPANIES | F1.0 | 0, 8, 9 |
| 224 | CONCLERG | CONFIDENCE IN ORGANIZED RELIGION | F1.0 | 0, 8, 9 |
| 225 | CONEDUC | CONFIDENCE IN EDUCATION | F1.0 | 0, 8, 9 |
| 226 | CONFED | CONFID. IN EXEC BRANCH OF FED GOVT | F1.0 | 0, 8, 9 |
| 227 | CONLABOR | CONFIDENCE IN ORGANIZED LABOR | F1.0 | 0, 8, 9 |
| 228 | CONPRESS | CONFIDENCE IN PRESS | F1.0 | 0, 8, 9 |
| 229 | CONMEDIC | CONFIDENCE IN MEDICINE | F1.0 | 0, 8, 9 |
| 230 | CONTV | CONFIDENCE IN TELEVISION | F1.0 | 0, 8, 9 |
| 231 | CONJUDGE | CONFID. IN UNITED STATES SUPREME COURT | F1.0 | 0, 8, 9 |
| 232 | CONSCI | CONFIDENCE IN SCIENTIFIC COMMUNITY | F1.0 | 0, 8, 9 |
| 233 | CONLEGIS | CONFIDENCE IN CONGRESS | F1.0 | 0, 8, 9 |
| 234 | CONARMY | CONFIDENCE IN MILITARY | F1.0 | 0, 8, 9 |
| 235 | OBEY | TO OBEY | F1.0 | 0, 8, 9 |
| 236 | POPULAR | TO BE WELL LIKED OR POPULAR | F1.0 | 0, 8, 9 |
| 237 | THNKSELF | TO THINK FOR ONES SELF | F1.0 | 0, 8, 9 |
| 238 | WORKHARD | TO WORK HARD | F1.0 | 0, 8, 9 |
| 239 | HELPOTH | TO HELP OTHERS | F1.0 | 0, 8, 9 |
| 240 | SOCREL | SPEND EVENING WITH RELATIVES | F2.0 | -1, 8, 9 |
| 241 | SOCOMMUN | SPEND EVENING WITH NEIGHBOR | F2.0 | -1, 8, 9 |
| 242 | SOCFREND | SPEND EVENING WITH FRIENDS | F2.0 | -1, 8, 9 |
| 243 | SOCBAR | SPEND EVENING AT BAR | F2.0 | -1, 8, 9 |
| 244 | SOCPARS | SPEND EVENING WITH PARENTS | F2.0 | -1, 8, 9 |
| 245 | SOCSIBS | SPEND EVENING WITH SIBLINGS | F2.0 | -1, 8, 9 |
| 246 | AGED | SHOULD AGED LIVE WITH THEIR CHILDREN | F1.0 | 0, 8, 9 |
| 247 | DRINK | EVER DRINK ALCOHOLIC BEVERAGES? | F1.0 | 0, 8, 9 |
| 248 | DRUNK | EVER DRINK TOO MUCH? | F1.0 | 0, 8, 9 |
| 249 | SMOKE | DOES R SMOKE | F1.0 | 0, 8, 9 |
| 250 | QUITSMK | EVER TRIED TO QUIT SMOKING | F1.0 | 0, 8, 9 |
| 251 | EVSMOKE | HAS R EVER SMOKED | F1.0 | 0, 8, 9 |
| 252 | ANOMIA5 | LOT OF THE AVERAGE MAN GETTING WORSE | F1.0 | 0, 8, 9 |
| 253 | ANOMIA6 | NOT FAIR TO BRING CHILD INTO WORLD | F1.0 | 0, 8, 9 |
| 254 | ANOMIA7 | OFFICIALS NOT INTERESTED IN AVERAGE MAN | F1.0 | 0, 8, 9 |
| 255 | JOBLOSE | IS R LIKELY TO LOSE JOB | F1.0 | 0, 8, 9 |
| 256 | JOBFIND | COULD R FIND EQUALLY GOOD JOB | F1.0 | 0, 8, 9 |
| 257 | SATJOB | JOB OR HOUSEWORK | F1.0 | 0, 8, 9 |
| 258 | RICHWORK | IF RICH, CONTINUE OR STOP WORKING | F1.0 | 0, 8, 9 |
| 259 | JOBINC | HIGH INCOME | F1.0 | 0, 8, 9 |
| 260 | JOBSEC | NO DANGER OF BEING FIRED | F1.0 | 0, 8, 9 |
| 261 | JOBHOUR | SHORT WORKING HOURS | F1.0 | 0, 8, 9 |
| 262 | JOBPROMO | CHANCES FOR ADVANCEMENT | F1.0 | 0, 8, 9 |
| 263 | JOBMEANS | WORK IMPORTANT AND FEEL ACCOMPLISHMENT | F1.0 | 0, 8, 9 |
| 264 | CLASS | SUBJECTIVE CLASS IDENTIFICATION | F1.0 | 0, 8, 9 |
| 265 | SATFIN | SATISFACTION WITH FINANCIAL SITUATION | F1.0 | 8, 9 |
| 266 | FINALTER | CHANGE IN FINANCIAL SITUATION | F1.0 | 8, 9 |
| 267 | FINRELA | OPINION OF FAMILY INCOME | F1.0 | 8, 9 |
| 268 | WKSUB | DOES R OR SPOUSE HAVE SUPERVISOR | F1.0 | 0, 8, 9 |
| 269 | WKSUBS | DOES SUPERVISOR HAVE SUPERVISOR | F1.0 | 0, 8, 9 |
| 270 | WKSUP | DOES R OR SPOUSE SUPERVISE ANYONE | F1.0 | 0, 8, 9 |
| 271 | WKSUPS | DOES SUBORDINATE SUPERVISE ANYONE | F1.0 | 0, 8, 9 |
| 272 | UNEMP | EVER UNEMPLOYED IN LAST TEN YRS | F1.0 | 0, 8, 9 |
| 273 | UNION | DOES R OR SPOUSE BELONG TO UNION | F1.0 | 0, 8, 9 |
| 274 | GETAHEAD | OPINION OF HOW PEOPLE GET AHEAD | F1.0 | 0, 8, 9 |
| 275 | FEHOME | WOMEN TAKE CARE OF HOME NOT COUNTRY | F1.0 | 0, 8, 9 |
| 276 | FEWORK | SHOULD WOMEN WORK | F1.0 | 0, 8, 9 |
| 277 | FEPRES | VOTE FOR WOMAN PRESIDENT | F1.0 | 0, 8, 9 |
| 278 | FEPOL | WOMEN NOT SUITED FOR POLITICS | F1.0 | 0, 8, 9 |
| 279 | ABDEFECT | STRONG CHANCE OF SERIOUS DEFECT | F1.0 | 0, 8, 9 |
| 280 | ABNOMORE | MARRIED--WANTS NO MORE CHILDREN | F1.0 | 0, 8, 9 |
| 281 | ABHLTH | WOMANS HEALTH SERIOUSLY ENDANGERED | F1.0 | 0, 8, 9 |
| 282 | ABPOOR | LOW INCOME--CANT AFFORD MORE CHILDREN | F1.0 | 0, 8, 9 |
| 283 | ABRAPE | PREGNANT AS RESULT OF RAPE | F1.0 | 0, 8, 9 |
| 284 | ABSINGLE | NOT MARRIED | F1.0 | 0, 8, 9 |
| 285 | ABANY | ABORTION IF WOMAN WANTS FOR ANY REASON | F1.0 | 0, 8, 9 |
| 286 | CHLDIDEL | IDEAL NUMBER OF CHILDREN | F2.0 | -1, 9 |
| 287 | CHLDMORE | EXPECT MORE CHILDREN | F1.0 | 0, 8, 9 |
| 288 | CHLDNUM | HOW MANY CHILDREN EXPECTED | F1.0 | 0, 9 |
| 289 | PILLOK | BIRTH CONTROL TO TEENAGERS 14-16 | F1.0 | 0, 8, 9 |
| 290 | SEXEDUC | SEX EDUCATION IN PUBLIC SCHOOLS | F1.0 | 0, 8, 9 |
| 291 | DIVLAW | DIVORCE LAWS | F1.0 | 0, 8, 9 |
| 292 | PREMARSX | SEX BEFORE MARRIAGE | F1.0 | 0, 8, 9 |
| 293 | TEENSEX | SEX BEFORE MARRIAGE -- TEENS 14-16 | F1.0 | 0, 8, 9 |
| 294 | XMARSEX | SEX WITH PERSON OTHER THAN SPOUSE | F1.0 | 0, 8, 9 |
| 295 | HOMOSEX | HOMOSEXUAL SEX RELATIONS | F1.0 | 0, 8, 9 |
| 296 | PORNINF | MATERIALS PROVIDE INFO ABOUT SEX | F1.0 | 0, 8, 9 |
| 297 | PORNMORL | MATERIALS LEAD TO BREAKDOWN IN MORALS | F1.0 | 0, 8, 9 |
| 298 | PORNRAPE | MATERIALS LEAD TO RAPE | F1.0 | 0, 8, 9 |
| 299 | PORNOUT | MATERIALS PROVIDE OUTLET | F1.0 | 0, 8, 9 |
| 300 | PORNLAW | FEELINGS ABOUT PORNOGRAPHY LAWS | F1.0 | 0, 8, 9 |
| 301 | XMOVIE | SEEN X-RATED MOVIE IN LAST YEAR | F1.0 | 0, 8, 9 |
| 302 | SPANKING | FAVOR SPANKING TO DISCIPLINE CHILD | F1.0 | 0, 8, 9 |
| 303 | LETDIE1 | ALLOW INCURABLE PATIENTS TO DIE | F1.0 | 0, 8, 9 |
| 304 | SUICIDE1 | SUICIDE IF INCURABLE DISEASE | F1.0 | 0, 8, 9 |
| 305 | SUICIDE2 | SUICIDE IF BANKRUPT | F1.0 | 0, 8, 9 |
| 306 | SUICIDE3 | SUICIDE IF DISHONORED FAMILY | F1.0 | 0, 8, 9 |
| 307 | SUICIDE4 | SUICIDE IF TIRED OF LIVING | F1.0 | 0, 8, 9 |
| 308 | HIT | EVER PUNCHED OR BEATEN BY ANOTHER PERSON | F1.0 | 0, 8, 9 |
| 309 | HITAGE | BEATEN AS CHILD OR ADULT | F1.0 | 0, 8, 9 |
| 310 | GUN | EVER THREATENED WITH GUN OR SHOT AT | F1.0 | 0, 8, 9 |
| 311 | GUNAGE | THREATENED OR SHOT AT AS CHILD OR ADULT | F1.0 | 0, 8, 9 |
| 312 | HITOK | EVER APPROVE OF MAN PUNCHING ADULT MALE | F1.0 | 0, 8, 9 |
| 313 | HITMARCH | STRANGER IN PROTEST MARCH | F1.0 | 0, 8, 9 |
| 314 | HITDRUNK | DRUNK BUMPED INTO MAN & WIFE | F1.0 | 0, 8, 9 |
| 315 | HITCHILD | STRANGER HAD HIT MANS CHILD | F1.0 | 0, 8, 9 |
| 316 | HITBEATR | STRANGER WAS BEATING UP A WOMAN | F1.0 | 0, 8, 9 |
| 317 | HITROBBR | STRANGER HAD BROKEN INTO MANS HOUSE | F1.0 | 0, 8, 9 |
| 318 | POLHITOK | EVER APPROVE OF POLICE STRIKING CITIZEN | F1.0 | 0, 8, 9 |
| 319 | POLABUSE | CITIZEN SAID VULGAR OR OBSCENE THINGS | F1.0 | 0, 8, 9 |
| 320 | POLMURDR | CITIZEN QUESTIONED AS MURDER SUSPECT | F1.0 | 0, 8, 9 |
| 321 | POLESCAP | CITIZEN ATTEMPTING TO ESCAPE CUSTODY | F1.0 | 0, 8, 9 |
| 322 | POLATTAK | CITIZEN ATTACKING POLICEMAN WITH FISTS | F1.0 | 0, 8, 9 |
| 323 | FEAR | AFRAID TO WALK AT NIGHT IN NEIGHBORHOOD | F1.0 | 0, 8, 9 |
| 324 | BURGLR | HOME BROKEN INTO DURING THE LAST YEAR | F1.0 | 0, 8, 9 |
| 325 | ROBBRY | FORCEFULLY ROBBED DURING THE LAST YEAR | F1.0 | 0, 8, 9 |
| 326 | OWNGUN | HAVE GUN IN HOME | F1.0 | 0, 8, 9 |
| 327 | PISTOL | PISTOL OR REVOLVER IN HOME | F1.0 | 0, 8, 9 |
| 328 | SHOTGUN | SHOTGUN IN HOME | F1.0 | 0, 8, 9 |
| 329 | RIFLE | RIFLE IN HOME | F1.0 | 0, 8, 9 |
| 330 | ROWNGUN | DOES GUN BELONG TO R | F1.0 | 0, 8, 9 |
| 331 | HUNT | DOES R OR SPOUSE HUNT | F1.0 | 0, 8, 9 |
| 332 | NEWS | HOW OFTEN DOES R READ NEWSPAPER | F1.0 | 0, 8, 9 |
| 333 | TVHOURS | HOURS PER DAY WATCHING TV | F2.0 | -1, 98, 99 |
| 334 | PHONE | DOES R HAVE TELEPHONE | F1.0 | 0, 9 |
| 335 | COOP | RS ATTITUDE TOWARD INTERVIEW | F1.0 | 0, 9 |
| 336 | COMPREND | RS UNDERSTANDING OF QUESTIONS | F1.0 | 0, 9 |
| 337 | FORM | FORM OF SPLIT QUESTIONNAIRE ASKED | F1.0 | 0 |
| 338 | FECHLD | MOTHER WORKING DOESNT HURT CHILDREN | F1.0 | 0, 8, 9 |
| 339 | FEHELP | WIFE SHOULD HELP HUSBANDS CAREER FIRST | F1.0 | 0, 8, 9 |
| 340 | FEPRESCH | PRESCHOOL KIDS SUFFER IF MOTHER WORKS | F1.0 | 0, 8, 9 |
| 341 | FEFAM | BETTER FOR MAN TO WORK, WOMAN TEND HOME | F1.0 | 0, 8, 9 |
| 342 | RACCHNG | TRY TO INTEGRATE SOCIAL CLUB | F1.0 | 0, 8, 9 |
| 343 | RACDIF1 | DIFFERENCES DUE TO DISCRIMINATION | F1.0 | 0, 8, 9 |
| 344 | RACDIF2 | DIFFERENCES DUE TO INBORN DISABILITY | F1.0 | 0, 8, 9 |
| 345 | RACDIF3 | DIFFERENCES DUE TO LACK OF EDUCATION | F1.0 | 0, 8, 9 |
| 346 | RACDIF4 | DIFFERENCES DUE TO LACK OF WILL | F1.0 | 0, 8, 9 |
| 347 | DIVORCE5 | DIVORCED IN LAST 5 YRS | F2.0 | -1, 9 |
| 348 | UNEMP5 | UNEMPLOYED IN LAST 5 YRS | F2.0 | -1, 9 |
| 349 | HOSDIS5 | HOSPITALIZED, DISABLED LAST 5 YRS | F2.0 | -1, 9 |
| 350 | DEATH5 | RELATIVES DIED IN LAST 5 YRS | F2.0 | -1, 9 |
| 351 | DEATH16 | RELATIVES DIED SINCE AGE 16 | F2.0 | -1 |
| 352 | PADEATH | DEATH OF FATHER | F2.0 | -1, 8, 9 |
| 353 | MADEATH | DEATH OF MOTHER | F2.0 | -1, 8, 9 |
| 354 | CHLDDTH | DEATH OF CHILD | F2.0 | -1, 9 |
| 355 | SIBDEATH | DEATH OF SIBLING | F2.0 | -1, 9 |
| 356 | SPDEATH | DEATH OF SPOUSE | F2.0 | -1, 9 |
| 357 | TRAUMA1 | TRAUMA SCALE, LAST YEAR | F2.0 | -1, 9 |
| 358 | TRAUMA5 | TRAUMA SCALE, LAST 5 YEARS | F2.0 | -1, 9 |
| 359 | HELPPOOR | SHOULD GOVT IMPROVE STANDARD OF LIVING? | F1.0 | 0, 8, 9 |
| 360 | HELPNOT | SHOULD GOVT DO MORE OR LESS? | F1.0 | 0, 8, 9 |
| 361 | HELPSICK | SHOULD GOVT HELP PAY FOR MEDICAL CARE? | F1.0 | 0, 8, 9 |
| 362 | HELPBLK | SHOULD GOVT AID BLACKS? | F1.0 | 0, 8, 9 |
| 363 | MEMFRAT | MEMBERSHIP IN FRATERNAL GROUP | F1.0 | 0, 8, 9 |
| 364 | MEMSERV | MEMBERSHIP IN SERVICE GROUP | F1.0 | 0, 8, 9 |
| 365 | MEMVET | MEMBERSHIP IN VETERAN GROUP | F1.0 | 0, 8, 9 |
| 366 | MEMPOLIT | MEMBERSHIP IN POLITICAL CLUB | F1.0 | 0, 8, 9 |
| 367 | MEMUNION | MEMBERSHIP IN LABOR UNION | F1.0 | 0, 8, 9 |
| 368 | MEMSPORT | MEMBERSHIP IN SPORTS CLUB | F1.0 | 0, 8, 9 |
| 369 | MEMYOUTH | MEMBERSHIP IN YOUTH GROUP | F1.0 | 0, 8, 9 |
| 370 | MEMSCHL | MEMBERSHIP IN SCHOOL SERVICE | F1.0 | 0, 8, 9 |
| 371 | MEMHOBBY | MEMBERSHIP IN HOBBY CLUB | F1.0 | 0, 8, 9 |
| 372 | MEMGREEK | MEMBERSHIP IN SCHOOL FRATERNITY | F1.0 | 0, 8, 9 |
| 373 | MEMNAT | MEMBERSHIP IN NATIONALITY GROUP | F1.0 | 0, 8, 9 |
| 374 | MEMFARM | MEMBERSHIP IN FARM ORGANIZATION | F1.0 | 0, 8, 9 |
| 375 | MEMLIT | MEMBERSHIP IN LITERARY OR ART GROUP | F1.0 | 0, 8, 9 |
| 376 | MEMPROF | MEMBERSHIP IN PROFESSIONAL SOCIETY | F1.0 | 0, 8, 9 |
| 377 | MEMCHURH | MEMBERSHIP IN CHURCH GROUP | F1.0 | 0, 8, 9 |
| 378 | MEMOTHER | MEMBERSHIP IN ANY OTHER | F1.0 | 0, 8, 9 |
| 379 | MEMNUM | NUMBER OF MEMBERSHIPS | F2.0 | -1, 98, 99 |
| 380 | GENEJOB | SHOULD EMPLOYERS GIVE GENETIC TESTS | F1.0 | 0, 8, 9 |
| 381 | GENEHIRE | EMPLOYERS' RIGHT TO HIRE BY GENETIC TESTS | F1.0 | 0, 8, 9 |
| 382 | GENECANX | EMPLOYER TEST CANCER OR SAFE  WORKPLACE | F1.0 | 0, 8, 9 |
| 383 | GENECANY | EMPLOYERS' RIGHT TO HIRE BY CANCER  TESTS | F1.0 | 0, 8, 9 |
| 384 | GENEGETS | EMPLOYER VS. EMPLOYEE ON ACCESS RIGHT TO TEST RESULT | F1.0 | 0, 8, 9 |
| 385 | PROFITS1 | WHETHER MANAGEMENT ONLY CARE ABOUT PROFIT | F1.0 | 0, 8, 9 |
| 386 | PROFITS2 | SHOULD CO. PAY WORKERS MORE THAN SHAREHOLDERS | F1.0 | 0, 8, 9 |
| 387 | UNPOWER | UNIONS IN THIS COUNTRY HAVE TOO LITTLE POWER | F1.0 | 0, 8, 9 |
| 388 | UNPROG | UNIONS JUST BLOCK ECONOMIC PROGRESS | F1.0 | 0, 8, 9 |
| 389 | OUTOFBIZ | THE ORGANIZATION WENT OUT OF BUSINESS | F1.0 | 0, 8, 9 |
| 390 | MERGED | THE ORG. WAS MERGED, TAKEN OVER | F1.0 | 0, 8, 9 |
| 391 | REORG | THERE WAS A MAJOR REORGANIZATION | F1.0 | 0, 8, 9 |
| 392 | ORGFIN | R'S FINANCIAL SITUATION AFTER ORG. CHANGES | F1.0 | 0, 8, 9 |
| 393 | WRKYEARS | # YEARS YOU HAVE WORKED FOR PAY SINCE WERE 16 | F2.0 | -1, 98, 99 |
| 394 | EVUNEMP | EVER BEEN UNEMPLOYED TWO WEEKS + | F1.0 | 0, 8, 9 |
| 395 | NUMUNEMP | HOW MANY TIMES UNEMPLOYED MORE THAN TWO WEEKS | F2.0 | 0, 98, 99 |
| 396 | TOTUNEMP | TOTAL TIMES UNEMPLOYED | F1.0 | 0, 8, 9 |
| 397 | EMPYEARS | YEARS WORKED FOR YOUR PRESENT EMPLOYER | F5.2 | -1, 99.98, 99.99 |
| 398 | FNDJOB1 | HEARD JOB FROM ONE ALREADY WORKED THERE | F1.0 | 0, 9 |
| 399 | FNDJOB2 | HEARD JOB FROM RELATIVES | F1.0 | 0, 9 |
| 400 | FNDJOB3 | HEARD JOB FROM FRIENDS | F1.0 | 0, 9 |
| 401 | FNDJOB4 | HEARD JOB FROM ACQUAINTANCES | F1.0 | 0, 9 |
| 402 | FNDJOB5 | HEARD JOB FROM NEWSPAPER AD | F1.0 | 0, 9 |
| 403 | FNDJOB6 | HEARD JOB THROUGH EMPLOYMENT AGENCY | F1.0 | 0, 9 |
| 404 | FNDJOB7 | HEARD JOB FROM RECRUITER FOR THIS EMPLOYER | F1.0 | 0, 9 |
| 405 | FNDJOB8 | HEARD JOB JUST CAME HERE AND ASKED FOR WORK | F1.0 | 0, 9 |
| 406 | FNDJOB9 | HEARD JOB OTHER (SPECIFY) | F1.0 | 0, 9 |
| 407 | INTLTEST | BEFORE GOT THE JOB TOOK AN INTELLEGENCE TEST | F1.0 | 0, 8, 9 |
| 408 | SKILTEST | BEFORE GOT THE JOB TOOK A SKILL TEST | F1.0 | 0, 8, 9 |
| 409 | DRUGTEST | BEFORE GOT THE JOB TOOK A DRUG AND ALCOHOL TEST | F1.0 | 0, 8, 9 |
| 410 | PHYSICAL | BEFORE GOT THE JOB TOOK A PHYSICAL TEST | F1.0 | 0, 8, 9 |
| 411 | LTRSREF | SUPPLY LETTERS OF REFERENCE | F1.0 | 0, 8, 9 |
| 412 | SAMEJOB | CURRENT JOB SAME OR DIFFERENT FROM  FIRST JOB | F1.0 | 0, 8, 9 |
| 413 | JOBYEARS | FOR HOW LONG HAVE YOU HAD YOUR PRESENT JOB | F5.2 | -1, 99.98, 99.99 |
| 414 | THISJOB1 | HEARD JOB FROM A NOTICES POSTED MY WORKPLACE | F1.0 | 0, 9 |
| 415 | THISJOB2 | HEARD JOB THROUGH MY UNION | F1.0 | 0, 9 |
| 416 | THISJOB3 | HEARD JOB FROM MY SUPERVISOR | F1.0 | 0, 9 |
| 417 | THISJOB4 | HEARD JOB FROM ONE OF MY COWORKERS | F1.0 | 0, 9 |
| 418 | THISJOB5 | HEARD JOB I NEAR THE TOP OF A SENIORITY LIST | F1.0 | 0, 9 |
| 419 | THISJOB6 | HEARD JOB I WAS ASKED TO TAKE THE NEW JOB | F1.0 | 0, 9 |
| 420 | THISJOB7 | HEARD JOB OTHERS (SPECIFY) | F1.0 | 0, 9 |
| 421 | PROMOTNG | PROCEDURES FOR PROMOTION | F1.0 | 0, 8, 9 |
| 422 | PROMOTED |  | F1.0 | 0, 9 |
| 423 | NUMPROMO | # PROMOTIONS HAVE YOU RECEIVED | F1.0 | 0, 8, 9 |
| 424 | IMPPROMO | IMPORTANCE OF THE OPPORTUNITY TO BE PROMOTED | F1.0 | 0, 8, 9 |
| 425 | FUTPROMO | HOW LIKELY YOU WILL BE PROMOTED NEXT FIVE YEARS | F1.0 | 0, 8, 9 |
| 426 | SEXPROMO | SEX MAKES YOUR PROMOTION DIFFERENT | F1.0 | 0, 8, 9 |
| 427 | RACPROMO | ETHNIC BACKGROUND MAKES YOUR PROMOTION DIFFERNT | F1.0 | 0, 8, 9 |
| 428 | ADVANCES | HAVE YOU ADVANCED, SAME LEVEL OR LOST | F1.0 | 0, 8, 9 |
| 429 | JOBCNTRL | WHO MAKES DECISION FOR YOUR JOB | F1.0 | 0, 8, 9 |
| 430 | WRKINDEP | I CAN WORK INDEPENDENTLY | F1.0 | 0, 8, 9 |
| 431 | LOTTOSAY | I HAVE A LOT TO SAY ON MY JOB | F1.0 | 0, 8, 9 |
| 432 | IDECIDE | MY JOB ALLOWS ME MAKE PART DECISIONS | F1.0 | 0, 8, 9 |
| 433 | AUTOMATN | MY JOB IS CONTROLLED BY MY MACHINE | F1.0 | 0, 8, 9 |
| 434 | MONITRED | COMPUTERS MONITOR MY JOB PERFORMANCE | F1.0 | 0, 8, 9 |
| 435 | OFFSUP | DO YOU SUPERVISE THE WORK OF OTHER EMPLOYEES | F1.0 | 0, 8, 9 |
| 436 | YOUSUP | HOW MANY PEOPLE DO YOU SUPERVISE DIRECTLY | F3.0 | 0, 998, 999 |
| 437 | SUPOTHRS | ANY PEOPLE SUPERVISED BY YOU SUPERVISE OTHERS | F1.0 | 0, 9 |
| 438 | LEVELS | HOW MANY LEVELS OF SUPERVISION BENEATH YOU | F2.0 | 0, 98, 99 |
| 439 | TOTSUP | HOW MANY PEOPLE RESPONSIBLE TO YOU | F4.0 | 0, 9998, 9999 |
| 440 | SUPDUTY1 | YOU TRAIN EMPLOYEES SAFE USE EQUIPMENT | F1.0 | 0, 9 |
| 441 | SUPDUTY2 | YOU TRAIN EMPLOYEES IN OTHER WAYS | F1.0 | 0, 9 |
| 442 | SUPDUTY3 | YOU ORGANIZE SCHEDULES OR TASKS | F1.0 | 0, 8, 9 |
| 443 | SUPDUTY4 | YOU DEVISE NEW WAYS OF DOING TASKS | F1.0 | 0, 9 |
| 444 | SUPDUTY5 | YOU CHECK WORKERS' PROGRESS,ATTENDANCE | F1.0 | 0, 9 |
| 445 | SUPDUTY6 | YOU EVALUATE JOB PERFORMANCE | F1.0 | 0, 8, 9 |
| 446 | SUPDUTY7 | YOU TAKE PROMOTIONS OR DISCIPLINARY ACTIONS | F1.0 | 0, 9 |
| 447 | OTHDUTY1 | YOU TRAIN EMPLOYEES SAFE USE EQUIP. NOT SUPERVISE | F1.0 | 0, 9 |
| 448 | OTHDUTY2 | YOU TRAIN EMPLOYEES IN OTHER WAYS, NOT SUPERVISE | F1.0 | 0, 9 |
| 449 | OTHDUTY3 | YOU ORGANIZE SCHEDULES OR TASKS, NOT SUPERVISE | F1.0 | 0, 8, 9 |
| 450 | OTHDUTY4 | YOU DEVISE NEW WAYS OF DOING TASKS, NOT SUPERVISE | F1.0 | 0, 9 |
| 451 | OTHDUTY5 | YOU CHECK PROGRESS OR ATTENDANCE, NOT SUPERVISE | F1.0 | 0, 9 |
| 452 | OTHDUTY6 | YOU EVALUATE JOB PERFORMANCE, NOT SUPERVISE | F1.0 | 0, 8, 9 |
| 453 | OTHDUTY7 | YOU PROMOT OR DISCIPLINe ACTIONS, NOT SUPERVISE | F1.0 | 0, 8, 9 |
| 454 | ORGMONEY | PARTICIPATE IN DECISIONS ABOUT ORG'S MONEY | F1.0 | 0, 9 |
| 455 | TOTMONEY | HOW MUCH MONEY IN THE LARGEST OF THESE DECISIONS | F7.0 | 0, 9999998, 9999999 |
| 456 | YOUMONEY | LARGEST DECISION IN WHICH YOU HAD THE FINAL SAY | F7.0 | 0, 9999998, 9999999 |
| 457 | JOBJUDGE | SOMEONE EVALUATE YOUR PERFORMANCE REGULARLY | F1.0 | 0, 8, 9 |
| 458 | QUANTITY | HOW EASY YOUR SUPERVISOR KNOW HOW MUCH YOU DO | F1.0 | 0, 8, 9 |
| 459 | QUALITY | HOW EASY YOUR SUPERVISOR KNOW HOW GOOD YOU ARE | F1.0 | 0, 8, 9 |
| 460 | WRKWELL | HOW WELL YOU  COMPARE TO PEOPLE DO SAME JOB | F1.0 | 0, 8, 9 |
| 461 | WRKMUCH | HOW MUCH YOU COMPARE TO PEOPLE DO SAME JOB | F1.0 | 0, 8, 9 |
| 462 | IMATTER | SUCCESS OF MY ORG. DEPENDS LOT ON HOW WELL I DO | F1.0 | 0, 8, 9 |
| 463 | HELPORG | I WILLING WORK HARDER THAN I HAVE TO TO HELP ORG. | F1.0 | 0, 8, 9 |
| 464 | NOTLOYAL | I FEEL VERY LITTLE LOYALTY TO THIS ORG. | F1.0 | 0, 8, 9 |
| 465 | STAYORG1 | WOULD TAKE ANY JOB TO KEEP WORKING FOR THIS ORG. | F1.0 | 0, 8, 9 |
| 466 | SAMEVALS | MY VALUES AND THE ORG.'S VALUES ARE VERY SIMILAR | F1.0 | 0, 8, 9 |
| 467 | PROUDORG | PROUD TO BE WORKING FOR THIS ORG. | F1.0 | 0, 8, 9 |
| 468 | STAYORG | TURN DOWN ANOTHER JOB FOR PAY TO STAY THIS ORG. | F1.0 | 0, 8, 9 |
| 469 | NOTICED | PEOPLE USUALLY NOTICE WHEN I DO MY JOB WELL | F1.0 | 0, 8, 9 |
| 470 | CHNGEORG | HOW LIKELY I'LL TRY TO FIND JOB IN ANOTHER ORG. | F1.0 | 0, 8, 9 |
| 471 | OTHERPAY | GET COMMISSIONS, BONUSES, TIPS FROM MAIN JOB | F1.0 | 0, 9 |
| 472 | RAISEALL | ALL WORKERS REGARDLESS OF PERFORMANCE GOT RAISE | F1.0 | 0, 8, 9 |
| 473 | RAISEHRD | WORKERS WHO WORK HARD AND PERFORM WELL GOT RAISE | F1.0 | 0, 8, 9 |
| 474 | RAISEFAV | WORKERS HAVE FAVORED RELATION TO BOSS GOT RAISE | F1.0 | 0, 8, 9 |
| 475 | FRINGE1 | MEDICAL OR HOSPITAL INSURANCE | F1.0 | 0, 8, 9 |
| 476 | FRINGE2 | DENTAL CARE BENEFITS | F1.0 | 0, 8, 9 |
| 477 | FRINGE3 | LIFE INSURANCE | F1.0 | 0, 8, 9 |
| 478 | FRINGE4 | SICK LEAVE WITH FULL PAY | F1.0 | 0, 8, 9 |
| 479 | FRINGE5 | MATERNITY LEAVE WITH FULL RE-EMPLOYMENT RIGHTS | F1.0 | 0, 8, 9 |
| 480 | FRINGE6 | FLEXIBLE HOURS, OR FLEXTIME SCHEDULING | F1.0 | 0, 8, 9 |
| 481 | FRINGE7 | CASH OR STOCK BONUSES FOR PERFORMANCE OR MERIT | F1.0 | 0, 8, 9 |
| 482 | FRINGE8 | A PENSION OR RETIREMENT PROGRAM | F1.0 | 0, 8, 9 |
| 483 | FRINGE9 | PROFIT SHARING OR STOCK OPTION PROGRAM | F1.0 | 0, 8, 9 |
| 484 | FRINGE10 | INFORMATION ABOUT CHILD CARE SERVICES IN COMMUNITY | F1.0 | 0, 8, 9 |
| 485 | FRINGE11 | ASSISTANCE WITH THE COSTS OF DAY CARE FOR CHILDREN | F1.0 | 0, 8, 9 |
| 486 | JOBVSHME | HOW OFTEN YOUR FAMILY INTERFERED WITH YOUR JOB | F1.0 | 0, 9 |
| 487 | UNVOTE | WOULD YOU VOTE FOR OR AGAINST HAVING A UNION | F1.0 | 0, 8, 9 |
| 488 | UNMANREL | RELATIONS BETWEEN MANAGEMENT AND WORKERS | F1.0 | 0, 8, 9 |
| 489 | COWRKREL | RELATIONS BETWEEN COWORKERS | F1.0 | 0, 8, 9 |
| 490 | SCHOOLNG | IMPORTANCE FORMAL SCHOOL FOR YOU JOB | F1.0 | 0, 8, 9 |
| 491 | TRAINING | IMPORTANCE OF ON-THE-JOB TRAINING FOR YOU JOB | F1.0 | 0, 8, 9 |
| 492 | LEARNING | IMPORTANCE OF LEARNING FROM CO-WORKERS FOR YOU JOB | F1.0 | 0, 8, 9 |
| 493 | EXPTRAIN | IMPORTANCE OF DIFFERENT EMPLOYER TRAINING FOR JOB | F1.0 | 0, 8, 9 |
| 494 | WHEREWRK | DOING YOUR JOB IN ONE OR SEVERAL DIFFERENT PLACES | F1.0 | 0, 9 |
| 495 | FINDOUT | CAN FIND OUT WHERE YOU WILL BE WORKING | F1.0 | 0, 9 |
| 496 | BASEOFOP | YOU HAVE BASE OF OPERATIONS | F1.0 | 0, 9 |
| 497 | SPLOCNUM | # OF WORKERS AT THE LOCATION YOUR SPOUSE WORKS | F1.0 | 0, 8, 9 |
| 498 | LOCALNUM | NUMBER OF EMPLOYEES: RS WORK SITE | F1.0 | 0, 8, 9 |
| 499 | AIDSKNOW | #PEOPLE R KNOWS INFECTED WITH AIDS | F2.0 | -1, 98, 99 |
| 500 | AIDSWHO | RS RELATIONSHIP TO CLOSEST AIDS VICTIM | F2.0 | 0, 98, 99 |
| 501 | AIDSDEAD | HAS AIDS VICTIM CLOSEST TO R DIED | F1.0 | 0, 8, 9 |
| 502 | AIDSSEX | SEX OF AIDS VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 503 | AIDSAGE | AGE OF AIDS VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 504 | AIDSRACE | RACE OF AIDS VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 505 | AIDSREG | REGION OF AIDS VICTIM CLOSEST TO R | F2.0 | -1, 98, 99 |
| 506 | AIDSWHO2 | RS RELATION. TO 2ND CLOSEST AIDS VICTIM | F2.0 | 0, 98, 99 |
| 507 | AIDSDED2 | HAS AIDS VICTIM 2ND CLOSEST TO R DIED | F1.0 | 0, 8, 9 |
| 508 | AIDSSEX2 | SEX OF AIDS VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 509 | AIDSAGE2 | AGE OF AIDS VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 510 | AIDSRAC2 | RACE OF AIDS VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 511 | AIDSREG2 | REGION OF AIDS VICTIM 2ND CLOSEST TO R | F2.0 | -1, 98, 99 |
| 512 | AIDSWHO3 | RS RELAT. TO 3RD CLOSEST AIDS VICTIM TO R | F2.0 | 0, 98, 99 |
| 513 | AIDSDED3 | HAS AIDS VICTIM 3RD CLOSEST TO R DIED | F1.0 | 0, 8, 9 |
| 514 | AIDSSEX3 | SEX OF AIDS VICTIM 3RD CLOSEST TO R | F1.0 | 0, 8, 9 |
| 515 | AIDSAGE3 | AGE OF AIDS VICTIM 3RD CLOSEST TO R | F1.0 | 0, 8, 9 |
| 516 | AIDSRAC3 | RACE OF AIDS VICTIM 3RD CLOEST TO R | F1.0 | 0, 8, 9 |
| 517 | AIDSREG3 | REGION OF AIDS VICTIM 3RD CLOSEST TO R | F2.0 | -1, 98, 99 |
| 518 | SUIKNEW | #PEOPLE R KNOWS SUICIDE IN LAST YEAR | F2.0 | -1, 8, 9 |
| 519 | SUIWHO | RS RELATIONSHIP TO CLOSEST SUICIDE | F2.0 | 0, 98, 99 |
| 520 | SUISEX | SEX OF SUICIDE VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 521 | SUIAGE | AGE OF SUICIDE VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 522 | SUIRACE | RACE OF SUICIDE VICTIM CLOSEST TO R | F1.0 | 0, 8, 9 |
| 523 | SUIREG | REGION OF SUICIDE VICTIM CLOSEST TO R | F2.0 | -1, 98, 99 |
| 524 | SUIWHO2 | RS RELATIONSHIP TO 2ND CLOSEST SUICIDE | F2.0 | 0, 98, 99 |
| 525 | SUISEX2 | SEX OF SUICIDE VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 526 | SUIAGE2 | AGE OF SUICIDE VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 527 | SUIRAC2 | RACE OF SUICIDE VICTIM 2ND CLOSEST TO R | F1.0 | 0, 8, 9 |
| 528 | SUIREG2 | REGION OF SUICIDE VICTIM 2ND CLOSEST TO R | F2.0 | -1, 98, 99 |
| 529 | SUIWHO3 | RS RELATIONSHIP TO 3RD CLOSEST SUICIDE | F2.0 | 0, 98, 99 |
| 530 | SUISEX3 | SEX OF SUICIDE  VICTIM 3RD CLOSEST TO R | F1.0 | 0, 8, 9 |
| 531 | SUIAGE3 | AGE OF SUICIDE VICTIM 3RD CLOSEST TO R | F1.0 | 0, 8, 9 |
| 532 | SUIRAC3 | RACE OF SUICIDE VICTIM 3RD CLOSEST TO R | F1.0 | 0, 8, 9 |
| 533 | SUIREG3 | REGION OF SUICIDE VICTIM 3RD CLOSEST TO R | F2.0 | -1, 98, 99 |
| 534 | PARTNERS | HOW MANY SEX PARTNERS R HAD IN LAST YEAR | F2.0 | -1, 98, 99 |
| 535 | MATESEX | WAS 1 OF RS PARTNERS SPOUSE OR REGULAR | F1.0 | 0, 8, 9 |
| 536 | FRNDSEX | R HAD SEX WITH FRIEND LAST YEAR | F1.0 | 0, 8, 9 |
| 537 | ACQNTSEX | R HAD SEX WITH ACQUAINTANCE LAST YEAR | F1.0 | 0, 8, 9 |
| 538 | PIKUPSEX | R HAD SEX WITH CAUSUAL DATE LAST YEAR | F1.0 | 0, 8, 9 |
| 539 | PAIDSEX | R HAD SEX FOR PAY LAST YEAR | F1.0 | 0, 8, 9 |
| 540 | OTHERSEX | R HAD SEX WITH SOME OTHER LAST YEAR | F1.0 | 0, 8, 9 |
| 541 | SEXSEX | SEX OF SEX PARTNERS IN LAST YEAR | F1.0 | 0, 8, 9 |
| 542 | SEXFREQ | FREQUENCY OF SEX DURING LAST YEAR | F2.0 | -1, 8, 9 |
| 543 | NUMWOMEN | NUMBER OF FEMALE SEX PARTNERS SINCE 18 | F3.0 | -1, 998, 999 |
| 544 | NUMMEN | NUMBER OF MALE SEX PARTNERS SINCE 18 | F3.0 | -1, 998, 999 |
| 545 | PARTOPEN | NUMBER OF SEX PARTNERS LAST YEAR | F3.0 | -1, 998, 999 |
| 546 | PARTOPN5 | NUMBER OF SEX PARTNERS LAST FIVE YEARS | F3.0 | -1, 998, 999 |
| 547 | PARTNRS5 | SEX OF THE PARTNER LAST FIVE YEARS | F2.0 | -1, 98, 99 |
| 548 | SEXSEX5 | SEX OF SEX PARTNERS LAST FIVE YEARS | F1.0 | 0, 8, 9 |
| 549 | EVPAIDSX | EVER HAVE SEX PAID FOR OR BEING PAID SINCE 18 | F1.0 | 0, 8, 9 |
| 550 | EVSTRAY | HAVE SEX OTHER THAN SPOUSE WHILE MARRIED | F1.0 | 0, 8, 9 |
| 551 | PROB1 |  | F3.0 | 0, 999 |
| 552 | PROB2 |  | F3.0 | 0, 999 |
| 553 | PROB3 |  | F3.0 | 0, 999 |
| 554 | PROB4 |  | F3.0 | 0, 999 |
| 555 | HLTH1 | ILL ENOUGH TO GO TO A DOCTOR | F1.0 | 0, 9 |
| 556 | HLTH2 | COUNSELLNG FOR MENTAL PROBLEMS | F1.0 | 0, 9 |
| 557 | HLTH3 | INFERTILITY, UNABLE TO HAVE A BABY | F1.0 | 0, 9 |
| 558 | HLTH4 | DRINKING PROBLEM | F1.0 | 0, 9 |
| 559 | HLTH5 | ILLEGAL DRUGS (MARIJUANA, COCAINE) | F1.0 | 0, 9 |
| 560 | HLTH6 | (HUSBAND,WIFE)PARTNER IN HOSPITAL | F1.0 | 0, 8, 9 |
| 561 | HLTH7 | A CHILD IN HOSPITAL | F1.0 | 0, 9 |
| 562 | HLTH8 | CHILD ON DRUGS, DRINKING PROBLEM | F1.0 | 0, 9 |
| 563 | HLTH9 | A DEATH OF A CLOSE FRIEND | F1.0 | 0, 9 |
| 564 | WORK1 | UNEMPLOYED AND LOOKING FOR WORK A MONTH + | F1.0 | 0, 9 |
| 565 | WORK2 | BEING DEMOTED OR MOVE TO WORSE POSITION | F1.0 | 0, 9 |
| 566 | WORK3 | A CUT IN PAY OR REDUCED HOURS | F1.0 | 0, 9 |
| 567 | WORK4 | BEING PASSED OVER FOR PROMOTION | F1.0 | 0, 9 |
| 568 | WORK5 | HAVING TROUBLE WITH ONE'S BOSS | F1.0 | 0, 9 |
| 569 | WORK6 | OWN BUSINESS LOSING MONEY OR FAILING | F1.0 | 0, 9 |
| 570 | WORK7 | A HUSBAND,WIFE,PARTNER BEING FIRED | F1.0 | 0, 8, 9 |
| 571 | WORK8 | A HUSBAND,WIFE,PARTNER CUT IN PAY | F1.0 | 0, 8, 9 |
| 572 | WORK9 | ONES'S SPOUSE BEING UNEMPLOYED | F1.0 | 0, 8, 9 |
| 573 | FINAN1 | GOING BANKRUPT | F1.0 | 0, 9 |
| 574 | FINAN2 | HAVING A CAR ETC. REPOSSESSED | F1.0 | 0, 9 |
| 575 | FINAN3 | PAWNING VALUABLES TO MAKE ENDS MEET | F1.0 | 0, 9 |
| 576 | FINAN4 | BEING PRESSURED TO PAY BILLS | F1.0 | 0, 9 |
| 577 | FINAN5 | MAJOR WORSENING FINANCIAL CONDITION | F1.0 | 0, 9 |
| 578 | HRDSHP1 | FALL BEHIND IN PAYING RENT, MORTGAGE | F1.0 | 0, 9 |
| 579 | HRDSHP2 | EVICTION FROM ONE'S APARTMENT,HOUSE | F1.0 | 0, 9 |
| 580 | HRDSHP3 | HAVING THE UTILITIES SHUT-OFF | F1.0 | 0, 9 |
| 581 | HRDSHP4 | BEING UNABLE TO PURCHASE NEEDED FOOD | F1.0 | 0, 9 |
| 582 | HRDSHP5 | UNABLE TO AFFORD NEEDED MEDICAL CARE | F1.0 | 0, 9 |
| 583 | HRDSHP6 | LACKING HEALTH INSURANCE COVERAGE | F1.0 | 0, 9 |
| 584 | HRDSHP7 | HOMELESS | F3.0 | 0, 9 |
| 585 | FAMPER1 | HAVING SERIOUS TROUBLE WITH SPOUSE | F1.0 | 0, 9 |
| 586 | FAMPER2 | SEPARATING FROM SPOUSE OR PARTENER | F1.0 | 0, 9 |
| 587 | FAMPER3 | BREAKING UP WITH FIANCE(E) | F1.0 | 0, 9 |
| 588 | FAMPER4 | HAVING SERIOUS TROUBLE WITH A CHILD | F1.0 | 0, 9 |
| 589 | FAMPER5 | HAVING SERIOUS TROUBLE WITH FRIEND | F1.0 | 0, 9 |
| 590 | LAW1 | A ROBERY | F1.0 | 0, 9 |
| 591 | LAW2 | A PERSONAL ASSULT | F1.0 | 0, 9 |
| 592 | LAW3 | YOUR HOME BURGLARIZED | F1.0 | 0, 9 |
| 593 | LAW4 | ACCUSED OF CRIME | F1.0 | 0, 9 |
| 594 | LAW5 | ARRESTED | F1.0 | 0, 9 |
| 595 | LAW6 | SUED IN CIVIL CASE | F1.0 | 0, 9 |
| 596 | LAW7 | YOUR CHILD ARRESTED | F1.0 | 0, 9 |
| 597 | LIVE1 | YOUR HOME DESTROYED IN DISARSTER | F1.0 | 0, 9 |
| 598 | LIVE2 | YOUR HOME IN POOR CONDITION | F1.0 | 0, 9 |
| 599 | LIVE3 | MAJOR HOME REPAIRS | F1.0 | 0, 9 |
| 600 | LIVE4 | SERIOUS PROBLEM WITH YOUR LANDLORD | F1.0 | 0, 9 |
| 601 | OTH1 | BEING DISCRIMINATED AGAINST | F1.0 | 0, 9 |
| 602 | OTH2 | UNABLE TO GET TO SCHOOL | F1.0 | 0, 9 |
| 603 | OTH3 | CHILD HAVE TROUBLE IN SCHOOL | F1.0 | 0, 9 |
| 604 | OTH4 | NEED BUT UNABLE TO USE PUBLIC TRANSPORT. | F1.0 | 0, 9 |
| 605 | OTH5 | DO NOT HAVE A CAR | F1.0 | 0, 9 |
| 606 | EXTRA1 | OTHER PROBLEMS | F3.0 | 0 |
| 607 | EXTRA2 | OTHER PROBLEMS | F3.0 | 0 |
| 608 | ETHNIC | COUNTRY OF FAMILY ORIGIN | F2.0 | 0, 98, 99 |
| 609 | ETH1 | 1ST MENTIONED COUNTRY OF ORIGIN | F2.0 | 0, 98, 99 |
| 610 | ETH2 | 2ND MENTIONED COUNTRY OF ORIGIN | F2.0 | 0, 98, 99 |
| 611 | ETH3 | 3RD MENTIONED COUNTRY OF ORIGIN | F2.0 | 0, 98, 99 |
| 612 | ETHNUM | TYPE OF RESPONSE ABOUT ETHNICITY -- R | F1.0 | 5 |
| 613 | SPETHNIC | COUNTRY OF SPOUSES FAMILY ORIGIN | F2.0 | 0, 98, 99 |
| 614 | SPETH1 | 1ST MENTIONED COUNTRY OF SPOUSES ORIGIN | F2.0 | 0, 98, 99 |
| 615 | SPETH2 | 2ND MENTIONED COUNTRY OF SPOUSES ORIGIN | F2.0 | 0, 98, 99 |
| 616 | SPETH3 | 3RD MENTIONED COUNTRY OF SPOUSES ORIGIN | F2.0 | 0, 98, 99 |
| 617 | SPETHNUM | TYPE OF RESPONSE ABOUT ETHNICITY -- SP | F1.0 | 0, 5 |
| 618 | VETYEARS | YEARS IN ARMED FORCES | F2.0 | -1, 9 |
| 619 | DWELLING | TYPE OF STRUCTURE | F2.0 | 0, 98, 99 |
| 620 | DWELOWN | DOES R OWN OR RENT HOME? | F1.0 | 0, 8, 9 |
| 621 | WORDA | WORD A | F2.0 | -1, 9 |
| 622 | WORDB | WORD B | F2.0 | -1, 9 |
| 623 | WORDC | WORD C | F2.0 | -1, 9 |
| 624 | WORDD | WORD D | F2.0 | -1, 9 |
| 625 | WORDE | WORD E | F2.0 | -1, 9 |
| 626 | WORDF | WORD F | F2.0 | -1, 9 |
| 627 | WORDG | WORD G | F2.0 | -1, 9 |
| 628 | WORDH | WORD H | F2.0 | -1, 9 |
| 629 | WORDI | WORD I | F2.0 | -1, 9 |
| 630 | WORDJ | WORD J | F2.0 | -1, 9 |
| 631 | WORDSUM | NUMBER WORDS CORRECT IN VOCABULARY TEST | F2.0 | -1, 98, 99 |
| 632 | BALLOT | BALLOT USED FOR INTERVIEW | F1.0 | 0 |
| 633 | FORMWT | POST-STRATIFICATION WEIGHT | F5.3 | none |
| 634 | SAMPCODE | SAMPLING ERROR CODE | F3.0 | 0 |
| 635 | SAMPLE | SAMPLING FRAME AND METHOD | F1.0 | none |
| 636 | OVERSAMP | WEIGHTS FOR BLACK OVERSAMPLES | F6.4 | none |
| 637 | IDGSS |  | F8.2 | none |
| 638 | SAMPCODS | SAMPLING ERROR CODE | F8.2 | -1 |
| 639 | SAMPID |  | F8.2 | none |
| 640 | MATCH3 |  | F8.2 | none |
| 641 | RGSSID |  | F8.2 | none |
| 642 | V1 | SRL Case Identification Number | F5.0 | none |
| 643 | V2 | Study Number | F3.0 | none |
| 644 | V3 | DC Method | F1.0 | none |
| 645 | V4 | Interviewer Identification Number | F3.0 | none |
| 646 | V5 | GSS Identification Number | F6.0 | none |
| 647 | V6 | R/Spouse Employer | F1.0 | none |
| 648 | V7 | Time Interview Begin | F4.0 | 9998, 9999 |
| 649 | V8 | Q.1a  Profit / non - profit organization | F1.0 | none |
| 650 | V9 | Q.1b  Legal form of ORG | F1.0 | 8, 9 |
| 651 | V10 | Q.1b  Other Specify | F2.0 | 98, 99 |
| 652 | V11 | Q.1c  R is the owner/the partner | F1.0 | 8, 9 |
| 653 | V12 | Q.2a  Kind of ORG | F1.0 | 8, 9 |
| 654 | V13 | Q.2a  Other Specify | F2.0 | 98, 99 |
| 655 | V14 | Q.2b  ORG is local/state/federal agency | F1.0 | 8, 9 |
| 656 | V15 | Q.2c  ORG is public / private | F1.0 | 8, 9 |
| 657 | V16 | Q.3  Year ORG was first established | F4.0 | 9998, 9999 |
| 658 | V17 | Q.4a  ORG is part of large ORG/indepndnt | F1.0 | none |
| 659 | V18 | Q.4b  Name of the larger ORG | F1.0 | none |
| 660 | V19 | Q.4c  Address of the larger ORG | F1.0 | none |
| 661 | V20 | Q.4d  Year ORG affiliated w/larger ORG | F4.0 | 9998, 9999 |
| 662 | V21 | Q.4e  Way ORG is part of larger ORG | F1.0 | 8, 9 |
| 663 | V22 | Q.4e  Other Specify | F2.0 | 98, 99 |
| 664 | V23 | Q.5a  Number of full time employees | F5.0 | 99998, 99999 |
| 665 | V24 | Q.5b  Percentage of women / full time | F3.0 | 998, 999 |
| 666 | V25 | Q.5c  Percentage of white / full time | F3.0 | 998, 999 |
| 667 | V26 | Q.6a  Number of inc/dec - full - 1 yrs | F1.0 | 8, 9 |
| 668 | V27 | Q.6b  Percentage of wrkplace incrsd/full | F3.0 | 998, 999 |
| 669 | V28 | Q.6c  Percentage of wrkplace decrsd/full | F3.0 | 998, 999 |
| 670 | V29 | Q.7a  Number of inc/dec - full - 3 yrs | F1.0 | 8, 9 |
| 671 | V30 | Q.7b  Percentage of wrkplace incrsd/full | F3.0 | 998, 999 |
| 672 | V31 | Q.7c  Percentage of wrkplace decrsd/full | F3.0 | 998, 999 |
| 673 | V32 | Q.5a  Number of part time employees | F5.0 | 99998, 99999 |
| 674 | V33 | Q.5b  Percentage of women / part time | F3.0 | 998, 999 |
| 675 | V34 | Q.5c  Percentage of white / part time | F3.0 | 998, 999 |
| 676 | V35 | Q.6a  Number of inc/dec - part - 1 yrs | F1.0 | 8, 9 |
| 677 | V36 | Q.6b  Percentage of wrkplace incrsd/part | F3.0 | 998, 999 |
| 678 | V37 | Q.6c  Percentage of wrkplace decrsd/part | F3.0 | 998, 999 |
| 679 | V38 | Q.7a  Number of inc/dec - part - 3 yrs | F1.0 | 8, 9 |
| 680 | V39 | Q.7b  Percentage of wrkplace incrsd/part | F3.0 | 998, 999 |
| 681 | V40 | Q.7c  Percentage of wrkplace decrsd/part | F3.0 | 998, 999 |
| 682 | V41 | Q.8a  Kind of work ORG does | F1.0 | 8, 9 |
| 683 | V42 | Q.8b  What ORG does | F3.0 | 998, 999 |
| 684 | V44 | Q.8d  Job title for most invlvd w/main | F3.0 | 998, 999 |
| 685 | V45 | Q.9a  Number of total COREs work for ORG | F5.0 | 99998, 99999 |
| 686 | V46 | Q.9b  Percentage of women | F3.0 | 998, 999 |
| 687 | V47 | Q.9c  Percentage of temporaries | F3.0 | 998, 999 |
| 688 | V48 | Q.9d  Percentage of wkd primarily at hm | F3.0 | 998, 999 |
| 689 | V49 | Q.10  Work of COREs done by subcntrctng | F1.0 | 8, 9 |
| 690 | V50 | Q.11a  Hired COREs from outside ORG | F1.0 | 8, 9 |
| 691 | V51 | Q.11b1  Freq of mthd/newspaper advtsmnt | F1.0 | 8, 9 |
| 692 | V52 | Q.11b2  Freq of mthd/signs posted | F1.0 | 8, 9 |
| 693 | V53 | Q.11b3  Freq of mthd/referral frm emplys | F1.0 | 8, 9 |
| 694 | V54 | Q.11b4  Freq of mthd/refrl frm pro cntct | F1.0 | 8, 9 |
| 695 | V55 | Q.11b5  Freq of mthd/emplymnt agency | F1.0 | 8, 9 |
| 696 | V56 | Q.11b6  Freq of mthd/unsolicited inquiry | F1.0 | 8, 9 |
| 697 | V57 | Q.12a  Require/intelligence-psycho tests | F1.0 | 8, 9 |
| 698 | V58 | Q.12b  Require/skills-proficiency tests | F1.0 | 8, 9 |
| 699 | V59 | Q.12c  Require/letters of reference | F1.0 | 8, 9 |
| 700 | V60 | Q.12d  Require/physical examination | F1.0 | 8, 9 |
| 701 | V61 | Q.12e  Require/drug-alcohol tests | F1.0 | 8, 9 |
| 702 | V62 | Q.13  Number of applicatns fr a opening | F3.0 | 995, 998, 999 |
| 703 | V63 | Q.14a  Number of applicants interviewed | F3.0 | 995, 998, 999 |
| 704 | V64 | Q.14b  Period of typical interview/ min | F3.0 | 998, 999 |
| 705 | V65 | Q.14b  Period of typical interview/ dys | F1.0 | 8, 9 |
| 706 | V66 | Q.15  Number of offers to fill position | F1.0 | 8, 9 |
| 707 | V67 | Q.16a  Fill vacancies with people at ORG | F1.0 | 8, 9 |
| 708 | V68 | Q.16b  People need additional training | F1.0 | 8, 9 |
| 709 | V69 | Q.16c1  Freq/consult a seniority list | F1.0 | 8, 9 |
| 710 | V70 | Q.16c2  Freq/infrm emplys by post notice | F1.0 | 8, 9 |
| 711 | V71 | Q.16c3  Freq/ask person to recommnd othr | F1.0 | 8, 9 |
| 712 | V72 | Q.16c4  Freq/ask othrs at wkplc fr recom | F1.0 | 8, 9 |
| 713 | V73 | Q.16c5  Freq/go to spec emplys to encorg | F1.0 | 8, 9 |
| 714 | V74 | Q.17a  There are diffrnt levels of COREs | F1.0 | 8, 9 |
| 715 | V75 | Q.17b  Procedure fr promtng-formal/infml | F1.0 | 8, 9 |
| 716 | V76 | Q.18a  Possible to be promtd above COREs | F1.0 | 8, 9 |
| 717 | V77 | Q.18b  Freq of promotion above COREs | F1.0 | 8, 9 |
| 718 | V78 | Q.18c  Procedure fo promtn-formal/infoml | F1.0 | 8, 9 |
| 719 | V79 | Q.19a  GSSs work for ORG on March 1 1991 | F1.0 | 8, 9 |
| 720 | V80 | Q.19b  Number of full and part-time GSSs | F5.0 | 99998, 99999 |
| 721 | V81 | Q.19c  Percentage of women | F3.0 | 998, 999 |
| 722 | V82 | Q.19d  Percentage of temporaries | F3.0 | 998, 999 |
| 723 | V83 | Q.19e  Percentage of wkd primarily at hm | F3.0 | 998, 999 |
| 724 | V84 | Work of GSSs done by subcontracting | F1.0 | 8, 9 |
| 725 | V85 | Q.21a  Hired GSSs from outside ORG | F1.0 | 8, 9 |
| 726 | V86 | Q.21b1  Freq of mthd/newspaper advtsmnt | F1.0 | 8, 9 |
| 727 | V87 | Q.21b2  Freq of mthd/signs posted | F1.0 | 8, 9 |
| 728 | V88 | Q.21b3  Freq of mthd/referral frm emplys | F1.0 | 8, 9 |
| 729 | V89 | Q.21b4  Freq of mthd/refrl frm pro cntct | F1.0 | 8, 9 |
| 730 | V90 | Q.21b5  Freq of mthd/emplymnt agency | F1.0 | 8, 9 |
| 731 | V91 | Q.21b6  Freq of mthd/unsolicited inquiry | F1.0 | 8, 9 |
| 732 | V92 | Q.22a  Require/intelligence-psycho tests | F1.0 | 8, 9 |
| 733 | V93 | Q.22b  Require/skills-proficiency tests | F1.0 | 8, 9 |
| 734 | V94 | Q.22c  Require/letters of reference | F1.0 | 8, 9 |
| 735 | V95 | Q.22d  Require/physical examination | F1.0 | 8, 9 |
| 736 | V96 | Q.22e  Require/drug-alcohol tests | F1.0 | 8, 9 |
| 737 | V97 | Q.23  Number of applicatns fr a opening | F3.0 | 995, 998, 999 |
| 738 | V98 | Q.24a  Number of applicants interviewed | F3.0 | 995, 998, 999 |
| 739 | V99 | Q.24b  Period of typical interview/ min | F3.0 | 998, 999 |
| 740 | V100 | Q.24b  Period of typical interview/ dys | F1.0 | 8, 9 |
| 741 | V101 | Q.25  Number of offers to fill position | F1.0 | 8, 9 |
| 742 | V102 | Q.26a  Fill vacancies with people at ORG | F1.0 | 8, 9 |
| 743 | V103 | Q.26b  People need additional training | F1.0 | 8, 9 |
| 744 | V104 | Q.26c1  Freq/consult a seniority list | F1.0 | 8, 9 |
| 745 | V105 | Q.26c2  Freq/infrm emplys by post notice | F1.0 | 8, 9 |
| 746 | V106 | Q.26c3  Freq/ask person to recommnd othr | F1.0 | 8, 9 |
| 747 | V107 | Q.26c4  Freq/ask othrs at wkplc fr recom | F1.0 | 8, 9 |
| 748 | V108 | Q.26c5  Freq/go to spec emplys to encorg | F1.0 | 8, 9 |
| 749 | V109 | Q.27a  There are diffrnt levels of GSSs | F1.0 | 8, 9 |
| 750 | V110 | Q.27b  Procedure fr promtng-formal/infml | F1.0 | 8, 9 |
| 751 | V111 | Q.28a  Possible to be promtd above GSSs | F1.0 | 8, 9 |
| 752 | V112 | Q.28b  Freq of promotion above GSSs | F1.0 | 8, 9 |
| 753 | V113 | Q.28c  Procedure fo promtn-formal/infoml | F1.0 | 8, 9 |
| 754 | V114 | Q.29a  Mngr/admin on payroll on Mar 1 91 | F1.0 | 8, 9 |
| 755 | V115 | Q.29b  Number of full and part-time mngr | F5.0 | 99998, 99999 |
| 756 | V116 | Q.29c  Percentage of women | F3.0 | 998, 999 |
| 757 | V117 | Q.29d  Percentage of temporaries | F3.0 | 998, 999 |
| 758 | V118 | Q.29e  Percentage of wkd primarily at hm | F3.0 | 998, 999 |
| 759 | V119 | Q.30a  Hired mngr from outside ORG | F1.0 | 8, 9 |
| 760 | V120 | Q.30b1  Freq of mthd/newspaper advtsmnt | F1.0 | 8, 9 |
| 761 | V121 | Q.30b2  Freq of mthd/signs posted | F1.0 | 8, 9 |
| 762 | V122 | Q.30b3  Freq of mthd/referral frm emplys | F1.0 | 8, 9 |
| 763 | V123 | Q.30b4  Freq of mthd/refrl frm pro cntct | F1.0 | 8, 9 |
| 764 | V124 | Q.30b5  Freq of mthd/emplymnt agency | F1.0 | 8, 9 |
| 765 | V125 | Q.30b6  Freq of mthd/unsolicited inquiry | F1.0 | 8, 9 |
| 766 | V126 | Q.31a  Require/intelligence-psycho tests | F1.0 | 8, 9 |
| 767 | V127 | Q.31b  Require/skills-proficiency tests | F1.0 | 8, 9 |
| 768 | V128 | Q.31c  Require/letters of reference | F1.0 | 8, 9 |
| 769 | V129 | Q.31d  Require/physical examination | F1.0 | 8, 9 |
| 770 | V130 | Q.31e  Require/drug-alcohol tests | F1.0 | 8, 9 |
| 771 | V131 | Q.32  Number of applicatns fr a opening | F3.0 | 995, 998, 999 |
| 772 | V132 | Q.33a  Number of applicants interviewed | F3.0 | 995, 998, 999 |
| 773 | V133 | Q.33b  Period of typical interview/ min | F3.0 | 998, 999 |
| 774 | V134 | Q.33b  Period of typical interview/ dys | F1.0 | 8, 9 |
| 775 | V135 | Q.34  Number of offers to fill position | F1.0 | 8, 9 |
| 776 | V136 | Q.35a  Fill vacancies with people at ORG | F1.0 | 8, 9 |
| 777 | V137 | Q.35b  People need additional training | F1.0 | 8, 9 |
| 778 | V138 | Q.35c1  Freq/consult a seniority list | F1.0 | 8, 9 |
| 779 | V139 | Q.35c2  Freq/infrm emplys by post notice | F1.0 | 8, 9 |
| 780 | V140 | Q.35c3  Freq/ask person to recommnd othr | F1.0 | 8, 9 |
| 781 | V141 | Q.35c4  Freq/ask othrs at wkplc fr recom | F1.0 | 8, 9 |
| 782 | V142 | Q.35c5  Freq/go to spec emplys to encorg | F1.0 | 8, 9 |
| 783 | V143 | Q.36a  There are diffrnt levels of mngrs | F1.0 | 8, 9 |
| 784 | V144 | Q.36b  Procedure fr promtng-formal/infml | F1.0 | 8, 9 |
| 785 | V145 | Q.37  Provide formal job training | F1.0 | 8, 9 |
| 786 | V146 | Q.38a  Training condctd by stff on prmss | F1.0 | 8, 9 |
| 787 | V147 | Q.38b  Number of persons prvding trainng | F3.0 | 998, 999 |
| 788 | V148 | Q.38c  Size of training staff -inc/dec | F1.0 | 8, 9 |
| 789 | V149 | Q.39  Training condctd by largr ORG stff | F1.0 | 8, 9 |
| 790 | V150 | Q.40  Training condctd by outsd agencies | F1.0 | 8, 9 |
| 791 | V151 | Q.41a  Particpt in training off premises | F1.0 | 8, 9 |
| 792 | V152 | Q.41b  ORG provide tuition/reimbursemts | F1.0 | 8, 9 |
| 793 | V153 | Q.41c  ORG provide paid release time | F1.0 | 8, 9 |
| 794 | V154 | Q.42  Cost ORG spent on training in 2yrs | F7.0 | 9999998, 9999999 |
| 795 | V155 | Q.43  Amt of resrcs ORG devotd to traing | F1.0 | 8, 9 |
| 796 | V156 | Q.44  ORG devt more/less resrc to traing | F1.0 | 8, 9 |
| 797 | V157 | Q.45a  Number of emplys prtcptd training | F5.0 | 99998, 99999 |
| 798 | V158 | Q.45b1  Receive formal training / COREs | F1.0 | 7, 8, 9 |
| 799 | V159 | Q.45b2  Receive formal training / GSSs | F1.0 | 7, 8, 9 |
| 800 | V160 | Q.45b3  Receive formal training/ mgr-adm | F1.0 | 7, 8, 9 |
| 801 | V161 | Q.46a  Extent/teach remedial skills | F1.0 | 8, 9 |
| 802 | V162 | Q.46b  Extent/train emplys to use cmptrs | F1.0 | 8, 9 |
| 803 | V163 | Q.46c  Extent/train emply safe use equip | F1.0 | 8, 9 |
| 804 | V164 | Q.46d  Extent/provide/improve mgt skills | F1.0 | 8, 9 |
| 805 | V165 | Q.47a  Reason/legal requirements | F1.0 | 8, 9 |
| 806 | V166 | Q.47b  Reason/union contract | F1.0 | 8, 9 |
| 807 | V167 | Q.47c  Reason/to keep up w/traing practc | F1.0 | 8, 9 |
| 808 | V168 | Q.48a  Evaluation/formal testing | F1.0 | 8, 9 |
| 809 | V169 | Q.48b  Evaluation/trainee opinions | F1.0 | 8, 9 |
| 810 | V170 | Q.48c  Evaluation/supervisrs evaluation | F1.0 | 8, 9 |
| 811 | V171 | Q.48d  Evaluation/prgm dirctrs assessmt | F1.0 | 8, 9 |
| 812 | V172 | Q.49  Effectiveness of training | F1.0 | 8, 9 |
| 813 | V173 | Q.50  Imprtnce of trng fr promotn chance | F1.0 | 7, 8, 9 |
| 814 | V174 | Q.51  Paid for by fed/state/local govmnt | F1.0 | 8, 9 |
| 815 | V175 | Q.52a  Any training funded by JTPA | F1.0 | 8, 9 |
| 816 | V176 | Q.52b  Types of training funded by JTPA | F2.0 | 98, 99 |
| 817 | V177 | Q.53a  Benefit/medical hospitl insurance | F1.0 | 8, 9 |
| 818 | V178 | Q.53b  Benefit/dental care benefits | F1.0 | 8, 9 |
| 819 | V179 | Q.53c  Benefit/life insurance | F1.0 | 8, 9 |
| 820 | V180 | Q.53d  Benefit/sick leave with full pay | F1.0 | 8, 9 |
| 821 | V181 | Q.53e  Benefit/matrnty leav w/re-emplymt | F1.0 | 8, 9 |
| 822 | V182 | Q.53f  Benefit/assistnc fr elderly membr | F1.0 | 8, 9 |
| 823 | V183 | Q.53g  Benefit/flexible hours/schedule | F1.0 | 8, 9 |
| 824 | V184 | Q.53h  Benefit/cash/stock bonus fr pfmnc | F1.0 | 8, 9 |
| 825 | V185 | Q.53i  Benefit/pension/retirement progrm | F1.0 | 8, 9 |
| 826 | V186 | Q.53j  Benefit/profit-sharing program | F1.0 | 8, 9 |
| 827 | V187 | Q.53k  Benefit/drug/alcohol abuse progrm | F1.0 | 8, 9 |
| 828 | V188 | Q.53l  Benefit/long-term disabilty insrc | F1.0 | 8, 9 |
| 829 | V189 | Q.54  Rate of benefit package | F1.0 | 8, 9 |
| 830 | V190 | Q.55  ORG has increased fringe benefits | F1.0 | 7, 8, 9 |
| 831 | V191 | Q.56a  ORG/cut medical benefits | F1.0 | 7, 8, 9 |
| 832 | V192 | Q.56b  ORG/incd contrbtn to help pay/med | F1.0 | 7, 8, 9 |
| 833 | V193 | Q.56c  ORG/cut other fringe benefits | F1.0 | 7, 8, 9 |
| 834 | V194 | Q.56d  ORG/incd contrbtn to help pay/frg | F1.0 | 7, 8, 9 |
| 835 | V195 | Q.56e  ORG/lowered salaries/wages | F1.0 | 7, 8, 9 |
| 836 | V196 | Q.57  Problem of emplys w/young children | F1.0 | 8, 9 |
| 837 | V197 | Q.58a1  ORG provide a day care program | F1.0 | 8, 9 |
| 838 | V198 | Q.58b1  ORG considering program in 2 yrs | F1.0 | 8, 9 |
| 839 | V199 | Q.58a2  ORG help to cover day care cost | F1.0 | 8, 9 |
| 840 | V200 | Q.58b2  ORG considering program in 2 yrs | F1.0 | 8, 9 |
| 841 | V201 | Q.58a3  ORG provide day care servc info | F1.0 | 8, 9 |
| 842 | V202 | Q.58b3  ORG considering program in 2 yrs | F1.0 | 8, 9 |
| 843 | V203 | Q.59a  ORG provide paid parental leaves | F1.0 | 7, 8, 9 |
| 844 | V204 | Q.59b  ORG allow emply to take unpaid lv | F1.0 | 7, 8, 9 |
| 845 | V205 | Q.60a  Annual earnings Mgr - lowest | F7.0 | 9999997, 9999998, 9999999 |
| 846 | V206 | Q.60a  Annual earnings Mgr - highest | F7.0 | 9999997, 9999998, 9999999 |
| 847 | V207 | Q.60b  Annual earnings of most managers | F7.0 | 9999997, 9999998, 9999999 |
| 848 | V208 | Q.61a  Importance/experience in org | F1.0 | 7, 8, 9 |
| 849 | V209 | Q.61b  Importance/job performance | F1.0 | 7, 8, 9 |
| 850 | V210 | Q.61c  Importance/what othr emplyr payng | F1.0 | 7, 8, 9 |
| 851 | V211 | Q.61d  Importance/amt of formal educatin | F1.0 | 7, 8, 9 |
| 852 | V212 | Q.61e  Importance/relevant experience | F1.0 | 7, 8, 9 |
| 853 | V213 | Q.61f  Importance/difficulty of the work | F1.0 | 7, 8, 9 |
| 854 | V214 | Q.61g  Importance/supervisry responsblty | F1.0 | 7, 8, 9 |
| 855 | V215 | Q.61h  Importance/shrtg of qualfd people | F1.0 | 7, 8, 9 |
| 856 | V216 | Q.61i  Importance/othr mgrs are paid | F1.0 | 7, 8, 9 |
| 857 | V217 | Q.62a  Annual earnings CORE - lowest | F7.0 | 9999998, 9999999 |
| 858 | V218 | Q.62a  Annual earnings CORE - highest | F7.0 | 9999998, 9999999 |
| 859 | V219 | Q.62b  Annual earnings of most COREs | F7.0 | 9999998, 9999999 |
| 860 | V220 | Q.63a  Importance/union negotiations | F1.0 | 8, 9 |
| 861 | V221 | Q.63b  Importance/experience in org | F1.0 | 8, 9 |
| 862 | V222 | Q.63c  Importance/job performance | F1.0 | 8, 9 |
| 863 | V223 | Q.63d  Importance/what othr emplyr payng | F1.0 | 8, 9 |
| 864 | V224 | Q.63e  Importance/amt of formal educatin | F1.0 | 8, 9 |
| 865 | V225 | Q.63f  Importance/relevant experience | F1.0 | 8, 9 |
| 866 | V226 | Q.63g  Importance/difficulty of the work | F1.0 | 8, 9 |
| 867 | V227 | Q.63h  Importance/supervisry responsblty | F1.0 | 8, 9 |
| 868 | V228 | Q.63i  Importance/shrtg of qualfd people | F1.0 | 8, 9 |
| 869 | V229 | Q.63j  Importance/othr COREs are paid | F1.0 | 8, 9 |
| 870 | V230 | Q.64a  Annual earnings GSS - lowest | F7.0 | 9999997, 9999998, 9999999 |
| 871 | V231 | Q.64a  Annual earnings GSS - highest | F7.0 | 9999997, 9999998, 9999999 |
| 872 | V232 | Q.64b  Annual earnings of most GGSs | F7.0 | 9999997, 9999998, 9999999 |
| 873 | V233 | Q.65a  Importance/union negotiations | F1.0 | 7, 8, 9 |
| 874 | V234 | Q.65b  Importance/experience in org | F1.0 | 7, 8, 9 |
| 875 | V235 | Q.65c  Importance/job performance | F1.0 | 7, 8, 9 |
| 876 | V236 | Q.65d  Importance/what othr emplyr payng | F1.0 | 7, 8, 9 |
| 877 | V237 | Q.65e  Importance/amt of formal educatin | F1.0 | 7, 8, 9 |
| 878 | V238 | Q.65f  Importance/relevant experience | F1.0 | 7, 8, 9 |
| 879 | V239 | Q.65g  Importance/difficulty of the work | F1.0 | 7, 8, 9 |
| 880 | V240 | Q.65h  Importance/supervisry responsblty | F1.0 | 7, 8, 9 |
| 881 | V241 | Q.65i  Importance/shrtg of qualfd people | F1.0 | 7, 8, 9 |
| 882 | V242 | Q.65j  Importance/othr GSSs are paid | F1.0 | 7, 8, 9 |
| 883 | V243 | Q.66  Variablty of earnings amg ORG pstn | F1.0 | 7, 8, 9 |
| 884 | V244 | Q.67  Improved if people paid equally | F1.0 | 7, 8, 9 |
| 885 | V245 | Q.68a1  Main resp/finance | F1.0 | 8, 9 |
| 886 | V246 | Q.68b1  Separate Finance Dept | F1.0 | 8, 9 |
| 887 | V247 | Q.68a2  Main resp/accounting | F1.0 | 8, 9 |
| 888 | V248 | Q.68b2  Separate Accounting Dept | F1.0 | 8, 9 |
| 889 | V249 | Q.68a3  Main resp/health and safety | F1.0 | 8, 9 |
| 890 | V250 | Q.68b3  Separate Health and Safety Dept | F1.0 | 8, 9 |
| 891 | V251 | Q.68a4  Main resp/public relations | F1.0 | 8, 9 |
| 892 | V252 | Q.68b4  Separate Public Relations Dept | F1.0 | 8, 9 |
| 893 | V253 | Q.68a5  Main resp/personnel-labor reltns | F1.0 | 8, 9 |
| 894 | V254 | Q.68b5  Separate Personnel Dept | F1.0 | 8, 9 |
| 895 | V255 | Q.68a6  Main resp/research and develpmnt | F1.0 | 8, 9 |
| 896 | V256 | Q.68b6  Separate R and D Dept | F1.0 | 8, 9 |
| 897 | V257 | Q.68a7  Main resp/long-range planning | F1.0 | 8, 9 |
| 898 | V258 | Q.68b7  Separate Long Range Plng Dept | F1.0 | 8, 9 |
| 899 | V259 | Q.68a8  Main resp/marketing or sales | F1.0 | 8, 9 |
| 900 | V260 | Q.68b8  Separate Mktg - Sales Dept | F1.0 | 8, 9 |
| 901 | V261 | Q.69  Number of vertcl levels btwn postn | F2.0 | 98, 99 |
| 902 | V262 | Q.70a  Exist/rules and procedures manual | F1.0 | 8, 9 |
| 903 | V263 | Q.70b  Exist/written job description | F1.0 | 8, 9 |
| 904 | V264 | Q.70c  Exist/writtn record of job perfmc | F1.0 | 8, 9 |
| 905 | V265 | Q.70d  Exist/employment contracts | F1.0 | 8, 9 |
| 906 | V266 | Q.70e  Exist/personnel evaltn documents | F1.0 | 8, 9 |
| 907 | V267 | Q.70f  Exist/hire-fire procedr documents | F1.0 | 8, 9 |
| 908 | V268 | Q.70g  Exist/safety-hygiene practc docmt | F1.0 | 8, 9 |
| 909 | V269 | Q.70h  Exist/fringe benefit documents | F1.0 | 8, 9 |
| 910 | V270 | Q.71  Formal procedrs for reslvng dispts | F1.0 | 7, 8, 9 |
| 911 | V271 | Q.72a1  Larger ORG/nmbr of people emplyd | F1.0 | 7, 8, 9 |
| 912 | V272 | Q.72a2  Larger ORG/new employees to hire | F1.0 | 7, 8, 9 |
| 913 | V273 | Q.72a3  Larger ORG/subcntrctrs-temporary | F1.0 | 7, 8, 9 |
| 914 | V274 | Q.72a4  Larger ORG/evaltg wkr perfrmace | F1.0 | 7, 8, 9 |
| 915 | V275 | Q.72a5  Larger ORG/worker promotions | F1.0 | 7, 8, 9 |
| 916 | V276 | Q.72a6  Larger ORG/wage rate-salary lvls | F1.0 | 7, 8, 9 |
| 917 | V277 | Q.72a7  Larger ORG/dischg-layng off wrks | F1.0 | 7, 8, 9 |
| 918 | V278 | Q.72a8  Larger ORG/scheduling - overtime | F1.0 | 7, 8, 9 |
| 919 | V279 | Q.72b1  ORG/number of people employed | F1.0 | 7, 8, 9 |
| 920 | V280 | Q.72b2  ORG/new employees to hire | F1.0 | 7, 8, 9 |
| 921 | V281 | Q.72b3  ORG/subcntrctrs-temporary workrs | F1.0 | 7, 8, 9 |
| 922 | V282 | Q.72b4  ORG/evaluating worker perfrmace | F1.0 | 7, 8, 9 |
| 923 | V283 | Q.72b5  ORG/worker promotions | F1.0 | 7, 8, 9 |
| 924 | V284 | Q.72b6  ORG/wage rate or salary levels | F1.0 | 7, 8, 9 |
| 925 | V285 | Q.72b7  ORG/discharging-laying off wrkrs | F1.0 | 7, 8, 9 |
| 926 | V286 | Q.72b8  ORG/worker scheduling - overtime | F1.0 | 7, 8, 9 |
| 927 | V287 | Q.73  ORGs current performance-1 yr ago | F1.0 | 7, 8, 9 |
| 928 | V288 | Q.74  ORGs current performance-3 yr ago | F1.0 | 7, 8, 9 |
| 929 | V289 | Q.75a  Perform/quality of prodts-service | F1.0 | 7, 8, 9 |
| 930 | V290 | Q.75b  Perform/development of new prodts | F1.0 | 7, 8, 9 |
| 931 | V291 | Q.75c  Perform/ability to attract emplys | F1.0 | 7, 8, 9 |
| 932 | V292 | Q.75d  Perform/ability to retain emplyes | F1.0 | 7, 8, 9 |
| 933 | V293 | Q.75e  Perform/satisfaction of customers | F1.0 | 7, 8, 9 |
| 934 | V294 | Q.75f  Perform/relation btwn mgmnt-emply | F1.0 | 7, 8, 9 |
| 935 | V295 | Q.75g  Perform/relations among employees | F1.0 | 7, 8, 9 |
| 936 | V296 | Q.76a  Performance/marketing | F1.0 | 7, 8, 9 |
| 937 | V297 | Q.76b  Performance/growth in sales | F1.0 | 7, 8, 9 |
| 938 | V298 | Q.76c  Performance/profitability | F1.0 | 7, 8, 9 |
| 939 | V299 | Q.76d  Performance/market share | F1.0 | 7, 8, 9 |
| 940 | V300 | Q.77a  Problem/relations with unions | F1.0 | 7, 8, 9 |
| 941 | V301 | Q.77b  Problem/government regulations | F1.0 | 7, 8, 9 |
| 942 | V302 | Q.77c  Problem/hiring enough qualfd wrks | F1.0 | 7, 8, 9 |
| 943 | V303 | Q.77d  Problem/retaining qualfd employee | F1.0 | 7, 8, 9 |
| 944 | V304 | Q.77e  Problem/improving compensation | F1.0 | 7, 8, 9 |
| 945 | V305 | Q.77f  Problem/improving quality of prod | F1.0 | 7, 8, 9 |
| 946 | V306 | Q.77g  Problem/developing new prod-servc | F1.0 | 7, 8, 9 |
| 947 | V307 | Q.77h  Problem/increasing productivity | F1.0 | 7, 8, 9 |
| 948 | V308 | Q.78a  Techniques changing rapidly | F1.0 | 8, 9 |
| 949 | V309 | Q.78b  Essential to wk cooperatvly | F1.0 | 8, 9 |
| 950 | V310 | Q.78c  Politcl climate is favorble | F1.0 | 8, 9 |
| 951 | V311 | Q.78d  Relation w/org is conflict | F1.0 | 8, 9 |
| 952 | V312 | Q.78e  Concentrate do well/few risk | F1.0 | 8, 9 |
| 953 | V313 | Q.78f  Reacts to outside pressures | F1.0 | 8, 9 |
| 954 | V314 | Q.78g  Making long-range plan | F1.0 | 8, 9 |
| 955 | V315 | Q.79  ORG is subject to periodic review | F1.0 | 8, 9 |
| 956 | V316 | Q.80  ORG belongs to association of orgs | F1.0 | 8, 9 |
| 957 | V317 | Q.81  Pay attention to othr org practice | F1.0 | 8, 9 |
| 958 | V318 | Q.82a  ORGs sales changes - past 12 mos | F1.0 | 8, 9 |
| 959 | V319 | Q.82b  Percentage increased | F3.0 | 998, 999 |
| 960 | V320 | Q.82c  Percentage decreased | F3.0 | 998, 999 |
| 961 | V321 | Q.83a  ORGs profits changes - past 12mts | F1.0 | 8, 9 |
| 962 | V322 | Q.83b  Percentage increased | F3.0 | 998, 999 |
| 963 | V323 | Q.83c  Percentage decreased | F3.0 | 998, 999 |
| 964 | V324 | Q.84a  ORGs main market area | F1.0 | 8, 9 |
| 965 | V325 | Q.84b  Percentage of outside U.S. sales | F3.0 | 998, 999 |
| 966 | V326 | Q.85a  Main area served by ORG | F1.0 | 8, 9 |
| 967 | V327 | Q.85b  Percentage of operations outsd US | F3.0 | 998, 999 |
| 968 | V328 | Q.86  Competition in main mkt/serv area | F1.0 | 7, 8, 9 |
| 969 | V329 | Q.87  Competition in area fm foreign org | F1.0 | 7, 8, 9 |
| 970 | V330 | Q.88  Amount of competition in past 3yrs | F1.0 | 7, 8, 9 |
| 971 | V331 | Q.89  Operation regultd by govt agencies | F1.0 | 7, 8, 9 |
| 972 | V332 | Q.90a  Total operating budget fr fisc yr | F10.0 | 9999999998, 9999999999 |
| 973 | V333 | Q.90b  Confident of estimate | F1.0 | 4, 9 |
| 974 | V334 | Q.90c  Person know operation budget | F1.0 | none |
| 975 | V335 | Q.91a  Total number of operating sites | F5.0 | 99998, 99999 |
| 976 | V336 | Q.91b1  Number of physcl lctn/this state | F5.0 | 99998, 99999 |
| 977 | V337 | Q.91b2  Number of physcl lctn/rest of US | F5.0 | 99998, 99999 |
| 978 | V338 | Q.91b3  Number of physcl lctn/outside US | F5.0 | 99998, 99999 |
| 979 | V339 | Q.92  Total number of full/part employes | F7.0 | 9999998, 9999999 |
| 980 | V340 | Q.93  Year larger ORG first establised | F4.0 | 9998, 9999 |
| 981 | V341 | Q.94  Years R has worked for ORG | F2.0 | 98, 99 |
| 982 | V342 | Q.95a  Rs job title | F2.0 | 98, 99 |
| 983 | V343 | Q.95b  Rs major duties | F1.0 | none |
| 984 | V344 | Q.96  Year R was born | F2.0 | 98, 99 |
| 985 | V345 | Time interview ended | F4.0 | 9998, 9999 |
| 986 | V346 | Q.98  Gender of R | F1.0 | 8, 9 |
| 987 | V347 | Q.99  Major R from ORG or LARGER ORG | F1.0 | 8, 9 |
| 988 | V348 | Q.100  Second R from ORG or LARGER ORG | F1.0 | 8, 9 |
| 989 | V349 | GSS occupation code | F3.0 | 998, 999 |
| 990 | V350 | Telephone number area code | F3.0 | 998, 999 |
| 991 | V351 | Telephone number prefix | F3.0 | 998, 999 |
| 992 | V352 | Zip code | F5.0 | 99998, 99999 |
| 993 | V353 | Coder identification number | F3.0 | none |
| 994 | GSSBUCKS |  | F8.2 | none |
| 995 | COMBMOST |  | F8.2 | none |
| 996 | DUP | CASES FROM THE SAME ORG | F8.2 | none |
| 997 | NUMOBS | NUMBER OF CASES FOR ORG | F8.2 | none |
| 998 | NEWFULL | ASSIGNED VALUES FOR FULL-TIME WORKERS | F8.2 | 99998, 99999 |
| 999 | NEWPART | ASSIGNED VALUES FOR PART-TIME WRKERS | F8.2 | 99998, 99999 |
| 1000 | NEWTOTAL | TOTAL EMPLOYEES BASED ON ASSIGNED | F8.2 | none |
| 1001 | RAWWGT | RECIPROCAL OF SIZE (NEWTOTAL) | F8.2 | none |
| 1002 | WEIGHT | rawwgt adjusted to n=688 | F8.2 | 0 |
| 1003 | SRLID | SRL ASSIGNED ID | F8.2 | -1 |
| 1004 | NOSID |  | F8.2 | none |
| 1005 | INNOS |  | F8.2 | none |
| 1006 | GSSID | NORC ASSIGNED NUMBER | F8.2 | -1 |
| 1007 | RSSOC | RESPONDENT SPOUSE INDICATOR | F8.2 | -1 |
| 1008 | MATCH1 |  | F8.2 | none |
| 1009 | MATCH2 |  | F8.2 | none |
| 1010 | RNOSID |  | F8.2 | none |
| 1011 | MATCH4 |  | F8.2 | none |
| 1012 | MATCH5 |  | F8.2 | none |
| 1013 | SNOSID |  | F8.2 | none |
| 1014 | SGSSID |  | F8.2 | none |
| 1015 | MATCH6 |  | F8.2 | none |
| 1016 | MATCH7 |  | F8.2 | none |
