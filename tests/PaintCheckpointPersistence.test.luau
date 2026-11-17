--!strict
local Profile = require("../src/server/Domain/Profile")
local Store = require("../src/server/Domain/ProfileStore")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local Result = require("../src/server/Domain/JobResult")
local Config = require("../src/shared/PaintConfig")
local Geometry = require("../src/shared/PaintGeometry")

local templateId = "paint-duo-v1"
local record: { [string]: unknown } = {}
local loseReply = false
local writes = 0
local adapter: Store.Adapter = {
	update = function(key, transform)
		local updated = transform(record[key])
		if updated ~= nil then
			record[key] = updated
			writes += 1
		end
		if loseReply then
			loseReply = false
			return false, nil
		end
		return true, updated
	end,
}
local function connect(token: string): Store.Session
	local session = Store.new(adapter, 42, token, function(): number
		return 100
	end, 120)
	assert(session.load(), "Profile did not load")
	return session
end
local function checkpoint(p: Profile.Profile): Profile.PaintFinish
	local job = p.jobs.active
	assert(job and job.checkpoint, "Checked walls are missing")
	return job.checkpoint
end
local function makeWork(id: string): Painting.State
	return Painting.new(
		"duo",
		id,
		0,
		Config,
		{ primary = "mint", secondary = "rose" },
		Geometry.layout(templateId),
		true
	)
end
local function paintRows(work: Painting.State, rows: number, start: number): number
	for row = 1, rows do
		local points = {}
		for col = 1, Config.columns do
			table.insert(
				points,
				{ u = (col - 0.5) / Config.columns, v = (row - 0.5) / Config.rows }
			)
		end
		assert(Painting.batch(work, work.seq + 1, points, true, start + row * 2, true))
	end
	return start + rows * 2
end

local first = connect("first")
assert(first.transact(function(p)
	p.progression.paintingXP, p.progression.xp = 210, 210
	return Jobs.accept(p, "duo", templateId)
end))
local initial = assert(first.read())
local wallA = makeWork("first-character")
assert(Painting.step(wallA, "inspect", nil, 0, true))
for i = 1, 3 do
	assert(Painting.beginPreparation(wallA, i, i * 2, true))
	assert(Painting.finishPreparation(wallA, i, i * 2 + 1, true))
end
assert(Painting.step(wallA, "prepare", nil, 8, true))
assert(Painting.step(wallA, "choose", "mint", 8, true))
assert(not Jobs.checkpoint(initial, wallA, 10), "Empty wall accepted")
local checkedAt = paintRows(wallA, 7, 8)
assert(wallA.count == 84, "Fixture did not leave real unpainted cells")
local mintMask = Painting.mask(wallA)
local characterValid = true
local countBefore = writes
loseReply = true
assert(not first.transact(function(p)
	return Jobs.checkpoint(p, wallA, checkedAt)
end, function()
	return characterValid
end), "Lost storage reply was reported as success")
assert(first.read() == nil and first.status() == "Uncertain", "Unconfirmed progress leaked")
characterValid = false
assert(wallA.phase == "Painting" and first.retry(), "Existing commit failed to resolve after reset")
assert(writes == countBefore + 2, "Resolution did not use exactly one write and an acknowledgement")
local saved = assert(first.read())
assert(
	saved.wallet.dollars == 0 and #saved.recentOperations == 0 and Result.read(saved) == nil,
	"A checkpoint changed the balance or created a receipt"
)
assert(
	#checkpoint(saved).masks == 1 and checkpoint(saved).masks[1] == mintMask,
	"The first confirmed mask was not saved"
)
assert(not Jobs.checkpoint(saved, wallA, checkedAt), "Same surface created another checkpoint")
local canceled = Profile.copy(saved)
assert(
	Jobs.cancel(canceled, "duo") and canceled.jobs.active and canceled.jobs.active.checkpoint == nil,
	"Cancel did not clear checked walls"
)
assert(
	Profile.decode(canceled, 42) and canceled.wallet.dollars == 0,
	"Cancel kept a payable checkpoint"
)
local corrupt = Profile.copy(saved)
checkpoint(corrupt).masks[1] = "bad mask"
assert(Profile.decode(corrupt, 42) == nil, "Corrupted checkpoint passed schema validation")
local invalid = Profile.copy(saved)
checkpoint(invalid).masks[1] = string.rep("0", 96)
local fresh = makeWork("fresh-before-first-wall")
assert(
	not Painting.restore(fresh, checkpoint(invalid)) and fresh.phase == "Inspect",
	"Invalid checkpoint changed live work"
)
assert(first.close())

