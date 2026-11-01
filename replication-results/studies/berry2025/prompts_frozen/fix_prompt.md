# Repair assignment

./input/code/ holds an analysis script. ./input/manifest.md is its specification. ./input/unmet.md is a list of items a checker says are unmet. ./input/synthetic/ holds synthetic test data whose numbers mean nothing.

Fix the script so it meets the manifest. Where a listed item is wrong, leave the code alone and say so in ./output/responses.md. Test with --boot 200 on the synthetic data, writing to ./synthetic_out. Use LANGUAGE_NOTES. Do not browse or look outside this directory. Write the full final script to ./output/SCRIPTNAME and responses to every listed item in ./output/responses.md. Then print only the word DONE.
