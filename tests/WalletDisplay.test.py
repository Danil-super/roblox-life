#!/usr/bin/env python3
"""Exercise the actual HUD subscription code with delayed/absent replication."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/Main.client.luau").read_text()
marker = 'player:GetAttributeChangedSignal("StorageMode"):Connect(render)\n'
body = source[source.index(marker) + len(marker):]

header = r'''
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, fn)
            local entry = {fn = fn, active = true}
            table.insert(callbacks, entry)
            return {Disconnect = function() entry.active = false end}
        end,
        Fire = function(_, ...)
            for _, entry in callbacks do if entry.active then entry.fn(...) end end
        end,
    }
end
local function instance(name, class)
    local object = {Name = name, Value = 0, children = {}, ChildAdded = signal(), Changed = signal()}
    function object:IsA(expected) return expected == class end
    function object:FindFirstChild(key) return self.children[key] end
    function object:WaitForChild(key)
        assert(self.children[key], "HUD yielded waiting for an optional display")
        return self.children[key]
    end
    function object:GetPropertyChangedSignal() return self.Changed end
    function object:add(child) self.children[child.Name] = child; self.ChildAdded:Fire(child) end
    return object
end
local player = instance("Player", "Player")
local stats = instance("leaderstats", "Folder")
local money = instance("Dollars", "IntValue")
money.Value = 250
local dollars = nil
local renders = 0
local function render() renders += 1 end
local task = {spawn = function(fn) fn() end}
if SCENARIO == "existing" then stats:add(money); player:add(stats) end
'''

scenarios = {
    "blocked_profile": 'assert(dollars == nil, "Failed load must not invent a balance")',
    "existing": 'assert(dollars == money and dollars.Value == 250, "Existing balance not bound")',
    "delayed_folder": '''
stats:add(money); player:add(stats)
assert(dollars == money, "Late leaderstats not observed")
local before = renders; money.Value = 70; money.Changed:Fire()
assert(dollars.Value == 70 and renders == before + 1, "Confirmed balance update lost")
''',
    "delayed_value": '''
player:add(stats); assert(dollars == nil)
stats:add(instance("Other", "IntValue")); assert(dollars == nil)
stats:add(money); assert(dollars == money, "Late Dollars not observed")
''',
    "wrong_class": '''
player:add(instance("leaderstats", "StringValue")); assert(dollars == nil)
player:add(stats); stats:add(instance("Dollars", "StringValue")); assert(dollars == nil)
stats:add(money); assert(dollars == money, "Valid display could not recover")
''',
    "replacement": '''
stats:add(money); player:add(stats)
local replacement = instance("Dollars", "IntValue"); replacement.Value = 70
stats:add(replacement); assert(dollars == replacement)
local before = renders; money.Changed:Fire(); assert(renders == before, "Old value listener leaked")
replacement.Changed:Fire(); assert(renders == before + 1)
''',
}

for name, assertions in scenarios.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header.replace("SCENARIO", '"' + name + '"') + "\ndo\n" + body + "\nend\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS WalletDisplay:", name)

# Job snapshots must not overwrite the HUD's profile loading/error message.
jobs = (ROOT / "src/client/JobController.luau").read_text()
start = jobs.index('\t\tlocal objective = screen:FindFirstChild("Objective")')
finish = jobs.index('\n\tend\n\taction.Activated', start)
objective_body = jobs[start:finish]
for profile_status in ("Error", "Loading", "Ready"):
    objective_header = r'''
local label = {Text="profile-status", IsA=function() return true end}
local detail = {Text="profile-hint", IsA=function() return true end}
local objective = {IsA=function() return true end, FindFirstChild=function(_,key)
    return if key=="Title" then label else detail
end}
local screen = {FindFirstChild=function() return objective end}
local player = {GetAttribute=function() return STATUS end}
local s, nearWall, phase = nil, false, "Offer"
local phaseKeys = {Offer="jobOffer"}
local function t(key) return key end
local function stepHint() return "offerHint" end
'''
    assertion = ('assert(label.Text=="jobOffer" and detail.Text=="offerHint")'
                 if profile_status == "Ready" else
                 'assert(label.Text=="profile-status" and detail.Text=="profile-hint", "Job replaced profile status")')
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(objective_header.replace("STATUS", '"' + profile_status + '"') + objective_body + "\n" + assertion)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS ObjectiveProfile:", profile_status)
