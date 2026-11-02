# Implementation assignment

Write one analysis script in LANGUAGE that meets every item in ./input/manifest.md.

Inputs in ./input: manifest.md, the dictionaries dictionary_1.csv to dictionary_4.csv, and synthetic/ holding synthetic dataset_1.csv to dataset_4.csv. The synthetic files are made up. Their numbers mean nothing and you should not reason about them beyond checking that your code runs and gives sensible output.

Run your script against the synthetic files with --boot 200 to test it, writing to ./synthetic_out. A run with --boot 5000 will be done later by someone else on other files.

Rules:
- Use LANGUAGE_NOTES.
- Do not browse or use the network. Do not look outside this directory. Do not ask for anything else. There is no target to match and no other input.
- If an item cannot be met, record it as status failed in the output with a reason, and list it in ./output/unmet.md.
- The final script goes in ./output/SCRIPTNAME. Keep it to that single file. Also write ./output/notes.md listing any decisions the manifest left open and how you resolved them.

Before finishing, run the script once on the synthetic files and confirm that results.csv, influence.csv, samples.csv and session_info.txt are written and that every key family in the manifest appears. Then print only the word DONE.
