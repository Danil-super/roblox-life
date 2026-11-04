#!/usr/bin/env python3
"""Execute real completion policy and guide actions, without a Roblox renderer."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/client/FirstStepsController.luau').read_text()
a=source.index('\tlocal function observe(');b=source.index('\n\tlocal function hide',a);observe=source[a:b]
a=source.index('\tlocal function step(');b=source.index('\n\treturn {',a);step=source[a:b]
header='''
local lastStatus=nil
local pending,announced=false,false
local selected=nil
local shown=0
local panel={Visible=false}
local hints=true
local status="Ready"
local data={status="Done"}
local function progress()return data end
local hum={Health=100}
local char={FindFirstChildOfClass=function()return hum end}
local player={Character=char,GetAttribute=function()return status end}
local others={}
local screen={GetAttribute=function()return hints end,FindFirstChild=function(_,name)return others[name]end}
local function hide()panel.Visible=false;selected=nil end
local function show()shown+=1;panel.Visible=true end
'''
checks='''
observe("Done");step(false);assert(shown==0,"Completed profile auto-replayed guide on join")
lastStatus=nil;observe("Active");observe("Waiting");observe("Done")
step(true);assert(shown==0 and pending,"Build/paint mode interrupted by completion")
others.ResultsPanel={Visible=true,IsA=function()return true end};step(false);assert(shown==0,"Payment result was hidden")
others.ResultsPanel=nil;hum.Health=0;step(false);assert(shown==0,"Dead avatar got a modal")
hum.Health=100;status="Loading";data=nil;step(false);assert(shown==0,"Unconfirmed profile got completion")
status="Ready";data={status="Done"};step(false);assert(shown==1 and not pending and announced,"Confirmed completion missing")
hide();observe("Done");step(false);assert(shown==1 and not panel.Visible,"Sync repeated completion")
lastStatus=nil;announced=false;observe("Active");observe("Done");hints=false;step(false)
assert(shown==1 and not pending and announced,"Hidden hints still forced guide")
hints=true;step(false);assert(shown==1,"Re-enabling hints replayed completion")
'''
a=source.index('\tlocal function selectedStep(');b=source.index('\n\tlocal render:',a);selection=source[a:b]
a=source.index('\tprimary.Activated:Connect(');b=source.index('\n\tback.Activated:',a);callback=source[a:b]
header2='''
local Guide=require("../src/shared/FirstSteps")
local selected=nil
local data=Guide.evaluate({completed=false,paid=false,ownsFurniture=false,phase="Offer"})
local function progress()return data end
local panel={Visible=true}
local clicked
local primary={Active=true,Activated={Connect=function(_,fn)clicked=fn end}}
local targets={}
local function dismiss()panel.Visible=false end
local function navigate(t)table.insert(targets,t)end
'''
checks2='''
clicked();clicked();assert(#targets==1 and targets[1]=="Jobs","Guide duplicated/skipped first action")
panel.Visible=true;selected="buy";clicked();assert(targets[2]=="Shop" and data.completed==0,"Read-ahead changed completion")
panel.Visible=true;selected=nil;data=Guide.evaluate({completed=false,paid=true,ownsFurniture=true,phase="Completed"});clicked()
assert(targets[3]=="Furniture","Owned furniture did not lead to inventory")
panel.Visible=true;data=Guide.evaluate({completed=true,paid=true,ownsFurniture=true,phase="Completed"});clicked()
assert(targets[4]=="Room","Completed cycle did not lead to room plan")
panel.Visible=true;selected="paint";clicked();assert(targets[5]=="Current" and data.completed==7,"Replay reset guide")
panel.Visible=true;data=nil;clicked();assert(#targets==5,"Unavailable guide navigated")
'''
for name,body in [('completion',header+observe+step+checks),('actions',header2+selection+callback+checks2)]:
 with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
  f.write(body);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
 print('PASS FirstStepsUI:',name)
