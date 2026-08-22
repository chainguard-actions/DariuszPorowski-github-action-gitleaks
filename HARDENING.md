<!-- markdownlint-disable -->

# Hardening Report: DariuszPorowski--github-action-gitleaks/v2.1.0

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **DariuszPorowski--github-action-gitleaks/v2.1.0** was hardened automatically. 5 finding(s) were identified and resolved across 3 iteration(s).

## Findings Fixed

### unpinned-uses (severity: high)

Multiple workflow files use mutable tag-based refs for `uses:` steps instead of pinned 40-character SHA digests. This exposes the workflow to supply-chain attacks if a tag is moved or a dependency is compromised. Affected references include: actions/github-script@v7 (docker.yml, dogfood.yml), actions/checkout@v4 (docker.yml, dogfood.yml), docker/login-action@v3 (docker.yml), docker/metadata-action@v5 (docker.yml), docker/build-push-action@v6 (docker.yml), release-drafter/release-drafter@v6 (release-draft.yml), softprops/action-gh-release@v2 (release-publish.yml), actions/publish-action@v0.3.0 (release-publish.yml), github/codeql-action/upload-sarif@v3 (dogfood.yml).

Locations:

- `.github/workflows/docker.yml:22`
- `.github/workflows/docker.yml:28`
- `.github/workflows/docker.yml:57`
- `.github/workflows/docker.yml:63`
- `.github/workflows/docker.yml:70`
- `.github/workflows/docker.yml:82`
- `.github/workflows/dogfood.yml:18`
- `.github/workflows/dogfood.yml:30`
- `.github/workflows/dogfood.yml:47`
- `.github/workflows/release-draft.yml:14`
- `.github/workflows/release-publish.yml:20`
- `.github/workflows/release-publish.yml:26`

### missing-permissions (severity: medium)

docker.yml and dogfood.yml have no top-level `permissions:` key and none of their jobs define job-level `permissions:` blocks. Without explicit permissions, workflows run with the default (potentially write-all) token permissions, violating the principle of least privilege.

Locations:

- `.github/workflows/docker.yml:1`
- `.github/workflows/dogfood.yml:1`

### script-injection (severity: high)

GitHub Actions expressions are interpolated directly inside `run:` shell command strings, violating rule (a). In docker.yml, the 'Check - upgrade Gitleaks or not' step embeds `${{ steps.repo_owner.outputs.result }}`, `${{ steps.repo_name.outputs.result }}`, and `${{ steps.gitleaks_latest_release.outputs.semver }}` directly in a shell command: `pkgs=$(gh api /users/${{ steps.repo_owner.outputs.result }}/packages/container/${{ steps.repo_name.outputs.result }}/versions --jq '[.[] | select(.metadata.container.tags | index("${{ steps.gitleaks_latest_release.outputs.semver }}"))] | length')`. In dogfood.yml, the 'Get the output from the gitleaks step' run block directly interpolates `${{ steps.gitleaks.outputs.exitcode }}`, `${{ steps.gitleaks.outputs.result }}`, `${{ steps.gitleaks.outputs.command }}`, and `${{ steps.gitleaks.outputs.report }}` into echo commands. These step outputs could contain attacker-controlled content (e.g., from a PR branch) and allow command injection.

Locations:

- `.github/workflows/docker.yml:40`
- `.github/workflows/dogfood.yml:38`

### github-env-injection (severity: high)

entrypoint.sh writes multiple user-controlled values to $GITHUB_OUTPUT without sanitization (no `printf '%s' ... | tr -d '\n\r'` step). The `command` variable is assembled from user-supplied inputs (INPUT_SOURCE, INPUT_CONFIG, INPUT_BASELINE_PATH, INPUT_REPORT_FORMAT, INPUT_LOG_OPTS, etc.) and written unsanitized: `echo "command=${command}" >> "$GITHUB_OUTPUT"`. Similarly, `OUTPUT` (the raw gitleaks tool output), `GITLEAKS_RESULT`, and `INPUT_REPORT_FORMAT` are written to $GITHUB_OUTPUT without newline stripping. A malicious input containing newlines could inject arbitrary key=value pairs into the output context.

