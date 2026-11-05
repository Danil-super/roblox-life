--!strict
local Types = require("./HomeTypes")
export type Filter = "All" | "Stored" | "Placed"
export type Counts = { All: number, Stored: number, Placed: number }
export type Projection = { items: { Types.Owned }, counts: Counts }
local Inventory = {}
function Inventory.project(items: { Types.Owned }, filter: Filter): Projection
	local result: Projection = { items = {}, counts = { All = 0, Stored = 0, Placed = 0 } }
	for _, item in items do
		local section: Filter = if item.placed then "Placed" else "Stored"
		result.counts.All += 1
		if item.placed then
			result.counts.Placed += 1
		else
			result.counts.Stored += 1
		end
		if filter == "All" or filter == section then
			table.insert(result.items, item)
		end
	end
	return result
end
function Inventory.count(counts: Counts, filter: Filter): number
	return if filter == "All"
		then counts.All
		elseif filter == "Stored" then counts.Stored
		else counts.Placed
end
return table.freeze(Inventory)
