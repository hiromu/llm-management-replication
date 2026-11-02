# Revision assignment

This folder contains a frozen analysis specification (manifest.md, grid.json), data, software notes (SOFTWARE.md), an existing implementation in code/ (run.R, tests/, NOTES.md) and CHECK.md, a list of items that an independent code check found unmet relative to the manifest.

For every item in CHECK.md either (a) change the code so the manifest requirement is met, or (b) if you conclude the item is not actually required by the manifest or has no effect, explain why in a new section of code/NOTES.md titled "Check round 1 responses", citing the manifest line. Do not change anything else; do not add analyses. Keep the same invocation.

Then rerun your synthetic tests (update them if a fix needs a new test) and save the log. On the real data you may again run sample/variable construction and at most spec S000 family T4 to confirm the script runs. Do not use the internet and do not install packages. Write all edits inside code/.
