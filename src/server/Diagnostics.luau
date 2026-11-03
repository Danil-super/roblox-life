--!strict
local Http = game:GetService("HttpService")
local Diagnostics = {}
export type Event = "profile_load" | "profile_recovery" | "profile_failure"
export type Entry = "join" | "manual" | "heartbeat" | "change" | "spawn"
function Diagnostics.emit(
	event: Event,
	trace: string,
	entry: Entry,
	ok: boolean,
	reason: string?
): ()
	print(Http:JSONEncode({
		event = event,
		trace = trace,
		entry = entry,
		outcome = if ok then "ok" else "blocked",
		reason = reason,
	}))
end
return table.freeze(Diagnostics)
