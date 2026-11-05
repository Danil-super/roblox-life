--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local Result = require("../src/server/Domain/JobResult")
local Config = require("../src/shared/PaintConfig")
local function complete(count: number): (Profile.Profile, Painting.State)
	local p = Profile.new(1)
	assert(Jobs.accept(p, "finish", "paint-tutorial-v1"), "Fixture accept failed")
	local w = Painting.new("finish", "work", 0, Config)
	assert(Painting.step(w, "inspect", nil, 0, true), "Inspect failed")
	assert(Painting.step(w, "prepare", nil, 0, true), "Prepare failed")
	assert(Painting.step(w, "choose", "warm-white", 0, true), "Colour failed")
	-- Server-state fixture: score is derived from cells, never from a client score.
	for i = 1, count do
		w.cells[i] = true
	end
	w.count = count
	assert(Painting.step(w, "review", nil, 20, true), "Review failed")
	assert(Jobs.submit(p, w, 21, true), "Valid job not paid")
	return p, w
end
local p, w = complete(77)
local summary = Result.read(p)
assert(p.schemaVersion == 3 and summary and summary.finish, "Confirmed finish was not recorded")
assert(
	summary.finish.masks[1] == string.rep("1", 77) .. string.rep("0", 19),
	"Wrong saved server mask"
)
local loaded = Profile.decode(p, 1)
assert(
	loaded and Result.read(loaded) and loaded.jobs.active and loaded.jobs.active.finish,
	"Reload lost finish"
)
w.count, w.cells = 96, {}
assert(Jobs.submit(p, w, 22, true) and p.wallet.dollars == 250, "Replay paid again")
local repeated = Result.read(p)
assert(
	repeated and repeated.finish and repeated.finish.masks[1] == summary.finish.masks[1],
	"Replay rescored completed job"
)
summary.finish.masks[1] = string.rep("1", 96)
local independent = Result.read(p)
assert(
	independent and independent.finish and independent.finish.masks[1] ~= summary.finish.masks[1],
	"Result aliases profile masks"
)
local legacy = Profile.copy(p)
legacy.schemaVersion = 2
assert(legacy.jobs.active, "Missing job")
assert(Profile.decode(legacy, 1) == nil, "V2 unexpectedly carried new-schema finish fields")
legacy.jobs.active.finish = nil
local migrated = Profile.decode(legacy, 1)
assert(
	migrated and migrated.schemaVersion == 3 and migrated.wallet.dollars == 250,
	"V2 migration lost money"
)
local oldResult = Result.read(migrated)
assert(oldResult and oldResult.finish == nil, "Legacy receipt invented coverage")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
assert(
	Economy.purchase(legacy, "buy-legacy", "floor-plant-v1", "legacy-plant", 22),
	"Legacy fixture purchase failed"
)
assert(
	Furniture.place(legacy, "legacy-plant", { x = 8, z = 6, rotationY = 345, mode = "Free" }, 0),
	"Legacy fixture placement failed"
)
local furnished = Profile.decode(legacy, 1)
assert(
	furnished
		and furnished.schemaVersion == 3
		and furnished.wallet.dollars == 70
		and furnished.progression.paintingXP == 50
		and furnished.inventory["legacy-plant"]
		and furnished.housing.placements["legacy-plant"].rotationY == 345,
	"V2 migration lost ownership, money, XP or pose"
)
for _, bad in { "x", string.rep("1", 95), string.rep("1", 97) } do
	local broken = Profile.copy(p)
	assert(broken.jobs.active and broken.jobs.active.finish, "Finish missing")
	broken.jobs.active.finish.masks[1] = bad
	assert(Profile.decode(broken, 1) == nil, "Corrupt mask loaded")
end
local wrongPhase = Profile.copy(p)
assert(wrongPhase.jobs.active, "Missing job")
wrongPhase.jobs.active.status = "Accepted"
wrongPhase.jobs.active.receipt = nil
assert(Profile.decode(wrongPhase, 1) == nil, "Unpaid job carried a completed finish")
print(
	"PaintFinishPersistence: atomic reward/finish, replay, isolation, legacy migration and corruption passed"
)

local Store = require("../src/server/Domain/ProfileStore")
local saved: unknown = nil
local uncertain = false
local clock = 100
local adapter: Store.Adapter = {
	update = function(_, transform)
		local nextValue = transform(saved)
		if nextValue then
			saved = nextValue
		end
		if uncertain then
			uncertain = false
			return false, nil
		end
		return true, nextValue
	end,
}
local session = Store.new(adapter, 1, "quality-server", function()
	return clock
end, 60)
assert(session.load(), "Store fixture load failed")
assert(
	session.transact(function(candidate)
		return Jobs.accept(candidate, "finish", "paint-tutorial-v1")
	end),
	"Store accept failed"
)
local _, ready = complete(77)
uncertain = true
assert(not session.transact(function(candidate)
	return Jobs.submit(candidate, ready, 120, true)
end), "Unknown result reported confirmed")
local beforeRetry = session.read()
assert(
	beforeRetry == nil and session.status() == "Uncertain",
	"Unknown write displayed a grade/reward"
)
ready.cells, ready.count = {}, 96
assert(session.retry(), "Same-intent retry failed")
assert(session.close(), "Store release failed")
local rejoin = Store.new(adapter, 1, "quality-new-server", function()
	return clock
end, 60)
assert(rejoin.load(), "Store reload failed")
local confirmed = rejoin.read()
assert(confirmed and confirmed.wallet.dollars == 250, "Unknown retry paid twice")
local restored = Result.read(confirmed)
assert(
	restored
		and restored.finish
		and restored.finish.masks[1] == string.rep("1", 77) .. string.rep("0", 19),
	"Unknown retry/reload rescored or lost the original finish"
)
assert(rejoin.close(), "Reload release failed")
print(
	"PaintFinishPersistence: uncertain atomic write/retry/release/reload preserved reward and original mask"
)
