#!/usr/bin/env bash
# sync-rust-template -- with --force + README → DEVELOPMENT.md handling
# Copies standard config files + appends header to lib.rs + handles README/DEVELOPMENT.md + workflow file + pre-push hook + .gitignore
set -euo pipefail

TEMPLATE_DIR="$HOME/dev/back_end/rust/rust_template"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --force | -f)
    FORCE=true
    shift
    ;;
  --help | -h)
    echo "Usage: $(basename "$0") [--force]"
    echo
    echo "  --force    Overwrite existing config files (clippy.toml, deny.toml, etc.)"
    echo "             and DEVELOPMENT.md; also overwrite rust-integrity-guard.yaml, pre-push hook, and .gitignore if exists"
    echo
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    echo "Use --help for usage" >&2
    exit 1
    ;;
  esac
done

# ── Early exit if template doesn't exist ───────────────────────────────
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: Template directory not found: $TEMPLATE_DIR" >&2
  exit 1
fi

# ── Check: is this a Rust project? ─────────────────────────────────────
if [[ ! -f "Cargo.toml" ]]; then
  echo "Error: Not a Rust project — Cargo.toml not found in current directory" >&2
  echo "       (current dir: $(pwd))" >&2
  exit 1
fi

# Config files (overwritten only with --force)
declare -a CONFIG_FILES=(
  "clippy.toml"
  "deny.toml"
  "rust-toolchain.toml"
  "rustfmt.toml"
  ".gitignore"
)

# Special workflow file
WORKFLOW_FILE=".github/workflows/rust-integrity-guard.yaml"

# Pre-push hook
HOOK_FILE=".git-hooks/pre-push"

# Files to append header (idempotent)
declare -a HEADER_FILES=(
  "src/lib.rs"
  # "src/main.rs" # uncomment if desired
)

