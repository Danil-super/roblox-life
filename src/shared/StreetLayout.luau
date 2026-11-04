--!strict
export type Site = { x: number, z: number }
export type Sign = { x: number, z: number, key: string }
export type Plan = {
	crossings: { Site },
	dashes: { Site },
	trees: { Site },
	benches: { Site },
	lamps: { Site },
	signs: { Sign },
}
local Layout = {}
-- Matches the four existing Rojo roads and RoomRules' 4x4 room grid.
function Layout.create(): Plan
	local p: Plan =
		{ crossings = {}, dashes = {}, trees = {}, benches = {}, lamps = {}, signs = {} }
	for row = 0, 3 do
		local base = row * 128
		for col = 0, 3 do
			for stripe = 0, 5 do
				table.insert(p.crossings, { x = col * 64, z = base + 31.75 + stripe * 2.5 })
			end
			table.insert(p.trees, { x = col * 64 + 22, z = base + 54 })
		end
		for x = -32, 224, 16 do
			if x % 64 ~= 0 then
				table.insert(p.dashes, { x = x, z = base + 38 })
			end
		end
		for _, x in { 24, 152 } do
			table.insert(p.benches, { x = x, z = base + 24 })
			table.insert(p.lamps, { x = x, z = base + 18 })
		end
		table.insert(p.signs, { x = 12, z = base + 28, key = "streetHomes" })
		table.insert(p.signs, { x = 12, z = base + 48, key = "streetClients" })
	end
	return p
end
return table.freeze(Layout)
