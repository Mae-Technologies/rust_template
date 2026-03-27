#!/usr/bin/env bash
set -euo pipefail

cargo fetch 2>/dev/null || true

exec cargo watch -w src -w Cargo.toml -w migrations -w ../lib -s 'bash scripts/dev-run.sh'
