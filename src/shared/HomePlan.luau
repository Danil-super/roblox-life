--!strict
export type Item = {
	id: string,
	catalogId: string,
	purchaseOperationId: string,
	placed: { x: number, z: number, rotationY: number }?,
}
export type Requirement = { catalogId: string, itemId: string?, placed: boolean }
export type Goal = { id: string, complete: boolean, requirements: { Requirement } }
export type Progress = { placed: number, total: number, goals: { Goal } }
local definitions = {
	{ id = "greenHome", products = { "floor-plant-v1" } },
	{ id = "readingCorner", products = { "reading-chair-v1", "side-table-v1", "floor-lamp-v1" } },
	{ id = "homeStorage", products = { "bookcase-v1" } },
}
local Plan = {}
function Plan.evaluate(items: { Item }): Progress
	local selected: { [string]: Item } = {}
	for _, item in items do
		local old = selected[item.catalogId]
		if
			old == nil
			or (item.placed ~= nil and old.placed == nil)
			or ((item.placed ~= nil) == (old.placed ~= nil) and item.id < old.id)
		then
			selected[item.catalogId] = item
		end
	end
	local result: Progress = { placed = 0, total = 0, goals = {} }
	for _, definition in definitions do
		local goal: Goal = { id = definition.id, complete = true, requirements = {} }
		for _, catalogId in definition.products do
			local item = selected[catalogId]
			local placed = item ~= nil and item.placed ~= nil
			table.insert(
				goal.requirements,
				{ catalogId = catalogId, itemId = if item then item.id else nil, placed = placed }
			)
			goal.complete = goal.complete and placed
			result.total += 1
			if placed then
				result.placed += 1
			end
		end
		table.insert(result.goals, goal)
	end
	return result
end
return table.freeze(Plan)
