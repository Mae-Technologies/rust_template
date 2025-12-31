```markdown
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

### cargo-deny (`deny.toml`)

Enforces workspace-wide dependency policy:

- Allowed licenses: `MIT`, `Apache-2.0`, `BSD-3-Clause`
- Forbidden licenses: `GPL-2.0`, `GPL-3.0`, `AGPL-3.0`
- Blocks known vulnerabilities and yanked crates
- Restricts sources to `crates.io` and your GitHub repositories

More info: https://github.com/embarkstudios/cargo-deny

### GitHub Actions CI (`.github/workflows/rust_ci.yaml`)

Triggers on push/PR to `main` or `master`. Includes:

- `cargo +nightly fmt -- --check`
- `cargo +nightly clippy -- -D warnings -D clippy::undocumented_unsafe_blocks`
- `cargo +nightly miri test`
- `cargo audit`
- `cargo deny check`

Optimizes performance by detecting changed `.rs` files and skipping checks when no Rust code is modified.

## Getting Started

```bash
# Create a repo from this template on GitHub, then:
git clone https://github.com/yourusername/your-project.git
cd your-project

# Toolchain auto-selected via rust-toolchain.toml
cargo build
cargo test
```

## Adding Dependencies

All new dependencies must pass `cargo deny check`. Update `Cargo.toml` and run:

```bash
cargo deny check
```

Also update the Git source allowlist in `deny.toml` if using private Git dependencies.

## Local Checks

Run these commands to verify code quality locally:

```bash
cargo +nightly fmt -- --check                    # Formatting
cargo +nightly clippy -- -D warnings              # Strict linting
cargo +nightly miri test                          # Undefined behavior
cargo audit                                       # Vulnerabilities
cargo deny check                                  # Licenses / sources / bans
```

Enjoy writing safe, clean, and rigorously checked Rust code!
```
