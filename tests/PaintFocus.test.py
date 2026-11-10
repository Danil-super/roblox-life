#!/usr/bin/env python3
"""Run real paint input handlers: focus loss and other pointers cannot own a stroke."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/PaintController.luau").read_text()
start = source.index("\tlocal beganConnection =")
handlers = source[start:source.index("\n\tRunService:BindToRenderStep(", start)]
start = source.index("\treview.Activated:Connect(")
review = source[start:source.index("\n\tleave.Activated:", start)]
header = '''
local callbacks={}
local function signal(name)return{Connect=function(_,fn)callbacks[name]=fn;return{Disconnect=function()end}end}end
local UIS={InputBegan=signal("begin"),InputChanged=signal("changed"),InputEnded=signal("ended"),WindowFocusReleased=signal("focus")}
local Enum={KeyCode={Escape="Escape"},UserInputType={MouseButton1="Mouse",Touch="Touch"}}
local Vector2={new=function(x,y)return{X=x,Y=y}end}
local active,held,touch=true,false,nil
local cameraReady=true
local disposed=false
local pointer=Vector2.new(0,0)
local queue,current={},nil
local sequence,inflight,inspectPending=7,7,false
local lastHit=10
local sound={Playing=true}
local flushed=0
local function flush()flushed+=1 end
local function stop()active=false end
local review={Activated=signal("review")}
local function input(kind,x,y)return{UserInputType=kind,KeyCode="Unknown",Position={X=x or 10,Y=y or 20}}end
local mouse=input("Mouse")
local finger,other=input("Touch"),input("Touch",40,50)
'''
cases = {
    "camera_transition_requires_a_new_gesture": '''
cameraReady=false
callbacks.begin(mouse,false);callbacks.begin(finger,false);callbacks.review()
assert(not held and touch==nil and #queue==0 and not inspectPending and flushed==0,"Moving camera admitted input or Review")
callbacks.ended(mouse);callbacks.ended(finger)
cameraReady=true;assert(not held and #queue==0,"Early press turned into a late stroke")
callbacks.begin(finger,false);assert(held and touch==finger and #queue==1)
callbacks.ended(finger);assert(not held and flushed==1)
cameraReady=false;local escape=input("Mouse");escape.KeyCode="Escape";callbacks.begin(escape,true)
assert(not active,"Camera transition blocked Escape")
''',
    "focus_releases_mouse_without_losing_recorded_packet": '''
callbacks.begin(mouse,false);assert(held and #queue==1)
local old=current;table.insert(old.points,{u=.2,v=.3})
assert(callbacks.focus,"Paint has no focus-loss handler")
callbacks.focus();callbacks.focus()
assert(not held and touch==nil and current==nil and not sound.Playing and lastHit==0,"Lost focus kept painting/contact")
assert(queue[1]==old and #old.points==1 and sequence==7 and inflight==7 and flushed==0,"Focus loss rewrote the recorded packet")
callbacks.ended(mouse);assert(flushed==0,"Late mouse-up flushed a released gesture")
callbacks.begin(mouse,false);assert(held and #queue==2 and current~=old and current.starts,"New stroke bridged the old segment")
callbacks.ended(mouse);assert(flushed==1 and not held)
''',
    "touch_owns_its_gesture_until_focus_loss": '''
callbacks.begin(finger,false);local old=current
callbacks.begin(other,false);callbacks.begin(mouse,false)
callbacks.changed(other);callbacks.ended(other);callbacks.ended(mouse)
assert(held and touch==finger and current==old and #queue==1 and flushed==0,"Other pointer stole or ended Touch")
finger.Position={X=11,Y=12};callbacks.changed(finger);assert(pointer.X==11 and pointer.Y==12)
callbacks.focus();callbacks.changed(finger);callbacks.ended(finger)
assert(not held and touch==nil and current==nil and flushed==0,"Late Touch resumed/flushed after focus loss")
callbacks.begin(other,false);assert(held and touch==other and current.starts and #queue==2)
''',
    "touch_cannot_steal_a_mouse_stroke": '''
callbacks.begin(mouse,false);local old=current
callbacks.begin(finger,false);callbacks.ended(finger)
assert(held and touch==nil and current==old and #queue==1 and flushed==0,"Touch stole Mouse")
callbacks.ended(mouse);callbacks.ended(mouse)
assert(not held and current==nil and flushed==1,"Duplicate release repeated work")
''',
    "review_releases_touch_and_preserves_pending_review_on_focus_loss": '''
callbacks.begin(finger,false);local old=current
callbacks.review();assert(not held and touch==nil and current==nil and inspectPending and flushed==1,"Review kept Touch ownership")
callbacks.begin(other,false);callbacks.focus();callbacks.ended(finger)
assert(not held and touch==nil and #queue==1 and queue[1]==old and inspectPending and flushed==1 and sequence==7 and inflight==7,"Focus/release changed pending review")
inspectPending=false;callbacks.begin(other,false);assert(held and #queue==2 and current.starts)
''',
    "processed_inactive_and_full_queue_send_no_work": '''
callbacks.begin(mouse,true);active=false;callbacks.begin(finger,false)
assert(not held and #queue==0)
active=true;queue={1,2,3,4};callbacks.begin(mouse,false)
assert(not held and #queue==4 and flushed==0)
''',
}
for name, checks in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + handlers + review + checks)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS PaintFocus:", name)

start = source.index("\tlocal function flush(): ()")
flush = source[start:source.index("\n\tlocal function render()", start)]
start = source.index("\t\tupdate = function(")
update = source[start:source.index("\n\t\tend,", start) + len("\n\t\tend")].replace("\t\tupdate =", "local update =", 1)
fixture = header.replace("local function flush()flushed+=1 end", "") + """
local reviewSent=false
local Config={maxPoints=12,wallId="a"}
local snapshot={workId="work",phase="Painting"}
local sentAt=0
local missing=false
local sent=0
local function send(action,_)assert(action=="review");sent+=1 end
local function render()end
""" + flush + handlers + review + update + """
inflight=nil
callbacks.review();assert(sent==1 and inspectPending,"Sending review released input before the answer")
callbacks.begin(finger,false);assert(not held and #queue==0)
for _=1,4 do flush()end
assert(sent==1,"A queued review repeated before its answer")
update({phase="Painting",workId="work",sequence=7})
callbacks.focus();callbacks.begin(mouse,false)
assert(inspectPending and not held and sent==1,"Unrelated sync/focus released a pending review")
update({phase="Painting",workId="work",sequence=7,error="Coverage"})
assert(not inspectPending and not reviewSent,"Review refusal did not release input")
callbacks.begin(mouse,false);assert(held and #queue==1 and current.starts)
callbacks.ended(mouse);queue={};inflight=nil
callbacks.review();assert(sent==2 and inspectPending)
update({phase="Ready",workId="work",sequence=7})
assert(not active and not inspectPending and not reviewSent,"Accepted review retained input")
"""
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(fixture)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS PaintFocus: dispatched review blocks gestures through sync/focus until refusal or acceptance")
