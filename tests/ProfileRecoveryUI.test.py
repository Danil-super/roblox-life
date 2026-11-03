#!/usr/bin/env python3
"""Execute actual recovery render/callbacks without mocking the game economy."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/ProfileRecoveryController.luau").read_text()
start = source.index("\tlocal function render()")
finish = source.index('\n\tplayer:GetAttributeChangedSignal("ProfileStatus")', start)
body = source[start:finish]
header = '''
local attrs={ProfileStatus="Error",ProfileErrorCode="Locked",ProfileRecoveryAllowed=true,ProfileCanRetry=true}
local player={GetAttribute=function(_,k)return attrs[k]end}
local seenError,awaiting,exiting,epoch=false,false,false,0
local cameraPending=false
local function restoreCamera()end
local panel,screen={Visible=false},{Parent={}}
local heading,message={},{ }
local lang={}
local function language()return "en"end
local onRetry,onExit
local retry={Activated={Connect=function(_,fn)onRetry=fn end}}
local exit={Activated={Connect=function(_,fn)onExit=fn end}}
local suspended=0
local function suspend()suspended+=1 end
local function t(key)return key end
local requests,delayed={},{}
local command={FireServer=function(_,action)table.insert(requests,action)end}
local task={delay=function(_,fn)table.insert(delayed,fn)end}
'''
cases = {
    "blocked_loading_recovered": '''
render();assert(panel.Visible and retry.Active and suspended==1)
assert(message.Text=="profileReasonLocked")
attrs.ProfileStatus="Loading";render();assert(panel.Visible and not retry.Active and suspended==1)
attrs.ProfileStatus="Ready";render();assert(not panel.Visible and not seenError)
''',
    "terminal_and_invalid_reason": '''
attrs.ProfileErrorCode="SessionLost";attrs.ProfileRecoveryAllowed=false;render()
assert(panel.Visible and not retry.Active and message.Text=="profileReasonSessionLost")
attrs.ProfileErrorCode={};render();assert(message.Text=="profileReasonUnavailable")
''',
    "rapid_retry_timeout_and_exit": '''
render();onRetry();onRetry();assert(#requests==1 and requests[1]=="retry")
assert(not retry.Active and heading.Text=="profileRecoveringTitle")
delayed[1]();assert(retry.Active,"Dropped request left UI stuck")
onRetry();assert(#requests==2)
onExit();onExit();assert(#requests==3 and requests[3]=="exit")
''',
}
for name, assertions in cases.items():
    with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
        script.write(header + body + "\n" + assertions)
        script.flush()
        subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
    print("PASS ProfileRecoveryUI:", name)
