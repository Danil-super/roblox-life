--!strict
local Painting = require("../src/server/Domain/Painting")
local Config = require("../src/shared/PaintConfig")
local function prepared(id: string): Painting.State
	local s = Painting.new(id, id .. "-work", 100, Config)
	assert(Painting.step(s, "inspect", nil, 100, true), "Inspect failed")
	assert(Painting.step(s, "prepare", nil, 100, true), "Prepare failed")
	return s
end
local basic, wide = prepared("basic"), prepared("wide")
assert(not Painting.tool(wide, "wide", 0), "Wide roller unlocked without XP")
assert(not Painting.tool(wide, "wide", 0 / 0), "Non-finite XP accepted")
assert(not Painting.tool(wide, "missing", 50), "Unknown tool accepted")
assert(Painting.tool(wide, "wide", 50), "Earned tool was rejected")
assert(wide.toolId == "wide" and basic.toolId == "basic", "Tool selection crossed players")
assert(Painting.step(basic, "choose", Config.colorId, 100, true), "Basic material failed")
assert(Painting.step(wide, "choose", Config.colorId, 100, true), "Wide material failed")
local point = { { u = 5.5 / 12, v = 3.5 / 8 } }
assert(Painting.batch(basic, 1, point, true, 100.2, true), "Basic stroke rejected")
assert(Painting.batch(wide, 1, point, true, 100.2, true), "Wide stroke rejected")
assert(basic.count == 1 and wide.count == 5, "Wide roller did not paint a larger real area")
assert(not Painting.tool(wide, "basic", 50), "Tool changed in an active stroke session")
assert(
	not Painting.batch(wide, 1, point, true, 101, true) and wide.count == 5,
	"Duplicate stroke added coverage"
)
assert(not Painting.step(wide, "review", nil, 120, true), "Tool bypassed coverage requirement")
local corner = prepared("corner")
assert(Painting.tool(corner, "wide", 50), "Corner tool failed")
assert(
	Painting.tool(corner, "basic", 50) and corner.config.rollerRadius == Config.rollerRadius,
	"Basic tool not restored"
)
assert(Painting.tool(corner, "wide", 50), "Second wide selection failed")
assert(Painting.step(corner, "choose", Config.colorId, 100, true), "Corner material failed")
assert(Painting.batch(corner, 1, { { u = 0, v = 0 } }, true, 100.2, true), "Corner stroke rejected")
for index in corner.cells do
	assert(index >= 1 and index <= 96, "Brush escaped wall bounds")
end
assert(Config.rollerRadius == 0.65, "Tool changed global configuration")
print("PaintTools: XP, stage, real footprint, retry, bounds and independent configurations passed")
