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

## Syncing Template Configs & Documentation

This template includes a small helper script called `sync-rust-template` that lets you easily bring in the latest configuration files and documentation standards from your rust_template directory into any Rust project.

What the script does

When run from the root of a Rust project (must contain `Cargo.toml`), it:

- Copies these config files (fails if they exist unless `--force` is used):  
  - `clippy.toml` (strict linting rules)  
  - `deny.toml` (license/vulnerability/source checks via cargo-deny)  
  - `rust-toolchain.toml` (nightly Rust + rustfmt/clippy/miri)  
  - `rustfmt.toml` (opinionated code formatting)

- Creates `DEVELOPMENT.md` by copying the template's `README.md` (skips if `DEVELOPMENT.md` already exists)

- Handles `README.md`:  
  - If missing → creates minimal version: `For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)`  
  - If exists → prepends the above link (only once, idempotent check)

- Appends header to `src/lib.rs` from template (skips if header already present via content check)

Safety features:
- Fails immediately if not in a Rust project (no `Cargo.toml`)
- Pre-checks: refuses to overwrite config files without `--force`
- Skips missing template files with clear warnings
- Idempotent: won't duplicate headers or README links

Prerequisites

1. Set the environment variable pointing to your template directory:

   ```bash
   export RUST_TEMPLATE_DIR="/path/to/your/rust_template"
   ```

   Make it permanent (add to `~/.bashrc`, `~/.zshrc`, or `~/.profile`):

   ```bash
   echo 'export RUST_TEMPLATE_DIR="/path/to/your/rust_template"' >> ~/.zshrc
   source ~/.zshrc
   ```

2. Verify the template directory exists:

   ```bash
   ls "$RUST_TEMPLATE_DIR"  # Should show clippy.toml, deny.toml, etc.
   ```

Installation & Setup

1. Save the script to a directory in your `$PATH`:

   ```bash
   mkdir -p ~/.local/bin
   # Save script as ~/.local/bin/sync-rust-template
   ```

2. Make executable (chmod privileges):

   ```bash
   chmod +x ~/.local/bin/sync-rust-template
   ```

   Verify:

   ```bash
   ls -l ~/.local/bin/sync-rust-template  # Should show -rwxr-xr-x
   ```

3. Add script directory to PATH (if not already):

   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

Usage

From any Rust project root:

```bash
# Safe mode (fails if config files exist)
sync-rust-template

# Force overwrite existing config files
sync-rust-template --force
# or
sync-rust-template -f

# Show help
sync-rust-template --help
```

Example workflow:

```bash
cd ~/projects/my-rust-app
export RUST_TEMPLATE_DIR="$HOME/templates/rust_template"
sync-rust-template

# Check results
ls -l clippy.toml deny.toml rust-toolchain.toml DEVELOPMENT.md
head -n 20 src/lib.rs  # Should show template header
head -n 5 README.md    # Should show DEVELOPMENT.md link

# Commit
git add clippy.toml deny.toml rust-toolchain.toml rustfmt.toml DEVELOPMENT.md README.md src/lib.rs
git commit -m "chore: sync rust_template configs and development docs"
```

Expected Output (first run)

```
Syncing from template: /path/to/your/rust_template
Target directory:     /home/user/projects/my-rust-app

'/path/to/your/rust_template/clippy.toml' -> './clippy.toml'
'/path/to/your/rust_template/deny.toml' -> './deny.toml'
'/path/to/your/rust_template/rust-toolchain.toml' -> './rust-toolchain.toml'
'/path/to/your/rust_template/rustfmt.toml' -> './rustfmt.toml'
'/path/to/your/rust_template/README.md' -> './DEVELOPMENT.md'
Created minimal README.md pointing to DEVELOPMENT.md
Appended header to src/lib.rs

Done:
  • 6 new file(s) created/copied
  • 0 config file(s) overwritten (with --force)
  • 1 file(s) updated (header or README pointer)
```

Troubleshooting

- `RUST_TEMPLATE_DIR is not set` → run the export command  
- `Template directory not found` → check path with `ls "$RUST_TEMPLATE_DIR"`  
- `Permission denied` → `chmod +x sync-rust-template`  
- `command not found` → add script dir to `$PATH` and `source ~/.zshrc`  
- `Not a Rust project` → run from directory containing `Cargo.toml`  
- `Files already exist` → use `--force` flag

After Syncing

Run these to verify everything works:

```bash
cargo +nightly fmt -- --check
cargo +nightly clippy -- -D warnings
cargo deny check
cargo +nightly miri test
```

Pro tip: Add an alias to your shell for convenience:

```bash
echo 'alias rust-sync="sync-rust-template"' >> ~/.zshrc
# Then just: rust-sync
```

Enjoy consistent, production-grade Rust tooling across all your projects! 🚀

Enjoy writing safe, clean, and rigorously checked Rust code!
