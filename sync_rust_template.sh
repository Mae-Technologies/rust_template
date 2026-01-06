#!/usr/bin/env bash
# sync-rust-template -- with --force + README → DEVELOPMENT.md handling
# Copies standard config files + appends header to lib.rs + handles README/DEVELOPMENT.md + workflow file + pre-push hook + .gitignore
set -euo pipefail

########################################
# Colors
########################################
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
RESET="\033[0m"

########################################
# PRE-CHECK: ensure RUST_TEMPLATE_DIR is set, points to the correct repo, clean, and up-to-date
########################################
if [[ -z "${RUST_TEMPLATE_DIR:-}" ]]; then
  echo -e "${RED}❌  ERROR: RUST_TEMPLATE_DIR environment variable is not set.${RESET}"
  echo "   Please set RUST_TEMPLATE_DIR to your local rust_template repository."
  exit 1
fi

# Save current directory
ORIG_DIR=$(pwd)

# Go to template directory
cd "$RUST_TEMPLATE_DIR" || {
  echo -e "${RED}❌  ERROR: Cannot cd to RUST_TEMPLATE_DIR: $RUST_TEMPLATE_DIR${RESET}"
  exit 1
}

# Validate remote
TEMPLATE_REMOTE_EXPECTED="https://github.com/MrCartaaa/rust_template.git"
TEMPLATE_REMOTE_EXPECTED_SSH="git@github.com:MrCartaaa/rust_template.git"
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || true)
TEMPLATE_BRANCH="main"

if [[ "$CURRENT_REMOTE" != "$TEMPLATE_REMOTE_EXPECTED" && "$CURRENT_REMOTE" != "$TEMPLATE_REMOTE_EXPECTED_SSH" ]]; then
  echo -e "${RED}❌  ERROR: The repo at RUST_TEMPLATE_DIR is not the expected rust_template repository.${RESET}"
  echo "   Expected: $TEMPLATE_REMOTE_EXPECTED or $TEMPLATE_REMOTE_EXPECTED_SSH"
  echo "   Found   : $CURRENT_REMOTE"
  cd "$ORIG_DIR"
  exit 1
fi

# Check for clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo -e "${RED}❌  ERROR: Working tree in RUST_TEMPLATE_DIR is dirty. Commit & push or stash changes before syncing.${RESET}"
  git status --short
  cd "$ORIG_DIR"
  exit 1
fi

# Fetch latest remote state quietly
echo -ne "${BLUE}⏱  Fetching latest rust_template SHA...${RESET}"
git fetch --quiet origin "$TEMPLATE_BRANCH"
echo " done"

# Ensure local HEAD == remote branch SHA
LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git rev-parse "origin/$TEMPLATE_BRANCH")

if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  echo -e "${RED}❌  ERROR: Local rust_template is not up-to-date with origin/$TEMPLATE_BRANCH.${RESET}"
  echo "   Local SHA : $LOCAL_SHA"
  echo "   Remote SHA: $REMOTE_SHA"
  echo "   Please pull, push or reset your template repo before syncing."
  cd "$ORIG_DIR"
  exit 1
fi

# Return to original directory
cd "$ORIG_DIR" || exit 1

echo -e "${GREEN}✔  Pre-check passed: correct rust_template repo, clean working tree, and up-to-date with remote${RESET}"

########################################
# Sync process
########################################
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
    echo -e "${BLUE}⏱  Usage: $(basename "$0") [--force]${RESET}"
    echo
    echo "  --force    Overwrite existing config files (clippy.toml, deny.toml, etc.)"
    echo "             and DEVELOPMENT.md; also overwrite rust-integrity-guard.yaml, pre-push hook, and .gitignore if exists"
    echo
    exit 0
    ;;
  *)
    echo -e "${RED}❌  Unknown option: $1${RESET}" >&2
    echo "Use --help for usage" >&2
    exit 1
    ;;
  esac
done

# ── Early exit if template doesn't exist ───────────────────────────────
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo -e "${RED}❌  Error: Template directory not found: $TEMPLATE_DIR${RESET}" >&2
  exit 1
fi

