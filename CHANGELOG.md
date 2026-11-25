# Changelog

## v1.0.0

First release.
- Builds a CycloneDX SBOM on the runner and scans it in Megatron. The project and the SBOM are created or updated by name.
- Returns the results as SARIF 2.1.0 for GitHub code scanning. Findings ignored in Megatron are sent as suppressed results.
- `include-internal-packages` and `internal-packages` keep your own package names on the runner.
- Notes on the lockfile and a summary table for failing findings.
- Without a token (fork pull requests), the SBOM is checked on the runner against OSV.
- Runs riq-scan 1.0.0.
