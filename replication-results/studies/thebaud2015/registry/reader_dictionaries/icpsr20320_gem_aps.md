# Source dictionary: GEM Adult Population Survey, harmonized file (ICPSR 20320, V6)

Summary-free description for independent readers. It lists variable names, labels, value codes and coverage expressed only as which years and countries are present. It contains no counts, means, frequencies or other observed values.

## What the source is

- Title: Global Entrepreneurship Monitor [GEM]: Adult Population Survey Data Set, 1998-2017. Principal investigator Paul D. Reynolds. Distributor ICPSR, study 20320, version V6 (2022-07-12), doi 10.3886/ICPSR20320.v6. Harmonized-file version 4.01 (2020).
- Unit: individual adult respondent (18 and older), cross-sectional national samples by year (country-year surveys). One SPSS file with 97 variables.
- Design: national random samples of adults, mostly telephone (landline, later mobile) or face-to-face; some surveys used gender quotas. Vendors post-stratified weights to national population characteristics.
- Harmonization: core items harmonized across all surveys; standardized transforms identify nascent entrepreneurs, new-firm owner-managers (owners paid for up to 42 months) and established owner-managers (more than 42 months). From 2003 the screening module asked eight attitude/perception items of everyone who qualified for a special module but only of a random half of the remaining respondents (two random item sets A and B).
- Before 2002 a 'don't know' to the first screening items was treated as 'no'; from 2002 a re-ask skip pattern was used. Screening wording broadened over time (self-employment, selling goods or services).
- Missing values are not declared as SPSS user-missing: missing information is system-missing or a labelled code (don't know, refused, not applicable, cannot code). Codes are listed per variable below.
- The file was supplied by the user from ICPSR. The article does not name the GEM release it used.

## Countries and survey years present (the article's 24 countries)

| Country | Survey years present in the file |
|---|---|
| Australia | 2000-2006, 2010-2011, 2014-2017 |
| Austria | 2005, 2007, 2012, 2014, 2016 |
| Belgium | 2000-2015 |
| Canada | 1998-2006, 2013-2017 |
| Czech Republic | 2006, 2011, 2013 |
| Denmark | 1999-2012, 2014 |
| Finland | 1998-2016 |
| France | 1999-2014, 2016-2017 |
| Germany | 1998-2006, 2008-2017 |
| Greece | 2003-2017 |
| Iceland | 2002-2010 |
| Ireland | 2000-2008, 2010-2017 |
| Italy | 1999-2010, 2012-2017 |
| Japan | 1999-2014, 2017 |
| Netherlands | 2001-2017 |
| New Zealand | 2001-2005 |
| Norway | 2000-2015 |
| Poland | 2001-2002, 2004, 2011-2017 |
| Portugal | 2001, 2004, 2007, 2010-2016 |
| Spain | 2000-2017 |
| Sweden | 2000-2007, 2010-2017 |
| Switzerland | 2002-2003, 2005, 2007, 2009-2017 |
| United Kingdom | 1998-2017 |
| United States | 1998-2017 |

The file contains many other countries (109 in total across 1998-2017); subnational samples (Scotland, Wales, NZ Maori, Azores, Shenzhen) are excluded from this version.

## Years in which selected items have any substantive response (article's 24 countries combined)

| Variable | Years with responses (2001-2008 window) |
|---|---|
| GEMSEX | 2001-2008 |
| GEMAGE | 2001-2008 |
| GEMWORK | 2001-2008 |
| GEMEDUC | 2001-2008 |
| GEMHHINC | 2001-2008 |
| BSTART | 2001-2008 |
| OWNMGE | 2001-2008 |
| KNOWENT | 2001-2008 |
| SUSKILL | 2001-2008 |
| FEARFAIL | 2001-2008 |
| NBSTATUS | 2003-2008 |
| OMOWN | 2001-2008 |
| OMOWNERS | 2001-2008 |
| OMWAGEYR | 2001-2008 |
| OMNEWCST | 2002-2008 |
| OMNEWTEC | 2002-2008 |
| OMNEWT_5 | 2005-2008 |
| OMNOWJOB | 2001-2008 |
| OMYR5JOB | 2001-2008 |
| OMREASON | 2001-2008 |
| WEIGHT | 2001-2008 |
| WEIGHT_L | 2001-2008 |
| WEIGHT_A | 2001-2008 |

Country-years within 2001-2008 in which an item has no substantive response at all (presence check only):

- Australia 2001: GEMEDUC
- France 2001: GEMWORK
- France 2003: GEMWORK, GEMEDUC
- New Zealand 2002: GEMWORK, GEMEDUC
- Norway 2001: GEMWORK
- Norway 2007: GEMWORK, GEMEDUC
- Spain 2001: GEMWORK, GEMEDUC
- NBSTATUS: no responses in any country in 2001 and 2002. OMNEWCST: none in 2001. OMNEWT_5: none before 2005.

## Variables

Type: numeric unless the SPSS format starts with A (string). Codes are listed as code = label. ISIC industry code lists and the full country code list are omitted for length (4-digit ISIC Rev. 3.1 codes to 2009, ISIC Rev. 4 from 2010; country code = international telephone access code, e.g. 1 United States, 44 United Kingdom, 49 Germany).

### GEM_YR

- Label: GEM PROC: GEM PROJECT YEAR
- SPSS format: F4.0
- Value labels: 1998 = 1998 GEM YR; 1999 = 1999 GEM YR; 2000 = 2000 GEM YR; 2001 = 2001 GEM YR; 2002 = 2002 GEM YR; 2003 = 2003 GEM YR; 2004 = 2004 GEM YR; 2005 = 2005 GEM YR; 2006 = 2006 GEM YR; 2007 = 2007 GEM YR; 2008 = 2008 GEM YR; 2009 = 2009 GEM YR; 2010 = 2010 GEM YR; 2011 = 2011 GEM YR; 2012 = 2012 GEM YR; 2013 = 2013 GEM YR; 2014 = 2014 GEM YR; 2015 = 2015 GEM YR; 2016 = 2016 GEM YR; 2017 = 2017 GEM YR

### SETID

- Label: GEM PROC: CASE ID+COUNTRY+PROJECT YEAR
- SPSS format: F13.0

### ID_9817_RDM

- Label: GEM PROC: 12 DIGIT RANDOM NUMBER
- SPSS format: F15.2

### SETID_NE

- Label: GEM PROC: GEM COORD UNIQUE ID: 2007 ON
- SPSS format: A17

### COUNTRY

- Label: GEM PROC: INTERNATIONAL PHONE ACCESS CODE
- SPSS format: F4.0
- Value labels: long code list (industry or country codes); see ICPSR documentation.

### CTRYALP

- Label: GEM PROC: UNIQUE 2 CHAR ALPHA COUNTRY ID
- SPSS format: A2
- Value labels: long code list (industry or country codes); see ICPSR documentation.

### WEO_CODE

- Label: GEM PROC: WORLD ECONOMIC OUTLOOK COUNTRY CODE
- SPSS format: F3.0
- Value labels: 998 = NOT ASSIGNED

### NAME

- Label: GEM PROC: COUNTRY NAME:20 CHAR ALPHA
- SPSS format: A20

### WEIGHT

- Label: GEM PROC: SURVEY VENDOR WEIGHT, ALL CASES
- SPSS format: F8.5
- Definition / question: Survey-vendor post-stratification weight, re-centred so its mean is 1 within each year.

### WEIGHT_L

- Label: GEM PROC: WEIGHT RECENTERED: 18-64 YEARS OLD
- SPSS format: F5.2
- Definition / question: Weight defined only for ages 18-64, adjusted to US Census Bureau International Data Base age-sex distributions after 2000 and re-centred within each country-year.

### WEIGHT_A

- Label: GEM PROC: WEIGHT RECENTERED: 18 AND OLDER
- SPSS format: F6.2
- Definition / question: Weight for ages 18 and older, adjusted and re-centred within each country-year.

### MOSURV

- Label: GEM PROC: MONTH SURVEY COMPLETED
- SPSS format: F2.0
- Value labels: 1 = JANUARY; 2 = FEBRUARY; 3 = MARCH; 4 = APRIL; 5 = MAY; 6 = JUNE; 7 = JULY; 8 = AUGUST; 9 = SEPTEMBER; 10 = OCTOBER; 11 = NOVEMBER; 12 = DECEMBER

### GEMSEX

- Label: GEM DEMO: R GENDER
- SPSS format: F1.0
- Definition / question: Respondent gender (interviewer/respondent report).
- Value labels: 1 = MALE; 2 = FEMALE; 9 = DK/NR/MISS

### GEMAGE

- Label: GEM DEMO: R EXACT AGE
- SPSS format: F3.0
- Definition / question: Respondent exact age in years. Where a survey collected only age categories, the harmonizer assigned an approximate category midpoint (18-24 -> 21, 25-34 -> 29, 35-44 -> 39, 45-54 -> 49, 55-64 -> 59, 65+ -> 71). Respondents under 18 or with unknown age are not in the harmonized file.
- Value labels: 99 = DK/REFUSED; 999 = DK/REFUSED/MISSING

### GEMAGE7C

- Label: GEM DEMO: R AGE IN CATEGORIES
- SPSS format: F4.0
- Value labels: 1017 = 10-17 YRS OLD; 1824 = 18-24 YRS OLD; 2534 = 25-34 YRS OLD; 3544 = 35-44 YRS OLD; 4554 = 45-54 YRS OLD; 5564 = 55-64 YRS OLD; 6598 = 65-UP YRS OLD; 9999 = R/DK/MISS

### GEMWORK

- Label: GEM DEMO: R WORK FORCE STATUS, 6 CATEGORIES
- SPSS format: F1.0
- Definition / question: Harmonized work force status (6 categories) recoded from national survey-vendor items; definitions vary across national surveys.
- Value labels: 1 = FULL/FULL OR PART TIME; 2 = PART TIME ONLY; 3 = RETIRED/DISABLED; 4 = HOMEMAKER; 5 = STUDENT; 6 = NOT WORKING:OTHER; 9 = MISS/CANNOT CODE

### GEMWORK3

- Label: GEM DEMO: R WORK FORCE STATUS, 3 CATEGORIES
- SPSS format: F2.0
- Definition / question: Harmonized work force status (3 categories): working full or part time / not working / retired or student.
- Value labels: 10 = WORK:F-T,P-T; 20 = NOT WORKING; 30 = RETIRED,STUDENTS; 99 = MISS/CANNOT CLASSIFY

### GEMHHINC

- Label: GEM DEMO: R HH/PERSONAL INCOME, 3 CATEGORIES
- SPSS format: F5.0
- Definition / question: Household or personal income, reclassified within each national sample and year into thirds (no PPP or inflation adjustment).
- Value labels: 33 = LOWEST 33%TILE; 3467 = MIDDLE 33%TILE; 68100 = UPPER 33%TILE; 99999 = MISS/CANNOT CODE

### GEMEDUC

- Label: GEM DEMO: R EDUCATIONAL ATTAINMENT
- SPSS format: F4.0
- Definition / question: Harmonized educational attainment using a North American frame (12 years = secondary degree; post-secondary may include academic, vocational or technical training; 'GRAD EXP' = more than 16 years / graduate training).
- Value labels: 0 = NONE; 111 = SOME SECONDARY; 1212 = SECONDARY DEGREE; 1316 = POST SECONDARY; 1720 = GRAD EXP; 9999 = CAN NOT CODE

### BSTART

- Label: SCREEN: YES, AUTNONOMOUS START-UP
- SPSS format: F1.0
- Definition / question: 'You are, alone or with others, currently trying to start a new business, including any self-employment or selling any goods or services to others?' (wording varies slightly by year).
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = DK/NR/MISS

### BJOBST

- Label: SCREEN: YES, JOB INVOLVES BUSS START-UP
- SPSS format: F1.0
- Definition / question: 'You are, alone or with others, currently trying to start a new business or a new venture for your employer, as part of your normal work?'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = DK/NR/MISS

### OWNMGE

- Label: SCREEN: YES, OWNS, MANAGES A BUSINESS
- SPSS format: F1.0
- Definition / question: 'You are, alone or with others, currently the owner of a company you help manage, self-employed, or selling any goods or services to others?'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = DK/NR/MISS

### BUSANG

- Label: SCREEN: YES, BUSS ANGEL IN PAST 3 YEARS
- SPSS format: F3.0
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### OPPORT

- Label: SCREEN: YES, GOOD OPPORT FOR BUSS IN NEXT 6 MTHS
- SPSS format: F3.0
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### KNOWENT

- Label: SCREEN: YES, KNOW ENTRE IN PAST 2 YEARS
- SPSS format: F3.0
- Definition / question: 'Do you know someone personally who started a business in the past 2 years?'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### SUSKILL

- Label: SCREEN: YES, R HAS SKILL,ABILITY 4 START-UP
- SPSS format: F3.0
- Definition / question: 'Do you have / You have the knowledge, skill and experience required to start a new business?'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### FEARFAIL

- Label: SCREEN: YES, FAILURE FEAR WOULD PREVENT START-UP
- SPSS format: F3.0
- Definition / question: 'Would fear of failure prevent you from starting a business?'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### FUTSUP

- Label: SCREEN: YES, EXPECTS TO START BUSS IN 3 YRS
- SPSS format: F1.0
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED

### DISCENT

- Label: SCREEN: YES, SHUT DOWN BUSS IN PAST 12 MTHS
- SPSS format: F1.0
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED

### NBGOODC

- Label: SCREEN: YES, NEW BUSS GOOD CAREER CHOICE
- SPSS format: F3.0
- Definition / question: 'In your country, most people consider starting a new business a desirable career choice.'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### NBSTATUS

- Label: SCREEN: YES, SUCC IN NEW BUSS IS HI STATUS
- SPSS format: F3.0
- Definition / question: 'In your country, those successful at starting a new business have a high level of status and respect.'
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### NBMEDIA

- Label: SCREEN: YES, GOOD MEDIA COVERAGE OF NEW BUSS
- SPSS format: F3.0
- Value labels: 0 = NO; 1 = YES; 8 = DON'T KNOW; 9 = REFUSED; 100 = YES

### EQUALINC

- Label: SCREEN: YES, ALL SHOULD HAVE SAME INCOME
- SPSS format: F1.0
- Value labels: 0 = NO; 1 = YES; 8 = DON T KNOW; 9 = REFUSED

### SUACTS

- Label: START-UP: R REPORTS START-UP ACTS IN PAST YEAR
- SPSS format: F1.0
- Definition / question: Start-up module: over the past twelve months, has the respondent done anything to help start this new business (e.g. looking for equipment or location, organizing a team, working on a business plan, saving money)?
- Value labels: 1 = YES; 2 = NO; 3 = DON T KNOW; 4 = REFUSED; 8 = DON'T KNOW; 9 = REFUSED

### SUOWN

- Label: START-UP: R WILL OWN PART/ALL NEW FIRM
- SPSS format: F6.0
- Definition / question: Start-up module: will the respondent personally own all, part, or none of this business?
- Value labels: 1 = ALL; 2 = PART; 3 = NONE; 4 = DON T KNOW; 5 = REFUSED; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED, MISSING; 999999 = SYSTEM MISSING

### SUOWNERS

- Label: START-UP: EXCPECTED NUMBER OF NEW FIRM OWNERS
- SPSS format: F4.0
- Value labels: 999 = DK,R,MISSING; 9997 = Not Codeable/Not Applicable; 9999 = DK,R,MISSING

### SUWAGE

- Label: START-UP: YES, WAGES, PROFITS PAID TO OWNERS 3+ MTHS
- SPSS format: F1.0
- Definition / question: Start-up module: has the new business paid any salaries, wages or payments in kind, including to the owners, for more than three months?
- Value labels: 1 = YES; 2 = NO; 3 = DON T KNOW; 4 = REFUSED; 8 = DON'T KNOW; 9 = REFUSED

### SUWAGEYR

- Label: START-UP: 1ST YR PAYMENTS TO OWNERS
- SPSS format: F5.0
- Value labels: 1990 = UP TO 1990; 9997 = NONE YET; 9998 = Not Applicable; 9999 = NO ANSWER/REFUSED; 99999 = CODING ERROR

### SUTYPE

- Label: START-UP: SECTOR,ISIC [UN,RE3.1,1990] 1998-2009
- SPSS format: F4.0
- Value labels: long code list (industry or country codes); see ICPSR documentation.

### SUTYPE_10

- Label: START-UP: SECTOR,ISIC [UN,RE4.0,2008] 2010 ON
- SPSS format: F4.0
- Value labels: 9997 = NOT APPLICABLE; 9998 = DID NOT KNOW; 9999 = REFUSED/MISSING

### SUTYPE1D

- Label: START-UP: SECTOR,ISIC [UN,RE3.1,1990],11 CAT, 1998-2009
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### SUTYPE1D_10

- Label: START-UP: SECTOR,ISIC [UN,RE4.0,2008],11 CAT, 2010 ON
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### SUNEWCST

- Label: START-UP: PROD/SERV NEW TO CUSTOMERS
- SPSS format: F1.0
- Value labels: 1 = NEW TO ALL; 2 = NEW TO SOME; 3 = NOT NEW TO ANY; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### SUCOMPET

- Label: START-UP: EXPECTED LEVEL OF COMPETITION
- SPSS format: F1.0
- Value labels: 1 = MANY COMPETITORS; 2 = SOME COMPETITORS; 3 = NO COMPETITORS; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### SUNEWTEC

- Label: START-UP: TECH AVAILABLE 1 YR AGO
- SPSS format: F1.0
- Value labels: 0 = NOT AVALIABLE 1 YEAR AGO; 1 = YES, AVALIABLE 1 YEAR AGO; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### SUNEWT_5

- Label: START-UP: WHEN TECH AVAILABLE (2005 ON)
- SPSS format: F2.0
- Value labels: 1 = Less than a year; 2 = Between one to five years; 3 = Longer than five years; 7 = Not Applicable; 8 = Don't know; 9 = Refused; 99 = SYSTEM MISSING

### SUEXPORT

- Label: START-UP: % CUSTOMERS LIVE ABROAD
- SPSS format: F5.0
- Value labels: 0 = NONE; 1 = OVER 90% EXPORT; 2 = OVER 75% EXPORT; 3 = OVER 50% EXPORT; 4 = OVER 25% EXPORT; 5 = UNDER 25% EXPORT; 6 = NO EXPORTS; 7 = DOES NOT APPLY; 8 = DON'T KNOW; 9 = REFUSED; 125 = 1- 25%; 2650 = 26- 50%; 5175 = 51- 75%; 7690 = 76- 90%; 91100 = 91-100%; 99997 = Not Applicable; 99999 = DK/R/MISSING

### SUNOWJOB

- Label: START-UP: NUMBER JOBS NOW
- SPSS format: F9.0
- Value labels: 0 = NONE; 999997 = DOES NOT APPLY; 999998 = DOES NOT KNOW; 999999 = REFUSED; 9999997 = Not Applicable; 9999999 = REFUSED/DON'T KNOW; 999999999 = DK/R/MISSING

### SUYR5JOB

- Label: START-UP: NUMBER JOBS 5 YRS POST-BIRTH
- SPSS format: F7.0
- Value labels: 0 = NONE; 999999 = MISSING; 9999997 = Not Applicable; 9999999 = REFUSED/DON'T KNOW

### SUREASON

- Label: START-UP: REASON R IS INVOLVED
- SPSS format: F6.0
- Definition / question: Start-up module: same opportunity versus no-better-choices question for start-up efforts.
- Value labels: 1 = EXPLOIT BUS OPPORT; 2 = BEST WORK CHOICE; 3 = WK CHOICE & OPPORT; 4 = JOB & BETTER OPPORT; 5 = OTHER; 6 = FAMILY BUSINESS; 7 = Not Applicable; 8 = DON T KNOW; 9 = REFUSED; 999999 = SYSTEM MISSING

### SUOPTYPE

- Label: START-UP: NATURE OF BUSS OPPORTUNITY
- SPSS format: F1.0
- Value labels: 1 = INDEPENDENCE; 2 = INCREASE INCOME; 3 = MAINTAIN INCOME; 4 = OTHER; 5 = FAMILY BUSINESS; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### SUMONTOT

- Label: START-UP: TOTAL MONEY REQUIRED, NATIONAL CURRENCY
- SPSS format: A12
- Value labels: 999,999,997 = DOES NOT APPLY; 999,999,998 = DON'T KNOW; 999,999,999 = REFUSED; 9999999999 = DK/R/MISSING; 99999999999 = DK/R/MISSING

### SUMONOWN

- Label: START-UP: TOTAL MONEY R INVESTED, NATIONAL CURRENCY
- SPSS format: A12
- Value labels: 999,999,997 = DOES NOT APPLY; 999,999,998 = DON'T KNOW; 999,999,999 = REFUSED; 9999999999 = DK/R/MISSING; 99999999999 = DK/R/MISSING

### OMOWN

- Label: OWN-MANGE: R OWNS PART/ALL OF FIRM
- SPSS format: F6.0
- Definition / question: Owner-manager module: 'Do you personally own all, part, or none of this business?'
- Value labels: 1 = ALL; 2 = PART; 3 = NONE; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED, MISSING; 999999 = SYSTEM MISSING

### OMOWNERS

- Label: OWN-MANGE: NUMBER OF FIRM OWNERS
- SPSS format: F4.0
- Definition / question: Owner-manager module: 'How many people both own and manage this business?' (from 2010 'including yourself').
- Value labels: 999 = DK,R,MISSING; 9997 = Not Codeable/Not Applicable; 9999 = DK,R,MISSING

### OMWAGEYR

- Label: OWN-MANGE: 1ST YR PAYMENTS TO OWNERS
- SPSS format: F4.0
- Definition / question: Owner-manager module: 'What was the first year the owners [founders] received wages, profits, or payments in kind?' Value labels include both a 1-15 code scheme (codes for 2000 back to before 1990, no profits yet, don't know, refused) and calendar-year codes with special codes; which scheme applies in which survey year must be checked in the data documentation.
- Value labels: 1 = 2000; 2 = 1999; 3 = 1998; 4 = 1997; 5 = 1996; 6 = 1995; 7 = 1994; 8 = 1993; 9 = 1992; 10 = 1991; 11 = 1990; 12 = Before 1990; 13 = No profits yet; 14 = Don't know; 15 = Refused; 1990 = UP TO 1990; 9997 = NONE YET; 9998 = Not Applicable; 9999 = NO ANSWER/REFUSED

### OMTYPE

- Label: OWN-MANGE: SECTOR,ISIC [UN,RE3.1,1990] 1998-2009
- SPSS format: F4.0
- Value labels: long code list (industry or country codes); see ICPSR documentation.

### BBTYPE_10

- Label: OWN-MANGE: NEW   FIRM, ISIC [UN,RE4.0,2008] 2010 ON
- SPSS format: F4.0
- Value labels: 9997 = NOT APPLICABLE; 9998 = DID NOT KNOW; 9999 = REFUSED/MISSING

### EBTYPE_10

- Label: OWN-MANGE: ESTAB FIRM, ISIC [UN,RE4.0,2008] 2010 ON
- SPSS format: F4.0
- Value labels: 9997 = NOT APPLICABLE; 9998 = DID NOT KNOW; 9999 = REFUSED/MISSING

### OMTYPE1D

- Label: OWN-MANGE: SECTOR,ISIC [UN,RE3.1,1990],11 CAT, 1998-2009
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### BBTYPE1D_10

- Label: OWN-MANGE: NEW   FIRM, ISIC [UN,RE4.0,2008],11 CAT, 2010 ON
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### EBTYPE1D_10

- Label: OWN-MANGE: ESTAB FIRM, ISIC [UN,RE4.0,2008],11 CAT, 2010 ON
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### OMNEWCST

- Label: OWN-MANGE: PROD/SERV NEW TO CUSTOMERS
- SPSS format: F1.0
- Definition / question: Owner-manager module: 'Do all, some, or none of your potential customers consider this product or service new and unfamiliar?'
- Value labels: 1 = NEW TO ALL; 2 = NEW TO SOME; 3 = NOT NEW TO ANY; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### OMCOMPET

- Label: OWN-MANGE: EXPECTED LEVEL OF COMPETITION
- SPSS format: F1.0
- Value labels: 1 = MANY COMPETITORS; 2 = SOME COMPETITORS; 3 = NO COMPETITORS; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### OMNEWTEC

- Label: OWN-MANGE: TECH AVAILABLE 1 YR AGO
- SPSS format: F1.0
- Definition / question: Owner-manager module: were the technologies or procedures required for this product or service available more than a year ago?
- Value labels: 0 = NOT AVALIABLE 1 YEAR AGO; 1 = YES, AVALIABLE 1 YEAR AGO; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### OMNEWT_5

- Label: OWN-MANGE: WHEN TECH AVAILABLE (2005 ON)
- SPSS format: F2.0
- Definition / question: Owner-manager module (2005 on): how long have the technologies or procedures required for this product or service been available: less than a year, between one and five years, or longer than five years?
- Value labels: 1 = Less than a year; 2 = Between one to five years; 3 = Longer than five years; 7 = Not Applicable; 8 = Don't know; 9 = Refused; 99 = SYSTEM MISSING

### OMEXPORT

- Label: OWN-MANGE: % CUSTOMERS LIVE ABROAD
- SPSS format: F5.0
- Value labels: 0 = NONE; 1 = OVER 90% EXPORT; 2 = OVER 75% EXPORT; 3 = OVER 50% EXPORT; 4 = OVER 25% EXPORT; 5 = UNDER 25% EXPORT; 6 = NO EXPORTS; 7 = DOES NOT APPLY; 8 = DON'T KNOW; 9 = REFUSED; 125 = 1- 25%; 2650 = 26- 50%; 5175 = 51- 75%; 7690 = 76- 90%; 91100 = 91-100%; 99997 = Not Applicable; 99999 = DK/R/MISSING

### OMNOWJOB

- Label: OWN-MANGE: NUMBER JOBS NOW
- SPSS format: F7.0
- Definition / question: Owner-manager module: number of people currently working for the business (not counting owners in most years' wording).
- Value labels: 0 = NONE; 999999 = MISSING; 9999997 = Not Applicable; 9999999 = REFUSED/DON'T KNOW

### OMYR5JOB

- Label: OWN-MANGE: NUMBER JOBS IN 5 YRS
- SPSS format: F7.0
- Definition / question: Owner-manager module: number of people expected to be working for the business five years from now (not counting owners in most years' wording).
- Value labels: 0 = NONE; 999999 = MISSING; 9999997 = Not Applicable; 9999999 = REFUSED/DON'T KNOW

### OMREASON

- Label: OWN-MANGE: REASON R IS INVOLVED
- SPSS format: F6.0
- Definition / question: Owner-manager module: 'Are you involved in this firm to take advantage of a business opportunity or because you have no better choices for work?' (2010 on: 'Did you become involved ...').
- Value labels: 1 = EXPLOIT BUS OPPORT; 2 = BEST WORK CHOICE; 3 = WK CHOICE & OPPORT; 4 = OTHER; 6 = FAMILY BUSINESS; 7 = Not Applicable; 8 = DON T KNOW; 9 = REFUSED; 999999 = SYSTEM MISSING

### OMOPTYPE

- Label: OWN-MANGE: NATURE OF BUSS OPPORTUNITY
- SPSS format: F1.0
- Value labels: 1 = INDEPENDENCE; 2 = INCREASE INCOME; 3 = MAINTAIN INCOME; 4 = OTHER; 5 = FAMILY BUSINESS; 7 = Not Applicable; 8 = DON'T KNOW; 9 = REFUSED

### BAFUND

- Label: BUS ANGEL: FUNDING IN PAST 3 YRS, NATIONAL CURRENCY
- SPSS format: A11
- Value labels: -1 = MISSING; 9999999999 = DK/R/MISSING; 99999999999 = DK/R/MISSING

### BATYPE

- Label: BUS ANGEL: ECON SECTOR,ISIC [UN,RE3.1,1990] B4 2010
- SPSS format: F4.0
- Value labels: long code list (industry or country codes); see ICPSR documentation.

### BATYPE1D

- Label: BUS ANGEL: ECON SECTOR,ISIC [UN,RE3.1,1990],11 CAT, B4 2010
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### BAREL

- Label: BUS ANGEL: R RELATION TO INVESTEE
- SPSS format: F6.0
- Value labels: 1 = CLOSE FAMILY; 2 = OTHER RELATIVE; 3 = WORK COLLEAGUE; 4 = FRIEND/NEIGHBOR; 5 = STRANGER W/ GOOD IDEA; 6 = OTHER; 8 = DON T KNOW; 9 = REFUSED; 999999 = SYSTEM MISSING

### SUBOANWT

- Label: TRANSFORM: START-UP, OWNER, ACTIVE, NO WAGES
- SPSS format: F3.0
- Definition / question: Transformed: nascent entrepreneur = active in start-up behaviour in the past 12 months, expects to own all or part, and has not paid owners' salaries/wages for more than three months. After 2001 respondents are reclassified across start-up and owner categories using reported first-payment year.
- Value labels: 0 = NOT ACTIVE; 1 = QUALIFIES; 100 = ACTIVE

### OMBABYBT

- Label: TRANSFORM: NEW (BABY)  BUSS, OWNER, ACTIVE, <3.5 YRS SALARY
- SPSS format: F3.0
- Definition / question: Transformed: new-firm owner-manager = manages, owns all or part, owners paid for more than 3 but less than 42 months.
- Value labels: 0 = NOT ACTVE; 1 = QUALIFIES; 100 = ACTIVE

### OMESTBBT

- Label: TRANSFORM: ESTABLISHED BUSS, OWNER, ACTIVE, >3.5 YRS SALARY
- SPSS format: F3.0
- Definition / question: Transformed: established-firm owner-manager = manages, owns all or part, owners paid for more than 42 months.
- Value labels: 0 = NOT ACTIVE; 1 = QUALIFIES; 100 = ACTIVE

### SUWHY

- Label: TRANSFORM: START-UP  MOTIVATIONS: RECODED
- SPSS format: F2.0
- Value labels: -1 = BEST CHOICE; 0 = OPPORT & OTHER; 1 = OPPORT PRIMARY; 9 = OTHER,DK,R,MISSING

### OMWHY

- Label: TRANSFORM: OWN-MANGE MOTIVATONS: RECODED
- SPSS format: F2.0
- Definition / question: Transformed recode of owner-manager motivation (OMREASON).
- Value labels: -1 = BEST CHOICE; 0 = OPPORT & OTHER; 1 = OPPORT PRIMARY; 9 = OTHER,DK,R,MISSING

### SU_MOT

- Label: TRANSFORM: START-UP  MOTIVES: RECODE 2
- SPSS format: F1.0
- Value labels: 1 = OPPORUNITY; 2 = BEST CHOICE; 3 = MIXED,OTHER; 9 = NO DATA

### OMBB_MOT

- Label: TRANSFORM: BABY (NEW)  BUSS MOTIVES: RECODE 2
- SPSS format: F1.0
- Definition / question: Transformed: new (baby) business owner motive (opportunity / best choice / mixed-other).
- Value labels: 1 = OPPORUNITY; 2 = BEST CHOICE; 3 = MIXED,OTHER; 9 = NO DATA

### OMEB_MOT

- Label: TRANSFORM: ESTABLISHED BUSS MOTIVES: RECODE 2
- SPSS format: F1.0
- Definition / question: Transformed: established-business owner motive (opportunity / best choice / mixed-other).
- Value labels: 1 = OPPORUNITY; 2 = BEST CHOICE; 3 = MIXED,OTHER; 9 = NO DATA

### TEA

- Label: TRANSFORM: TEA/EARLY STAGE ACTIVITY
- SPSS format: F3.0
- Definition / question: Transformed: total early-stage entrepreneurial activity = nascent entrepreneur or new-firm owner-manager (counted once if both).
- Value labels: 0 = NOT ACTIVE; 1 = QUALIFIES; 100 = ACTIVE

### TEA_MOT

- Label: TRANSFORM: TEA/EARLY STAGE MOTIVATION
- SPSS format: F1.0
- Value labels: 1 = OPPORUNITY; 2 = BEST CHOICE; 3 = MIXED,OTHER; 9 = NO DATA

### TEOPTYPE

- Label: TRANSFORM: TEA NATURE OF BUSINESS OPPORTUNITY
- SPSS format: F1.0
- Value labels: 1 = INDEPENDENCE; 2 = INCREASE INCOME; 3 = MAINTAIN INCOME; 4 = OTHER; 5 = FAMILY BUSINESS; 7 = NOT APPLICABLE; 8 = DON'T KNOW; 9 = REFUSED

### TEATYPE

- Label: TRANSFORM: TEA VENTURE SECTOR,ISIC [UN,RE3.1,1990] B4 2010
- SPSS format: F4.0
- Value labels: 9997 = NOT APPLICABLE; 9998 = DID NOT KNOW; 9999 = REFUSED/MISSING

### TEATYPE_10

- Label: TRANSFORM: TEA VENTURE SECTOR,ISIC [UN,RE4.0,2008] 2010 ON
- SPSS format: F4.0
- Value labels: 9997 = NOT APPLICABLE; 9998 = DID NOT KNOW; 9999 = REFUSED/MISSING

### TEATYPE1D

- Label: TRANSFORM: TEA VENTURE SECTOR,ISIC [UN,RE3.1,1990],11 CAT, B4 2010
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### TEATYPE1D_10

- Label: TRANSFORM: TEA VENTURE SECTOR,ISIC [UN,RE4.0,2008],11 CAT, 2010 ON
- SPSS format: F5.0
- Value labels: 1000 = AGR,FOR,HUNT,FISH; 2000 = MINING, CONSTRUCTION; 3000 = MANUFACTURING; 4000 = TRANS,COMM,UTIL; 5000 = WHOLE,MV SALE,REPAIR; 6000 = RETAIL,HOTEL,REST,BAR; 7000 = FIN,INSUR,REAL EST; 8000 = BUS SERVICES; 9000 = HLTH,EDUC,SOC SERV; 10000 = CONSUMER SERVICE; 11000 = PUBLIC ADMINISTRATION; 99999 = OTHER,CAN NOT CODE,MISS

### TENEWCST

- Label: TRANSFORM: TEA VENTURE PROD/SERV NEW TO CUSTOMERS
- SPSS format: F1.0
- Value labels: 1 = NEW TO ALL; 2 = NEW TO SOME; 3 = NOT NEW TO ANY

### TECOMPET

- Label: TRANSFORM: TEA VENTURE EXPECTED LEVEL OF COMPETITION
- SPSS format: F1.0
- Value labels: 1 = MANY COMPETITORS; 2 = SOME COMPETITORS; 3 = NO COMPETITORS

### TENEWTEC

- Label: TRANSFORM: TEA VENTURE TECH AVALIABLE 1 YR AGO
- SPSS format: F1.0
- Value labels: 0 = NO/NONE; 1 = YES

### TENEWT_5

- Label: TRANSFORM: TEA VENTURE WHEN TECH AVALIABLE (2005 ON)
- SPSS format: F2.0

### TEEXPORT

- Label: TRANSFORM: TEA VENTURE % CUSTOMERS LIVE ABROAD
- SPSS format: F5.0
- Value labels: 0 = NONE; 125 = 1-25%; 2650 = 26-50%; 5175 = 51-75%; 7690 = 86-90%; 91100 = 91-100%

### TENOWJOB

- Label: TRANSFORM: TEA VENTURE NUMBER JOBS NOW
- SPSS format: F10.2

### TEYR5JOB

- Label: TRANSFORM: TEA VENTURE NUMBER JOBS IN 5 YRS
- SPSS format: F10.2

## Notes for use

- Weighting: three weights are provided (WEIGHT, WEIGHT_L, WEIGHT_A); the documentation recommends weights in any analysis, and dividing venture-level weights by team size when describing ventures rather than people.
- 'Best choice' / 'no better choices for work' motive: the harmonizer cautions that it is not equivalent to being unable to find any job.
- Case identifiers: ID_9817_RDM is a unique random record identifier; SETID / SETID_NE are original GEM case IDs (duplicates possible across years/countries).
