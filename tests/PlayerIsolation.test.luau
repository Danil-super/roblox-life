--!strict
-- Two real coordinators share one deterministic adapter; this is not a Studio multi-client test.
local Store = require("../src/server/Domain/ProfileStore")
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local records: { [string]: unknown } = {}
local uncertainKey: string? = nil
local adapter: Store.Adapter = {
	update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local result = transform(records[key])
		if result ~= nil then
			records[key] = result
		end
		return key ~= uncertainKey, result
	end,
}
local function session(userId: number, token: string): Store.Session
	return Store.new(adapter, userId, token, function(): number
		return 100
	end, 60)
end
local function read(s: Store.Session): Profile.Profile
	local p = s.read()
	assert(p, "Expected a confirmed profile")
	return p
end
local function settle(p: Profile.Profile): boolean
	local job = p.jobs.active
	assert(job, "Fixture requires an accepted job")
	-- Isolate payment/persistence; painting acceptance has separate domain and Play tests.
	job.status = "ReadyForInspection"
	return Economy.completeJob(p, job.id, 100) ~= nil
end
local a, b = session(11, "session-a"), session(22, "session-b")
assert(a.load() and b.load(), "Players could not independently acquire profiles")
assert(read(a).userId == 11 and read(b).userId == 22, "Owner keys mixed")
assert(read(a).wallet.dollars == 0 and read(b).wallet.dollars == 0, "Fresh wallets not empty")
for _, s in { a, b } do
	assert(
		s.transact(function(p: Profile.Profile): boolean
			return Jobs.accept(p, "same-job-id")
		end),
		"Job identity should be scoped to the owning profile"
	)
end
assert(a.transact(settle), "First player's payment failed")
local bj = read(b).jobs.active
assert(
	bj and bj.status == "Accepted" and read(b).wallet.dollars == 0,
	"Payment changed another job/wallet"
)
assert(b.transact(settle), "Second player's payment failed")
for index, s in { a, b } do
	assert(
		s.transact(function(p: Profile.Profile): boolean
			return Economy.purchase(p, "same-request-id", "floor-plant-v1", "item-" .. index, 100)
				~= nil
		end),
		"Independent purchase failed"
	)
end
assert(
	read(a).wallet.dollars == 70 and read(b).wallet.dollars == 70,
	"Payment IDs leaked across users"
)
assert(
	read(a).inventory["item-2"] == nil and read(b).inventory["item-1"] == nil,
	"Ownership leaked"
)
uncertainKey = "player:11"
local mutations = 0
assert(not a.transact(function(p: Profile.Profile): boolean
	mutations += 1
	local accepted =
		Furniture.place(p, "item-1", { x = 5, z = 3, rotationY = 15, mode = "Free" }, 0)
	return accepted
end), "Unknown write should not acknowledge")
assert(a.read() == nil and a.status() == "Uncertain", "Unconfirmed state escaped")
assert(
	b.transact(function(p: Profile.Profile): boolean
		local accepted =
			Furniture.place(p, "item-2", { x = 8, z = 3, rotationY = 90, mode = "Grid" }, 0)
		return accepted
	end),
	"One uncertain profile blocked the other player"
)
assert(
	read(b).housing.revision == 1 and read(b).wallet.dollars == 70,
	"Independent placement changed money"
)
uncertainKey = nil
assert(a.retry() and mutations == 1, "Recovery reran the original mutation")
assert(
	read(a).housing.placements["item-1"].x == 5 and read(b).housing.placements["item-2"].x == 8,
	"Retry mixed poses"
)
local revision = read(a).revision
assert(not a.transact(function(p: Profile.Profile): boolean
	local accepted = Furniture.place(p, "item-2", { x = 5, z = 3, rotationY = 0, mode = "Grid" }, 1)
	return accepted
end), "Another player's item was placed")
assert(
	read(a).revision == revision and read(b).housing.revision == 1,
	"Foreign placement mutated data"
)
for _, s in { a, b } do
	assert(
		s.transact(function(p: Profile.Profile): boolean
			return Economy.purchase(p, "same-request-id", "floor-plant-v1", "replay-item", 101)
				~= nil
		end),
		"Repeated purchase did not acknowledge"
	)
	assert(
		s.transact(function(p: Profile.Profile): boolean
			return Economy.completeJob(p, "same-job-id", 101) ~= nil
		end),
		"Repeated payment did not acknowledge"
	)
	assert(
		read(s).wallet.dollars == 70 and read(s).inventory["replay-item"] == nil,
		"Replay created money/items"
	)
end
local blocked = session(11, "other-a-session")
assert(not blocked.load() and blocked.read() == nil, "Foreign session took a live lease")
assert(
	b.renew() and read(b).wallet.dollars == 70,
	"One user's locked session blocked another renewal"
)
assert(a.close(), "First player could not release their lease")
assert(
	b.transact(function(p: Profile.Profile): boolean
		local accepted = Furniture.store(p, "item-2", 1)
		return accepted
	end),
	"Other player could not store after first player left"
)
local returned = session(11, "returned-a")
assert(returned.load(), "First player's profile did not reload")
assert(
	read(returned).housing.placements["item-1"].x == 5 and read(returned).wallet.dollars == 70,
	"Reload lost owner's data"
)
assert(
	next(read(b).housing.placements) == nil
		and read(b).inventory["item-2"] ~= nil
		and read(b).wallet.dollars == 70,
	"Other player's store crossed profile keys"
)
local copy = read(returned)
copy.wallet.dollars = 999
copy.housing.placements["item-1"].x = 999
assert(
	read(returned).wallet.dollars == 70 and read(returned).housing.placements["item-1"].x == 5,
	"Read leaked mutable state"
)
assert(read(b).wallet.dollars == 70, "Another player received a mutable state alias")
print(
	"PlayerIsolation: reward/purchase IDs, ownership, uncertain write/retry, lease, leave/reload and copies passed (memory only)"
)
