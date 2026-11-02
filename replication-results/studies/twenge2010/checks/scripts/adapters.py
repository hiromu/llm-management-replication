"""Normalize the three implementations' result JSON files into flat records (no scoring, no targets).

normalize(impl, spec_json) -> dict mapping key tuples to float/int/str values.
Keys:
  ('rows', file_key)                     rows read
  ('item', V, year, field)               field in n, mean, sd, pct
  ('itest', V, pair, field)              field in diff, t, df, p, welch_t, welch_df, welch_p, z, zp (weighted)
  ('lat', K, year, field)                field in mean, se, psi, sd
  ('con', K, pair, field)                field in Delta, se, z, p, d_eq, d_df, g, d_glass, d_obs
  ('fit', model, group, field)           model in form3, form4_7, form4_5 (group = year) or M1..M5 (group = 'MG'); field in chisq, df, rmsea, cfi, tli, srmr
  ('mdiff', name, field)                 name in M2-M1, M3-M2, M4-M2, M5-M4; field in dchisq, ddf, p, dcfi
  ('alpha', scale, year)
  ('mgn', year), ('mghash', year)        multigroup analysis n and V4 hash
"""
import re

YEARS = ("1976", "1991", "2006")


def g(d, *path, default=None):
    for p in path:
        if isinstance(d, dict) and p in d:
            d = d[p]
        else:
            return default
    return d


def first(d, *paths):
    for p in paths:
        v = g(d, *p)
        if v is not None:
            return v
    return None


def norm_fit(f):
    return {"chisq": first(f, ("chisq",), ("chi_square",)), "df": f.get("df"), "rmsea": first(f, ("rmsea",), ("RMSEA",)),
            "cfi": first(f, ("cfi",), ("CFI",)), "tli": first(f, ("tli",), ("TLI",)), "srmr": first(f, ("srmr",), ("SRMR",))}


