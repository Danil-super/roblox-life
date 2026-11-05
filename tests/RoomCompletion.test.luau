--!strict
local Plan = require("../src/shared/HomePlan")
local items: { Plan.Item } = {}
for index, id in
	{ "floor-plant-v1", "reading-chair-v1", "side-table-v1", "floor-lamp-v1", "bookcase-v1" }
do
	table.insert(items, {
		id = tostring(index),
		catalogId = id,
		purchaseOperationId = "buy-" .. index,
		placed = { x = index, z = 6, rotationY = 0 },
	})
end
local full = Plan.evaluate(items)
assert(Plan.isComplete(full), "Confirmed five-item room not complete")
assert(
	not Plan.isComplete(nil) and not Plan.isComplete(Plan.evaluate({})),
	"Empty/missing plan completed"
)
items[1].placed = nil
assert(not Plan.isComplete(Plan.evaluate(items)), "Stored item kept room complete")
local invalid = Plan.evaluate(items)
invalid.placed = invalid.total
assert(not Plan.isComplete(invalid), "Count overrode missing installation")
invalid = Plan.evaluate(items)
invalid.goals[1].complete = true
assert(not Plan.isComplete(invalid), "Goal flag overrode missing installation")
full.total = 0
assert(not Plan.isComplete(full), "Empty totals completed room")
full = Plan.evaluate(items)
full.placed = math.huge
assert(not Plan.isComplete(full), "Invalid total accepted")
assert(items[1].placed == nil and items[2].placed ~= nil, "Completion mutated placements")
print(
	"RoomCompletion: confirmed requirements, incomplete/storage/missing/malformed and no mutation passed"
)
