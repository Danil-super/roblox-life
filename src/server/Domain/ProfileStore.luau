--!strict
-- One coordinator per player/key. UpdateAsync is the sole persistence boundary.
local Profile = require("./Profile")
type Data = Profile.Profile
export type Adapter = { update: (string, (unknown) -> unknown) -> (boolean, unknown) }
export type Session = {
	load: () -> (boolean, string?),
	transact: ((Data) -> boolean) -> (boolean, string?),
	renew: () -> (boolean, string?),
	retry: () -> (boolean, string?),
	close: () -> (boolean, string?),
	read: () -> Data?,
	status: () -> string,
}
type Record = {
	recordVersion: number,
	profile: Data,
	fence: number,
	leaseOwner: string,
	leaseUntil: number,
	commitId: string,
}
type Intent = { kind: string, profile: Data?, baseRevision: number, writeId: string }
local MAX = 9007199254740991
local Store = {}

local function decode(raw: unknown, userId: number): Record?
	if type(raw) ~= "table" then
		return nil
	end
	local values = raw :: { [string]: unknown }
	local fields: { [string]: unknown } = {}
	local allowed = {
		recordVersion = true,
		profile = true,
		fence = true,
		leaseOwner = true,
		leaseUntil = true,
		commitId = true,
	}
	for key, value in next, values do
		if not allowed[key] then
			return nil
		end
		fields[key] = value
	end
	if
		fields.recordVersion ~= 1
		or not Profile.integer(fields.fence, 1, MAX - 1)
		or type(fields.leaseOwner) ~= "string"
		or (fields.leaseOwner ~= "" and not Profile.identifier(fields.leaseOwner))
		or not Profile.integer(fields.leaseUntil, 0, MAX)
		or not Profile.identifier(fields.commitId)
		or ((fields.leaseOwner == "") ~= (fields.leaseUntil == 0))
	then
		return nil
	end
	local profile = Profile.decode(fields.profile, userId)
	if profile == nil then
		return nil
	end
	return {
		recordVersion = 1,
		profile = profile,
		fence = fields.fence :: number,
		leaseOwner = fields.leaseOwner :: string,
		leaseUntil = fields.leaseUntil :: number,
		commitId = fields.commitId :: string,
	}
end

