"""Source role: assemble registry/registry.json from the validation outputs.
Run: ~/.venv/bin/python -I 07_build_registry.py"""
import json, os, re, datetime, hashlib, platform, subprocess
STUDY = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
R = lambda *p: os.path.join(STUDY, *p)
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
inv = json.load(open(R('data', 'supplied', 'supplied_sources.json')))
fv = {s['source_id']: s for s in json.load(open(R('registry', 'work', 'file_validation.json')))['sources']}
lc = json.load(open(R('registry', 'loader_check.json')))
st = json.load(open(R('registry', 'structure_check.json')))
YEAR = {'icpsr07927': '1976', 'icpsr09871': '1991', 'icpsr20022': '2006'}

def html_text(p):
    t = re.sub(r'<[^>]+>', ' ', open(p, encoding='utf-8', errors='replace').read())
    return re.sub(r'\s+', ' ', t)

def sha(p):
    h = hashlib.sha256(); h.update(open(p, 'rb').read()); return h.hexdigest()

extra = {
 'icpsr07927': dict(
    provider_title='Monitoring the Future: A Continuing Study of the Lifestyles and Values of Youth, 1976 (ICPSR 7927)',
    principal_investigators=['Jerald G. Bachman', 'Lloyd D. Johnston', "Patrick M. O'Malley"],
    provider_release=dict(version='V4', version_date='2007-05-25', original_release_date='1984-03-18', doi='10.3886/ICPSR07927.v4',
                          evidence=['07927-manifest.txt header (ICPSR07927-v4, 2007-05-25, doi)', '07927-descriptioncitation.html citation and version history']),
    provider_notes=['Version history: 2007-05-25 change in how missing values were assigned to V151; 2004-07-30 value labels added, 22 Form 1 variables recoded to correct coding errors, and 14 Form 3 variables (V3319-V3332) removed due to undefined codes.',
                    'Public-use weight V5 is a bracketed version of the original school-specific weight (six grouped values per the codebook); codebook distributions used the original full weights.',
                    'Identifying variables (birth month, school, city, state, student ID) removed; race collapsed (white/non-white/missing) per codebook.',
                    'Codebook is an edited ISR frequency volume; it documents question wording but not missing-data code values.']),
 'icpsr09871': dict(
    provider_title='Monitoring the Future: A Continuing Study of the Lifestyles and Values of Youth, 1991 (ICPSR 9871)',
    principal_investigators=['Lloyd D. Johnston', 'Jerald G. Bachman', "Patrick M. O'Malley"],
    provider_release=dict(version='V1', version_date='2006-03-30', original_release_date='1993-05-02', doi='10.3886/ICPSR09871.v1',
                          evidence=['09871-manifest.txt header', '09871-descriptioncitation.html citation and version history', 'ICPSR EDITION NUMBER variable value label "February 1993 release" in every 1991 file']),
    provider_notes=['Public-use weight V5 modified from the original school-varying weight for confidentiality; codebook distributions used the original full weights.',
                    'Codebook file-structure table lists Form 6 (Part 7) with a different variable count and case count than the delivered data file and the manifest; the data file agrees with the manifest. Not relevant to Forms 3-4.',
                    'Codebook states missing-data rules per variable (e.g. "MISSING 0 OR GE 9"); SPSS files declare discrete missing values that agree for one-digit items. For V5 the codebook says "MISSING 0 OR GE 9000" while the SPSS file declares 0 and 9.']),
 'icpsr20022': dict(
    provider_title='Monitoring the Future: A Continuing Study of American Youth (12th-Grade Survey), 2006 (ICPSR 20022)',
    principal_investigators=['Lloyd D. Johnston', 'Jerald G. Bachman', "Patrick M. O'Malley", 'John E. Schulenberg'],
    provider_release=dict(version='V3', version_date='2008-09-12', original_release_date='2007-10-29', doi='10.3886/ICPSR20022.v3',
                          evidence=['20022-manifest.txt header', '20022-descriptioncitation.html citation and version history']),
    provider_notes=['Version history: 2008-09-12 new PI data for Form 5 V5530-V5532; 2007-12-13 minor question-text changes for Form 3 V3342, V3359, V3376 and Form 4 V4223 (none are the Form 3 leisure/work statements or the Form 4 job-importance battery).',
                    'ICPSR standardized missing values to -9 and declared them as SPSS user-missing.',
                    'Some variables from Western-region schools were set to -9 for confidentiality (listed per form in the codebooks; none of the Form 3 A05/A06 or Form 4 A08 items are listed).',
                    'Public-use weight V5 modified from the original version for confidentiality.',
                    'User guide contains the MTF grade 12 cross-time question index 1976-2006 by item reference number.'])}

