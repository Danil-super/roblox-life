--!strict
local Flow = require("../src/shared/JobAcceptFlow")
local Types = require("../src/shared/JobTypes")
local function snapshot(): Types.Snapshot
	return {
		available = true,
		phase = "Offer",
		jobId = "",
		workId = "",
		sequence = 0,
		mask = "",
		count = 0,
		reward = 250,
		near = false,
		offers = {
			{
				id = "basic",
				unlocked = true,
				titleKey = "",
				briefKey = "",
				colorId = "",
				requiredXP = 0,
				reward = 250,
				xp = 50,
			},
			{
				id = "mint",
				unlocked = false,
				titleKey = "",
				briefKey = "",
				colorId = "",
				requiredXP = 50,
				reward = 300,
				xp = 70,
			},
		},
	}
end
local s = snapshot()
assert(
	not Flow.request(s, "basic", true, "")
		and not Flow.request(s, "basic", true, string.rep("x", 81)),
	"Invalid request ID started acceptance"
)
local request = Flow.request(s, "basic", true, "request-one")
assert(request and request.offerId == "basic" and request.jobId == "", "Initial baseline missing")
assert(
	not Flow.request(s, "mint", true, "request-one")
		and not Flow.request(s, "missing", true, "request-one"),
	"Missing or locked offer accepted"
)
assert(
	not Flow.request(nil, "basic", true, "request-one")
		and not Flow.request(s, "basic", false, "request-one"),
	"Unready acceptance started"
)
local sent = Flow.sent(request, s, 10, true)
assert(sent and sent.sentAt == 10 and request.sentAt == nil, "Send mutated request")
assert(
	not Flow.canSend(sent, s, 17.999, true) and Flow.canSend(sent, s, 18, true),
	"Retry boundary changed"
)
local retry = Flow.sent(sent, s, 18, true)
assert(
	retry
		and retry.requestId == sent.requestId
		and retry.offerId == sent.offerId
		and retry.jobId == sent.jobId
		and retry.sentAt == 18,
	"Retry changed acceptance target"
)
for _, now in { -1, math.huge, 0 / 0 } do
	assert(not Flow.canSend(sent, s, now, true), "Invalid clock")
end
s.available = false
assert(
	Flow.observe(sent, s) == sent and not Flow.canSend(sent, s, 20, true),
	"Busy state released intent"
)
s.available = true
s.error = "Unavailable"
assert(
	Flow.observe(sent, s) == sent and Flow.canSend(sent, s, 20, true),
	"Unknown outcome changed intent"
)
s.acceptAck = { requestId = "old-request", jobId = "", offerId = "basic", error = "OfferLocked" }
assert(Flow.observe(sent, s) == sent, "Previous attempt ack released new request")
s.acceptAck = nil
s.error = "OfferLocked"
assert(Flow.observe(sent, s) == sent, "Uncorrelated error released intent")
for _, ack in
	{
		{ requestId = "request-one", jobId = "other", offerId = "basic", error = "OfferLocked" },
		{ requestId = "request-one", jobId = "", offerId = "mint", error = "OfferLocked" },
		{ requestId = "request-one", jobId = "", offerId = "basic", error = "Unavailable" },
	}
do
	s.acceptAck = ack
	assert(Flow.observe(sent, s) == sent, "Wrong/unknown ack released intent")
end
for _, reason in { "OfferLocked", "UnknownOffer" } do
	s.acceptAck = { requestId = "request-one", jobId = "", offerId = "basic", error = reason }
	local resolved, outcome = Flow.observe(sent, s)
	assert(resolved == nil and outcome == "Rejected", "Definite correlated refusal ignored")
end
for _, phase in
	{ "Inspect", "Prepare", "ChooseMaterial", "Painting", "SurfaceReady", "Ready", "Completed" }
do
	s = snapshot()
	s.jobId, s.contractId, s.phase = "new-job", "basic", phase
	local resolved, outcome = Flow.observe(sent, s)
	assert(resolved == nil and outcome == "Confirmed", "Confirmed accepted job not recognised")
	assert(not Flow.canSend(sent, s, 20, true), "Old target can accept another job")
end
for _, phase in { "Offer", "Unknown" } do
	s.phase = phase
	local _, outcome = Flow.observe(sent, s)
	assert(outcome == "Expired", "Inactive/unknown new context confirmed acceptance")
end
s.phase, s.contractId = "Inspect", "different"
local _, outcome = Flow.observe(sent, s)
assert(outcome == "Expired", "Different contract confirmed acceptance")
s = snapshot()
s.phase, s.jobId = "Completed", "previous"
local nextRequest = Flow.request(s, "basic", true, "request-one")
assert(
	nextRequest and nextRequest.jobId == "previous" and sent.jobId == "",
	"Baselines crossed between players/attempts"
)
assert(not Flow.request(s, "basic", false, "request-one"), "Lost profile started next job")
print(
	"JobAcceptFlow: fixed baseline, explicit retry, unknown/busy, correlated refusals, acceptance proof and isolation passed"
)
