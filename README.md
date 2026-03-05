# Rust Template

A strict, modern Rust project template focused on code quality, safety, security, and reliability.

This template enforces Rust best practices using nightly tooling, aggressive linting, undefined behavior detection, dependency auditing, and comprehensive CI.

## Key Features

- **Nightly Rust toolchain** with `rustfmt`, `clippy`, and `miri` (`rust-toolchain.toml`)
- **Strict Clippy rules** — `unwrap_used` and `expect_used` are denied via `[lints.clippy]` in `Cargo.toml`, which applies only to user-written code (not external macro expansions like `serde_json::json!`)
- **`serde_json::json!` safe to use freely** — `clippy.toml` uses `allow-unwrap-in-tests` instead of `disallowed-methods`, so the json macro works without inline `#[allow]` attrs
- **Miri** for detecting undefined behavior in tests
- **cargo-deny** for license compliance, vulnerability scanning, yanked crate blocking, and source restrictions
- **Opinionated rustfmt** configuration for consistent code style
- **Optimized GitHub Actions CI** that runs all checks on push
- **Compile-time denials** for common anti-patterns (configured in `lib.rs`)
- **Git pre-push hook** that automatically runs formatting, tests, Miri, Clippy, audit, and deny checks before pushing
- **Git pre-commit hook** that checks for latest rust_template changes
- **`sync_rust_template.sh`** — syncs template files to a target service, including enforcing `[lints.clippy]` in its `Cargo.toml`
- **Comprehensive .gitignore**

---

## Lint Strategy

Unwrap/expect enforcement is done via **`Cargo.toml [lints.clippy]`**, not `clippy.toml disallowed-methods`:

```toml
# Cargo.toml (each service)
[lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
```

**Why not `disallowed-methods`?** The `disallowed-methods` lint fires on _all_ code including external macro expansions — which breaks `serde_json::json!` (it calls `.unwrap()` internally for OOM-only handling). The `clippy::unwrap_used` lint only fires on user-written code, so `json!` works freely.

Test code is exempt via `clippy.toml`:
```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
```

---

For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)

---

## Usage

### New project setup
1. Create a new project: `cargo new [project-name]`
2. Run `sync_rust_template.sh` inside the project directory — copies all config files and enforces `[lints.clippy]` in `Cargo.toml`

### Updating an existing project
1. `git pull` inside the `rust_template` directory
2. Run `sync_rust_template.sh --force --private "Your Org Name"` from the project directory

#### Recommendations When Forking

```bash
# Point git to the correct hooks directory
git config core.hooksPath .git-hooks

# Remove the sync script (not needed in forks)
rm sync_rust_template.sh
```
