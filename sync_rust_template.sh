#!/usr/bin/env bash
# sync-rust-template -- with --force + README → DEVELOPMENT.md handling
# Copies standard config files + appends header to lib.rs + handles README/DEVELOPMENT.md + workflow file + pre-push hook + .gitignore
set -euo pipefail

########################################
# PRE-CHECK: ensure RUST_TEMPLATE_DIR is set and points to the correct repo, and working tree is clean
########################################
if [[ -z "${RUST_TEMPLATE_DIR:-}" ]]; then
  echo "❌ ERROR: RUST_TEMPLATE_DIR environment variable is not set."
  echo "   Please set RUST_TEMPLATE_DIR to your local rust_template repository."
  exit 1
fi

# Save current directory
ORIG_DIR=$(pwd)

# Go to template directory
cd "$RUST_TEMPLATE_DIR" || {
  echo "❌ ERROR: Cannot cd to RUST_TEMPLATE_DIR: $RUST_TEMPLATE_DIR"
  exit 1
}

# Validate remote
TEMPLATE_REMOTE_EXPECTED="https://github.com/MrCartaaa/rust_template.git"
TEMPLATE_REMOTE_EXPECTED_SSH="git@github.com:MrCartaaa/rust_template.git"
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || true)

if [[ "$CURRENT_REMOTE" != "$TEMPLATE_REMOTE_EXPECTED" && "$CURRENT_REMOTE" != "$TEMPLATE_REMOTE_EXPECTED_SSH" ]]; then
  echo "❌ ERROR: The repo at RUST_TEMPLATE_DIR is not the expected rust_template repository."
  echo "   Expected: $TEMPLATE_REMOTE_EXPECTED or $TEMPLATE_REMOTE_EXPECTED_SSH"
  echo "   Found   : $CURRENT_REMOTE"
  cd "$ORIG_DIR"
  exit 1
fi

# Check for clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ ERROR: Working tree in RUST_TEMPLATE_DIR is dirty. Commit or stash changes before syncing."
  git status --short
  cd "$ORIG_DIR"
  exit 1
fi

# Return to original directory
cd "$ORIG_DIR" || exit 1

echo "⏱ Pre-check passed: correct rust_template repo and clean working tree"

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
HOOK_DIR=".git-hooks/"

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

SRC_DIR="$TEMPLATE_DIR/.git-hooks"
DST_DIR="./.git/hooks"
FORCE=${FORCE:-false}

# Ensure source exists
if [[ ! -d "$SRC_DIR" ]]; then
  echo "Warning: Source hooks directory $SRC_DIR does not exist — nothing to copy"
  exit 0
fi

# Loop over all files in source directory
while IFS= read -r -d '' src_path; do
  # Relative path under SRC_DIR
  rel_path="${src_path#$SRC_DIR/}"
  dst_path="$DST_DIR/$rel_path"

  # Make sure destination directory exists
  mkdir -p "$(dirname "$dst_path")"

  if [[ -e "$dst_path" ]]; then
    if [[ "$FORCE" == true ]]; then
      cp "$src_path" "$dst_path"
      chmod +x "$dst_path"
      overwritten=$((overwritten + 1))
      echo "Overwritten existing hook: $dst_path (with --force)"
    else
      echo "Note: $dst_path already exists → skipping (use --force to overwrite)"
    fi
  else
    cp "$src_path" "$dst_path"
    chmod +x "$dst_path"
    copied=$((copied + 1))
    echo "Created hook: $dst_path"
  fi

done < <(find "$SRC_DIR" -type f -print0)

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

# 5. Copy .rust_template_version
src_version="$TEMPLATE_DIR/.rust_template_version"
dst_version="./.rust_template_version"

if [[ -f "$src_version" ]]; then
  if [[ -f "$dst_version" ]]; then
    if $FORCE; then
      cp "$src_version" "$dst_version"
      overwritten=$((overwritten + 1))
      echo "Overwritten existing .rust_template_version (with --force)"
    else
      echo "Note: .rust_template_version already exists → skipping (use --force to overwrite)"
    fi
  else
    cp "$src_version" "$dst_version"
    copied=$((copied + 1))
    echo "Created .rust_template_version from template"
  fi
else
  echo "Warning: Template .rust_template_version not found — skipped"
fi

echo
echo "Done:"
echo "  • $copied new file(s) created/copied"
echo "  • $overwritten file(s) overwritten (with --force)"
echo "  • $appended file(s) updated (header or README pointer)"
echo
