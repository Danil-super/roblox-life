--!strict
local Types = require("./HomeTypes")
export type Pending = { requestId: string, catalogId: string, retryAt: number }
export type Outcome = "Idle" | "Pending" | "Confirmed" | "Rejected"
local Flow = {}
local TIMEOUT = 8
local rejections: { [string]: boolean } = {
	GoShop = true,
	InvalidRequest = true,
	OperationConflict = true,
	UnknownProduct = true,
	InventoryConflict = true,
	LimitReached = true,
	InsufficientFunds = true,
}
function Flow.canRetry(pending: Pending, now: number): boolean
	return now >= pending.retryAt
end
function Flow.request(
	pending: Pending?,
	catalogId: string,
	requestId: string,
	now: number
): (Pending, boolean)
	if pending and (pending.catalogId ~= catalogId or not Flow.canRetry(pending, now)) then
		return pending, false
	end
	return {
		requestId = if pending then pending.requestId else requestId,
		catalogId = catalogId,
		retryAt = now + TIMEOUT,
	},
		true
end
function Flow.observe(
	pending: Pending?,
	items: { Types.Owned },
	ack: string?,
	reason: string?
): (Pending?, Outcome, string?)
	if pending == nil then
		return nil, "Idle", nil
	end
	for _, owned in items do
		if
			owned.purchaseOperationId == "purchase:" .. pending.requestId
			and owned.catalogId == pending.catalogId
		then
			return nil, "Confirmed", owned.id
		end
	end
	-- A sync/editor error cannot decide the outcome of an in-flight payment.
	if ack == pending.requestId and reason ~= nil and rejections[reason] then
		return nil, "Rejected", nil
	end
	return pending, "Pending", nil
end
return table.freeze(Flow)
