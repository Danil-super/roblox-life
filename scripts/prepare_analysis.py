#!/usr/bin/env python3
"""Fetch pinned Roblox types and generate Selene's Roblox standard library."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau"
SHA256 = "2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080"


def main():
  os.chdir(ROOT)
  os.environ["PATH"] = str(ROOT / ".tools/bin") + os.pathsep + str(Path.home() / ".rokit/bin") + os.pathsep + os.environ["PATH"]
  target = ROOT / ".tools/definitions/roblox.d.luau"
  target.parent.mkdir(parents=True, exist_ok=True)
  if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != SHA256:
    partial = target.with_suffix(".part")
    subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--proto", "=https",
                    "--connect-timeout", "15", "--max-time", "120", "--retry", "2", URL,
                    "--output", str(partial)], check=True)
    if hashlib.sha256(partial.read_bytes()).hexdigest() != SHA256:
      partial.unlink()
      raise RuntimeError("Roblox definitions SHA-256 mismatch")
    partial.replace(target)
  if not (ROOT / "roblox.yml").is_file():
    if not shutil.which("selene"):
      raise RuntimeError("Install Selene first: python3 scripts/bootstrap.py")
    subprocess.run(["selene", "generate-roblox-std"], check=True)
  print("Analysis data ready (Roblox definitions pinned to luau-lsp 1.70.1).")


if __name__ == "__main__":
  main()
