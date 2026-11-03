#!/usr/bin/env python3
"""Run the actual Service.start body against deterministic lifecycle dependencies."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT/'src/server/ProfileService.luau')
args = parser.parse_args()
source = args.source.read_text()
assert source.startswith('--!strict'), 'Runtime source must remain strict'

header = r'''
local scenario = SCENARIO
local queue, time = {}, 0
local function schedule(fn, at) table.insert(queue, {co=coroutine.create(fn), at=at}) end
local task = {}
function task.spawn(fn, ...) local args=table.pack(...); schedule(function() fn(table.unpack(args,1,args.n)) end,time) end
function task.defer(fn, ...) task.spawn(fn, ...) end
function task.wait(seconds) return coroutine.yield(seconds or 0.01) end
function task.delay(seconds, fn) schedule(fn,time+seconds) end
local os = {clock=function() return time end,time=function() return math.floor(100+time) end}
local math = table.clone(math)
math.random=function() return 0 end
local signal = {Connect=function() end}
local attrs = {}
local Players = {PlayerAdded=signal,PlayerRemoving=signal,RespawnTime=5}
local added
local player = {UserId=1,Parent=Players,CharacterAdded={Connect=function(_,fn) added=fn end}}
function player:SetAttribute(key,value) attrs[key]=value end
function player:GetAttribute(key) return attrs[key] end
local spawnCount, homeCount = 0, 0
local humanoid
function player:LoadCharacterAsync()
    spawnCount+=1
    humanoid={Health=100}
    humanoid.IsA=function() return true end
    humanoid.Died={Once=function(_,fn)
        if scenario=="respawn" and spawnCount==1 then schedule(function() humanoid.Health=0;fn() end,26) end
    end}
    local thisHumanoid=humanoid
    self.Character={
        WaitForChild=function(_,name) return if name=="Humanoid" then thisHumanoid else nil end,
        FindFirstChild=function(_,name) return if name=="Humanoid" then thisHumanoid else nil end,
        FindFirstChildOfClass=function() return thisHumanoid end,
        IsDescendantOf=function() return true end,
    }
    added(self.Character)
end
function Players:GetPlayers() return {player} end
local remote={OnServerEvent=signal,IsA=function() return true end}
local ReplicatedStorage={WaitForChild=function() return remote end}
local HttpService={GenerateGUID=function() return "token" end}
local phase, storeBusy, attempts="Loading",false,0
local wallet={wallet={dollars=0},progression={paintingXP=0},housing={roomTemplateId="StarterDormTemplate_v1",roomTemplateVersion=1}}
local session={
    load=function() phase=if scenario=="late_load" then "Uncertain" else "Ready";return phase=="Ready" end,
    status=function() return phase end,
    retry=function() attempts+=1;if attempts>=4 then phase="Ready";return true end;return false end,
    renew=function() storeBusy=true;task.wait(10);storeBusy=false;return true end,
    read=function() return if phase=="Ready" and not storeBusy then wallet else nil end,
}
local Store={new=function() return session end}
local Profile={integer=function() return true end}
local RoomRules={SLOTS=16}
local Storage={create=function() return {} end,preview=true}
local World={
    createHome=function() homeCount+=1;return {model={Destroy=function() end},ownerId=1,spawn={}} end,
    isIntruding=function() return false end,
    returnHome=function() return true end,
}
local Instance={new=function() return {} end}
local services={Players=Players,HttpService=HttpService,ReplicatedStorage=ReplicatedStorage}
local game={BindToClose=function() end,GetService=function(_,name) assert(services[name],name);return services[name] end}
local dependencies={
 ["./Domain/ProfileStore"]=Store,["./Domain/Profile"]=Profile,["./Domain/RoomRules"]=RoomRules,
 ["./Storage"]=Storage,["./World"]=World,
}
local function require(path) assert(dependencies[path],path);return dependencies[path] end
local warn=print
'''
footer = r'''
serviceModule.start()
while #queue>0 do
    table.sort(queue,function(a,b) return a.at<b.at end)
    local item=table.remove(queue,1)
    if item.at>45 then break end
    time=item.at
    local ok,duration=coroutine.resume(item.co)
    assert(ok,tostring(duration))
    if coroutine.status(item.co)~="dead" then table.insert(queue,{co=item.co,at=time+duration}) end
end
assert(phase=="Ready" and not storeBusy,"Scenario did not finish in confirmed Ready state")
assert(attrs.ProfileStatus=="Ready","Ready state was not published")
assert(homeCount==1,"Recovered profile must create exactly one home; actual="..homeCount)
local expectedSpawns=if scenario=="late_load" then 1 else 2
assert(spawnCount==expectedSpawns,"Character must eventually spawn; expected="..expectedSpawns..", actual="..spawnCount)
print("PASS lifecycle",scenario,"homes",homeCount,"character loads",spawnCount)
'''
failed = False
for scenario in ('late_load', 'respawn'):
    script = '--!strict\n' + header.replace('SCENARIO', '"'+scenario+'"') + '\nlocal serviceModule=(function()\n' + source + '\nend)()\n' + footer
    with tempfile.NamedTemporaryFile('w', suffix='.luau') as f:
        f.write(script)
        f.flush()
        print(f'Running {scenario} using {args.source}', flush=True)
        result = subprocess.run(['luau', f.name], cwd=ROOT, timeout=30)
        failed |= result.returncode != 0
raise SystemExit(1 if failed else 0)
