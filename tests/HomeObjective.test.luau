--!strict
local Objective = require("../src/shared/HomeObjective")
local Plan = require("../src/shared/HomePlan")
local Types = require("../src/shared/HomeTypes")
local items: { Plan.Item } = {}
local s: Types.Snapshot = {
	available = true,
	dollars = 70,
	revision = 1,
	editorId = "editor",
	homeName = "home",
	origin = { 0, 0, 0 },
	nearHome = true,
	nearShop = false,
	items = items,
	catalog = {},
	onboarding = "DONE",
	plan = Plan.evaluate(items),
}
assert(Objective.evaluate(nil, false) == nil, "Missing profile invented home progress")
s.plan = nil
assert(Objective.evaluate(s, false) == nil, "Missing confirmed plan invented progress")
s.plan = Plan.evaluate(items)
local first = Objective.evaluate(s, false)
assert(
	first and first.kind == "Base" and first.placed == 0 and first.total == 5,
	"Empty confirmed home has no goal"
)
for _, key in { "blocked", "available", "nearHome", "onboarding" } do
	if key == "blocked" then
		assert(Objective.evaluate(s, true) == nil, "Pending housing remained actionable")
	elseif key == "available" then
		s.available = false
	elseif key == "nearHome" then
		s.nearHome = false
	else
		s.onboarding = "PLACE"
	end
	if key ~= "blocked" then
		assert(Objective.evaluate(s, false) == nil, "Unavailable/context/onboarding gate ignored")
	end
	if key == "available" then
		s.available = true
	elseif key == "nearHome" then
		s.nearHome = true
	elseif key == "onboarding" then
		s.onboarding = "DONE"
	end
end
for i, id in
	{ "floor-plant-v1", "reading-chair-v1", "side-table-v1", "floor-lamp-v1", "bookcase-v1" }
do
	table.insert(items, {
		id = "base" .. i,
		catalogId = id,
		purchaseOperationId = "buy" .. i,
		placed = {
			x = i,
			z = 6,
			rotationY = 0,
		},
	})
end
assert(Objective.evaluate(s, false) == nil, "Stale plan disagreed with confirmed inventory")
s.plan = Plan.evaluate(items)
local creative = Objective.evaluate(s, false)
assert(
	creative and creative.kind == "Creative" and creative.placed == 0 and creative.total == 3,
	"Completed base has no optional goal"
)
for i, id in { "cozy-sofa-v1", "floor-easel-v1", "floor-planter-v1" } do
	table.insert(items, {
		id = "extra" .. i,
		catalogId = id,
		purchaseOperationId = "extra-buy" .. i,
		placed = { x = 10, z = i, rotationY = 0 },
	})
end
local ready = Objective.evaluate(s, false)
assert(ready and ready.kind == "Ready" and ready.placed == 3, "Fully furnished room not recognized")
table.insert(items, {
	id = "duplicate-sofa",
	catalogId = "cozy-sofa-v1",
	purchaseOperationId = "another-sofa",
	placed = { x = 5, z = -6, rotationY = 90 },
})
local duplicate = Objective.evaluate(s, false)
assert(duplicate and duplicate.placed == 3, "Duplicate furniture inflated the goal")
items[6].placed = nil
local replacement = Objective.evaluate(s, false)
assert(replacement and replacement.kind == "Ready", "Installed second sofa was ignored")
table.remove(items)
local stored = Objective.evaluate(s, false)
assert(
	stored and stored.kind == "Creative" and stored.placed == 2,
	"Stored sofa kept full completion"
)
items[1].placed = nil
s.plan = Plan.evaluate(items)
local base = Objective.evaluate(s, false)
assert(base and base.kind == "Base" and base.placed == 4, "Stored base item kept optional cue")
assert(
	first and first.placed == 0 and creative and creative.placed == 0,
	"Later projections mutated earlier snapshots"
)
print("HomeObjective: readiness/context, base/optional/store, stale snapshots and isolation passed")
