--!strict
local Rooms = require("../src/server/Domain/ClientRoomConfig")
local Config = require("../src/server/Domain/EconomyConfig")
local Strings = require("../src/shared/Strings")
for _, contract in Config.contracts do
	assert(Rooms[contract.roomStyle], "Unknown contract room style")
	for _, lang in { "en", "ru" } do
		assert(
			Strings.text(lang, contract.clientKey) ~= contract.clientKey,
			"Missing resident name"
		)
	end
end
for _, room in Rooms do
	for _, item in room.furniture do
		local spec = Config.catalog[item.id]
		assert(spec, "Room uses unknown furniture")
		local radiusX = if item.yaw == 90 then spec.depth / 2 else spec.width / 2
		local radiusZ = if item.yaw == 90 then spec.width / 2 else spec.depth / 2
		assert(math.abs(item.x) - radiusX > 6.5, "Furniture blocks central work area")
		assert(
			math.abs(item.x) + radiusX < 15.4 and math.abs(item.z) + radiusZ < 11,
			"Furniture intersects room shell"
		)
	end
end
print("ClientRooms: known styles/names/models, clear central work area and room bounds passed")
