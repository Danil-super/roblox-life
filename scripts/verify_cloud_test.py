#!/usr/bin/env python3
"""Compare four SAVE-01 snapshots copied from Roblox Studio Output."""

import argparse
import json
import math
from pathlib import Path
import re

STAGES = ("wall-before", "wall-after", "furniture-before", "furniture-after")
PREFIX = "SAVE01 "


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_snapshots(output: str) -> list[dict]:
    decoder = json.JSONDecoder()
    snapshots = []
    for line in output.splitlines():
        _, prefix, payload = line.partition(PREFIX)
        if not prefix or not payload.lstrip().startswith("{"):
            continue
        snapshot, _ = decoder.raw_decode(payload.lstrip())
        snapshots.append(snapshot)
    require(tuple(s.get("stage") for s in snapshots) == STAGES,
            "Expected one snapshot per stage in order. Keep the four captures from one run.")
    return snapshots


def positive(value: object) -> bool:
    return type(value) is int and 0 < value <= 9007199254740991


def verify(output: str) -> dict:
    snapshots = read_snapshots(output)
    first, resumed, placed, restored = snapshots
    target = (first.get("universe"), first.get("place"), first.get("scope"))
    require(positive(target[0]) and positive(target[1]) and isinstance(target[2], str)
            and re.fullmatch(r"qa-[a-z0-9][a-z0-9-]{0,19}", target[2]) is not None,
            "First capture does not name a valid published QA target.")
    require(all(s.get("schema") == 1 and (s.get("universe"), s.get("place"), s.get("scope")) == target
                and positive(s.get("universe")) and positive(s.get("place")) for s in snapshots),
            "Captures use different targets or schema versions.")
    require(all(positive(s.get("fence")) for s in snapshots) and
            tuple(s["fence"] for s in snapshots) == (1, 2, 2, 3),
            "Expected a fresh run with exactly three successive profile acquisitions.")
    require(all(positive(s.get("revision")) for s in snapshots) and
            first["revision"] == resumed["revision"] < placed["revision"] == restored["revision"],
            "A profile revision changed across a rejoin or the furniture was never saved.")

    job = first.get("job")
    require(isinstance(job, dict) and isinstance(job.get("id"), str) and len(job["id"]) > 0,
            "Initial saved job is missing.")
    cells = job.get("cells")
    require(isinstance(cells, dict) and cells.get("columns") == 12 and cells.get("rows") == 8,
            "Initial wall has the wrong grid.")
    masks = cells.get("masks")
    require(isinstance(masks, list) and len(masks) == 1 and isinstance(masks[0], str)
            and re.fullmatch(r"[01]{96}", masks[0]) is not None and masks[0].count("1") >= 77,
            "Initial wall needs a checked mask of at least 77 of 96 cells.")
    for wall in (first, resumed):
        require(wall.get("job") == job and job.get("status") == "Accepted" and job.get("reward") is None
                and all(type(wall.get(field)) is int and wall[field] == 0
                        for field in ("dollars", "xp", "completed", "housingRevision"))
                and wall.get("items") in ([], {}),
                "Unpaid checkpoint or empty starter profile changed after the first rejoin.")

    items = placed.get("items")
    require(isinstance(items, list) and len(items) == 1 and isinstance(items[0], dict),
            "Capture the first installation with exactly one owned plant.")
    item = items[0]
    require(isinstance(item.get("id"), str) and len(item["id"]) > 0
            and item.get("catalog") in ("floor-plant-v1", "floor-plant-coral-v1", "floor-plant-lagoon-v1")
            and item.get("price") == 180,
            "The one owned item must be a starter plant priced at $180.")
    pose = item.get("pose")
    require(isinstance(pose, dict) and pose.get("roomTemplateVersion") == 1
            and all(type(pose.get(axis)) in (int, float) and math.isfinite(pose[axis])
                    for axis in ("x", "y", "z", "rotationY")),
            "Item has no valid room-relative installed pose.")
    for home in (placed, restored):
        finished = home.get("job")
        require(isinstance(finished, dict) and finished.get("id") == job["id"]
                and finished.get("status") == "Completed" and finished.get("cells") == cells
                and finished.get("reward") == 250,
                "Completed job did not retain the checked wall and $250 receipt.")
        require(home.get("dollars") == 70 and home.get("xp") == 50 and home.get("completed") == 1
                and home.get("housingRevision") == 1 and home.get("step") == "DONE"
                and home.get("items") == items,
                "Saved balance, progress, item identity or installed pose changed across rejoin.")
    return {"scope": target[2], "covered": masks[0].count("1"), "dollars": 70, "xp": 50, "acquisitions": 3}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Text file containing the four SAVE01 Output lines")
    args = parser.parse_args()
    try:
        result = verify(args.output.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        parser.exit(1, f"SAVE-01 comparison failed: {error}\n")
    print("SAVE-01 snapshots match: " + json.dumps(result))


if __name__ == "__main__":
    main()
