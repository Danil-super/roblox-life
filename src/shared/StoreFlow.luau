--!strict
local Types = require("./HomeTypes")
export type Pending = {
	requestId: string,
	editorId: string,
	itemId: string,
	revision: number,
	retryAt: number,
}
export type Outcome = "Idle" | "Pending" | "Confirmed" | "Rejected" | "Expired"
local Flow = {}
local rejections: { [string]: boolean } =
	{ GoHome = true, StaleRevision = true, NotOwned = true, LimitReached = true }
function Flow.canRetry(pending: Pending, now: number): boolean
	return now >= pending.retryAt
end
function Flow.request(
	pending: Pending?,
	itemId: string,
	editorId: string,
	revision: number,
	requestId: string,
	now: number
): (Pending, boolean)
	if
		pending
		and (
			pending.itemId ~= itemId
			or pending.editorId ~= editorId
			or not Flow.canRetry(pending, now)
		)
	then
		return pending, false
	end
	return {
		requestId = if pending then pending.requestId else requestId,
		editorId = editorId,
		itemId = itemId,
		revision = if pending then pending.revision else revision,
		retryAt = now + 8,
	},
		true
end
function Flow.observe(pending: Pending?, s: Types.Snapshot): (Pending?, Outcome)
	if pending == nil then
		return nil, "Idle"
	end
	if s.editorId ~= pending.editorId then
		return nil, "Expired"
	end
	if not s.available then
		return pending, "Pending"
	end
	local acknowledged = s.storeAck == pending.requestId
	for _, owned in s.items do
		if
			owned.id == pending.itemId
			and owned.placed == nil
			and (s.revision > pending.revision or (acknowledged and s.error == nil))
		then
			return nil, "Confirmed"
		end
	end
	if acknowledged and s.error and rejections[s.error] then
		return nil, "Rejected"
	end
	return pending, "Pending"
end
return table.freeze(Flow)
