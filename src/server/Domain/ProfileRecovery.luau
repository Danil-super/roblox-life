--!strict
local Store = require("./ProfileStore")
local Recovery = {}
function Recovery.action(status: string, reason: string?, blocked: string?): string?
	if blocked ~= nil then
		return nil
	end
	if status == "Uncertain" then
		return "retry"
	end
	if status == "Blocked" and reason == "Locked" then
		return "load"
	end
	if status == "Ready" and reason == "CharacterLoad" then
		return "finalize"
	end
	return nil
end
function Recovery.attempt(
	session: Store.Session,
	reason: string?,
	blocked: string?
): (boolean, string?)
	local action = Recovery.action(session.status(), reason, blocked)
	if action == "retry" then
		return session.retry()
	end
	if action == "load" then
		return session.load()
	end
	if action == "finalize" then
		return session.read() ~= nil, nil
	end
	return false, reason or blocked or "SessionLost"
end
function Recovery.code(status: string, reason: string?, blocked: string?): string
	if blocked ~= nil then
		return "Configuration"
	end
	if status == "Lost" or status == "Closed" then
		return "SessionLost"
	end
	if reason == "Locked" then
		return "Locked"
	end
	if reason == "Corrupt" then
		return "Corrupt"
	end
	if reason == "RoomVersion" then
		return "RoomVersion"
	end
	if reason == "CharacterLoad" then
		return "CharacterLoad"
	end
	return "Unavailable"
end
return table.freeze(Recovery)
