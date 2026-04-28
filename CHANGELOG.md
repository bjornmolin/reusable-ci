# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — v2.8.0 (SBOM surface enhancements)

Default orchestrator-only consumers see no behaviour change. The SBOM surface
gains a CISA-aligned per-artefact enum, container scanning is now derived from
source-artefact configuration, and the SBOM generator script picks up a
flag-based CLI. Removed/renamed fields below only matter for consumers that set
SBOM options explicitly (none have, in practice — defaults preserve the prior
contract end-to-end).

### Added

- **Rust version-bump support** in `version-bump.yml` via `cargo-edit`'s
  `cargo set-version`. Workspaces are bumped uniformly with `--workspace`;
  single-crate projects bump in place. To avoid matrix races when multiple
  Rust artefacts share one Cargo workspace, `release-prepare-stage.yml`
  dispatches Rust through a dedicated single-job path
  (`execute-version-bump-rust`) at the workspace root, while the existing
  matrix continues to handle non-Rust artefacts. The `rust` file pattern
  in `get-file-pattern.sh` now uses `:(glob)**/Cargo.toml` so workspace
  member version updates are committed alongside the root `Cargo.lock`.
  `cargo-edit` is pinned to `0.13.7` and its `cargo-set-version` binary
  is cached across runs. Per-crate independent versioning remains out of
  scope (set `release.skipversionbump: true` and manage manually).
- **Rust first-class support** (Phases 1-3). `build-rust.yml` is now a
  full builder — `cargo build --release` + `cargo test` + CycloneDX SBOM
  via `cargo-cyclonedx`. Toolchain auto-detects `rust-toolchain.toml`
  when present, otherwise uses the `rust-toolchain` input. New
  `apt-packages` input installs native deps before building.
  `upload-binaries: false` by default to preserve SBOM-only behaviour
  for existing direct callers.
- `release-orchestrator.yml` now dispatches `build-rust.yml` for `rust`
  artefacts in `artifacts.yml` exactly like npm/maven. `rust-artifacts`
  flows through `release-build-stage.yml` → `summarize-build-stage`
  → `write-build-stage-result.sh`. Per-artefact `config.rust-toolchain`
  is honoured.
- New `lint-rust.yml` workflow with four independently-togglable jobs:
  `cargo fmt --check`, `cargo clippy`, `cargo audit`, and (opt-in)
  `cargo deny check`. Mirrors the swift two-flag dispatch pattern.
  `apt-packages` input on the clippy job for crates with native deps.
- `pullrequest-orchestrator.yml` gains three new sub-flags —
  `linters.clippy`, `linters.rustfmt`, `linters.cargoaudit` (all default
  false). `write-pr-interface.sh` emits an umbrella `rust` policy bool
  that gates the rust-lint dispatch in `pullrequest-quality-stage.yml`.
  A new top-level string input `rust.apt-packages` is forwarded to
  `lint-rust.yml`'s `apt-packages` job input so clippy can compile crates
  with native deps.
- `release-build-stage.yml`'s `build-rust` matrix now forwards
  `apt-packages`, `cargo-args`, `test-args`, and `skip-tests` from each
  artefact's `config:` block to `build-rust.yml`. Without this, those
  builder inputs were unreachable from the orchestrator path.
- `examples/rust-app/` — full configuration example mirroring the npm
  / maven examples.
- `scripts/summary/write-rust-build-summary.sh` — per-artefact build
  summary in the GitHub step summary, matching the npm/maven helper.


### Changed

- Container SBOM scanning is now **derived** from each source artefact's
  `sboms` — the container is scanned if any source includes
  `analyzed-container` in its effective sboms. Single source of truth.
- Per-stack builders skip the cyclonedx plugin step entirely when `build` is
  not in the artefact's effective sboms (was: always ran with
  `continue-on-error: true`). Saves CI time on monorepos with `sboms: none`
  artefacts.
- Source layer dropped from the user-facing surface: `sboms` no longer accepts
  `source`. Build SBOM is strictly richer for ecosystems that support it;
  analyzed-artifact covers the rest. The layer code remains internal but no
  orchestrator passes it.

### Removed

- `artifacts.yml` per-artefact `generate-sbom: bool` field. Silently ignored
  if still present.
- `artifacts.yml` per-container `enable-sbom: bool` field. Silently ignored
  if still present.
- `release-orchestrator.yml` input `release.generatesbom`. Replaced by
  `release.sboms`.

### Renamed

- SBOM generator script: `generate-sbom.sh` → `generate-sboms.sh`.
- Job: `generate-dev-sbom` → `generate-dev-sboms`.
- Container SBOM artefact: `container-sbom-<run-id>` →
  `analyzed-container-sbom-<run-id>`.
