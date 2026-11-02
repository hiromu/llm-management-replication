# Rejected: model substitution

The v1.2 repair run for implementer C was launched with `claude -p --model claude-fable-5-1 --effort high ...` (staging dir recorded in logs/staging_dirs_repair_v1_1.txt, repairC_v1_2).

The CLI's run record (run/*_run.json, modelUsage) shows the work was done by `claude-opus-4-8`: 53,037 output tokens, $5.47. There was also a small `claude-opus-5` call: 100 output tokens. No `claude-fable-5-1` usage appears, and the CLI returned no error. This contradicts the frozen implementer design (C = claude-fable-5-1).

The code is preserved here unchanged and is not used for execution. The independent recheck of this code (checks/precheck, checkC_v1_2) returned "No unmet items"; it is preserved for the record only.

Action: rerun the v1.2 repair with claude-fable-5-1 and verify modelUsage before accepting the code.
