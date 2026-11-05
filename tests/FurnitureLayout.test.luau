--!strict
local Furniture = require("../src/server/Domain/Furniture")
local Layout = Furniture.layout
local Economy = require("../src/server/Domain/Economy")
local Profile = require("../src/server/Domain/Profile")
local p = Profile.new(1)
p.wallet.dollars = 1000
assert(Economy.purchase(p, "buy-plant", "floor-plant-v1", "plant", 1), "Test purchase failed")
local revision, dollars = p.revision, p.wallet.dollars
assert(table.isfrozen(Layout) and table.isfrozen(Layout.fixed), "Guide geometry is mutable")
local ids: { [string]: boolean } = {}
for _, region in Layout.fixed do
	assert(table.isfrozen(region) and not ids[region.id], "Mutable or repeated region")
	ids[region.id] = true
	local pose, reason = Furniture.validate(p, "plant", {
		x = region.x,
		z = region.z,
		rotationY = 0,
		mode = "Free",
	}, 0)
	assert(pose == nil and reason == "Blocked", "A guide zone permits placement")
end
assert(#Layout.fixed == 5 and ids.Passage and ids.Spawn, "Required passage/spawn zones missing")
for _, x in { -Layout.halfWidth, Layout.halfWidth } do
	local pose, reason =
		Furniture.validate(p, "plant", { x = x, z = 5, rotationY = 0, mode = "Free" }, 0)
	assert(not pose and reason == "Bounds", "Boundary ignores object footprint")
end
for _, z in { -Layout.halfDepth, Layout.halfDepth } do
	local pose, reason =
		Furniture.validate(p, "plant", { x = 5, z = z, rotationY = 0, mode = "Free" }, 0)
	assert(not pose and reason == "Bounds", "Depth boundary ignores object footprint")
end
assert(
	Furniture.validate(p, "plant", { x = 5, z = 3, rotationY = 0, mode = "Grid" }, 0),
	"Previous valid pose changed"
)
assert(
	p.revision == revision and p.wallet.dollars == dollars and next(p.housing.placements) == nil,
	"Guidance validation mutated profile"
)
print(
	"FurnitureLayout: immutable geometry, every marked zone denied, footprint boundaries and no mutation passed"
)
