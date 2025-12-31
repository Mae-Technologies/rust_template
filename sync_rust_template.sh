#!/usr/bin/env bash
# sync-rust-template -- with --force + README → DEVELOPMENT.md handling
# Copies standard config files + appends header to lib.rs + handles README/DEVELOPMENT.md

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
    echo "             Does NOT force-overwrite DEVELOPMENT.md or README.md"
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
)

# Files to append header (idempotent)
declare -a HEADER_FILES=(
  "src/lib.rs"
  # "src/main.rs"   # uncomment if desired
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
echo "Target directory: $(pwd)"
$FORCE && echo "(FORCE mode: will overwrite existing config files)"
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
      cp -v "$src" "$dst"
      overwritten=$((overwritten + 1))
    } || echo "Skipped $dst (use --force to overwrite)"
  else
    cp -v "$src" "$dst"
    copied=$((copied + 1))
  fi
done

# 2. Handle DEVELOPMENT.md (copy from template's README.md)
src_readme="$TEMPLATE_DIR/README.md"
dst_dev="DEVELOPMENT.md"

if [[ -f "$src_readme" ]]; then
  if [[ -f "$dst_dev" ]]; then
    echo "Note: $dst_dev already exists → skipping copy from template README.md"
  else
    cp -v "$src_readme" "$dst_dev"
    copied=$((copied + 1))
    echo "Created $dst_dev from template README.md"
  fi
else
  echo "Warning: Template README.md not found — skipping DEVELOPMENT.md creation" >&2
fi

# 3. Handle README.md (create minimal or append pointer if missing)
readme_link="For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)"

if [[ ! -f "README.md" ]]; then
  echo "$readme_link" >README.md
  echo "Created minimal README.md pointing to DEVELOPMENT.md"
  copied=$((copied + 1))
else
  # Check if the line (or very similar) already exists
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

  # Simple presence check (first few non-blank lines)
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
echo "  • $overwritten config file(s) overwritten (with --force)"
echo "  • $appended file(s) updated (header or README pointer)"
echo
