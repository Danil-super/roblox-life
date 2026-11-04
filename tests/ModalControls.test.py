#!/usr/bin/env python3
"""Run the real modal visibility controller with deterministic GUI signals."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/ModalControls.luau").read_text()
body = source[source.index("local Controller = {}"):].removesuffix("\n").removesuffix("return Controller")
header = r'''
local function signal()
    local callbacks = {}
    local s = {}
    function s:Connect(fn) table.insert(callbacks, fn) end
    s.Once = s.Connect
    function s:Fire() for _, fn in callbacks do fn() end end
    return s
end
local function gui(name)
    local g = {Name=name, Visible=false, changed=signal()}
    function g:IsA(class) return class=="GuiObject" end
    function g:GetPropertyChangedSignal() return self.changed end
    function g:set(value) self.Visible=value;self.changed:Fire() end
    return g
end
local phone, jobs, paint, nav = gui("HomePanel"),gui("JobsPanel"),gui("PaintToolbar"),gui("JobNavigation")
local results = gui("ResultsPanel")
local profile = gui("ProfilePanel")
local roomPlan = gui("RoomPlanPanel")
local client = gui("ClientPanel")
local screen = {Enabled=true, changed=signal(), Destroying=signal()}
function screen:GetChildren() return {phone,jobs,paint,nav,results,profile,roomPlan,client} end
function screen:GetPropertyChangedSignal() return self.changed end
local GuiService = {TouchControlsEnabled=true}
'''
scenarios = {
    "client_dialogue_transition": '''
Controller.start(screen);jobs:set(true);client:set(true);jobs:set(false)
assert(not GuiService.TouchControlsEnabled,"Conversation lost movement lock")
client:set(false);assert(GuiService.TouchControlsEnabled,"Closed conversation retained controls")
''',

    "room_plan_transition": '''
Controller.start(screen);phone:set(true);roomPlan:set(true);phone:set(false)
assert(not GuiService.TouchControlsEnabled,"Room plan released movement")
roomPlan:set(false);assert(GuiService.TouchControlsEnabled,"Room plan retained controls")
''',

    "profile_recovery": '''
Controller.start(screen);paint:set(true);profile:set(true);paint:set(false)
assert(not GuiService.TouchControlsEnabled,"Recovery released movement controls")
profile:set(false);assert(GuiService.TouchControlsEnabled,"Confirmed recovery did not release controls")
''',
    "open_close": '''
Controller.start(screen); assert(GuiService.TouchControlsEnabled)
phone:set(true); assert(not GuiService.TouchControlsEnabled)
phone:set(false); assert(GuiService.TouchControlsEnabled)
''',
    "modal_transition": '''
Controller.start(screen); phone:set(true); jobs:set(true); phone:set(false)
assert(not GuiService.TouchControlsEnabled,"Second modal lost its lock")
paint:set(true); jobs:set(false); assert(not GuiService.TouchControlsEnabled)
paint:set(false); assert(GuiService.TouchControlsEnabled)
''',
    "previously_disabled": '''
GuiService.TouchControlsEnabled=false; Controller.start(screen)
phone:set(true);phone:set(false)
assert(not GuiService.TouchControlsEnabled,"Overwrote prior disabled state")
''',
    "hud_disabled_destroyed": '''
Controller.start(screen); paint:set(true); assert(not GuiService.TouchControlsEnabled)
screen.Enabled=false;screen.changed:Fire();assert(GuiService.TouchControlsEnabled)
screen.Enabled=true;screen.changed:Fire();assert(not GuiService.TouchControlsEnabled)
screen.Destroying:Fire();assert(GuiService.TouchControlsEnabled)
''',
    "navigation_is_not_modal": '''
Controller.start(screen);nav:set(true);assert(GuiService.TouchControlsEnabled)
''',
    "results_to_shop": '''
Controller.start(screen);results:set(true);phone:set(true);results:set(false)
assert(not GuiService.TouchControlsEnabled,"Result transition released modal lock")
phone:set(false);assert(GuiService.TouchControlsEnabled)
''',
}
for name, assertions in scenarios.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + body + "\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS ModalControls:", name)

jobs_source = (ROOT / "src/client/JobController.luau").read_text()
start = jobs_source.index("\tlocal function revealActions(): ()")
finish = jobs_source.index('\n\tjobs:GetPropertyChangedSignal("Visible")', start)
reveal = jobs_source[start:finish]
for height, phase in ((116, "ChooseMaterial"), (170, "ChooseMaterial"), (266, "Offer"), (266, "Completed"), (170, "Prepare")):
    setup = f'''
local Vector2 = {{new=function(x,y) return {{X=x,Y=y}} end}}
local jobs = {{Visible=true}}
local state = {{phase="{phase}"}}
local jobBody = {{AbsoluteSize={{Y={height}}}}}
'''
    assertions = '''
revealActions()
local offset = jobBody.CanvasPosition.Y
assert(168-offset >= 0 and 212-offset <= jobBody.AbsoluteSize.Y,"Primary action clipped")
if state.phase=="ChooseMaterial" then
    assert(116-offset >= 0 and 160-offset <= jobBody.AbsoluteSize.Y,"Tool choice clipped")
    local cancelOffset=math.max(0,268-jobBody.AbsoluteSize.Y)
    assert(224-cancelOffset>=0 and 268-cancelOffset<=jobBody.AbsoluteSize.Y,"Cancel not reachable by scrolling")
elseif state.phase~="Offer" and state.phase~="Completed" then
    assert(224-offset >= 0 and 268-offset <= jobBody.AbsoluteSize.Y,"Cancel clipped")
end
jobs.Visible=false;jobBody.CanvasPosition={Y=7};revealActions()
assert(jobBody.CanvasPosition.Y==7,"Hidden panel changed scroll")
'''
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(setup + reveal + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS JobActions:", height, phase)
