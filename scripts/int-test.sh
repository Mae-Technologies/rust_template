#!/usr/bin/env bash
set -euo pipefail

MAE_TESTCONTAINERS=1 cargo nextest run --features integration-testing
