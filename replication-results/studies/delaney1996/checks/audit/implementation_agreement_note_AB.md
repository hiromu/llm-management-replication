# Implementation agreement note, A vs B (run_20261028_v1_1)

The frozen scorer function pair_agree reports 37 of 38 specs in agreement (sample identity identical; max absolute coefficient/SE difference about 2.4e-12).

The one flagged spec, D02 (market_sample L1, publicly held), has identical samples and identical estimates for every fitted model. The flag comes only from formatting of the two failed models, mkt_M9 and mkt_M10:
- Both implementations fail them for the same reason: GRIEV_x_INCENT is collinear in the 69-row sample. A reports "term collinear in the estimation sample", B "Rank-deficient non-industry terms".
- B writes 90 all-NA coefficient rows for the failed models; A writes none.

The scorer counts the NA rows as unmatched terms. No substantive disagreement exists. The scorer was not modified after execution; this note records the reading.
