--!strict
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Store = require("../src/server/Domain/ProfileStore")
local saved: unknown = nil
local failAfter, calls = false, 0
local adapter: Store.Adapter = {
	update = function(_key: string, transform: (unknown) -> unknown): (boolean, unknown)
		local value = transform(saved)
		if value ~= nil then
			saved = value
		end
		return not failAfter, if failAfter then nil else value
	end,
}
local function open(token: string): Store.Session
	return Store.new(adapter, 101, token, function(): number
		return 1000
	end, 60)
end
local session = open("accept-one")
assert(session.load())
local function accept(p: Profile.Profile, baseline: string, id: string): boolean
	calls += 1
	local old = p.jobs.active
	if baseline ~= (if old then old.id else "") then
		return false
	end
	return Jobs.accept(p, id, "paint-tutorial-v1")
end
failAfter = true
assert(not session.transact(function(p: Profile.Profile): boolean
	return accept(p, "", "server-job-one")
end), "Unknown write exposed a confirmed acceptance")
assert(
	session.status() == "Uncertain" and session.read() == nil and calls == 1,
	"Pending acceptance lost its original mutation"
)
assert(not session.transact(function(p: Profile.Profile): boolean
	return accept(p, "", "must-not-exist")
end), "A second transaction bypassed the pending write")
assert(calls == 1, "Unknown acceptance reran a mutation")
failAfter = false
assert(session.retry())
local p = session.read()
assert(
	p and p.jobs.active and p.jobs.active.id == "server-job-one" and p.jobs.issuedSequence == 1,
	"Recovered acceptance changed the issued job"
)
assert(p.wallet.dollars == 0 and p.progression.paintingXP == 0, "Acceptance paid a reward")
assert(session.transact(function(candidate: Profile.Profile): boolean
	return Jobs.cancel(candidate, "server-job-one")
end))
assert(not session.transact(function(candidate: Profile.Profile): boolean
	return accept(candidate, "", "stale-replay")
end), "Old acceptance replay created work after abandonment")
assert(session.close())
session = open("accept-two")
assert(session.load())
p = session.read()
assert(
	p
		and p.jobs.active
		and p.jobs.active.id == "server-job-one"
		and p.jobs.active.status == "Abandoned",
	"Memory reload changed the abandoned job"
)
assert(not session.transact(function(candidate: Profile.Profile): boolean
	return accept(candidate, "", "stale-after-rejoin")
end), "Reload allowed an old baseline to create work")
assert(session.transact(function(candidate: Profile.Profile): boolean
	return accept(candidate, "server-job-one", "server-job-two")
end))
p = session.read()
assert(
	p and p.jobs.issuedSequence == 2 and p.jobs.active and p.jobs.active.id == "server-job-two",
	"New baseline failed to issue exactly the next job"
)
assert(
	p.wallet.dollars == 0 and p.progression.paintingXP == 0,
	"Accept/retry/cancel/reload paid a reward"
)
print(
	"JobAcceptance: unknown commit, same-intent recovery, stale replay after cancel/reload, next baseline and no payout passed"
)
