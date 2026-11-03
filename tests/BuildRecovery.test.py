#!/usr/bin/env python3
"""Exercise actual builder recovery callbacks with isolated Luau state.

This checks callback transitions, not Roblox input, networking, camera cleanup,
or DataStore delivery. Business branches come directly from BuildController;
render and stop are observable external dependencies.
"""
from pathlib import Path
import argparse
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=ROOT / "src/client/BuildController.luau")
args = parser.parse_args()
source = args.source.read_text()
assert source.startswith("--!strict"), "Runtime source must remain strict"

# Extract the implementation verbatim; fail visibly if its enclosing structure changes.
change_start = source.index("\tlocal function change(): ()")
change_end = source.index("\n\tbuttons.Mode.Activated", change_start)
change = source[change_start:change_end]
update_start = source.index("update = function(s: Types.Snapshot): ()")
update_end = source.index("\n\t\tend,", update_start) + len("\n\t\tend")
update = "local " + source[update_start:update_end]
touch_end_start = source.index("\tUIS.InputEnded:Connect")
touch_end_finish = source.index("\n\tplayer.CharacterRemoving:Connect", touch_end_start)
touch_end = source[touch_end_start:touch_end_finish]

header = r'''
local snapshot = {
    available = true, editorId = "editor-a", homeName = "Home_1",
    nearHome = true, revision = 0,
    items = {{ id = "plant-a", placed = {x = 9, z = 3, rotationY = 0} }},
}
local active, waiting, valid, dirty = true, true, true, false
local item = { id = "plant-a" }
local x, z, rotation = 5, 3, 0
local reason = "Saving"
local stopCalls, renderCalls = 0, 0
local function stop(): () stopCalls += 1 end
local function render(): () renderCalls += 1 end
local pinned, touch = false, nil
local ended
local UIS = { InputEnded = { Connect = function(_, callback) ended = callback end } }
-- Coordinate-only stand-ins: the callback still decides when and how to aim/pin.
local Vector2 = {}
local vectorMetatable = {
    __add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end,
}
function Vector2.new(x, y) return setmetatable({X = x, Y = y}, vectorMetatable) end
local GuiService = { GetGuiInset = function() return Vector2.new(4, 36) end }
local aimCalls, aimedAt, aimHit = 0, nil, true
local function aim(position)
    aimCalls += 1
    aimedAt = position
    return aimHit
end
local function state(available: boolean, errorMessage: string?, editorId: string?, matching: boolean)
    return {
        available = available, editorId = editorId or "editor-a", homeName = "Home_1",
        nearHome = true, revision = if matching then 1 else 0,
        error = errorMessage,
        items = if matching
            then {{ id = "plant-a", placed = {x = 5, z = 3, rotationY = 0} }}
            else {{ id = "plant-a", placed = {x = 9, z = 3, rotationY = 0} }},
    }
end
'''

scenarios = {
    "unavailable_then_ready_old_pose": r'''
update(state(false, "Unavailable", nil, false))
update(state(true, nil, nil, false))
assert(stopCalls == 0, "A transient rejection must keep the editor open")
assert(not waiting, "Confirmed old pose must unlock the rejected placement")
assert(not valid and dirty, "Recovered editor must request a fresh server preview")
''',
    "unknown_then_ready_matching_pose": r'''
update(state(false, "Unavailable", nil, false))
assert(waiting and stopCalls == 0, "An unknown write must wait for confirmed profile data")
update(state(true, nil, nil, true))
assert(stopCalls == 1, "An acknowledged matching placement must close the editor once")
''',
    "changed_editor_nonce": r'''
update(state(false, "Restart", "editor-b", false))
assert(stopCalls == 1, "A changed editor nonce must close the stale editor")
''',
    "quick_touch_pins_final_floor_position": r'''
waiting = false
local input = {Position = {X = 10, Y = 20}}
touch = input
ended(input)
assert(aimCalls == 1, "Touch release must aim even without an intervening render tick")
assert(aimedAt.X == 14 and aimedAt.Y == 56, "Aim must use final touch coordinates plus GUI inset")
assert(pinned and touch == nil, "Successful final floor hit must pin the position and release touch")
assert(renderCalls == 1, "Touch release must refresh the confirmation controls")
''',
    "touch_miss_does_not_pin": r'''
waiting = false
pinned = true
aimHit = false
local input = {Position = {X = 10, Y = 20}}
touch = input
ended(input)
assert(aimCalls == 1, "Touch release must test the final floor position")
assert(not pinned and touch == nil, "A final raycast miss must not leave a position pinned")
''',
}

failed = False
for name, assertions in scenarios.items():
    script = "--!strict\n" + header + change + "\n" + update + "\n" + touch_end + "\n" + assertions
    script += '\nprint("PASS BuildRecovery", "' + name + '")\n'
    with tempfile.NamedTemporaryFile("w", suffix=".luau") as temporary:
        temporary.write(script)
        temporary.flush()
        print(f"Running {name} using {args.source}", flush=True)
        result = subprocess.run(["luau", temporary.name], cwd=ROOT, timeout=30)
        failed |= result.returncode != 0
raise SystemExit(1 if failed else 0)
