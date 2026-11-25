# Releasing

## 1. Build riq-scan

riq-scan lives in the Megatron backend repository.
1. Tag a commit there as `riq-scan-v1.0.0`. The `riq-scan-release` CI job builds the six binaries and `SHA256SUMS` into `out/riq-scan/`. Download that folder from the job's artifacts.
2. Or build them yourself with `scripts/build-riq-scan.sh 1.0.0`.

## 2. Publish the binaries here

```sh
scripts/release-riq-scan.sh 1.0.0 path/to/riq-scan-folder
```

The script:
- checks every binary against `SHA256SUMS`;
- creates the GitHub release `riq-scan-v1.0.0` with the binaries attached, not marked as latest;
- copies the checksums to `checksums/riq-scan-1.0.0.sha256`.

## 3. Release the action

1. Set the default of `scanner-version` in `action.yml` to the new version, if it changed.
2. Update `CHANGELOG.md`.
3. Commit `checksums/`, `action.yml` and `CHANGELOG.md`, then push. Wait for the **Test** workflow to pass on all four runners.
4. Create a release `v1.0.0` from that commit. Tick **Publish this Action to the GitHub Marketplace** (only for `v*` releases, never the `riq-scan-v*` ones).
5. Move the major tag:

   ```sh
   git tag -f v1 v1.0.0 && git push -f origin v1
   ```

The first Marketplace release requires accepting the Marketplace developer agreement and enabling two-factor authentication on the publishing account. The action's `name` (Megatron Vulnerability Scan) must be unique on the Marketplace.

## Settings for the repository

- Turn on **private vulnerability reporting** (Settings → Code security), which SECURITY.md points to.
- Protect `main`, and require the Test workflow to pass.
- Restrict who can create tags matching `v*` and `riq-scan-v*`.