# ── Check: is this a Rust project? ─────────────────────────────────────
if [[ ! -f "Cargo.toml" ]]; then
  echo -e "${RED}❌  Error: Not a Rust project — Cargo.toml not found in current directory${RESET}" >&2
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
    echo -e "${RED}❌  Error: The following config files already exist:${RESET}" >&2
    printf "  - %s\n" "${existing_config[@]}" >&2
    echo >&2
    echo -e "${YELLOW}⚠️  Use --force to overwrite them.${RESET}" >&2
    exit 1
  fi
fi

# ── Proceed ─────────────────────────────────────────────────────────────
declare -i copied=0
declare -i overwritten=0
declare -i appended=0

echo -e "${BLUE}⏱  Syncing from template: $TEMPLATE_DIR${RESET}"
echo -e "${BLUE}⏱  Target directory:     $(pwd)${RESET}"
$FORCE && echo -e "${YELLOW}⚠️  FORCE mode: will overwrite existing config files + DEVELOPMENT.md + pre-push hook + .gitignore${RESET}"
echo

# 1. Copy config files
for file in "${CONFIG_FILES[@]}"; do
  src="$TEMPLATE_DIR/$file"
  dst="./$file"
  [[ ! -f "$src" ]] && {
    echo -e "${YELLOW}⚠️  Warning: $src missing — skipped${RESET}"
    continue
  }
  if [[ -e "$dst" ]]; then
    $FORCE && {
      cp "$src" "$dst"
      overwritten=$((overwritten + 1))
    } || echo -e "${BLUE}📝  Skipped $dst (use --force to overwrite)${RESET}"
  else
    cp "$src" "$dst"
    copied=$((copied + 1))
  fi
done

# 1b. Handle workflow file
src_workflow="$TEMPLATE_DIR/$WORKFLOW_FILE"
dst_workflow="./$WORKFLOW_FILE"

if [[ -f "$src_workflow" ]]; then
  mkdir -p "$(dirname "$dst_workflow")"
  if [[ -e "$dst_workflow" ]]; then
    if $FORCE; then
      cp "$src_workflow" "$dst_workflow"
      overwritten=$((overwritten + 1))
      echo -e "${GREEN}✔  Overwritten existing workflow file (with --force)${RESET}"
    else
      echo -e "${BLUE}📝  Note: $dst_workflow already exists → skipping (use --force to overwrite)${RESET}"
    fi
  else
    cp "$src_workflow" "$dst_workflow"
    copied=$((copied + 1))
    echo -e "${GREEN}✔  Created workflow file: $dst_workflow${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Warning: Template workflow file $src_workflow not found — skipped${RESET}"
fi

# 1c. Handle pre-push hooks
SRC_DIR="$TEMPLATE_DIR/.git-hooks"
DST_DIR="./.git/hooks"
FORCE=${FORCE:-false}

if [[ ! -d "$SRC_DIR" ]]; then
  echo -e "${YELLOW}⚠️  Warning: Source hooks directory $SRC_DIR does not exist — nothing to copy${RESET}"
  exit 0
fi

while IFS= read -r -d '' src_path; do
  rel_path="${src_path#$SRC_DIR/}"
  dst_path="$DST_DIR/$rel_path"
  mkdir -p "$(dirname "$dst_path")"

  if [[ -e "$dst_path" ]]; then
    if [[ "$FORCE" == true ]]; then
      cp "$src_path" "$dst_path"
      chmod +x "$dst_path"
      overwritten=$((overwritten + 1))
      echo -e "${GREEN}✔  Overwritten existing hook: $dst_path (with --force)${RESET}"
    else
      echo -e "${BLUE}📝  Note: $dst_path already exists → skipping (use --force to overwrite)${RESET}"
    fi
  else
    cp "$src_path" "$dst_path"
    chmod +x "$dst_path"
    copied=$((copied + 1))
    echo -e "${GREEN}✔  Created hook: $dst_path${RESET}"
  fi
done < <(find "$SRC_DIR" -type f -print0)

# 2. Handle DEVELOPMENT.md
src_readme="$TEMPLATE_DIR/DEVELOPMENT.md"
dst_dev="DEVELOPMENT.md"

