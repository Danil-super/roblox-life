--!strict
local Geometry = require("../src/shared/PaintGeometry")
local Painting = require("../src/server/Domain/Painting")
local Config = require("../src/shared/PaintConfig")
local expected: { [string]: { { number } } } = {
	["paint-tutorial-v1"] = { { 12, 8 } },
	["paint-room-v1"] = { { 12, 8 } },
	["paint-mint-v1"] = { { 8, 8 } },
	["paint-rose-v1"] = { { 8, 9 } },
	["paint-duo-v1"] = { { 16, 8 }, { 8, 8 } },
	["paint-sunroom-v1"] = { { 16, 6 }, { 10, 8 } },
	["paint-atelier-v1"] = { { 8, 9 }, { 16, 6 } },
}
for id, sizes in expected do
	local layout = assert(Geometry.layout(id), "Known layout missing")
	assert(#layout == #sizes, "Surface count changed")
	for i, size in sizes do
		assert(layout[i].width == size[1] and layout[i].height == size[2], "Wrong shape: " .. id)
	end
	assert(table.isfrozen(layout) and table.isfrozen(layout[1]), "Shared geometry mutable")
end
assert(
	Geometry.layout(nil) == nil and Geometry.layout("unknown") == nil,
	"Unknown result invented dimensions"
)
local compact = Painting.new(
	"j",
	"w",
	0,
	Config,
	{ primary = "mint" },
	{ { width = 8, height = 8 } }
)
assert(Painting.step(compact, "inspect", nil, 1, true), "Inspect failed")
assert(Painting.step(compact, "prepare", nil, 2, true), "Prepare failed")
assert(Painting.step(compact, "choose", "mint", 3, true), "Material failed")
assert(Painting.batch(compact, 1, { { u = 0.5, v = 0.5 } }, true, 4, true), "Compact stroke failed")
assert(compact.count == 4, "Physical compact brush did not reach four cell centres")
local wide = Painting.new(
	"j2",
	"w2",
	0,
	Config,
	{ primary = "mint" },
	{ { width = 16, height = 8 } }
)
assert(Painting.step(wide, "inspect", nil, 1, true), "Inspect failed")
assert(Painting.step(wide, "prepare", nil, 2, true), "Prepare failed")
assert(Painting.step(wide, "choose", "mint", 3, true), "Material failed")
assert(Painting.batch(wide, 1, { { u = 0.5, v = 0.5 } }, true, 4, true), "Wide stroke failed")
assert(wide.count == 1, "Small roller filled a wider physical gap")
assert(compact.count == 4 and compact.seq == 1, "Independent wall changed compact state")
print("PaintGeometry: presets, immutable sizes, missing layouts and physical radius passed")

local source = { { width = 16, height = 8 }, { width = 8, height = 9 } }
local duo = Painting.new("duo", "a", 0, Config, { primary = "mint", secondary = "rose" }, source)
source[1].width = 64
assert(duo.sizes[1].width == 16, "Caller changed live geometry")
assert(Painting.step(duo, "inspect", nil, 1, true), "Inspect failed")
assert(Painting.step(duo, "prepare", nil, 2, true), "Prepare failed")
assert(not Painting.tool(duo, "wide", 49), "Geometry bypassed XP")
assert(Painting.tool(duo, "wide", 50), "Unlocked tool failed")
assert(Painting.step(duo, "choose", "mint", 3, true), "Material failed")
assert(Painting.batch(duo, 1, { { u = 0.5, v = 0.5 } }, true, 4, true), "Wide stroke failed")
assert(duo.count == 4, "Wide brush lost physical footprint")
assert(
	not Painting.batch(duo, 1, { { u = 0.5, v = 0.5 } }, true, 5, true),
	"Geometry replay accepted"
)
assert(
	not Painting.batch(duo, 2, { { u = 0 / 0, v = 0.5 } }, true, 6, true),
	"Geometry allowed NaN"
)
assert(
	not Painting.batch(duo, 2, { { u = 0.5, v = 0.5 } }, true, 7, false),
	"Geometry bypassed eligibility"
)
duo.phase, duo.count = "Ready", 96
for i = 1, 96 do
	duo.cells[i] = true
end
assert(Painting.nextSurface(duo, "b", 10), "Second surface failed")
assert(
	duo.toolId == "basic" and Painting.tool(duo, "wide", 50),
	"Second wall did not reset/revalidate tool"
)
assert(Painting.step(duo, "choose", "rose", 11, true), "Second material failed")
assert(Painting.batch(duo, 1, { { u = 0.5, v = 0.5 } }, true, 12, true), "Second stroke failed")
assert(
	duo.count == 8 and #duo.completedMasks == 1 and duo.config.colorId == "rose",
	"Second surface reused first brush geometry/mask"
)
for _, bad in
	{
		{},
		{ { width = 0, height = 8 } },
		{ { width = 0 / 0, height = 8 } },
		{ { width = 8, height = math.huge } },
		{ { width = 65, height = 8 } },
	}
do
	assert(not pcall(function()
		Painting.new("bad", "bad", 0, Config, { primary = "mint" }, bad)
	end), "Invalid server geometry accepted")
end
local view = require("../src/shared/PaintView")
for _, sizes in expected do
	for _, size in sizes do
		for _, viewport in { { 320, 640 }, { 926, 403 }, { 666, 316 }, { 567, 260 } } do
			local w, h = size[1], size[2]
			local vw, vh = viewport[1], viewport[2]
			local top, bottom = 40, vh - 140
			local distance, offset = view.fit(w, h, vw, vh, top, bottom)
			local scale = vh / (2 * distance * math.tan(math.rad(25)))
			local center = vh / 2 + offset * scale
			assert(
				w * scale <= vw - 32
					and center - h * scale / 2 >= top
					and center + h * scale / 2 <= bottom,
				"Variant left camera work area"
			)
		end
	end
end
print(
	"PaintGeometry: real brush units, copies/invalid sizes, wide XP, replay/NaN/eligibility, second wall and camera bounds passed"
)

local oneCell = {
	columns = 1,
	rows = 1,
	threshold = Config.threshold,
	minSeconds = Config.minSeconds,
	maxPoints = Config.maxPoints,
	packetInterval = Config.packetInterval,
	maxSegment = Config.maxSegment,
	rollerRadius = Config.rollerRadius,
	wideRollerRadius = Config.wideRollerRadius,
	wideRollerXP = Config.wideRollerXP,
	areaPerSecond = Config.areaPerSecond,
	areaBurst = Config.areaBurst,
	colorId = Config.colorId,
}
local single = Painting.new("one", "one", 0, oneCell)
assert(
	single.sizes[1].width == 1 and single.sizes[1].height == 1,
	"Legacy one-cell configuration rejected"
)
