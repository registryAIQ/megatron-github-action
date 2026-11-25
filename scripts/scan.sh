#!/usr/bin/env bash
# Runs riq-scan with the action's inputs. Always exits 0 so the SARIF upload step can still run;
# riq-scan's exit code (0 pass, 1 vulnerabilities at or above fail-on, 2 error) is passed on as
# the exit-code output and applied by result.sh.
set -uo pipefail

bad() {
  echo "::error title=Megatron::$1"
  echo "exit-code=2" >> "$GITHUB_OUTPUT"
  exit 0
}
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

report="$(lower "$(trim "${RIQ_REPORT_FORMAT:-sarif}")")"
case "$report" in
  sarif | sarif-2.1.0 | "sarif 2.1.0") report=sarif ;;
  none) ;;
  *) bad "report-format must be sarif or none, got '$RIQ_REPORT_FORMAT'" ;;
esac

case "$(lower "$(trim "${RIQ_INCLUDE_INTERNAL:-yes}")")" in
  yes | true | y | 1) include_internal=true ;;
  no | false | n | 0) include_internal=false ;;
  *) bad "include-internal-packages must be yes or no, got '$RIQ_INCLUDE_INTERNAL'" ;;
esac

upload_sarif="$(lower "$(trim "${RIQ_UPLOAD_SARIF:-auto}")")"
case "$upload_sarif" in
  auto | true | false) ;;
  *) bad "upload-sarif must be auto, true or false, got '$RIQ_UPLOAD_SARIF'" ;;
esac

args=(-format table -fail-on "$(trim "${RIQ_FAIL_ON:-high}")" -wait "$(trim "${RIQ_WAIT:-10m}")")
[ -n "${RIQ_SERVER:-}" ] && args+=(-server "$(trim "$RIQ_SERVER")")
[ -n "${RIQ_IGNORE_FILE:-}" ] && args+=(-ignore "$RIQ_IGNORE_FILE")
[ -n "${RIQ_PROJECT:-}" ] && args+=(-project "$(trim "$RIQ_PROJECT")")
[ -n "${RIQ_SBOM_NAME:-}" ] && args+=(-name "$(trim "$RIQ_SBOM_NAME")")
[ -n "${RIQ_SBOM_FILE:-}" ] && args+=(-sbom "$RIQ_SBOM_FILE")

if [ -n "${MEGATRON_TOKEN:-}" ]; then
  # The token stays in the environment; riq-scan reads MEGATRON_TOKEN itself.
  args+=(-upload)
elif [ "${RIQ_FORK_PR:-false}" = true ]; then
  echo "::notice title=Megatron::Pull request from a fork: GitHub gives it no secrets, so the SBOM is checked on the runner against OSV and nothing is sent to Megatron."
else
  echo "::notice title=Megatron::No token input: the SBOM is checked on the runner against OSV and nothing is sent to Megatron. Add a Megatron API token as a secret to keep results in Megatron."
fi

if [ "$include_internal" = false ]; then
  args+=(-include-internal=false)
  while IFS= read -r line; do
    IFS=',' read -ra parts <<< "$line"
    for p in "${parts[@]}"; do
      p="$(trim "$p")"
      [ -n "$p" ] && args+=(-internal "$p")
    done
  done <<< "${RIQ_INTERNAL:-}"
elif [ -n "$(trim "${RIQ_INTERNAL:-}")" ]; then
  echo "::warning title=Megatron::internal-packages is set but include-internal-packages is yes, so internal packages are kept. Set include-internal-packages: no to leave them out."
fi

while IFS= read -r line; do
  line="$(trim "$line")"
  [ -n "$line" ] && args+=(-exclude "$line")
done <<< "${RIQ_EXCLUDE:-}"

sarif=""
if [ "$report" = sarif ]; then
  sarif="${RIQ_SARIF_FILE:-megatron.sarif}"
  args+=(-sarif "$sarif")
fi

"${RIQ_BIN:?}" "${args[@]}" "${RIQ_PATH:-.}"
code=$?
echo "exit-code=$code" >> "$GITHUB_OUTPUT"

send=false
if [ -n "$sarif" ] && [ -f "$sarif" ]; then
  echo "sarif-file=$sarif" >> "$GITHUB_OUTPUT"
  if [ "$upload_sarif" = true ]; then
    send=true
  elif [ "$upload_sarif" = auto ]; then
    if [ "${RIQ_FORK_PR:-false}" = true ]; then
      echo "Not sending SARIF to code scanning: pull requests from forks can't write security events."
    else
      send=true
    fi
  fi
fi
echo "send-sarif=$send" >> "$GITHUB_OUTPUT"
exit 0
