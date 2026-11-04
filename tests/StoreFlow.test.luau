--!strict
local Flow = require("../src/shared/StoreFlow")
local Types = require("../src/shared/HomeTypes")
local function snapshot(): Types.Snapshot
	return {
		available = true,
		dollars = 70,
		revision = 1,
		editorId = "editor",
		homeName = "Home_1",
		origin = { 0, 0, 0 },
		nearHome = true,
		nearShop = false,
		items = {
			{
				id = "plant",
				catalogId = "floor-plant-v1",
				purchaseOperationId = "purchase:one",
				placed = { x = 5, z = 3, rotationY = 0 },
			},
		},
		catalog = {},
		onboarding = "DONE",
	}
end
local pending, sent = Flow.request(nil, "plant", "editor", 1, "store-one", 0)
assert(
	sent and not Flow.canRetry(pending, 7.99) and Flow.canRetry(pending, 8),
	"Store retry boundary"
)
local busy, again = Flow.request(pending, "plant", "editor", 1, "new-id", 1)
assert(not again and busy == pending, "Busy action changed identity")
local other, otherSent = Flow.request(pending, "lamp", "editor", 99, "other-id", 20)
assert(not otherSent and other == pending, "Unknown outcome allowed another item")
local retry, retried = Flow.request(pending, "plant", "editor", 99, "new-id", 8)
assert(
	retried and retry.requestId == "store-one" and retry.revision == 1 and retry.itemId == "plant",
	"Retry changed intent"
)
assert(not Flow.canRetry(retry, 15.99) and Flow.canRetry(retry, 16), "Retry timer did not renew")
local s = snapshot()
local kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Sync unlocked an unknown outcome")
s.storeAck = "another"
s.error = "NotOwned"
kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Other refusal released intent")
s.storeAck = "store-one"
for _, reason in { "Unavailable", "Saving", "UnknownTransportError" } do
	s.error = reason
	kept, outcome = Flow.observe(retry, s)
	assert(kept == retry and outcome == "Pending", "Uncertain result released intent")
end
s.error = "NotOwned"
kept, outcome = Flow.observe(retry, s)
assert(kept == nil and outcome == "Rejected", "Correlated refusal did not resolve")
s.error = nil
kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Ack alone removed the placed item")
s.items[1].placed = nil
s.available = false
kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Unavailable state proved storage")
s.available = true
s.storeAck = nil
kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Old stored state proved an unanswered no-op")
s.revision = 2
kept, outcome = Flow.observe(retry, s)
assert(kept == nil and outcome == "Confirmed", "Confirmed new room state did not resolve")
s.revision = 1
s.storeAck = "store-one"
kept, outcome = Flow.observe(retry, s)
assert(kept == nil and outcome == "Confirmed", "No-op acknowledgement did not resolve")
s.items = {}
kept, outcome = Flow.observe(retry, s)
assert(kept == retry and outcome == "Pending", "Missing ownership was treated as stored")
s.editorId = "new-editor"
kept, outcome = Flow.observe(retry, s)
assert(kept == nil and outcome == "Expired", "Old editor survived respawn")
assert(
	pending.requestId == "store-one" and pending.revision == 1,
	"Independent observations mutated original"
)
print(
	"StoreFlow: retry, identity, correlation, ownership, revision, unavailable and respawn passed"
)
