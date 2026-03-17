# Rust Development Rules

Focus on code quality, safety, security, and reliability.

This project enforces Rust best practices using nightly tooling, aggressive linting, undefined behavior detection, dependency auditing (with `cargo-deny`), comprehensive CI, and Licensing.

## Prerequisites

### cargo-llvm-cov (Required)

`cargo-llvm-cov` is **mandatory** for this project. The pre-push hook and `smoke-test.sh` will **hard-fail** if it is not installed.

**Install via cargo:**

```bash
cargo +nightly install cargo-llvm-cov
```

**Install via Homebrew (macOS/Linux):**

```bash
brew install cargo-llvm-cov
```

**Verify installation:**

```bash
cargo llvm-cov --version
```

For more options, see: https://github.com/taiki-e/cargo-llvm-cov#installation

> ⚠️ Without `cargo-llvm-cov` installed, you will **not** be able to push commits. This is intentional — coverage checking is a hard requirement, not optional.

### TruffleHog (Required)

TruffleHog is **mandatory** for this project. The pre-push hook and `smoke-test.sh` will **hard-fail** if it is not installed.

**Install via Homebrew (macOS/Linux):**

```bash
brew install trufflehog
```

**Install via install script (Linux):**

```bash
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
```

**Verify installation:**

```bash
trufflehog --version
```

For more options, see: https://github.com/trufflesecurity/trufflehog#installation

> ⚠️ Without `trufflehog` installed, you will **not** be able to push commits. This is intentional — secret scanning is a hard requirement, not optional.

## Key Features

- **Nightly Rust toolchain** with `rustfmt`, `clippy`, and `miri` (`rust-toolchain.toml`)
- **Strict Clippy rules** banning `unwrap()`, `expect()`, and requiring documentation on `unsafe` blocks
- **Miri** for detecting undefined behavior in tests
- **cargo-deny** for license compliance, vulnerability scanning, yanked crate blocking, and source restrictions
- **Opinionated rustfmt** configuration for consistent code style
- **Optimized GitHub Actions CI** that runs checks only on changed `.rs` files
- **Compile-time denials** for common anti-patterns (configured in `lib.rs`)
- **Git pre-push hook** that automatically runs formatting, tests, Miri, Clippy, and deny checks before pushing commits
- **Git pre-commit hook** that checks for latest rust_template changes
- **Comprehensive .gitignore** to exclude build artifacts, temporary files, environment files, Docker outputs, and IDE/editor settings
- **License support** via `--private <name>` flag (creates proprietary LICENSE file) **or** `--name <name>` flag (creates MIT LICENSE file)
  - optionally set `RUST_OWNER` to use as the `<name>`

## Tooling Details

### Rust Toolchain (`rust-toolchain.toml`)

Pins the project to the latest `nightly` channel with essential components:

```toml
channel = "nightly"
components = ["rustfmt", "clippy", "miri"]
profile = "minimal"
```

### rustfmt (`rustfmt.toml`)

Enforces consistent formatting:

- 4-space indentation
- 100 character line width
- Trailing commas where possible
- Unix newlines
- Reordered imports

### Clippy (`clippy.toml` + `lib.rs`)

Bans footguns via `disallowed-methods`:

- `Option::unwrap` / `expect`
- `Result::unwrap` / `expect`

Additional compile-time denials in `lib.rs`:

```rust
#![deny(clippy::disallowed_methods)]
#![deny(clippy::unwrap_used)]
#![deny(clippy::expect_used)]
#![deny(clippy::undocumented_unsafe_blocks)]
#![deny(unsafe_op_in_unsafe_fn)]
```

### Miri

Miri interprets Rust MIR to catch undefined behavior (UB) such as invalid memory access, uninitialized reads, and more.

The CI runs:

```bash
cargo +nightly miri test --all-targets --all-features
```

**Resources**:
- Official repository: https://github.com/rust-lang/miri
- Documentation & usage: https://github.com/rust-lang/miri/blob/master/README.md
- Undefined Behavior in Rust: https://doc.rust-lang.org/reference/behavior-considered-undefined.html

### Test Utilities (`mae::testing`)

The template no longer ships a local `tests/must.rs` helper.

Use the test helper utilities provided by the `mae` library (`mae::testing`) instead.
This keeps test helper behavior centralized and avoids template-specific duplication.

### cargo-deny (`deny.toml` & `deny.exceptions.toml`)

Enforces workspace-wide dependency policy:

- Allowed licenses: `MIT`, `Apache-2.0`, `BSD-3-Clause`, `ISC`, `MPL-2.0`
- Blocks known vulnerabilities and yanked crates
- Restricts sources to `crates.io` and your GitHub repositories

[read the `cargo-deny` docs](https://embarkstudios.github.io/cargo-deny/checks/bans/cfg.html)

### GitHub Actions CI (`.github/workflows/ci.yml`)

Triggers on PR to `main` or `production`. Runs four parallel jobs after **Mission Brief** (config parsing):

- **🔐 Secret Scan** — trufflehog scan of the last commit
- **🦀 Ferris Says No Bugs** — rustfmt, clippy, llvm-cov coverage, cargo-deny
- **🔌 Connection Check** → **⚙️ Integration Gauntlet** — connectivity probe then integration tests via `bash scripts/int-test.sh --ci`

Coverage threshold is read from `.ci/ci_env.toml` (`coverage_threshold` key, default 45%).

#### Configuring service-specific secrets

Service-specific host secrets use **standard names** set per-repo by the ansible `k8s-bootstrap` playbook. The CI workflow injects them directly — no declarations needed in `.ci/ci_env.toml`.

`.ci/ci_env.toml` only needs the local dev flags:

```toml
coverage_threshold = 45
en...

## Local Dev with Docker Compose Watch

This template includes a fast local development loop powered by **Docker Compose Watch** and **cargo-watch** inside a dev container.

- Uses `Dockerfile.dev`, which pre-cooks dependencies using **cargo-chef**. This keeps rebuilds fast as long as `Cargo.lock` doesn't change.
- Running `docker compose up --watch` starts your services and watches for relevant file changes on the host.
- The `develop.watch` section in the compose file syncs `src/` (and related) changes from your workstation into the running container.
- Inside the container, `cargo-watch` (via `scripts/boot.sh`) detects these synced changes and triggers an **incremental recompile + restart** of the application.
- Expected cycle time for typical code changes is **~5–30 seconds**, depending on change size and machine resources.
- Changes to dependencies (i.e., updates to `Cargo.toml` / `Cargo.lock`) invalidate the cargo-chef cache and trigger a **full dev image rebuild**, which is slower (**~2–5 minutes**), but only happens when deps change.
