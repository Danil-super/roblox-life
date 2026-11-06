--!strict
local Plan = require("../src/shared/HomePlan")
local Budget = require("../src/shared/HomeBudget")
local Config = require("../src/server/Domain/EconomyConfig")
local Profile = require("../src/server/Domain/Profile")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local Types = require("../src/shared/HomeTypes")
local ids = { "cozy-sofa-v1", "floor-easel-v1", "floor-planter-v1" }
local catalog: { Types.Product } = {}
for id, spec in Config.catalog do
	table.insert(catalog, {
		id = id,
		dollars = spec.dollars,
		modelVersion = spec.modelVersion,
		width = spec.width,
		depth = spec.depth,
		height = spec.height,
	})
end
assert(#catalog == 8, "Creative furnishings missing from catalog")
local items: { Plan.Item } = {}
for i, id in
	{ "floor-plant-v1", "reading-chair-v1", "side-table-v1", "floor-lamp-v1", "bookcase-v1" }
do
	table.insert(items, {
		id = "basic" .. i,
		catalogId = id,
		purchaseOperationId = "buy-basic" .. i,
		placed = { x = i, z = 6, rotationY = 0 },
	})
end
local basic = Plan.evaluate(items)
assert(Plan.isComplete(basic) and basic.total == 5, "Optional items changed basic room completion")
assert(#Plan.displayGoals(Plan.evaluate({}), {}) == 3, "Optional collection distracted empty room")
local goals = Plan.displayGoals(basic, items)
assert(#goals == 4 and #basic.goals == 3, "Display goals mutated confirmed base plan")
local optional = goals[4]
assert(
	optional.id == "creativeCorner" and not optional.complete and #optional.requirements == 3,
	"Optional collection requirements missing"
)
local budget = Budget.evaluate(optional, catalog, 330, true)
assert(
	budget.cost == 1080 and budget.shortfall == 750 and budget.action == "Buy",
	"Optional budget used wrong prices"
)
assert(
	Budget.evaluate(optional, catalog, 239, true).action == "Earn",
	"Unaffordable collection did not suggest work"
)
local p = Profile.new(13)
p.wallet.dollars = 1080
local positions = { { -7, 9 }, { -13, 4 }, { 10, 9 } }
for i, id in ids do
	local before = p.wallet.dollars
	assert(
		Economy.purchase(p, "creative-buy" .. i, id, "creative" .. i, i),
		"New item purchase failed"
	)
	assert(p.wallet.dollars == before - Config.catalog[id].dollars, "Server price ignored")
	assert(
		Economy.purchase(p, "creative-buy" .. i, id, "duplicate" .. i, i + 10)
			and p.inventory["duplicate" .. i] == nil
			and p.wallet.dollars == before - Config.catalog[id].dollars,
		"Replay charged or duplicated new furniture"
	)
	assert(
		not Furniture.place(
			p,
			"creative" .. i,
			{ x = 0, z = 7, rotationY = 0, mode = "Grid" },
			p.housing.revision
		),
		"New furniture blocked passage"
	)
	assert(
		Furniture.place(
			p,
			"creative" .. i,
			{ x = positions[i][1], z = positions[i][2], rotationY = 0, mode = "Grid" },
			p.housing.revision
		),
		"New furniture did not fit approved area"
	)
	table.insert(items, {
		id = "creative" .. i,
		catalogId = id,
		purchaseOperationId = "creative-buy" .. i,
		placed = p.housing.placements["creative" .. i],
	})
end
assert(
	p.wallet.dollars == 0 and not Economy.purchase(p, "too-poor", ids[1], "extra", 30),
	"Insufficient funds purchased a sofa"
)
assert(
	Plan.displayGoals(basic, items)[4].complete,
	"Three installed items did not complete optional collection"
)
assert(not Plan.displayGoals(basic, {})[4].complete, "Owned items crossed players")
local revision = p.housing.revision
assert(
	not Furniture.place(
			p,
			"creative2",
			{ x = -7, z = 9, rotationY = 0, mode = "Grid" },
			revision
		) and p.housing.revision == revision,
	"Easel overlapped the sofa"
)
assert(
	not Furniture.place(p, "creative1", { x = 14, z = 9, rotationY = 0, mode = "Grid" }, revision),
	"Sofa crossed room bounds"
)
assert(Furniture.store(p, "creative1", p.housing.revision), "Sofa did not return to storage")
items[6].placed = nil
local stored = Plan.displayGoals(basic, items)[4]
assert(
	not stored.complete
		and Budget.evaluate(stored, catalog, 0, true).action == "Place"
		and Budget.evaluate(stored, catalog, 0, true).cost == 0,
	"Stored sofa demanded another purchase"
)
assert(Plan.isComplete(Plan.evaluate(items)), "Optional storage cleared basic 5/5")
local loaded = Profile.decode(p, 13)
assert(
	loaded
		and loaded.wallet.dollars == 0
		and loaded.inventory.creative1
		and not loaded.housing.placements.creative1
		and loaded.housing.placements.creative2,
	"Decode lost new catalog ownership/placement"
)
print(
	"CreativeHome: optional base5/collection3, budget, purchases/replays, placement, store, decode and isolation passed"
)

local Store = require("../src/server/Domain/ProfileStore")
local saved: unknown = {
	recordVersion = 1,
	profile = p,
	fence = 1,
	leaseOwner = "",
	leaseUntil = 0,
	commitId = "creative-seed",
}
local adapter: Store.Adapter = {
	update = function(_key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local value = transform(saved)
		if value ~= nil then
			saved = value
		end
		return true, value
	end,
}
local first = Store.new(adapter, 13, "creative-first", function(): number
	return 1000
end, 60)
assert(first.load() and first.close(), "Creative profile lease/release failed")
local second = Store.new(adapter, 13, "creative-second", function(): number
	return 1001
end, 60)
assert(second.load(), "Creative profile reload failed")
local reloaded = second.read()
assert(
	reloaded
		and reloaded.wallet.dollars == 0
		and reloaded.inventory.creative1
		and not reloaded.housing.placements.creative1
		and reloaded.housing.placements.creative2,
	"Storage reload lost new owned/placed items"
)
assert(
	second.transact(function(c: Profile.Profile): boolean
		return Economy.purchase(c, "creative-buy1", "cozy-sofa-v1", "replayed-sofa", 50) ~= nil
	end),
	"Stored sofa replay did not return original receipt"
)
local repeated = second.read()
assert(
	repeated and repeated.wallet.dollars == 0 and not repeated.inventory["replayed-sofa"],
	"Reloaded sofa charged twice"
)
print("CreativeHome storage: release/reload, new owned/placed items and sofa replay passed")
