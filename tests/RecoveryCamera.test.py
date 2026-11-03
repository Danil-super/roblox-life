#!/usr/bin/env python3
"""Run actual camera restoration for delayed characters and interrupted work."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/ProfileRecoveryController.luau").read_text()
start = source.index("\tlocal function restoreCamera()")
finish = source.index("\n\tlocal function t(", start)
body = source[start:finish]
header = '''
local cameraPending=true
local status,building,painting="Ready",false,false
local humanoid={Health=100}
local character={FindFirstChildOfClass=function()return humanoid end}
local player={Character=character,GetAttribute=function()return status end}
local screen={GetAttribute=function()return building end,FindFirstChild=function()return {Visible=painting,IsA=function()return true end}end}
local Enum={CameraType={Custom="Custom"}}
local camera={CameraType="Fixed"}
local workspace={CurrentCamera=camera}
'''
cases = {
    "character_after_profile": '''
player.Character=nil;restoreCamera();assert(cameraPending and camera.CameraType=="Fixed")
player.Character=character;restoreCamera()
assert(not cameraPending and camera.CameraType=="Custom" and camera.CameraSubject==humanoid)
camera.CameraType="Scriptable";restoreCamera();assert(camera.CameraType=="Scriptable","Repeated render stole working camera")
''',
    "profile_after_character": '''
status="Loading";restoreCamera();assert(cameraPending)
status="Ready";restoreCamera();assert(not cameraPending and camera.CameraType=="Custom")
''',
    "active_work_and_dead_character": '''
building=true;restoreCamera();assert(cameraPending and camera.CameraType=="Fixed")
building=false;painting=true;restoreCamera();assert(cameraPending)
painting=false;humanoid.Health=0;restoreCamera();assert(cameraPending)
humanoid.Health=100;restoreCamera();assert(not cameraPending)
''',
}
for name, assertions in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + body + "\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS RecoveryCamera:", name)
