import sys, pyreadstat, pandas as pd, numpy as np
cols=["GEM_YR","COUNTRY","CTRYALP","GEMSEX","GEMAGE","GEMEDUC","GEMWORK","OWNMGE","WEIGHT","OMNOWJOB"]
df, meta = pyreadstat.read_sav(sys.argv[1], usecols=cols)
rows=[]
for v in cols:
    x=df[v]
    if x.dtype==object:
        # haven reads empty strings as "" (non-missing); pyreadstat may too
        s=x.iloc[::9973].fillna("").str.cat(); h=sum(map(ord,s))
        rows.append((v,int(x.notna().sum()),str(h)))
    else:
        rows.append((v,int(x.notna().sum()),"%.6f"%float(np.nansum(x.astype(float)))))
pd.DataFrame(rows,columns=["var","n_nonmiss","sum_or_hash"]).to_csv(sys.argv[2],index=False)
print("pyreadstat", pyreadstat.__version__, "pandas", pd.__version__, "rows", meta.number_rows, "cols_total", meta.number_columns)
