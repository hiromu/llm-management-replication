# Implementation assignment

You are an independent programmer. Implement the analyses in `input/implementation_manifest_v1.md` in Python. Other programmers implement the same manifest separately; you cannot see their work and they cannot see yours.

## Inputs (in ./input)
- `implementation_manifest_v1.md`: what to compute. It is complete and fixed; follow it literally.
- `grid_v1.csv`: every specification to run, one per row. Blank cells mean the parameter does not apply.
- `data_registry_impl_v1.json`: file formats and columns.
- `data/`: synthetic development data in the real formats. The real data will be run later by someone else with your frozen script.

## Software
Python 3.13.16, run with <home>/.venv/bin/python, with numpy 2.4.2, pandas 2.3.3, scipy 1.17.1, statsmodels 0.14.6, linearmodels 7.0, pyfixest 0.60.0, pyreadstat 1.3.7 and openpyxl 3.1.5.
No other packages are available, and nothing can be installed. Do not use the network or browse for documentation.

## Deliverables (in ./output)
1. `run_analysis.py`: a single script, run as `<home>/.venv/bin/python run_analysis.py <data_dir> <output_dir>` for the full grid and `<home>/.venv/bin/python run_analysis.py <data_dir> <output_dir> --influence <spec_id>` for influence mode.
2. Run it on `input/data` into `output/synthetic_run/` and make sure it finishes and writes every output file the manifest lists. Running the whole grid on the synthetic data should take under 30 minutes. If it does not, make it faster without changing what it computes.
3. Run influence mode once on the synthetic data for spec S00008 into `output/synthetic_influence/`.
4. `output/impl_notes.md`: any manifest item you could not implement or found ambiguous, and how your code handles it. Be brief and specific.

## Rules
- Work only inside this directory.
- Do not tune anything to the synthetic values; they are random.
- Do not drop or alter grid rows. A row that fails is recorded with its error and the run continues.
- Read the data exactly as the registry describes, including the irregular lines it mentions.
- When finished, print only the word DONE.
