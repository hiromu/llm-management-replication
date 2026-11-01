"""Build the reader reconciliation ledgers and initial agreement statistics.

Matching rules (fixed before any comparison of labels):
- Claims are matched on estimand units: (model, term or term family, hypothesis). A reader claim maps to
  every unit whose model and term it explicitly covers in its support locators or statement.
- Specification levels are matched on content: two levels match when they prescribe the same operational
  rule for the same decision. Levels that bundle different rules are not matched.
- Agreement is computed on the reader's own label for each matched pair, including origin levels.
- Gwet's AC1 uses the categories actually defined by the schema (tiers: 5; spec labels: 3).
"""
import csv, json, os

OUT = os.path.join(os.path.dirname(__file__), '..')

# unit_id, description, fable claims, fable tier, astra claims, astra tier
CLAIM_UNITS = [
    ('U01', 'M3 female x paid leave and squared (H1a)', 'C03;C01', 'focal', 'C01', 'focal'),
    ('U02', 'M3 female x childcare (H1b)', 'C02;C01', 'focal', 'C02;C14', 'focal'),
    ('U03', 'M3 female x part-time (H1c)', 'C04;C01', 'focal', 'C03', 'focal'),
    ('U04', 'M1 female main effect', 'C05', 'focal', 'C13', 'focal'),
    ('U05', 'M4 female x childcare (H2)', 'C14', 'focal', 'C05;C04;C15', 'focal'),
    ('U06', 'M4 female x part-time (H2)', 'C15', 'focal', 'C06;C04;C15', 'focal'),
    ('U07', 'M4 female x paid leave and squared (H2)', 'C16', 'focal', 'C04', 'focal'),
    ('U08', 'M5 female x paid leave and squared (H3 size)', 'C18;C23', 'focal', 'C07;C16', 'focal'),
    ('U09', 'M6 female x paid leave and squared (H3 growth)', 'C19;C23', 'focal', 'C08;C16', 'focal'),
    ('U10', 'M7 female x paid leave and squared (H3 new product)', 'C20;C23', 'focal', 'C09;C17', 'focal'),
    ('U11', 'M8 female x childcare (H3 new technology)', 'C21;C23', 'focal', 'C10;C17', 'focal'),
    ('U12', 'M5-M8 female x part-time and other null interactions (H3)', 'C18;C23', 'focal', 'C11;C12', 'focal'),
    ('U13', 'M5-M8 female main effects', 'C22', 'descriptive', 'C26', 'focal'),
    ('U14', 'A3 M1 nascent outcome, female x childcare', 'C11', 'robustness', 'C18', 'robustness'),
    ('U15', 'A3 M2 full sample, female x childcare', 'C12', 'robustness', 'C19', 'robustness'),
    ('U16', 'A3 M3 perceptions added, female x childcare', 'C13', 'robustness', 'C20', 'robustness'),
    ('U17', 'M1 individual controls', 'C06', 'nuisance_control', 'C22', 'nuisance_control'),
    ('U18', 'M2 country-level controls', 'C07', 'nuisance_control', 'C23', 'nuisance_control'),
    ('U19', 'M4 individual and country controls', 'C17', 'nuisance_control', 'C24;C25', 'nuisance_control'),
    ('U20', 'A3 M3 perception and network coefficients', 'C13', 'robustness', 'C21', 'nuisance_control'),
    ('U21', 'M5-M8 country-level main effects', 'C31', 'nuisance_control', '', None),
    ('U22', 'Between-country variance explained, M1 to M2', 'C08', 'identification_or_inference_diagnostic', 'C33', 'identification_or_inference_diagnostic'),
    ('U23', 'Gender-slope variance explained, M2 to M3', 'C09', 'identification_or_inference_diagnostic', 'C34', 'identification_or_inference_diagnostic'),
    ('U24', 'LR test of random female slope (fn 17)', 'C10', 'identification_or_inference_diagnostic', 'C32', 'identification_or_inference_diagnostic'),
    ('U25', 'Indicator correlations and VIFs (fn 10, 13)', 'C27', 'identification_or_inference_diagnostic', 'C30;C31', 'identification_or_inference_diagnostic'),
    ('U26', 'Residual gender-slope variance in M8', '', None, 'C35', 'identification_or_inference_diagnostic'),
    ('U27', 'Figure 1 country activity rates', 'C24', 'descriptive', 'C27', 'descriptive'),
    ('U28', 'Figure 2 country-specific adjusted gaps', 'C25', 'descriptive', 'C28', 'descriptive'),
    ('U29', 'Figure 3 gap-institution correlations', 'C26', 'descriptive', 'C29', 'descriptive'),
    ('U30', 'Sample descriptive facts and appendix descriptives', 'C30', 'descriptive', 'C47', 'descriptive'),
    ('U31', 'Not-shown robustness: lags, alternative controls, separate entry (fn 8, 11-13)', 'C28', 'robustness', 'C36;C37;C38;C39', 'robustness'),
    ('U32', 'Not-shown robustness: women-only models (fn 22-23)', 'C29', 'robustness', 'C41;C42', 'robustness'),
    ('U33', 'Not-shown robustness: fn 16, 21, 24, 25 and Table A3 note', '', None, 'C40;C43;C44;C45;C46', 'robustness'),
    ('U34', 'Overall H3 / mechanism synthesis', 'C23', 'focal', 'C48', 'focal'),
]

