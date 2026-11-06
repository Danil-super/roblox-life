#!/usr/bin/env python3
"""Run actual JobService snapshot projection; visuals only follow authoritative work."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/server/JobService.luau').read_text()
a=s.index('\tlocal function phaseOf(');b=s.index('\n\tlocal function canTalk(',a);phase=s[a:b]
a=s.index('\tlocal function send(');b=s.index('\n\ttalk = function(',a);send=s[a:b]
header=r'''
local Profile=require("../src/server/Domain/Profile")
local Jobs=require("../src/server/Domain/Jobs")
local EconomyConfig=require("../src/server/Domain/EconomyConfig")
local Painting=require("../src/server/Domain/Painting")
local Config=require("../src/shared/PaintConfig")
local FirstSteps=require("../src/shared/FirstSteps")
local Result=require("../src/server/Domain/JobResult")
local Players={};local player={Parent=Players}
local data=Profile.new(1);data.progression.paintingXP=210;assert(Jobs.accept(data,"job","paint-duo-v1"))
local p=data
local profiles={read=function()return p end}
local calls={};local ctx={saving=false,site={update=function(...)table.insert(calls,{...})end},work=Painting.new("job","work",0,Config,{primary="mint",secondary="rose"})}
local snapshots={};local stateEvent={FireClient=function(_,actor,snapshot)
 assert(actor==player and #calls==#snapshots+1,"Scene projection did not precede confirmed snapshot")
 table.insert(snapshots,snapshot)
end}
local function eligible()return false end
local function canTalk()return false end
'''
checks=r'''
send(player,ctx,nil)
assert(#calls==1 and calls[1][1]=="Inspect"and calls[1][2]=="mint"and calls[1][3]and calls[1][4],"Authoritative work did not reach scene")
local work=ctx.work
assert(Painting.step(work,"inspect",nil,1,true));send(player,ctx,nil)
assert(calls[#calls][1]=="Prepare","Inspect invented preparation")
assert(not Painting.step(work,"prepare",nil,2,false));send(player,ctx,"TooFar")
assert(calls[#calls][1]=="Prepare"and snapshots[#snapshots].error=="TooFar","Denied preparation advanced visuals")
assert(Painting.step(work,"prepare",nil,3,true));send(player,ctx,nil)
assert(calls[#calls][1]=="ChooseMaterial"and calls[#calls][2]=="mint")
assert(not Painting.step(work,"choose","rose",4,true));send(player,ctx,"Color")
assert(calls[#calls][1]=="ChooseMaterial"and calls[#calls][2]=="mint","Client color overwrote confirmed materials")
ctx.saving=true;send(player,ctx,nil);assert(not calls[#calls][3]and not snapshots[#snapshots].available,"Busy profile kept site active")
ctx.saving=false;assert(Painting.step(work,"choose","mint",5,true));send(player,ctx,nil)
assert(calls[#calls][1]=="Painting"and calls[#calls][3])
work.phase="Ready";work.count=96;for i=1,96 do work.cells[i]=true end
send(player,ctx,nil);assert(calls[#calls][1]=="SurfaceReady"and snapshots[#snapshots].phase=="SurfaceReady")
assert(Painting.nextSurface(work,"second",30));send(player,ctx,nil)
assert(calls[#calls][1]=="ChooseMaterial"and calls[#calls][2]=="rose"and calls[#calls][4],"Second wall retained first color or lost protection")
data.jobs.active.status="Completed";send(player,ctx,nil);assert(calls[#calls][1]=="Completed")
data.jobs.active.status="Abandoned";send(player,ctx,nil);assert(calls[#calls][1]=="Offer")
data.jobs.active.status="Accepted";ctx.work=nil;send(player,ctx,"Restart");assert(calls[#calls][1]=="Inspect","Death retained prepared work")
p=nil;send(player,ctx,"Unavailable");assert(not calls[#calls][3],"Missing profile retained site")
assert(data.wallet.dollars==0 and data.progression.paintingXP==210,"Visual projection changed economy")
local count=#calls;player.Parent={};send(player,ctx,nil);assert(#calls==count,"Departed actor still updated its room")
print("PASS PaintWorksiteAdapter: actual snapshot source, denied prepare/color, pending/missing, duo/next color, death/cancel/complete and no economy mutation")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(header+phase+send+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
