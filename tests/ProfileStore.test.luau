--!strict
local Profile = require("../src/server/Domain/Profile")
local Store = require("../src/server/Domain/ProfileStore")
local Economy = require("../src/server/Domain/Economy")
local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print("PASS", name)
end

local function fixture()
	local now = 100
	local data: { [string]: unknown } = {}
	local failBefore, failAfter = false, false
	local adapter: Store.Adapter = {
		update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
			if failBefore then
				return false, "Transport"
			end
			local result = transform(data[key])
			if result ~= nil then
				data[key] = result
			end
			if failAfter then
				return false, "UnknownWriteOutcome"
			end
			return true, result
		end,
	}
	return {
		new = function(token: string, userId: number?)
			return Store.new(adapter, userId or 1, token, function(): number
				return now
			end, 60)
		end,
		advance = function(seconds: number): ()
			now += seconds
		end,
		before = function(value: boolean): ()
			failBefore = value
		end,
		after = function(value: boolean): ()
			failAfter = value
		end,
		data = data,
	}
end

test("load atomically creates and exclusively locks a fresh profile", function()
	local f = fixture()
	local first, second = f.new("server-a"), f.new("server-b")
	assert(first.load(), "First load must acquire a lease")
	local profile = first.read()
	assert(profile ~= nil and profile.wallet.dollars == 0, "New wallet must be empty")
	assert(not second.load(), "A live foreign lease must block another server")
	assert(second.read() == nil, "Blocked load must expose no editable default")
	profile.wallet.dollars = 999
	assert(
		(first.read() :: Profile.Profile).wallet.dollars == 0,
		"Reads must return isolated copies"
	)
end)

test("load failures stay closed and retry the same acquisition", function()
	local f = fixture()
	local session = f.new("server-a")
	f.before(true)
	assert(not session.load() and session.read() == nil, "Failed load must not produce a default")
	f.before(false)
	assert(session.retry(), "A safe retry must finish acquisition")
	assert(session.read() ~= nil, "Confirmed load must unlock gameplay")
end)

test("ambiguous acquisition is recovered with the original token", function()
	local f = fixture()
	f.after(true)
	local session = f.new("server-a")
	assert(
		not session.load() and session.read() == nil,
		"Unacknowledged acquisition must remain blocked"
	)
	f.after(false)
	assert(session.retry(), "Already committed acquisition must be recognized")
	assert(not f.new("server-b").load(), "Recovered lock must still be exclusive")
end)

test("expired owners cannot write even after the new owner releases", function()
	local f = fixture()
	local first, second = f.new("server-a"), f.new("server-b")
	assert(first.load(), "First acquisition failed")
	f.advance(61)
	assert(second.load(), "Expired lease must permit a new owner")
	assert(second.close(), "New owner must release successfully")
	assert(not first.transact(function(p: Profile.Profile): boolean
		p.wallet.dollars = 999
		return true
	end), "Stale owner must not regain a released lease")
	assert(first.read() == nil, "Stale session must become unusable")
end)

test("successful mutations persist before becoming visible and survive reopen", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	assert(
		session.transact(function(p: Profile.Profile): boolean
			p.wallet.dollars = 250
			return true
		end),
		"Commit failed"
	)
	assert((session.read() :: Profile.Profile).wallet.dollars == 250, "Confirmed mutation missing")
	assert(session.close(), "Release failed")
	local nextSession = f.new("server-b")
	assert(nextSession.load(), "Next session must acquire released profile")
	assert(
		(nextSession.read() :: Profile.Profile).wallet.dollars == 250,
		"Saved balance must survive session handoff"
	)
end)

test("unknown commit outcome freezes writes and retries the same snapshot once", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	local calls = 0
	f.after(true)
	assert(not session.transact(function(p: Profile.Profile): boolean
		calls += 1
		p.wallet.dollars += 250
		return true
	end), "Unknown result must not be acknowledged")
	assert(session.read() == nil, "Uncertain profile must not be editable")
	assert(not session.transact(function(): boolean
		error("New mutation ran while uncertain")
	end), "Later mutation must wait for resolution")
	f.after(false)
	assert(session.retry(), "Retry must acknowledge committed snapshot")
	assert(
		calls == 1 and (session.read() :: Profile.Profile).wallet.dollars == 250,
		"Retry must neither rerun mutation nor double reward"
	)
end)

test("pre-commit failure cannot publish the speculative profile", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	f.before(true)
	assert(not session.transact(function(p: Profile.Profile): boolean
		p.wallet.dollars = 250
		return true
	end), "Failed write must be uncertain")
	f.before(false)
	assert(session.retry(), "Retry must write the original pending profile")
	assert((session.read() :: Profile.Profile).wallet.dollars == 250, "Pending result lost")
end)

