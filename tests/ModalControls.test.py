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
local guide = gui("GuidePanel")
local abandon = gui("AbandonPanel")
local screen = {Enabled=true, changed=signal(), Destroying=signal()}
local modalOpen=nil
function screen:SetAttribute(name,value) assert(name=="ModalOpen");modalOpen=value end
function screen:GetChildren() return {phone,jobs,paint,nav,results,profile,roomPlan,client,guide,abandon} end
function screen:GetPropertyChangedSignal() return self.changed end
local GuiService = {TouchControlsEnabled=true}
local Enum={CoreGuiType={Chat="Chat"}}
local chatEnabled,chatWrites=true,0
local StarterGui={
 GetCoreGuiEnabled=function(_,kind)assert(kind=="Chat");return chatEnabled end,
 SetCoreGuiEnabled=function(_,kind,value)assert(kind=="Chat");chatEnabled=value;chatWrites+=1 end,
}
'''
scenarios = {
    "paint_hides_chat_and_restores_on_modal_transition": '''
Controller.start(screen);phone:set(true);assert(chatEnabled and chatWrites==0)
paint:set(true);assert(not chatEnabled,"Chat textbox still covers the paint surface")
phone:set(false);jobs:set(true);assert(chatWrites==1,"Sync/other panels overwrote the saved chat state")
paint:set(false);assert(chatEnabled and not GuiService.TouchControlsEnabled,"Paint exit did not restore chat during another modal")
jobs:set(false);assert(chatWrites==2 and GuiService.TouchControlsEnabled)
''',
    "paint_preserves_previously_disabled_chat": '''
chatEnabled=false;Controller.start(screen);paint:set(true);paint:set(false)
assert(not chatEnabled,"Paint enabled a previously disabled chat")
''',
    "paint_chat_hud_disable_reenable_destroy": '''
Controller.start(screen);paint:set(true);assert(not chatEnabled)
screen.Enabled=false;screen.changed:Fire();assert(chatEnabled)
screen.Enabled=true;screen.changed:Fire();assert(not chatEnabled)
screen.Destroying:Fire();assert(chatEnabled)
paint:set(false);paint:set(true);assert(chatEnabled,"Destroyed HUD changed chat")
''',
    "paint_chat_detected_when_other_panel_is_first": '''
Controller.start(screen);phone:set(true);paint:set(true)
assert(not chatEnabled,"Earlier visible panel hid the painting mode")
paint:set(false);assert(chatEnabled and not GuiService.TouchControlsEnabled)
''',
    "abandon_confirmation": '''
Controller.start(screen);jobs:set(true);abandon:set(true);jobs:set(false)
assert(modalOpen and not GuiService.TouchControlsEnabled,"Confirmation released movement")
phone:set(true);abandon:set(false);assert(modalOpen and not GuiService.TouchControlsEnabled)
phone:set(false);assert(not modalOpen and GuiService.TouchControlsEnabled,"Closed confirmation retained movement")
''',
    "interaction_blocking": '''
Controller.start(screen);assert(modalOpen==false)
phone:set(true);assert(modalOpen==true)
guide:set(true);phone:set(false);assert(modalOpen==true)
guide:set(false);assert(modalOpen==false)
paint:set(true);screen.Enabled=false;screen.changed:Fire();assert(modalOpen==false)
screen.Enabled=true;screen.changed:Fire();assert(modalOpen==true)
screen.Destroying:Fire();assert(modalOpen==false)
''',
    "guide_to_inventory": '''
Controller.start(screen);guide:set(true);assert(not GuiService.TouchControlsEnabled)
phone:set(true);guide:set(false);assert(not GuiService.TouchControlsEnabled,"Guide transition released modal lock")
phone:set(false);assert(GuiService.TouchControlsEnabled,"Guide retained touch controls")
''',

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
local jobBody = {{AbsoluteSize={{Y={height}}},CanvasSize={{Y={{Offset=666}}}}}}
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
