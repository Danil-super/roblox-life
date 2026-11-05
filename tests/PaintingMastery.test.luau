--!strict
local Mastery = require("../src/shared/PaintingMastery")
local Types = require("../src/shared/JobTypes")
local function offers(xp: number): { Types.Offer }
	local out: { Types.Offer } = {}
	for _, row in { { "tutorial", 0 }, { "mint", 50 }, { "rose", 120 }, { "duo", 210 } } do
		local id, threshold = tostring(row[1]), tonumber(row[2]) or 0
		table.insert(out, {
			id = id,
			titleKey = id,
			briefKey = "brief",
			colorId = "mint",
			requiredXP = threshold,
			unlocked = xp >= threshold,
			reward = 250,
			xp = 50,
		})
	end
	return out
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.00001
end
for _, case in
	{
		{ 0, 50, 0, "mint", "tutorial" },
		{ 49, 1, 0.98, "mint", "tutorial" },
		{ 50, 70, 0, "rose", "mint" },
		{ 119, 1, 69 / 70, "rose", "mint" },
		{ 120, 90, 0, "duo", "rose" },
		{ 209, 1, 89 / 90, "duo", "rose" },
	}
do
	local xp = tonumber(case[1]) or 0
	local p = Mastery.evaluate(xp, offers(xp), true, nil)
	assert(
		p.ready and p.needed == case[2] and near(p.fraction, tonumber(case[3]) or 0),
		"Wrong milestone progress"
	)
	assert(p.nextId == case[4] and p.recommendedId == case[5], "Wrong next/recommended offer")
end
local first = Mastery.evaluate(50, offers(50), true, 50)
assert(
	first.wide and first.wideJustUnlocked and #first.opened == 1 and first.opened[1].id == "mint",
	"First reward unlocks missing"
)
local second = Mastery.evaluate(120, offers(120), true, 70)
assert(
	not second.wideJustUnlocked and #second.opened == 1 and second.opened[1].id == "rose",
	"Unlock replayed/missed"
)
local last = Mastery.evaluate(210, offers(210), true, 90)
assert(
	last.ready
		and last.nextId == nil
		and last.fraction == 1
		and #last.opened == 1
		and last.opened[1].id == "duo",
	"Final threshold did not open exactly the last contract"
)
local all = Mastery.evaluate(330, offers(330), true, 120)
assert(
	all.ready
		and all.nextId == nil
		and all.openCount == 4
		and all.total == 4
		and all.fraction == 1
		and all.recommendedId == "duo",
	"All-open state invented another tier"
)
assert(#all.opened == 0 and not all.wideJustUnlocked, "Already open milestone replayed")
local lag = offers(50)
lag[2].unlocked = false
assert(not Mastery.evaluate(50, lag, true, 50).ready, "XP overrode server availability")
local duplicate = offers(50)
duplicate[2].id = duplicate[1].id
assert(not Mastery.evaluate(50, duplicate, true, 50).ready, "Duplicate offer IDs accepted")
local malformed = offers(50)
malformed[2].requiredXP = 0 / 0
assert(not Mastery.evaluate(50, malformed, true, 50).ready, "Invalid threshold accepted")
assert(not Mastery.evaluate(0, {}, true, nil).ready, "Empty offers invented progress")
for _, xp in { -1, 0.5, 0 / 0, math.huge } do
	assert(not Mastery.evaluate(xp, offers(0), true, nil).ready, "Invalid XP displayed progress")
end
assert(
	not Mastery.evaluate(nil, offers(0), true, nil).ready
		and not Mastery.evaluate(50, nil, true, nil).ready,
	"Missing snapshot invented progress"
)
assert(not Mastery.evaluate(50, offers(50), false, 50).ready, "Busy profile displayed unlock")
for _, gained in { -1, 51, 0.5, math.huge } do
	local p = Mastery.evaluate(50, offers(50), true, gained)
	assert(
		p.ready and #p.opened == 0 and not p.wideJustUnlocked,
		"Invalid reward invented new unlock"
	)
end
local input = offers(120)
local a = Mastery.evaluate(120, input, true, 70)
local b = Mastery.evaluate(0, offers(0), true, nil)
a.opened[1].titleKey = "changed"
assert(
	input[1].id == "tutorial" and input[3].titleKey == "rose" and b.recommendedId == "tutorial",
	"Projection mutated offers or leaked between players"
)
print(
	"PaintingMastery: thresholds, server flags, new unlocks, all-open, malformed/busy and isolation passed"
)
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Strings = require("../src/shared/Strings")
local profile = Profile.new(101)
profile.progression.paintingXP = 120
local clientOffers: { Types.Offer } = {}
for _, o in Jobs.offers(profile) do
	table.insert(clientOffers, {
		id = o.id,
		titleKey = o.titleKey,
		briefKey = o.briefKey,
		colorId = o.colorId,
		requiredXP = o.requiredXP,
		unlocked = o.unlocked,
		reward = o.reward,
		xp = o.xp,
		clientKey = o.clientKey,
		secondaryColorId = o.secondaryColorId,
	})
end
local projected = Mastery.evaluate(120, clientOffers, true, 70)
assert(
	projected.nextId == "paint-duo-v1" and projected.nextTitleKey == "contractDuoShort",
	"Real server contract projection incompatible"
)
for _, language in { "en", "ru" } do
	local text = Mastery.goalText(projected, language)
	assert(
		text:find("90", 1, true) and text:find(Strings.text(language, "contractDuoShort"), 1, true),
		"Localized next goal missing"
	)
	assert(
		Mastery.goalText(Mastery.evaluate(nil, nil, false, nil), language)
			== Strings.text(language, "offerWaiting"),
		"Unavailable text invented a goal"
	)
end
assert(
	profile.progression.paintingXP == 120 and profile.wallet.dollars == 0,
	"Projection changed real profile"
)
print("PaintingMastery: actual server offers, short dual-wall title and EN/RU passed")
