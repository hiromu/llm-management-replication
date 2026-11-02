# Anonymous distribution

On 1 November 2026, 90 conversation files were removed from this copy: chat logs, raw model replies and event streams, probe transcripts, and conversations captured in standard-error files. A remaining personal home path in the Nagaraj README was replaced with `~/`. The root and proposal READMEs were updated to describe the current documents and this cleanup.

[anonymization_manifest.json](anonymization_manifest.json) lists every removed file with its pre-removal SHA-256 and records the before/after hashes of the edited files. Original files were backed up outside the repository. The manifest covers this cleanup only; it is not a complete audit of every possible identifying detail.

Analysis code, structured reader assessments, numerical results, scoring rules, and ordinary scholarly citations were retained. Historical run receipts and frozen hashes were not rewritten. They may still reference removed conversation files, so checking an original run inventory against this distributed copy can report those files as missing. Do not interpret those historical inventories as checksums of the distribution.

Nagaraj's export manifest separately records the updated README hash while preserving its original source hash. Its export verifier continues to check the public files and frozen protocol.

This cleanup applies to `Replication_management/`. It does not anonymize the parent repository's unrelated files or Git history.