if [[ -f "$src_readme" ]]; then
  if [[ -f "$dst_dev" ]] && ! $FORCE; then
    echo -e "${BLUE}📝  Note: $dst_dev already exists → skipping copy from template DEVELOPMENT.md${RESET}"
  else
    [[ -f "$dst_dev" ]] && echo -e "${YELLOW}⚠️  Overwriting $dst_dev (with --force)${RESET}" && overwritten=$((overwritten + 1)) || copied=$((copied + 1))
    cp "$src_readme" "$dst_dev"
    echo -e "${GREEN}✔  Created/Updated $dst_dev from template DEVELOPMENT.md${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Warning: Template .md not found — skipping DEVELOPMENT.md${RESET}"
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
      echo -e "${GREEN}✔  Overwritten existing $dst_unwrap (with --force)${RESET}"
    else
      echo -e "${BLUE}📝  Note: $dst_unwrap already exists → skipping (use --force to overwrite)${RESET}"
    fi
  else
    cp "$src_common" "$dst_unwrap"
    copied=$((copied + 1))
    echo -e "${GREEN}✔  Created $dst_unwrap from template common.rs${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Warning: Template tests/common.rs not found — skipping must.rs${RESET}"
fi

# 3. Handle README.md
readme_link="For development rules, see [DEVELOPMENT.md](DEVELOPMENT.md)"
if [[ ! -f "README.md" ]]; then
  echo "$readme_link" >README.md
  echo -e "${GREEN}✔  Created minimal README.md pointing to DEVELOPMENT.md${RESET}"
  copied=$((copied + 1))
else
  if grep -qF "DEVELOPMENT.md" README.md 2>/dev/null; then
    echo -e "${BLUE}📝  Note: README.md already references DEVELOPMENT.md → skipping append${RESET}"
  else
    {
      echo "$readme_link"
      echo ""
      cat README.md
    } >README.md.tmp && mv README.md.tmp README.md
    echo -e "${GREEN}✔  Prepended DEVELOPMENT.md link to existing README.md${RESET}"
    appended=$((appended + 1))
  fi
fi

# adding empty exceptions file for cargo deny
if [[ !-f "deny.exceptions.toml" ]]; then
  echo "exceptions = []" > deny.exceptions.toml
  echo -e "${GREEN}✔  Created minimal deny.exceptions.toml file."
  copied=$((copied +1))
fi

# 4. Append header to lib.rs (etc.)
for file in "${HEADER_FILES[@]}"; do
  src="$TEMPLATE_DIR/$file"
  dst="./$file"
  [[ ! -f "$dst" ]] && {
    echo -e "${BLUE}📝  Note: $dst missing → skipping header${RESET}"
    continue
  }
  [[ ! -f "$src" ]] && {
    echo -e "${YELLOW}⚠️  Warning: $src missing → skipping $dst${RESET}"
    continue
  }

  if head -n 40 "$dst" | grep -qF "$(head -n 8 "$src" | grep -v '^\s*$' | head -n 3)"; then
    echo -e "${BLUE}📝  Note: Header already in $dst → skipping${RESET}"
    continue
  fi

  {
    cat "$src"
    tail -n1 "$src" | grep -q '^$' || echo ""
    cat "$dst"
  } >"$dst.tmp" && mv "$dst.tmp" "$dst"
  echo -e "${GREEN}✔  Appended header to $dst${RESET}"
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
      echo -e "${GREEN}✔  Overwritten existing .rust_template_version (with --force)${RESET}"
    else
      echo -e "${BLUE}📝  Note: .rust_template_version already exists → skipping (use --force to overwrite)${RESET}"
    fi
  else
    cp "$src_version" "$dst_version"
    copied=$((copied + 1))
    echo -e "${GREEN}✔  Created .rust_template_version from template${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Warning: Template .rust_template_version not found — skipped${RESET}"
fi

# Final summary
echo
echo -e "${GREEN}✔  Done:${RESET}"
echo -e "  • $copied new file(s) created/copied"
echo -e "  • $overwritten file(s) overwritten (with --force)"
echo -e "  • $appended file(s) updated (header or README pointer)"
echo
