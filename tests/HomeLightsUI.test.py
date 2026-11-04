#!/usr/bin/env python3
"""Execute real lamp labels and modal/profile/character visibility policy."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/HomeLightsController.luau").read_text()
start = source.index("\tlocal function render(): ()")
render = source[start:source.index("\n\tlocal function track(", start)]
header = '''
local Strings=require("../src/shared/Strings")
local lang="en"
local function language()return lang end
local stopped=false
local modal=false
local screen={Enabled=true,GetAttribute=function()return modal end}
local status="Ready"
local hum={Health=100}
local char={FindFirstChildOfClass=function()return hum end,IsDescendantOf=function()return true end}
local player={UserId=1,Character=char,GetAttribute=function()return status end}
local workspace={}
local on=true
local own={GetAttribute=function(_,k)return if k=="OwnerUserId"then 1 else on end}
local foreign={GetAttribute=function(_,k)return if k=="OwnerUserId"then 2 else true end}
local prompt,other={},{}
local prompts={[prompt]=own,[other]=foreign}
'''
checks = '''
render();assert(prompt.Enabled and not other.Enabled and prompt.ActionText=="Turn off")
on=false;lang="ru";render();assert(prompt.ActionText=="Зажечь" and prompt.ObjectText=="Торшер")
modal=true;render();assert(not prompt.Enabled,"Menu left native interaction active")
modal=false;status="Loading";render();assert(not prompt.Enabled)
status="Error";render();assert(not prompt.Enabled)
status="Ready";hum.Health=0;render();assert(not prompt.Enabled)
hum.Health=100;player.Character=nil;render();assert(not prompt.Enabled)
player.Character=char;screen.Enabled=false;render();assert(not prompt.Enabled)
screen.Enabled=true;render();assert(prompt.Enabled and not on,"Rendering changed lamp state")
stopped=true;prompt.Enabled=false;render();assert(not prompt.Enabled,"Destroyed HUD reactivated lamp prompt")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + render + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS HomeLightsUI: EN/RU, foreign owner, modal, profile, death/removal and disabled HUD")
