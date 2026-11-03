--!strict
local Store = require("../src/server/Domain/ProfileStore")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local Profile = require("../src/server/Domain/Profile")
local data: { [string]: unknown } = {}
local failAfter = false
local adapter: Store.Adapter = {
	update = function(key: string, change: (unknown) -> unknown): (boolean, unknown)
		local result = change(data[key])
		if result ~= nil then
			data[key] = result
		end
		if failAfter then
			return false, "Unknown"
		end
		return true, result
	end,
}
local function clock(): number
	return 100
end
local first = Store.new(adapter, 1, "first", clock, 120)
assert(first.load(), "Load")
assert(
	first.transact(function(p: Profile.Profile): boolean
		p.jobs.issuedSequence = 1
		p.jobs.active = {
			id = "job-1",
			sequence = 1,
			templateId = "paint-tutorial-v1",
			status = "ReadyForInspection",
		}
		return Economy.completeJob(p, "job-1", 1) ~= nil
	end),
	"Award"
)
assert(
	first.transact(function(p: Profile.Profile): boolean
		return Economy.purchase(p, "buy-1", "floor-plant-v1", "plant-1", 2) ~= nil
	end),
	"Buy"
)
failAfter = true
assert(not first.transact(function(p: Profile.Profile): boolean
	local ok = Furniture.place(p, "plant-1", { x = 5, z = 3, rotationY = 45, mode = "Free" }, 0)
	return ok
end), "Unknown placement outcome must not acknowledge")
assert(first.read() == nil, "Unconfirmed state exposed")
failAfter = false
assert(first.retry(), "Retry must confirm the existing placement")
local placed = first.read()
assert(
	placed and placed.wallet.dollars == 70 and placed.housing.revision == 1,
	"Retry duplicated operation"
)
assert(first.close(), "Release")
local second = Store.new(adapter, 1, "second", clock, 120)
assert(second.load(), "Reacquire")
local restored = second.read()
assert(restored, "Read restored profile")
assert(
	restored.wallet.dollars == 70 and restored.inventory["plant-1"] ~= nil,
	"Money or ownership lost"
)
local pose = restored.housing.placements["plant-1"]
assert(pose and pose.x == 5 and pose.z == 3 and pose.rotationY == 45, "Pose did not restore")
assert(restored.onboarding.completed, "Onboarding did not persist")
assert(
	second.transact(function(p: Profile.Profile): boolean
		return Economy.purchase(p, "buy-1", "floor-plant-v1", "unused-new-id", 3) ~= nil
	end),
	"Duplicate purchase must acknowledge existing item"
)
local duplicate = second.read()
assert(
	duplicate and duplicate.wallet.dollars == 70 and duplicate.inventory["unused-new-id"] == nil,
	"Replay debited money"
)
print(
	"FurniturePersistence: unknown placement commit, reload and purchase replay passed (memory adapter, not cloud)"
)
