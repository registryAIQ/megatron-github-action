#!/usr/bin/env bash
# Fails the job with riq-scan's exit code, after the SARIF report has been sent.
set -euo pipefail
case "${RIQ_EXIT:-}" in
  0) ;;
  1) echo "Vulnerabilities at or above fail-on were found (listed above and in the job summary)."; exit 1 ;;
  "") echo "::error title=Megatron::The scan didn't run."; exit 2 ;;
  *) echo "::error title=Megatron::riq-scan stopped with an error (exit code $RIQ_EXIT); see the Scan dependencies step."; exit "$RIQ_EXIT" ;;
esac
