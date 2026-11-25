#!/usr/bin/env bash
# Publishes a riq-scan build as a release of this repository and records its checksums, so the
# action can download and verify it. Run it from the repository root with the folder made by the
# backend's scripts/build-riq-scan.sh (or the GitLab riq-scan-release job's artifacts):
#
#   scripts/release-riq-scan.sh 1.0.0 path/to/riq-scan-1.0.0
#
# Needs the GitHub CLI (gh), signed in with permission to create releases here.
set -euo pipefail

version="${1:?usage: scripts/release-riq-scan.sh VERSION DIST_DIR}"
dist="${2:?usage: scripts/release-riq-scan.sh VERSION DIST_DIR}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must look like 1.2.3" >&2; exit 2; }
[ -f "$dist/SHA256SUMS" ] || { echo "$dist/SHA256SUMS not found" >&2; exit 2; }

expected=(linux_amd64 linux_arm64 darwin_amd64 darwin_arm64 windows_amd64.exe windows_arm64.exe)
files=()
for t in "${expected[@]}"; do
  f="$dist/riq-scan_${version}_$t"
  [ -f "$f" ] || { echo "missing $f" >&2; exit 2; }
  files+=("$f")
done

# Every binary must match SHA256SUMS before anything is published.
(cd "$dist" && sha256sum -c SHA256SUMS)

tag="riq-scan-v$version"
gh release create "$tag" "${files[@]}" "$dist/SHA256SUMS" \
  --title "riq-scan $version" \
  --notes "Scanner binaries used by the action (scanner-version: $version). Not an action release." \
  --latest=false

cp "$dist/SHA256SUMS" "checksums/riq-scan-$version.sha256"
echo
echo "Published $tag and wrote checksums/riq-scan-$version.sha256."
echo "Next: set scanner-version's default to $version in action.yml, commit, and release the action."
