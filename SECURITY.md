# Security Policy

## Reporting a vulnerability

Please do not report security vulnerabilities in public GitHub issues. Contact registryAIQ through its designated security-reporting channel.

**Before publication:** registryAIQ must replace the instruction above with a monitored security contact address or a verified private vulnerability reporting process.

## Supported versions

Security support applies to the latest supported major release unless registryAIQ publishes a different policy.

## Secrets and untrusted pull requests

- Store the Megatron API key in GitHub Actions Secrets.
- The action passes the key to the scanner through an environment variable, not command-line arguments.
- Never print the key or include it in SARIF, artifacts, logs, or workflow outputs.
- Do not execute untrusted fork pull-request code in a privileged `pull_request_target` workflow.
- Restrict workflow token permissions to the minimum required.
- Pin third-party actions to reviewed commit SHAs for production use.

## Scanner supply chain

Before production release, pin the container base image and scanner artifact by immutable digest/version, verify checksums or signatures, and document the update process.
