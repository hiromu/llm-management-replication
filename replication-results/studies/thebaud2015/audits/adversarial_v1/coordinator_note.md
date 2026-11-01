# Coordinator note on adversarial review v1

- Correction: review.md line 3 says implementers A and B are Anthropic-family. That is wrong. A and C are Claude Fable 5.1 (Anthropic); B is GPT-6 Astra (OpenAI). The reviewer (Claude Opus 5.5) is in the same family as A and C, not B. No family independent of every implementer is available, so a second adversarial review was run with GPT-6 Astra (audits/adversarial_astra_v1/). That family is independent of A and C but not of B.
- The review is preserved unedited. Its what-if fits are post-hoc diagnostics. They do not replace the frozen scores in scoring/.
- The four pipeline errors it names were found after the discrepancies were seen. They are not applied to the frozen v1 analysis. Any corrected analysis needs a new, separately labelled registration (v2), authorized by the user.
