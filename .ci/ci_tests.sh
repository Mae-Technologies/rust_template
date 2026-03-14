#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────
# CI test selector via .ci/ci_env.toml
#   engine = "miri"     -> cargo miri test
#   engine = "cargo"    -> cargo test
#   engine = "nextest"  -> cargo nextest run
#   engine = "nothing"  -> skip tests
#
# Optional TOML keys:
#   env = ["KEY=VALUE", ...]  # exported before running tests
#   flags = ["--features", "integration-testing", ...]
#
# Env var overrides (highest priority):
#   TEST_WITH, CI_TEST_ENGINE, CI_TEST_FLAGS, CI_TEST_ENV
#
# Defaults when file/key missing:
#   engine=nextest
#   env=["MAE_TESTCONTAINERS=1"]
#   flags=["--features", "integration-testing", "--all-features", "--ignored", "all"]
# ────────────────────────────────────────────────

repo_root="$(git rev-parse --show-toplevel)"
CFG_FILE="$repo_root/.ci/ci_env.toml"

TEST_WITH="${TEST_WITH:-${CI_TEST_ENGINE:-}}"
CI_TEST_FLAGS_VALUE="${CI_TEST_FLAGS:-}"
CI_TEST_ENV_VALUE="${CI_TEST_ENV:-}"

TOML_STATE="$(python3 - "$CFG_FILE" <<'PY'
import json
import os
import sys

cfg_path = sys.argv[1]

defaults = {
    "engine": "nextest",
    "flags": ["--features", "integration-testing", "--all-features", "--ignored", "all"],
    "env": ["MAE_TESTCONTAINERS=1"],
}

cfg = {}
if os.path.exists(cfg_path):
    with open(cfg_path, "rb") as f:
        try:
            import tomllib  # requires Python 3.11+
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

if [[ -z "${TEST_WITH:-}" ]]; then
  TEST_WITH="$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["engine"])' "$TOML_STATE")"
fi

if [[ -z "$CI_TEST_FLAGS_VALUE" ]]; then
  CI_TEST_FLAGS_VALUE="$(python3 -c 'import json,sys; print(" ".join(json.loads(sys.argv[1])["flags"]))' "$TOML_STATE")"
fi

if [[ -z "$CI_TEST_ENV_VALUE" ]]; then
  CI_TEST_ENV_VALUE="$(python3 -c 'import json,sys; print("\n".join(json.loads(sys.argv[1])["env"]))' "$TOML_STATE")"
fi

if [[ -n "$CI_TEST_ENV_VALUE" ]]; then
  while IFS= read -r kv; do
    [[ -z "$kv" ]] && continue
    if [[ "$kv" != *=* ]]; then
      echo "❌ ERROR: invalid env entry '$kv' (expected KEY=VALUE)" >&2
      exit 1
    fi
    export "$kv"
  done <<< "$CI_TEST_ENV_VALUE"
fi

ARGS=()
if [[ -n "$CI_TEST_FLAGS_VALUE" ]]; then
  # shellcheck disable=SC2206
  ARGS=($CI_TEST_FLAGS_VALUE)
fi

case "$TEST_WITH" in
miri)
  echo "▶ Running: cargo miri test ${ARGS[*]}"
  cargo miri test "${ARGS[@]}"
  ;;
cargo)
  echo "▶ Running: cargo test ${ARGS[*]}"
  cargo test "${ARGS[@]}"
  ;;
nextest)
  echo "▶ Running: cargo nextest run ${ARGS[*]}"
  cargo nextest run "${ARGS[@]}"
  ;;
nothing)
  echo "▶ Skipping tests (engine=nothing)"
  exit 0
  ;;
*)
  echo "❌ ERROR: Unknown test engine '$TEST_WITH' (expected: miri|cargo|nextest|nothing)" >&2
  exit 1
  ;;
esac
