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

FORCE=false
TEST=false
NAME="" # Optional default name for MIT license
LICENSE_NAME=""
PRIVATE_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
  --force | -f)
    FORCE=true
    shift
    ;;
  --test | -t)
    TEST=true
    shift
    ;;
  --private)
    shift
    if [[ $# -eq 0 ]]; then
      if [[ -z "$RUST_OWNER" ]]; then
        echo -e "${RED}❌  Error: --private requires a name argument or set RUST_OWNER${RESET}" >&2
        exit 1
      else
        PRIVATE_NAME="$RUST_OWNER"
        echo -e "${YELLOW}⚠️  Info: --private name arguement not provided, using RUST_OWNER='$RUST_OWNER'${RESET}"
      fi
    else
      PRIVATE_NAME="$1"
      shift
    fi
    ;;

  --name)
    shift
    if [[ $# -eq 0 ]]; then
      if [[ -z "$RUST_OWNER" ]]; then
        echo -e "${RED}❌  Error: --name requires a name argument or set RUST_OWNER${RESET}" >&2
        exit 1
      else
        NAME="$RUST_OWNER"
        echo -e "${YELLOW}⚠️  Info: --nam name argument not provided, using RUST_OWNER='$RUST_OWNER'${RESET}"
      fi
    else
      NAME="$1"
      shift
    fi
    ;;
  --help | -h)
    echo -e "${BLUE}⏱  Usage: $(basename "$0") [--force] [--private NAME] [--name NAME]${RESET}"
    echo
    echo "  --force       Overwrite existing config files and docs"
    echo "  --private     Provide a name to generate a proprietary LICENSE file"
    echo "  --name        Optional name for MIT license if --private not used"
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

# Determine LICENSE name
if [[ -n "$PRIVATE_NAME" ]]; then
  LICENSE_NAME="$PRIVATE_NAME"
elif [[ -n "$NAME" ]]; then
  LICENSE_NAME="$NAME"
elif [[ -n "${RUST_OWNER:-}" ]]; then
  LICENSE_NAME="$RUST_OWNER"
  NAME=LICENSE_NAME
  echo -e "${YELLOW}⚠️   No --private, --name provided. adding MIT License for ${RUST_OWNER}."
else
  echo -e "${RED}❌  Error: No --private, --name, or RUST_OWNER environment variable provided.${RESET}" >&2
  echo "Please provide a name for the LICENSE via --private, --name, or export RUST_OWNER=<name>" >&2
  exit 1
fi

########################################
# PRE-CHECK: ensure RUST_TEMPLATE_DIR is set, points to the correct repo, clean, and up-to-date
########################################
if ! $TEST; then
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

else
  echo -e "${YELLOW}⚠️  TEST mode bypassing checks for rust_template sync requirements"
fi
########################################
# Sync process
########################################
# ── Early exit if template doesn't exist ───────────────────────────────
if [[ ! -d "$RUST_TEMPLATE_DIR" ]]; then
  echo -e "${RED}❌  Error: Template directory not found: $RUST_TEMPLATE_DIR${RESET}" >&2
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

echo -e "${BLUE}⏱  Syncing from template: $RUST_TEMPLATE_DIR${RESET}"
echo -e "${BLUE}⏱  Target directory:     $(pwd)${RESET}"
$FORCE && echo -e "${YELLOW}⚠️  FORCE mode: will overwrite existing config files + DEVELOPMENT.md + pre-push hook + .gitignore${RESET}"
echo

# 1. Copy config files
for file in "${CONFIG_FILES[@]}"; do
  src="$RUST_TEMPLATE_DIR/$file"
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
src_workflow="$RUST_TEMPLATE_DIR/$WORKFLOW_FILE"
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
SRC_DIR="$RUST_TEMPLATE_DIR/.git-hooks"
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
src_readme="$RUST_TEMPLATE_DIR/DEVELOPMENT.md"
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
src_common="$RUST_TEMPLATE_DIR/tests/common.rs"
dst_unwrap="./tests/common/must.rs"
dst_mod="./tests/common/mod.rs"

if [[ -f "$src_common" ]]; then
  # Ensure destination directories exist
  mkdir -p "./tests"
  mkdir -p "./tests/common"
  touch "./tests/common/mod.rs"

  if [[ -f "$dst_unwrap" ]]; then
    if $FORCE; then
      cp "$src_common" "$dst_unwrap"
      if ! grep -qxF "pub mod must;" "$dst_mod"; then
        echo -e "${GREEN}✔  appending existing $dst_mod to inlude must mod (with --force)${RESET}"
        echo "pub mod must;" >>"$dst_mod"
      fi
      overwritten=$((overwritten + 1))
      echo -e "${GREEN}✔  Overwritten existing $dst_unwrap (with --force)${RESET}"
    else
      echo -e "${BLUE}📝  Note: $dst_unwrap already exists → skipping (use --force to overwrite)${RESET}"
    fi
  else
    cp "$src_common" "$dst_unwrap"
    echo "pub mod must;" >>"$dst_mod"
    copied=$((copied + 2))
    echo -e "${GREEN}✔  Created $dst_unwrap from template common.rs${RESET}"
  fi
else
  echo -e "${YELLOW}⚠️  Warning: Template tests/common.rs not found — skipping must.rs${RESET}"
fi

# add common to tests
common_decl="pub mod common;"
lib="./tests/lib.rs"
main="./tests/main.rs"

if $FORCE; then
  if [[ -f "$lib" ]]; then
    if ! grep -qxF "$common_decl" "$lib"; then
      echo -e "${GREEN}✔  appending existing $lib to include common directory (with --force)${RESET}"
      echo "" >>"$lib"
      echo "$common_decl" >>"$lib"
    fi
  elif [[ -f "$main" ]]; then
    if ! grep -qxF "$common_decl" "$main"; then
      echo "" >>"$main"
      echo "$common_decl" >>"$main"
      echo -e "${GREEN}✔  appending existing $main to include common directory (with --force)${RESET}"
    fi
  fi
else
  echo -e "${BLUE}📝  Note: skipping common/must.rs (use --force to overwrite)${RESET}"
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
if [[ ! -f "deny.exceptions.toml" ]]; then
  echo "exceptions = []" >deny.exceptions.toml
  echo -e "${GREEN}✔  Created minimal deny.exceptions.toml file."
  copied=$((copied + 1))
else
  echo -e "${BLUE}📝  Note: deny.excemptions.toml file already exists → skipping append${RESET}"
fi

# 4. Append header to lib.rs (etc.)
for file in "${HEADER_FILES[@]}"; do
  src="$RUST_TEMPLATE_DIR/$file"
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
src_version="$RUST_TEMPLATE_DIR/.rust_template_version"
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

# --- Add LICENSE file --
if [[ -n "$PRIVATE_NAME" ]]; then
  LICENSE_FILE="./LICENSE"
  YEAR=$(date +%Y)

  if [[ -f "$LICENSE_FILE" && "$FORCE" != true ]]; then
    echo -e "${BLUE}📝  Note: LICENSE already exists → skipping${RESET}"
  else
    cat >"$LICENSE_FILE" <<EOF
Copyright (c) $YEAR $LICENSE_NAME

All rights reserved.

This software is proprietary and may not be used, copied, modified,
or distributed without explicit permission from $PRIVATE_NAME.
EOF

    echo -e "${GREEN}✔  Created LICENSE file for private use by $PRIVATE_NAME${RESET}"
    copied=$((copied + 1))
  fi

# --- Default to MIT if no private name provided ---
else
  LICENSE_FILE="./LICENSE"
  YEAR=$(date +%Y)
  NAME="$LICENSE_NAME" # or set to a sensible default variable if you have one

  # Inform about defaulting
  echo -e "${YELLOW}⚠️   Info: No private name provided → defaulting to MIT license${RESET}"

  # If file exists and not forcing overwrite
  if [[ -f "$LICENSE_FILE" && "$FORCE" != true ]]; then
    echo -e "${BLUE}📝  Note: LICENSE already exists → skipping default MIT license${RESET}"
  else
    cat >"$LICENSE_FILE" <<EOF
MIT License

Copyright (c) $YEAR $LICENSE_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    echo -e "${GREEN}✔  Created default MIT LICENSE file${RESET}"
    copied=$((copied + 1))
  fi
fi

# Determine LICENSE_TYPE based on PRIVATE_NAME
if [[ -n "${PRIVATE_NAME:-}" ]]; then
  LICENSE_TYPE="LicenseRef-Proprietary"
else
  LICENSE_TYPE="MIT"
fi

CARGO_FILE="Cargo.toml"

# Check if Cargo.toml exists
if [[ ! -f "$CARGO_FILE" ]]; then
  echo -e "${RED}❌  Error: Cargo.toml not found${RESET}" >&2
  exit 1
fi

# Check if [package] section exists
if ! grep -q "^\[package\]" "$CARGO_FILE"; then
  echo -e "${RED}❌  Error: [package] section not found in Cargo.toml${RESET}" >&2
  exit 1
fi

# If license key exists, update it
if grep -q "^\s*license\s*=" "$CARGO_FILE"; then
  sed -i.bak "s/^\(\s*license\s*=\s*\).*/\1\"$LICENSE_TYPE\"/" "$CARGO_FILE"
  echo -e "${GREEN}✔  Updated license to $LICENSE_TYPE in Cargo.toml${RESET}"
else
  # Insert license = "<LICENSE_TYPE>" after first non-empty line after [package]
  awk -v license="$LICENSE_TYPE" '
        BEGIN { inserted=0 }
        /^\[package\]/ { print; nextline=1; next }
        nextline && /^[[:space:]]*$/ { print; next }
        nextline && !inserted { print "license = \"" license "\""; inserted=1 }
        { print }
    ' "$CARGO_FILE" >"${CARGO_FILE}.tmp" && mv "${CARGO_FILE}.tmp" "$CARGO_FILE"
  echo -e "${GREEN}✔  Added license = $LICENSE_TYPE to Cargo.toml under [package]${RESET}"
fi
# Final summary
echo
echo -e "${GREEN}✔  Done:${RESET}"
echo -e "  • $copied new file(s) created/copied"
echo -e "  • $overwritten file(s) overwritten (with --force)"
echo -e "  • $appended file(s) updated (header or README pointer)"
echo
