#!/usr/bin/env python3
"""Exercise the complete offer controller with GUI boundaries and a controlled clock."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobOffersController.luau").read_text()
body = source[source.index("function Controller.start("):source.rindex("\nreturn Controller")]
header = r'''
local Flow=require("../src/shared/JobAcceptFlow")
local Strings=require("../src/shared/Strings")
local Config=require("../src/shared/PaintConfig")
local Mastery=require("../src/shared/PaintingMastery")
local Theme=require("../src/shared/Theme")
local Jobs=require("../src/server/Domain/Jobs")
local Profile=require("../src/server/Domain/Profile")
local Controller={}
local now,serial=10,0
local os={clock=function()return now end}
local HttpService={GenerateGUID=function()serial+=1;return "request-"..serial end}
local pool={}
local Instance={new=function(kind)
 local o={ClassName=kind,Visible=true,Active=true}
 table.insert(pool,o)
 function o:GetChildren()local r={};for _,v in pool do if v.Parent==self and not v.Destroyed then table.insert(r,v)end end;return r end
 function o:FindFirstChild(name)for _,v in self:GetChildren()do if v.Name==name then return v end end end
 function o:Destroy()for _,v in self:GetChildren()do v:Destroy()end;self.Destroyed=true;self.Parent=nil end
 o.Activated={Connect=function(_,fn)o.clicked=fn end}
 o.Destroying={Once=function(_,fn)o.onDestroy=fn end}
 return o
end}
local function find(name)
 for i=#pool,1,-1 do if pool[i].Name==name and not pool[i].Destroyed then return pool[i]end end
 error("Missing GUI "..name)
end
local UDim2={fromScale=function()return{}end,fromOffset=function()return{}end,new=function()return{}end}
local Vector2={zero=0}
local Color3={fromRGB=function()return{}end}
local Enum={Font={GothamMedium=1,GothamBold=2}}
local timers={}
local task={delay=function(_,fn)table.insert(timers,fn)end}
local requests={}
local function accept(offer,job,request)table.insert(requests,{offerId=offer,jobId=job,requestId=request})end
local profileReady=true
local function ready()return profileReady end
local function language()return "en"end
local panel=Instance.new("Frame");panel.Parent={}
local workBody=Instance.new("ScrollingFrame")
local back=Instance.new("TextButton")
local function snapshot()
 return {available=true,phase="Offer",jobId="",workId="",count=0,mask="",sequence=0,reward=250,near=false,
 offers=Jobs.offers(Profile.new(1)),paintingXP=0}
end
'''
checks = r'''
local api=Controller.start(panel,workBody,back,language,accept,ready)
local s=snapshot();api.render(s);api.show("paint-mint-v1")
assert(not find("AcceptOffer").Visible,"Locked recommendation opened as ready")
find("paint-mint-v1").clicked();find("AcceptOffer").clicked()
assert(#requests==0 and not find("AcceptOffer").Active,"Locked preview accepted")
api.show("missing");assert(not find("AcceptOffer").Visible,"Missing offer selected")
api.show("paint-tutorial-v1");assert(find("AcceptOffer").Active and #requests==0,"Preview auto-accepted")
local confirm=find("AcceptOffer")
panel.Visible=false;confirm.clicked();assert(#requests==0,"Hidden confirm sent acceptance")
panel.Visible=true;confirm.clicked();confirm.clicked()
assert(#requests==1 and api.pending() and not confirm.Active,"Rapid acceptance duplicated")
assert(back.Text==Strings.text("en","backHome"),"Pending Back advertised switching offers")
assert(requests[1].jobId=="" and requests[1].offerId=="paint-tutorial-v1")
now=17.999;timers[1]();assert(api.pending() and not confirm.Active,"Timer invented a known outcome")
now=18;timers[1]();assert(api.pending() and confirm.Active and confirm.Text==Strings.text("en","acceptRetry"))
api.back();panel.Visible=false;confirm.clicked();assert(api.pending() and #requests==1,"Close lost unknown request")
panel.Visible=true;api.show("paint-mint-v1")
assert(find("Details"):FindFirstChild("Title").Text==Strings.text("en","contractTutorial"),"Reopen changed pending offer")
find("paint-mint-v1").clicked();assert(find("Details"):FindFirstChild("Title").Text==Strings.text("en","contractTutorial"),"Hidden card replaced pending target")
confirm.clicked();assert(#requests==2 and requests[2].requestId==requests[1].requestId and requests[2].jobId==requests[1].jobId,"Retry changed intent")
s.error="Unavailable";s.available=false;api.render(s)
assert(api.pending() and not confirm.Active,"Unknown/busy outcome released request")
s.available=true;now=26;profileReady=false;api.render(s);confirm.clicked();assert(#requests==2,"Lost profile retried")
profileReady=true;api.render(s);confirm.clicked();assert(#requests==3 and requests[3].requestId==requests[1].requestId)
s.acceptAck={jobId="",offerId="paint-tutorial-v1",requestId="other",error="UnknownOffer"};api.render(s)
assert(api.pending(),"Uncorrelated ack released pending request")
s.acceptAck.requestId=requests[1].requestId;api.render(s);assert(not api.pending(),"Correlated refusal ignored")
confirm.clicked();local nextId=requests[#requests].requestId
assert(nextId~=requests[1].requestId and api.pending(),"New acceptance reused rejected attempt ID")
api.render(s);assert(api.pending(),"Old ack released new attempt with same baseline/offer")
s.jobId,s.contractId,s.phase,s.acceptAck="confirmed-job","paint-tutorial-v1","Inspect",nil
api.render(s);assert(not api.pending() and not confirm.Visible,"Confirmed acceptance kept pending dialog")
local before=#requests;confirm.clicked();assert(#requests==before,"Hidden old confirm started another job")
s=snapshot();s.phase,s.jobId="Completed","previous-job";api.render(s);api.show("paint-tutorial-v1")
assert(confirm.Active and #requests==before,"Next completed-job preview auto-accepted")
confirm.clicked();assert(api.pending() and requests[#requests].jobId=="previous-job")
local count=#requests;panel.onDestroy();timers[#timers]();api.show();api.render(s);confirm.clicked()
assert(not api.pending() and #requests==count,"Destroyed panel revived acceptance")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS JobOffersUI: explicit accept, fixed retry, pending close/reopen, unknown/correlated replies, stale callbacks and cleanup")
