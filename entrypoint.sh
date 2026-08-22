#!/bin/bash

set +e

function arg() {
  local _format="${1}"
  local _val="${2}"

  if [[ "${#_val}" == 0 || "${_val}" == "false" ]]; then
    return
  fi

  printf " ${_format}" "${_val}"
}

function default() {
  local _default="${1}"
  local _result="${2}"
  local _val="${3}"
  local _defaultifnotset="${4}"

  if [[ "${_defaultifnotset}" == "true" ]]; then
    if [ "${#_val}" = 0 ]; then
      echo "${_default}"
      return
    fi
  fi

  if [[ "${_val}" != "${_default}" ]]; then
    echo "${_result}"
  else
    echo "${_val}"
  fi
}

INPUT_SOURCE=$(default "${GITHUB_WORKSPACE}" "${GITHUB_WORKSPACE}/${INPUT_SOURCE}" "${INPUT_SOURCE}" 'true')
INPUT_CONFIG=$(default "/.gitleaks/UDMSecretChecks.toml" "${GITHUB_WORKSPACE}/${INPUT_CONFIG}" "${INPUT_CONFIG}" 'true')
INPUT_REPORT_FORMAT=$(default 'json' "${INPUT_REPORT_FORMAT}" "${INPUT_REPORT_FORMAT}" 'true')
INPUT_REDACT=$(default 'true' 'false' "${INPUT_REDACT}" 'true')
INPUT_FAIL=$(default 'true' 'false' "${INPUT_FAIL}" 'true')
INPUT_VERBOSE=$(default 'true' 'false' "${INPUT_VERBOSE}" 'true')
INPUT_LOG_LEVEL=$(default 'info' "${INPUT_LOG_LEVEL}" "${INPUT_LOG_LEVEL}" 'true')
INPUT_EXIT_CODE=$(default '1' '0' "${INPUT_EXIT_CODE}" 'true')
INPUT_MAX_DECODE_DEPTH=$(default '0' '0' "${INPUT_MAX_DECODE_DEPTH}" 'true')
INPUT_FOLLOW_SYMLINKS=$(default 'false' 'true' "${INPUT_FOLLOW_SYMLINKS}" 'true')

echo "----------------------------------"
echo "INPUT PARAMETERS"
echo "----------------------------------"
echo "INPUT_SOURCE: ${INPUT_SOURCE}"
echo "INPUT_CONFIG: ${INPUT_CONFIG}"
echo "INPUT_BASELINE_PATH: ${INPUT_BASELINE_PATH}"
echo "INPUT_REPORT_FORMAT: ${INPUT_REPORT_FORMAT}"
echo "INPUT_NO_GIT: ${INPUT_NO_GIT}"
echo "INPUT_REDACT: ${INPUT_REDACT}"
echo "INPUT_FAIL: ${INPUT_FAIL}"
echo "INPUT_VERBOSE: ${INPUT_VERBOSE}"
echo "INPUT_LOG_LEVEL: ${INPUT_LOG_LEVEL}"
echo "INPUT_EXIT_CODE: ${INPUT_EXIT_CODE}"
echo "INPUT_LOG_OPTS: ${INPUT_LOG_OPTS}"
echo "INPUT_MAX_DECODE_DEPTH: ${INPUT_MAX_DECODE_DEPTH}"
echo "INPUT_FOLLOW_SYMLINKS: ${INPUT_FOLLOW_SYMLINKS}"
echo "----------------------------------"

echo "Setting Git safe directory (CVE-2022-24765)"
echo "git config --global --add safe.directory ${GITHUB_WORKSPACE}"
git config --global --add safe.directory "${GITHUB_WORKSPACE}"
echo "----------------------------------"

# Build the gitleaks command as an array to avoid eval and shell injection
cmd_args=("gitleaks" "detect")

if [ -f "${INPUT_CONFIG}" ]; then
  cmd_args+=("--config" "${INPUT_CONFIG}")
fi

if [[ "${#INPUT_BASELINE_PATH}" -gt 0 && "${INPUT_BASELINE_PATH}" != "false" ]]; then
  cmd_args+=("--baseline-path" "${INPUT_BASELINE_PATH}")
fi

if [[ "${#INPUT_REPORT_FORMAT}" -gt 0 && "${INPUT_REPORT_FORMAT}" != "false" ]]; then
  cmd_args+=("--report-format" "${INPUT_REPORT_FORMAT}")
fi

if [[ "${INPUT_REDACT}" != "false" && "${#INPUT_REDACT}" -gt 0 ]]; then
  cmd_args+=("--redact")
fi

