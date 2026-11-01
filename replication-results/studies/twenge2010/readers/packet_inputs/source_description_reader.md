# Source description: Monitoring the Future, 12th-grade surveys 1976, 1991 and 2006

This is a neutral description of the original survey files available to this study. It is drawn from the provider documentation (ICPSR description-citation files, manifests, codebooks and the 2006 user guide) and from the SPSS file metadata. It contains no frequencies, means, counts or other summaries of the data, and no results from any publication.

## The survey

Monitoring the Future (MTF) is an ongoing annual survey of American high school seniors conducted by the University of Michigan Institute for Social Research, Survey Research Center, with core funding from the National Institute on Drug Abuse. Data are collected every spring by self-administered questionnaires in a sample of public and private high schools in the contiguous United States. The target population is high school seniors; students who have dropped out of school before the end of the senior year are outside the target population. Each survey year is a separate cross-section of a different graduating class. The public-use files are distributed by ICPSR (NAHDAP archive).

## Files and releases

| Year | ICPSR study | Version (release date) | DOI | Format |
|---|---|---|---|---|
| 1976 | 7927 | V4 (2007-05-25) | 10.3886/ICPSR07927.v4 | SPSS portable (.por) |
| 1991 | 9871 | V1 (2006-03-30) | 10.3886/ICPSR09871.v1 | SPSS portable (.por) |
| 2006 | 20022 | V3 (2008-09-12) | 10.3886/ICPSR20022.v3 | SPSS system (.sav) |

Each year is split by ICPSR into datasets ("DS"). The provider's dataset labels are:

| Year | Core | Form 1 | Form 2 | Form 3 | Form 4 | Form 5 | Form 6 |
|---|---|---|---|---|---|---|---|
| 1976 | DS0006 | DS0001 | DS0002 | DS0003 | DS0004 | DS0005 | (none) |
| 1991 | DS0001 | DS0002 | DS0003 | DS0004 | DS0005 | DS0006 | DS0007 |
| 2006 | DS0001 | DS0002 | DS0003 | DS0004 | DS0005 | DS0006 | DS0007 |

Dataset numbers therefore do not mean the same form in every year. The mapping was confirmed from the ICPSR manifests and description files, the form identifier variable V3 inside each form file, the ICPSR part-number variable (1976 and 1991) and the titles of the 2006 per-dataset codebooks.

## Questionnaire-form design

Every respondent completes one questionnaire form. In 1976 there were five forms and in 1991 and 2006 six. Forms are distributed within each school in an ordered (1976 documentation) or random (2006 documentation) sequence intended to give virtually identical subsamples. About a third of every form is a common "core" (drug use in section B and demographic and background items in section C); the remaining sections (A, D, E) differ by form.

- The core dataset holds the core variables for all respondents of all forms in that year.
- Each form dataset holds that form's respondents only, with the core variables (renamed with the form digit, for example V101 in the core file corresponds to V3101 in a Form 3 file in 1976) plus the form-specific variables.
- A respondent appears in exactly one form file. The serial number V4 is unique within each file, the serial numbers of the form files do not overlap, and together they equal the serial numbers of the core file of the same year (checked for all three years).

Form-specific items keep the same variable names across years when the item is unchanged. Exact wording, response categories and declared missing codes of every item are in the per-dataset dictionaries; compare years there.

## Sampling design

The sample is a multistage area probability sample with three stages: (1) geographic primary sampling units (PSUs) from the Survey Research Center national frame, some selected with certainty; (2) one or more high schools within each PSU, selected with probability proportional to the size of the senior class; (3) seniors within schools (all seniors in smaller schools, a random sample of seniors or classrooms in larger schools). Schools are asked to take part in two consecutive years, so about half the school sample is replaced each year. Schools that decline are replaced by similar schools from the same area (location, size and type). Students absent on the survey day are not followed up. The documentation states that, because of the clustered design, standard formulas for confidence intervals are not appropriate, and refers users to design guidance in the annual ISR volumes (not part of these files).

## Weights

Every file has a sampling weight V5 (SAMPLING WEIGHT). The original weights correct for unequal selection probabilities arising in the sampling stages and varied by school. In the public files the weight has been modified for confidentiality (the 1976 documentation describes it as a bracketed weight with a small number of grouped values). The provider recommends using V5 for all analyses and notes that results will differ slightly from published ISR tables, which used the original weights. In the 1976 form files and all 1991 files, the SPSS metadata declare certain weight codes as missing (0 and 9 or higher in 1976; 0 and 9 in 1991); see the dictionaries.

## Identifiers and geography

- V4: respondent serial number (unique within a file; links form files to the core file within a year).
- CASEID (2006 only): sequential case number within the file.
- V1: year of administration (two-digit code in 1976 and 1991, four digits in 2006); V3: form identifier.
- V13: Census region of the school (Northeast, North Central, South, West); V16: whether the school's PSU is self-representing; V17: whether the school is in an SMSA/MSA.
- No school, PSU, stratum, state or city identifier is present in any public file. The provider removed school, location and student ID information and other potentially identifying details.
- ICPSR housekeeping variables (study, part, edition or version number) appear at the end of the 1976 and 1991 files.

## Missing-data conventions

- System-missing values (blank in the source) appear as empty fields in the extracts.
- 1976 and 1991 (.por): the SPSS files declare user-missing values per variable, typically 0 and 9 (or "9 thru highest", "8 thru highest" and similar for items with more categories). The 1991 codebook states the rule per variable (for example "MISSING 0 OR GE 9"). The 1976 codebook does not document missing-data codes. In 2007 ICPSR changed how missing values were assigned to one 1976 variable (V151).
- 2006 (.sav): ICPSR standardized missing data to -9, declared as user-missing. For confidentiality some variables from Western-region schools were set to -9; the 2006 codebooks list the affected variables.
- The extracts keep every declared user-missing code as its numeric value. Whether and how to treat these codes is left to the analysis. Each variable's declared missing values are listed in its dictionary entry.

## Cross-year comparability notes

- The 2006 user guide includes a cross-time question index that flags wording, response-category and renumbering changes; such flags, where documented, are not reproduced here. Compare wording across years in the dictionaries.
- The numeric storage format of items changed (one-digit fields in 1976 and 1991, two-digit fields in 2006 to allow -9).
- Missing-value codes differ by release (0 and 9-or-higher versus -9), as do the year codes in V1.
- Race was collapsed in the public 1976 file (white or non-white), was black or white in 1991, and in 2006 is a black, white or Hispanic recode of a multiple-response question. Other demographic items may differ similarly; check the dictionaries.
- The 1976 public file removed 14 Form 3 variables (V3319-V3332) for undefined codes (version history, 2004).
- Generational or period interpretation is not addressed by the source documentation: each year is a cross-section of seniors surveyed in that year, so survey year, birth cohort and the period of measurement coincide within a year.

## What readers receive

- dictionaries/<year>_<DS>.dictionary.json and .md: one per dataset, listing variable name, SPSS label, storage format, value labels, declared missing values and codebook question wording (with MTF item reference numbers for 1991 and 2006). They contain no frequencies, percentages, counts, means or valid-code ranges.
- This description.

The underlying data are not part of the reader packet.
