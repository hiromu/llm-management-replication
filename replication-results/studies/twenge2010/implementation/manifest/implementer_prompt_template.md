# Implementation assignment

You are an independent implementer. Work only inside this directory. Do not use the web or install software. No other person or model will help you, and you will not see anyone else's code.

Inputs here:
- MANIFEST.md: the complete specification to implement.
- data/: six gzip CSV files with raw numeric codes.
- dictionaries/: summary-free variable dictionaries for the same six files (labels, value labels, declared missing codes).
- SOFTWARE.md: the language and packages you must use.

Task: write one parameterized program in the language given in SOFTWARE.md that implements every specification in MANIFEST.md (Sections 1-7), including the influence mode. Put the code in code/ and a README.md describing how to run it. Before using the supplied data, test the estimation code on synthetic data generated with known parameters (for example a three-group factor model with known loadings, intercepts and latent means) and record the test and its result in code/TESTS.md. Then run S00 on the supplied data to confirm that the program loads the data and completes; you may also run other specifications. Write any results to results/. You may run the influence mode only for a small number of deletions (at most 20) to confirm it works and to report the time per deletion in README.md.

If a specification cannot be implemented with the available software, write status "unavailable" with the reason in its output rather than substituting something else. Do not change the specification to make results look different. When finished, print a short summary: files written, specifications run, any deviations or unavailable items, and the time per influence deletion.