local second = connect("second")
local restoredA = makeWork("second-character")
assert(Painting.restore(restoredA, checkpoint(assert(second.read()))))
assert(
	restoredA.phase == "Ready" and restoredA.count == 84 and restoredA.seq == 0,
	"First checked wall did not restore"
)
assert(
	Painting.mask(restoredA) == mintMask and Painting.preparedCount(restoredA) == 3,
	"Restored wall has the wrong phase, count or sequence"
)
assert(not Jobs.submit(assert(second.read()), restoredA, 20, true), "One wall generated a payment")
assert(Painting.nextSurface(restoredA, "second-wall", 1))
assert(Painting.step(restoredA, "choose", "rose", 2, true))
local checkedBAt = paintRows(restoredA, 8, 2)
restoredA.completedMasks[1] = string.rep("1", 96)
assert(
	not Jobs.checkpoint(assert(second.read()), restoredA, checkedBAt),
	"Changed first mask replaced a confirmed wall"
)
restoredA.completedMasks[1] = mintMask
assert(not second.transact(function(p)
	return Jobs.checkpoint(p, restoredA, checkedBAt)
end, function()
	return false
end), "A late check from a dead character wrote progress")
assert(#checkpoint(assert(second.read())).masks == 1, "Rejected write replaced the first wall")
assert(second.transact(function(p)
	return Jobs.checkpoint(p, restoredA, checkedBAt)
end))
assert(second.close())

local third = connect("third")
local ready = makeWork("third-character")
assert(Painting.restore(ready, checkpoint(assert(third.read()))))
assert(
	Painting.allReady(ready) and Painting.surface(ready) == 2 and ready.config.colorId == "rose",
	"Reload did not restore the final surface"
)
assert(
	ready.completedMasks[1] == mintMask and ready.count == 96,
	"Restored surfaces lost their confirmed coverage"
)
assert(third.transact(function(p)
	return Jobs.submit(p, ready, 130, true)
end))
assert(
	third.transact(function(p)
		return Jobs.submit(p, ready, 131, true)
	end),
	"Replayed submission did not confirm the first payment"
)
assert(third.transact(function(p)
	return Economy.purchase(p, "buy-plant", "floor-plant-coral-v1", "plant", 132) ~= nil
end))
assert(third.transact(function(p)
	local placed = Furniture.place(p, "plant", { x = 8, z = 6, rotationY = 45, mode = "Free" }, 0)
	return placed
end))
assert(third.close())

local fourth = connect("fourth")
local final = assert(fourth.read())
local result = assert(Result.read(final))
assert(
	result.finish
		and result.finish.masks[1] == mintMask
		and result.finish.masks[2] == string.rep("1", 96),
	"Submission lost the checked masks"
)
assert(
	result.dollars == 550 and result.perfectBonus == 0 and final.wallet.dollars == 370,
	"Final balance, payout or tip changed"
)
assert(
	final.jobs.active and final.jobs.active.checkpoint == nil and final.jobs.completedCount == 1,
	"Completed order kept its checkpoint or counted twice"
)
assert(
	final.inventory.plant.catalogItemId == "floor-plant-coral-v1",
	"Reload lost the purchased coral finish"
)
assert(
	final.housing.placements.plant.x == 8 and final.housing.placements.plant.rotationY == 45,
	"Reload lost the saved furniture pose"
)
assert(fourth.close())
print(
	"PaintCheckpointPersistence: checked walls, uncertain recovery, rejoin, exactly one reward, purchase and home restore"
)
