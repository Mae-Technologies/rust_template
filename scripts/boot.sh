#!/usr/bin/env bash
set -euo pipefail
exec cargo watch -x 'run' -w src -w Cargo.toml
