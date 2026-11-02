#!/usr/bin/env python3
"""Install missing official release binaries locally; never replace existing tools."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / ".tools"


def install(asset):
  binary = TOOLS / "bin" / asset["name"]
  existing = shutil.which(asset["name"])
  if all((TOOLS / "bin" / name).is_file() or shutil.which(name) for name in asset["files"]):
    print(f"Keep {asset['name']}: {binary if binary.is_file() else existing}", flush=True)
    return
  archive = TOOLS / "downloads" / (asset["name"] + ".zip")
  def verified():
    return archive.is_file() and hashlib.sha256(archive.read_bytes()).hexdigest() == asset["sha256"]
  if not verified():
    partial = archive.with_suffix(".part")
    print(f"Download {asset['name']} {asset['version']} from GitHub", flush=True)
    subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                    "--proto", "=https", "--connect-timeout", "15", "--max-time", "600",
                    "--retry", "2", asset["url"], "--output", str(partial)], check=True)
    if hashlib.sha256(partial.read_bytes()).hexdigest() != asset["sha256"]:
      partial.unlink()
      raise RuntimeError(f"SHA-256 mismatch: {asset['name']}")
    partial.replace(archive)
  with zipfile.ZipFile(archive) as package:
    for name in asset["files"]:
      target = TOOLS / "bin" / name
      if target.exists() or shutil.which(name):
        continue
      # Select exact basename, never extract archive paths into the project.
      members = [p for p in package.namelist() if Path(p).name == name and not p.endswith("/")]
      if len(members) != 1:
        raise RuntimeError(f"Expected one binary {name}, got {members}")
      target.write_bytes(package.read(members[0]))
      target.chmod(0o755)
  print(f"Installed {asset['name']} {asset['version']}", flush=True)


def main():
  if platform.system() != "Linux" or platform.machine() not in ("x86_64", "amd64"):
    sys.exit("This locked bootstrap is for Ubuntu x86_64; use Rokit on other platforms.")
  if not shutil.which("curl"):
    sys.exit("Install curl: sudo apt install curl")
  for directory in ("bin", "downloads"):
    (TOOLS / directory).mkdir(parents=True, exist_ok=True)
  manifest = json.loads((ROOT / "scripts/toolchain.json").read_text())
  failed = False
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    futures = {pool.submit(install, asset): asset["name"] for asset in manifest["assets"]}
    for future in concurrent.futures.as_completed(futures):
      try:
        future.result()
      except Exception as error:
        print(f"FAILED {futures[future]}: {error}", file=sys.stderr)
        failed = True
  if failed:
    sys.exit(1)
  subprocess.run([sys.executable, str(ROOT / "scripts/configure_editor.py")], check=True)
  print('Ready. Add local tools to this terminal: export PATH="$PWD/.tools/bin:$HOME/.rokit/bin:$PATH"')


if __name__ == "__main__":
  main()