test("renew keeps ownership while expired sessions stop exposing data", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	f.advance(45)
	assert(session.renew(), "Heartbeat must renew lease")
	f.advance(30)
	assert(not f.new("server-b").load(), "Renewed lease must still block competitors")
	f.advance(31)
	assert(session.read() == nil, "Expired local lease must block gameplay")
	assert(not session.renew(), "Expired owner must not resurrect itself")
end)

test("corrupt records and rejected mutations never overwrite stored data", function()
	local f = fixture()
	f.data["player:1"] = { recordVersion = 999 }
	local session = f.new("server-a")
	assert(not session.load() and session.read() == nil, "Unknown record version must block load")
	local clean = fixture()
	session = clean.new("server-a")
	assert(session.load(), "Load failed")
	assert(not session.transact(function(p: Profile.Profile): boolean
		p.wallet.dollars = -1
		return true
	end), "Invalid profile must not be committed")
	assert(not session.transact(function(p: Profile.Profile): boolean
		p.wallet.dollars = 99
		return false
	end), "Rejected operation must discard its copy")
	assert((session.read() :: Profile.Profile).wallet.dollars == 0, "Failed mutation leaked")
end)

test("economy commits dollars, item and replay proof together across sessions", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	assert(
		session.transact(function(p: Profile.Profile): boolean
			p.jobs.issuedSequence = 1
			p.jobs.active = {
				id = "one",
				sequence = 1,
				templateId = "paint-tutorial-v1",
				status = "ReadyForInspection",
			}
			return Economy.completeJob(p, "one", 100) ~= nil
		end),
		"Reward commit failed"
	)
	f.after(true)
	assert(not session.transact(function(p: Profile.Profile): boolean
		return Economy.purchase(p, "one", "floor-plant-v1", "item-1", 100) ~= nil
	end), "Unknown purchase outcome must not be acknowledged")
	f.after(false)
	assert(session.retry() and session.close(), "Purchase resolution/release failed")
	local nextSession = f.new("server-b")
	assert(nextSession.load(), "Reopen failed")
	assert(
		nextSession.transact(function(p: Profile.Profile): boolean
			return Economy.purchase(p, "one", "floor-plant-v1", "item-2", 101) ~= nil
		end),
		"Idempotent retry must succeed"
	)
	local p = nextSession.read()
	assert(
		p ~= nil
			and p.wallet.dollars == 70
			and p.inventory["item-1"] ~= nil
			and p.inventory["item-2"] == nil,
		"Purchase was duplicated or ownership lost"
	)
end)

test("stale data revisions are fenced without overwriting newer data", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	local raw = f.data["player:1"] :: { profile: Profile.Profile }
	raw.profile.revision += 1
	raw.profile.wallet.dollars = 700
	local ok, reason = session.transact(function(p: Profile.Profile): boolean
		p.wallet.dollars = 1
		return true
	end)
	assert(not ok and reason == "StaleRevision", "Stale revision must be rejected")
	assert(
		raw.profile.wallet.dollars == 700 and session.read() == nil,
		"Newer state must remain untouched"
	)
end)

test("release with a lost acknowledgement remains safely retryable", function()
	local f = fixture()
	local session = f.new("server-a")
	assert(session.load(), "Load failed")
	f.after(true)
	assert(not session.close(), "Unknown release cannot be acknowledged")
	f.after(false)
	assert(
		session.retry() and session.status() == "Closed",
		"Retry must recognize committed release"
	)
	assert(session.close(), "Repeated close must be harmless")
	assert(f.new("server-b").load(), "Released profile must load on another session")
end)

test("one yielding adapter call blocks reentrant work for the same key", function()
	local records: { [string]: unknown } = {}
	local session: Store.Session? = nil
	local attempted = false
	local adapter: Store.Adapter = {
		update = function(key: string, transform: (unknown) -> unknown): (boolean, unknown)
			local current = session
			if current ~= nil then
				attempted = true
				assert(not current.transact(function(): boolean
					error("Concurrent change executed")
				end), "Reentrant write must be blocked")
			end
			-- UpdateAsync may call a transform more than once before committing.
			transform(records[key])
			local result = transform(records[key])
			if result ~= nil then
				records[key] = result
			end
			return true, result
		end,
	}
	session = Store.new(adapter, 1, "server-a", function(): number
		return 100
	end, 60)
	assert(session.load(), "Load failed")
	assert(
		session.transact(function(p: Profile.Profile): boolean
			p.wallet.dollars = 250
			return true
		end),
		"Commit failed"
	)
	assert(
		attempted and (session.read() :: Profile.Profile).wallet.dollars == 250,
		"Repeated transforms must not duplicate the mutation"
	)
end)

print(string.format("%d profile store tests passed", passed))
