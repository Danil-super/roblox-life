--!strict
local Recovery = require("../src/server/Domain/ProfileRecovery")
local Store = require("../src/server/Domain/ProfileStore")
local data: { [string]: unknown } = {}
local failBefore, failAfter, calls = false, false, 0
local now = 100
local adapter: Store.Adapter = {
	update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
		calls += 1
		if failBefore then
			return false, "Transport"
		end
		local value = transform(data[key])
		if value ~= nil then
			data[key] = value
		end
		return not failAfter, value
	end,
}
local function session(token: string, userId: number?): Store.Session
	return Store.new(adapter, userId or 1, token, function(): number
		return now
	end, 60)
end
local a = session("owner")
failBefore = true
local loaded = a.load()
assert(not loaded and a.read() == nil, "Failed load exposed profile")
failBefore = false
assert(Recovery.attempt(a, "StorageUnavailable", nil), "Retry did not recover initial load")
failAfter = true
local mutations = 0
assert(not a.transact(function(p)
	mutations += 1
	p.wallet.dollars = 250
	return true
end), "Unknown commit was acknowledged")
assert(a.read() == nil, "Unknown write exposed editable profile")
failAfter = false
assert(Recovery.attempt(a, "StorageUnavailable", nil), "Exact pending write was not recovered")
local p = a.read()
assert(p and p.wallet.dollars == 250 and mutations == 1, "Recovery reran payment or lost money")
local b = session("other")
local ok, reason = b.load()
assert(not ok and reason == "Locked", "Live session was stolen")
assert(not Recovery.attempt(b, reason, nil), "Recovery bypassed another owner")
assert(
	b.read() == nil and (a.read() :: typeof(p)).wallet.dollars == 250,
	"Foreign retry altered owner"
)
assert(a.close(), "Owner did not release session")
assert(Recovery.attempt(b, "Locked", nil), "Released lease could not be retried")
assert((b.read() :: typeof(p)).wallet.dollars == 250, "Retry replaced saved profile with defaults")
now += 61
assert(b.read() == nil and b.status() == "Lost", "Lease expiry not detected")
local before = calls
assert(
	not Recovery.attempt(b, "LeaseLost", nil) and calls == before,
	"Lost session attempted a write"
)
data["player:2"] = { broken = true }
local corrupt = session("corrupt", 2)
local _, corruptReason = corrupt.load()
before = calls
assert(
	not Recovery.attempt(corrupt, corruptReason, nil) and calls == before,
	"Corrupt profile was retried"
)
local blocked = session("blocked", 3)
assert(
	not Recovery.attempt(blocked, nil, "CloudTestUnpublished") and calls == before,
	"Blocked QA used storage"
)
assert(
	Recovery.action("Ready", "CharacterLoad", nil) == "finalize",
	"Character failure is not recoverable"
)
assert(
	Recovery.action("Ready", "RoomVersion", nil) == nil,
	"Unsupported room was treated as recoverable"
)
print(
	"ProfileRecovery: initial load, unknown commit, locked/released lease, loss, corruption and config passed"
)
