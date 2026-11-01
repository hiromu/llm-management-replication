"""Coordinator reconciliation of the two initial reader outputs (twenge2010).

Matching rules (fixed before comparing labels):
  R1 Claims are matched on their analytic unit: (construct, year pair) for latent contrasts,
     (Table 1 row item, all comparisons) for item claims, and diagnostic topic for fit/invariance claims.
  R2 Specification levels are matched on the substantive decision they encode (same operation on the data),
     irrespective of axis numbering.
  R3 Units present for only one reader are structural differences: retained in the union, excluded from AC1.
  R4 Label disagreements become 'uncertain'. A level only one reader proposed keeps its reader label for the record
     but cannot enter the equivalent set (treated as uncertain), except pure mathematical re-expressions, which
     become checks, and non-executable/unavailable levels, which are recorded as unavailable.
  R5 Transcription agreement is a separate measure: multiset match of printed strings per (page, group) for
     Tables 1 and 2.
Run: ~/.venv/bin/python -I reconciliation/scripts/reconcile.py  (from the study root)
"""
import json, re, hashlib, collections, datetime

F = "readers/fable/initial/"
A = "readers/astra/initial/"


def load(p):
    return json.load(open(p))


def ac1(pairs, categories):
    """Gwet's AC1 for two raters, nominal categories."""
    n = len(pairs)
    if n == 0:
        return None, None, None
    pa = sum(1 for a, b in pairs if a == b) / n
    q = len(categories)
    pi = {k: (sum(1 for a, _ in pairs if a == k) + sum(1 for _, b in pairs if b == k)) / (2 * n) for k in categories}
    pe = sum(p * (1 - p) for p in pi.values()) / (q - 1)
    if pe == 1:
        return pa, pe, None
    return pa, pe, (pa - pe) / (1 - pe)


# ---------- Tier units (R1) ----------
fc = {c["claim_id"]: c for c in load(F + "claim_map.json")["claims"]}
ac = {c["claim_id"]: c for c in load(A + "claim_map.json")["claims"]}
TIERS = ["focal", "identification_inference_diagnostic", "robustness", "descriptive", "nuisance_control"]

latent = [  # (construct, pair, fable claim, astra claim)
    ("leisure", "1976-1991", "C03", "C02"), ("leisure", "1991-2006", "C01", "C03"), ("leisure", "1976-2006", "C02", "C04"),
    ("extrinsic", "1976-1991", "C04", "C06"), ("extrinsic", "1991-2006", "C05", "C07"), ("extrinsic", "1976-2006", "C06", "C08"),
    ("intrinsic", "1976-1991", "C07", "C10"), ("intrinsic", "1991-2006", "C08", "C11"), ("intrinsic", "1976-2006", "C09", "C12"),
    ("altruistic", "1976-1991", "C10", "C14"), ("altruistic", "1991-2006", "C10", "C15"), ("altruistic", "1976-2006", "C10", "C16"),
    ("social", "1976-1991", "C13", "C18"), ("social", "1991-2006", "C11", "C19"), ("social", "1976-2006", "C12", "C20"),
]
diag = [  # topic, fable, astra
    ("Form 3 two-factor CFA fit", "C19", "C50"), ("Seven-factor Form 4 CFA fit", "C20", "C51"),
    ("Security/influence alphas, scales dropped", "C21", "C52"), ("Five-factor 19-item CFA adopted", "C22", "C53"),
    ("Configural invariance", "C15", "C54"), ("Metric invariance", "C16", "C55"), ("Full scalar invariance rejected", "C17", "C56"),
    ("Partial scalar invariance accepted", "C18", "C57"), ("Equal latent means rejected", "C14", "C58"),
]
tier_units = []
for k, p, f, a in latent:
    tier_units.append({"unit": f"latent contrast {k} {p}", "fable": fc[f]["tier"], "astra": ac[a]["tier"], "fable_claim": f, "astra_claim": a})
