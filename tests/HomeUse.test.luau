--!strict
local Use = require("../src/server/Domain/HomeUse")
local function facts(): Use.Facts
	return {
		ownerId = 1,
		actorId = 1,
		available = true,
		alive = true,
		inside = true,
		owned = true,
		placed = true,
		visible = true,
		distance = 8,
		catalogId = "floor-lamp-v1",
	}
end
assert(Use.allowed(facts()), "Own nearby installed lamp refused")
for _, field in { "available", "alive", "inside", "owned", "placed", "visible" } do
	local f = facts()
	if field == "available" then
		f.available = false
	elseif field == "alive" then
		f.alive = false
	elseif field == "inside" then
		f.inside = false
	elseif field == "owned" then
		f.owned = false
	elseif field == "placed" then
		f.placed = false
	else
		f.visible = false
	end
	assert(not Use.allowed(f), "Use ignored " .. field)
end
local f = facts()
f.actorId = 2
assert(not Use.allowed(f), "Foreign actor used lamp")
f = facts()
f.catalogId = "floor-plant-v1"
assert(not Use.allowed(f), "Unusable furniture accepted")
for _, distance in { -1, 8.01, 0 / 0, math.huge } do
	f = facts()
	f.distance = distance
	assert(not Use.allowed(f), "Invalid distance accepted")
end
f = facts()
f.distance = 0
assert(Use.allowed(f), "Zero distance refused")
assert(Use.allowed(facts()), "One player's refusal changed another")
print("HomeUse: owner/profile/character/placement/room/LOS/distance and independence passed")
