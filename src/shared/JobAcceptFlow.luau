--!strict
local Types = require("./JobTypes")
export type Target = { requestId: string, offerId: string, jobId: string, sentAt: number? }
export type Outcome = "Waiting" | "Confirmed" | "Rejected" | "Expired"
local Flow = {}
local accepted: { [string]: boolean } = {
	Inspect = true,
	Prepare = true,
	ChooseMaterial = true,
	Painting = true,
	SurfaceReady = true,
	Ready = true,
	Completed = true,
}
local function selectable(s: Types.Snapshot): boolean
	return s.available and (s.phase == "Offer" or s.phase == "Completed")
end
function Flow.available(s: Types.Snapshot?, id: string, ready: boolean): boolean
	if s == nil or not ready or not selectable(s) or s.offers == nil then
		return false
	end
	for _, offer in s.offers do
		if offer.id == id and offer.unlocked then
			return true
		end
	end
	return false
end
function Flow.request(s: Types.Snapshot?, id: string, ready: boolean, requestId: string): Target?
	if s == nil or #requestId == 0 or #requestId > 80 or not Flow.available(s, id, ready) then
		return nil
	end
	return { requestId = requestId, offerId = id, jobId = s.jobId }
end
function Flow.canSend(t: Target?, s: Types.Snapshot?, now: number, ready: boolean): boolean
	return t ~= nil
		and s ~= nil
		and ready
		and selectable(s)
		and s.jobId == t.jobId
		and now == now
		and now >= 0
		and now < math.huge
		and (t.sentAt == nil or now - t.sentAt >= 8)
end
function Flow.sent(t: Target?, s: Types.Snapshot?, now: number, ready: boolean): Target?
	if t == nil or not Flow.canSend(t, s, now, ready) then
		return nil
	end
	return { requestId = t.requestId, offerId = t.offerId, jobId = t.jobId, sentAt = now }
end
function Flow.observe(t: Target?, s: Types.Snapshot?): (Target?, Outcome)
	if t == nil or s == nil or not s.available then
		return t, "Waiting"
	end
	if s.jobId ~= t.jobId then
		return nil,
			if t.sentAt ~= nil
					and s.contractId == t.offerId
					and accepted[s.phase]
				then "Confirmed"
				else "Expired"
	end
	local ack = s.acceptAck
	if
		ack
		and ack.requestId == t.requestId
		and ack.jobId == t.jobId
		and ack.offerId == t.offerId
		and (ack.error == "OfferLocked" or ack.error == "UnknownOffer")
	then
		return nil, "Rejected"
	end
	return t, "Waiting"
end
return table.freeze(Flow)
