#!/usr/bin/env python3
"""Run the real purchase callback: duplicate clicks and timeout retain one intent."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/HomeController.luau").read_text()
start = source.index("\tlocal function buy(")
finish = source.index("\n\tlocal function render()", start)
body = source[start:finish]
header = '''
local PurchaseFlow = require("../src/shared/PurchaseFlow")
local now, generated = 0, 0
local os = {clock = function() return now end}
local Http = {GenerateGUID = function() generated += 1;return "request-"..generated end}
local function t(key) return key end
local state = {available=true, nearShop=true}
local purchase, storing = nil, nil
local lastError, errorUntil, listKey = nil, 0, ""
local sent = {}
local function send(action, packet)
    assert(action == "buy")
    table.insert(sent, packet)
end
local product = {id="floor-plant-v1",dollars=180}
'''
cases = {
    "pending_store_blocks_purchase": '''storing={requestId="store-one"};buy(product);assert(#sent==0,"Store allowed concurrent purchase")''',

    "rapid_clicks": '''
buy(product);buy(product);buy(product)
assert(#sent==1,"Busy purchase sent another request")
assert(generated==1,"Busy purchase generated another payment ID")
''',
    "timeout_same_intent": '''
buy(product);now=20;buy({id="floor-lamp-v1",dollars=220})
assert(#sent==1,"Unknown result allowed a different purchase")
buy(product)
assert(#sent==2 and sent[1].requestId==sent[2].requestId,"Retry created another payment")
buy(product);assert(#sent==2,"Retry did not enter busy state")
''',
    "away_or_unavailable": '''
state.nearShop=false;buy(product);assert(#sent==0)
state.nearShop=true;state.available=false;buy(product);assert(#sent==0)
''',
}
for name, assertions in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + body + "\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS PurchaseUI:", name)
