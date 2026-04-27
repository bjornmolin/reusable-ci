<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

# Rust Application Example

Simple Rust application with container build, full CI lints (clippy,
rustfmt, cargo audit), `cargo build`/`cargo test`, and SBOM generation.

## Project Structure

```text
my-rust-app/
├── src/
│   └── main.rs
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml          # Pin toolchain (recommended)
├── Containerfile
└── .github/
    ├── artifacts.yml
    └── workflows/
        ├── pullrequest-workflow.yml
        └── release-workflow.yml
```

## Configuration Files

### `.github/artifacts.yml`

See [artifacts.yml](artifacts.yml) in this directory.

Key points:
- Single Rust artifact, project-type `rust`
- Optional `config.rust-toolchain` (auto-detected from
  `rust-toolchain.toml` when present — preferred)
- Optional `config.apt-packages` for native dependencies
- Multi-platform container

### `.github/workflows/pullrequest-workflow.yml`

See [pullrequest-workflow.yml](pullrequest-workflow.yml). The
orchestrator dispatches `lint-rust.yml` whenever any of `linters.clippy`,
`linters.rustfmt`, or `linters.cargoaudit` is true.

### `.github/workflows/release-workflow.yml`

See [release-workflow.yml](release-workflow.yml).

## Pinning the toolchain

Add a `rust-toolchain.toml` at the repo root so PR lints, builds, and
local development all agree on the compiler version:

```toml
[toolchain]
channel = "1.94"
components = ["clippy", "rustfmt"]
profile = "minimal"
```

When this file is present, both `lint-rust.yml` and `build-rust.yml`
prefer it over their `rust-toolchain` input — toolchain is configured in
exactly one place.

## How to Use

1. **Copy files to your repository:**
   ```bash
   mkdir -p .github/workflows
   cp examples/rust-app/artifacts.yml .github/
   cp examples/rust-app/pullrequest-workflow.yml .github/workflows/
   cp examples/rust-app/release-workflow.yml .github/workflows/
   ```

2. **Customize:**
   - Update the artifact `name` in artifacts.yml
   - Add `config.apt-packages` if your crates need native libs
     (e.g. `"cmake libssl-dev pkg-config"` for rdkafka/openssl)
   - Pin `rust-toolchain.toml` if you haven't already

3. **Create first release:**
   ```bash
   git tag -s v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

## What Gets Built

- `cargo build --release --workspace` produces release binaries
- `cargo test --workspace` runs the test suite
- `cargo-cyclonedx` produces a CycloneDX SBOM from `Cargo.lock`
- Container image → `ghcr.io/org/repo:v1.0.0`
- Platforms → `linux/amd64`, `linux/arm64`

## Publishing to crates.io

Currently out of scope (tracked in TODO.md). Use `release-orchestrator.yml`
for GitHub releases + container publishing; publish to crates.io from a
separate job until first-class support lands.

## See Also

- [Artifacts Reference](../../docs/artifacts-reference.md)
- [SBOM Strategy](../../docs/sbom.md)
- [Components Reference](../../docs/components.md)
