# TODO

## Multi-artifact version-bump race condition

The `execute-version-bump` job in `release-prepare-stage.yml` uses a matrix strategy.
When multiple artifacts each run their own version-bump, they race on `git push` and
`git tag --force`. The `release-sha` output from a matrix reusable workflow call takes
the value from the last-completing matrix leg, which may not be deterministic.

Single-artifact projects (the common case) are unaffected. Rust workspaces are
already handled via the dedicated `execute-version-bump-rust` single-job path
added in v2.8.0. For multi-artifact non-Rust projects (e.g. multiple Maven
modules in independent repos), consider extending the same single-job pattern.

## Rename `reusable-ci-ref` output in orchestrator

The `parse-config` job output `reusable-ci-ref` holds the pinned commit SHA of the
scripts checkout (resolved before any tag movement). The name suggests it is the
original ref input, but it is actually a resolved SHA used only for checking out
helper scripts. Consider renaming to `reusable-ci-sha` or `scripts-ref` to make
the intent clearer.

## Rust first-class support — Phase 4 (deferred)

v2.8.0 ships Rust as a full builder + linter + version-bump. The
release-side ergonomics still missing for Rust are:

- **`publish-cratesio.yml`** — analogous to `publish-mavencentral.yml` /
  `publish-npm.yml`. Wired into `release-orchestrator.yml` via
  `publish-to: [crates-io]`. Needs API token handling, dry-run support,
  and workspace publishing order.
- **`validate-release-prerequisites.yml` choices** — add a Rust path
  that asserts `Cargo.lock` is checked in and `cargo --version` matches
  `rust-toolchain.toml` channel.
- **Per-crate independent versioning** — today's bump-version supports
  uniform-workspace and single-crate. Workspaces where each member has
  an independent version need either an artefact-level
  `version-bump-mode: per-crate` flag or auto-detection of
  `[workspace.package].version` inheritance.

Track concrete progress via dedicated branches; each item is independent
and shippable as a v2.8.x patch or v2.9.0 minor.
