--!strict
local Flow = require("../src/shared/JobAbandonFlow")
local Types = require("../src/shared/JobTypes")
local function snapshot(): Types.Snapshot
	return {
		available = true,
		phase = "Painting",
		jobId = "job-one",
		workId = "work-one",
		sequence = 5,
		mask = string.rep("1", 40) .. string.rep("0", 56),
		count = 40,
		reward = 250,
		near = true,
	}
end
local s = snapshot()
local question = Flow.request(s, true)
assert(
	question and question.jobId == "job-one" and question.sentAt == nil,
	"Cancel must ask before sending"
)
local pending = Flow.sent(question, s, 10, true)
assert(
	pending and pending.sentAt == 10 and pending.workId == "work-one",
	"Confirmed cancellation intent missing"
)
assert(
	question.sentAt == nil and s.count == 40 and s.phase == "Painting",
	"Confirmation mutated inputs"
)
assert(not Flow.canSend(pending, s, 17.999, true), "Cancellation retried too early")
assert(Flow.canSend(pending, s, 18, true), "Cancellation cannot retry at eight seconds")
local retried = Flow.sent(pending, s, 18, true)
assert(
	retried
		and retried.jobId == pending.jobId
		and retried.workId == pending.workId
		and retried.sentAt == 18,
	"Retry changed the target"
)
assert(not Flow.canSend(pending, s, 18, false), "Lost profile retried")
s.available = false
local held, outcome = Flow.observe(pending, s)
assert(
	held == pending and outcome == "Waiting" and not Flow.canSend(pending, s, 19, true),
	"Unavailable state released cancellation"
)
s.available = true
s.error = "Unavailable"
assert(Flow.observe(pending, s) == pending, "Unknown cancellation outcome released target")
s.phase = "Offer"
s.workId = ""
local resolved, confirmation = Flow.observe(pending, s)
assert(resolved == nil and confirmation == "Confirmed", "Abandoned job receipt was not recognised")
s = snapshot()
s.jobId = "new-job"
assert(not Flow.canSend(pending, s, 20, true), "Old cancellation can abandon another job")
local expired, oldOutcome = Flow.observe(pending, s)
assert(expired == nil and oldOutcome == "Expired", "Changed job retained old cancellation")
s = snapshot()
s.workId = "new-surface"
assert(
	not Flow.canSend(pending, s, 20, true) and Flow.observe(pending, s) == nil,
	"Old work session remained cancellable"
)
s = snapshot()
s.phase = "Completed"
assert(
	Flow.request(s, true) == nil
		and not Flow.canSend(pending, s, 20, true)
		and Flow.observe(pending, s) == nil,
	"Paid work was abandoned"
)
for _, phase in { "Inspect", "Prepare", "ChooseMaterial", "Painting", "SurfaceReady", "Ready" } do
	s = snapshot()
	s.phase = phase
	assert(Flow.request(s, true), "Active phase cannot ask for cancellation")
end
for _, phase in { "Offer", "Completed", "Unknown" } do
	s = snapshot()
	s.phase = phase
	assert(not Flow.request(s, true), "Inactive phase offered cancellation")
end
s = snapshot()
for _, now in { -1, 0 / 0, math.huge } do
	assert(not Flow.canSend(pending, s, now, true), "Invalid clock retried cancellation")
end
assert(
	not Flow.request(s, false) and not Flow.request(nil, true),
	"Unready/missing snapshot allowed cancellation"
)
local other = snapshot()
other.jobId = "other-player"
local isolated = Flow.request(other, true)
assert(
	isolated and isolated.jobId == "other-player" and pending.jobId == "job-one",
	"Cancellation leaked between players"
)
print(
	"JobAbandonFlow: confirmation, exact-target retry, unknown outcome, stale session, boundaries and isolation passed"
)