# level_key, decision, description, fable (level_id,label), astra (level_id,label)
LEVELS = [
    ('LF_employed', 'labour-force restriction', 'Employed only, GEMWORK 1-2', ('A1.0', 'equivalent', True), ('S02_1', 'uncertain', True)),
    ('LF_plus_unemployed', 'labour-force restriction', 'Employed plus unemployed job seekers', ('A1.1', 'uncertain', False), ('S02_2', 'uncertain', False)),
    ('LF_full_sample', 'labour-force restriction', 'Full sample with not-employed control', ('A1.2', 'non_equivalent', False), ('S02_3', 'non_equivalent', False)),
    ('AGE_18_54', 'age bounds', 'Ages 18-54 inclusive', ('A2.0', 'equivalent', True), ('S01_2', 'uncertain', False)),
    ('AGE_19_54', 'age bounds', 'Ages 19-54 (literal over 18, under 55)', ('A2.1', 'uncertain', False), ('S01_1', 'uncertain', True)),
    ('CY_roster', 'country-year inclusion', 'Exactly the country-years listed in S1 Table A1', ('A3.0', 'equivalent', True), None),
    ('CY_all_available', 'country-year inclusion', 'All 2001-2008 country-years for the 24 countries', ('A3.1', 'uncertain', False), None),
    ('DK_missing', 'screening item DK', "Don't know / refused as missing", ('A4.0', 'equivalent', True), None),
    ('DK_as_no', 'screening item DK', "Don't know treated as no", ('A4.1', 'uncertain', False), None),
    ('OUT_screening', 'entrepreneurial-activity construction', 'BSTART=1 and no wages >3 months, or OWNMGE=1', ('A5.0', 'equivalent', True), ('S04_2', 'uncertain', False)),
    ('OUT_transforms_all', 'entrepreneurial-activity construction', 'SUBOANWT or OMBABYBT or OMESTBBT', ('A5.1', 'uncertain', False), None),
    ('OUT_suboanwt_ownmge', 'entrepreneurial-activity construction', 'SUBOANWT (nascent) or OWNMGE=1 (owner)', None, ('S04_1', 'uncertain', True)),
    ('OUT_nascent_only', 'entrepreneurial-activity construction', 'Nascent only', ('A5.2', 'non_equivalent', False), None),
    ('OUT_tea', 'entrepreneurial-activity construction', 'TEA alone', None, ('S04_3', 'non_equivalent', False)),
    ('OWN_ownmge', 'owner subsample', 'All current owner-managers OWNMGE=1', ('A6.0', 'equivalent', True), ('S03_1', 'uncertain', True)),
    ('OWN_omown_corrob', 'owner subsample', 'OWNMGE=1 corroborated by OMOWN', None, ('S03_2', 'uncertain', False)),
    ('OWN_omestbbt', 'owner subsample', 'OMESTBBT only (>42 months payments)', ('A6.1', 'uncertain', False), ('S03_3', 'non_equivalent', False)),
    ('MOT_omreason2', 'Plan-B coding', 'OMREASON=2 -> 1, other substantive -> 0', ('A7.0', 'equivalent', True), ('S14_1', 'uncertain', True)),
    ('MOT_omwhy', 'Plan-B coding', 'OMWHY=-1 -> 1', ('A7.1', 'equivalent', False), None),
    ('MOT_omreason23', 'Plan-B coding', 'OMREASON in {2,3} -> 1', ('A7.2', 'uncertain', False), ('S14_2', 'uncertain', False)),
    ('TECH_12', 'new-technology coding', 'OMNEWT_5 in {1,2} -> 1', ('A8.0', 'equivalent', True), None),
    ('TECH_1', 'new-technology coding', 'OMNEWT_5 = 1 only', ('A8.1', 'non_equivalent', False), None),
    ('BAGE_log1p', 'business-age transform', 'log(years + 1)', ('A9.0', 'uncertain', True), ('S16_2', 'non_equivalent', False)),
    ('BAGE_log_drop0', 'business-age transform', 'log(years), zero-year cases missing', ('A9.1', 'uncertain', False), ('S16_1', 'uncertain', True)),
    ('PT_common_total', 'part-time measure', 'Common definition, women in total employment', ('A10.0', 'equivalent', True), ('S10_4', 'non_equivalent', False)),
    ('PT_national', 'part-time measure', 'National definitions', ('A10.1', 'uncertain', False), ('S10_3', 'uncertain', False)),
    ('PT_common_employees', 'part-time measure', 'Common definition, women employees', ('A10.2', 'uncertain', False), ('S10_2', 'uncertain', False)),
    ('PT_employees_unresolved', 'part-time measure', 'Female employees, hours definition unresolved', None, ('S10_1', 'uncertain', True)),
    ('STD_sq_of_z', 'standardization and square', 'z-score across analytic country-years; square of standardized leave', ('A11.0', 'equivalent', True), ('S12_2', 'equivalent', False)),
    ('STD_country_means', 'standardization and square', 'z-score across 24 country means', ('A11.1', 'uncertain', False), None),
    ('STD_z_of_sq', 'standardization and square', 'square raw leave then standardize separately', ('A11.2', 'uncertain', False), ('S12_1', 'uncertain', True)),
    ('STD_age_sq_recentred', 'standardization and square', 'centre age-squared again', None, ('S12_3', 'equivalent', False)),
    ('STD_pop_country_years', 'standardization population', 'each country-year counted once', None, ('S13_1', 'uncertain', True)),
    ('STD_pop_individuals', 'standardization population', 'pooled individual rows', None, ('S13_2', 'equivalent', False)),
    ('STD_pop_model_specific', 'standardization population', 'outcome-specific country-year subset', None, ('S13_3', 'equivalent', False)),
    ('LAG_1', 'leave lag', 'one-year lag', ('A12.0', 'equivalent', True), ('S08_1', 'equivalent', True)),
    ('LAG_0', 'leave lag', 'no lag', ('A12.1', 'equivalent', False), ('S08_2', 'non_equivalent', False)),
    ('LAG_2', 'leave lag', 'two-year lag', ('A12.2', 'equivalent', False), ('S08_3', 'non_equivalent', False)),
    ('CC_interp', 'childcare missing years', 'linear interpolation between 2005 and 2007, carry endpoints', ('A13.0', 'uncertain', True), ('S09_2', 'uncertain', False)),
    ('CC_hist_unresolved', 'childcare missing years', 'historical concept, algorithm unresolved', None, ('S09_1', 'uncertain', True)),
    ('CC_nearest', 'childcare missing years', 'nearest-year value', None, ('S09_3', 'uncertain', False)),
    ('CC_annual_current', 'childcare missing years', 'current annual ECEC series directly', ('A13.1', 'uncertain', False), ('S09_4', 'non_equivalent', False)),
    ('RE_unstructured', 'random-effects covariance', 'intercept-slope covariance estimated', ('A14.0', 'uncertain', True), ('S19_2', 'uncertain', False)),
    ('RE_independent', 'random-effects covariance', 'independent intercept and slope', ('A14.1', 'uncertain', False), ('S19_3', 'uncertain', False)),
    ('RE_country_fe', 'random-effects covariance', 'country fixed effects', None, ('S19_4', 'non_equivalent', False)),
    ('W_none', 'weights', 'unweighted', ('A15.0', 'equivalent', True), ('S18_1', 'uncertain', True)),
    ('W_survey', 'weights', 'weighted (WEIGHT_L or WEIGHT_A)', ('A15.1', 'uncertain', False), ('S18_2', 'uncertain', False)),
    ('EST_aghq', 'likelihood approximation', 'adaptive Gauss-Hermite quadrature', ('A16.0', 'equivalent', True), ('S21_2', 'uncertain', False)),
    ('EST_aghq_more', 'likelihood approximation', 'AGHQ with more points', ('A16.1', 'equivalent', False), None),
    ('EST_laplace', 'likelihood approximation', 'Laplace approximation', ('A16.2', 'uncertain', False), ('S21_3', 'uncertain', False)),
    ('EST_reml', 'likelihood approximation', 'REML for linear model', None, ('S21_4', 'uncertain', False)),
    ('STAT_carry_back', 'status 2001-2002', "carry back each country's earliest available status", ('A17.0', 'uncertain', True), ('S06_3', 'non_equivalent', False)),
    ('STAT_drop_0102', 'status 2001-2002', 'drop 2001-2002 surveys', ('A17.1', 'non_equivalent', False), ('S06_2', 'non_equivalent', False)),
    ('STAT_unresolved', 'status 2001-2002', 'retain control, values unresolved', None, ('S06_1', 'uncertain', True)),
    ('STATPOP_all', 'status mean population', 'all valid respondents in country-year', None, ('S07_1', 'uncertain', True)),
    ('STATPOP_analytic', 'status mean population', 'analytic respondents only', None, ('S07_2', 'uncertain', False)),
    ('STATPOP_weighted', 'status mean population', 'design-weighted with routing adjustment', None, ('S07_3', 'uncertain', False)),
    ('GROW_additional', 'growth threshold', 'additional employees > 5', ('A18.0', 'equivalent', True), ('S15_1', 'equivalent', True)),
    ('GROW_total', 'growth threshold', 'total expected employees > 5', ('A18.1', 'uncertain', False), ('S15_2', 'non_equivalent', False)),
    ('MISS_model_cc', 'missing values', 'complete cases per model', None, ('S05_1', 'uncertain', True)),
    ('MISS_family_cc', 'missing values', 'common complete-case sample per family', None, ('S05_2', 'uncertain', False)),
    ('GDP_index', 'GDP control', 'UNDP GDP index', None, ('S11_1', 'uncertain', True)),
    ('GDP_pc_undp', 'GDP control', 'UNDP GDP per capita PPP', None, ('S11_2', 'uncertain', False)),
    ('GDP_wdi', 'GDP control', 'current WDI GDP per capita PPP', None, ('S11_3', 'non_equivalent', False)),
    ('SOLE_omown', 'sole owner', 'OMOWN all vs part', None, ('S17_1', 'uncertain', True)),
    ('SOLE_omowners', 'sole owner', 'OMOWNERS=1', None, ('S17_2', 'uncertain', False)),
    ('VCOV_model', 'native covariance', 'model-based', None, ('S20_1', 'uncertain', True)),
    ('VCOV_cluster', 'native covariance', 'country-cluster sandwich', None, ('S20_2', 'non_equivalent', False)),
    ('A3M2_no_fert', 'fertility in A3 M2', 'omit fertility', None, ('S22_1', 'uncertain', True)),
    ('A3M2_fert', 'fertility in A3 M2', 'include fertility', None, ('S22_2', 'uncertain', False)),
]