sources = []
for s in inv['sources']:
    sid = s['source_id']; f = fv[sid]; yr = YEAR[sid]
    files = f['files']
    data_files = [x for x in files if re.search(r'-Data\.(por|sav)$', x['path'])]
    md5_ok = all(x.get('manifest_md5_match') for x in data_files)
    inv_ok = all(x['setup_sha256_match'] and x['setup_bytes_match'] for x in files) and not f['setup_inventory_missing_on_disk'] and len(files) == len(s['file_inventory'])
    loader = {r['key']: r['pass'] for r in lc['files'] if r['key'].startswith(yr)}
    terms_txt = html_text(R(s['path_from_study'], 'TermsOfUse.html'))
    m = re.search(r'On (\d{4}-\d{2}-\d{2}), .*? agreed to the terms below pursuant to the download of study (\d+)', terms_txt)
    dslabels = f['manifest_dataset_labels']
    forms = {}
    for ds, lab in dslabels.items():
        key = f'{yr}_{ds}'; sc = st['files'][key]
        forms[ds] = dict(provider_label=lab,
                         label_in_setup_inventory=next((e['provider_dataset_label'] for e in s['empirical_data_validation'] if e['dataset_id'] == ds), None),
                         form_id_variable_V3_constant_and_matches=sc['V3_form_id_constant_and_equals_form'],
                         icpsr_part_variable=sc['icpsr_part_variable'],
                         rows_cols_match_manifest=next((x['manifest_record_count'].replace(',', '') == str(r['dimensions']['haven'][0]) and x['manifest_var_count'] == str(r['dimensions']['haven'][1])
                                                        for x in data_files if x['manifest_ds'] == ds for r in lc['files'] if r['key'] == key), None))
    sources.append(dict(
        source_id=sid, kind='user-supplied original survey bundle', provider='ICPSR (NAHDAP archive), data producer University of Michigan Institute for Social Research, Survey Research Center',
        provider_url_from_setup_inventory=s['provider_url'], provider_url_accessed_by_agent=False,
        title=extra[sid]['provider_title'], principal_investigators=extra[sid]['principal_investigators'],
        survey_year=int(yr), grade=12, release=extra[sid]['provider_release'],
        path_from_study=s['path_from_study'],
        provenance='downloaded by the user, a human, by hand; download time not recorded',
        download_date_evidence=(f'TermsOfUse.html states that the user agreed to the ICPSR terms on {m.group(1)} pursuant to the download of study {m.group(2)}; time of day and file-level download times are not recorded.' if m else None),
        setup_copy_time_utc='2026-10-28T01:48:50Z', validation_time_utc=now,
        validation=dict(
            files_on_disk=len(files), files_in_setup_inventory=len(s['file_inventory']),
            setup_inventory_sha256_and_size_match_all=inv_ok,
            data_files=len(data_files), provider_manifest_md5_match_all_data_files=md5_ok,
            codebook_md5_match=[x['path'] for x in files if x['path'].endswith('.pdf') and x.get('manifest_md5_match')],
            hidden_or_extra_files=f['hidden_files'],
            dataset_labels=forms,
            loader_equivalence_pass=loader,
            release_identity='confirmed from manifest header and description-citation html (title, version, DOI, distributor date)'),
        files=[dict(path=x['path'], bytes=x['bytes'], sha256=x['sha256'], md5=x['md5'], provider_manifest_md5=x.get('manifest_md5'), manifest_dataset=x.get('manifest_ds')) for x in files],
        provider_manifest_components_not_supplied=dict(
            files=f['manifest_files_not_supplied'],
            assessment='Alternative formats (Stata .dta, ASCII .txt, SAS transport .xpt) and setup/syntax files of the same datasets, plus the description-citation PDF (supplied as HTML). Not needed: the SPSS files carry all variables, value labels and declared missing values, and two independent loaders agree.'),
        provider_documentation_notes=extra[sid]['provider_notes'],
        terms=dict(file='TermsOfUse.html (preserved unchanged)',
                   summary=['Use the data solely for research or statistical purposes; no re-identification of research subjects.',
                            'Make no use of any identity discovered inadvertently and report such a discovery (to CBHSQ/SAMHDA per the text).',
                            'Cite the recommended bibliographic citation in publications and send citations of published works to ICPSR.',
                            'SAMHSA and ICPSR bear no responsibility for use or interpretation; violations may lead to institutional sanctions.',
                            'The terms text uses SAMHSA/SAMHDA wording although the study is distributed through NAHDAP; it does not expressly address redistribution, so data and derived extracts stay inside this study folder and are never given to readers.'],
                   accepted_by='the user, at download; no agent accepted terms'),
        missing_components=[]))

