#!/usr/bin/env bash
set -euo pipefail
# Refresh Cargo.lock if Cargo.toml was updated via Docker Compose Watch sync
# after the image was built (e.g. dep version bump). Deps are already cached
# from the cook step so this is fast and avoids "failed to write Cargo.lock".
cargo fetch 2>/dev/null || true
exec cargo watch -x 'run' -w src -w Cargo.toml
