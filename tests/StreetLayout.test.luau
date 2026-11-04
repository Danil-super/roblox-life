--!strict
local Layout = require("../src/shared/StreetLayout")
local Rooms = require("../src/server/Domain/RoomRules")
local p = Layout.create()
assert(#p.crossings == 96 and #p.dashes == 52, "Road markings changed")
assert(
	#p.trees == 16 and #p.benches == 8 and #p.lamps == 8 and #p.signs == 8,
	"Missing street landmarks"
)
local function overlaps(
	x: number,
	z: number,
	hx: number,
	hz: number,
	cx: number,
	cz: number,
	cw: number,
	cd: number
): boolean
	return math.abs(x - cx) < hx + cw and math.abs(z - cz) < hz + cd
end
for _, group in
	{
		{ items = p.trees, hx = 4, hz = 4 },
		{ items = p.benches, hx = 3, hz = 1.3 },
		{ items = p.lamps, hx = 1, hz = 1 },
		{ items = p.signs, hx = 3, hz = 0.5 },
	}
do
	for _, site in group.items do
		assert(
			site.x == site.x
				and site.z == site.z
				and math.abs(site.x) < 248
				and site.z >= 0
				and site.z < 512,
			"Scenery outside ground"
		)
		for slot = 1, Rooms.SLOTS do
			local x, z = Rooms.origin(slot)
			assert(
				not overlaps(site.x, site.z, group.hx, group.hz, x, z, 16, 12),
				"Decoration enters private home"
			)
			assert(
				not overlaps(site.x, site.z, group.hx, group.hz, x, z + 68, 16, 12),
				"Decoration enters client room"
			)
			assert(
				not overlaps(site.x, site.z, group.hx, group.hz, x, z + 36, 5, 20),
				"Decoration blocks doorway/crossing route"
			)
		end
		assert(
			not overlaps(site.x, site.z, group.hx, group.hz, 32, 0, 10, 11),
			"Decoration enters shop"
		)
		assert(
			not overlaps(site.x, site.z, group.hx, group.hz, 32, 24, 3, 12),
			"Decoration blocks shop route"
		)
	end
end
for row = 0, 3 do
	for col = 0, 3 do
		local n = 0
		for _, site in p.crossings do
			if site.x == col * 64 and math.abs(site.z - (row * 128 + 38)) < 8 then
				n += 1
			end
		end
		assert(n == 6, "Slot has no complete crossing")
	end
end
p.trees[1].x = 999
assert(Layout.create().trees[1].x ~= 999, "Layout leaked mutable shared data")
print(
	"StreetLayout: 16 crossings, bounded landmarks, clear private rooms/routes and fresh plans passed"
)
