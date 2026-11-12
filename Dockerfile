megatron scan \
  --path "$GITHUB_WORKSPACE/$SCAN_PATH" \
  --format sarif \
  --output "$GITHUB_WORKSPACE/megatron-results.sarif" \
  --fail-on "$FAIL_ON_SEVERITY"
