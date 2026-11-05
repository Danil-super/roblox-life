--!strict
local Http = game:GetService("HttpService")
local Profile = require("./Domain/Profile")
local Changes = require("./Domain/ProfileChanges")
local Diagnostics = {}
export type State = Changes.State
export type Event = "profile_load" | "profile_recovery" | "profile_failure"
export type Entry = "join" | "manual" | "heartbeat" | "change" | "spawn"
local reasons: { [string]: boolean } = {
	Requested = true,
	Unavailable = true,
	StorageUnavailable = true,
	Locked = true,
	Lost = true,
	Corrupt = true,
	Uncertain = true,
	Busy = true,
	Closed = true,
	InvalidProfile = true,
	Configuration = true,
	Cancelled = true,
	NoPendingWrite = true,
	InvalidAcknowledgement = true,
	LimitReached = true,
	NotLoadable = true,
	NotReady = true,
	Rejected = true,
	InvalidMutation = true,
	CharacterLoad = true,
	RoomVersion = true,
	SessionLost = true,
	LeaseLost = true,
	InvalidClock = true,
	StaleRevision = true,
	CloudTestNotConfigured = true,
	CloudTestUnpublished = true,
	CloudTestWrongExperience = true,
}
local function safeTrace(trace: string): string
	return if #trace == 36 and string.match(trace, "^%x+%-%x+%-%x+%-%x+%-%x+$")
		then trace
		else "redacted"
end
function Diagnostics.emit(
	event: Event,
	trace: string,
	entry: Entry,
	ok: boolean,
	reason: string?
): ()
	pcall(function()
		print(Http:JSONEncode({
			schema = 1,
			event = event,
			trace = safeTrace(trace),
			entry = entry,
			outcome = if ok then "ok" else "blocked",
			reason = if reason then (if reasons[reason] then reason else "Other") else nil,
		}))
	end)
end

function Diagnostics.observe(trace: string, previous: State?, profile: Profile.Profile): State
	if previous and previous.revision >= profile.revision then
		return previous
	end
	local current = Changes.capture(profile)
	local batch = Changes.diff(previous, current)
	if batch then
		-- Output is best effort. Logging must never turn a committed operation into an error.
		pcall(function()
			print(Http:JSONEncode({
				schema = 1,
				event = "profile_change",
				trace = safeTrace(trace),
				entry = "confirmed",
				revision = batch.revision,
				dollarsDelta = batch.dollarsDelta,
				xpDelta = batch.xpDelta,
				changes = batch.changes,
				omitted = batch.omitted,
			}))
		end)
	end
	return current
end
return table.freeze(Diagnostics)
