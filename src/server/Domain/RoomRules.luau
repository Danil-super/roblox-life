--!strict
-- Interior coordinates are local to the room template; the open doorway faces +Z.
local RoomRules = {}
RoomRules.WIDTH = 32
RoomRules.DEPTH = 24
RoomRules.HEIGHT = 10
RoomRules.SLOTS = 16
function RoomRules.origin(slot: number): (number, number)
	assert(slot % 1 == 0 and slot >= 1 and slot <= RoomRules.SLOTS, "Invalid room slot")
	return ((slot - 1) % 4) * 64, math.floor((slot - 1) / 4) * 128
end

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end

function RoomRules.contains(x: number, y: number, z: number): boolean
	return finite(x)
		and finite(y)
		and finite(z)
		and math.abs(x) < RoomRules.WIDTH / 2
		and math.abs(z) < RoomRules.DEPTH / 2
		and y > -1
		and y < RoomRules.HEIGHT + 1
end

function RoomRules.mayEnter(owner: number, visitor: number): boolean
	return finite(owner) and finite(visitor) and owner == visitor
end

return table.freeze(RoomRules)