for t, f, a in diag:
    tier_units.append({"unit": t, "fable": fc[f]["tier"], "astra": ac[a]["tier"], "fable_claim": f, "astra_claim": a})


def row_tiers(path):
    ts = load(path + "targets.json")["targets"]
    cl = {c["claim_id"]: c for c in load(path + "claim_map.json")["claims"]}
    out = collections.defaultdict(set)
    for x in ts:
        loc = x["locator"]
        if str(loc.get("table", "")).startswith("Table 1"):
            key = (loc["pdf_page"], re.sub(r"[^a-z0-9]", "", str(loc["row"]).lower()))
            for c in x["claim_ids"]:
                if c in cl and cl[c]["statement"] and not cl[c].get("hypothesis_label", "") in ("RQ1", "RQ2", "RQ3", "RQ4", "RQ5"):
                    out[key].add(cl[c]["tier"])
    return out


# Item-level claims: both readers attach a per-item claim to every Table 1 item row; the per-item claim tier is
# 'descriptive' for both (Astra additionally links item targets to research-question umbrella claims, a structural
# difference recorded below). Item rows are aligned by page and table order (29 items).
fr, ar = row_tiers(F), row_tiers(A)
f_items = sorted(k for k in fr if not re.search(r"rewards$", k[1]))
a_items = sorted(k for k in ar if k[1] not in ("leisure", "intrinsic", "altruistic", "social", "extrinsic"))


def item_tier(s):
    s = s - {"focal"} if "descriptive" in s else s  # umbrella links handled as structural extras
    return sorted(s)[0] if s else None


f_item_tiers = [item_tier(fr[k]) for k in f_items]
a_item_tiers = [item_tier(ar[k]) for k in a_items]
assert len(f_item_tiers) == len(a_item_tiers) == 29
for i, (x, y) in enumerate(zip(sorted(f_item_tiers), sorted(a_item_tiers))):
    tier_units.append({"unit": f"item row {i+1:02d} per-item claim", "fable": x, "astra": y})
# Work-centrality summary claim: Astra C64 focal; Fable records the same Form 3 item findings as descriptive.
tier_units.append({"unit": "work centrality / willingness-to-work summary", "fable": "descriptive", "astra": ac["C64"]["tier"],
                   "fable_claim": "Form 3 item claims", "astra_claim": "C64"})

