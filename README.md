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
- **ARC-based GitHub Actions CI** (`ci.yml`) — runs on PRs to `main`/`production` on self-hosted `mae-runner` nodes; three jobs: config read, integrity (smoke-test), and integration (full service stack)
- **Compile-time denials** for common anti-patterns (configured in `lib.rs`)
- **Git pre-push hook** that automatically runs formatting, tests, coverage, Clippy, cargo-deny, and TruffleHog secret scanning before pushing
- **Git pre-commit hook** that checks for latest rust_template changes
- **`sync_rust_template.sh`** — syncs template files to a target service, including: config files, workflow (`ci.yml`), `configuration/` YAML files, `.ci/` files, `scripts/`, pre-push hook, DEVELOPMENT.md, and `[lints.clippy]` enforcement in `Cargo.toml`; also **removes deprecated files** from the target on every sync
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

## CI Pipeline (`ci.yml`)

The CI workflow runs on pull requests targeting `main` or `production` using **self-hosted ARC runners** (`mae-runner`). It has three jobs:

| Job | Purpose |
|-----|---------|
| `config` | Reads `configuration/base.yaml` + `configuration/test.yaml` (merged with `yq`) and exports service credentials as job outputs |
| `integrity` | Installs nightly Rust + `cargo-llvm-cov` + `cargo-deny`, then runs `scripts/smoke-test.sh` (format, clippy, coverage, deny, TruffleHog) |
| `integration` | Spins up Postgres, Neo4j, RabbitMQ, and Redis service containers, then runs `scripts/int-test.sh` against the full stack |

### Configuration files

- **`.ci/ci_env.toml`** — configures the test runner engine (`nextest`, `cargo`, `miri`, `nothing`), extra CLI flags, environment variables, and the coverage threshold (default: 45%). Read by both `scripts/smoke-test.sh` and `scripts/int-test.sh`.
- **`configuration/base.yaml`** — base service configuration (DB, broker, etc.)
- **`configuration/test.yaml`** — overrides applied on top of `base.yaml` during CI

---

## `sync_rust_template.sh`

Syncs template files into a target Rust service repo. Run it from the **target service's root directory** with `RUST_TEMPLATE_DIR` pointing at your local clone of this repo.

### Flags

| Flag | Description |
|------|-------------|
| `--force` / `-f` | Overwrite existing config files, workflow, hooks, DEVELOPMENT.md, and `configuration/` files |
| `--private NAME` | Generate a proprietary LICENSE file for `NAME`; accepts `RUST_OWNER` env var as fallback |
| `--name NAME` | Use MIT license for `NAME`; accepts `RUST_OWNER` env var as fallback |
| `--test` / `-t` | Skip pre-flight checks (remote validation, clean tree, up-to-date SHA) — useful for local testing |

### What gets synced

1. **Config files** — `clippy.toml`, `deny.toml`, `rust-toolchain.toml`, `rustfmt.toml`, `.gitignore` (skipped if they exist unless `--force`)
2. **Workflow** — `.github/workflows/ci.yml` (skipped if exists unless `--force`)
3. **Configuration** — `configuration/base.yaml`, `configuration/test.yaml` (skipped if they exist unless `--force`)
4. **`.ci/` files** — all files under `.ci/` (e.g., `ci_env.toml`) — skipped if they exist unless `--force`
5. **`scripts/`** — `scripts/smoke-test.sh`, `scripts/int-test.sh` (skipped if they exist unless `--force`)
6. **Pre-push hook** — `.git-hooks/` → `.git/hooks/` (skipped if hook exists unless `--force`)
7. **DEVELOPMENT.md** — copied from template (skipped if exists unless `--force`)
8. **`[lints.clippy]`** — enforced in target `Cargo.toml` (idempotent)
9. **LICENSE** — generated from `--private` or `--name`
10. **`.cargo/config.toml`** — sets `git-fetch-with-cli = true`
11. **`.rust_template_version`** — synced version stamp
12. **README.md** — prepends a `DEVELOPMENT.md` link if not already present

### Deprecated file removal

On every sync, the following deprecated files are **deleted** from the target service if present:

- `.github/workflows/cooked-crab.yaml`
- `.github/workflows/rust-integrity-guard.yaml`
- `.ci/ci_tests.sh`
- `.ci/ci_tests.env`

---

For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)

---

## Usage

### New project setup
1. Create a new project: `cargo new [project-name]`
2. Export `RUST_TEMPLATE_DIR` pointing to your local rust_template clone
3. Run `sync_rust_template.sh --name "Your Name"` (or `--private "Org Name"` for proprietary) from inside the new project directory — copies all config files, workflow, scripts, and enforces `[lints.clippy]` in `Cargo.toml`

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
