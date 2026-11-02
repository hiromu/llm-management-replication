"""Frozen design, deterministic sample construction and ID provenance."""
import hashlib
import itertools
import numpy as np
import pandas as pd
import pyarrow.parquet as pq

AXES = [f"U{i}" for i in range(1, 9)]
ORIGIN = dict.fromkeys(AXES, 0)
BASE = ["total_points", "yards_first_down", "yards_touchdown", "same_division",
        "same_conference", "home_field", "week", "minutes"]
PERF = ["perf_below", "perf_below_sq", "perf_above", "below_indicator"]
INTER = ["perf_below_x_min", "perf_below_sq_x_min", "perf_above_x_min"]
SEASONS = [f"season_{s}" for s in range(2001, 2006)]
PBP_COLUMNS = ["game_id", "play_id", "season", "season_type", "down", "play_type",
               "punt_attempt", "field_goal_attempt", "pass", "rush", "qtr",
               "game_seconds_remaining", "posteam", "defteam", "posteam_score",
               "defteam_score", "ydstogo", "yardline_100", "posteam_type", "week"]


def cells():
    yield 1, ORIGIN.copy(), ["M1", "M2", "M3"]
    for axis in AXES:
        for level in ([1, 2] if axis == "U7" else [1]):
            c = ORIGIN.copy()
            c[axis] = level
            yield 2, c, ["M1"] if axis == "U8" else ["M1", "M2", "M3"]
    for levels in itertools.product(*([[0, 1]]*6 + [[0, 1, 2]])):
        c = dict(zip(AXES[:7], levels)) | {"U8": 0}
        yield 3, c, ["M1", "M2", "M3"]


def spec_id(model, cell):
    return model + "|" + "|".join(f"{a}={cell[a]}" for a in AXES)


def terms(model, cell):
    out = BASE.copy() + ([] if cell["U7"] == 2 else SEASONS)
    if model in ("M2", "M3"):
        out += PERF
    elif cell["U8"]:
        out += ["below_indicator"]
    if model == "M3":
        out += INTER
    return out


def refresh_interactions(df):
    for p, i in zip(PERF[:3], INTER):
        df[i] = df[p] * df.minutes


def variables(df, cell):
    df = df.copy()
    df["d"] = df.posteam_score - df.defteam_score - 1
    df["perf_below"] = np.minimum(df.d, 0)
    df["perf_below_sq"] = df.perf_below**2
    df["perf_above"] = np.maximum(df.d, 0)
    df["below_indicator"] = np.where(df.d.isna(), np.nan, (df.d <= 0).astype(float))
    df["minutes"] = df.game_seconds_remaining / 60
    if cell["U4"]:
        df["minutes"] = np.floor(df.minutes)
    df["total_points"] = df.posteam_score
    df["yards_first_down"] = df.ydstogo
    df["yards_touchdown"] = df.yardline_100
    df["same_division"] = (df.off_division == df.def_division).astype(float)
    df["same_conference"] = (df.off_conference == df.def_conference).astype(float)
    if cell["U5"]:
        df["same_conference"] *= 1-df.same_division
    df["home_field"] = (df.posteam_type == "home").astype(float)
    if cell["U6"]:
        df.loc[df.location == "Neutral", "home_field"] = 0
    for season in range(2001, 2006):
        df[f"season_{season}"] = np.where(df.season.isna(), np.nan, (df.season == season).astype(float))
    refresh_interactions(df)
    return df


def id_hash(df):
    ids = df[["game_id", "play_id"]].copy()
    if ids.isna().any().any() or ids.duplicated().any():
        raise ValueError("Missing or duplicated game_id/play_id")
    if not np.equal(ids.play_id, np.floor(ids.play_id)).all():
        raise ValueError("Nonintegral play_id")
    ids["play_id"] = ids.play_id.astype("int64")
    # Canonical hash: UTF-8, lexicographically sorted game_id|integer lines,
    # LF after every line (including the last), no header in the hash.
    lines = ids.game_id.astype(str) + "|" + ids.play_id.astype(str)
    order = np.argsort(lines.to_numpy(), kind="stable")
    payload = "".join(line+"\n" for line in lines.iloc[order]).encode()
    return hashlib.sha256(payload).hexdigest(), ids.iloc[order]


