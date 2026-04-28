#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../ci/output.sh"
source "$SCRIPT_DIR/../ci/stage-result.sh"

main() {
  local prepare_result rust_result stage_ran stage_result combined_result

  prepare_result="$(ci_normalize_result "${PREPARE_RELEASE_RESULT:-skipped}")"
  rust_result="$(ci_normalize_result "${PREPARE_RELEASE_RUST_RESULT:-skipped}")"

  stage_ran=false
  # Matrix path runs when there are any non-Rust artifacts to bump.
  if [[ "${SHOULD_RUN_VERSION_BUMP:-false}" == 'true' && "${ARTIFACTS:-[]}" != '[]' ]]; then
    stage_ran=true
  fi
  # Rust single-job path runs when any Rust artifact is present.
  if [[ "${SHOULD_RUN_VERSION_BUMP:-false}" == 'true' && "${HAS_RUST:-false}" == 'true' ]]; then
    stage_ran=true
  fi

  # Combined result precedence (matches GitHub Actions composite semantics):
  # failure > cancelled > success > skipped.
  if [[ "$prepare_result" == "failure" || "$rust_result" == "failure" ]]; then
    combined_result="failure"
  elif [[ "$prepare_result" == "cancelled" || "$rust_result" == "cancelled" ]]; then
    combined_result="cancelled"
  elif [[ "$prepare_result" == "success" || "$rust_result" == "success" ]]; then
    combined_result="success"
  else
    combined_result="skipped"
  fi

  if [[ "$stage_ran" != "true" ]]; then
    stage_result="skipped"
  else
    stage_result="$combined_result"
  fi

  local targets_json result_json
  targets_json="$(ci_build_targets_json "version-bump:$prepare_result" "version-bump-rust:$rust_result")"
  result_json="$(ci_stage_result_json "prepare" "$stage_result" "$stage_ran" "$targets_json")"

  ci_output "stage-ran" "$stage_ran"
  ci_output "stage-result" "$stage_result"
  ci_output "result-json" "$result_json"
}

main "$@"