registry = dict(
    schema_version=1, study_id='twenge2010', created_utc=now, created_by='source/data role (fresh context)',
    runtime=dict(python=platform.python_version(), pyreadstat=lc['software']['pyreadstat'], pandas=lc['software']['pandas'], numpy=lc['software']['numpy'],
                 R=lc['software']['R'], haven=lc['software']['haven'],
                 pdftotext=subprocess.run(['pdftotext', '-v'], capture_output=True, text=True).stderr.split('\n')[0]),
    sources=sources,
    newly_acquired_sources=[],
    newly_acquired_note='No other public source is required: the article uses only MTF 12th-grade surveys for 1976, 1991 and 2006 (Forms 3 and 4), all present in the supplied bundles. No network access to any provider was made by this role.',
    source_requirements='registry/source_requirements.json',
    derived=dict(
        extracts=dict(dir='data/derived/extracts', files=[dict(path=r['extract']['path'], sha256=r['extract']['sha256'], source=r['source'], source_sha256=r['source_sha256']) for r in lc['files']],
                      content='every row and variable of every supplied SPSS file; raw numeric codes; declared user-missing codes retained; system-missing as empty field'),
        dictionaries=dict(dir='data/derived/dictionaries', summary_free_check='registry/summary_free_check.json'),
        source_description='data/derived/dictionaries/source_description.md'),
    checks=dict(loader_check='registry/loader_check.json', structure_check='registry/structure_check.json',
                summary_free_check='registry/summary_free_check.json', coverage_internal='registry/coverage_internal.json (coordinator-only)',
                file_validation='registry/work/file_validation.json'),
    cross_year_findings=dict(
        form_mapping={'1976': {'Form 3': 'DS0003', 'Form 4': 'DS0004', 'core': 'DS0006'}, '1991': {'Form 3': 'DS0004', 'Form 4': 'DS0005', 'core': 'DS0001'}, '2006': {'Form 3': 'DS0004', 'Form 4': 'DS0005', 'core': 'DS0001'}},
        form_mapping_evidence=['ICPSR manifest dataset labels', 'description-citation files', 'V3 (FORM ID) constant and equal to the form number in each form file', '1991 ICPSR PART NUMBER value labels (Part 4: Form 3; Part 5: Form 4)', '1976 V9002 part number', '2006 per-dataset codebook titles'],
        work_items_present_all_years=True,
        work_items='Form 3: V3222-V3226 (A05A-E, five agree/disagree categories) and V3227 (A06, two categories); Form 4: V4225-V4247 (A08A-W, four importance categories). Same variable names, question codes and MTF item reference numbers (08050-08100; 10090-10310) in 1976, 1991 and 2006. The A06/A14 "would you want to work" item (08100) also appears in Form 4 as V4263 and, per the cross-time index, in Form 5.',
        wording_and_scale_comparability='Question wording and response-category wording agree across the three codebooks apart from capitalisation and abbreviated SPSS labels; the 2006 cross-time index flags no wording, response-category or renumbering change for these items between 1976 and 2006. Missing-value coding differs by release (1976/1991: 0 and 9-or-higher declared missing, blanks system-missing; 2006: -9).',
        school_or_psu_identifiers='absent in all public files; only region (V13), self-representing PSU flag (V16) and SMSA/MSA flag (V17) describe the sampling location',
        weights='V5 SAMPLING WEIGHT in every file (public-use modified/bracketed version)',
        respondent_ids='V4 serial number unique within each file; form-file serials are disjoint across forms and together equal the core-file serials in each year; 2006 files also carry CASEID (sequential case number within file)'),
    blocking_issues=[],
)
json.dump(registry, open(R('registry', 'registry.json'), 'w'), indent=1, ensure_ascii=False)
cov = json.load(open(R('registry', 'coverage_internal.json')))
cov['loader_user_missing_cells'] = json.load(open(R('registry', 'work', 'loader_user_missing_counts_internal.json')))['counts']
json.dump(cov, open(R('registry', 'coverage_internal.json'), 'w'), indent=1)
print('written', now, [ (x['source_id'], x['validation']['setup_inventory_sha256_and_size_match_all'], x['validation']['provider_manifest_md5_match_all_data_files']) for x in sources])
print(json.dumps({x['source_id']: x['validation']['dataset_labels'] for x in sources}, indent=0)[:3000])
