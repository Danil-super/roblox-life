--!strict
local Inventory = require("../src/shared/FurnitureInventory")
local Types = require("../src/shared/HomeTypes")
local items: { Types.Owned } = {
	{ id = "plant-1", catalogId = "floor-plant-v1", purchaseOperationId = "buy-1" },
	{
		id = "plant-2",
		catalogId = "floor-plant-v1",
		purchaseOperationId = "buy-2",
		placed = { x = 8, z = 6, rotationY = 345 },
	},
	{ id = "lamp", catalogId = "floor-lamp-v1", purchaseOperationId = "buy-3" },
}
local all = Inventory.project(items, "All")
assert(
	#all.items == 3 and all.counts.All == 3 and all.counts.Stored == 2 and all.counts.Placed == 1,
	"Counts must describe owned instances in all sections"
)
assert(all.items[1].id == "plant-1" and all.items[2].id == "plant-2", "Instance order changed")
local stored = Inventory.project(items, "Stored")
assert(
	#stored.items == 2 and stored.items[1].id == "plant-1" and stored.items[2].id == "lamp",
	"Stored section is wrong"
)
local placed = Inventory.project(items, "Placed")
assert(#placed.items == 1 and placed.items[1].id == "plant-2", "Duplicate product hid an instance")
items[2].placed = nil
local afterStore = Inventory.project(items, "Placed")
assert(
	#afterStore.items == 0 and afterStore.counts.Stored == 3,
	"Confirmed store did not change sections"
)
items[1].placed = { x = 9, z = 6, rotationY = 0 }
assert(
	Inventory.project(items, "Stored").counts.Placed == 1,
	"Confirmed placement did not change count"
)
local other = Inventory.project({}, "All")
assert(
	#other.items == 0 and other.counts.All == 0 and other.counts.Placed == 0,
	"Empty inventory inherited another player's counts"
)
assert(
	all.counts.Stored == 2 and stored.counts.Placed == 1,
	"Projection reused another result's counts"
)
assert(#items == 3 and items[1].purchaseOperationId == "buy-1", "Projection changed ownership")
table.clear(all.items)
assert(#items == 3 and #stored.items == 2, "Output list aliases source or another projection")
print(
	"FurnitureInventory: owned instances, confirmed poses, empty sections and independent projections passed"
)
