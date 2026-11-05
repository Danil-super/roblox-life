#!/usr/bin/env python3
"""Exercise the P0 loop with real input in one already open, fresh MemoryPreview Play."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import uuid

from studio_test import StudioRpc
from studio_ui import click

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "_G.RobloxLifeLocalQA"


def validate_start(state: dict) -> None:
    expected = {"ready": True, "preview": True, "dollars": 0, "xp": 0, "step": "INTRO", "building": False}
    if any(type(state.get(key)) is not type(value) or state[key] != value for key, value in expected.items()):
        raise RuntimeError("QA requires a fresh Ready MemoryPreview profile ($0 / 0 XP / INTRO), outside Build")


def diagnostic_batches(raw: str) -> list[dict]:
    found = []

    def walk(value, depth=0):
        if depth > 12:
            return
        if isinstance(value, dict):
            if value.get("schema") == 1 and value.get("event") == "profile_change":
                found.append(value)
            else:
                for child in value.values():
                    walk(child, depth + 1)
        elif isinstance(value, list):
            for child in value:
                walk(child, depth + 1)
        elif isinstance(value, str):
            try:
                parsed = json.loads(value)
            except ValueError:
                for line in value.splitlines():
                    start = line.find("{")
                    if start < 0:
                        continue
                    try:
                        parsed, _ = json.JSONDecoder().raw_decode(line[start:])
                    except ValueError:
                        continue
                    walk(parsed, depth + 1)
            else:
                if not isinstance(parsed, str):
                    walk(parsed, depth + 1)

    walk(raw)
    return found


def validate_events(raw: str) -> dict:
    batches = diagnostic_batches(raw)
    if not batches:
        raise RuntimeError("No confirmed diagnostic batches in actual Studio Output")
    # Output may retain older Play sessions. Only the newest context belongs to this run.
    trace = batches[-1]["trace"]
    batches = [batch for batch in batches if batch.get("trace") == trace]
    counts = Counter(change["event"] for batch in batches for change in batch["changes"])
    expected = {
        "job_accepted": 2, "job_completed": 1, "job_abandoned": 1,
        "furniture_purchased": 1, "furniture_placed": 2, "furniture_moved": 1,
        "furniture_stored": 1, "onboarding_completed": 1,
    }
    if any(counts[name] != count for name, count in expected.items()):
        raise RuntimeError("Confirmed diagnostic event counts do not match the real QA actions")
    revisions = [batch["revision"] for batch in batches]
    if len(set(revisions)) != len(revisions) or any(batch.get("entry") != "confirmed" or batch.get("omitted") != 0 or len(batch["changes"]) > 8 for batch in batches):
        raise RuntimeError("Duplicated, truncated or unconfirmed diagnostic batch")
    if sum(batch["dollarsDelta"] for batch in batches) != 70 or sum(batch["xpDelta"] for batch in batches) != 50:
        raise RuntimeError("Diagnostic totals disagree with the expected $70 / 50 XP")
    return {"batches": len(batches), "events": dict(counts), "dollarsDelta": 70, "xpDelta": 50}


class LocalQA:
    def __init__(self, client, studio_id: str):
        self.client, self.studio_id = client, studio_id
        self.steps = []
        self.observing = False
        self.token = uuid.uuid4().hex

    def lua(self, code: str, mode: str = "Client") -> str:
        return self.client.tool("execute_luau", {"studio_id": self.studio_id, "datamodel_type": mode, "code": "--!strict\n" + code})

    def value(self, expression: str):
        return json.loads(self.lua("return game.HttpService:JSONEncode(" + expression + ")"))

    def note(self, label: str) -> None:
        self.steps.append(label)
        print(label, flush=True)

    def click(self, path: str, expect: str | None = None) -> None:
        click(self.client, self.studio_id, path, expect=expect)

    def mouse(self, actions: list) -> None:
        self.client.tool("user_mouse_input", {"studio_id": self.studio_id, "datamodel_type": "Client", "actions": actions})

    def state(self) -> dict:
        return self.value('''(function()
local q=''' + PREFIX + ''';local p=game.Players.LocalPlayer;local h=p.PlayerGui.NeighborhoodHUD
return {phase=if q.job then q.job.phase else nil,xp=p:GetAttribute("PaintingXP"),dollars=p.leaderstats.Dollars.Value,
 home=q.home,guide=h.GuidePanel.Visible,inventory=h.InventoryPanel.Visible,phone=h.HomePanel.Visible,building=h:GetAttribute("Building")}
end)()''')

    def begin(self) -> None:
        studios = json.loads(self.client.tool("list_roblox_studios", {})).get("studios", [])
        if len(studios) != 1 or studios[0]["id"] != self.studio_id or studios[0]["name"] not in ("NeighborhoodFixer", "roblox-life.rbxlx"):
            raise RuntimeError("QA requires exactly one selected Roblox Life Studio")
        self.lua('assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsRunning(),"Open a fresh solo Play first");assert(not game.ServerStorage.DevelopmentSettings.StudioDataStoreTest.Value,"Cloud QA is outside this local runner")', "Server")
        self.lua('''local p=game.Players.LocalPlayer;local deadline=os.clock()+10
while (p:GetAttribute("ProfileStatus")==nil or p:GetAttribute("ProfileStatus")=="Loading")and os.clock()<deadline do task.wait(.1)end
assert(p.PlayerGui:WaitForChild("NeighborhoodHUD",5),"HUD not ready")''')
        validate_start(self.value('''(function()local p=game.Players.LocalPlayer;local h=p.PlayerGui:FindFirstChild("NeighborhoodHUD")
return {ready=p:GetAttribute("ProfileStatus")=="Ready",preview=p:GetAttribute("StorageMode")=="Preview",
 dollars=if p:FindFirstChild("leaderstats")then p.leaderstats.Dollars.Value else -1,xp=p:GetAttribute("PaintingXP"),
 step=p:GetAttribute("OnboardingStep"),building=if h then h:GetAttribute("Building")==true else true}end)()'''))
        self.observing = True
        self.lua('''local p=game.Players.LocalPlayer;local h=p.PlayerGui:WaitForChild("NeighborhoodHUD",10);assert(h)
local deadline=os.clock()+10
repeat task.wait(.1)until h.HomePanel.Apps.RoomPlan.Text~="Button"or os.clock()>deadline
assert(h.HomePanel.Apps.RoomPlan.Text~="Button","GUI not ready")
assert(''' + PREFIX + '''==nil,"An earlier QA observer is still active")
local q={connections={},mouse=false,touch=false,token=''' + json.dumps(self.token) + '''};''' + PREFIX + '''=q
table.insert(q.connections,game.ReplicatedStorage.JobState.OnClientEvent:Connect(function(s)q.job=s end))
table.insert(q.connections,game.ReplicatedStorage.HomeState.OnClientEvent:Connect(function(s)q.home=s end))
table.insert(q.connections,game.UserInputService.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 then q.mouse=true end
 if input.UserInputType==Enum.UserInputType.Touch then q.touch=true end
end))
return "Readonly observers attached"''')
        self.device("default")
        self.note("Fresh MemoryPreview profile verified; one Studio")

    def device(self, name: str) -> None:
        self.lua('local d=game:GetService("StudioDeviceSimulatorService");d:SetDeviceAsync(' + json.dumps(name) + ');' + ('d:SetOrientationAsync(Enum.ScreenOrientation.Portrait);' if name != "default" else '') + 'task.wait(.8);return "Device ready"')

    def walk(self, shop: bool = False) -> None:
        goal = PREFIX + (".home and " + PREFIX + ".home.nearShop" if shop else ".job and " + PREFIX + ".job.canTalk")
        self.lua('''local p=game.Players.LocalPlayer;local hum=p.Character.Humanoid;local root=p.Character.HumanoidRootPart;local deadline=os.clock()+28
repeat local marker=workspace:FindFirstChild("WalkingRouteMarker");if marker and marker.Transparency<1 then hum:MoveTo(marker.Position)end;task.wait(.1)
until ''' + goal + ''' or os.clock()>deadline
hum:MoveTo(root.Position);assert(''' + goal + ''',"Walking route did not arrive");return "Arrived by walking"''')

    def paint(self) -> None:
        rows = self.value('''(function()local p=game.Players.LocalPlayer;local s=''' + PREFIX + '''.job;local h=p.PlayerGui.NeighborhoodHUD
assert(s and s.phase=="Painting"and h.PaintToolbar.Visible,"Not painting")
local w=workspace.Homes[s.location][s.wallName];local inset=game.GuiService:GetGuiInset();local rows={}
for r=0,7 do local row={};for col=0,11 do
 local point=workspace.CurrentCamera:WorldToViewportPoint(w.CFrame:PointToWorldSpace(Vector3.new(((col+.5)/12-.5)*w.Size.X,(.5-(r+.5)/8)*w.Size.Y,w.Size.Z/2)))
 table.insert(row,{x=point.X-inset.X,y=point.Y-inset.Y})end;table.insert(rows,row)end;return rows end)()''')
        for index, row in enumerate(rows):
            self.lua('assert(' + PREFIX + '.job.phase=="Painting" and game.Players.LocalPlayer.PlayerGui.NeighborhoodHUD.PaintToolbar.Visible,"Painting interrupted")')
            if index % 2:
                row = list(reversed(row))
            actions = [{"action": "mouseButtonDown", "mouse_button": "left", **row[0]}, {"action": "wait", "wait_time_ms": 180}]
            for point in row[1:]:
                actions.extend([{"action": "moveTo", **point}, {"action": "wait", "wait_time_ms": 180}])
            actions.extend([{"action": "mouseButtonUp", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 160}])
            self.mouse(actions)
            self.note(f"Real painting input: row {index + 1}/8")
        self.lua('assert(' + PREFIX + '.job.count>=77 and ' + PREFIX + '.mouse,"Server coverage or actual mouse input missing")')

    def place(self, item: str, x: int, z: int) -> None:
        state = self.state()
        if not state["inventory"]:
            if not state["phone"]:
                self.click("Home", "HomePanel")
            self.click("HomePanel.Apps.Furniture", "InventoryPanel")
        self.lua('local b=game.Players.LocalPlayer.PlayerGui.NeighborhoodHUD.InventoryPanel.Body;b.CanvasPosition=Vector2.zero')
        self.click("InventoryPanel.Body." + item + ".Place", "BuildToolbar")
        point = self.value('''(function()task.wait(.4);local origin=Vector3.new(table.unpack(''' + PREFIX + '''.home.origin))
local p=workspace.CurrentCamera:WorldToViewportPoint(origin+Vector3.new(''' + str(x) + ',0,' + str(z) + '''));local inset=game.GuiService:GetGuiInset()
return{x=p.X-inset.X,y=p.Y-inset.Y}end)()''')
        self.mouse([{"action": "mouseButtonDown", "mouse_button": "left", **point}, {"action": "wait", "wait_time_ms": 300},
                    {"action": "mouseButtonUp", "mouse_button": "left"}, {"action": "wait", "wait_time_ms": 500}])
        self.click("BuildToolbar.Confirm")
        state = self.state()
        owned = next(owned for owned in state["home"]["items"] if owned["id"] == item)
        if owned.get("placed") != {"x": x, "z": z, "rotationY": 0} or state["building"] or state["dollars"] != 70:
            raise RuntimeError("Placement did not confirm its pose, close the editor and preserve $70")
        self.lua('local h=game.Players.LocalPlayer.PlayerGui.NeighborhoodHUD;assert(not workspace:FindFirstChild("FurnitureGhost"));assert(#workspace.Homes[' + PREFIX + '.home.homeName].Furniture:GetChildren()==1,"Expected one real plant")')
        if state["guide"]:
            self.click("GuidePanel.Close")

    def exercise(self) -> dict:
        self.click("Home", "HomePanel")
        self.click("HomePanel.Apps.Jobs", "JobsPanel")
        self.click("JobsPanel.Offers.List.paint-tutorial-v1", "JobsPanel.AcceptOffer")
        self.click("JobsPanel.AcceptOffer")
        if self.state()["phase"] != "Inspect":
            raise RuntimeError("Tutorial acceptance was not confirmed")
        self.walk()
        self.click("Objective.NextAction", "ClientPanel")
        self.click("ClientPanel.Action")
        self.click("Objective.NextAction")
        self.click("Objective.NextAction", "JobsPanel")
        self.click("JobsPanel.Body.Colors.WarmWhite", "PaintToolbar")
        self.paint()
        self.click("PaintToolbar.Review")
        self.walk()
        self.click("Objective.NextAction", "ClientPanel")
        self.click("ClientPanel.Action", "ResultsPanel")
        state = self.state()
        if (state["phase"], state["dollars"], state["xp"]) != ("Completed", 250, 50):
            raise RuntimeError("Actual tutorial reward was not $250 / 50 XP")
        self.note("Tutorial completed by real painting input: $250 / 50 XP")
        self.click("ResultsPanel.Continue", "ShopPanel")
        self.click("ShopPanel.Route")
        self.walk(shop=True)
        self.click("Objective.NextAction", "ShopPanel")
        self.device("iphone_7")
        self.click("ShopPanel.Body.floor-plant-v1.Buy")
        home = self.state()["home"]
        if home["dollars"] != 70 or len(home["items"]) != 1 or home["items"][0]["catalogId"] != "floor-plant-v1":
            raise RuntimeError("Touch purchase did not confirm exactly one owned plant and $70")
        item = home["items"][0]["id"]
        self.note("Touch purchase confirmed: one plant, $70")
        self.click("ShopPanel.Back", "InventoryPanel")
        self.click("InventoryPanel.ReturnHome")
        self.lua('task.wait(.8);assert(' + PREFIX + '.home.nearHome,"Return Home did not arrive")')
        self.place(item, 8, 6)
        self.lua('assert(game.Players.LocalPlayer:GetAttribute("OnboardingStep")=="DONE" and ' + PREFIX + '.touch,"DONE or actual simulated Touch input missing")')
        self.note("Touch installation confirmed; onboarding DONE; editor closed")
        self.device("default")
        self.place(item, 9, 6)
        self.click("InventoryPanel.Body." + item + ".Store")
        state = self.state()
        if state["home"]["items"][0].get("placed") is not None or state["dollars"] != 70:
            raise RuntimeError("Store was not confirmed without payment")
        self.place(item, 8, 6)
        self.note("Move / store / reinstall confirmed; one model, $70, no extra editor")
        self.click("InventoryPanel.Back", "HomePanel")
        self.click("HomePanel.Apps.Jobs", "JobsPanel")
        self.click("JobsPanel.Offers.List.paint-mint-v1", "JobsPanel.AcceptOffer")
        self.click("JobsPanel.AcceptOffer")
        self.click("Home", "HomePanel")
        self.click("HomePanel.Apps.Jobs", "JobsPanel")
        self.click("JobsPanel.Body.Cancel", "AbandonPanel")
        self.click("AbandonPanel.Confirm")
        state = self.state()
        if (state["phase"], state["dollars"], state["xp"], state["building"]) != ("Offer", 70, 50, False):
            raise RuntimeError("Mint cancellation did not preserve confirmed progress")
        self.note("Mint accepted and explicitly abandoned without another reward")
        evidence = validate_events(self.client.tool("get_console_output", {"studio_id": self.studio_id}))
        self.note("Actual Output confirms every transaction once")
        return {"schema": 1, "status": "passed", "steps": self.steps, "dollars": 70, "xp": 50, "placed": 1,
                "diagnostics": evidence, "limits": ["MemoryPreview", "one solo Play", "emulated touch"]}

    def cleanup(self) -> None:
        if self.observing:
            owned = self.lua('local q=' + PREFIX + ';if not q or q.token~=' + json.dumps(self.token) + ' then return "absent"end;for _,c in q.connections do c:Disconnect()end;' + PREFIX + '=nil;return "owned"')
            if owned == "owned":
                self.device("default")
            self.observing = False


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--studio-id", required=True)
    args = parser.parse_args()
    client, qa = None, None
    folder = ROOT / ".tools/local-qa"
    folder.mkdir(parents=True, exist_ok=True)
    report = {"schema": 1, "status": "failed", "steps": [], "startedAt": datetime.now(timezone.utc).isoformat()}
    try:
        client = StudioRpc()
        qa = LocalQA(client, args.studio_id)
        report["steps"] = qa.steps
        qa.begin()
        report.update(qa.exercise())
    except Exception as error:
        report["failure"] = type(error).__name__
        raise
    finally:
        try:
            if qa:
                qa.cleanup()
        except Exception:
            report["status"] = "failed"
            report["cleanup"] = "unconfirmed"
            raise
        finally:
            (folder / "latest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            if client:
                client.close()
    print("PASS local P0; report:", folder / "latest.json")


if __name__ == "__main__":
    main()
