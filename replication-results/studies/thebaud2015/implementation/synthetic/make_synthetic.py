"""Generate synthetic inputs with the same columns and codes as the real files.

Values are random draws from a known data-generating process; nothing is taken from the real data
or from any publication. Used to test implementer code and synthetic rule checks.
"""
import json, sys
import numpy as np, pandas as pd

out = sys.argv[1]
rng = np.random.default_rng(20261028)
ISO = ['AUS', 'AUT', 'BEL', 'CAN', 'CZE', 'DNK', 'FIN', 'FRA', 'DEU', 'GRC', 'ISL', 'IRL', 'ITA', 'JPN', 'NLD',
       'NZL', 'NOR', 'POL', 'PRT', 'ESP', 'SWE', 'CHE', 'GBR', 'USA']
TRUE = {'b0': -2.0, 'female': -0.5, 'female:childcare': -0.25, 'female:leave': 0.2, 'female:parttime': 0.0,
        'childcare': 0.1, 'sd_country': 0.3, 'sd_country_female': 0.1, 'sd_survey': 0.2, 'sd_survey_female': 0.1,
        'n_per_survey': 160}

cy = []
for c in ISO:
    base = rng.normal(size=8)
    for y in range(1998, 2009):
        d = rng.normal(scale=0.2, size=8)
        cy.append(dict(iso3=c, year=y, leave_fte_weeks=max(0, 30 + 15 * (base[0] + d[0])),
                       childcare_interp=max(0.05, 0.6 + 0.3 * base[1]), childcare_pct_gdp_annual=max(0.05, 0.6 + 0.3 * (base[1] + d[1])),
                       pt_common_employees_women=25 + 8 * (base[2] + d[2]), pt_national_women=27 + 8 * (base[2] + d[2]),
                       pt_common_total_women=24 + 8 * (base[2] + d[2]), gdp_index_undp=min(1, 0.9 + 0.03 * (base[3] + d[3])),
                       unemployment_rate=max(1, 6 + 2 * (base[4] + d[4])), epl_overall=2 + 0.6 * (base[5] + d[5]),
                       women_managers_pct=30 + 5 * (base[6] + d[6]), fertility_rate=1.6 + 0.2 * (base[7] + d[7])))
cy = pd.DataFrame(cy)
cy.loc[(cy.iso3 == 'CHE') & (cy.year == 2001), 'unemployment_rate'] = np.nan  # a missing cell to exercise complete-case rules
cy.to_csv(f'{out}/country_year_inputs.csv', index=False)

z = lambda s: (s - s.mean()) / s.std()
cyz = cy.copy()
for k in ['leave_fte_weeks', 'childcare_interp', 'pt_common_employees_women']:
    cyz[k] = z(cy[k])
ce_c = dict(zip(ISO, rng.normal(scale=TRUE['sd_country'], size=24)))
ce_f = dict(zip(ISO, rng.normal(scale=TRUE['sd_country_female'], size=24)))
rows, rid = [], 1
for c in ISO:
    for y in range(2000, 2009):
        if rng.random() < 0.25:
            continue
        s_c, s_f = rng.normal(scale=TRUE['sd_survey']), rng.normal(scale=TRUE['sd_survey_female'])
        r = cyz[(cyz.iso3 == c) & (cyz.year == y)].iloc[0]
        rl = cyz[(cyz.iso3 == c) & (cyz.year == y - 1)].iloc[0]
        n = TRUE['n_per_survey']
        sex = rng.choice([1, 2], size=n)
        fem = (sex == 2).astype(int)
        age = rng.integers(18, 80, size=n)
        educ = rng.choice([0, 111, 1212, 1316, 1720, 9999], size=n, p=[.05, .15, .35, .3, .13, .02])
        work = rng.choice([1, 2, 3, 4, 5, 6, 9], size=n, p=[.55, .12, .1, .08, .07, .06, .02])
        eta = (TRUE['b0'] + ce_c[c] + s_c + fem * (TRUE['female'] + ce_f[c] + s_f)
               + TRUE['childcare'] * r.childcare_interp + TRUE['female:childcare'] * fem * r.childcare_interp
               + TRUE['female:leave'] * fem * rl.leave_fte_weeks)
        act = rng.random(n) < 1 / (1 + np.exp(-eta))
        own = act & (rng.random(n) < 0.6)
        nasc = act & ~own
        for i in range(n):
            o = bool(own[i])
            first = int(rng.integers(1988, y + 1)) if o else None
            now = int(rng.poisson(3)) if o else None
            rows.append(dict(
                ID_9817_RDM=rid, GEM_YR=y, iso3=c, COUNTRY=0, CTRYALP=c[:2], GEMSEX=int(sex[i]) if rng.random() > 0.005 else 9,
                GEMAGE=int(age[i]) if rng.random() > 0.01 else 999, GEMEDUC=int(educ[i]), GEMWORK=int(work[i]),
                GEMWORK3={1: 10, 2: 10, 3: 30, 4: 20, 5: 30, 6: 20, 9: 99}[int(work[i])],
                BSTART=int(nasc[i]) if rng.random() > 0.01 else 8, SUWAGE=(2 if nasc[i] else None),
                SUBOANWT=int(nasc[i]), OWNMGE=int(o) if rng.random() > 0.01 else 9,
                OMBABYBT=int(o and (y - first) <= 3), OMESTBBT=int(o and (y - first) > 3),
                OMOWN=(int(rng.choice([1, 2])) if o else None), OMOWNERS=(int(rng.integers(1, 4)) if o else None),
                OMWAGEYR=(max(1990, first) if o else None),
                OMREASON=(int(rng.choice([1, 2, 3, 4, 6, 8], p=[.55, .25, .08, .05, .05, .02])) if o else None),
                OMWHY=None, OMNOWJOB=now, OMYR5JOB=(now + int(rng.poisson(3)) if o else None),
                OMNEWCST=(int(rng.choice([1, 2, 3])) if (o and y >= 2002) else None),
                OMNEWT_5=(int(rng.choice([1, 2, 3])) if (o and y >= 2005) else None),
                SUSKILL=int(rng.choice([0, 1, 100, 8])), FEARFAIL=int(rng.choice([0, 1, 8])), KNOWENT=int(rng.choice([0, 1, 9])),
                NBSTATUS=(int(rng.choice([0, 1, 8])) if y >= 2003 else None),
                WEIGHT=1.0, WEIGHT_L=1.0, WEIGHT_A=1.0, TEA=int(act[i]), SUACTS=None, SUOWN=None))
            r_ = rows[-1]
            if r_['OMREASON'] is not None:
                r_['OMWHY'] = {1: 1, 2: -1, 3: 0, 4: 0, 6: 0, 8: 9}[r_['OMREASON']]
            rid += 1
pd.DataFrame(rows).to_csv(f'{out}/gem_extract.csv', index=False)
json.dump(TRUE, open(f'{out}/synthetic_truth.json', 'w'), indent=1)
print(len(rows), 'synthetic rows')
