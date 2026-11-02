#!/usr/bin/env python3
"""Launch Roblox's official stdio MCP executable inside the running Vinegar sandbox."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def launch_command():
  if not shutil.which("flatpak"):
    raise RuntimeError("Flatpak is missing. This launcher supports Vinegar on Linux.")
  result = subprocess.run(
    ["flatpak", "ps", "--columns=instance,pid,application"],
    capture_output=True, text=True, check=True, timeout=10,
  )
  instances = [line.split() for line in result.stdout.splitlines()
               if len(line.split()) == 3 and line.split()[2] == "org.vinegarhq.Vinegar"]
  if not instances:
    raise RuntimeError("Open Roblox Studio through Vinegar before connecting MCP.")
  # A manager window may keep an older sandbox alive. Start in the newest one;
  # Studio's own MCP router still requires an explicit studio_id for every call.
  selected = max(instances, key=lambda row: int(row[1]))
  instance = selected[0]
  if not instance.isdigit():
    raise RuntimeError("Flatpak returned an invalid sandbox identifier.")
  base = Path.home() / ".var/app/org.vinegarhq.Vinegar/data/vinegar"
  wine = base / "kombucha/bin/wine"
  prefix = base / "prefixes/studio"
  versions = list((base / "versions").glob("*/StudioMCP.exe"))
  if not wine.is_file() or not prefix.is_dir() or not versions:
    raise RuntimeError("StudioMCP.exe or Vinegar's Wine prefix is missing. Complete Studio setup first.")
  # Vinegar keeps previous deployments; prefer its most recently installed executable.
  executable = max(versions, key=lambda path: path.stat().st_mtime_ns)
  environment = ["LANG=C.UTF-8", "LC_ALL=C.UTF-8", "WINEDEBUG=-all", f"WINEPREFIX={prefix}",
                 "XAUTHORITY=/run/flatpak/Xauthority"]
  for name in ("DISPLAY", "WAYLAND_DISPLAY"):
    if os.environ.get(name):
      environment.append(f"{name}={os.environ[name]}")
  return ["flatpak", "enter", instance, "env", *environment, str(wine), str(executable)]


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--check", action="store_true", help="Check paths without starting MCP")
  args = parser.parse_args()
  try:
    command = launch_command()
  except (RuntimeError, subprocess.SubprocessError) as error:
    print(f"Studio MCP: {error}", file=sys.stderr)
    return 1
  if args.check:
    print(json.dumps({"wine": command[-2], "server": command[-1], "sandbox": command[2]}))
    return 0
  # Preserve stdin/stdout for MCP; no proxy server, API credentials or downloads.
  os.execvp(command[0], command)


if __name__ == "__main__":
  sys.exit(main())
