--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Economy = require("../src/server/Domain/Economy")
local Config = require("../src/server/Domain/EconomyConfig")
local p, other = Profile.new(1), Profile.new(2)
local offers = Jobs.offers(p)
assert(#offers == 3 and offers[1].id == "paint-tutorial-v1", "Board has no accessible first job")
assert(offers[1].unlocked and not offers[2].unlocked and not offers[3].unlocked, "XP gate ignored")
local revision = p.revision
assert(
	not Jobs.accept(p, "locked", "paint-mint-v1") and p.revision == revision,
	"Locked offer accepted"
)
assert(not Jobs.accept(p, "fake", "missing-offer"), "Unknown offer accepted")
offers[1].reward = 99999
assert(Config.rewards["paint-tutorial-v1"].dollars == 250, "Client projection changed economy")
assert(Jobs.accept(p, "first"), "Tutorial compatibility broken")
local first = p.jobs.active
assert(first ~= nil, "Accepted job missing")
first.status = "ReadyForInspection"
assert(Economy.completeJob(p, first.id, 100) ~= nil, "First reward failed")
assert(p.wallet.dollars == 250 and p.progression.paintingXP == 50, "Tutorial economy changed")
assert(
	Economy.completeJob(p, first.id, 101) ~= nil and p.progression.paintingXP == 50,
	"Duplicate XP reward"
)
local unlocked = Jobs.offers(p)
assert(
	unlocked[2].unlocked and unlocked[2].colorId == "mint" and not unlocked[3].unlocked,
	"First unlock missing"
)
assert(Jobs.accept(p, "second", unlocked[2].id), "Unlocked contract rejected")
local second = p.jobs.active
assert(
	second ~= nil and second.templateId == "paint-mint-v1",
	"Selected contract replaced by tutorial"
)
assert(not Jobs.accept(p, "parallel", "paint-tutorial-v1"), "Two active jobs created")
second.status = "ReadyForInspection"
assert(Economy.completeJob(p, second.id, 102) ~= nil, "Mint reward failed")
assert(
	p.wallet.dollars == 550 and p.progression.paintingXP == 120,
	"Selected reward not authoritative"
)
assert(Jobs.offers(p)[3].unlocked, "Next contract did not unlock")
assert(not Jobs.offers(other)[2].unlocked and other.wallet.dollars == 0, "Progress crossed players")
assert(Config.rewards["paint-room-v1"].dollars == 250, "Legacy reward changed")
print(
	"Contracts: choice, XP unlocks, immutable projection, rewards, repeats and player isolation passed"
)

local Store = require("../src/server/Domain/ProfileStore")
local Painting = require("../src/server/Domain/Painting")
local PaintConfig = require("../src/shared/PaintConfig")
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
local firstSession = Store.new(adapter, 3, "contracts-old", function(): number
	return 1000
end, 60)
assert(firstSession.load(), "Persistence profile did not load")
local function finish(candidate: Profile.Profile, id: string): boolean
	local job = candidate.jobs.active
	if job == nil or job.id ~= id then
		return false
	end
	job.status = "ReadyForInspection"
	return Economy.completeJob(candidate, id, 1001) ~= nil
end
assert(
	firstSession.transact(function(c)
		return Jobs.accept(c, "persist-first")
	end),
	"Persistent tutorial accept failed"
)
assert(
	firstSession.transact(function(c)
		return finish(c, "persist-first")
	end),
	"Persistent first reward failed"
)
assert(
	firstSession.transact(function(c)
		return Jobs.accept(c, "persist-mint", "paint-mint-v1")
	end),
	"Persistent mint accept failed"
)
local mutations = 0
failAfter = true
assert(not firstSession.transact(function(c)
	mutations += 1
	return finish(c, "persist-mint")
end), "Unknown mint write acknowledged")
assert(firstSession.read() == nil, "Unknown mint payout exposed editable data")
failAfter = false
assert(firstSession.retry() and mutations == 1, "Mint payout mutation repeated during retry")
assert(firstSession.close(), "Persistent session did not release lease")
local secondSession = Store.new(adapter, 3, "contracts-new", function(): number
	return 1002
end, 60)
assert(secondSession.load(), "Persistent profile did not reload")
local loaded = secondSession.read()
assert(
	loaded and loaded.wallet.dollars == 550 and loaded.progression.paintingXP == 120,
	"Contract money/XP lost on memory reload"
)
assert(Jobs.offers(loaded)[3].unlocked, "Saved progression did not unlock rose")
local tool = Painting.new("saved-tool", "saved-work", 100, PaintConfig)
assert(
	Painting.step(tool, "inspect", nil, 100, true)
		and Painting.step(tool, "prepare", nil, 100, true),
	"Saved tool preparation failed"
)
assert(
	Painting.tool(tool, "wide", loaded.progression.paintingXP),
	"Saved XP did not unlock wide roller"
)
assert(
	secondSession.transact(function(c)
		return Economy.completeJob(c, "persist-mint", 1003) ~= nil
	end),
	"Receipt retry failed after reload"
)
local repeated = secondSession.read()
assert(
	repeated and repeated.wallet.dollars == 550 and repeated.progression.paintingXP == 120,
	"Reloaded mint receipt paid twice"
)
print(
	"Contracts persistence: unknown payout, exact retry, release/reload, tool unlock and no duplicate XP passed"
)