# ── Pre-check: config files (unless --force) ───────────────────────────
if ! $FORCE; then
  declare -a existing_config=()
  for file in "${CONFIG_FILES[@]}"; do
    [[ -e "./$file" ]] && existing_config+=("$file")
  done
  if [ ${#existing_config[@]} -gt 0 ]; then
    echo "Error: The following config files already exist:" >&2
    printf "  - %s\n" "${existing_config[@]}" >&2
    echo >&2
    echo "Use --force to overwrite them." >&2
    exit 1
  fi
fi

# ── Proceed ─────────────────────────────────────────────────────────────
declare -i copied=0
declare -i overwritten=0
declare -i appended=0

echo "Syncing from template: $TEMPLATE_DIR"
echo "Target directory:     $(pwd)"
$FORCE && echo "(FORCE mode: will overwrite existing config files + DEVELOPMENT.md + pre-push hook + .gitignore)"
echo

# 1. Copy config files
for file in "${CONFIG_FILES[@]}"; do
  src="$TEMPLATE_DIR/$file"
  dst="./$file"
  [[ ! -f "$src" ]] && {
    echo "Warning: $src missing — skipped"
    continue
  }
  if [[ -e "$dst" ]]; then
    $FORCE && {
      cp "$src" "$dst"
      overwritten=$((overwritten + 1))
    } || echo "Skipped $dst (use --force to overwrite)"
  else
    cp "$src" "$dst"
    copied=$((copied + 1))
  fi
done

# 1b. Handle .github/workflows/rust-integrity-guard.yaml
src_workflow="$TEMPLATE_DIR/$WORKFLOW_FILE"
dst_workflow="./$WORKFLOW_FILE"

if [[ -f "$src_workflow" ]]; then
  mkdir -p "$(dirname "$dst_workflow")"
  if [[ -e "$dst_workflow" ]]; then
    if $FORCE; then
      cp "$src_workflow" "$dst_workflow"
      overwritten=$((overwritten + 1))
      echo "Overwritten existing workflow file (with --force)"
    else
      echo "Note: $dst_workflow already exists → skipping (use --force to overwrite)"
    fi
  else
    cp "$src_workflow" "$dst_workflow"
    copied=$((copied + 1))
    echo "Created workflow file: $dst_workflow"
  fi
else
  echo "Warning: Template workflow file $src_workflow not found — skipped"
fi

# 1c. Handle pre-push hook
src_hook="$TEMPLATE_DIR/.git/hooks/pre-push"
dst_hook="./.git/hooks/pre-push"

if [[ -f "$src_hook" ]]; then
  mkdir -p "$(dirname "$dst_hook")"
  if [[ -e "$dst_hook" ]]; then
    if $FORCE; then
      cp "$src_hook" "$dst_hook"
      chmod +x "$dst_hook"
      overwritten=$((overwritten + 1))
      echo "Overwritten existing pre-push hook (with --force)"
    else
      echo "Note: $dst_hook already exists → skipping (use --force to overwrite)"
    fi
  else
    cp "$src_hook" "$dst_hook"
    chmod +x "$dst_hook"
    copied=$((copied + 1))
    echo "Created pre-push hook: $dst_hook"
  fi
else
  echo "Warning: Template pre-push hook $src_hook not found — skipped"
fi

# 2. Handle DEVELOPMENT.md
src_readme="$TEMPLATE_DIR/DEVELOPMENT.md"
dst_dev="DEVELOPMENT.md"

if [[ -f "$src_readme" ]]; then
  if [[ -f "$dst_dev" ]] && ! $FORCE; then
    echo "Note: $dst_dev already exists → skipping copy from template DEVELOPMENT.md"
  else
    [[ -f "$dst_dev" ]] && echo "Overwriting $dst_dev (with --force)" && overwritten=$((overwritten + 1)) || copied=$((copied + 1))
    cp "$src_readme" "$dst_dev"
    echo "Created/Updated $dst_dev from template DEVELOPMENT.md"
  fi
else
  echo "Warning: Template .md not found — skipping DEVELOPMENT.md" >&2
fi

# 2b. Handle tests/common.rs → tests/must.rs
src_common="$TEMPLATE_DIR/tests/common.rs"
dst_unwrap="./tests/must.rs"

if [[ -f "$src_common" ]]; then
  mkdir -p "./tests"
  if [[ -f "$dst_unwrap" ]]; then
    if $FORCE; then
      cp "$src_common" "$dst_unwrap"
      overwritten=$((overwritten + 1))
      echo "Overwritten existing $dst_unwrap (with --force)"
    else
      echo "Note: $dst_unwrap already exists → skipping (use --force to overwrite)"
    fi
  else
    cp "$src_common" "$dst_unwrap"
    copied=$((copied + 1))
    echo "Created $dst_unwrap from template common.rs"
  fi
else
  echo "Warning: Template tests/common.rs not found — skipping must.rs" >&2
fi

# 3. Handle README.md
readme_link="For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)"
if [[ ! -f "README.md" ]]; then
  echo "$readme_link" >README.md
  echo "Created minimal README.md pointing to DEVELOPMENT.md"
  copied=$((copied + 1))
else
  if grep -qF "DEVELOPMENT.md" README.md 2>/dev/null; then
    echo "Note: README.md already references DEVELOPMENT.md → skipping append"
  else
    {
      echo "$readme_link"
      echo ""
      cat README.md
    } >README.md.tmp && mv README.md.tmp README.md
    echo "Prepended DEVELOPMENT.md link to existing README.md"
    appended=$((appended + 1))
  fi
fi

# 4. Append header to lib.rs (etc.)
for file in "${HEADER_FILES[@]}"; do
  src="$TEMPLATE_DIR/$file"
  dst="./$file"
  [[ ! -f "$dst" ]] && {
    echo "Note: $dst missing → skipping header"
    continue
  }
  [[ ! -f "$src" ]] && {
    echo "Warning: $src missing → skipping $dst"
    continue
  }
  if head -n 40 "$dst" | grep -qF "$(head -n 8 "$src" | grep -v '^\s*$' | head -n 3)"; then
    echo "Note: Header already in $dst → skipping"
    continue
  fi
  {
    cat "$src"
    tail -n1 "$src" | grep -q '^$' || echo ""
    cat "$dst"
  } >"$dst.tmp" && mv "$dst.tmp" "$dst"
  echo "Appended header to $dst"
  appended=$((appended + 1))
done

echo
echo "Done:"
echo "  • $copied new file(s) created/copied"
echo "  • $overwritten file(s) overwritten (with --force)"
echo "  • $appended file(s) updated (header or README pointer)"
echo