if [[ "${INPUT_VERBOSE}" != "false" && "${#INPUT_VERBOSE}" -gt 0 ]]; then
  cmd_args+=("--verbose")
fi

if [[ "${#INPUT_LOG_LEVEL}" -gt 0 && "${INPUT_LOG_LEVEL}" != "false" ]]; then
  cmd_args+=("--log-level" "${INPUT_LOG_LEVEL}")
fi

cmd_args+=("--report-path" "${GITHUB_WORKSPACE}/gitleaks-report.${INPUT_REPORT_FORMAT}")

if [[ "${#INPUT_EXIT_CODE}" -gt 0 && "${INPUT_EXIT_CODE}" != "false" ]]; then
  cmd_args+=("--exit-code" "${INPUT_EXIT_CODE}")
fi

if [[ "${#INPUT_MAX_DECODE_DEPTH}" -gt 0 && "${INPUT_MAX_DECODE_DEPTH}" != "false" ]]; then
  cmd_args+=("--max-decode-depth" "${INPUT_MAX_DECODE_DEPTH}")
fi

if [[ "${INPUT_FOLLOW_SYMLINKS}" != "false" && "${#INPUT_FOLLOW_SYMLINKS}" -gt 0 ]]; then
  cmd_args+=("--follow-symlinks")
fi

if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
  cmd_args+=("--source" "${GITHUB_WORKSPACE}")

  base_sha=$(git rev-parse "refs/remotes/origin/${GITHUB_BASE_REF}")
  head_sha=$(git rev-list --no-merges -n 1 "refs/remotes/pull/${GITHUB_REF_NAME}")
  cmd_args+=("--log-opts" "--no-merges --first-parent ${base_sha}...${head_sha}")
else
  if [[ "${#INPUT_LOG_OPTS}" -gt 0 && "${INPUT_LOG_OPTS}" != "false" ]]; then
    cmd_args+=("--log-opts" "${INPUT_LOG_OPTS}")
  fi
  cmd_args+=("--source" "${INPUT_SOURCE}")
  if [[ "${INPUT_NO_GIT}" != "false" && "${#INPUT_NO_GIT}" -gt 0 ]]; then
    cmd_args+=("--no-git")
  fi
fi

# Build a display string for logging (not used for execution)
command_display="${cmd_args[*]}"

echo "Running gitleaks $(gitleaks version)"
echo "----------------------------------"
echo "${command_display}"

OUTPUT=$("${cmd_args[@]}")
exitcode=$?

if [ ${exitcode} -eq 0 ]; then
  GITLEAKS_RESULT="✅ SUCCESS! Your code is good to go"
elif [ ${exitcode} -eq 1 ]; then
  GITLEAKS_RESULT="❌ STOP! Gitleaks encountered leaks or error"
else
  GITLEAKS_RESULT="Gitleaks unknown error"
fi

echo "----------------------------------"
echo -e "${OUTPUT}"

# Sanitize values before writing to GITHUB_OUTPUT to prevent newline injection
safe_command=$(printf '%s' "${command_display}" | tr -d '\n\r')
safe_result=$(printf '%s' "${GITLEAKS_RESULT}" | tr -d '\n\r')
safe_report=$(printf '%s' "gitleaks-report.${INPUT_REPORT_FORMAT}" | tr -d '\n\r')
safe_exitcode=$(printf '%s' "${exitcode}" | tr -d '\n\r')

EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
echo "output<<$EOF" >>"$GITHUB_OUTPUT"
echo -e "${OUTPUT}" >>"$GITHUB_OUTPUT"
echo "$EOF" >>"$GITHUB_OUTPUT"
echo "report=${safe_report}" >>"$GITHUB_OUTPUT"
echo "result=${safe_result}" >>"$GITHUB_OUTPUT"
echo "command=${safe_command}" >>"$GITHUB_OUTPUT"
echo "exitcode=${safe_exitcode}" >>"$GITHUB_OUTPUT"
echo -e "Gitleaks Summary: ${GITLEAKS_RESULT}\n" >>"$GITHUB_STEP_SUMMARY"
echo -e "${OUTPUT}" >>"$GITHUB_STEP_SUMMARY"

if [ ${exitcode} -eq 0 ]; then
  echo "::notice::${GITLEAKS_RESULT}"
elif [ ${exitcode} -eq 1 ]; then
  if [ "${INPUT_FAIL}" = "true" ]; then
    echo "::error::${GITLEAKS_RESULT}"
  else
    echo "::warning::${GITLEAKS_RESULT}"
    exit 0
  fi
else
  echo "::error::${GITLEAKS_RESULT}"
fi
exit ${exitcode}
