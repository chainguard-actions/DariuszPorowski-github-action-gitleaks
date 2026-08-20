<!-- markdownlint-disable -->

# Hardening Report: DariuszPorowski--github-action-gitleaks/v.2.0.6

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **DariuszPorowski--github-action-gitleaks/v.2.0.6** was hardened automatically. 5 finding(s) were identified and resolved across 1 iteration(s).

## Findings Fixed

### unpinned-uses (severity: high)

Multiple `uses:` references and the Docker image in action.yml use mutable tags instead of pinned 40-character SHA commits, making the action vulnerable to supply-chain attacks.

action.yml: `image: docker://ghcr.io/dariuszporowski/github-action-gitleaks:latest` — mutable `:latest` tag instead of a SHA digest.

docker.yml: `actions/github-script@v6`, `actions/checkout@v3`, `docker/login-action@v2`, `docker/metadata-action@v4`, `docker/build-push-action@v3`.

dogfood.yml: `actions/checkout@v3`, `DariuszPorowski/github-action-gitleaks@v2`, `github/codeql-action/upload-sarif@v2`.

Locations:

- `action.yml:56`
- `.github/workflows/docker.yml:22`
- `.github/workflows/docker.yml:27`
- `.github/workflows/docker.yml:60`
- `.github/workflows/docker.yml:66`
- `.github/workflows/docker.yml:73`
- `.github/workflows/docker.yml:80`
- `.github/workflows/dogfood.yml:8`
- `.github/workflows/dogfood.yml:14`
- `.github/workflows/dogfood.yml:27`

### script-injection (severity: high)

GitHub Actions expressions are interpolated directly inside `run:` shell command strings (rule a), allowing an attacker who controls step outputs to inject arbitrary shell commands.

docker.yml — the 'Check - upgrade Gitleaks or not' step interpolates `${{ steps.repo_owner.outputs.result }}`, `${{ steps.repo_name.outputs.result }}`, and `${{ steps.gitleaks_latest_release.outputs.semver }}` directly into a `gh api` shell command:
  `pkgs=$(gh api /users/${{ steps.repo_owner.outputs.result }}/packages/container/${{ steps.repo_name.outputs.result }}/versions --jq '[.[] | select(.metadata.container.tags | index("${{ steps.gitleaks_latest_release.outputs.semver }}"))] | length')`

dogfood.yml — the 'Get the output from the gitleaks step' step interpolates `${{ steps.gitleaks.outputs.exitcode }}`, `${{ steps.gitleaks.outputs.result }}`, `${{ steps.gitleaks.outputs.output }}`, `${{ steps.gitleaks.outputs.command }}`, and `${{ steps.gitleaks.outputs.report }}` directly into `echo` shell commands. Since gitleaks scans arbitrary repository content, these outputs can contain attacker-controlled data.

Locations:

- `.github/workflows/docker.yml:40`
- `.github/workflows/dogfood.yml:22`

### missing-permissions (severity: medium)

Neither workflow file has a top-level `permissions:` key, and neither job within them defines a job-level `permissions:` block. Without explicit permissions, workflows run with the default (potentially broad) token permissions, violating the principle of least privilege.

Locations:

- `.github/workflows/docker.yml:1`
- `.github/workflows/dogfood.yml:1`

### github-env-injection (severity: high)

entrypoint.sh writes multiple values derived from user-controlled inputs and inherited environment variables to `$GITHUB_OUTPUT` without the required sanitization step (`printf '%s' ... | tr -d '\n\r'`). This allows newline injection that can poison subsequent steps' outputs or environment.

Affected writes (all unsanitized):
- `echo "output=${OUTPUT}" >> $GITHUB_OUTPUT` — OUTPUT is the result of `eval "${command}"` where command is built from user-supplied inputs (INPUT_SOURCE, INPUT_CONFIG, INPUT_REPORT_FORMAT, etc.)
- `echo "report=gitleaks-report.${INPUT_REPORT_FORMAT}" >> $GITHUB_OUTPUT` — INPUT_REPORT_FORMAT is a user-controlled input
- `echo "result=${GITLEAKS_RESULT}" >> $GITHUB_OUTPUT` — GITLEAKS_RESULT is derived from the eval output
- `echo "command=${command}" >> $GITHUB_OUTPUT` — command is built from user-controlled inputs
- `echo "exitcode=${exitcode}" >> $GITHUB_OUTPUT` — exitcode from eval of user-controlled command

Locations:

- `entrypoint.sh:82`
- `entrypoint.sh:83`
- `entrypoint.sh:84`
- `entrypoint.sh:85`
- `entrypoint.sh:86`

### suspicious-run-content (severity: high)

eval-dynamic: entrypoint.sh executes `OUTPUT=$(eval "${command}")` where `$command` is a string built from user-controlled inputs (INPUT_SOURCE, INPUT_CONFIG, INPUT_REPORT_FORMAT, INPUT_REDACT, INPUT_FAIL, INPUT_VERBOSE, INPUT_LOG_LEVEL, INPUT_NO_GIT). Using `eval` with a dynamically constructed variable allows an attacker who controls any of these inputs to inject arbitrary shell commands into the runner. The pattern `eval "${command}"` matches the eval-dynamic check (`eval` followed by `$`).

Locations:

- `entrypoint.sh:80`

## Iteration Notes

### Iteration 1

**Fixes applied:** unpinned-uses, script-injection, missing-permissions, github-env-injection, suspicious-run-content

**Notes:**

Fixed all 5 findings:

1. unpinned-uses: Pinned all action references to full commit SHAs with tag comments. Pinned the Docker image in action.yml to its sha256 digest while preserving the docker:// scheme and :latest tag.

2. script-injection: In docker.yml, moved step output expressions (repo_owner, repo_name, gitleaks_latest_release semver) into env: block and referenced as shell variables. In dogfood.yml, moved all 5 gitleaks step output expressions into env: block.

3. missing-permissions: Added top-level permissions blocks to both workflows. docker.yml gets contents:read + packages:write (needed to push Docker images). dogfood.yml gets contents:read + security-events:write (needed to upload SARIF reports).

4. github-env-injection: In entrypoint.sh, all 5 GITHUB_OUTPUT writes now sanitize values using `printf '%s' ... | tr -d '\n\r'` before writing to prevent newline injection.

5. suspicious-run-content (eval-dynamic): In entrypoint.sh, replaced `eval "${command}"` with a bash array (cmd_args) that builds the gitleaks command safely and executes it directly as `"${cmd_args[@]}"`, eliminating the eval entirely.

