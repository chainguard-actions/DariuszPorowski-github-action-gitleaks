# Hardening Report: DariuszPorowski--github-action-gitleaks/v2.0.8

> This file was generated automatically by the hardening agent.

**Policy SHA:** `ff50f15e4b79bfbf764dafdfd2579175a6ea9771`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **DariuszPorowski--github-action-gitleaks/v2.0.8** was hardened automatically. 0 finding(s) were identified and resolved across 1 iteration(s).

## Iteration Notes

### Iteration 1

**Fixes applied:** github-env-injection

**Notes:**

Fixed two github-env-injection vulnerabilities in entrypoint.sh:
1. Line 111: Added `safe_report_format=$(printf '%s' "${INPUT_REPORT_FORMAT}" | tr -d '\n\r')` before writing to $GITHUB_OUTPUT, and used `${safe_report_format}` in the echo.
2. Line 113: Added `safe_command=$(printf '%s' "${command}" | tr -d '\n\r')` before writing to $GITHUB_OUTPUT, and used `${safe_command}` in the echo.
Both sanitizations strip carriage returns and newlines to prevent newline injection attacks that could poison subsequent steps reading from $GITHUB_OUTPUT.

