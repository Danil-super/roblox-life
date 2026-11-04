#!/usr/bin/env python3
"""Run the actual affordable first-purchase suggestion; it never buys anything."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
s=(ROOT/'src/client/HomeController.luau').read_text();a=s.index('\tlocal function firstProduct(');b=s.index('\n\tlocal function t(',a)
body=s[a:b]
checks='''
local products={{id="bookcase-v1",dollars=280},{id="cheap",dollars=120},{id="floor-plant-v1",dollars=180}}
assert(firstProduct({catalog=products,dollars=250})=="floor-plant-v1","Affordable first plant not focused")
assert(firstProduct({catalog=products,dollars=150})=="cheap","Cheaper affordable fallback missing")
assert(firstProduct({catalog=products,dollars=100})==nil,"Unaffordable product recommended")
assert(firstProduct({catalog={{id="b",dollars=99},{id="a",dollars=99}},dollars=100})=="a","Tie not deterministic")
assert(products[1].id=="bookcase-v1" and products[3].dollars==180,"Suggestion changed catalog")
'''
with tempfile.NamedTemporaryFile('w',suffix='.luau',dir=ROOT/'.tools')as f:
 f.write(body+checks);f.flush();subprocess.run([str(ROOT/'.tools/bin/luau'),f.name],cwd=ROOT,check=True)
print('PASS FirstPurchase: preference, affordable fallback, insufficient funds, tie and no mutation')
