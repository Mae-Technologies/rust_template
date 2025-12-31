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

For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)