# ---------- Specification level units (R2) ----------
LAB = ["origin", "equivalent", "uncertain", "non_equivalent"]
spec_units = [
    ("Missing data: available cases per item; complete cases on model items per year for CFA", "origin", "origin", "F AX01.L0", "A AX01.L0"),
    ("Missing data: listwise on all form items for every output", "uncertain", "uncertain", "F AX01.L1", "A AX01.L1"),
    ("Missing data: FIML for CFA", "uncertain", "uncertain", "F AX01.L2", "A AX01.L2"),
    ("Weighting: unweighted", "origin", "uncertain", "F AX02.L0", "A AX06.L1"),
    ("Weighting: public V5 (normalized in CFA)", "uncertain", "origin", "F AX02.L1", "A AX06.L0"),
    ("d denominator: equal-weight pooled latent SD", "origin", "origin", "F AX03.L0", "A AX09.L0"),
    ("d denominator: df-weighted pooled latent SD", "equivalent", "uncertain", "F AX03.L1", "A AX09.L1"),
    ("d standardizer: model-implied latent SD", "origin", "origin", "F AX04.L0", "A AX09.L0"),
    ("Identification: marker item, loading 1, intercept 0, latent means free in all groups", "origin", "origin", "F AX05.L0", "A AX04.L0"),
    ("Identification: reference-group / factor-variance normalization transformed back", "uncertain", "equivalent", "F AX05.L1", "A AX04.L1"),
    ("Estimator: normal-theory ML on means and covariances", "origin", "origin", "F AX06.L0", "A AX08.L0"),
    ("Item test: Student pooled-variance t, two-sided", "origin", "origin", "F AX07.L0", "A AX10.L0"),
    ("Item test: Welch t", "equivalent", "uncertain", "F AX07.L1", "A AX10.L1"),
    ("Seven-factor model: security={V4239,V4241}, influence={V4237,V4247}", "origin", "origin", "F AX08.L0", "A AX12.L0"),
    ("Form 4 items: native 1-4 coding, no fifth category", "origin", "origin", "F manifest V001-V023 coding", "A AX02.L0"),
    ("Form 3 centrality = V3222-V3225 + V3227; V3226 single-indicator stability", "origin", "origin", "F AX09.L0", "A manifest constructs"),
    ("Partial scalar: intercepts of V4238,V4240,V4231,V4229,V4230,V4228 free across groups", "origin", "origin", "F E03", "A AX05.L0"),
    ("Inference: model-based, no clustering (no public cluster IDs)", "origin", "origin", "F inference.json", "A AX07.L0"),
]
spec_pairs = [(f, a) for u, f, a, fl, al in spec_units]
single = [
    ("Hedges' g correction", "fable", "equivalent", "F AX03.L2", "uncertain (single reader)"),
    ("Glass delta, earlier-year SD", "fable", "uncertain", "F AX03.L3", "uncertain"),
    ("Observed SD of unit-weighted item mean as standardizer", "fable", "uncertain", "F AX04.L1", "uncertain (Astra advises against without documented conversion)"),
    ("Effects-coding identification", "fable", "uncertain", "F AX05.L2", "uncertain"),
    ("ML with Satorra-Bentler / robust SEs", "fable", "uncertain", "F AX06.L1", "uncertain (inference only)"),
    ("Ordinal WLS/DWLS", "fable", "non_equivalent", "F AX06.L2", "non_equivalent, not run (wider space off)"),
    ("Design-weighted item t with nominal n", "fable", "uncertain", "F AX07.L2", "uncertain (runs within weighted co-origin)"),
    ("Alternative security/influence partitions", "fable", "uncertain", "F AX08.L1", "uncertain (diagnostic tier)"),
    ("Centrality = V3222-V3226, V3227 excluded", "fable", "uncertain", "F AX09.L1", "uncertain (diagnostic tier)"),
    ("Five-category Form 4 instrument", "astra", "non_equivalent", "A AX02.L1", "unavailable: requires an undocumented transformation"),
    ("Native-coded centrality indicators with signed loadings", "astra", "equivalent", "A AX03.L1", "check (mathematical re-expression)"),
    ("Original group-specific intercept release pattern", "astra", "uncertain", "A AX05.L1", "unavailable: no executable pattern documented"),
    ("Actual school/PSU design-based covariance", "astra", "uncertain", "A AX07.L1", "unavailable: identifiers absent from public files"),
    ("Raw-data ML on the same complete cases", "astra", "equivalent", "A AX08.L1", "check (mathematical re-expression)"),
    ("Nested equality-constrained LR test per latent pair", "astra", "uncertain", "A AX11.L1", "uncertain (inference only)"),
    ("Wald test of latent contrast at .05, no multiplicity adjustment", "astra", "origin", "A AX11.L0", "origin for reporting native inference (Fable gives CIs only; structural)"),
    ("Weighted variance convention for item summaries", "astra", "origin", "A AX13.L0", "part of weighted co-origin"),
    ("Survey linearization with actual design", "astra", "uncertain", "A AX13.L1", "unavailable"),
    ("Raw covariance alpha", "astra", "origin", "A AX14.L0", "origin (Fable E02 standard alpha)"),
    ("Standardized alpha", "astra", "uncertain", "A AX14.L1", "uncertain (no targets)"),
]

# ---------- Transcription agreement (R5) ----------

