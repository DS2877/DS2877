#!/usr/bin/env bash
# Cloud environment setup for Claude Code on the web.
#
# Paste this into the environment's setup script field (docs/PHILIP-TODO.md #5).
#
# WHY CARGO AND NOT ROKIT: the egress proxy blocks github.com releases and
# codeload.github.com (403), so Rokit and every prebuilt binary are
# unreachable. index.crates.io and static.crates.io are reachable, so we build
# from source. Measured cold install times on a 4-core runner, 2026-09-16:
#
#     stylua   44s      selene  54s      lune  172s
#     rojo    101s      wally   69s      -> 440s total (~7.3 min)
#
# Measured again on a second cold container: 573s (9.5 min) -- the machine,
# not the plan, is the variable. Budget 7-10 minutes.
#
# Either way it is over the ~5 minute setup budget, so tools install in priority order:
# if the script is cut short, we lose the least important ones first. Results
# are cached for about a week, so this is a cold-start cost only.
#
# luau-lsp is NOT installable here -- it is a C++ project with no crates.io
# package. Typechecking is CI-only. See docs/DECISIONS.md D-014.

set -euo pipefail

export CARGO_HTTP_CAINFO=/root/.ccr/ca-bundle.crt
BIN_DIR="${HOME}/.cargo/bin"
export PATH="${BIN_DIR}:${PATH}"

# Priority order: the fast inner loop first (format, lint, tests), then build,
# then packages.
TOOLS=(
  "stylua:2.5.2"
  "selene:0.31.0"
  "lune:0.10.5"
  "rojo:7.7.0"
  "wally:0.3.2"
)

echo "==> Installing Roblox toolchain from crates.io"
started=$(date +%s)

for entry in "${TOOLS[@]}"; do
  name="${entry%%:*}"
  version="${entry##*:}"

  if command -v "$name" >/dev/null 2>&1; then
    installed="$("$name" --version 2>/dev/null | head -1 || true)"
    if [[ "$installed" == *"$version"* ]]; then
      echo "  $name $version already present, skipping"
      continue
    fi
  fi

  echo "  installing $name $version ..."
  if cargo install --locked "$name" --version "$version" >/dev/null 2>&1; then
    echo "    ok ($(( $(date +%s) - started ))s elapsed)"
  else
    # A missing tool degrades the session; it must not abort setup, or the
    # session starts with nothing at all.
    echo "    WARNING: $name failed to install; continuing" >&2
  fi
done

echo "==> Toolchain ready in $(( $(date +%s) - started ))s"
for t in stylua selene lune rojo wally; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '    %-8s %s\n' "$t" "$($t --version 2>&1 | head -1)"
  else
    printf '    %-8s MISSING\n' "$t"
  fi
done

echo "==> Note: luau-lsp is unavailable here by design; typecheck runs in CI."
