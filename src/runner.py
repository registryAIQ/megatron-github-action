#!/usr/bin/env python3
"""GitHub Actions adapter. The Megatron CLI contract below is a documented placeholder."""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

SEVERITY = {"none": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}
# Expected CLI contract (MUST be confirmed/adapted by registryAIQ):
#   megatron scan --path PATH --format sarif --output FILE
# API key is supplied only through MEGATRON_API_KEY in the child process environment.
# Expected process exit codes: 0 = scan completed; nonzero = scanner/runtime failure.
# The action applies the severity gate by inspecting SARIF after a successful scan.


def log(message: str) -> None:
    # Never log environment values, command arguments containing secrets, or report contents.
    print(f"::notice::{message}", flush=True)


def fail(message: str, code: int = 2) -> int:
    print(f"::error::{message}", file=sys.stderr, flush=True)
    return code


def parse_bool(value: str, name: str) -> bool:
    normalized = value.strip().lower()
    if normalized not in ("true", "false"):
        raise ValueError(f"{name} must be 'true' or 'false'")
    return normalized == "true"


def resolve_inside_workspace(workspace: Path, value: str, label: str) -> Path:
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = workspace / candidate
    resolved = candidate.resolve()
    try:
        resolved.relative_to(workspace.resolve())
    except ValueError:
        raise ValueError(f"{label} must resolve inside GITHUB_WORKSPACE")
    return resolved


def severity_of_result(result: dict, rules: dict) -> int:
    props = result.get("properties") or {}
    rule_id = result.get("ruleId")
    rule = rules.get(rule_id, {}) if isinstance(rules, dict) else {}
    rule_props = rule.get("properties") or {}
    candidates = [
        props.get("security-severity"),
        rule_props.get("security-severity"),
        props.get("severity"),
        rule_props.get("severity"),
        result.get("level"),
    ]
    for candidate in candidates:
        if candidate is None:
            continue
        text = str(candidate).strip().lower()
        if text.replace(".", "", 1).isdigit():
            score = float(text)
            if score >= 9.0: return SEVERITY["critical"]
            if score >= 7.0: return SEVERITY["high"]
            if score >= 4.0: return SEVERITY["medium"]
            if score > 0: return SEVERITY["low"]
        if text in SEVERITY:
            return SEVERITY[text]
        if text == "error": return SEVERITY["high"]
        if text == "warning": return SEVERITY["medium"]
        if text == "note": return SEVERITY["low"]
    return 0


def validate_sarif(path: Path) -> dict:
    if not path.is_file():
        raise ValueError("Megatron CLI did not create the requested SARIF file")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"SARIF output is not valid JSON: {exc}")
    if data.get("version") != "2.1.0" or not isinstance(data.get("runs"), list):
        raise ValueError("SARIF must declare version 2.1.0 and contain a runs array")
    return data


def main() -> int:
    workspace = Path(os.environ.get("GITHUB_WORKSPACE", os.getcwd())).resolve()
    scan_path_raw = os.environ.get("MEGATRON_SCAN_PATH", ".")
    sarif_raw = os.environ.get("MEGATRON_SARIF_FILE", "megatron-results.sarif")
    threshold_raw = os.environ.get("MEGATRON_FAIL_ON_SEVERITY", "high").strip().lower()
    command = os.environ.get("MEGATRON_SCANNER_COMMAND", "megatron").strip()
    api_key = os.environ.get("MEGATRON_API_KEY", "")
    skip_without_key = os.environ.get("MEGATRON_SKIP_WITHOUT_API_KEY", "false")
    try:
        if threshold_raw not in SEVERITY:
            return fail("fail-on-severity must be critical, high, medium, low, or none")
        if not command:
            return fail("scanner-command cannot be empty")
        if not api_key:
            if parse_bool(skip_without_key, "skip-without-api-key"):
                log("Megatron scan skipped because no API key was supplied.")
                return 0
            return fail("No Megatron API key supplied. Add MEGATRON_API_KEY as a repository or organization secret.")
        scan_path = resolve_inside_workspace(workspace, scan_path_raw, "scan-path")
        if not scan_path.exists():
            return fail("scan-path does not exist inside the workspace")
        sarif_path = resolve_inside_workspace(workspace, sarif_raw, "sarif-file")
        sarif_path.parent.mkdir(parents=True, exist_ok=True)
        extra = json.loads(os.environ.get("MEGATRON_SCANNER_EXTRA_ARGS", "[]"))
        if not isinstance(extra, list) or not all(isinstance(x, str) for x in extra):
            return fail("scanner-extra-args must be a JSON array of strings")
        executable = shlex.split(command)
        if len(executable) != 1:
            return fail("scanner-command must be a single executable path/name")
    except (ValueError, json.JSONDecodeError) as exc:
        return fail(str(exc))

    child_env = os.environ.copy()
    # The API key is never placed in command-line arguments.
    child_env["MEGATRON_API_KEY"] = api_key
    child_env["MEGATRON_WORKSPACE"] = str(workspace)
    argv = executable + [
        "scan", "--path", str(scan_path),
        "--format", "sarif", "--output", str(sarif_path),
    ] + extra

    log("Starting Megatron scan.")
    try:
        completed = subprocess.run(argv, cwd=workspace, env=child_env, check=False)
    except FileNotFoundError:
        return fail(f"Scanner executable '{executable[0]}' was not found in the action image.")
    except OSError as exc:
        return fail(f"Unable to start Megatron scanner: {exc}")
    if completed.returncode != 0:
        return fail(f"Megatron scanner failed with exit code {completed.returncode}.", 2)

    try:
        report = validate_sarif(sarif_path)
    except ValueError as exc:
        return fail(str(exc), 2)

    threshold = SEVERITY[threshold_raw]
    findings = 0
    blocking = 0
    for run in report["runs"]:
        rules_list = ((run.get("tool") or {}).get("driver") or {}).get("rules") or []
        rules = {rule.get("id"): rule for rule in rules_list if isinstance(rule, dict)}
        for result in run.get("results") or []:
            if not isinstance(result, dict):
                continue
            findings += 1
            if threshold and severity_of_result(result, rules) >= threshold:
                blocking += 1

    # GitHub Actions output for downstream workflow steps.
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as handle:
            handle.write(f"sarif-file={sarif_path}\n")
            handle.write(f"finding-count={findings}\n")
            handle.write(f"blocking-count={blocking}\n")

    log(f"Megatron scan completed: {findings} finding(s); {blocking} at or above configured threshold.")
    if blocking:
        print(f"::error::Megatron found {blocking} finding(s) at or above '{threshold_raw}'.", flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
