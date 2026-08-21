<!-- markdownlint-disable -->

# Hardening Report: DariuszPorowski--github-action-gitleaks/v2.0.8

> This file was generated automatically by the hardening agent.

**Policy SHA:** `d636be7e43ef829af6e853da6b3c7566db9f72fe`

**Test Policy SHA:** `843adf9e4b8f85d0c08b27b9d0b09dd094b54702`

**Harden Agent Version:** `2`

Action **DariuszPorowski--github-action-gitleaks/v2.0.8** was hardened automatically. 5 finding(s) were identified and resolved across 3 iteration(s).

## Findings Fixed

### unpinned-uses (severity: high)

All `uses:` references in workflow files use mutable version tags instead of full 40-character SHA digests, making the action vulnerable to supply-chain attacks if a tag is moved or a dependency is compromised. Failing references include: actions/github-script@v6 (×2), actions/checkout@v3, docker/login-action@v2, docker/metadata-action@v4, docker/build-push-action@v4 (docker.yml); actions/github-script@v6, actions/checkout@v3, github/codeql-action/upload-sarif@v2 (dogfood.yml); release-drafter/release-drafter@v5 (release-draft.yml); softprops/action-gh-release@v1, actions/publish-action@v0.2.2 (release-publish.yml).

Locations:

- `.github/workflows/docker.yml:21`
- `.github/workflows/docker.yml:27`
- `.github/workflows/docker.yml:56`
- `.github/workflows/docker.yml:63`
- `.github/workflows/docker.yml:70`
- `.github/workflows/docker.yml:82`
- `.github/workflows/dogfood.yml:18`
- `.github/workflows/dogfood.yml:33`
- `.github/workflows/dogfood.yml:48`
- `.github/workflows/release-draft.yml:16`
- `.github/workflows/release-publish.yml:22`
- `.github/workflows/release-publish.yml:27`

### script-injection (severity: high)

Sub-rule (a): In docker.yml, the 'Check - upgrade Gitleaks or not' run block directly interpolates GitHub Actions expressions inside a shell command string: `pkgs=$(gh api /users/${{ steps.repo_owner.outputs.result }}/packages/container/${{ steps.repo_name.outputs.result }}/versions --jq '[.[] | select(.metadata.container.tags | index("${{ steps.gitleaks_latest_release.outputs.semver }}"))] | length')`. The step output values `steps.repo_owner.outputs.result`, `steps.repo_name.outputs.result`, and `steps.gitleaks_latest_release.outputs.semver` are interpolated directly into the shell command before the shell parses it, enabling command injection if any of those values contain shell metacharacters.

Locations:

- `.github/workflows/docker.yml:35`

### suspicious-run-content (severity: high)

eval-dynamic: entrypoint.sh executes `OUTPUT=$(eval "${command}")` where `$command` is a string dynamically constructed from user-controlled inherited environment variables (INPUT_SOURCE, INPUT_CONFIG, INPUT_BASELINE_PATH, INPUT_REPORT_FORMAT, INPUT_NO_GIT, INPUT_LOG_LEVEL, INPUT_REDACT, INPUT_VERBOSE). These variables are set by the calling workflow and are untrusted. An attacker who controls any of these inputs can inject arbitrary shell commands via the eval. For example, a malicious `INPUT_CONFIG` value containing shell metacharacters would be executed as part of the gitleaks command string.

Locations:

- `entrypoint.sh:79`

### github-env-injection (severity: high)

Multiple writes to $GITHUB_OUTPUT in entrypoint.sh use values derived from user-controlled inputs without the required sanitization step (`printf '%s' ... | tr -d '\n\r'`): (1) `echo "report=gitleaks-report.${INPUT_REPORT_FORMAT}" >> "$GITHUB_OUTPUT"` — INPUT_REPORT_FORMAT is a user-supplied input; (2) `echo "command=${command}" >> "$GITHUB_OUTPUT"` — $command is built from multiple user-supplied inputs; (3) `echo -e "${OUTPUT}" >> "$GITHUB_OUTPUT"` — $OUTPUT is the result of eval-ing the user-influenced command. A newline character in any of these values would allow an attacker to inject arbitrary key=value pairs into GITHUB_OUTPUT, potentially overwriting outputs consumed by downstream steps.

Locations:

- `entrypoint.sh:87`
- `entrypoint.sh:88`
- `entrypoint.sh:90`

### permissions (severity: medium)

missing-permissions: docker.yml has no top-level `permissions:` key and its `docker` job has no job-level `permissions:` key, so the workflow runs with the default (potentially broad) token permissions. dogfood.yml similarly has no top-level `permissions:` key and neither the `ghdiag` nor the `gitleaks` job defines job-level permissions. Both files should declare minimal explicit permissions.

Locations:

- `.github/workflows/docker.yml:1`
- `.github/workflows/dogfood.yml:1`

## Iteration Notes

### Iteration 1

**Fixes applied:** unpinned-uses, script-injection, suspicious-run-content, github-env-injection, permissions

**Notes:**

Fixed all 5 findings across 5 files:

1. docker.yml: Pinned all 6 action references to full SHAs (actions/github-script@v6 ×2, actions/checkout@v3, docker/login-action@v2, docker/metadata-action@v4, docker/build-push-action@v4). Added top-level permissions block (contents: read, packages: write). Fixed script injection in 'Check - upgrade Gitleaks or not' step by moving step output expressions to env vars (REPO_OWNER, REPO_NAME, GITLEAKS_SEMVER).

2. dogfood.yml: Pinned all 3 action references to full SHAs (actions/github-script@v6, actions/checkout@v3, github/codeql-action/upload-sarif@v2). Added top-level permissions block (contents: read, security-events: write) and job-level permissions for each job.

3. release-draft.yml: Pinned release-drafter/release-drafter@v5 to full SHA.

4. release-publish.yml: Pinned softprops/action-gh-release@v1 and actions/publish-action@v0.2.2 to full SHAs.

5. entrypoint.sh: Replaced eval-based command execution with a bash array (cmd) built argument-by-argument, eliminating shell injection risk. Added sanitization (printf '%s' ... | tr -d '\n\r') for all user-controlled values written to $GITHUB_OUTPUT to prevent newline injection.

### Iteration 2

**Fixes applied:** script-injection

**Notes:**

Fixed script injection in .github/workflows/dogfood.yml at the 'Get the output from the gitleaks step' run block. Moved all four directly-interpolated ${{ steps.gitleaks.outputs.exitcode }}, ${{ steps.gitleaks.outputs.result }}, ${{ steps.gitleaks.outputs.command }}, and ${{ steps.gitleaks.outputs.report }} expressions into the step's env: block as GITLEAKS_EXITCODE, GITLEAKS_RESULT, GITLEAKS_COMMAND, and GITLEAKS_REPORT respectively. The shell script now references these as plain environment variables (${GITLEAKS_EXITCODE}, etc.), preventing attacker-controlled output values from being interpreted as shell commands.

### Iteration 1

**Fixes applied:** unpinned-uses

**Notes:**

Pinned the Dockerfile base image `zricethezav/gitleaks:latest` to an immutable SHA256 digest: `zricethezav/gitleaks:latest@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f`. The tag is preserved inline for readability while the digest ensures the image is immutable and cannot be replaced by a supply-chain attacker.

