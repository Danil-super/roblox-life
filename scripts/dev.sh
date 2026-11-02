#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
export PATH="$PWD/.tools/bin:$HOME/.rokit/bin:$PATH"

require_tool() {
  command -v "$1" >/dev/null || { echo "Missing $1. Run python3 scripts/bootstrap.py or rokit install." >&2; exit 1; }
}

case "${1:-check}" in
  prepare)
    python3 scripts/prepare_analysis.py
    ;;
  format)
    require_tool stylua
    stylua src tests
    ;;
  lint)
    require_tool selene
    selene src tests
    ;;
  test)
    require_tool luau
    luau tests/ChoreRules.test.luau
    ;;
  sourcemap)
    require_tool rojo
    rojo sourcemap default.project.json --include-non-scripts --output sourcemap.json
    ;;
  types)
    require_tool luau-lsp
    test -s .tools/definitions/roblox.d.luau || { echo "Run bash scripts/dev.sh prepare first" >&2; exit 1; }
    bash scripts/dev.sh sourcemap
    luau-lsp analyze --platform=roblox --definitions=.tools/definitions/roblox.d.luau --sourcemap=sourcemap.json src
    require_tool luau-analyze
    luau-analyze src/shared tests
    ;;
  build)
    require_tool rojo
    mkdir -p build
    rojo build default.project.json --output build/roblox-life.rbxlx
    python3 tests/Scene.test.py
    ;;
  serve)
    require_tool rojo
    exec rojo serve default.project.json --address 127.0.0.1 --port 34872
    ;;
  check)
    require_tool stylua
    stylua --check src tests
    bash scripts/dev.sh lint
    bash scripts/dev.sh test
    bash scripts/dev.sh types
    bash scripts/dev.sh build
    ;;
  *) echo "Usage: bash scripts/dev.sh {prepare|format|lint|test|sourcemap|types|build|serve|check}" >&2; exit 2 ;;
esac
