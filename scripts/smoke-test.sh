#!/usr/bin/env bash
set -euo pipefail

########################################
# 🎨 Color Support (Cargo colors untouched)
########################################
if command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  CYAN="$(tput setaf 6)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
  BOLD=""
  RESET=""
fi

info() { echo "${BLUE}$*${RESET}"; }
ok() { echo "${GREEN}$*${RESET}"; }
warn() { echo "${YELLOW}$*${RESET}"; }
err() { echo "${RED}$*${RESET}" >&2; }

########################################
# 1️⃣ RUST PRE-PUSH CHECKS
########################################

# Only run in interactive shells (keeps Cargo colors)
if [[ ! -t 1 ]]; then
  exit 0
fi

# Global bypass
if [[ -n "${SKIP_GUARD:-}" ]]; then
  warn "⚠️  SKIP_GUARD set — skipping Rust quality gate"
  exit 0
fi

# Only allow pushing over ssh
remote_name="${1:-}"
remote_url="${2:-}"

case "$remote_url" in
https://* | http://*)
  echo "ERROR: HTTPS push blocked. Use SSH remote URLs (git@...)." >&2
  echo "Remote: $remote_name  URL: $remote_url" >&2
  exit 1
  ;;
esac

# Drain stdin (required by git pre-push hook protocol)
while read -r local_ref local_sha remote_ref remote_sha; do
  : # checks run on every branch — no branch filtering
done

# Detect Rust project by policy files
required_files=(
  clippy.toml
  deny.toml
  rustfmt.toml
  rust-toolchain.toml
)

for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || exit 0
done

info "🦀  Rust quality gate detected — running pre-push checks"
echo

run() {
  local label="$1"
  shift
  info "▶ ${label}"
  "$@" || {
    err "❌ ${label} failed — aborting push"
    exit 1
  }
}

########################################
# ✨ Always run formatting
########################################
run "rustfmt" cargo fmt -- --check

########################################
# 🧪 Tests (optional fast-paths)
########################################
repo_root="$(git rev-parse --show-toplevel)"
ci_tests="$repo_root/.ci/ci_tests.sh"

if [[ ! -f "$ci_tests" ]]; then
  echo "❌ ERROR: missing $ci_tests" >&2
  exit 1
fi
if [[ ! -x "$ci_tests" ]]; then
  chmod +x "$ci_tests"
fi

if [[ -z "${SKIP_TEST:-}" ]]; then
  run "tests" "$ci_tests"
  ok "✔  Tests completed successfully"
else
  warn "⚡ SKIP_TEST set — skipping tests and Miri"
fi

########################################
# 🔍 Lint / Security / Policy
########################################
run "clippy" cargo clippy -- -D warnings
run "cargo deny" cargo deny check

########################################
# 🔐 Secret Scanning (TruffleHog)
#
# Scans the most recent commit for verified secrets (API keys, tokens, etc.).
# Uses TruffleHog (https://github.com/trufflesecurity/trufflehog).
#
# Install: see DEVELOPMENT.md or run sync_rust_template.sh which bootstraps it.
#
# False-positive handling:
#   - Add patterns to .trufflehog-ignore (one regex per line, matched against
#     the detector name + file path).
#   - Alternatively use --exclude-paths=<file> with a list of paths to skip.
#   - For test fixtures / example keys, add them to .trufflehog-ignore.
#
# Skip: set SKIP_SECRET_SCAN=1 to bypass this step.
########################################
if [[ -z "${SKIP_SECRET_SCAN:-}" ]]; then
  if command -v trufflehog >/dev/null 2>&1; then
    trufflehog_args=(git "file://." --since-commit HEAD~1 --only-verified --fail)
    if [[ -f ".trufflehog-ignore" ]]; then
      trufflehog_args+=(--exclude-paths .trufflehog-ignore)
    fi
    run "secret scan (trufflehog)" trufflehog "${trufflehog_args[@]}"
    ok "✔  No secrets detected"
  else
    warn "⚠️  trufflehog not found — skipping secret scan (install: https://github.com/trufflesecurity/trufflehog#installation)"
  fi
else
  warn "⚡ SKIP_SECRET_SCAN set — skipping secret scan"
fi

echo
ok "✅  All Rust checks passed — continuing push"
