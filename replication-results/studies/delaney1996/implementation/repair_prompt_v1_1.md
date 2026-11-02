# Repair round (v1.1)

Your previous code is in `code/`. Two new inputs:
- `spec_amendment_v1_1.md`: clarifications to the specification that apply to everyone. They take precedence over `implementation_spec.md` wherever the two differ.
- `checker_items.md`: a list of items an independent checker found unmet or different from the specification in your code. Some may be resolved by the amendment.

Task:
1. Update your code so that it satisfies the specification as amended, and addresses every checker item. If you believe a checker item is mistaken, leave the code unchanged for that item and explain why in README.
2. Add or update synthetic tests for the amended behaviour, including HC3 with a leverage-one row and the copy-rule validity.
3. Run your tests and the full grid on the synthetic data again (into `code/dev_out/v1_1/`).
4. Update `code/README.md` with a section "v1.1 changes" listing, for each amendment item and checker item, what changed.
5. Write `code/DONE_v1_1.txt`.

Same rules as before: use only this directory, no network, no package installation, do not change the grid or add specifications, do not interpret synthetic results.