Locations:

- `entrypoint.sh:88`
- `entrypoint.sh:89`
- `entrypoint.sh:90`
- `entrypoint.sh:91`
- `entrypoint.sh:92`
- `entrypoint.sh:93`
- `entrypoint.sh:94`

### suspicious-run-content (severity: high)

entrypoint.sh uses `eval "${command}"` (eval-dynamic pattern) where `command` is a string assembled from user-controlled inputs (INPUT_SOURCE, INPUT_CONFIG, INPUT_BASELINE_PATH, INPUT_LOG_OPTS, INPUT_NO_GIT, etc.). An attacker who can control any of these inputs (e.g., via a crafted `source` or `log_opts` action input) could inject arbitrary shell commands that are executed via eval. Matching pattern: `eval $(...)`/`eval "$VAR"` with attacker-influenced variable.

Locations:

- `entrypoint.sh:82`

## Iteration Notes

### Iteration 1

**Fixes applied:** unpinned-uses, missing-permissions, script-injection, github-env-injection, suspicious-run-content

**Notes:**

Fixed all 5 findings:

1. **unpinned-uses**: Pinned all action refs to full SHA digests with tag comments:
   - actions/github-script@v7 → @f28e40c7f34bde8b3046d885e986cb6290c5673b
   - actions/checkout@v4 → @11d5960a326750d5838078e36cf38b85af677262
   - docker/login-action@v3 → @c94ce9fb468520275223c153574b00df6fe4bcc9
   - docker/metadata-action@v5 → @c299e40c65443455700f0fdfc63efafe5b349051
   - docker/build-push-action@v6 → @10e90e3645eae34f1e60eeb005ba3a3d33f178e8
   - release-drafter/release-drafter@v6 → @6a93d829887aa2e0748befe2e808c66c0ec6e4c7
   - softprops/action-gh-release@v2 → @3bb12739c298aeb8a4eeaf626c5b8d85266b0e65
   - actions/publish-action@v0.3.0 → @f784495ce78a41bac4ed7e34a73f0034015764bb
   - github/codeql-action/upload-sarif@v3 → @42947a340483f03ba47bb1a039b2c519aab3df85

2. **missing-permissions**: Added top-level permissions blocks to docker.yml (contents: read, packages: write) and dogfood.yml (contents: read, security-events: write).

3. **script-injection**: Moved all ${{ }} expressions out of run: shell strings into env: blocks in docker.yml and dogfood.yml.

4. **github-env-injection**: In entrypoint.sh, sanitized all values written to $GITHUB_OUTPUT using `printf '%s' | tr -d '\n\r'` before writing.

5. **suspicious-run-content**: Replaced `eval "${command}"` in entrypoint.sh with a bash array (cmd_args) built incrementally and executed directly as `"${cmd_args[@]}"`, eliminating shell injection risk.

### Iteration 1

**Fixes applied:** script-injection

**Notes:**

Fixed script injection in .github/workflows/docker.yml at line 43. The gh api URL argument was unquoted, allowing REPO_OWNER and REPO_NAME (sourced from step outputs) to inject shell metacharacters. Fixed by wrapping the URL in double quotes: `gh api "/users/${REPO_OWNER}/packages/container/${REPO_NAME}/versions"` so the variable expansions are properly quoted.

### Iteration 2

**Fixes applied:** unpinned-uses

**Notes:**

Pinned the Dockerfile base image from 'ghcr.io/gitleaks/gitleaks:latest' to 'ghcr.io/gitleaks/gitleaks:latest@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f'. The :latest tag is retained inline for readability while the SHA256 digest ensures the image is immutably pinned, eliminating the supply-chain risk from a mutable tag.

