#!/usr/bin/env bash
set -euo pipefail

########################################
# 🎨 Color Support
########################################
if command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
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

info()    { echo "${BLUE}$*${RESET}"; }
ok()      { echo "${GREEN}$*${RESET}"; }
warn()    { echo "${YELLOW}$*${RESET}"; }
err()     { echo "${RED}$*${RESET}" >&2; }
section() { echo; echo "${BOLD}${CYAN}═══════════════════════════════════════${RESET}"; echo "${BOLD}${CYAN}  $*${RESET}"; echo "${BOLD}${CYAN}═══════════════════════════════════════${RESET}"; echo; }
step()    { echo "${BLUE}▶${RESET} ${BOLD}$*${RESET}"; }

########################################
# 🧪 Integration Test Runner
########################################

# Parse --ci flag: when running in CI, unset MAE_TESTCONTAINERS so docker-gated
# tests (#[mae_test(docker)]) are compiled without the env var and skip at runtime.
# Developers run the script without this flag — ci_env.toml sets MAE_TESTCONTAINERS=1
# automatically so containers spin up with no extra setup required.
CI_MODE=false
for arg in "$@"; do
  if [[ "$arg" == "--ci" ]]; then
    CI_MODE=true
  fi
done

section "Integration Tests"
step "Reading configuration from .ci/ci_env.toml"

repo_root="$(git rev-parse --show-toplevel)"
CFG_FILE="$repo_root/.ci/ci_env.toml"

if [[ ! -f "$CFG_FILE" ]]; then
  err "❌ ERROR: $CFG_FILE not found"
  exit 1
fi

# Parse TOML config via Python
TOML_STATE="$(python3 - "$CFG_FILE" <<'PY'
import json
import os
import sys

cfg_path = sys.argv[1]

defaults = {
    "engine": "nextest",
    "flags": ["--features", "integration-testing", "--all-features", "--run-ignored", "all"],
    "env": ["MAE_TESTCONTAINERS=1"],
}

cfg = {}
if os.path.exists(cfg_path):
    with open(cfg_path, "rb") as f:
        try:
            import tomllib
            parsed = tomllib.load(f)
        except Exception:
            parsed = {}
    if isinstance(parsed, dict):
        cfg = parsed

engine = cfg.get("engine", defaults["engine"])
flags = cfg.get("flags", defaults["flags"])
env = cfg.get("env", defaults["env"])

if not isinstance(engine, str):
    engine = defaults["engine"]
if not isinstance(flags, list):
    flags = defaults["flags"]
if not isinstance(env, list):
    env = defaults["env"]

flags = [str(x) for x in flags]
env = [str(x) for x in env]

print(json.dumps({"engine": engine.strip(), "flags": flags, "env": env}))
PY
)"

ENGINE="$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["engine"])' "$TOML_STATE")"
FLAGS="$(python3 -c 'import json,sys;print(" ".join(json.loads(sys.argv[1])["flags"]))' "$TOML_STATE")"
ENV_VARS="$(python3 -c 'import json,sys;print("\n".join(json.loads(sys.argv[1])["env"]))' "$TOML_STATE")"

# Export environment variables
if [[ -n "$ENV_VARS" ]]; then
  step "Exporting environment variables"
  while IFS= read -r kv; do
    [[ -z "$kv" ]] && continue
    if [[ "$kv" != *=* ]]; then
      err "❌ ERROR: invalid env entry '$kv' (expected KEY=VALUE)"
      exit 1
    fi
    export "$kv"
    info "   ${kv%%=*}=${kv#*=}"
  done <<< "$ENV_VARS"
fi

# In CI mode, unset MAE_TESTCONTAINERS so docker-gated tests are compiled without
# the env var — option_env!() will see None, and those tests skip early.
if [[ "$CI_MODE" == "true" ]]; then
  step "--ci mode: unsetting MAE_TESTCONTAINERS (docker-gated tests will skip)"
  unset MAE_TESTCONTAINERS
fi

# Warn local developers about external service env vars.
# In CI these are injected via GitHub secrets; locally they may be provided by
# docker containers or set manually.
if [[ "$CI_MODE" == "false" ]]; then
  MISSING_VARS=()
  [[ -z "${APP_DATABASE__HOST:-}" ]] && MISSING_VARS+=("APP_DATABASE__HOST  (CI secret: CI_STAGE_WIDGET_SERVICE_POSTGRES_HOST → maps to database.host)")
  [[ -z "${APP_GRAPHDB__HOST:-}" ]]  && MISSING_VARS+=("APP_GRAPHDB__HOST   (CI secret: CI_STAGE_WIDGET_SERVICE_NEO4J_HOST   → maps to graphdb.host)")
  [[ -z "${APP_REDIS_URI:-}" ]]      && MISSING_VARS+=("APP_REDIS_URI       (CI secret: CI_STAGE_REDIS_URL                   → maps to redis_uri)")

  if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo
    warn "⚠️  The following env vars are not set:"
    for v in "${MISSING_VARS[@]}"; do
      warn "   • $v"
    done
    warn ""
    warn "   In CI these are injected automatically via GitHub secrets."
    warn "   Locally, tests may still pass if docker containers provide the services."
    echo
  fi
fi

# Build flags array
ARGS=()
if [[ -n "$FLAGS" ]]; then
  # shellcheck disable=SC2206
  ARGS=($FLAGS)
fi

# Run tests based on engine
step "Engine: ${BOLD}${ENGINE}${RESET}"

case "$ENGINE" in
  miri)
    info "▶ Running: cargo miri test ${ARGS[*]}"
    cargo miri test "${ARGS[@]}"
    ;;
  cargo)
    info "▶ Running: cargo test ${ARGS[*]}"
    cargo test "${ARGS[@]}"
    ;;
  nextest)
    info "▶ Running: cargo nextest run ${ARGS[*]}"
    cargo nextest run "${ARGS[@]}"
    ;;
  nothing)
    warn "▶ Skipping tests (engine=nothing)"
    exit 0
    ;;
  *)
    err "❌ ERROR: Unknown test engine '$ENGINE' (expected: miri|cargo|nextest|nothing)"
    exit 1
    ;;
esac

echo
ok "✅  Integration tests completed successfully"
