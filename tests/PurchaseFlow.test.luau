--!strict
local Flow = require("../src/shared/PurchaseFlow")
local Types = require("../src/shared/HomeTypes")
local pending, sent = Flow.request(nil, "plant", "one", 0)
assert(sent and not Flow.canRetry(pending, 7.99), "Initial request must wait for confirmation")
local duplicate, again = Flow.request(pending, "plant", "two", 1)
assert(not again and duplicate == pending and duplicate.requestId == "one", "Busy request changed")
local other, changed = Flow.request(pending, "lamp", "two", 30)
assert(not changed and other == pending, "Another product replaced unknown payment")
local retry, retried = Flow.request(pending, "plant", "two", 8)
assert(
	retried and retry.requestId == "one" and retry.catalogId == "plant",
	"Retry changed identity"
)
assert(
	not Flow.canRetry(retry, 15.99) and Flow.canRetry(retry, 16),
	"Retry timeout boundary changed"
)
local items: { Types.Owned } = {}
local kept, outcome = Flow.observe(retry, items, "unrelated", "Collision")
assert(kept == retry and outcome == "Pending", "Unrelated error dropped payment identity")
for _, reason in { "Unavailable", "Restart", "Saving", "UnexpectedTransportError" } do
	local unresolved, status = Flow.observe(retry, items, "one", reason)
	assert(unresolved == retry and status == "Pending", "Unknown outcome became a new payment")
end
local noProof, status = Flow.observe(retry, items, "one", nil)
assert(noProof == retry and status == "Pending", "Ack alone invented an owned item")
local rejected, rejection = Flow.observe(retry, items, "one", "InsufficientFunds")
assert(rejected == nil and rejection == "Rejected", "Definitive correlated refusal not resolved")
table.insert(items, { id = "owned", catalogId = "plant", purchaseOperationId = "purchase:one" })
local done, confirmed, id = Flow.observe(retry, items, nil, "GoHome")
assert(
	done == nil and confirmed == "Confirmed" and id == "owned",
	"Owned receipt did not resolve payment"
)
local repeated, repeatOutcome = Flow.observe(done, items, "one", nil)
assert(repeated == nil and repeatOutcome == "Idle", "Repeated receipt reopened confirmation")
local fresh, freshSent = Flow.request(done, "lamp", "three", 17)
assert(freshSent and fresh.requestId == "three", "Confirmed intent blocked next purchase")
assert(retry.requestId == "one", "Independent purchase mutated another player")
print("PurchaseFlow: busy, timeout, correlation, receipt, rejection and independence passed")
