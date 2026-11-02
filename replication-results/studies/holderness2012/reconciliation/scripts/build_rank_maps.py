"""Build rank mapping tables from the reconciled reader rules (ledger decisions D-RANK).
rank_army: mapping for SERVICE_CODE other than '2'; rank_navy: mapping for SERVICE_CODE '2'.
Origin (Reader A rule): collapse detailed grades to the nine ranks; Navy ratings by class; ambiguous labels missing.
Strict (Reader B origin rule): only labels that name one of the nine printed categories directly; Navy-only, technician,
cadet, flight-officer and other detailed labels missing."""
import csv, os, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
rows = list(csv.DictReader(open(f'{ROOT}/registry/code_lists/pow_GRADE_ALPHA_cl1275.csv', encoding='utf-8', errors='replace')))
def m(meaning):
    s = meaning.lower()
    # (army, navy, strict_army, strict_navy, rule)
    if s.startswith('civilian') or s in ('army transport service', 'bureau of yards and docks', "employee of the adjutant general's corps", 'contract surgeon', 'payclerk', 'aviation pilots'):
        return None, None, None, None, 'civilian/non-rank or unclassifiable label -> missing'
    if s.startswith('admiral') or 'vice admiral' in s or 'rear admiral' in s: return 9, 9, None, None, 'flag officer (Navy) -> 9; strict: Navy-only label'
    if 'general' in s and 'adjutant' not in s: return 9, 9, 9, 9, 'general officer -> 9'
    if s.startswith('lieutenant colonel or lieutenant commander'): return 8, 7, 8, None, 'Army LtCol (8) / Navy LtCdr (7) by service'
    if s.startswith('lieutenant colonel'): return 8, 8, 8, 8, 'lieutenant colonel -> 8'
    if s.startswith('colonel'): return 8, 8, 8, 8, 'colonel -> 8'
    if s.startswith('commander'): return 8, 8, None, None, 'Navy commander -> 8; strict: Navy-only'
    if s.startswith('lieutenant commander') or s.startswith('lt. commander'): return 7, 7, None, None, 'Navy lieutenant commander -> 7; strict: Navy-only'
    if s.startswith('major') and 'general' not in s: return 7, 7, 7, 7, 'major -> 7'
    if s.startswith('captain'): return 6, 8, 6, None, 'Army captain (6) / Navy captain (8) by service'
    if s.startswith('lieutenant junior grade') or s.startswith('lt. jr. grade') or s.startswith('ensign'): return 5, 5, None, None, 'LTJG/Ensign -> 5; strict: Navy-only'
    if s.startswith('first lieutenant') or s.startswith('second lieutenant'): return 5, 5, 5, 5, 'lieutenant -> 5'
    if s == 'lieutenant': return 5, 6, 5, None, 'Army lieutenant (5) / Navy lieutenant (6) by service'
    if 'warrant officer' in s: return 4, 4, 4, 4, 'warrant officer -> 4'
    if s.startswith('flight officer'): return 4, 4, None, None, 'flight officer -> 4; strict: detailed label'
    if 'sergeant' in s: return 3, 3, 3, 3, 'sergeant grades -> 3'
    if s.startswith('technician 3d') or s.startswith('technician 4th') or s.startswith('technician, 4th') or s.startswith('technician, third'):
        return 3, 3, None, None, 'technician 3d/4th grade -> 3; strict: detailed label'
    if s.startswith('technician 5th') or s.startswith('technician, grade 5'): return 2, 2, None, None, 'technician 5th grade -> 2; strict: detailed label'
    if s.startswith('corporal'): return 2, 2, 2, 2, 'corporal -> 2'
    if s.startswith('private'): return 1, 1, 1, 1, 'private/PFC -> 1'
    if s.startswith('aviation cadet') or s.startswith('cadet'): return 1, 1, None, None, 'cadet -> 1; strict: detailed label'
    if s.startswith('coxswain'): return 2, 2, None, None, 'coxswain (petty-officer-third-class equivalent) -> 2; strict: Navy-only'
    if s.startswith('chief') or s.startswith('aviation chief') or s.startswith('metalsmith, chief') or s.startswith('master at arms'):
        return 3, 3, None, None, 'chief petty officer / master at arms -> 3; strict: Navy-only'
    if re.search(r'apprentice|seaman|fireman|hospital apprentic', s): return 1, 1, None, None, 'seaman/apprentice/fireman -> 1; strict: Navy-only'
    if 'petty officer, 1st' in s or 'petty officer, 2nd' in s: return 3, 3, None, None, 'PO1/PO2 -> 3; strict: Navy-only'
    if 'petty officer, 3rd' in s: return 2, 2, None, None, 'PO3 -> 2; strict: Navy-only'
    if re.search(r'first class|second class', s): return 3, 3, None, None, 'rated 1st/2nd class -> 3; strict: Navy-only'
    if re.search(r'third class', s): return 2, 2, None, None, 'rated 3rd class -> 2; strict: Navy-only'
    return None, None, None, None, 'rating without class or unclassifiable -> missing'
out = []
for r in rows:
    a, n, sa, sn, rule = m(r['Meaning'])
    out.append({'grade_alpha': r['Code'], 'meaning': r['Meaning'], 'rank_origin_service_not_navy': a, 'rank_origin_navy': n,
                'rank_strict_service_not_navy': sa, 'rank_strict_navy': sn, 'rule': rule})
f = f'{ROOT}/registry/manifest_tables/rank_map_grade_alpha.csv'
with open(f, 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
# GRADE_CODE fallback / alternative mapping (officer identity from SERIAL_NO first character 'O' or 'T')
gc = [
 ('1', 9, 3, 9, 3), ('2', 8, 3, 8, 3), ('3', 8, 3, 8, 3), ('4', 7, 3, 7, 3), ('5', 6, 3, 6, 2), ('6', 5, 2, 5, 1), ('7', 5, 1, 5, 1),
 ('8', 4, 1, None, 1), ('9', 4, 1, 4, None), ('A', 9, None, 9, None), ('B', 8, None, 8, None), ('C', 8, None, 8, None),
 ('D', 7, None, 7, None), ('E', 6, None, 6, None), ('F', 5, None, 5, None), ('G', 5, None, 5, None), ('H', 1, 1, 1, 1),
 ('I', 4, 4, 4, 4), ('Y', 4, 4, 4, 4), ('Z', 4, 4, 4, 4), ('P', 5, 5, 5, 5), ('K', 8, 8, 8, 8),
 ('L', None, None, None, None), ('M', None, 3, None, None), ('N', None, 3, None, None), ('O', None, 2, None, None), ('S', None, None, None, None)]
with open(f'{ROOT}/registry/manifest_tables/rank_map_grade_code.csv', 'w', newline='') as fh:
    w = csv.writer(fh); w.writerow(['grade_code', 'rank_officer_not_navy', 'rank_enlisted_not_navy', 'rank_officer_navy', 'rank_enlisted_navy'])
    w.writerows(gc)
print(sum(1 for o in out if o['rank_origin_service_not_navy'] is None), 'of', len(out), 'labels missing under origin (non-Navy)')
print(sum(1 for o in out if o['rank_strict_service_not_navy'] is None), 'missing under strict (non-Navy)')