function Store.new(
	adapter: Adapter,
	userId: number,
	token: string,
	clock: () -> number,
	ttl: number
): Session
	assert(Profile.integer(userId, 1, MAX), "Positive profile owner required")
	assert(
		Profile.identifier(token) and #token <= 64,
		"Unique server-generated session token required"
	)
	assert(Profile.integer(ttl, 30, 600), "Lease TTL must be 30..600 seconds")
	local key = "player:" .. userId
	local state, busy, sequence = "Loading", false, 0
	local confirmed: Record? = nil
	local pending: Intent? = nil

	local function now(): number?
		local value = clock()
		return if Profile.integer(value, 1, MAX - ttl) then value else nil
	end
	local function usable(): boolean
		local current = confirmed
		if state ~= "Ready" or busy or current == nil then
			return false
		end
		local time = now()
		if time == nil or current.leaseUntil <= time then
			state = "Lost"
			return false
		end
		return true
	end

	local function resolve(): (boolean, string?)
		if busy then
			return false, "Busy"
		end
		local intent = pending
		if intent == nil then
			return false, "NoPendingWrite"
		end
		busy = true
		local denial = "Corrupt"
		local ran, ok, result = pcall(adapter.update, key, function(raw: unknown): unknown
			denial = "Corrupt"
			local time = now()
			if time == nil then
				denial = "InvalidClock"
				return nil
			end
			local current = if raw ~= nil then decode(raw, userId) else nil
			if raw ~= nil and current == nil then
				return nil
			end
			if intent.kind == "load" then
				if current == nil then
					return {
						recordVersion = 1,
						profile = Profile.new(userId),
						fence = 1,
						leaseOwner = token,
						leaseUntil = time + ttl,
						commitId = intent.writeId,
					}
				end
				if current.leaseOwner == token then
					if current.leaseUntil <= time then
						denial = "LeaseLost"
						return nil
					end
					return current -- An acquisition may have committed before its response failed.
				end
				if current.leaseOwner ~= "" and current.leaseUntil > time then
					denial = "Locked"
					return nil
				end
				if current.fence >= MAX - 1 then
					denial = "LimitReached"
					return nil
				end
				current.fence += 1
				current.leaseOwner, current.leaseUntil, current.commitId =
					token, time + ttl, intent.writeId
				return current
			end
			local previous = confirmed
			if current == nil or previous == nil or current.fence ~= previous.fence then
				denial = "LeaseLost"
				return nil
			end
			if current.commitId == intent.writeId then
				if intent.kind == "close" and current.leaseOwner == "" then
					return current
				end
				if current.leaseOwner == token and current.leaseUntil > time then
					return current
				end
				denial = "LeaseLost"
				return nil
			end
			if current.leaseOwner ~= token or current.leaseUntil <= time then
				denial = "LeaseLost"
				return nil
			end
			if current.profile.revision ~= intent.baseRevision then
				denial = "StaleRevision"
				return nil
			end
			if intent.profile ~= nil then
				current.profile = Profile.copy(intent.profile)
			end
			current.commitId = intent.writeId
			current.leaseOwner = if intent.kind == "close" then "" else token
			current.leaseUntil = if intent.kind == "close" then 0 else time + ttl
			return current
		end)
		busy = false
		if not ran or not ok then
			state = "Uncertain" -- Keep the exact intent; never rerun the mutation on retry.
			return false, "StorageUnavailable"
		end
		if result == nil then
			pending = nil
			state = if intent.kind == "load" then "Blocked" else "Lost"
			return false, denial
		end
		local saved = decode(result, userId)
		local time = now()
		if
			saved == nil
			or time == nil
			or saved.commitId ~= intent.writeId
			or (intent.kind ~= "close" and (saved.leaseOwner ~= token or saved.leaseUntil <= time))
		then
			state, pending = "Lost", nil
			return false, "InvalidAcknowledgement"
		end
		confirmed, pending = saved, nil
		state = if intent.kind == "close" then "Closed" else "Ready"
		return true, nil
	end

	local function prepare(kind: string, profile: Data?): (boolean, string?)
		sequence += 1
		if sequence > 1000000000 then
			state = "Lost"
			return false, "LimitReached"
		end
		pending = {
			kind = kind,
			profile = profile,
			baseRevision = if confirmed then confirmed.profile.revision else 0,
			writeId = token .. ":" .. sequence,
		}
		return resolve()
	end
	return {
		load = function(): (boolean, string?)
			if
				busy
				or pending ~= nil
				or state == "Ready"
				or state == "Closed"
				or state == "Lost"
			then
				return false, "NotLoadable"
			end
			return prepare("load", nil)
		end,
		transact = function(change: (Data) -> boolean): (boolean, string?)
			local current = confirmed
			if not usable() or current == nil then
				return false, "NotReady"
			end
			busy = true
			local candidate = Profile.copy(current.profile)
			local ran, accepted = pcall(change, candidate)
			busy = false
			if not ran or not accepted then
				return false, "Rejected"
			end
			if current.profile.revision >= MAX then
				return false, "LimitReached"
			end
			candidate.revision = current.profile.revision + 1
			local validated = Profile.decode(candidate, userId)
			if validated == nil then
				return false, "InvalidMutation"
			end
			return prepare("commit", validated)
		end,
		renew = function(): (boolean, string?)
			if not usable() then
				return false, "NotReady"
			end
			return prepare("renew", nil)
		end,
		retry = resolve,
		close = function(): (boolean, string?)
			if state == "Closed" then
				return true, nil
			end
			if not usable() then
				return false, "NotReady"
			end
			return prepare("close", nil)
		end,
		read = function(): Data?
			return if usable() and confirmed ~= nil then Profile.copy(confirmed.profile) else nil
		end,
		status = function(): string
			if state == "Ready" and not busy then
				usable()
			end
			return state
		end,
	}
end

return Store