def normalize(impl, d):
    out = {}
    rows = first(d, ("rows_read",), ("rows_read_per_file",)) or {}
    for k, v in rows.items():
        out[("rows", k)] = v
    # ---- item statistics
    if impl == "A":
        st = g(d, "item_statistics", "statistics") or {}
        for form in st.values():
            for V, rec in form.items():
                for y, s in (rec.get("by_year") or {}).items():
                    out[("item", V, y, "n")] = s.get("n"); out[("item", V, y, "mean")] = s.get("mean")
                    out[("item", V, y, "sd")] = s.get("sd"); out[("item", V, y, "pct")] = s.get("pct_top")
                for P, c in (rec.get("pairs") or {}).items():
                    out[("itest", V, P, "diff")] = c.get("mean_diff")
                    for a, b in (("t", "student_t"), ("df", "student_df"), ("p", "student_p"), ("welch_t", "welch_t"), ("welch_df", "welch_df"), ("welch_p", "welch_p"), ("z", "z"), ("zp", "z_p"), ("zp", "p")):
                        if c.get(b) is not None:
                            out[("itest", V, P, a)] = c.get(b)
    else:
        st = g(d, "item_statistics") or {}
        byy = first(st, ("by_year",), ("by_item_year",)) or {}
        for V, rec in byy.items():
            for y, s in rec.items():
                out[("item", V, y, "n")] = s.get("n"); out[("item", V, y, "mean")] = s.get("mean")
                out[("item", V, y, "sd")] = first(s, ("SD",), ("sd",)); out[("item", V, y, "pct")] = first(s, ("percentage_top",), ("pct_top",))
        for V, rec in (st.get("comparisons") or {}).items():
            for P, c in rec.items():
                out[("itest", V, P, "diff")] = c.get("mean_difference")
                stu, wel = c.get("Student") or {}, c.get("Welch") or {}
                out[("itest", V, P, "t")] = stu.get("t"); out[("itest", V, P, "df")] = stu.get("df"); out[("itest", V, P, "p")] = stu.get("p")
                out[("itest", V, P, "welch_t")] = wel.get("t"); out[("itest", V, P, "welch_df")] = wel.get("df"); out[("itest", V, P, "welch_p")] = wel.get("p")
                wz = first(c, ("weighted_z",), ("approximate_z",), ("Weighted",), ("weighted",))
                if isinstance(wz, dict):
                    out[("itest", V, P, "z")] = first(wz, ("z",)); out[("itest", V, P, "zp")] = first(wz, ("p",))
    # ---- latent means and contrasts
    if impl == "A":
        lat = g(d, "multigroup", "latent", "by_group") or {}
        con = g(d, "multigroup", "contrasts", "contrasts") or {}
        dl = g(d, "multigroup", "latent", "deltas") or {}
        for K, yy in lat.items():
            for y, s in yy.items():
                out[("lat", K, y, "mean")] = s.get("alpha"); out[("lat", K, y, "se")] = s.get("se"); out[("lat", K, y, "psi")] = s.get("psi"); out[("lat", K, y, "sd")] = s.get("sd")
        for K, pp in dl.items():
            for P, c in pp.items():
                out[("con", K, P, "Delta")] = c.get("delta"); out[("con", K, P, "se")] = c.get("se"); out[("con", K, P, "z")] = c.get("z"); out[("con", K, P, "p")] = c.get("pvalue")
        for K, pp in con.items():
            for P, c in pp.items():
                for f in ("d_eq", "d_df", "g", "d_glass", "d_obs"):
                    out[("con", K, P, f)] = c.get(f)
    else:
        L = d.get("latent") if impl == "B" else d.get("latent_M4")
        L = L or {}
        for K, yy in (L.get("means") or {}).items():
            for y, s in yy.items():
                out[("lat", K, y, "mean")] = s.get("alpha"); out[("lat", K, y, "se")] = s.get("SE")
                out[("lat", K, y, "psi")] = first(s, ("psi",), ("variance",)); out[("lat", K, y, "sd")] = s.get("SD")
        for K, pp in (L.get("contrasts") or {}).items():
            for P, c in pp.items():
                out[("con", K, P, "Delta")] = c.get("Delta"); out[("con", K, P, "se")] = c.get("SE"); out[("con", K, P, "z")] = c.get("z"); out[("con", K, P, "p")] = c.get("p")
                for f in ("d_eq", "d_df", "g", "d_glass", "d_obs"):
                    out[("con", K, P, f)] = c.get(f)
    # ---- fits
    sg = d.get("single_group") or {}
    names = {"form3": ("form3_C1C2", "form3", "Form3_C1_C2", "form3_one_factor", "Form3_one_factor", "form3_S08"),
             "form4_7": ("form4_seven_factor", "form4_seven", "Form4_seven_factor"),
             "form4_5": ("form4_five_factor", "form4_five", "Form4_five_factor")}
    for m, cands in names.items():
        node = None
        for c in cands:
            if c in sg:
                node = sg[c]; break
        if node is None and len(sg) == 1 and m == "form3":
            node = list(sg.values())[0]
        if node is None:
            continue
        node = node.get("by_year", node)
        for y in YEARS:
            s = node.get(y)
            if not isinstance(s, dict):
                continue
            f = s.get("fit", s)
            for k, v in norm_fit(f).items():
                out[("fit", m, y, k)] = v
    mg = d.get("multigroup") or {}
    models = mg.get("models", mg)
    for M in ("M1", "M2", "M3", "M4", "M5"):
        s = models.get(M) if isinstance(models, dict) else None
        if not isinstance(s, dict):
            continue
        f = s.get("fit", s)
        for k, v in norm_fit(f).items():
            out[("fit", M, "MG", k)] = v
    # multigroup n / hash
    samp = first(mg, ("samples",), ("M4", "samples"), ("models", "M4", "samples"))
    if isinstance(samp, dict):
        for y, s in samp.items():
            out[("mgn", y)] = s.get("n"); out[("mghash", y)] = first(s, ("sha256_V4",), ("V4_sha256",))
    elif isinstance(samp, list):
        for s in samp:
            out[("mgn", str(s.get("year")))] = s.get("n"); out[("mghash", str(s.get("year")))] = s.get("V4_sha256")
    md = first(d, ("model_differences",), ("multigroup", "differences")) or {}
    for name, c in md.items():
        nm = name.replace(" ", "")
        if c is None:
            continue
        out[("mdiff", nm, "dchisq")] = first(c, ("chi_square_difference",), ("chisq_diff",))
        out[("mdiff", nm, "ddf")] = first(c, ("df_difference",), ("df_diff",))
        out[("mdiff", nm, "p")] = first(c, ("p",), ("pvalue",))
        out[("mdiff", nm, "dcfi")] = first(c, ("CFI_difference",), ("cfi_diff",))
    al = first(d, ("coefficient_alpha", "alpha"), ("alpha",)) or {}
    for sc, yy in al.items():
        if not isinstance(yy, dict):
            continue
        for y in YEARS:
            s = yy.get(y)
            if isinstance(s, dict):
                out[("alpha", sc, y)] = s.get("alpha")
    return {k: v for k, v in out.items() if v is not None}
