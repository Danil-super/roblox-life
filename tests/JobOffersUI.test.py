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
local Geometry=require("../src/shared/PaintGeometry")
local Config=require("../src/shared/PaintConfig")
local Mastery=require("../src/shared/PaintingMastery")
local Theme=require("../src/shared/Theme")
local Jobs=require("../src/server/Domain/Jobs")
local Profile=require("../src/server/Domain/Profile")
local Controller={}
local now,serial=10,0
local os={clock=function()return now end}
local HttpService={GenerateGUID=function()serial+=1;return "request-"..serial end}
local previews={}
local OfferScene={start=function(parent)
 local r={parent=parent};table.insert(previews,r)
 return{render=function(offer)r.offer=offer;return offer~=nil end}
end}
local pool={}
local Instance={new=function(kind)
 local o={ClassName=kind,Visible=true,Active=true}
 table.insert(pool,o)
 function o:GetChildren()local r={};for _,v in pool do if v.Parent==self and not v.Destroyed then table.insert(r,v)end end;return r end
 function o:FindFirstChild(name)for _,v in self:GetChildren()do if v.Name==name then return v end end end
 function o:Destroy()for _,v in self:GetChildren()do v:Destroy()end;self.Destroyed=true;self.Parent=nil end
 o.Activated={Connect=function(_,fn)o.clicked=fn end}
 o.Destroying={Once=function(_,fn)o.onDestroy=fn end}
 function o:GetPropertyChangedSignal(name)return{Connect=function(_,fn)if name=="Visible"then o.visibilityChanged=fn else o.enabledChanged=fn end;return{Disconnect=function()if name=="Visible"then o.visibilityDisconnected=true else o.enabledDisconnected=true end end}end}end
 function o:FindFirstAncestorOfClass(kind)return if self.Parent and self.Parent.ClassName==kind then self.Parent else nil end
 function o:IsA(kind)return self.ClassName==kind end
 return o
end}
local function find(name)
 for i=#pool,1,-1 do if pool[i].Name==name and not pool[i].Destroyed then return pool[i]end end
 error("Missing GUI "..name)
end
local UDim2={fromScale=function()return{}end,fromOffset=function(x,y)return{X=x,Y=y}end,
 new=function(_,x,_,y)return{X=x,Y=y}end}
local Vector2={zero=0}
local Color3={fromRGB=function()return{}end,new=function(r,g,b)return{r,g,b}end}
local Enum={Font={GothamMedium=1,GothamBold=2},TextXAlignment={Left=1}}
local timers={}
local task={delay=function(_,fn)table.insert(timers,fn)end}
local requests={}
local function accept(offer,job,request)table.insert(requests,{offerId=offer,jobId=job,requestId=request})end
local profileReady=true
local function ready()return profileReady end
local lang="en"
local function language()return lang end
local screenGui=Instance.new("ScreenGui");screenGui.Enabled=true
local panel=Instance.new("Frame");panel.Parent=screenGui
local workBody=Instance.new("ScrollingFrame")
local back=Instance.new("TextButton")
local function snapshot()
 return {available=true,phase="Offer",jobId="",workId="",count=0,mask="",sequence=0,reward=250,near=false,
 offers=Jobs.offers(Profile.new(1)),paintingXP=0}
