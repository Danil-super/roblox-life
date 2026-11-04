#!/usr/bin/env python3
"""ReturnHome releases only the current character's native seat weld before moving."""
from pathlib import Path
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/World.luau").read_text()
body = source[source.index("function World.returnHome"):source.index("function World.isIntruding")]
header = '''
local World={}
local removed,moved,held,restored=0,0,0,0
local deferred={}
local task={delay=function(_,fn)table.insert(deferred,fn)end}
local Vector3={new=function()return 0 end}
local workspace={}
local seat
local character
local limb={IsDescendantOf=function(_,target)return target==character end}
local weld={Part1=limb,IsA=function(_,kind)return kind=="Weld"end,Destroy=function()removed+=1 end}
local humanoid={Health=100,Sit=true}
local root={IsA=function(_,kind)return kind=="BasePart"end,CanSetNetworkOwnership=function()return true end,
SetNetworkOwner=function(_,owner)assert(owner==nil);held+=1 end,SetNetworkOwnershipAuto=function()restored+=1 end,
IsDescendantOf=function(_,target)return target==character end}
character={FindFirstChild=function()return root end,IsDescendantOf=function()return true end,FindFirstChildOfClass=function()return humanoid end,
PivotTo=function()assert(not seat or (removed==1 and held==1),"Teleport happened without released server authority");moved+=1 end}
local player={Character=character}
local home={spawn={CFrame=0}}
'''
checks = '''
assert(World.returnHome(player,home) and moved==1 and removed==0,"Standing return failed")
seat={FindFirstChild=function()return weld end};humanoid.SeatPart=seat
assert(World.returnHome(player,home) and removed==1 and moved==2 and not humanoid.Sit,"Seated return failed")
assert(held==1 and restored==0 and #deferred==1,"Release authority was not held")
deferred[1]();assert(restored==1,"Automatic authority was not restored")
seat=nil;humanoid.SeatPart=nil;humanoid.Health=0
assert(not World.returnHome(player,home) and moved==2,"Dead character was moved")
humanoid.Health=100;weld.Part1={IsDescendantOf=function()return false end}
humanoid.SeatPart={FindFirstChild=function()return weld end}
assert(World.returnHome(player,home) and removed==1,"Foreign weld was destroyed")
root.CanSetNetworkOwnership=function()return false end
assert(not World.returnHome(player,home),"Anchored assembly moved")
root.CanSetNetworkOwnership=function()return true end
character.IsDescendantOf=function()return false end;deferred[2]();assert(restored==1,"Removed character reclaimed authority")
player.Character=nil;assert(not World.returnHome(player,home),"Absent character moved")
'''
with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools") as script:
    script.write(header+body+checks);script.flush()
    subprocess.run([str(ROOT/".tools/bin/luau"),script.name],cwd=ROOT,check=True)
print("PASS SeatReturn: standing, seated order, dead, foreign weld and absent character")
