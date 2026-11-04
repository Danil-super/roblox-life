--!strict
local Plan = require("../src/shared/HomePlan")
local Profile = require("../src/server/Domain/Profile")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local p, other = Profile.new(1), Profile.new(2)
p.wallet.dollars = 2000
local function read(candidate: Profile.Profile): Plan.Progress
	local items: { Plan.Item } = {}
	for id, item in candidate.inventory do
		table.insert(items, {
			id = id,
			catalogId = item.catalogItemId,
			purchaseOperationId = item.purchaseOperationId,
			placed = candidate.housing.placements[id],
		})
	end
	return Plan.evaluate(items)
end
local empty = read(p)
assert(empty.placed == 0 and empty.total == 5 and #empty.goals == 3, "Initial plan changed")
assert(
	not empty.goals[1].complete and empty.goals[1].requirements[1].itemId == nil,
	"Empty room completed goal"
)
assert(Economy.purchase(p, "plant-buy", "floor-plant-v1", "plant", 1))
assert(read(p).placed == 0, "Buying alone counted as furnishing")
assert(Furniture.place(p, "plant", { x = 5, z = 3, rotationY = 0, mode = "Grid" }, 0))
assert(read(p).placed == 1 and read(p).goals[1].complete, "Installed plant not counted")
assert(Economy.purchase(p, "plant-two-buy", "floor-plant-v1", "plant-two", 2))
assert(Furniture.place(p, "plant-two", { x = 9, z = 3, rotationY = 0, mode = "Grid" }, 1))
assert(read(p).placed == 1, "Duplicate plants completed different goals")
assert(Economy.purchase(p, "chair-buy", "reading-chair-v1", "chair", 3))
assert(Economy.purchase(p, "shelf-buy", "bookcase-v1", "shelf", 4))
assert(Furniture.place(p, "chair", { x = -6, z = 4, rotationY = 0, mode = "Grid" }, 2))
assert(Furniture.place(p, "shelf", { x = 7, z = -2, rotationY = 90, mode = "Grid" }, 3))
local state = read(p)
assert(state.placed == 3 and state.goals[3].complete, "Installed storage not counted")
assert(not state.goals[2].complete, "Chair alone completed reading corner")
assert(state.goals[2].requirements[1].itemId == "chair", "Owned chair not linked")
state.goals[2].requirements[1].catalogId = "tampered"
assert(read(p).goals[2].requirements[1].catalogId == "reading-chair-v1", "Projection mutated plan")
assert(Furniture.store(p, "plant", 4) and Furniture.store(p, "plant-two", 5), "Store plants failed")
assert(not read(p).goals[1].complete and read(p).placed == 2, "Stored item counted as installed")
assert(read(other).placed == 0 and other.wallet.dollars == 0, "Plan crossed players")
local decoded = Profile.decode(p, 1)
assert(decoded and read(decoded).placed == 2, "New purchases/plan did not survive profile decode")
assert(
	not Furniture.place(p, "shelf", { x = 0, z = 8, rotationY = 0, mode = "Grid" }, 6),
	"New furniture blocked doorway"
)
local selection = Plan.evaluate({
	{ id = "a", catalogId = "floor-plant-v1", purchaseOperationId = "buy-a" },
	{
		id = "z",
		catalogId = "floor-plant-v1",
		purchaseOperationId = "buy-z",
		placed = { x = 5, z = 3, rotationY = 0 },
	},
})
assert(selection.goals[1].requirements[1].itemId == "z", "Stored duplicate hid installed item")
print(
	"HomePlan: placement goals, duplicate handling, storage, new products, decode and isolation passed"
)

assert(Economy.purchase(p, "table-buy", "side-table-v1", "table", 5))
assert(Economy.purchase(p, "lamp-buy", "floor-lamp-v1", "lamp", 6))
assert(Furniture.place(p, "plant", { x = 5, z = 3, rotationY = 0, mode = "Grid" }, 6))
assert(Furniture.place(p, "table", { x = 9, z = 3, rotationY = 0, mode = "Grid" }, 7))
assert(Furniture.place(p, "lamp", { x = 12, z = 3, rotationY = 0, mode = "Grid" }, 8))
local complete = read(p)
assert(
	complete.placed == 5 and p.wallet.dollars == 700,
	"Full plan or actual purchase costs incorrect"
)
for _, goal in complete.goals do
	assert(goal.complete, "Fully furnished room has unfinished goal")
end
local Store = require("../src/server/Domain/ProfileStore")
local saved: unknown = {
	recordVersion = 1,
	profile = p,
	fence = 1,
	leaseOwner = "",
	leaseUntil = 0,
	commitId = "home-seed",
}
local adapter: Store.Adapter = {
	update = function(_key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local result = transform(saved)
		if result ~= nil then
			saved = result
		end
		return true, result
	end,
}
local first = Store.new(adapter, 1, "home-first", function(): number
	return 1000
end, 60)
assert(first.load() and first.close(), "Home plan lease/release failed")
local second = Store.new(adapter, 1, "home-second", function(): number
	return 1001
end, 60)
assert(second.load(), "Home plan reload failed")
local loaded = second.read()
assert(
	loaded and read(loaded).placed == 5 and loaded.wallet.dollars == 700,
	"Room plan changed on memory reload"
)
assert(
	second.transact(function(c: Profile.Profile): boolean
		return Economy.purchase(c, "chair-buy", "reading-chair-v1", "duplicate-chair", 7) ~= nil
	end),
	"New product purchase retry failed"
)
local repeated = second.read()
assert(
	repeated and repeated.inventory["duplicate-chair"] == nil and repeated.wallet.dollars == 700,
	"Reloaded chair paid twice"
)
print(
	"HomePlan persistence: five items, full plan, release/reload and repeated chair purchase passed"
)
