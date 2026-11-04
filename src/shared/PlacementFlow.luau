--!strict
local Types = require("./HomeTypes")
export type Pose = { x: number, z: number, rotationY: number, mode: string }
export type Pending = {
	requestId: string,
	editorId: string,
	itemId: string,
	revision: number,
	pose: Pose,
	retryAt: number,
}
local Flow = {}
local rejections: { [string]: boolean } = {
	GoHome = true,
	StaleRevision = true,
	NotOwned = true,
	UnknownProduct = true,
	RoomVersion = true,
	InvalidPose = true,
	Bounds = true,
	Blocked = true,
	Collision = true,
	LimitReached = true,
}
function Flow.start(
	requestId: string,
	editorId: string,
	itemId: string,
	revision: number,
	pose: Pose,
	now: number
): Pending
	return {
		requestId = requestId,
		editorId = editorId,
		itemId = itemId,
		revision = revision,
		pose = table.clone(pose),
		retryAt = now + 8,
	}
end
function Flow.canRetry(pending: Pending, now: number): boolean
	return now >= pending.retryAt
end
function Flow.retry(pending: Pending, now: number): Pending
	return Flow.start(
		pending.requestId,
		pending.editorId,
		pending.itemId,
		pending.revision,
		pending.pose,
		now
	)
end
function Flow.observe(pending: Pending, s: Types.Snapshot): (Pending?, string)
	if not s.available or s.editorId ~= pending.editorId then
		return pending, "Pending"
	end
	local acknowledged = s.placementAck == pending.requestId
	for _, owned in s.items do
		local p = owned.placed
		if
			owned.id == pending.itemId
			and p
			and math.abs(p.x - pending.pose.x) < 0.001
			and math.abs(p.z - pending.pose.z) < 0.001
			and p.rotationY == pending.pose.rotationY
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
