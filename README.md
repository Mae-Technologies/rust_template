# Rust Template

A strict, modern Rust project template focused on code quality, safety, security, and reliability.

This template enforces Rust best practices using nightly tooling, aggressive linting, undefined behavior detection, dependency auditing, and comprehensive CI.

## Key Features

- **Nightly Rust toolchain** with `rustfmt`, `clippy`, and `miri` (`rust-toolchain.toml`)
- **Strict Clippy rules** banning `unwrap()`, `expect()`, and requiring documentation on `unsafe` blocks
- **Miri** for detecting undefined behavior in tests
- **cargo-deny** for license compliance, vulnerability scanning, yanked crate blocking, and source restrictions
- **Opinionated rustfmt** configuration for consistent code style
- **Optimized GitHub Actions CI** that runs checks only on changed `.rs` files
- **Compile-time denials** for common anti-patterns (configured in `lib.rs`)
- **Git pre-push hook** that automatically runs formatting, tests, Miri, Clippy, audit, and deny checks before pushing commits
- **Git pre-commit hook** that checks for latest rust_template changes
- **Comprehensive .gitignore** to exclude build artifacts, temporary files, environment files, Docker outputs, and IDE/editor settings

For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)

## Recommended Use:
1. create a new project with `cargo new [new-rust-project]`
2. run script `sync_rust_template.sh` inside the project directory to copy all necessary rust-template config files to the current directory

If there is a new version of the `rust_template` repo:
1. run `git pull` from inside the `rust_template` directory
2. run `sync_rust_template.sh -f` from inside the project directory to override the config files
  - see [DEVELOPMENT.md](DEVELOPMENT.md) for more information

## Recommendations When Forking or Using as a Template

- **sym-link from  `.git-hooks/`**:
Example:
```bash
chmod +x .git-hooks/pre-push
ln -s .git-hooks/pre-push .git/hooks/pre-push
```
- **remove the `sync_rust_template.sh` file**
```bash
rm sync_rust_template.sh
```
