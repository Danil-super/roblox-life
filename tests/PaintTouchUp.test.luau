--!strict
local Profile = require("../src/server/Domain/Profile")
local Store = require("../src/server/Domain/ProfileStore")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local Result = require("../src/server/Domain/JobResult")
local Config = require("../src/shared/PaintConfig")
local Geometry = require("../src/shared/PaintGeometry")

local contract, jobId = "paint-duo-v1", "duo"
local record: unknown = nil
local loseReply = false
local adapter: Store.Adapter = {
	update = function(_, transform)
		local updated = transform(record)
		if updated ~= nil then
			record = updated
		end
		if loseReply then
			loseReply = false
			return false, nil
		end
		return true, updated
	end,
}
local function connect(token: string): Store.Session
	local session = Store.new(adapter, 42, token, function()
		return 100
	end, 120)
	assert(session.load())
	return session
end
local function work(id: string): Painting.State
	return Painting.new(
		jobId,
		id,
		0,
		Config,
		{ primary = "mint", secondary = "rose" },
		Geometry.layout(contract),
		true
	)
end
local function checkpoint(p: Profile.Profile): Profile.PaintFinish
	local job = p.jobs.active
	assert(job and job.checkpoint)
	return job.checkpoint
end
local function paintRow(w: Painting.State, row: number, time: number): ()
	local points = {}
	for column = 1, Config.columns do
		table.insert(points, {
			u = (column - 0.5) / Config.columns,
			v = (row - 0.5) / Config.rows,
		})
	end
	assert(Painting.batch(w, w.seq + 1, points, true, time, true))
end
local function check(session: Store.Session, w: Painting.State, time: number): boolean
	local ok = session.transact(function(p)
		return Jobs.checkpoint(p, w, time)
	end)
	return ok
end

local first = connect("first")
assert(first.transact(function(p)
	p.progression.xp, p.progression.paintingXP = 210, 210
	return Jobs.accept(p, jobId, contract)
end))
local wallA = work("first-wall")
assert(Painting.step(wallA, "inspect", nil, 0, true))
for i = 1, 3 do
	assert(Painting.beginPreparation(wallA, i, i * 2, true))
	assert(Painting.finishPreparation(wallA, i, i * 2 + 1, true))
end
assert(Painting.step(wallA, "prepare", nil, 8, true))
assert(Painting.step(wallA, "choose", "mint", 8, true))
for row = 1, 7 do
	paintRow(wallA, row, 8 + row * 2)
end
assert(wallA.count == 84 and check(first, wallA, 22))
local partial = Painting.mask(wallA)
local perfect = string.rep("1", 96)
assert(first.close())

local second = connect("second")
local resumed = work("resumed")
local before = checkpoint(assert(second.read()))
assert(Painting.restore(resumed, before) and Painting.canTouchUp(resumed, before))
assert(not Painting.touchUp(resumed, before, resumed.workId, 25))
assert(not Painting.touchUp(resumed, nil, "missing-proof", 25))
assert(not Painting.touchUp(resumed, before, "invalid-time", math.huge))
assert(Painting.touchUp(resumed, before, "fix-first", 25))
assert(resumed.phase == "Painting" and resumed.seq == 0 and resumed.count == 84)
assert(Painting.preparedCount(resumed) == 3 and resumed.config.colorId == "mint")
assert(not Painting.nextSurface(resumed, "early-second-wall", 25))
assert(not Jobs.submit(assert(second.read()), resumed, 150, true), "Touch-up allowed a handover")
assert(not check(second, resumed, 25) and checkpoint(assert(second.read())).masks[1] == partial)
paintRow(resumed, 8, 27)
assert(resumed.count == 96 and Painting.mask(resumed) == perfect)
resumed.cells[1], resumed.count = nil, 95
assert(not check(second, resumed, 27), "An improvement removed confirmed cells")
resumed.cells[1], resumed.count = true, 96
assert(not Jobs.checkpoint(Profile.new(99), resumed, 27), "Different player accepted this work")
assert(check(second, resumed, 27))
local improved = checkpoint(assert(second.read()))
assert(improved.masks[1] == perfect and Painting.restore(resumed, improved))
assert(resumed.touchUpBase == nil and not Painting.canTouchUp(resumed, improved))

assert(Painting.nextSurface(resumed, "second-wall", 28))
assert(Painting.step(resumed, "choose", "rose", 28, true))
for row = 1, 7 do
	paintRow(resumed, row, 28 + row * 2)
end
assert(check(second, resumed, 42))
local beforeSecond = checkpoint(assert(second.read()))
assert(beforeSecond.masks[1] == perfect and beforeSecond.masks[2] == partial)
assert(Painting.restore(resumed, beforeSecond))
assert(Painting.touchUp(resumed, beforeSecond, "fix-second", 43))
paintRow(resumed, 8, 45)
local rejoinBeforeSave = work("fallback")
assert(Painting.restore(rejoinBeforeSave, checkpoint(assert(second.read()))))
assert(rejoinBeforeSave.count == 84 and Painting.mask(rejoinBeforeSave) == partial)
assert(rejoinBeforeSave.completedMasks[1] == perfect and rejoinBeforeSave.phase == "Ready")

resumed.completedMasks[1] = partial
assert(not check(second, resumed, 45), "One wall's touch-up changed a prior wall")
resumed.completedMasks[1] = perfect
loseReply = true
assert(not check(second, resumed, 45) and second.read() == nil)
assert(second.retry() and second.close())

local third = connect("third")
local finished = work("return-to-client")
local stored = assert(third.read())
assert(stored.wallet.dollars == 0 and #stored.recentOperations == 0)
assert(Painting.restore(finished, checkpoint(stored)) and Painting.allReady(finished))
assert(Painting.mask(finished) == perfect and finished.completedMasks[1] == perfect)
assert(third.transact(function(p)
	return Jobs.submit(p, finished, 160, true)
end))
assert(third.transact(function(p)
	return Jobs.submit(p, finished, 161, true)
end))
local paid = assert(third.read())
local result = assert(Result.read(paid))
assert(paid.wallet.dollars == 660 and result.baseDollars == 550 and result.perfectBonus == 110)
assert(#paid.recentOperations == 1 and paid.jobs.completedCount == 1)
assert(result.finish and #result.finish.masks == 2 and result.finish.masks[2] == perfect)
assert(third.close())
print("PaintTouchUp: two real touch-ups, monotonic masks, reliable recovery and one $660 reward")
