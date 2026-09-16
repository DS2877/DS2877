#!/usr/bin/env bash
# Everything CI runs, runnable locally in one command.
#
#     ./scripts/check.sh          run all checks
#     ./scripts/check.sh --fix    format in place, then check
#
# Run this before every push. One validated push beats three speculative ones.

set -uo pipefail
cd "$(dirname "$0")/.."

export PATH="${HOME}/.cargo/bin:${PATH}"

FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

fail=0
step() {
  local label="$1"; shift
  printf '\n\033[1m==> %s\033[0m\n' "$label"
  if "$@"; then
    printf '    \033[32mPASS\033[0m\n'
  else
    printf '    \033[31mFAIL\033[0m\n'
    fail=1
  fi
}

if [[ $FIX -eq 1 ]]; then
  step "Format (writing)" stylua --syntax Luau src tests
else
  step "Format check" stylua --syntax Luau --check src tests
fi

step "Lint" selene src tests
step "Unit tests" lune run tests/unit/run
step "Economy parity" python3 tests/parity/economy_parity.py
step "Catalog validation" python3 tools/validate-catalog.py
step "Rojo build" rojo build default.project.json --output /tmp/nomling-check.rbxl

printf '\n'
if [[ $fail -eq 0 ]]; then
  printf '\033[32mAll checks passed.\033[0m\n'
else
  printf '\033[31mChecks failed.\033[0m\n'
fi
exit $fail
