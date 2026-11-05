#!/usr/bin/env python3
"""Run the actual input preflight in Luau and ensure rejected clicks never send input."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from studio_ui import click, inspect_code

HEADER = '''
local function point(x,y)return {X=x,Y=y}end
local function node(name,class,parent)
 local n={Name=name,ClassName=class,Parent=parent,Visible=true,Enabled=true,Active=true,Interactable=true,ClipsDescendants=false,AbsolutePosition=point(10,10),AbsoluteSize=point(100,100),children={}}
 if parent then parent.children[name]=n end
 function n:IsA(kind)return self.ClassName==kind or (kind=="GuiObject"and (self.ClassName=="Frame"or self.ClassName=="TextButton"or self.ClassName=="TextLabel"))or(kind=="GuiButton"and self.ClassName=="TextButton")end
 function n:FindFirstChild(k)return self.children[k]end
 function n:IsDescendantOf(ancestor)local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false end
 return n
end
local game=node("game","DataModel")
local players=node("Players","Players",game)
local player=node("LocalPlayer","Player",players);players.LocalPlayer=player
local gui=node("PlayerGui","PlayerGui",player);player.PlayerGui=gui
local hud=node("NeighborhoodHUD","ScreenGui",gui)
local panel=node("InventoryPanel","Frame",hud)
local button=node("Place","TextButton",panel)
local hits={button,panel}
function gui:GetGuiObjectsAtPosition(x,y)assert(x==60 and y==60);return hits end
game.Players=players
game.HttpService={JSONEncode=function(_,value)return value end}
local running=true
local run={IsRunning=function()return running end}
function game:GetService(name)assert(name=="RunService");return run end
'''


class StudioUI(unittest.TestCase):
    def run_guard(self, setup, assertion):
        with tempfile.NamedTemporaryFile("w", suffix=".luau", dir=ROOT / ".tools") as file:
            file.write('--!strict\n' + HEADER + setup + '\nlocal result=(function()\n' + inspect_code("InventoryPanel.Place") + '\nend)()\n' + assertion)
            file.flush()
            subprocess.run([str(ROOT / ".tools/bin/luau"), file.name], check=True)

    def test_visible_button(self):
        self.run_guard('', 'assert(result.ready and result.visible)')

    def test_hidden_ancestor_rejects_even_when_button_visible(self):
        self.run_guard('panel.Visible=false', 'assert(not result.ready and not result.visible and result.reason=="Hidden")')

    def test_disabled_screen(self):
        self.run_guard('hud.Enabled=false', 'assert(not result.ready and not result.visible)')

    def test_inactive_button(self):
        self.run_guard('button.Active=false', 'assert(result.visible and not result.ready and result.reason=="Inactive")')

    def test_noninteractive_button(self):
        self.run_guard('button.Interactable=false', 'assert(not result.ready and result.reason=="Inactive")')

    def test_overlap_rejects_another_button(self):
        self.run_guard('local other=node("Move","TextButton",panel);hits={other,button,panel}', 'assert(not result.ready and result.reason=="Covered")')

    def test_label_inside_button_is_safe(self):
        self.run_guard('local label=node("Caption","TextLabel",button);hits={label,button,panel}', 'assert(result.ready)')

    def test_clipped_center(self):
        self.run_guard('panel.ClipsDescendants=true;panel.AbsoluteSize=point(20,20)', 'assert(not result.ready and result.reason=="Clipped")')

    def test_zero_size(self):
        self.run_guard('button.AbsoluteSize=point(0,0)', 'assert(not result.ready and result.reason=="Geometry")')

    def test_missing_target(self):
        self.run_guard('panel.children.Place=nil', 'assert(not result.ready and result.reason=="Missing")')

    def test_button_not_under_pointer_is_rejected(self):
        self.run_guard('hits={}', 'assert(not result.ready and result.reason=="NotHit")')

    def test_edit_refuses_input(self):
        self.run_guard('running=false', 'assert(not result.ready and result.reason=="NotPlaying")')

    def test_bad_path(self):
        for path in ("", "../Home", "InventoryPanel..Place", 'Home\");error("x")', "a"*513):
            with self.assertRaises(ValueError):
                inspect_code(path)

    def test_preflight_blocks_input_and_does_not_retry(self):
        class Fake:
            def __init__(self, ready, visible=True):self.ready,self.visible,self.calls=ready,visible,[]
            def tool(self,name,args):
                self.calls.append(name)
                if name=="execute_luau":return json.dumps({"ready":self.ready,"visible":self.visible,"reason":"Hidden"})
                return "Success"
        client=Fake(False)
        with self.assertRaisesRegex(RuntimeError,"Hidden"):
            click(client,"one","HomePanel.Apps.Jobs")
        self.assertEqual(client.calls,["execute_luau"])
        client=Fake(True,False)
        with self.assertRaisesRegex(RuntimeError,"no retry"):
            click(client,"one","Home",expect="HomePanel")
        self.assertEqual(client.calls,["execute_luau","user_mouse_input","execute_luau"])
        client=Fake(True)
        click(client,"one","Home",expect="HomePanel")
        self.assertEqual(client.calls.count("user_mouse_input"),1)
        client=Fake(True)
        with self.assertRaises(ValueError):click(client,"one","Home",expect="../Jobs")
        self.assertEqual(client.calls,[])


if __name__ == "__main__":
    unittest.main()
