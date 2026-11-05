--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local Config = require("../src/shared/PaintConfig")
local Economy = require("../src/server/Domain/EconomyConfig")
local Mastery = require("../src/shared/PaintingMastery")
local Result = require("../src/server/Domain/JobResult")
local p = Profile.new(1)
assert(#Jobs.offers(p) == 6, "Campaign still ends at four contracts")
for _, row in { { "paint-sunroom-v1", 330 }, { "paint-atelier-v1", 470 } } do
	local id, xp = tostring(row[1]), tonumber(row[2]) or 0
	p.progression.paintingXP = xp - 1
	assert(not Jobs.accept(p, "locked", id), "New contract ignored XP boundary")
	p.progression.paintingXP = xp
	assert(Jobs.accept(p, "unlocked-" .. id, id), "Exact boundary remained locked")
	assert(Jobs.cancel(p, "unlocked-" .. id), "Boundary fixture did not cancel")
end
p = Profile.new(2)
local function wall(w: Painting.State, color: string, at: number): ()
	if w.phase == "Inspect" then
		assert(Painting.step(w, "inspect", nil, at, true), "Inspect failed")
		assert(Painting.step(w, "prepare", nil, at, true), "Prepare failed")
	end
	assert(Painting.step(w, "choose", color, at, true), "Material failed")
	for r = 0, 7 do
		local points = {}
		for c = 0, 11 do
			table.insert(points, { u = (c + 0.5) / 12, v = (r + 0.5) / 8 })
		end
		assert(Painting.batch(w, r + 1, points, true, at + (r + 1) * 2, true), "Stroke failed")
	end
	assert(Painting.step(w, "review", nil, at + 25, true), "Review failed")
end
local order = {
	"paint-tutorial-v1",
	"paint-mint-v1",
	"paint-rose-v1",
	"paint-duo-v1",
	"paint-sunroom-v1",
	"paint-atelier-v1",
}
local totals = { 50, 120, 210, 330, 470, 630 }
for index, id in order do
	local jobId = "campaign-" .. index
	assert(Jobs.accept(p, jobId, id), "Natural campaign gate failed")
	local contract = Economy.contracts[id]
	local w = Painting.new(
		jobId,
		"work-a",
		0,
		Config,
		{ primary = contract.colorId, secondary = contract.secondaryColorId }
	)
	wall(w, contract.colorId, 0)
	if contract.secondaryColorId then
		local dollars = p.wallet.dollars
		assert(
			not Jobs.submit(p, w, 26, true) and p.wallet.dollars == dollars,
			"First wall paid full contract"
		)
		assert(Painting.nextSurface(w, "work-b", 26), "Next wall failed")
		wall(w, contract.secondaryColorId, 27)
	end
	assert(Jobs.submit(p, w, 60, true), "Whole contract did not pay")
	local before = p.wallet.dollars
	assert(
		Jobs.submit(p, w, 61, true) and p.wallet.dollars == before,
		"Repeated contract paid again"
	)
	assert(p.progression.paintingXP == totals[index], "Natural XP progression changed")
	local loaded = Profile.decode(p, 2)
	assert(loaded, "Campaign profile did not reload")
	p = loaded
	local receipt = Result.read(p)
	assert(
		receipt
			and receipt.finish
			and #receipt.finish.masks == (if contract.secondaryColorId then 2 else 1),
		"Reload lost completed walls"
	)
	if index == 4 or index == 5 then
		local offers: { Mastery.Offer } = {}
		for _, offer in Jobs.offers(p) do
			table.insert(offers, {
				id = offer.id,
				titleKey = offer.titleKey,
				briefKey = offer.briefKey,
				clientKey = offer.clientKey,
				colorId = offer.colorId,
				secondaryColorId = offer.secondaryColorId,
				requiredXP = offer.requiredXP,
				reward = offer.reward,
				xp = offer.xp,
				unlocked = offer.unlocked,
			})
		end
		local progress =
			Mastery.evaluate(p.progression.paintingXP, offers, true, Economy.rewards[id].xp)
		assert(
			progress.ready
				and progress.nextId == order[index + 2]
				and progress.recommendedId == order[index + 1],
			"New unlock or following goal missing"
		)
	end
end
assert(
	p.wallet.dollars == 2700 and p.progression.paintingXP == 630 and p.jobs.completedCount == 6,
	"Six-contract campaign totals changed"
)
assert(not Jobs.offers(Profile.new(3))[5].unlocked, "New unlock crossed players")
print(
	"ExtendedContracts: exact gates, six natural jobs/nine walls, one payout, replay, reload, masks and next goals passed"
)
