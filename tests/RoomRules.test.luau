--!strict
local Rules = require("../src/server/Domain/RoomRules")
assert(Rules.contains(0, 3, 4), "Spawn must be inside its room")
assert(Rules.contains(15, 3, 11), "Interior near walls must be recognized")
assert(not Rules.contains(0, 3, 12), "Doorway boundary must lead outside")
assert(not Rules.contains(16, 3, 0), "Side wall boundary must be outside interior")
assert(not Rules.contains(0, 12, 0), "Rooftop is not interior")
assert(not Rules.contains(0 / 0, 3, 0), "NaN cannot pass bounds")
assert(not Rules.contains(0, math.huge, 0), "Infinite coordinates cannot pass bounds")
assert(Rules.mayEnter(123, 123), "Owner must have access")
assert(not Rules.mayEnter(123, 456), "Private room must reject guests")
assert(not Rules.mayEnter(0 / 0, 0 / 0), "Invalid identifiers cannot grant access")
local firstX, firstZ = Rules.origin(1)
local lastX, lastZ = Rules.origin(16)
assert(
	firstX == 0 and firstZ == 0 and lastX == 192 and lastZ == 384,
	"Slots must fit the compact neighborhood"
)
local occupied: { [string]: boolean } = {}
for slot = 1, 16 do
	local x, z = Rules.origin(slot)
	local key = x .. ":" .. z
	assert(not occupied[key], "Each room needs its own plot")
	occupied[key] = true
end
print("12 room rule scenarios passed")
