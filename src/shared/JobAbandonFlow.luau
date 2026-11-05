--!strict
local Types = require("./JobTypes")
export type Target = { jobId: string, workId: string, sentAt: number? }
export type Outcome = "Waiting" | "Confirmed" | "Expired"
local Flow = {}
local phases: { [string]: boolean } = {
	Inspect = true,
	Prepare = true,
	ChooseMaterial = true,
	Painting = true,
	SurfaceReady = true,
	Ready = true,
}
function Flow.request(s: Types.Snapshot?, ready: boolean): Target?
	if
		s == nil
		or not ready
		or not s.available
		or not phases[s.phase]
		or #s.jobId == 0
		or #s.workId == 0
	then
		return nil
	end
	return { jobId = s.jobId, workId = s.workId }
end
function Flow.canSend(t: Target?, s: Types.Snapshot?, now: number, ready: boolean): boolean
	local current = Flow.request(s, ready)
	return t ~= nil
		and current ~= nil
		and t.jobId == current.jobId
		and t.workId == current.workId
		and now == now
		and now >= 0
		and now < math.huge
		and (t.sentAt == nil or now - t.sentAt >= 8)
end
function Flow.sent(t: Target?, s: Types.Snapshot?, now: number, ready: boolean): Target?
	if t == nil or not Flow.canSend(t, s, now, ready) then
		return nil
	end
	return { jobId = t.jobId, workId = t.workId, sentAt = now }
end
function Flow.observe(t: Target?, s: Types.Snapshot?): (Target?, Outcome)
	if t == nil or s == nil or not s.available then
		return t, "Waiting"
	end
	if s.phase == "Offer" and (s.jobId == t.jobId or s.jobId == "") then
		return nil, if t.sentAt ~= nil then "Confirmed" else "Expired"
	end
	if s.jobId ~= t.jobId or s.workId ~= t.workId or not phases[s.phase] then
		return nil, "Expired"
	end
	return t, "Waiting"
end
return table.freeze(Flow)
