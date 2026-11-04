#!/usr/bin/env python3
"""Execute planner navigation against current confirmed ownership."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/"src/client/HomeController.luau").read_text()
start=source.index("\tplanner = RoomPlanner.start(")
finish=source.index("\n\tfor _, back in", start)
body=source[start:finish]
header='''
local navigate
local RoomPlanner={start=function(_,_,fn)navigate=fn;return {} end}
local planner,screen,language={},{},function()return "en"end
local state={available=true,items={{id="chair",catalogId="reading-chair-v1"}}}
local focus,shown,renders=nil,nil,0
local function show(tab)shown=tab end
local function render()renders+=1 end
'''
checks='''
navigate("reading-chair-v1",nil)
assert(shown=="Shop" and focus.id=="reading-chair-v1","Unowned target did not focus shop")
navigate("reading-chair-v1","chair")
assert(shown=="Furniture" and focus.id=="chair","Owned target did not focus inventory")
navigate("bookcase-v1","chair")
assert(shown=="Shop" and focus.id=="bookcase-v1","Mismatched item redirected to another product")
state.available=false;local before=renders
navigate("reading-chair-v1","chair");assert(renders==before,"Unavailable profile navigated")
state=nil;navigate("reading-chair-v1","chair");assert(renders==before,"Missing profile navigated")
'''
with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools")as script:
    script.write(header+body+checks);script.flush()
    subprocess.run([str(ROOT/".tools/bin/luau"),script.name],cwd=ROOT,check=True)
print("PASS HomePlannerUI: shop, owned inventory, mismatch and unavailable profile")