def ac1(pairs, cats):
    n = len(pairs)
    if n == 0:
        return None, None, None
    pa = sum(a == b for a, b in pairs) / n
    q = len(cats)
    pis = [((sum(a == k for a, _ in pairs) + sum(b == k for _, b in pairs)) / (2 * n)) for k in cats]
    pe = sum(p * (1 - p) for p in pis) / (q - 1)
    return pa, pe, (pa - pe) / (1 - pe) if pe < 1 else None


rows = []
for u in CLAIM_UNITS:
    uid, desc, fc, ft, ac, at = u
    status = 'matched' if ft and at else ('fable_only' if ft else 'astra_only')
    rows.append(dict(unit_id=uid, description=desc, fable_claims=fc, fable_tier=ft or '', astra_claims=ac,
                     astra_tier=at or '', match_status=status,
                     tier_agree='' if status != 'matched' else str(ft == at)))
with open(os.path.join(OUT, 'claim_ledger.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader(); w.writerows(rows)

lrows = []
for key, dec, desc, fa, as_ in LEVELS:
    status = 'matched' if fa and as_ else ('fable_only' if fa else 'astra_only')
    lrows.append(dict(level_key=key, decision=dec, description=desc,
                      fable_level=fa[0] if fa else '', fable_label=fa[1] if fa else '', fable_origin=fa[2] if fa else '',
                      astra_level=as_[0] if as_ else '', astra_label=as_[1] if as_ else '', astra_origin=as_[2] if as_ else '',
                      match_status=status,
                      label_agree='' if status != 'matched' else str(fa[1] == as_[1]),
                      origin_agree='' if status != 'matched' else str(fa[2] == as_[2])))
with open(os.path.join(OUT, 'spec_level_ledger.csv'), 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(lrows[0]))
    w.writeheader(); w.writerows(lrows)

tiers = ['focal', 'identification_or_inference_diagnostic', 'robustness', 'descriptive', 'nuisance_control']
tp = [(r['fable_tier'], r['astra_tier']) for r in rows if r['match_status'] == 'matched']
labs = ['equivalent', 'uncertain', 'non_equivalent']
lp = [(r['fable_label'], r['astra_label']) for r in lrows if r['match_status'] == 'matched']
op = [(r['fable_origin'], r['astra_origin']) for r in lrows if r['match_status'] == 'matched']
lp_nonorigin = [(r['fable_label'], r['astra_label']) for r in lrows
                if r['match_status'] == 'matched' and not r['fable_origin'] and not r['astra_origin']]
res = {}
for name, pairs, cats in [('claim_tier', tp, tiers), ('spec_label_all_matched_levels', lp, labs),
                          ('spec_label_matched_non_origin_levels', lp_nonorigin, labs),
                          ('origin_choice_matched_levels', op, [True, False])]:
    pa, pe, a = ac1(pairs, cats)
    res[name] = dict(n_matched=len(pairs), n_agree=sum(x == y for x, y in pairs), percent_agreement=pa,
                     gwet_ac1=a, chance_agreement=pe, categories=[str(c) for c in cats])
res['structure'] = dict(
    claim_units=len(rows), claim_units_matched=sum(r['match_status'] == 'matched' for r in rows),
    claim_units_fable_only=sum(r['match_status'] == 'fable_only' for r in rows),
    claim_units_astra_only=sum(r['match_status'] == 'astra_only' for r in rows),
    raw_claims_fable=31, raw_claims_astra=48,
    spec_levels=len(lrows), spec_levels_matched=sum(r['match_status'] == 'matched' for r in lrows),
    spec_levels_fable_only=sum(r['match_status'] == 'fable_only' for r in lrows),
    spec_levels_astra_only=sum(r['match_status'] == 'astra_only' for r in lrows),
    axes_fable=18, axes_astra=22, models_fable=13, models_astra=12)
res['note'] = ('Initial agreement before any clarification round. Matching rules are in the docstring of '
               'reconciliation/scripts/build_ledger.py. Origin labels are compared as given; readers used '
               'different conventions for labelling the origin level (Fable mostly equivalent, Astra mostly uncertain).')
json.dump(res, open(os.path.join(OUT, 'initial_agreement.json'), 'w'), indent=2)
print(json.dumps(res, indent=1))
