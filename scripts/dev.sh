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
    for suite in tests/*.test.luau; do
      luau "$suite"
    done
    python3 tests/Desktop.test.py
    python3 tests/SeatReturn.test.py
    python3 tests/HomePlannerUI.test.py
    python3 tests/HomeLights.test.py
    python3 tests/HomeLightsUI.test.py
    python3 tests/WorldSignsUI.test.py
    python3 tests/ProfileLifecycle.test.py
    python3 tests/ProfileRetry.test.py
    python3 tests/ProfileRecoveryUI.test.py
    python3 tests/RecoveryCamera.test.py
    python3 tests/StudioTest.test.py
    python3 tests/StudioLaunch.test.py
    python3 tests/BuildRecovery.test.py
    python3 tests/BuildLifecycle.test.py
    python3 tests/PlacementUI.test.py
    python3 tests/PlacementAdapter.test.py
    python3 tests/PaintScopeAdapter.test.py
    python3 tests/PaintLifecycle.test.py
    python3 tests/PaintFeedbackUI.test.py
    python3 tests/PaintSurfaceUI.test.py
    python3 tests/WalletDisplay.test.py
    python3 tests/ModalControls.test.py
    python3 tests/JobResultUI.test.py
    python3 tests/JobOffersUI.test.py
    python3 tests/ContractText.test.py
    python3 tests/ClientDialogueUI.test.py
    python3 tests/ClientTalk.test.py
    python3 tests/FirstStepsUI.test.py
    python3 tests/PhoneInput.test.py
    python3 tests/FirstPurchase.test.py
    python3 tests/PurchaseUI.test.py
    python3 tests/HintsUI.test.py
    python3 tests/StorageAdapter.test.py
    python3 tests/CloudBuild.test.py
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
    luau-analyze src/shared src/server/Domain tests
    ;;
  build)
    require_tool rojo
    mkdir -p build
    rojo build default.project.json --output build/roblox-life.rbxlx
    rojo build prototype.project.json --output build/sink-prototype.rbxlx
    python3 tests/Scene.test.py
    ;;
  studio)
    exec python3 scripts/studio_open.py
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
  *) echo "Usage: bash scripts/dev.sh {prepare|format|lint|test|sourcemap|types|build|studio|serve|check}" >&2; exit 2 ;;
esac
