--!strict
local Painting = require("../src/server/Domain/Painting")
local Jobs = require("../src/server/Domain/Jobs")
local Profile = require("../src/server/Domain/Profile")
local Config = require("../src/shared/PaintConfig")
local function fresh(id: string): Painting.State
	return Painting.new(id, "wall-first", 0, Config, { primary = "mint", secondary = "rose" })
end
local function paint(s: Painting.State, at: number, color: string, wide: boolean?): ()
	if s.phase == "Inspect" then
		assert(Painting.step(s, "inspect", nil, at, true))
		assert(Painting.step(s, "prepare", nil, at, true))
	end
	if wide then
		assert(Painting.tool(s, "wide", 210), "First wall wide setup failed")
	end
	assert(Painting.step(s, "choose", color, at, true))
	local sequence = 0
	for row = 0, 7 do
		for col = 0, 11 do
			sequence += 1
			assert(
				Painting.batch(
					s,
					sequence,
					{ { u = (col + 0.5) / 12, v = (row + 0.5) / 8 } },
					col == 0,
					at + sequence * 0.5,
					true
				),
				"Normal paced paint stroke failed"
			)
		end
	end
	assert(Painting.step(s, "review", nil, at + 49, true))
end
local p = Profile.new(1)
assert(not Jobs.accept(p, "locked", "paint-duo-v1"), "Two-wall contract ignored XP gate")
p.progression.paintingXP = 209
assert(not Jobs.accept(p, "below-boundary", "paint-duo-v1"), "209 XP unlocked 210 XP contract")
p.progression.paintingXP = 210
assert(Jobs.accept(p, "duo", "paint-duo-v1"))
local s, other = fresh("duo"), fresh("other")
assert(not Painting.nextSurface(s, "too-soon", 1), "Skipped first wall")
paint(s, 0, "mint", true)
assert(s.phase == "Ready" and not Painting.allReady(s), "First wall completed whole project")
assert(not Jobs.submit(p, s, 40, true) and p.wallet.dollars == 0, "First wall paid full reward")
assert(not Painting.nextSurface(s, s.workId, 50), "Reused work nonce")
assert(not Painting.nextSurface(s, "new", 0 / 0), "NaN advance clock")
assert(Painting.nextSurface(s, "wall-second", 50))
assert(
	#s.completedMasks == 1
		and s.count == 0
		and s.seq == 0
		and s.phase == "ChooseMaterial"
		and s.workId == "wall-second"
		and s.toolId == "basic"
		and s.config.rollerRadius == Config.rollerRadius
		and s.completedMasks[1] == string.rep("1", 96),
	"Second wall retained first state"
)
assert(
	s.config.colorId == "rose" and other.config.colorId == "mint" and #other.completedMasks == 0,
	"Walls crossed projects"
)
assert(not Painting.nextSurface(s, "duplicate", 51), "Repeated advance skipped second wall")
assert(not Painting.step(s, "choose", "mint", 51, true), "Wrong second color accepted")
paint(s, 52, "rose")
assert(Painting.allReady(s), "Two verified walls not complete")
assert(not Painting.nextSurface(s, "third", 102), "Unconfigured third wall created")
assert(
	Jobs.submit(p, s, 100, true) and p.wallet.dollars == 550 and p.progression.paintingXP == 330,
	"Whole project reward missing"
)
assert(
	Jobs.submit(p, s, 101, true) and p.wallet.dollars == 550 and p.jobs.completedCount == 1,
	"Repeat paid twice"
)
assert(Profile.decode(p, 1), "Profile schema changed")
local incomplete = fresh("duo")
paint(incomplete, 0, "mint")
assert(not Painting.allReady(incomplete), "Fresh project inherited completion")
local fake = Painting.new("fresh", "fake", 0, Config)
fake.phase = "Ready"
assert(Jobs.accept(p, "fresh", "paint-duo-v1"))
assert(not Jobs.submit(p, fake, 102, true), "Single-wall state paid two-wall template")
assert(Jobs.cancel(p, "fresh") and p.wallet.dollars == 550, "Cancel charged or paid")
print(
	"PaintScope: early submit, XP, next/nonce/color/reset, isolation, complete payout/repeat and template guard passed"
)

-- Confirmed payout survives an ambiguous adapter response; runtime walls are not serialized.
local Store = require("../src/server/Domain/ProfileStore")
local Result = require("../src/server/Domain/JobResult")
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
local session = Store.new(adapter, 3, "duo-old", function(): number
	return 1000
end, 60)
assert(session.load())
assert(session.transact(function(c: Profile.Profile): boolean
	c.progression.paintingXP = 210
	return Jobs.accept(c, "saved-duo", "paint-duo-v1")
end))
local savedWork = fresh("saved-duo")
paint(savedWork, 0, "mint")
assert(not session.transact(function(c: Profile.Profile): boolean
	return Jobs.submit(c, savedWork, 1001, true)
end), "Partial contract persisted payout")
assert(Painting.nextSurface(savedWork, "saved-second", 50))
paint(savedWork, 52, "rose")
local mutations = 0
failAfter = true
assert(not session.transact(function(c: Profile.Profile): boolean
	mutations += 1
	return Jobs.submit(c, savedWork, 1001, true)
end), "Unknown payout acknowledged")
assert(session.read() == nil, "Unknown payout exposed editable profile")
failAfter = false
assert(session.retry() and mutations == 1, "Retry repainted or repeated mutation")
assert(session.close())
local rejoin = Store.new(adapter, 3, "duo-new", function(): number
	return 1002
end, 60)
assert(rejoin.load())
local loaded = rejoin.read()
assert(loaded, "Reload did not expose a confirmed profile")
local receipt = Result.read(loaded)
assert(
	loaded.wallet.dollars == 550
		and loaded.progression.paintingXP == 330
		and receipt
		and receipt.primaryColorId == "mint"
		and receipt.secondaryColorId == "rose",
	"Reload lost whole project result"
)
assert(rejoin.transact(function(c: Profile.Profile): boolean
	return Jobs.submit(c, savedWork, 1003, true)
end))
local repeated = rejoin.read()
assert(
	repeated and repeated.wallet.dollars == 550 and repeated.jobs.completedCount == 1,
	"Reload replay paid twice"
)
print(
	"PaintScope persistence: partial denial, uncertain write, same-intent retry, release/reload and stable two-colour receipt passed"
)

for _, second in { "mint", "", string.rep("x", 33) } do
	local valid = pcall(function(): ()
		Painting.new("bad", "bad", 0, Config, { primary = "mint", secondary = second })
	end)
	assert(not valid, "Invalid second colour accepted")
end
