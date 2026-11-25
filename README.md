# Megatron Vulnerability Scan

A GitHub Action that finds vulnerable dependencies in your repository with [Megatron](https://megatron.registryaiq.com) by RegistryAIQ.

On every run it:

1. Builds a CycloneDX SBOM of your dependencies **on the runner**, from your lockfiles and manifests.
2. Optionally leaves your own internal packages out of it.
3. Uploads **only the SBOM** to Megatron. Your source code never leaves GitHub. Megatron:
   - creates the project, or updates it if it exists;
   - creates the SBOM under the name you choose, or updates it;
   - scans the SBOM and shows the vulnerability report on the dashboard, the same way it does for connected repositories.
4. Gets the report back as **SARIF 2.1.0** and sends it to GitHub code scanning (the Security tab and pull request alerts).
5. Fails the job when a vulnerability is at or above the severity you set, unless someone ignored it in Megatron.

Each finding that fails the build is also shown as an error note on the lockfile, and a results table is added to the job summary. Both work on every repository, including private ones without GitHub Code Security.

## Quick start

1. In Megatron, go to **Developer → API tokens** and create a token. It's shown only once.
2. In GitHub, go to **Settings → Secrets and variables → Actions** and add it as a repository secret named `MEGATRON_TOKEN`.
3. Add `.github/workflows/megatron.yml`:

```yaml
name: Megatron
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  security-events: write # send SARIF to code scanning
  actions: read          # needed by code scanning on private repositories

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: registryaiq/megatron-github-action@v1
        with:
          token: ${{ secrets.MEGATRON_TOKEN }}
```

That's all. The project is named after the repository and the SBOM after `owner/repo`. Each push updates the same SBOM, and every scan stays in Megatron's history.

## Inputs

| Input | Default | What it does |
|---|---|---|
| `token` | | Megatron API token (`riqpat_…`), from a secret. If it's empty, the SBOM is checked on the runner against the public [OSV](https://osv.dev) database and nothing is sent to Megatron. |
| `project` | repository name | The Megatron project to scan into. It's created if no project of that name exists in your enterprise. Names are matched without regard to case. |
| `sbom-name` | `owner/repo` | The SBOM's name inside the project. Each name is one SBOM, and every run updates it. Use different names to keep several SBOMs in one project, for example one per service in a monorepo. |
| `report-format` | `sarif` | `sarif` (SARIF 2.1.0) or `none`. |
| `sarif-file` | `megatron.sarif` | Where the SARIF report is written. |
| `upload-sarif` | `auto` | Send the SARIF report to GitHub code scanning.<br>`auto` sends it except on pull requests from forks; `true` always sends it; `false` never does. |
| `include-internal-packages` | `yes` | `no` leaves your own packages out of the SBOM before it's scanned or uploaded. Your own packages are the ones matching `internal-packages`, plus local and workspace dependencies. |
| `internal-packages` | | Names of your own packages, one per line or comma-separated. `*` matches anything. Example: `@acme/*, com.acme.*, github.com/acme/*`. |
| `fail-on` | `high` | Fail the job when a vulnerability that isn't ignored is at or above this severity: `critical`, `high`, `medium`, `low`, `any` or `none`. |
| `path` | `.` | The folder to scan. |
| `exclude` | | Paths to skip, one per line, relative to `path`. Example: `testdata/**`. |
| `sbom-file` | | Also write the CycloneDX 1.6 SBOM to this file, for example to keep it as a build artifact. |
| `ignore-file` | `.registryaiq-ignore` | A file, relative to `path`, of advisory IDs to ignore: one per line, then a reason. |
| `wait` | `10m` | How long to wait for Megatron's scan. |
| `server` | `https://megatron.registryaiq.com` | Megatron's address. It must use HTTPS. |
| `scanner-version` | see `action.yml` | The `riq-scan` version to run. Only versions with a checksum file in this action can be used. |
| `download-url` | GitHub releases of this action | Change this only for a mirror on runners without internet access. Downloads are still checked against this action's checksums. |

## Outputs

| Output | Meaning |
|---|---|
| `sarif-file` | Path of the SARIF report. Empty when `report-format` is `none`. |
| `scan-url` | Link to the scan in Megatron. Empty when nothing was uploaded. |
| `packages` | Number of packages in the SBOM. |
| `vulnerabilities` | Number of vulnerabilities found, including ignored ones. |
| `failing` | Number of vulnerabilities at or above `fail-on` that aren't ignored. |
| `uploaded` | `true` if Megatron scanned the SBOM, `false` if it was checked on the runner. |

## What is sent to Megatron

Only the SBOM, plus a few details about where it came from. The SBOM contains:
- package names, versions and package URLs;
- hashes and licenses;
- the paths of the lockfiles each package was found in.

Alongside it, the action sends:
- the repository name and URL;
- the branch;
- the commit SHA.

No source code is sent, and no environment variables or secrets other than the token. The token is sent only in the `Authorization` header, over HTTPS.

With `include-internal-packages: no`, your own packages are removed before the SBOM is built. Their names never leave the runner. They have no public advisories, so nothing is lost. It also prevents a false match against a public package that happens to share an internal name.

## Permissions

**On the Megatron side:** the token acts as the user who created it, with that user's role.
- To create projects, the user needs permission to manage projects. Otherwise, create the project in Megatron first and set `project`.
- The first run for a repository also needs permission to add sources.
- Later runs only need access to the project.

**On the GitHub side:**
- `security-events: write` lets the action send SARIF to code scanning.
- On private repositories, code scanning also needs `actions: read`.

## Private repositories

Code scanning on private repositories needs GitHub Code Security, a paid add-on. Without it, the SARIF upload fails. The action reports that as a warning and doesn't fail the job.

To skip the upload entirely, set `upload-sarif: false`. The lockfile notes, the job summary and the report in Megatron all still work.

## Pull requests from forks

GitHub gives fork pull requests no secrets and no permission to write security events. On those runs, the action:
- checks the SBOM on the runner against OSV;
- notes the failing findings on the pull request;
- doesn't upload anything.

Use `pull_request`, not `pull_request_target`. Never run untrusted fork code with your secrets.

## Ignoring a finding

There are two ways:
- **In Megatron**, mark the finding as accepted risk, not affected, or false positive. It stops failing the build. It's sent to code scanning as a suppressed result with your reason.
- **In the repository**, add the advisory ID and a reason to `.registryaiq-ignore`:

```text
GHSA-29mw-wpgm-hmr9  dev-only dependency, not shipped
CVE-2024-12345       not reachable: we never call parse()
```

## Supported ecosystems

The action reads the lockfiles and manifests that [Syft](https://github.com/anchore/syft) understands, including:
- npm, Yarn and pnpm;
- Go modules;
- Python (pip, Poetry, Pipenv, uv);
- Maven and Gradle;
- Composer, Bundler, Cargo, NuGet, Pub, CocoaPods, Swift Package Manager, Hex and Conan.

Commit your lockfiles for the most accurate results.

## Pinning

`@v1` follows the latest 1.x release. For the strictest supply-chain policy, pin to a full commit SHA:

```yaml
- uses: registryaiq/megatron-github-action@<40-character commit SHA> # v1.0.0
```

The scanner binary's checksums are committed in this repository. Pinning the action to a commit therefore also pins the exact `riq-scan` binary that runs. A download that doesn't match is never run.

## Self-hosted runners

Self-hosted runners need Linux, macOS or Windows on x64 or ARM64, plus `bash` and `curl`. On Windows, Git Bash provides both. The binary is kept in the runner's tool cache and reused while its checksum matches.

## Troubleshooting

| Message | Fix |
|---|---|
| `401` … check MEGATRON_TOKEN | The token is wrong, expired or revoked. Create a new one in Megatron and update the secret. |
| `403` | The token's user can't create projects or add sources. See [Permissions](#permissions). |
| `409` … archived | A project with that name is archived. Restore it in Megatron, or choose another `project`. |
| `422` | The SBOM listed no packages. Check `path`, and that your lockfiles are committed. |
| The SARIF upload fails | See [Private repositories](#private-repositories). |
| Timed out waiting for the scan | Increase `wait`. The scan keeps running in Megatron either way. |

## More examples

See [examples/](examples/):
- a monorepo with one SBOM per service;
- leaving out internal packages;
- a private repository without Code Security;
- keeping the SBOM as a build artifact.

## Security

To report a vulnerability in this action, see [SECURITY.md](SECURITY.md).

## License

To be decided before the first release; see [LICENSE](LICENSE).
