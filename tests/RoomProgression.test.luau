--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Painting = require("../src/server/Domain/Painting")
local PaintConfig = require("../src/shared/PaintConfig")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local Store = require("../src/server/Domain/ProfileStore")
local Plan = require("../src/shared/HomePlan")
local saved: unknown = nil
local clock = 1000
local adapter: Store.Adapter = {
	update = function(_key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local value = transform(saved)
		if value ~= nil then
			saved = value
		end
		return true, value
	end,
}
local session = Store.new(adapter, 201, "natural-1", function(): number
	return clock
end, 60)
assert(session.load(), "Natural progression profile did not load")
local function read(): Profile.Profile
	local p = session.read()
	assert(p, "No confirmed progression profile")
	return p
end
local function plan(p: Profile.Profile): Plan.Progress
	local items: { Plan.Item } = {}
	for id, item in p.inventory do
		table.insert(items, {
			id = id,
			catalogId = item.catalogItemId,
			purchaseOperationId = item.purchaseOperationId,
			placed = p.housing.placements[id],
		})
	end
	return Plan.evaluate(items)
end
local function paint(work: Painting.State, color: string, base: number): ()
	if work.phase == "Inspect" then
		assert(Painting.step(work, "inspect", nil, base, true))
		assert(Painting.step(work, "prepare", nil, base, true))
	end
	assert(Painting.step(work, "choose", color, base, true))
	for row = 0, 7 do
		local points = {}
		for col = 0, 11 do
			table.insert(points, { u = (col + 0.5) / 12, v = (row + 0.5) / 8 })
		end
		assert(Painting.batch(work, row + 1, points, true, base + (row + 1) * 2, true))
	end
	assert(Painting.step(work, "review", nil, base + 25, true), "Natural wall failed review")
end
type Purchase = { catalog: string, x: number, z: number, rotation: number }
type Stage = {
	id: string,
	color: string,
	secondary: string?,
	reward: number,
	xp: number,
	remaining: number,
	placed: number,
	buys: { Purchase },
}
local stages: { Stage } = {
	{
		id = "paint-tutorial-v1",
		color = "warm-white",
		reward = 250,
		xp = 50,
		remaining = 70,
		placed = 1,
		buys = { { catalog = "floor-plant-v1", x = 8, z = 6, rotation = 0 } },
	},
	{
		id = "paint-mint-v1",
		color = "mint",
		reward = 300,
		xp = 120,
		remaining = 50,
		placed = 2,
		buys = { { catalog = "reading-chair-v1", x = -6, z = 4, rotation = 0 } },
	},
	{
		id = "paint-rose-v1",
		color = "rose",
		reward = 350,
		xp = 210,
		remaining = 60,
		placed = 4,
		buys = {
			{ catalog = "side-table-v1", x = 9, z = 3, rotation = 0 },
			{ catalog = "floor-lamp-v1", x = 12, z = 3, rotation = 0 },
		},
	},
	{
		id = "paint-duo-v1",
		color = "mint",
		secondary = "rose",
		reward = 550,
		xp = 330,
		remaining = 330,
		placed = 5,
		buys = { { catalog = "bookcase-v1", x = 7, z = -2, rotation = 90 } },
	},
}
assert(
	read().wallet.dollars == 0 and not Plan.isComplete(plan(read())),
	"Natural cycle did not start empty"
)
for index, stage in stages do
	local jobId, base = "natural-job-" .. index, index * 100
	local before = read().wallet.dollars
	assert(
		session.transact(function(p: Profile.Profile): boolean
			return Jobs.accept(p, jobId, stage.id)
		end),
		"Natural XP gate blocked next contract"
	)
	local work = Painting.new(
		jobId,
		jobId .. "-wall1",
		base,
		PaintConfig,
		{ primary = stage.color, secondary = stage.secondary }
	)
	paint(work, stage.color, base)
	if stage.secondary then
		assert(not session.transact(function(p: Profile.Profile): boolean
			return Jobs.submit(p, work, base + 26, true)
		end), "Duo paid before second wall")
		assert(read().wallet.dollars == before, "First wall paid partial reward")
		assert(
			Painting.nextSurface(work, jobId .. "-wall2", base + 26),
			"Natural duo did not advance"
		)
		paint(work, stage.secondary, base + 28)
	end
	assert(
		session.transact(function(p: Profile.Profile): boolean
			return Jobs.submit(p, work, base + 60, true)
		end),
		"Natural order did not pay"
	)
	assert(
		read().wallet.dollars == before + stage.reward and read().progression.paintingXP == stage.xp,
		"Natural reward or XP wrong"
	)
	assert(
		session.transact(function(p: Profile.Profile): boolean
			return Jobs.submit(p, work, base + 61, true)
		end),
		"Reward replay was not recognised"
	)
	assert(read().wallet.dollars == before + stage.reward, "Repeated submit paid twice")
	for _, buy in stage.buys do
		local request, item = "buy:" .. buy.catalog, "owned:" .. buy.catalog
		local oldCount = plan(read()).placed
		assert(
			session.transact(function(p: Profile.Profile): boolean
				return Economy.purchase(p, request, buy.catalog, item, base + 62) ~= nil
			end),
			"Earned money cannot buy planned item"
		)
		assert(plan(read()).placed == oldCount, "Purchase alone completed a room requirement")
		assert(
			session.transact(function(p: Profile.Profile): boolean
				local ok = Furniture.place(
					p,
					item,
					{ x = buy.x, z = buy.z, rotationY = buy.rotation, mode = "Grid" },
					p.housing.revision
				)
				return ok
			end),
			"Natural furniture pose rejected"
		)
	end
	assert(
		read().wallet.dollars == stage.remaining and plan(read()).placed == stage.placed,
		"Natural home milestone wrong"
	)
	assert(session.close(), "Natural session release failed")
	clock += 1
	session = Store.new(adapter, 201, "natural-" .. (index + 1), function(): number
		return clock
	end, 60)
	assert(session.load(), "Natural session reload failed")
	assert(
		read().wallet.dollars == stage.remaining
			and read().progression.paintingXP == stage.xp
			and plan(read()).placed == stage.placed,
		"Natural milestone changed on memory reload"
	)
end
local final = read()
assert(
	Plan.isComplete(plan(final))
		and final.wallet.dollars == 330
		and final.progression.paintingXP == 330
		and final.jobs.completedCount == 4,
	"Full natural room loop incomplete"
)
local count = 0
for _ in final.inventory do
	count += 1
end
assert(count == 5, "Natural purchases duplicated inventory")
assert(
	session.transact(function(p: Profile.Profile): boolean
		local ok = Furniture.store(p, "owned:bookcase-v1", p.housing.revision)
		return ok
	end),
	"Completed room could not store item"
)
assert(
	not Plan.isComplete(plan(read())) and read().wallet.dollars == 330,
	"Storage preserved false completion or changed balance"
)
assert(
	session.transact(function(p: Profile.Profile): boolean
		local ok = Furniture.place(
			p,
			"owned:bookcase-v1",
			{ x = 7, z = -2, rotationY = 90, mode = "Grid" },
			p.housing.revision
		)
		return ok
	end),
	"Owned bookcase could not be restored"
)
assert(
	Plan.isComplete(plan(read())) and read().wallet.dollars == 330,
	"Restoring room charged or failed"
)
assert(session.close(), "Final natural session close failed")
print(
	"RoomProgression: $0, four real contracts/five walls, $1450 rewards/$1120 furniture, $330/330 XP, five placements and memory reloads passed"
)
