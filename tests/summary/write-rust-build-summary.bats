#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2119,SC2120,SC2155
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: CC0-1.0

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/../libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/../libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/../libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  common_setup_with_github_env
  export RUST_TOOLCHAIN="1.94.0"
  export TOOLCHAIN_SOURCE="rust-toolchain.toml"
  export WORKING_DIRECTORY="."
  export SKIP_TESTS="false"
  export UPLOAD_BINARIES="false"
  export ENABLE_BUILD_SBOM="true"
}

teardown() {
  common_teardown
}

@test "write-rust-build-summary writes header and toolchain" {
  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "Rust Build Summary"
  assert_output --partial '`1.94.0`'
  assert_output --partial "source: rust-toolchain.toml"
}

@test "write-rust-build-summary reflects skipped tests" {
  export SKIP_TESTS="true"

  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "⊘ Skipped"
}

@test "write-rust-build-summary shows binaries disabled by default" {
  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "Binaries uploaded:** ⊘ disabled"
}

@test "write-rust-build-summary shows binaries enabled when opted in" {
  export UPLOAD_BINARIES="true"

  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "Binaries uploaded:** ✅ rust-build-artifacts"
}

@test "write-rust-build-summary shows sbom disabled when opted out" {
  export ENABLE_BUILD_SBOM="false"

  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "Build SBOM:** ⊘ disabled"
}

@test "write-rust-build-summary defaults toolchain source when unset" {
  unset TOOLCHAIN_SOURCE

  run_script "summary/write-rust-build-summary.sh"

  assert_success
  run get_summary
  assert_output --partial "source: input"
}

@test "write-rust-build-summary fails when RUST_TOOLCHAIN missing" {
  unset RUST_TOOLCHAIN

  run_script "summary/write-rust-build-summary.sh"

  assert_failure
}