- SBOM filenames inside the release zip — unified to
  `<artefact>-<version>-<sha>-<cisa-type>-sbom.<fmt>.json`. Specifically:
  `*-jar-sbom.*` → `*-analyzed-jar-sbom.*`,
  `*-tararchive-sbom.*` → `*-analyzed-tararchive-sbom.*`,
  `*-container-sbom.*` → `*-analyzed-container-sbom.*`,
  `*-binary-sbom.*` (Rust/Go) → `*-analyzed-binary-sbom.*`,
  `*-wheel-sbom.*` (Python) → `*-analyzed-wheel-sbom.*`. Short commit SHA
  is now injected for traceability across all SBOM filenames (was only on
  build SBOM previously). Build SBOM filename is unchanged.
- `publish-container.yml` input: `enable-sbom` → `enable-analyzed-container-sbom`
  (matches the CISA layer name and the existing `enable-X` family).
- Helper function: `_find_shallowest_bom` → `_find_build_bom`.
- Plan output: `should-generate-sbom` → `effective-sboms` (string carrying
  the layer list, not a bool).
- Parse output: `needs-sbom` → `pipeline-sboms` (string, the union across
  artefacts).

### Fixed

- `ci/output.sh` no longer reassigns `SCRIPT_DIR` at source-time, removing
  a footgun for any script that sources it and uses its own `SCRIPT_DIR`.
- `_find_build_bom` (formerly `_find_shallowest_bom`) now uses deterministic
  tie-break (`sort -k1,1n -k2,2`) when multiple BOMs share a depth.
- `release-dev` publish-stage summary now surfaces `generate-dev-sboms` job
  status.

### Migration (only if you set SBOM options explicitly)

| If you had…                                                | Change to                                                         |
|------------------------------------------------------------|-------------------------------------------------------------------|
| `artifacts.yml` artefact `generate-sbom: true`             | `sboms: all` (or omit — `all` is the default for buildable types) |
| `artifacts.yml` artefact `generate-sbom: false`            | `sboms: none`                                                     |
| `artifacts.yml` container `enable-sbom: true`              | Delete the line (default behaviour unchanged)                     |
| `release-orchestrator.yml` caller using `release.generatesbom: true`  | `release.sboms: all` (or omit)                          |
| `release-orchestrator.yml` caller using `release.generatesbom: false` | `release.sboms: none`                                   |
| Direct caller of `publish-container.yml` with `enable-sbom: true`     | `enable-analyzed-container-sbom: true`                  |
| Workflow downloading `container-sbom-<run-id>`             | Download `analyzed-container-sbom-<run-id>`                       |
| Workflow depending on plan output `should-generate-sbom` (bool)       | Use `effective-sboms` (string) — non-empty means generate         |
| Workflow depending on parse output `needs-sbom` (bool)     | Use `pipeline-sboms` (string) — non-empty means generate          |

## [2.7.9] - 2026-04-14

### Fixed

- Bump gommitlint
- Split SARIF upload into its own job

## [2.7.8] - 2026-04-14

### Fixed

- Move scorecard SARIF token to step env and guard script checkouts


## [2.7.7] - 2026-04-13

### Added

- Add OpenGrep SAST support to reusable CI
- Add build SBOM layer via CycloneDX Maven plugin

### Changed

- Rename SBOM layers to CISA taxonomy

### Fixed

- Argument list to sarif upload take two
- Argument list to sarif upload
- Dont use expressions in run steps
- Reset working tree after install to prevent false lint failures
- Jar SBOM missing for artefacts without version suffix


## [2.7.6] - 2026-04-02

### Changed

- Improve readme


## [2.7.5] - 2026-04-01

### Changed

