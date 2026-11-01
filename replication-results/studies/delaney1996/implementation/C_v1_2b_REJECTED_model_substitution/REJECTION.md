# Rejected: model substitution (second attempt)

Run record modelUsage lists claude-opus-5 and claude-opus-4-8, not claude-fable-5-1, although --model claude-fable-5-1 was requested. A separate one-line connectivity check minutes later ran on claude-fable-5-1, which suggests the CLI fell back silently while Fable 5.1 was overloaded. Code preserved here, not used.
