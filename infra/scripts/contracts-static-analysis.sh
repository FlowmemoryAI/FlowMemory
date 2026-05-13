#!/usr/bin/env bash
set -euo pipefail

REQUIRE_SLITHER="${REQUIRE_SLITHER:-0}"
CHECK_FORGE_FMT="${CHECK_FORGE_FMT:-0}"

if ! command -v forge >/dev/null 2>&1; then
  echo "forge is required for contract hardening checks" >&2
  exit 1
fi

if [ "$CHECK_FORGE_FMT" = "1" ]; then
  forge fmt --check
fi
forge build
forge test

if command -v slither >/dev/null 2>&1; then
  slither . --config-file .slither.config.json
elif [ "$REQUIRE_SLITHER" = "1" ]; then
  echo "slither is required but was not found on PATH" >&2
  exit 1
else
  echo "warning: slither was not found on PATH; install slither-analyzer or set REQUIRE_SLITHER=1 in audit environments" >&2
fi
