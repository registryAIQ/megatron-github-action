# Megatron Security Scanner for GitHub Actions

**Megatron by registryAIQ** — starter integration for running the Megatron security engine in GitHub Actions.

> **Integration status: starter scaffold.** The action adapter, path validation, API-key environment handling, SARIF validation, severity gate, sample workflows, and tests are implemented. The actual Megatron CLI distribution and its command/API contract are **not included or verified**. RegistryAIQ must supply the scanner binary/image and confirm the CLI contract before this is a production-ready scanner.

## What it does

- Runs a scanner executable inside a Docker-based GitHub Action.
- Supplies the API key through `MEGATRON_API_KEY` (never as a command-line argument).
- Configures scan path and severity threshold.
- Expects SARIF 2.1.0 output and validates its basic structure.
- Fails the job when findings meet or exceed the configured severity.
- Keeps the scanning engine separate from GitHub-specific workflow configuration.

## Repository layout

```text
.
├── action.yml
├── Dockerfile
├── entrypoint.sh
├── src/runner.py
├── tests/test_runner.py
├── examples/basic-scan.yml
├── examples/fork-safe-scan.yml
├── .github/workflows/ci.yml
├── SECURITY.md
├── LICENSE
└── CHANGELOG.md
```

## Quick start

1. Obtain a Megatron API key from https://megatron.registryaiq.com/ .
2. Add it to the repository as `MEGATRON_API_KEY` under **Settings → Secrets and variables → Actions**.
3. Add `.github/workflows/megatron.yml`:

```yaml
name: Megatron Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Megatron scan
        uses: registryaiq/megatron-github-action@v1
        with:
          api-key: ${{ secrets.MEGATRON_API_KEY }}
          scan-path: .
          fail-on-severity: high
```

The `@v1` reference becomes usable after registryAIQ publishes the repository and creates the corresponding major-version tag. Pin to a full commit SHA for the strongest supply-chain protection.

## Fork pull requests and secret handling

GitHub does not pass repository secrets to workflows triggered by `pull_request` events from forks. Do not work around this by using `pull_request_target` to check out and execute untrusted pull-request code with a privileged token.

Use `examples/fork-safe-scan.yml` as a starting point. It runs the authenticated scan on pushes and same-repository pull requests, and skips the scan for fork-originated pull requests. If desired, a separate unauthenticated/local-only mode can be added once registryAIQ defines and tests that product capability. Do not assume that it exists.

## Inputs

| Input | Default | Description |
|---|---|---|
| `api-key` | required | Megatron API key |
| `scan-path` | `.` | File or directory inside the checked-out workspace |
| `fail-on-severity` | `high` | `critical`, `high`, `medium`, `low`, or `none` |
| `sarif-file` | `megatron-results.sarif` | Output report path inside workspace |
| `scanner-command` | `megatron` | Executable present in action image |
| `scanner-extra-args` | `[]` | JSON array of extra CLI arguments |
| `upload-sarif` | `true` | Reserved for workflow examples; SARIF upload is done by caller workflow |
| `skip-without-api-key` | `false` | Explicitly skip if key absent; use only for safe fork handling |

`upload-sarif` is currently descriptive/reserved: a Docker action cannot itself invoke GitHub's SARIF upload action. The consuming workflow must add `github/codeql-action/upload-sarif`.

## Scanner CLI contract — registryAIQ action required

The adapter currently assumes this invocation:

```bash
megatron scan --path <workspace-path> --format sarif --output <report-path>
```

It passes the credential in the process environment as `MEGATRON_API_KEY`. It expects the scanner to return `0` when scanning completed and to write a valid SARIF 2.1.0 report. The adapter itself applies the severity threshold based on SARIF result/rule metadata.

**This is a proposed interface, not a claim about an existing Megatron CLI.** Before release, registryAIQ must either implement this contract or update `src/runner.py` to the actual supported interface. Confirm whether the engine needs network access, tenant/account identifiers, policy IDs, proxy settings, or additional environment variables.

### SARIF severity mapping

The adapter reads `security-severity` numeric scores and common severity labels from result/rule properties. Numeric scores map as follows: 9+ critical, 7–8.9 high, 4–6.9 medium, above 0–3.9 low. If no severity metadata exists, it falls back to SARIF `level` (`error` → high, `warning` → medium, `note` → low). Confirm that the Megatron SARIF producer emits compatible metadata.

## SARIF upload

Add this step after the scan:

```yaml
- name: Upload Megatron SARIF
  if: always() && hashFiles('megatron-results.sarif') != ''
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: megatron-results.sarif
    category: megatron
```

The workflow needs `security-events: write`. GitHub code-scanning availability depends on repository visibility, plan, and Code Security entitlement. Validate the supported upload action version and entitlement for each target customer.

## Local development and tests

The tests use a temporary fake `megatron` executable; they do not require the proprietary scanner.

```bash
python -m unittest discover -s tests -v
```

To exercise the adapter locally, create a compatible test executable named `megatron` on `PATH` that writes SARIF 2.1.0 to the `--output` argument, then set:

```bash
export GITHUB_WORKSPACE="$PWD"
export MEGATRON_API_KEY="test-key"
export MEGATRON_SCANNER_COMMAND="megatron"
python src/runner.py
```

Do not use a real production key in local logs, shell history, or test fixtures.

## Building the Docker image

```bash
docker build -t megatron-github-action:local .
```

The Dockerfile intentionally does not download an unverified binary or call an undocumented API. Add the official registryAIQ installation step after the distribution mechanism, checksum/signature verification, and supported versions are decided.

## Release process

1. Run unit tests and workflow CI.
2. Build and test the image against a registryAIQ staging scanner.
3. Pin the base image and scanner artifact by immutable digest/version; verify signatures/checksums.
4. Review permissions, fork behavior, and secret redaction.
5. Publish a GitHub Release and create immutable release tag `v1.0.0`.
6. Create/update the major tag `v1` to point to the tested release commit.
7. Enable Marketplace publication from the public repository if eligible; complete listing metadata and Marketplace terms.
8. Publish release notes and update the changelog.

## License

`LICENSE` is deliberately a placeholder. RegistryAIQ must select and approve a license (for example, MIT or Apache-2.0) and replace the placeholder with the complete, correct license text before making the repository public. Do not publish a blank or misleading license file.

## Roadmap

- Add official Megatron scanner installation and signature verification.
- Confirm API tenancy, usage metering, retries, timeouts, and offline behavior.
- Add optional PR annotations and a summary in `$GITHUB_STEP_SUMMARY`.
- Add a local-only/fork-safe mode if supported by the engine.
- Add integration tests against a registryAIQ staging tenant.
- Reuse the scanner core through GitLab CI, Jenkins, Azure DevOps, and Bitbucket adapters.
