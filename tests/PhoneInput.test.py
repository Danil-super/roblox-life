#!/usr/bin/env python3
"""Run the actual phone toggle and keyboard binding with text/mode guards."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/client/Main.client.luau').read_text()
a=source.index('local function togglePhone()');b=source.index('\ncloseButton.Activated:',a)
body=source[a:b]
header='''
local InputConfig=table.clone(require("../src/shared/InputConfig"))
local status,building,working,focused="Ready",false,false,nil
local calls=0
local player={GetAttribute=function()return status end}
local screen={GetAttribute=function()return building end}
local jobs={hide=function()calls+=1 end,isWorking=function()return working end}
local housing={hide=function()calls+=1 end}
local panel={Visible=false}
local clicked,key
local homeButton={Activated={Connect=function(_,fn)clicked=fn end}}
local UIS={GetFocusedTextBox=function()return focused end,InputBegan={Connect=function(_,fn)key=fn end}}
local function press(name,processed)key({KeyCode={Name=name}},processed or false)end
'''
checks='''
press("M");assert(panel.Visible and calls==2,"M did not open phone")
clicked();assert(not panel.Visible and calls==4,"Button did not share toggle")
press("M",true);focused={};press("M");focused=nil
working=true;press("M");working=false;building=true;press("M");building=false
status="Error";press("M");status="Loading";clicked();status="Ready"
press("E");assert(not panel.Visible and calls==4,"Typing/processed/mode/profile guard failed")
InputConfig.phoneKey="N";press("M");assert(not panel.Visible,"Old config key still active")
press("N");assert(panel.Visible and calls==6,"Configured key ignored")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+body+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS PhoneInput: shared toggle, configured key, typing, processed input, working modes and profile guards')
