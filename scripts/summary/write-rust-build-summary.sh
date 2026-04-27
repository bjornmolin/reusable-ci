#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../ci/output.sh"

main() {
  readonly RUST_TOOLCHAIN="${RUST_TOOLCHAIN:?RUST_TOOLCHAIN is required}"
  readonly TOOLCHAIN_SOURCE="${TOOLCHAIN_SOURCE:-input}"
  readonly WORKING_DIRECTORY="${WORKING_DIRECTORY:-.}"
  readonly SKIP_TESTS="${SKIP_TESTS:-false}"
  readonly UPLOAD_BINARIES="${UPLOAD_BINARIES:-false}"
  readonly ENABLE_BUILD_SBOM="${ENABLE_BUILD_SBOM:-true}"

  {
    printf "## Rust Build Summary 🦀\n"
    printf "\n"
    printf "%s **Toolchain:** \`%s\` (source: %s)\n" "-" "$RUST_TOOLCHAIN" "$TOOLCHAIN_SOURCE"
    printf "%s **Working directory:** \`%s\`\n" "-" "$WORKING_DIRECTORY"
    ci_test_status "$SKIP_TESTS"
    if [[ "$UPLOAD_BINARIES" == "true" ]]; then
      printf "%s **Binaries uploaded:** ✅ rust-build-artifacts\n" "-"
    else
      printf "%s **Binaries uploaded:** ⊘ disabled (upload-binaries=false)\n" "-"
    fi
    if [[ "$ENABLE_BUILD_SBOM" == "true" ]]; then
      printf "%s **Build SBOM:** ✅ enabled\n" "-"
    else
      printf "%s **Build SBOM:** ⊘ disabled\n" "-"
    fi
    printf "\n"
    printf "*Build completed at %s*\n" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  } >>"$(ci_summary_file)"
}

main "$@"
