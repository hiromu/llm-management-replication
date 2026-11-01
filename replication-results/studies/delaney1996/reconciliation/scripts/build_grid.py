"""Build the frozen grid: origin, single-axis uncertain deviations, algebraic checks."""
import json
# axis: (origin level, {level: (label, basis)})
AX = {
 'records': ('L0', {'L1': ('uncertain', 'P02 both readers uncertain (drop V3=0 copies)')}),
 'market_sample': ('L0', {'L1': ('uncertain', 'P04 both uncertain (Table 1 footnote publicly held)')}),
 'market_requires_pop': ('L0', {'L1': ('uncertain', 'Fable manifest step 5 (subset of Sample A); Astra silent; rule (c) origin')}),
 'case_scope': ('L0', {'L1': ('uncertain', 'P06 label disagreement (non_equivalent vs uncertain)')}),
 'item_rule': ('L0', {'L1': ('uncertain', 'P08 both uncertain'), 'L2': ('uncertain', 'P09 both uncertain')}),
 'staff_coding': ('L0', {'L1': ('uncertain', 'P11 both uncertain'), 'L2': ('uncertain', 'Fable A05.L2 single reader uncertain')}),
 'z_reference': ('L0', {'L1': ('uncertain', 'P12 disagreement; Fable origin'), 'L2': ('uncertain', 'Astra A08.L2'), 'L3': ('uncertain', 'Astra A08.L4 single reader')}),
 'train_log': ('L0', {'L1': ('uncertain', 'P15 both uncertain'), 'L2': ('uncertain', 'Astra origin A06.L0; disagreement')}),
 'no_training': ('L0', {'L1': ('uncertain', 'P16 disagreement (Fable origin, Astra non_equivalent)'), 'L2': ('uncertain', 'Astra A05.L1 single reader')}),
 'decision_map': ('L0', {'L1': ('uncertain', 'Fable A10.L1 single reader')}),
 'union_items': ('L0', {'L1': ('uncertain', 'P19 both uncertain'), 'L2': ('uncertain', 'Fable A11.L1 single reader')}),
 'subsidiary': ('L0', {'L1': ('uncertain', 'P22 both uncertain'), 'L2': ('uncertain', 'Fable A12.L2 single reader')}),
 'age': ('L0', {'L1': ('uncertain', 'P25 disagreement'), 'L2': ('uncertain', 'P24 disagreement')}),
 'hierarchy': ('L0', {'L1': ('uncertain', 'P27 disagreement'), 'L2': ('uncertain', 'Astra A10.L2 single reader')}),
 'employment': ('L0', {'L1': ('uncertain', 'P30 disagreement'), 'L2': ('uncertain', 'Fable A14.L2 single reader')}),
 'pct_managers': ('L0', {'L1': ('uncertain', 'Fable A15.L1 single reader'), 'L2': ('uncertain', 'P32 disagreement')}),
 'competition': ('L0', {'L1': ('uncertain', 'P35 disagreement'), 'L2': ('uncertain', 'Fable A16.L2 single reader')}),
 'neither': ('L0', {'L1': ('uncertain', 'P37 disagreement')}),
 'industry': ('L0', {'L1': ('uncertain', 'Astra A17.L1 single reader (operationalized as exclusion)')}),
 'weights': ('L0', {'L1': ('uncertain', 'P44 disagreement')}),
 'centering': ('L0', {'L1': ('uncertain', 'P46 disagreement')}),
}
origin = {a: v[0] for a, v in AX.items()}
specs = [dict(spec_id='O', type='origin', settings=dict(origin))]
lab = [dict(spec_id='O', type='origin', axis=None, level=None, label='origin', basis='working origin per reconciliation rules')]
i = 0
for a, (o, lv) in AX.items():
    for l, (label, basis) in lv.items():
        i += 1; sid = f'D{i:02d}'
        s = dict(origin); s[a] = l
        specs.append(dict(spec_id=sid, type='deviation', settings=s))
        lab.append(dict(spec_id=sid, type='deviation', axis=a, level=l, label=label, basis=basis))
for c in ['hierarchy_log10', 'pct_proportion', 'industry_ref_alt']:
    specs.append(dict(spec_id='CHK_' + c, type='check', settings=dict(origin), check=c))
    lab.append(dict(spec_id='CHK_' + c, type='check', axis=None, level=None, label='algebraic_check', basis='exact re-expression (rules_v1)'))
json.dump(dict(grid_version='v1', compute_order=[s['spec_id'] for s in specs], specs=specs), open('reconciliation/grid_v1.json', 'w'), indent=1)
json.dump(dict(grid_version='v1', equivalent_substantive_levels=[], note='No substantive equivalent alternatives survived reconciliation; all executed alternatives are uncertain.', labels=lab), open('reconciliation/grid_v1_labels_coordinator.json', 'w'), indent=1)
print(len(specs), 'specs;', i, 'deviations')
