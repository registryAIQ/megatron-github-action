#!/usr/bin/env bash
# Downloads the riq-scan binary for this runner and checks it against the checksum file kept in
# this repository, so pinning the action to a commit also pins the exact binary. Reuses a copy
# already in the runner's tool cache when its checksum still matches.
set -euo pipefail

version="${RIQ_VERSION:?}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error title=Megatron::scanner-version must look like 1.2.3, got '$version'"
  exit 2
fi

case "${RIQ_RUNNER_OS:-}" in
  Linux) os=linux ;;
  macOS) os=darwin ;;
  Windows) os=windows ;;
  *) echo "::error title=Megatron::Unsupported runner OS '${RIQ_RUNNER_OS:-}'"; exit 2 ;;
esac
case "${RIQ_RUNNER_ARCH:-}" in
  X64) arch=amd64 ;;
  ARM64) arch=arm64 ;;
  *) echo "::error title=Megatron::Unsupported runner architecture '${RIQ_RUNNER_ARCH:-}' (X64 and ARM64 are supported)"; exit 2 ;;
esac

name="riq-scan_${version}_${os}_${arch}"
exe=riq-scan
if [ "$os" = windows ]; then
  name="$name.exe"
  exe=riq-scan.exe
fi

sums="$GITHUB_ACTION_PATH/checksums/riq-scan-$version.sha256"
if [ ! -f "$sums" ]; then
  echo "::error title=Megatron::riq-scan $version isn't known to this version of the action (no checksums/riq-scan-$version.sha256). Use the default scanner-version or a newer action."
  exit 2
fi
# SHA256SUMS lines are "<hash>  <file>" (or "<hash> *<file>" in binary mode).
expected="$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' "$sums")"
if [ -z "$expected" ]; then
  echo "::error title=Megatron::No checksum for $name in $sums"
  exit 2
fi

# Read the file on stdin: given a Windows path (with backslashes), GNU sha256sum escapes the line
# and prefixes the hash with "\", so it would never match.
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum < "$1" | awk '{ print $1 }'
  else
    shasum -a 256 < "$1" | awk '{ print $1 }'
  fi
}

dir="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:?}}/megatron-riq-scan/$version/$os-$arch"
bin="$dir/$exe"
if [ -f "$bin" ] && [ "$(sha256 "$bin")" = "$expected" ]; then
  echo "Using cached riq-scan $version ($os/$arch)"
else
  mkdir -p "$dir"
  url="${RIQ_DOWNLOAD_URL%/}/riq-scan-v$version/$name"
  echo "Downloading $url"
  tmp="$dir/.download.$$"
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$tmp" "$url"
  got="$(sha256 "$tmp")"
  if [ "$got" != "$expected" ]; then
    echo "::error title=Megatron::Checksum mismatch for $name: expected $expected, got $got. The file was not run."
    exit 2
  fi
  chmod +x "$tmp"
  mv -f "$tmp" "$bin"
  echo "Checksum OK ($expected)"
fi

echo "bin=$bin" >> "$GITHUB_OUTPUT"
