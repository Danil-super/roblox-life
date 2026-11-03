#!/usr/bin/env python3
"""Actual job descriptions must follow each contract's required material in EN/RU."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/client/JobController.luau").read_text()
start = source.index("\tlocal function stepHint(")
finish = source.index("\n\tlocal function render()", start)
hint = source[start:finish]
start = source.index("\t\tdescription.Text =")
finish = source.index("\n\t\tprogress.Text =", start)
description = source[start:finish]
header = '''
local Config=require("../src/shared/PaintConfig")
local Strings=require("../src/shared/Strings")
local lang="en"
local function t(key)return Strings.text(lang,key)end
local state={requiredColorId="mint"}
local nearWall,lastError,errorUntil=true,nil,10
local os={clock=function()return 1 end}
local player={GetAttribute=function()return "DONE"end}
local phase="ChooseMaterial"
local phaseKeys={ChooseMaterial="jobColor"}
local description={Text=""}
'''
checks = '''
for _,locale in {"en","ru"}do
 lang=locale
 for _,id in {"mint","rose","warm-white"}do
  state.requiredColorId=id;lastError=nil
  local required=string.format(t("contractMaterial"),t(Config.colorKeys[id]))
  assert(stepHint(phase)==required,"Requested material hint changed")
  describe()
  assert(description.Text:find(required,1,true),"Description lost required colour")
  if id~="warm-white"then
   local wrong=t("warmWhite")
   assert(not description.Text:lower():find(wrong:lower(),1,true),"Another contract still asks for warm white")
  end
  lastError="Color"
  assert(stepHint(phase):find(required,1,true),"Wrong-colour error advertises another material")
 end
end
'''
with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as script:
    script.write(header + hint + "\nlocal function describe()\n" + description + "\nend\n" + checks)
    script.flush()
    subprocess.run([str(ROOT / ".tools/bin/luau"), script.name], cwd=ROOT, check=True)
print("PASS ContractText: real descriptions and retry hints for three colours in EN/RU")