class Samples:
    def __init__(self, root, results):
        self.results = results
        raw = pd.concat([pq.read_table(root / "data/pbp" / f"play_by_play_{s}.parquet",
                                      columns=PBP_COLUMNS).to_pandas()
                         for s in range(2000, 2006)], ignore_index=True)
        self.raw_rows = len(raw)
        self.reg = raw.loc[raw.season_type == "REG"].copy()
        self.fourth = self.reg.loc[self.reg.down == 4].copy()
        self.games = pq.read_table(root / "data/games/games.parquet",
                                   columns=["game_id", "location", "div_game"]).to_pandas()
        self.align = pd.read_csv(root / "data/alignment/team_season_alignment.csv")
        self.cache, self.written = {}, set()
        self.flows, self.index = [], []

    def prepare(self, cell):
        key = tuple(cell[a] for a in AXES[:3])
        if key not in self.cache:
            flow = [("S1", "Stack 2000-2005; keep REG", len(self.reg)),
                    ("S2", "Keep fourth downs", len(self.fourth))]
            df = self.fourth.copy()
            y = pd.Series(np.nan, index=df.index)
            y.loc[df.play_type.isin(["run", "pass"])] = 1
            y.loc[df.play_type.isin(["punt", "field_goal"])] = 0
            if cell["U1"]:
                no = df.play_type == "no_play"
                non = (df.punt_attempt == 1) | (df.field_goal_attempt == 1)
                att = (df["pass"] == 1) | (df.rush == 1)
                y.loc[no & non] = 0
                y.loc[no & ~non & att] = 1
            if cell["U2"]:
                y.loc[df.play_type.isin(["qb_kneel", "qb_spike"])] = 0
            df["y"] = y
            df = df.loc[df.y.notna()].copy()
            flow.append(("S3", "Eligible classified decision rows", len(df)))
            df = df.loc[df.qtr.isin([1, 2, 3, 4])].copy()
            flow.append(("S4", "Regulation", len(df)))
            keep = df.game_seconds_remaining.ge(120) if cell["U3"] else df.game_seconds_remaining.gt(120)
            df = df.loc[keep].copy()
            flow.append(("S5", "Seconds >=120" if cell["U3"] else "Seconds >120", len(df)))
            df = df.loc[df.posteam.notna() & df.defteam.notna() &
                        df.posteam.ne("") & df.defteam.ne("")].copy()
            flow.append(("S6", "Nonempty offense and defense", len(df)))
            df = df.merge(self.games, on="game_id", how="left", validate="many_to_one", indicator=True)
            if not df._merge.eq("both").all():
                raise ValueError("Unmatched games merge")
            df = df.drop(columns="_merge")
            for side, col in [("off", "posteam"), ("def", "defteam")]:
                a = self.align[["season", "team_abbr_pbp", "conference", "division"]].rename(
                    columns={"team_abbr_pbp": col, "conference": side+"_conference", "division": side+"_division"})
                df = df.merge(a, on=["season", col], how="left", validate="many_to_one", indicator=True)
                if not df._merge.eq("both").all():
                    raise ValueError("Unmatched " + side + " alignment merge")
                df = df.drop(columns="_merge")
            flow.append(("S7", "Validated games and both alignment merges", len(df)))
            self.cache[key] = df, flow
        raw, flow = self.cache[key]
        df = variables(raw, cell)
        masks = {m: np.isfinite(df[["y"] + terms(m, cell)].to_numpy(float)).all(axis=1)
                 & df.season.notna().to_numpy() for m in ["M1", "M2", "M3"]}
        common = np.logical_and.reduce(list(masks.values()))
        out = df.loc[common].sort_values(["game_id", "play_id"]).reset_index(drop=True)
        sha, ids = id_hash(out)
        if sha not in self.written:
            ids.to_csv(self.results / "samples" / (sha+".csv.gz"), index=False,
                       compression={"method": "gzip", "mtime": 0})
            self.written.add(sha)
        counts = {m: int(mask.sum()) for m, mask in masks.items()}
        disagree = int((out.same_division != out.div_game).sum())
        return out, sha, flow + [("S8", "Common M1/M2/M3 complete cases", len(out))], counts, len(df)-len(out), disagree

    def record(self, step, cell, models, prepared):
        df, sha, flow, counts, dropped, disagree = prepared
        key = spec_id("cell", cell)
        for s, desc, n in flow:
            self.flows.append(dict(cell_id=key, compute_step=step, **cell, sample_hash=sha,
                                   step=s, description=desc, rows=n,
                                   dropped=(dropped if s == "S8" else None),
                                   m1_complete_rows=counts["M1"] if s == "S8" else None,
                                   m2_complete_rows=counts["M2"] if s == "S8" else None,
                                   m3_complete_rows=counts["M3"] if s == "S8" else None,
                                   model_specific_differs=any(v != len(df) for v in counts.values()) if s == "S8" else None,
                                   division_disagreements=disagree if s == "S8" else None))
        for m in models:
            self.index.append(dict(spec_id=spec_id(m, cell), step=step, model=m, **cell,
                                   sample_hash=sha, n_obs=len(df),
                                   model_specific_complete_rows=counts[m],
                                   common_dropped=dropped, division_disagreements=disagree))

    def save(self):
        pd.DataFrame(self.flows).to_csv(self.results / "sample_flow.csv", index=False)
        pd.DataFrame(self.index).to_csv(self.results / "sample_index.csv", index=False)


def design(df, model, cell, random=False, influence=False):
    names = terms(model, cell)
    # Season deletion leaves a structural alias: express the same factor space
    # using the earliest retained season as reference, and no absent levels.
    if influence and cell["U7"] != 2:
        present = sorted(df.season.unique())
        names = [n for n in names if not n.startswith("season_")]
        names += [f"season_{int(s)}" for s in present[1:]]
    X = df[names].to_numpy(float)
    if cell["U7"] == 1 or random:
        X = np.column_stack((np.ones(len(df)), X))
        names = ["intercept"] + names
        if not random:
            teams = sorted(df.posteam.unique())
            dummies = np.column_stack([(df.posteam == t).to_numpy(float) for t in teams[1:]])
            X = np.column_stack((X, dummies))
            names += ["team_"+t for t in teams[1:]]
    groups = (df.posteam.astype(str)+"|"+df.season.astype(int).astype(str)).to_numpy() if cell["U7"] == 2 else df.posteam.to_numpy()
    return X, df.y.to_numpy(float), groups, names
