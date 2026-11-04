--!strict
local Flow = require("../src/shared/PlacementFlow")
local Types = require("../src/shared/HomeTypes")
local function state(): Types.Snapshot
	return {
		available = true,
		dollars = 70,
		revision = 2,
		editorId = "editor",
		homeName = "Home_1",
		origin = { 0, 0, 0 },
		nearHome = true,
		nearShop = false,
		items = {},
		catalog = {},
		onboarding = "DONE",
	}
end
local pose = { x = 5, z = 3, rotationY = 90, mode = "Grid" }
local pending = Flow.start("placement-one", "editor", "plant", 2, pose, 0)
pose.x = 10
assert(pending.pose.x == 5, "Input mutated an in-flight placement")
assert(not Flow.canRetry(pending, 7.99) and Flow.canRetry(pending, 8), "Retry boundary changed")
local retry = Flow.retry(pending, 8)
assert(
	retry.requestId == pending.requestId and retry.revision == 2 and retry.pose.x == 5,
	"Retry changed intent"
)
assert(
	not Flow.canRetry(retry, 15.99) and Flow.canRetry(retry, 16),
	"Retry did not restart timeout"
)
local s = state()
local kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Unrelated sync unlocked an unknown placement")
s.placementAck, s.error = "another", "Blocked"
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Unrelated rejection released placement")
s.placementAck, s.error = retry.requestId, "Unavailable"
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Unknown persistence outcome released placement")
s.error = "Blocked"
kept, result = Flow.observe(retry, s)
assert(kept == nil and result == "Rejected", "Correlated definite rejection did not unlock")
s.error = nil
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Ack invented furniture without confirmed pose")
s.items = {
	{
		id = "plant",
		catalogId = "floor-plant-v1",
		purchaseOperationId = "purchase:one",
		placed = { x = 5, z = 3, rotationY = 90 },
	},
}
s.available = false
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Unavailable snapshot confirmed placement")
s.available, s.placementAck = true, nil
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Pre-existing pose confirmed an unanswered no-op")
s.revision = 3
kept, result = Flow.observe(retry, s)
assert(kept == nil and result == "Confirmed", "Confirmed changed room did not resolve placement")
s.revision, s.placementAck = 2, retry.requestId
kept, result = Flow.observe(retry, s)
assert(kept == nil and result == "Confirmed", "Acknowledged no-op failed")
s.editorId = "other"
kept, result = Flow.observe(retry, s)
assert(kept == retry and result == "Pending", "Another editor confirmed placement")
local other = Flow.start("placement-two", "other", "lamp", 0, pose, 1)
assert(other.requestId ~= retry.requestId and retry.pose.x == 5, "Player intents shared state")
print(
	"PlacementFlow: immutable retry, correlated refusal, confirmed pose, revision and isolation passed"
)