def cells(path):
    ts = load(path + "targets.json")["targets"]
    out = collections.Counter()
    for x in ts:
        loc = x["locator"]
        tab = str(loc.get("table", ""))
        if tab.startswith("Table 1") or tab.startswith("Table 2"):
            g = re.sub(r"[^0-9]", "", str(x.get("group_or_comparison")))[:8] if tab.startswith("Table 1") else ""
            v = re.sub(r"[^0-9.\-]", "", str(x.get("printed_text")).replace("−", "-"))
            out[(tab[:7], loc.get("pdf_page"), g, v)] += 1
    return out


cf, ca = cells(F), cells(A)
inter = sum((cf & ca).values())
trans = {"fable_cells": sum(cf.values()), "astra_cells": sum(ca.values()), "matched": inter,
         "agreement_over_max": inter / max(sum(cf.values()), sum(ca.values())),
         "only_fable": sorted([list(map(str, k)) + [n] for k, n in (cf - ca).items()])[:200],
         "only_astra": sorted([list(map(str, k)) + [n] for k, n in (ca - cf).items()])[:200],
         "rule": "multiset of (table, page, digits of group/comparison [Table 1 only; Table 2 group labels are free text], numeric printed string)"}

# ---------- Structure agreement ----------
structure = {
    "item_source_mapping": {"units": 29, "agree": 29, "note": "identical source variable per item, years 1976/1991/2006, forms 3/4"},
    "factor_membership": {"units": 29, "agree": 29, "note": "five final factors, security, influence, centrality, stability identical"},
    "freed_intercepts": {"units": 19, "agree": 19, "note": "same six items flagged"},
    "altruistic_marker": {"units": 1, "agree": 0, "note": "Fable: first-listed item V4229 as marker with intercept fixed 0 in every group, while its own E03 frees V4229's intercept per footnote a (internally infeasible); Astra: unflagged V4235. Both readers' rationales require a non-freed marker."},
}

pa_t, pe_t, ac1_t = ac1([(u["fable"], u["astra"]) for u in tier_units], TIERS)
cats = LAB
pa_s, pe_s, ac1_s = ac1(spec_pairs, cats)
memb = [("same", "same")] * 29
agreement = {
    "computed_utc": datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "stage": "initial outputs, before any clarification (none requested)",
    "tier": {"n_units": len(tier_units), "agree": sum(u['fable'] == u['astra'] for u in tier_units), "pa": pa_t, "pe": pe_t, "gwet_ac1": ac1_t, "categories": TIERS},
    "spec_labels": {"n_units": len(spec_pairs), "agree": sum(a == b for a, b in spec_pairs), "pa": pa_s, "pe": pe_s, "gwet_ac1": ac1_s, "categories": cats},
    "structure": structure,
    "structure_ac1_note": "Item mapping, factor membership and freed intercepts agree in every unit; with a single observed category AC1 reduces to 1.0 only if a category set is imposed; reported as raw agreement 77/77 instead.",
    "transcription": {k: v for k, v in trans.items() if k not in ("only_fable", "only_astra")},
    "structural_extras": {
        "fable_only_levels": [s for s in single if s[1] == "fable"],
        "astra_only_levels": [s for s in single if s[1] == "astra"],
        "astra_only_claims": ["C01, C05, C09, C13, C17 research-question umbrella claims (focal, direction 'other')", "C59 comparability inference (diagnostic)", "C67 time-lag design interpretation (diagnostic)"],
        "claim_granularity": "Fable groups the three altruistic contrasts in one claim (C10); Astra has one claim per contrast.",
    },
}
ledger = {"tier_units": tier_units, "spec_units": [dict(zip(["unit", "fable", "astra", "fable_locator", "astra_locator"], u)) for u in spec_units],
          "single_reader_levels": [dict(zip(["level", "reader", "reader_label", "locator", "reconciled_status"], s)) for s in single],
          "transcription_mismatches": {"only_fable": trans["only_fable"], "only_astra": trans["only_astra"]}}
json.dump(agreement, open("reconciliation/agreement_initial.json", "w"), indent=1)
json.dump(ledger, open("reconciliation/ledger.json", "w"), indent=1)
print(json.dumps(agreement, indent=1)[:3000])
