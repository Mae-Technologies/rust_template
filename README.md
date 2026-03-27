For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)

# Rust Template

A strict, modern Rust project template for Mae-Technologies services. Focused on code quality, safety, security, and reliability.

## Key Features

- **Nightly Rust toolchain** with `rustfmt`, `clippy`, and `miri` (`rust-toolchain.toml`)
- **Strict Clippy rules** — `unwrap_used` and `expect_used` denied via `[lints.clippy]` in `Cargo.toml` (applies only to user-written code, not external macro expansions like `serde_json::json!`)
- **Miri** for detecting undefined behavior in tests
- **cargo-deny** for license compliance, vulnerability scanning, yanked crate blocking, and source restrictions
- **ARC-based GitHub Actions CI** (`ci.yml`) — runs on PRs to `main`/`production` on self-hosted `mae-runner` nodes; three jobs: config read, integrity (smoke-test), and integration (full service stack)
- **Git pre-push hook** — runs format, tests, coverage, Clippy, cargo-deny, and TruffleHog secret scan before every push
- **Git pre-commit hook** — checks for unsynced rust_template changes
- **`sync_rust_template.sh`** — syncs template files into a target service repo; bumps `mae` to latest; removes deprecated files

---

## Lint Strategy

Unwrap/expect enforcement is done via **`Cargo.toml [lints.clippy]`**, not `clippy.toml disallowed-methods`:

```toml
[lints.clippy]
unwrap_used = "deny"
expect_used = "deny"
```

`disallowed-methods` fires on external macro expansions (including `serde_json::json!`), so we use `clippy::unwrap_used` instead, which only fires on user-written code.

Test code is exempt via `clippy.toml`:
```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
```

---

## CI Pipeline (`ci.yml`)

Runs on PRs targeting `main` or `production` using self-hosted `mae-runner` ARC nodes.

| Job | Purpose |
|-----|---------|
| `config` | Reads `configuration/base.yaml` + `configuration/test.yaml` and exports service credentials as job outputs |
| `integrity` | Runs `scripts/smoke-test.sh` (format, clippy, coverage, deny, TruffleHog) |
| `integration` | Spins up Postgres, Neo4j, RabbitMQ, Redis; runs `scripts/int-test.sh` |

**Key config files:**
- **`.ci/ci_env.toml`** — test runner engine (`nextest`, `cargo`, `miri`, `nothing`), CLI flags, env vars, coverage threshold
- **`configuration/base.yaml`** — base service config
- **`configuration/test.yaml`** — CI overrides applied on top of `base.yaml`

---

## Dev Workflow (`Dockerfile.dev`)

Services use a single-stage dev image (no cargo-chef pre-cook). The dev container:

1. Installs `cargo-watch` and `sqlx-cli`
2. Mounts source via Docker Compose Watch
3. On start: runs `dev-boot.sh` → `cargo fetch` → `cargo watch` → `dev-run.sh` (migrate + `cargo run`)

`dev-run.sh` handles migration failures gracefully — if migrations fail, the watcher stays alive and retries on the next file change.

---

## `sync_rust_template.sh`

Syncs template files into a target Rust service repo. Run from the **target service root** with `RUST_TEMPLATE_DIR` pointing at your local clone of this repo.

### Flags

| Flag | Description |
|------|-------------|
| `--force` / `-f` | Overwrite existing config files, workflow, hooks, DEVELOPMENT.md, and `configuration/` files |
| `--private NAME` | Generate a proprietary LICENSE file for `NAME`; accepts `RUST_OWNER` env var as fallback |
| `--name NAME` | MIT license for `NAME`; accepts `RUST_OWNER` env var as fallback |
| `--lib` | Library crate — skip `Dockerfile.*` sync |
| `--skip-mae-bump` | Skip bumping the `mae` dependency to latest |
| `--test` / `-t` | Skip pre-flight checks — useful for local testing |

### What gets synced

1. **Config files** — `clippy.toml`, `deny.toml`, `rust-toolchain.toml`, `rustfmt.toml`, `.gitignore`
2. **Workflow** — `.github/workflows/ci.yml`
3. **Configuration** — `configuration/base.yaml`, `configuration/test.yaml`, `configuration/dev.yaml`
4. **`.ci/` files** — all files under `.ci/` (e.g., `ci_env.toml`)
5. **`scripts/`** — `smoke-test.sh`, `int-test.sh`, `dev-boot.sh`, `dev-run.sh`
6. **Pre-push hook** — `.git-hooks/` → `.git/hooks/`
7. **DEVELOPMENT.md** — copied from template
8. **`[lints.clippy]`** — enforced in target `Cargo.toml` (idempotent)
9. **LICENSE** — generated from `--private` or `--name`
10. **`.cargo/config.toml`** — sets `git-fetch-with-cli = true`
11. **`.rust_template_version`** — version stamp
12. **README.md** — prepends a `DEVELOPMENT.md` link if not already present
13. **`mae` dep bump** — bumps `mae` to latest published version if present in `Cargo.toml`

### Deprecated file removal

On every sync, the following deprecated files are deleted from the target service if present:

- `.github/workflows/cooked-crab.yaml`
- `.github/workflows/rust-integrity-guard.yaml`
- `.ci/ci_tests.sh`
- `.ci/ci_tests.env`

---

## Usage

### New project setup

```bash
cargo new my-service
cd my-service
export RUST_TEMPLATE_DIR=/path/to/rust_template
bash $RUST_TEMPLATE_DIR/sync_rust_template.sh --private "1000482371 ONTARIO CORPORATION"
git config core.hooksPath .git-hooks
```

### Updating an existing project

```bash
cd /path/to/rust_template && git pull
cd /path/to/my-service
bash $RUST_TEMPLATE_DIR/sync_rust_template.sh --force --private "1000482371 ONTARIO CORPORATION"
```

### Library crates (no Docker)

```bash
bash $RUST_TEMPLATE_DIR/sync_rust_template.sh --lib --private "1000482371 ONTARIO CORPORATION"
```
