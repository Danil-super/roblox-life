--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local Economy = require("../src/server/Domain/Economy")
local Config = require("../src/shared/PaintConfig")
local Pay = require("../src/server/Domain/EconomyConfig")
local Result = require("../src/server/Domain/JobResult")
local function finish(template: string, counts: { number }): (Profile.Profile, Painting.State)
	local p = Profile.new(7)
	p.progression.paintingXP = 1000
	assert(Jobs.accept(p, "job", template))
	local contract = Pay.contracts[template]
	local w = Painting.new(
		"job",
		"work",
		0,
		Config,
		{ primary = contract.colorId, secondary = contract.secondaryColorId }
	)
	assert(Painting.step(w, "inspect", nil, 0, true))
	assert(Painting.step(w, "prepare", nil, 0, true))
	for index, count in counts do
		assert(
			Painting.step(
				w,
				"choose",
				if index == 1 then contract.colorId else contract.secondaryColorId,
				index * 40,
				true
			)
		)
		w.count = count
		for i = 1, 96 do
			w.cells[i] = i <= count
		end
		assert(Painting.step(w, "review", nil, index * 40 + 30, true))
		if index < #counts then
			assert(Painting.nextSurface(w, "work-b", 71))
		end
	end
	assert(Jobs.submit(p, w, 200, true))
	return p, w
end
for _, count in { 96, 77, 92, 95 } do
	local p, w = finish("paint-rose-v1", { count })
	local total = if count == 96 then 420 else 350
	assert(p.wallet.dollars == total, "Perfect finish did not change authoritative pay")
	local r = Result.read(p)
	assert(
		r
			and r.dollars == total
			and r.xp == 90
			and r.perfectBonus == total - 350
			and r.baseDollars == 350,
		"Receipt lost actual bonus breakdown"
	)
	local revision = p.revision
	assert(
		Jobs.submit(p, w, 101, true) and p.wallet.dollars == total and p.revision == revision,
		"Replay paid a new tip"
	)
	local loaded = Profile.decode(p, 7)
	assert(
		loaded and loaded.wallet.dollars == total and loaded.schemaVersion == 3,
		"Tip did not survive existing schema reload"
	)
end
for _, template in { "paint-tutorial-v1", "paint-mint-v1" } do
	local p = finish(template, { 96 })
	assert(p.wallet.dollars == Pay.rewards[template].dollars, "Starter reward changed")
end
for _, second in { 95, 96 } do
	local p = finish("paint-duo-v1", { 96, second })
	assert(
		p.wallet.dollars == (if second == 96 then 660 else 550),
		"A perfect wall hid an unfinished second wall"
	)
end
local p, w = finish("paint-rose-v1", { 96 })
local job = p.jobs.active
assert(job and job.receipt, "Missing completed receipt fixture")
job.receipt.dollarsDelta = 350
p.wallet.dollars = 350
p.recentOperations[1].dollarsDelta = 350
local legacy = Profile.decode(p, 7)
assert(
	legacy and Jobs.submit(legacy, w, 102, true) and legacy.wallet.dollars == 350,
	"Old perfect receipt got retroactive tip"
)
local old = Result.read(legacy)
assert(old and old.perfectBonus == 0, "Old receipt invented a tip")
local capped = Profile.new(8)
capped.progression.paintingXP = 120
assert(Jobs.accept(capped, "cap", "paint-rose-v1"))
assert(capped.jobs.active, "Missing wallet-limit job fixture")
capped.jobs.active.status = "ReadyForInspection"
capped.wallet.dollars = Pay.maxDollars - 419
local before = Profile.copy(capped)
local receipt, reason = Economy.completeJob(capped, "cap", 100, true)
assert(
	not receipt
		and reason == "LimitReached"
		and capped.wallet.dollars == before.wallet.dollars
		and capped.revision == before.revision,
	"Tip overflow partially paid"
)
local offers = Jobs.offers(Profile.new(9))
assert(
	offers[1].perfectBonus == 0 and offers[3].perfectBonus == 70,
	"Offer invented tip or hid advanced tip"
)
print(
	"PerfectTip: actual Jobs pay, 80/95/99/100%, two walls, starters, replay, reload/legacy, limit and offer passed"
)
