--!strict
local Budget = require("../src/shared/HomeBudget")
local Plan = require("../src/shared/HomePlan")
local Types = require("../src/shared/HomeTypes")
local catalog: { Types.Product } = {}
for _, entry in
	{
		{ "floor-plant-v1", 180 },
		{ "reading-chair-v1", 320 },
		{ "side-table-v1", 120 },
		{ "floor-lamp-v1", 220 },
		{ "bookcase-v1", 280 },
	}
do
	table.insert(catalog, {
		id = tostring(entry[1]),
		dollars = tonumber(entry[2]) or 0,
		modelVersion = 1,
		width = 2,
		depth = 2,
		height = 2,
	})
end
local empty = Plan.evaluate({})
local reading = Budget.evaluate(empty.goals[2], catalog, 70, true)
assert(
	reading.ready and reading.cost == 660 and reading.shortfall == 590 and reading.action == "Earn",
	"Reading goal budget missing"
)
assert(
	Budget.evaluate(empty.goals[2], catalog, 120, true).action == "Buy",
	"Affordable table was hidden by full-goal cost"
)
assert(
	Budget.evaluate(empty.goals[2], catalog, 660, true).shortfall == 0,
	"Exact balance not affordable"
)
local owned: { Plan.Item } = {
	{ id = "chair", catalogId = "reading-chair-v1", purchaseOperationId = "buy-chair" },
	{ id = "other-chair", catalogId = "reading-chair-v1", purchaseOperationId = "buy-chair2" },
}
local goal = Plan.evaluate(owned).goals[2]
local stored = Budget.evaluate(goal, catalog, 0, true)
assert(
	stored.cost == 340 and stored.stored == 1 and stored.action == "Place",
	"Stored item was counted as missing or duplicate counted twice"
)
owned[1].placed = { x = 6, z = 6, rotationY = 0 }
local installed = Budget.evaluate(Plan.evaluate(owned).goals[2], catalog, 200, true)
assert(
	installed.placed == 1
		and installed.stored == 0
		and installed.cost == 340
		and installed.shortfall == 140
		and installed.action == "Buy",
	"Installed chair did not reduce the remaining purchase budget"
)
local plant: { Plan.Item } = {
	{
		id = "plant",
		catalogId = "floor-plant-v1",
		purchaseOperationId = "buy-plant",
		placed = { x = 6, z = 6, rotationY = 0 },
	},
}
local done = Budget.evaluate(Plan.evaluate(plant).goals[1], catalog, 0, true)
assert(
	done.action == "Complete" and done.cost == 0 and done.placed == 1 and done.shortfall == 0,
	"Complete goal still needs money"
)
plant[1].placed = nil
assert(
	Budget.evaluate(Plan.evaluate(plant).goals[1], catalog, 0, true).action == "Place",
	"Storing furniture suggested buying a duplicate"
)
assert(not Budget.evaluate(goal, catalog, 0, false).ready, "Busy snapshot displayed budget")
for _, value in { -1, 0.5, 0 / 0, math.huge } do
	assert(
		not Budget.evaluate(goal, catalog, value, true).ready,
		"Invalid dollars displayed budget"
	)
end
assert(not Budget.evaluate(empty.goals[1], {}, 250, true).ready, "Missing price guessed an amount")
local broken = table.clone(catalog)
broken[1] = table.clone(catalog[1])
broken[1].dollars = -1
assert(not Budget.evaluate(empty.goals[1], broken, 250, true).ready, "Invalid price accepted")
local duplicate = table.clone(catalog)
table.insert(duplicate, catalog[1])
assert(
	not Budget.evaluate(empty.goals[1], duplicate, 250, true).ready,
	"Duplicate product ID accepted"
)
assert(
	goal.requirements[1].itemId == "chair" and catalog[1].dollars == 180 and reading.cost == 660,
	"Budget mutated inputs or other result"
)
print(
	"HomeBudget: ownership, missing cost, affordability, storage, malformed/busy and isolation passed"
)
local Strings = require("../src/shared/Strings")
local allStored: { Plan.Item } = {}
for _, id in { "reading-chair-v1", "side-table-v1", "floor-lamp-v1" } do
	table.insert(allStored, { id = id, catalogId = id, purchaseOperationId = "buy:" .. id })
end
local arranged = Budget.evaluate(Plan.evaluate(allStored).goals[2], catalog, 0, true)
assert(
	arranged.ready and arranged.cost == 0 and arranged.stored == 3 and arranged.action == "Place",
	"Owned full set suggested more earning"
)
local freeCatalog = table.clone(catalog)
freeCatalog[1] = table.clone(catalog[1])
freeCatalog[1].dollars = 0
assert(
	Budget.evaluate(empty.goals[1], freeCatalog, 0, true).action == "Buy",
	"Free unowned product was marked installed"
)
local malformedGoal: Plan.Goal = {
	id = "bad",
	complete = true,
	requirements = { { catalogId = "floor-plant-v1", placed = true } },
}
assert(
	not Budget.evaluate(malformedGoal, catalog, 0, true).ready,
	"Installation without ownership completed a budget"
)
for _, language in { "en", "ru" } do
	assert(Budget.text(reading, language):find("590", 1, true), "Localized deficit missing")
	assert(
		Budget.text(done, language):find(Strings.text(language, "roomGoalComplete"), 1, true),
		"Localized completion missing"
	)
	assert(
		Budget.text(Budget.evaluate(goal, catalog, 0, false), language)
			== Strings.text(language, "offerWaiting"),
		"Busy text guessed a budget"
	)
	assert(
		Budget.text(arranged, language):find(Strings.text(language, "roomBudgetStored"), 1, true),
		"All-owned guidance missing"
	)
end
