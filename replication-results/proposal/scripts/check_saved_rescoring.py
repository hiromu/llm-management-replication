"""Re-run only the post hoc scorer in a temporary copy and compare all outputs."""
from pathlib import Path
import tempfile,shutil,subprocess,json,sys
ROOT=Path(__file__).resolve().parents[1]
# Artifact root: the sibling folder in the proposal workspace, or the repository root when this
# folder sits at <repo>/proposal/.
base=(ROOT/'orgsci-proposal-supplement' if (ROOT/'orgsci-proposal-supplement').is_dir() else ROOT.parent)/'studies'
files={'lehman2011':'runs/score_v1/target_comparisons_all_cells.csv','holderness2012':'scoring/claim_scores.csv','deephouse1999':'scoring/run_v1/term_scores.csv','thebaud2015':'reports/exports/term_comparisons.csv','twenge2010':'reports/claim_comparisons.csv','delaney1996':'reports/data/claim_cell_comparisons.csv'}
with tempfile.TemporaryDirectory(prefix='os-rescore-') as td:
 t=Path(td)
 needed=['score_common.py','scoring_rules_common_v1.json']+[s+'/'+p for s,p in files.items()]+['thebaud2015/reports/exports/claim_comparisons.csv']
 for p in needed:
  (t/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(base/p,t/p)
 for s in files:(t/s/'reports').mkdir(exist_ok=True)
 r=subprocess.run([sys.executable,str(t/'score_common.py')],capture_output=True,text=True)
 if r.returncode:raise RuntimeError(r.stderr)
 diffs=[];checked=0
 for s in files:
  for p in ['scoring/common_v1/terms.csv','scoring/common_v1/claims.csv','scoring/common_v1/paper_record.json','reports/common_rule_v1.md']:
   checked+=1
   if (t/s/p).read_bytes()!=(base/s/p).read_bytes():diffs.append(s+'/'+p)
 for p in ['common_v1_summary.csv','common_v1_summary.md']:
  checked+=1
  if (t/p).read_bytes()!=(base/p).read_bytes():diffs.append(p)
 result={'common_rescoring_files_checked':checked,'byte_differences':diffs,'empirical_models_refitted':False,'historical_outputs_modified':False}
 (ROOT/'supplement_assets/generated/rescoring_check.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
 if diffs:sys.exit(1)
