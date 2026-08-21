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
echo "----------------------------------"

echo "Setting Git safe directory (CVE-2022-24765)"
echo "git config --global --add safe.directory ${GITHUB_WORKSPACE}"
git config --global --add safe.directory "${GITHUB_WORKSPACE}"
echo "----------------------------------"

# Build command as an array to avoid eval and shell injection
cmd=(gitleaks detect)

if [ -f "${INPUT_CONFIG}" ]; then
  cmd+=(--config "${INPUT_CONFIG}")
fi

if [[ "${#INPUT_BASELINE_PATH}" -gt 0 && "${INPUT_BASELINE_PATH}" != "false" ]]; then
  cmd+=(--baseline-path "${INPUT_BASELINE_PATH}")
fi

if [[ "${#INPUT_REPORT_FORMAT}" -gt 0 && "${INPUT_REPORT_FORMAT}" != "false" ]]; then
  cmd+=(--report-format "${INPUT_REPORT_FORMAT}")
fi

if [[ "${INPUT_REDACT}" != "false" && "${#INPUT_REDACT}" -gt 0 ]]; then
  cmd+=(--redact)
fi

if [[ "${INPUT_VERBOSE}" != "false" && "${#INPUT_VERBOSE}" -gt 0 ]]; then
  cmd+=(--verbose)
fi

if [[ "${#INPUT_LOG_LEVEL}" -gt 0 && "${INPUT_LOG_LEVEL}" != "false" ]]; then
  cmd+=(--log-level "${INPUT_LOG_LEVEL}")
fi

cmd+=(--report-path "${GITHUB_WORKSPACE}/gitleaks-report.${INPUT_REPORT_FORMAT}")

if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
  cmd+=(--source "${GITHUB_WORKSPACE}")

  base_sha=$(git rev-parse "refs/remotes/origin/${GITHUB_BASE_REF}")
  head_sha=$(git rev-list --no-merges -n 1 refs/remotes/pull/${GITHUB_REF_NAME})
  cmd+=(--log-opts "--no-merges --first-parent ${base_sha}^..${head_sha}")
else
  if [[ "${#INPUT_SOURCE}" -gt 0 && "${INPUT_SOURCE}" != "false" ]]; then
    cmd+=(--source "${INPUT_SOURCE}")
  fi
  if [[ "${INPUT_NO_GIT}" != "false" && "${#INPUT_NO_GIT}" -gt 0 ]]; then
    cmd+=(--no-git)
  fi
fi

# Build a display string of the command (for output/logging only)
command_str="${cmd[*]}"

echo "Running gitleaks $(gitleaks version)"
echo "----------------------------------"
echo "${command_str}"

OUTPUT=$("${cmd[@]}")
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

EOF=$(dd if=/dev/urandom bs=15 count=1 status=none | base64)
echo "output<<$EOF" >>"$GITHUB_OUTPUT"
echo -e "${OUTPUT}" >>"$GITHUB_OUTPUT"
echo "$EOF" >>"$GITHUB_OUTPUT"

# Sanitize user-controlled values before writing to GITHUB_OUTPUT
safe_report_format=$(printf '%s' "${INPUT_REPORT_FORMAT}" | tr -d '\n\r')
safe_result=$(printf '%s' "${GITLEAKS_RESULT}" | tr -d '\n\r')
safe_command=$(printf '%s' "${command_str}" | tr -d '\n\r')
safe_exitcode=$(printf '%s' "${exitcode}" | tr -d '\n\r')

echo "report=gitleaks-report.${safe_report_format}" >>"$GITHUB_OUTPUT"
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
