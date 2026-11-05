--!strict
local Store = require("../src/server/Domain/ProfileStore")
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local Guide = require("../src/shared/FirstSteps")
local saved: unknown = nil
local failAfter = false
local adapter: Store.Adapter = {
	update = function(_key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local value = transform(saved)
		if value ~= nil then
			saved = value
		end
		return not failAfter, value
	end,
}
local a = Store.new(adapter, 1, "guide-first", function(): number
	return 1000
end, 60)
local function read(s: Store.Session, phase: string): Guide.Progress
	local p = s.read()
	return Guide.evaluate(if p
		then {
			completed = p.onboarding.completed,
			paid = p.jobs.completedCount > 0,
			ownsFurniture = next(p.inventory) ~= nil,
			phase = phase,
		}
		else nil)
end
assert(a.load(), "Profile failed to load")
assert(
	a.transact(function(p: Profile.Profile): boolean
		return Jobs.accept(p, "first")
	end),
	"Accept failed"
)
assert(read(a, "Inspect").completed == 1, "Accept did not advance first step")
assert(
	a.transact(function(p: Profile.Profile): boolean
		local job = p.jobs.active
		assert(job, "Job missing")
		job.status = "ReadyForInspection"
		return Economy.completeJob(p, "first", 1001) ~= nil
	end),
	"Payment failed"
)
assert(read(a, "Completed").current == "buy", "Paid profile did not resume at buying")
assert(
	a.transact(function(p: Profile.Profile): boolean
		return Economy.purchase(p, "plant-buy", "floor-plant-v1", "plant", 1002) ~= nil
	end),
	"Purchase failed"
)
assert(read(a, "Completed").current == "place", "Purchased profile did not resume at placing")
local mutations = 0
failAfter = true
assert(not a.transact(function(p: Profile.Profile): boolean
	mutations += 1
	local ok = Furniture.place(p, "plant", { x = 5, z = 3, rotationY = 0, mode = "Grid" }, 0)
	return ok
end), "Unknown placement acknowledged")
assert(read(a, "Completed").status == "Waiting", "Unknown commit invented tutorial progress")
failAfter = false
assert(a.retry() and mutations == 1, "Placement mutation repeated")
assert(read(a, "Completed").status == "Done", "Recovered placement did not complete guide")
assert(a.close(), "Session release failed")
local b = Store.new(adapter, 1, "guide-second", function(): number
	return 1001
end, 60)
assert(b.load(), "Reload failed")
assert(read(b, "Completed").completed == 7, "Confirmed milestones disappeared on reload")
local loaded = b.read()
assert(loaded and loaded.wallet.dollars == 70 and loaded.schemaVersion == 3, "Money/schema changed")
assert(
	b.transact(function(p: Profile.Profile): boolean
		local ok = Furniture.store(p, "plant", 1)
		return ok
	end),
	"Store failed"
)
assert(read(b, "Completed").status == "Done", "Storing furniture erased tutorial history")
assert(
	b.transact(function(p: Profile.Profile): boolean
		return Jobs.accept(p, "second", "paint-mint-v1")
	end),
	"Next job failed"
)
assert(read(b, "Inspect").status == "Done", "Next job restarted onboarding")
local other =
	Guide.evaluate({ completed = false, paid = false, ownsFurniture = false, phase = "Offer" })
assert(other.completed == 0, "Progress crossed profiles")
print(
	"FirstSteps persistence: payment, purchase, uncertain placement/retry, release/reload, storage and next job passed"
)
