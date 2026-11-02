# National Organizations Survey (NOS), 1991: source description

Prepared by the source-acquisition role from the ICPSR study description, the NOS technical manual and file-creation documentation in the ICPSR codebook, and the SPSS portable file's own metadata. It contains design and release facts only, with no summaries of the data.

## Release

- Title: National Organizations Survey (NOS), 1991. Principal investigators: Arne L. Kalleberg, David Knoke, Peter V. Marsden and Joe L. Spaeth.
- Distributor: Inter-university Consortium for Political and Social Research (ICPSR), study 6240, version V1 (DOI 10.3886/ICPSR06240.v1). ICPSR records an original release date of 1994-10-17 and a version date of 2006-01-18. The codebook PDF is labelled "Second ICPSR Release, November 1994".
- Producer: Survey Research Laboratory (SRL), University of Illinois, collected the establishment data. The NOS technical manual (August 1993) and codebook (July 1992) were prepared at the University of Minnesota. NSF grant SES-9022192, with a U.S. Department of Labor subcontract for the training analysis.
- Restrictions: county-level and ZIP-code-level contextual files are not in the public release.

## Design

- Universe: all U.S. business establishments with one or more paid employees, including self-employed owners. The unit is the work establishment, the physical site where paid employment occurs.
- Sampling: a hypernetwork design. Employed respondents to the 1991 General Social Survey (GSS), an equal-probability sample of adults, named their own employer and their working spouse's employer. Establishments therefore enter with probability proportional to their number of employees.
- Data collection: from 1991-04-18 to 1991-11-29, an SRL telephone interview with an informant at each establishment, usually the head of personnel or the person responsible for hiring, or else the chief executive. Informants who asked for it got a mail questionnaire that was changed as little as possible from the telephone version. Some interviews involved more than one informant or more than one session.
- Duplicate employers: when several GSS nominators named the same establishment, the informant was interviewed once and the data were copied to each nominator's record. These copies are coded V3 = 0 ("Duplicated by SRL"). The documentation reports 727 completed records, of which 688 are distinct (non-duplicated) establishments.
- Linked information: each record also carries the nominating GSS respondent's 1991 GSS variables. For spouse-employer records, the documentation says spouse information was substituted where available. Each record also carries industry-level variables from published government sources, which the technical manual says were merged at the two-digit SIC level.
- Questionnaire structure: organization type and ownership, size, and kind of work and main product or service. Three occupational blocks follow, each covering staffing, selection, internal filling of vacancies and promotion:
  - CORE: the job most directly involved with the main product or service.
  - GSS: the occupation of the nominating GSS respondent or spouse. This block is skipped if it is the same as CORE.
  - Managers and administrators: skipped if the same as CORE or GSS.

  The remaining sections cover formal training, benefits, earnings and the criteria used to set earnings, work organization and departments, vertical levels, formalization documents, dispute procedures, decision-making, performance relative to other organizations, environment and competition, operating budget, the larger organization (if any), and informant characteristics.
- Routing that creates structural missingness:
  - Q.1b-1c are for for-profit organizations and Q.2a-2c for not-for-profit ones.
  - Q.4b-4e apply only to establishments that are part of a larger organization.
  - Box A skips the GSS block when the GSS occupation is the same as CORE. Box B skips the manager block when CORE or GSS is a managerial job.
  - Q.37 = no skips the training block.
  - Box D skips the GSS earnings items when the GSS occupation is the same as CORE or manager.
  - Box E routes decision-making to Q.72a (part of a larger organization) or Q.72b (independent).
  - Box F asks the market-performance items Q.76a-d only of profit-making organizations. Box G applies the same profit-making condition to sales and profit items.
  - Box H asks the larger-organization items Q.91-93 only of establishments that are part of one.

## Weights

- The file has no weight variable set in its header.
- WEIGHT: labelled "rawwgt adjusted to n=688". The file-creation syntax defines it as RAWWGT x (688/83.637).
- RAWWGT: the reciprocal of establishment size (NEWTOTAL, the total of assigned full-time and part-time employment, NEWFULL + NEWPART).
- An earlier processing step set WEIGHT to 0 for duplicate records. The final documented step recomputed WEIGHT from RAWWGT for every record. WEIGHT = 0 is declared missing in the file.
- These weights undo the probability-proportional-to-size selection so that estimates refer to establishments. Unweighted estimates refer to establishments weighted by size, which is equivalent to the employees' view.
- The GSS weights carried on the record (FORMWT, OVERSAMP) refer to the GSS person sample, not to establishments.

## File

- Dataset DS0002 is an SPSS portable (.por) file written by SPSS Release 4.0 for Sun 4 on 1994-09-19. It has 727 records and 1016 numeric variables.
- ICPSR also lists DS0001, a fixed-width ASCII version (record length 1910). It is not supplied and not needed.
- Variable layout:
  - Positions 1-39: industry-level merged variables (INDUSTRY, a 1980 Census industry code, and industry characteristics).
  - Position 40 (V43): the main product or service code.
  - Positions 41-641: GSS 1991 individual variables and GSS design variables.
  - Positions 642-993 (V1-V353): the NOS establishment interview.
  - Positions 994-1016: file-construction, size-assignment, weight and match variables.
- Missing values:
  - The ICPSR file declares user-missing codes for 970 variables, mostly 7/8/9 or 97/98/99-type not-applicable, don't-know and no-response codes. System-missing values come mainly from skips.
  - The NOS technical manual states that the original archived SPSS-X file declared no missing values and asks users to decide which codes to treat as missing.
  - Some declared codes are substantive, for example 995 "large number of applications". Some non-substantive codes are not declared, for example 997 "not applicable" for application counts and 4 "varies/depends" for training effectiveness.
- Industry codes: V43 and INDUSTRY use the 1980 Census of Population industry classification. The release has no SIC code variable. The U.S. Census Bureau publishes the 1980 Census industry classification with 1972 SIC equivalents, and a study-local transcription of that list has been prepared.
- Embedded DOCUMENT text in the .por file was inherited from a GSS cumulative file and does not describe the NOS.

## Terms of use (summary)

ICPSR terms apply:

- Use the data for research or statistical purposes only.
- Do not attempt to identify respondents or organizations.
- Do not redistribute the data without ICPSR's written agreement, except as the terms allow for authorized users at member institutions.
- Cite the data in publications.

Derived data files therefore stay inside the study folder.
