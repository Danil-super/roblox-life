#!/usr/bin/env python3
"""Open the local place once; repeated VS Code tasks must not spawn more Studio windows."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def studio_processes(proc=Path("/proc")):
    result = []
    for folder in proc.iterdir():
        if not folder.name.isdigit():
            continue
        try:
            if folder.stat().st_uid != os.getuid():
                continue
            executable = (folder / "cmdline").read_bytes().split(b"\0", 1)[0]
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        name = executable.strip(b'"').replace(b"\\", b"/").rsplit(b"/", 1)[-1].lower()
        if name == b"robloxstudiobeta.exe":
            result.append(int(folder.name))
    return sorted(result)


def open_once(root, proc=Path("/proc")):
    root = root.resolve()
    place = root / "build/roblox-life.rbxlx"
    if not place.is_file():
        raise FileNotFoundError("Build the place first: bash scripts/dev.sh build")
    tools = root / ".tools"
    tools.mkdir(exist_ok=True)
    with (tools / "studio-launch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if studio_processes(proc):
            return "existing"
        reservation = tools / "studio-launch.json"
        if reservation.exists():
            try:
                record = json.loads(reservation.read_text())
                pid = record.get("pid")
            except (ValueError, AttributeError):
                pid = None
            # Flatpak/Wine startup may take time before the actual Studio process exists.
            if time.time() - reservation.stat().st_mtime < 90 or (
                type(pid) is int and pid > 0 and (proc / str(pid)).exists()
            ):
                return "starting"
        if not shutil.which("flatpak"):
            raise RuntimeError("Install Vinegar Flatpak as described in README.md.")
        command = ["flatpak", "run", "org.vinegarhq.Vinegar", "--task", "EditFile",
                   "--localPlaceFile", "Z:" + str(place).replace("/", "\\")]
        descriptor = os.open(tools / "studio-launch.log", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        with os.fdopen(descriptor, "ab") as log:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        reservation.write_text(json.dumps({"pid": process.pid}))
        return "started"


def main():
    try:
        result = open_once(Path(__file__).resolve().parents[1])
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Studio: {error}", file=sys.stderr)
        return 1
    print({"existing": "Studio is already open. Use its existing project tab; no new window was opened.",
           "starting": "Studio startup is already in progress; no duplicate was started.",
           "started": "Studio startup requested. Log: .tools/studio-launch.log"}[result])
    return 0


if __name__ == "__main__":
    sys.exit(main())
