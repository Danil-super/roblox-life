#!/usr/bin/env python3
"""Generate ignored machine-local VS Code paths; keep the repository portable."""
import json
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent


def main():
  os.environ["PATH"] = str(ROOT / ".tools/bin") + os.pathsep + str(Path.home() / ".rokit/bin") + os.pathsep + os.environ["PATH"]
  settings = {}
  for tool, setting in [("selene", "selene.selenePath"), ("stylua", "stylua.styluaPath"),
                        ("luau-lsp", "luau-lsp.server.path")]:
    binary = shutil.which(tool)
    if not binary:
      raise RuntimeError(f"Missing {tool}; run bootstrap first")
    settings[setting] = binary
  target = ROOT / "roblox-life.local.code-workspace"
  target.write_text(json.dumps({"folders": [{"path": "."}], "settings": settings}, indent=2) + "\n")
  print(f"Editor configured: code {target.name}")


if __name__ == "__main__":
  main()
