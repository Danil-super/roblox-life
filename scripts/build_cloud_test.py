#!/usr/bin/env python3
"""Build an explicit Studio cloud-QA copy without changing source or publishing."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MAX_ID = 9007199254740991


def make_project(root: Path, universe_id: int, place_id: int, run_id: str | None = None) -> dict:
    for value in (universe_id, place_id):
        if isinstance(value, bool) or not isinstance(value, int) or not 0 < value <= MAX_ID:
            raise ValueError("Universe ID and Place ID must be positive exact integers")
    if run_id is not None and (not isinstance(run_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,19}", run_id)):
        raise ValueError("Run ID must have 1 to 20 lowercase letters, digits or hyphens and start with a letter or digit")
    project = json.loads((root / "default.project.json").read_text())

    def paths(node: object) -> None:
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path" and isinstance(value, str):
                    node[key] = str((root / value).resolve())
                else:
                    paths(value)
        elif isinstance(node, list):
            for value in node:
                paths(value)

    paths(project)
    settings = project["tree"]["ServerStorage"]["DevelopmentSettings"]
    settings["StudioDataStoreTest"]["$properties"]["Value"] = True
    settings["TestUniverseId"]["$properties"]["Value"] = universe_id
    settings["TestPlaceId"]["$properties"]["Value"] = place_id
    if run_id is not None:
        settings["TestRunId"] = {"$className": "StringValue", "$properties": {"Value": run_id}}
        project["tree"]["ServerStorage"]["CloudQASnapshot"] = {
            "$path": str((root / "scripts/cloud_qa_snapshot.luau").resolve())
        }
    project["name"] = "NeighborhoodFixerCloudQA"
    project["serveAddress"] = "127.0.0.1"
    project["servePort"] = 34873
    return project


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--universe-id", type=int, required=True)
    parser.add_argument("--place-id", type=int, required=True)
    parser.add_argument("--run-id", help="Reuse the same identifier across the Play sessions of one acceptance run")
    parser.add_argument("--check", action="store_true", help="Validate arguments without building")
    args = parser.parse_args()
    try:
        project = make_project(ROOT, args.universe_id, args.place_id, args.run_id)
    except ValueError as error:
        parser.error(str(error))
    scope = f"qa-{args.run_id}" if args.run_id else "global"
    if args.check:
        print(f"QA target: universe={args.universe_id}, place={args.place_id}; scope={scope}; no cloud access")
        return
    local_rojo = ROOT / ".tools/bin/rojo"
    rojo = str(local_rojo) if local_rojo.is_file() else shutil.which("rojo")
    if not rojo:
        parser.error("Rojo is missing; run scripts/bootstrap.py")
    output = ROOT / "build"
    output.mkdir(exist_ok=True)
    project_path = output / "cloud-test.project.json"
    scene_path = output / "cloud-test.rbxlx"
    project_path.write_text(json.dumps(project, indent=2, ensure_ascii=False) + "\n")
    subprocess.run([rojo, "build", str(project_path), "--output", str(scene_path)], cwd=ROOT, check=True)
    print(f"QA scene: {scene_path}")
    print(f"Expected universe={args.universe_id}, place={args.place_id}")
    print("Studio DataStore: NeighborhoodFixer_P0_StudioQA_v1")
    print(f"Scope: {scope}")
    print("No publishing or cloud requests performed; default source remains MemoryPreview.")


if __name__ == "__main__":
    main()
