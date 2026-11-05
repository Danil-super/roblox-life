#!/usr/bin/env python3
"""Execute real dialogue render/activation with deterministic GUI boundaries."""
from pathlib import Path
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'src/client/ClientInteractionController.luau').read_text()
a=source.index('\tlocal function render(');b=source.index('\n\taction.Activated:',a)
render=source[a:b]
a=b+1;b=source.index('\n\tlocal shown',a);activation=source[a:b]
header='''
local Dialogue=require("../src/shared/ClientDialogue")
local Strings=require("../src/shared/Strings")
local Config=require("../src/shared/PaintConfig")
local Types={}
local state,previous,token=nil,nil,nil
local started,opens=0,0
local os={clock=function()return 1 end}
local body={CanvasPosition=0}
local Vector2={zero=0}
local UDim2={new=function()return 0 end}
local panel={Visible=false}
local heading,line,details,back={},{},{},{}
local clicked
local action={Activated={Connect=function(_,fn)clicked=fn end}}
local requests={}
local function act(a)table.insert(requests,a)end
local function open()opens+=1 end
local function hide()panel.Visible=false;token=nil end
local function t(k)return Strings.text("en",k)end
'''
checks='''
local s={available=true,canTalk=true,jobId="a",workId="1",phase="Inspect",clientKey="residentNina",requiredColorId="mint",reward=300,conversation=Dialogue.describe("residentNina","Inspect")}
render(s);assert(panel.Visible and opens==1 and details.Text:find("Mint",1,true),"Valid talk did not open with requested colour")
hide();render(s);assert(not panel.Visible and opens==1,"Language redraw reopened consumed conversation")
s=table.clone(s);s.conversation=nil;render(s);assert(not panel.Visible,"Sync reopened closed dialogue")
s=table.clone(s);s.conversation=Dialogue.describe("residentNina","Inspect");render(s)
clicked();clicked();assert(#requests==1 and requests[1]=="inspect" and not panel.Visible,"Dialogue duplicated inspection")
s=table.clone(s);render(s);assert(panel.Visible)
s=table.clone(s);s.conversation=nil;s.workId="2";render(s);assert(not panel.Visible,"Respawn retained stale dialogue")
s=table.clone(s);s.conversation=Dialogue.describe("residentNina","Inspect");render(s)
s=table.clone(s);s.conversation=nil;s.available=false;render(s);assert(not panel.Visible,"Profile failure retained dialogue")
s.available=true;s.canTalk=true;s.conversation=Dialogue.describe("residentNina","Inspect");s=table.clone(s);render(s)
s=table.clone(s);s.conversation=nil;s.canTalk=false;render(s);assert(not panel.Visible,"Departed player retained dialogue")
s=table.clone(s);s.canTalk=true;s.phase="Completed";s.conversation=Dialogue.describe("residentNina","Completed");render(s)
clicked();assert(panel.Visible and not action.Visible and #requests==1,"Thank-you dialogue could award again")
s=table.clone(s);s.phase="SurfaceReady";s.conversation=Dialogue.describe("residentMila","SurfaceReady");render(s)
assert(details.Text:find("1 / 2",1,true) and not details.Text:find("Requested colour",1,true),"Intermediate dialogue advertised old colour as next task")
clicked();clicked();assert(#requests==2 and requests[2]=="nextSurface" and not panel.Visible,"Intermediate dialogue duplicated transition or paid reward")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(header+render+'\n'+activation+checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS ClientDialogueUI: one-shot display, sync/language, action dedup, respawn, profile, distance and completed state')

jobs_source=(ROOT/'src/client/JobController.luau').read_text()
a=jobs_source.index('interaction = ClientInteraction.start(screen, language, function()')+len('interaction = ClientInteraction.start(screen, language, function()')
b=jobs_source.index('\n\tend, function',a)
opening=jobs_source[a:b]
checks='''
local inventoryVisible,building,stops=true,true,0
local guideVisible=true
local shopRouteSelected=true
local function stopTravel()shopRouteSelected=false end
local guide={hide=function()guideVisible=false end}
local jobs,results,homePanel={Visible=true},{Visible=true},{Visible=true}
local mapVisible=true
local map={hide=function()mapVisible=false end}
local painter={stop=function()stops+=1 end}
local function hideHousing()inventoryVisible=false;building=false end
local function openDialogue()
'''+opening+'''
end
openDialogue()
assert(not inventoryVisible and not building and not guideVisible,"Conversation retained housing mode")
assert(not shopRouteSelected,"Conversation retained the shop route instead of work")
assert(not jobs.Visible and not results.Visible and not homePanel.Visible and not mapVisible and stops==1,"Conversation stacked another modal or painter")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
    f.write(checks);f.flush()
    subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS ClientDialogueUI: opening releases housing, painter and other modals')
