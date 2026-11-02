# Implementer A: residual unmet items after the three-round checker budget

The frozen role record allows up to 3 checker/repair rounds. After round 3 (implementation/A/r3), the checker (gpt-6-astra) listed the four items in checks/A/r3/out/unmet.md. They were not repaired, and A r3 was executed as is. The coordinator's assessment of their effect, written before execution:

1. S7 merge errors are caught and execution continues instead of stopping. Effect: none expected. All merges matched in the sample stage of A, B and C, which produced identical sample hashes.
2. The U9a counterpart is fitted on all rows rather than on rows retained by the conditional fit. Effect: differs only if a group has an invariant outcome. U9a is computed only for the origin and individual-deviation cells, and team groups have hundreds of plays each.
3. The U7=1 counterparts for N2 have no benchmark (game-clustered) output. Effect: the N2 benchmark is unavailable from A. N2 is a non-equivalent robustness run and is not scored.
4. Influence-deletion samples are not hashed or saved. Effect: sample-ID provenance for the deletions is not recorded by A. Each deletion sample is deterministic (the origin sample minus one unit), and C records them.

None of the items affects origin estimates, grid estimates or the scored targets. They are disclosed as limitations.
