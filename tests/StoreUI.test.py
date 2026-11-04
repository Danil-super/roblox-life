"""Execute actual inventory action callbacks with an uncertain server result."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/HomeController.luau").read_text()
a = source.index("\tlocal function storeItem(")
b = source.index("\n\tlocal function render()", a)
body = source[a:b]
header = '''
local StoreFlow=require("../src/shared/StoreFlow")
local state={available=true,nearHome=true,editorId="editor",revision=1}
local storing,purchase=nil,nil
local focus,listKey=nil,"old"
local now,generated=0,0
local os={clock=function()return now end}
local Http={GenerateGUID=function()generated+=1;return "id-"..generated end}
local sent={}
local function send(action,packet)assert(action=="store");table.insert(sent,packet)end
local item={id="plant",placed={x=5,z=3,rotationY=0}}
'''
cases={
    "rapid_clicks_keep_one_intent": '''
storeItem(item);storeItem(item);storeItem(item)
assert(#sent==1 and generated==1 and storing.requestId=="store:id-1","Busy store sent a new operation")
assert(focus.id=="plant" and listKey=="","Pending item was not kept in focus")
''',
    "retry_uses_original_item_and_revision": '''
storeItem(item);now=8;state.revision=99
storeItem({id="lamp",placed={}});assert(#sent==1,"Another item replaced pending operation")
storeItem(item);storeItem(item)
assert(#sent==2 and generated==1 and sent[1].requestId==sent[2].requestId,"Retry changed operation ID")
assert(sent[2].revision==1 and sent[2].itemId=="plant","Retry changed stored intent")
''',
    "context_and_purchase_guards": '''
state.nearHome=false;storeItem(item);assert(#sent==0)
state.nearHome=true;state.available=false;storeItem(item);assert(#sent==0)
state.available=true;purchase={};storeItem(item);assert(#sent==0)
purchase=nil;storeItem({id="stored"});assert(#sent==0,"Stored item started another store operation")
''',
}
for name,checks in cases.items():
    with tempfile.NamedTemporaryFile("w",suffix=".luau",dir=ROOT/".tools")as f:
        f.write(header+body+checks);f.flush()
        subprocess.run([str(ROOT/".tools/bin/luau"),f.name],cwd=ROOT,check=True)
    print("PASS StoreUI:",name)