- Update mise tools (#93)
- Update dependency itiquette/gommitlint to v0.9.5 (#92)
- Update italia/publiccode-parser-action action to v1.5.0 (#91)
- Update dependency jdx/mise to v2026.3.10 (#90)
- Update dependency diggsweden/devbase-check to v0.4.2 (#89)

### Fixed

- Fix failing gitleaks lint
- Fix: allow containerfiles starting with Containerfile and Dockerfile
- Improve feedback in npm release dev flow


## [2.7.4] - 2026-03-26

### Changed

- Change sarif upload flow


## [2.7.3] - 2026-03-23

### Fixed

- Fix lintproblem
- Workaround the stricter gh 6 action


## [2.7.2] - 2026-03-23

### Changed

- Update github actions
- Clearify we dont need ref ci for scorecard
- Replace dependency-review-action with Trivy-based scanner
- Extract shared CI helpers and consolidate inline workflow logic
- Update mise tools (#85)

### Fixed

- Use available trivy
- Dont use hardcoded tmp in ci


## [2.7.1] - 2026-03-20

### Added

- Add recommended ref ci examples etc

### Fixed

- Correct path for extra commitlint


## [2.7.0] - 2026-03-18

### Changed

- Improve maintainability

### Fixed

- Clean up after major refactoring


## [2.6.2] - 2026-03-13

### Added

- Add BUILD_NUMBER for xcode-ios build
- Add missing versions lint
- Add support for xcodegen in build-xcode-ios

### Changed

- Read XCCONFIG_BASE64 in xcode-ios build
- Read SECRETS_PROPERTIES_BASE64 from secrets
- Replace conform with gommitlint

### Fixed

- Failing test
- Wire xcodegen config through release orchestration


## [2.6.1] - 2026-03-04

### Changed

- Update github actions (#68)
- Clean up examples etc for 2.6.0

### Fixed

- Bump trivy and other deps
- Exit if uploading IPA to App Store fails


## [2.6.0] - 2025-12-18

### Added

- Add devbasecheck support


## [2.5.0] - 2025-12-17

### Changed

- Improve android app support
- Migrate to devbase-check
- Update mise tools (#65)
- Update github/codeql-action action to v4.31.7 (#66)
- Improve bats tests
- Update mise tools (#63)
- Update actions/checkout action to v6
- Update github actions (#62)
- Minor doc fix


## [2.4.3] - 2025-12-12

### Added

- Add experimental play store support
- Add bats shellcheck exceptions
- Add initial bats test suite
- Add initial bats test suite

### Fixed

- Dont break on printf


## [2.4.2] - 2025-12-08

### Added

- Add default exclude lint jobs
- Add more artifact search paths for sbom

### Changed

- Pass lint
- Improve justfile


## [2.4.1] - 2025-12-01

### Changed

- Dont add extra target to mvn artifact
- Set profile value


## [2.4.0] - 2025-12-01

### Added

- Add self and meta jobs for release
- Add idiomatic package check

### Changed

- Use devbase-justkit and fix lints
- Improve npm ci
- Set xconfig version
- Set license header to recommended style
- Rename build and publish pipes
- Extract bash scripts
- Improve bash code
- Improve bash code
- Improve headers
- Improve release maintenace
- Echo to printf
- Improve inline bash reading
- Dedupe mvn opts
- Standardsize scripts checkout
- Set default to main where was v1
- Pin versions of subscripts
- Clean up status scripts
- Update dependency anchore/syft to v1.38.0 (#60)
- Update mise tools (#59)
- Update github actions (#58)

### Fixed

- Dont run pr on commit to main
- Dont add empty checksum to release
- Pass artifact name to sbom zip
- Use maven name for jar artifact
- No container sbom try for libs
- Propagate summary env var
- Clear up ternary expressions
- Default java 25 and node 24
- Separate artifact from container
- Correct references branch
- Improve token handling
- Improve script strucutres
- Improve sbom generation
- Upload maven dev artifacts
- Minor optimizations
- Set githistory full only when needed
- Bump to latest lts for node and jvm

### Removed

- Remove e for debug
- Remove leading dashs printfs
- Remove token refactor residue
- Delete existing release draft


## [2.3.8] - 2025-11-25

### Changed

- Improve artifact naming

## [2.3.7] - 2025-11-25

### Changed

- Set macos-26 runner as default for xcode

## [2.3.6] - 2025-11-25

### Fixed

- Skip package plugin validation during archive

## [2.3.5] - 2025-11-25

### Changed

- Restore destination

## [2.3.4] - 2025-11-25

### Removed

- Remove archive dest

## [2.3.3] - 2025-11-25

### Fixed

- Dont enable skiptest for ios build arc

## [2.3.2] - 2025-11-25

### Added

- Add tag check for relase flow
- Add ios tool bump agvtool support

### Changed

- Update mise tools (#55)
- Update github actions (#54)

## [2.3.1] - 2025-11-20

### Added

- Add initial support for ios

### Fixed

- Fix swift lint
- Fix swift lint

## [2.3.0] - 2025-11-19

### Changed

- Expose android keystore path as env variable

## [2.2.5] - 2025-11-18

### Added

- Add env vars check to mise install

### Changed

- Update mise tools (#49)
- Update github actions (#48)
- Update docker/metadata-action action to v5.9.0 (#46)
- Update dependency anchore/syft to v1.37.0 (#45)
- Update dependency ubi:rvben/rumdl to v0.0.171 (#47)

### Fixed

- Update auto find poms
- Correct git glob pom handle

## [2.2.4] - 2025-11-10

### Added

- Add mise rate limit token, reuse install

### Changed

- Update github actions (#44)
- Update dependency ubi:rvben/rumdl to v0.0.170 (#43)

## [2.2.3] - 2025-11-06

### Fixed

- Build npm tarball name

## [2.2.2] - 2025-11-06

### Fixed

- Fix npm assets upload
- Fix github packages name

## [2.2.1] - 2025-11-05

### Changed

- Adjust default mvn pom deploy

## [2.2.0] - 2025-11-05

### Added

- Add mvn module support

### Changed

- Update mise tools (#39)
- Update github artifact actions
- Update github actions (#38)
- Update dependency anchore/syft to v1.36.0 (#37)

## [2.1.1] - 2025-10-31

### Changed

- Formatting + gitleaks ignore for examples

### Fixed

- Fix ref

## [2.1.0] - 2025-10-31

### Changed

- Handle linter metadata
- Improve shell target
- Improve just lint support
- Update mise tools (#35)
- Update github actions (#34)
- Update dependency anchore/syft to v1.34.2 (#33)
- Update github actions (#28)
- Update actions/setup-node action to v6
- Update dependency anchore/syft to v1.34.1 (#31)
- Update mise tools (#29)
- Use default branch

### Fixed

- Fix linting
- Always refer main

## [2.0.0] - 2025-10-19

### Changed

- Initial commit

[2.7.9]: https://github.com/diggsweden/reusable-ci/compare/v2.7.8..v2.7.9
[2.7.8]: https://github.com/diggsweden/reusable-ci/compare/v2.7.7..v2.7.8
[2.7.7]: https://github.com/diggsweden/reusable-ci/compare/v2.7.6..v2.7.7
[2.7.6]: https://github.com/diggsweden/reusable-ci/compare/v2.7.5..v2.7.6
[2.7.5]: https://github.com/diggsweden/reusable-ci/compare/v2.7.4..v2.7.5
[2.7.4]: https://github.com/diggsweden/reusable-ci/compare/v2.7.3..v2.7.4
[2.7.3]: https://github.com/diggsweden/reusable-ci/compare/v2.7.2..v2.7.3
[2.7.2]: https://github.com/diggsweden/reusable-ci/compare/v2.7.1..v2.7.2
[2.7.1]: https://github.com/diggsweden/reusable-ci/compare/v2.7.0..v2.7.1
[2.7.0]: https://github.com/diggsweden/reusable-ci/compare/v2.6.2..v2.7.0
[2.6.2]: https://github.com/diggsweden/reusable-ci/compare/v2.6.1..v2.6.2
[2.6.1]: https://github.com/diggsweden/reusable-ci/compare/v2.6.0..v2.6.1
[2.6.0]: https://github.com/diggsweden/reusable-ci/compare/v2.5.0..v2.6.0
[2.5.0]: https://github.com/diggsweden/reusable-ci/compare/v2.4.3..v2.5.0
[2.4.3]: https://github.com/diggsweden/reusable-ci/compare/v2.4.2..v2.4.3
[2.4.2]: https://github.com/diggsweden/reusable-ci/compare/v2.4.1..v2.4.2
[2.4.1]: https://github.com/diggsweden/reusable-ci/compare/v2.4.0..v2.4.1
[2.4.0]: https://github.com/diggsweden/reusable-ci/compare/v2.3.8..v2.4.0
[2.3.8]: https://github.com/diggsweden/reusable-ci/compare/v2.3.7..v2.3.8
[2.3.7]: https://github.com/diggsweden/reusable-ci/compare/v2.3.6..v2.3.7
[2.3.6]: https://github.com/diggsweden/reusable-ci/compare/v2.3.5..v2.3.6
[2.3.5]: https://github.com/diggsweden/reusable-ci/compare/v2.3.4..v2.3.5
[2.3.4]: https://github.com/diggsweden/reusable-ci/compare/v2.3.3..v2.3.4
[2.3.3]: https://github.com/diggsweden/reusable-ci/compare/v2.3.2..v2.3.3
[2.3.2]: https://github.com/diggsweden/reusable-ci/compare/v2.3.1..v2.3.2
[2.3.1]: https://github.com/diggsweden/reusable-ci/compare/v2.3.0..v2.3.1
[2.3.0]: https://github.com/diggsweden/reusable-ci/compare/v2.2.5..v2.3.0
[2.2.5]: https://github.com/diggsweden/reusable-ci/compare/v2.2.4..v2.2.5
[2.2.4]: https://github.com/diggsweden/reusable-ci/compare/v2.2.3..v2.2.4
[2.2.3]: https://github.com/diggsweden/reusable-ci/compare/v2.2.2..v2.2.3
[2.2.2]: https://github.com/diggsweden/reusable-ci/compare/v2.2.1..v2.2.2
[2.2.1]: https://github.com/diggsweden/reusable-ci/compare/v2.2.0..v2.2.1
[2.2.0]: https://github.com/diggsweden/reusable-ci/compare/v2.1.1..v2.2.0
[2.1.1]: https://github.com/diggsweden/reusable-ci/compare/v2.1.0..v2.1.1
[2.1.0]: https://github.com/diggsweden/reusable-ci/compare/v2.0.0..v2.1.0

<!-- generated by git-cliff -->