end
'''
checks = r'''
local api=Controller.start(panel,workBody,back,language,accept,ready)
assert(#previews==1,"Offer details have no bounded plan renderer")
local s=snapshot();api.render(s)
local list=find("List")
local all,available=find("AllJobs"),find("AvailableJobs")
local staleCard=find("paint-rose-v1")
assert(all.Size.Y>=44 and available.Size.Y>=44 and all.Position.Y==available.Position.Y)
assert(not all.Active and available.Active and available.Text=="Available (1)")
assert(staleCard:FindFirstChild("Scope").Text==Strings.text(lang,"offerStandard"))
local duo=find("paint-duo-v1")
assert(duo:FindFirstChild("Scope").Text==Strings.text(lang,"offerAdvanced"))
assert(duo:FindFirstChild("PaintSwatch1").BackgroundColor3[1]==Config.palette.mint[1])
assert(duo:FindFirstChild("PaintSwatch2").BackgroundColor3[1]==Config.palette.rose[1])
assert(not staleCard:FindFirstChild("PaintSwatch2"),"One wall displayed two paint samples")
list.CanvasPosition=27;available.clicked()
assert(list.CanvasPosition==0 and find("paint-tutorial-v1") and staleCard.Destroyed)
assert(#requests==0 and not find("AcceptOffer").Visible and not available.Active and all.Active)
staleCard.clicked();assert(not find("AcceptOffer").Visible,"Filtered-out card opened detail")
local first=find("paint-tutorial-v1");list.CanvasPosition=14
api.render(s);assert(list.CanvasPosition==14 and find("paint-tutorial-v1")==first,"Sync rebuilt the same filtered list")
local earned=Profile.new(1);earned.progression.paintingXP=210
s.offers,s.paintingXP=Jobs.offers(earned),earned.progression.paintingXP
api.render(s)
assert(list:FindFirstChild("paint-duo-v1") and not list:FindFirstChild("paint-atelier-v1"))
screenGui.Enabled=false;all.clicked();assert(all.Active and available.Text=="✓ Available (4)")
screenGui.Enabled=true
find("paint-duo-v1").clicked();all.clicked();assert(api.back() and all.Active)
lang="ru";api.render(s);assert(available.Text=="✓ Доступные (4)")
all.clicked();assert(list:FindFirstChild("paint-atelier-v1") and not all.Active)
s=snapshot();api.render(s)
for _,locale in {"en","ru"}do
 lang=locale;api.render(s);api.show(nil);find("paint-rose-v1").clicked()
 assert(find("PerfectTip").Visible and find("PerfectTip").Text==string.format(Strings.text(lang,"perfectTipOffer"),70),"Advanced offer lost potential tip")
 assert(find("Preparation").Text==Strings.text(lang,"offerScrapeAndProtect"))
 assert(#requests==0,"Viewing tip accepted a job")
 assert(api.back());find("paint-tutorial-v1").clicked();assert(not find("PerfectTip").Visible,"Starter advertised tip")
 assert(find("Preparation").Text==Strings.text(lang,"offerProtectFloor"))
end
lang="en";api.render(s);api.show("paint-mint-v1")
assert(not find("AcceptOffer").Visible,"Locked recommendation opened as ready")
find("paint-mint-v1").clicked();assert(previews[1].offer.id=="paint-mint-v1","Locked detail has no planned room")
screenGui.Enabled=false;assert(screenGui.enabledChanged,"Preview does not observe disabled HUD");screenGui.enabledChanged();assert(previews[1].offer==nil and #requests==0,"Disabled HUD retained preview")
screenGui.Enabled=true;screenGui.enabledChanged();assert(previews[1].offer.id=="paint-mint-v1")
find("AcceptOffer").clicked()
assert(#requests==0 and not find("AcceptOffer").Active,"Locked preview accepted")
api.show("missing");assert(not find("AcceptOffer").Visible,"Missing offer selected")
api.show("paint-tutorial-v1");assert(find("AcceptOffer").Active and #requests==0,"Preview auto-accepted")
assert(find("SurfaceSize").Text=="Painting · Quick · 1 wall\n"..string.format(Strings.text("en","paintSurfaceSizes"),"12×8"),"Job details hid real scope or shape")
local confirm=find("AcceptOffer")
panel.Visible=false;panel.visibilityChanged();assert(previews[1].offer==nil,"Closed pending details retained the plan");confirm.clicked();assert(#requests==0,"Hidden confirm sent acceptance")
panel.Visible=true;confirm.clicked();confirm.clicked()
assert(#requests==1 and api.pending() and not confirm.Active,"Rapid acceptance duplicated")
assert(back.Text==Strings.text("en","backHome"),"Pending Back advertised switching offers")
assert(requests[1].jobId=="" and requests[1].offerId=="paint-tutorial-v1")
now=17.999;timers[1]();assert(api.pending() and not confirm.Active,"Timer invented a known outcome")
now=18;timers[1]();assert(api.pending() and confirm.Active and confirm.Text==Strings.text("en","acceptRetry"))
api.back();panel.Visible=false;panel.visibilityChanged();assert(previews[1].offer==nil,"Closed pending details retained the plan");confirm.clicked();assert(api.pending() and #requests==1,"Close lost unknown request")
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
assert(previews[1].offer==nil and panel.visibilityDisconnected and screenGui.enabledDisconnected,"Destroyed offers retained the plan or visibility observer")
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + body + "\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS JobOffersUI: localized work scope, confirmed availability filter, explicit acceptance, retry and cleanup")
