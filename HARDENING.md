# Hardening Report: DariuszPorowski--github-action-gitleaks/v.2.0.6

> This file was generated automatically by the hardening agent.

**Policy SHA:** `ff50f15e4b79bfbf764dafdfd2579175a6ea9771`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `1`

Action **DariuszPorowski--github-action-gitleaks/v.2.0.6** was hardened automatically. 2 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unpinned-uses (severity: high)

action.yml uses a mutable Docker image tag `:latest` for the `runs.image:` field instead of a pinned SHA digest. This means the action can silently pull a different (potentially malicious) image on each run. The reference `docker://ghcr.io/dariuszporowski/github-action-gitleaks:latest` should be replaced with a SHA-digested reference such as `ghcr.io/dariuszporowski/github-action-gitleaks@sha256:<64-hex-digest>`.

Locations:

- `action.yml:54`

### github-env-injection (severity: high)

entrypoint.sh writes user-controlled input values to $GITHUB_OUTPUT without the required sanitization step (`printf '%s' ... | tr -d '\n\r'`). The action inputs (e.g. `inputs.report_format`, `inputs.source`, `inputs.config`, `inputs.log_level`) are passed as Docker environment variables (`INPUT_REPORT_FORMAT`, `INPUT_SOURCE`, etc.) and then written unsanitized to $GITHUB_OUTPUT. An attacker can inject newlines into these values to poison the output file and set arbitrary environment variables or outputs. Affected writes include: `echo "report=gitleaks-report.${INPUT_REPORT_FORMAT}" >> $GITHUB_OUTPUT` (line 88), `echo "output=${OUTPUT}" >> $GITHUB_OUTPUT` (line 87), and `echo "command=${command}" >> $GITHUB_OUTPUT` (line 90), where `command` is constructed from multiple user-supplied inputs.

Locations:

- `entrypoint.sh:87`
- `entrypoint.sh:88`
- `entrypoint.sh:90`

## Iteration Notes

### Iteration 1

**Fixes applied:** unpinned-uses, github-env-injection

**Notes:**

1. Fixed unpinned-uses in action.yml: replaced `docker://ghcr.io/dariuszporowski/github-action-gitleaks:latest` with `docker://ghcr.io/dariuszporowski/github-action-gitleaks@sha256:b8122d73a64a979072e10888d8feb036746012efc00e2ddc0690fdb52c0c8ff0 # latest`.
2. Fixed github-env-injection in entrypoint.sh: sanitized all user-controlled values (OUTPUT, INPUT_REPORT_FORMAT, GITLEAKS_RESULT, command) using `printf '%s' ... | tr -d '\n\r'` before writing them to $GITHUB_OUTPUT, preventing newline injection attacks.

