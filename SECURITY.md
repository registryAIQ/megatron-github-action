# Security policy

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's **Report a vulnerability** button on this repository's Security tab (private vulnerability reporting). We'll acknowledge within 3 working days and keep you updated until it's fixed.

## How this action protects you

- **Only the SBOM is uploaded.** Source code stays on the runner. With `include-internal-packages: no`, internal package names stay there too.
- **Checked binaries.** `riq-scan` is downloaded from this repository's releases and run only if its SHA-256 matches the checksum committed in this repository. Pin the action to a commit SHA, and you pin the binary as well.
- **No script injection.** Inputs are passed to the scripts as environment variables, never written into the script text.
- **The token stays private.** It's read from the `MEGATRON_TOKEN` environment variable, never put on a command line, and sent only over HTTPS. Plain HTTP is refused except to localhost.
- **Pinned dependencies.** The one third-party action used, `github/codeql-action/upload-sarif`, is pinned to a commit SHA.
- **Least privilege.** The token acts with its user's role in Megatron. Create it for a user who has only the access the pipeline needs, and give it the shortest expiry you can manage.

## Supported versions

Only the latest major version (`v1`) receives security fixes.
