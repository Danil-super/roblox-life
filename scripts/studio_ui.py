#!/usr/bin/env python3
"""Check the actual HUD target before sending input through official Studio MCP."""
import argparse
import json
import re

from studio_test import StudioRpc


def inspect_code(path: str) -> str:
    if not path or len(path) > 512 or not all(re.fullmatch(r"[A-Za-z0-9_-]+", part) for part in path.split(".")):
        raise ValueError("Use a relative NeighborhoodHUD path with named components")
    parts = "{" + ",".join(json.dumps(part) for part in path.split(".")) + "}"
    return '''--!strict
local function result(ready: boolean, visible: boolean, reason: string): string
 return game.HttpService:JSONEncode({ready=ready,visible=visible,reason=reason})
end
local player=game.Players.LocalPlayer
if not game:GetService("RunService"):IsRunning() or player==nil then return result(false,false,"NotPlaying")end
local node: Instance?=player.PlayerGui:FindFirstChild("NeighborhoodHUD")
for _,name in ''' + parts + ''' do
 if node==nil then return result(false,false,"Missing")end
 node=node:FindFirstChild(name)
end
if node==nil then return result(false,false,"Missing")end
if not node:IsA("GuiObject")then return result(false,false,"NotGui")end
local target=node
local pos,size=target.AbsolutePosition,target.AbsoluteSize
if size.X<=0 or size.Y<=0 then return result(false,false,"Geometry")end
local x,y=pos.X+size.X/2,pos.Y+size.Y/2
local ancestor: Instance?=target
while ancestor do
 if ancestor:IsA("ScreenGui")and not ancestor.Enabled then return result(false,false,"Hidden")end
 if ancestor:IsA("GuiObject")then
  if not ancestor.Visible then return result(false,false,"Hidden")end
  if ancestor.ClipsDescendants then
   local p,s=ancestor.AbsolutePosition,ancestor.AbsoluteSize
   if x<p.X or y<p.Y or x>=p.X+s.X or y>=p.Y+s.Y then return result(false,false,"Clipped")end
  end
 end
 ancestor=ancestor.Parent
end
if not target:IsA("GuiButton")then return result(false,true,"NotButton")end
if not target.Active or not target.Interactable then return result(false,true,"Inactive")end
for _,hit in player.PlayerGui:GetGuiObjectsAtPosition(x,y)do
 if hit==target or hit:IsDescendantOf(target)then return result(true,true,"Ready")end
 if not target:IsDescendantOf(hit)then return result(false,true,"Covered")end
end
return result(false,true,"NotHit")
'''


def inspect(client, studio_id: str, path: str) -> dict:
    return json.loads(client.tool("execute_luau", {
        "studio_id": studio_id, "datamodel_type": "Client", "code": inspect_code(path),
    }))


def click(client, studio_id: str, path: str, *, expect: str | None = None) -> None:
    # Validate both paths before any input, including a malformed postcondition.
    inspect_code(path)
    if expect is not None:
        inspect_code(expect)
    result = inspect(client, studio_id, path)
    if not result.get("ready"):
        raise RuntimeError(f"UI target {path}: {result.get('reason', 'Unavailable')}")
    client.tool("user_mouse_input", {
        "studio_id": studio_id, "datamodel_type": "Client", "actions": [
            {"action": "mouseButtonClick", "instance_path": "LocalPlayer.PlayerGui.NeighborhoodHUD." + path,
             "mouse_button": "left"},
            {"action": "wait", "wait_time_ms": 600},
        ],
    })
    if expect is not None and not inspect(client, studio_id, expect).get("visible"):
        raise RuntimeError(f"UI transition after {path}: {expect} is not visible; no retry was sent")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Relative HUD button path")
    parser.add_argument("--studio-id", required=True)
    parser.add_argument("--expect", help="HUD panel that must be visible after the click")
    args = parser.parse_args()
    client = StudioRpc()
    try:
        studios = json.loads(client.tool("list_roblox_studios", {})).get("studios", [])
        if len(studios) != 1 or studios[0]["id"] != args.studio_id or studios[0]["name"] not in ("NeighborhoodFixer", "roblox-life.rbxlx"):
            raise RuntimeError("Select the one open Roblox Life Studio; no window was opened")
        click(client, args.studio_id, args.path, expect=args.expect)
        print("Verified UI click:", args.path)
    finally:
        client.close()


if __name__ == "__main__":
    main()
