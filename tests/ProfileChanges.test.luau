--!strict
local Changes = require("../src/server/Domain/ProfileChanges")
local Profile = require("../src/server/Domain/Profile")
local Jobs = require("../src/server/Domain/Jobs")
local Economy = require("../src/server/Domain/Economy")
local Furniture = require("../src/server/Domain/Furniture")
local p = Profile.new(12345)
local before = Changes.capture(p)
assert(Changes.diff(nil, before) == nil, "Initial load replayed historical events")
p.revision += 1
assert(Changes.diff(before, Changes.capture(p)) == nil, "Unchanged checkpoint emitted progression")
before = Changes.capture(p)
assert(Jobs.accept(p, "private-job", "paint-tutorial-v1"), "Test accept failed")
local accepted = Changes.diff(before, Changes.capture(p))
assert(accepted and accepted.changes[1].event == "job_accepted", "Confirmed acceptance missing")
local function has(batch: Changes.Batch?, event: string): boolean
	if batch then
		for _, change in batch.changes do
			if change.event == event then
				return true
			end
		end
	end
	return false
end
before = Changes.capture(p)
local job = p.jobs.active
assert(job, "Test job missing")
job.status = "ReadyForInspection"
assert(Economy.completeJob(p, job.id, 100), "Test reward failed")
local paid = Changes.diff(before, Changes.capture(p))
assert(
	paid and paid.dollarsDelta == 250 and paid.xpDelta == 50 and has(paid, "job_completed"),
	"Confirmed reward missing"
)
before = Changes.capture(p)
assert(Economy.completeJob(p, job.id, 101), "Reward replay failed")
assert(Changes.diff(before, Changes.capture(p)) == nil, "Repeated reward logged another payment")
assert(
	Economy.purchase(p, "private-request", "floor-plant-v1", "private-item", 102),
	"Test purchase failed"
)
local bought = Changes.diff(before, Changes.capture(p))
assert(
	bought and bought.dollarsDelta == -180 and has(bought, "furniture_purchased"),
	"Purchase missing"
)
before = Changes.capture(p)
assert(
	Furniture.place(p, "private-item", { x = 8, z = 6, rotationY = 0, mode = "Grid" }, 0),
	"Test placement failed"
)
local installed = Changes.diff(before, Changes.capture(p))
assert(
	has(installed, "furniture_placed") and has(installed, "onboarding_completed"),
	"Installation/onboarding missing"
)
before = Changes.capture(p)
assert(
	Furniture.place(p, "private-item", { x = 9, z = 6, rotationY = 0, mode = "Grid" }, 1),
	"Test move failed"
)
assert(has(Changes.diff(before, Changes.capture(p)), "furniture_moved"), "Movement missing")
assert(
	before.items["private-item"].pose and before.items["private-item"].pose.x == 8,
	"Capture aliased placement"
)
before = Changes.capture(p)
assert(Furniture.store(p, "private-item", 2), "Test store failed")
assert(has(Changes.diff(before, Changes.capture(p)), "furniture_stored"), "Store missing")
before = Changes.capture(p)
assert(Jobs.accept(p, "next-private-job", "paint-mint-v1"), "Second test accept failed")
local newer = Changes.capture(p)
assert(has(Changes.diff(before, newer), "job_accepted"), "Next acceptance missing")
assert(Jobs.cancel(p, "next-private-job"), "Test cancel failed")
assert(has(Changes.diff(newer, Changes.capture(p)), "job_abandoned"), "Cancellation missing")
assert(Changes.diff(Changes.capture(p), before) == nil, "Revision rollback invented events")
local other = Profile.new(67890)
assert(
	Changes.diff(nil, Changes.capture(other)) == nil and other.wallet.dollars == 0,
	"Other player inherited telemetry"
)
local many = Profile.new(55)
local initial = Changes.capture(many)
for i = 1, 20 do
	many.inventory["private-" .. i] = {
		catalogItemId = "floor-plant-v1",
		modelVersion = 1,
		acquiredAt = 0,
		purchaseOperationId = "private-op",
		paidDollars = 180,
	}
end
many.revision += 1
local bounded = Changes.diff(initial, Changes.capture(many))
assert(bounded and #bounded.changes == 8 and bounded.omitted == 12, "Batch is not bounded")
for _, change in bounded.changes do
	assert(
		change.subject == "floor-plant-v1" and change.amount == 180,
		"Batch lost approved catalog/amount"
	)
end
local historical = Changes.capture(many)
assert(Changes.diff(nil, historical) == nil, "Existing inventory replayed on join")
many.inventory["private-1"].catalogItemId = "private-catalog"
many.onboarding.step = "private-step"
many.jobs.active = {
	id = "private-job",
	sequence = 1,
	templateId = "private-template",
	status = "Accepted",
	receipt = nil,
}
local scrubbed = Changes.capture(many)
assert(
	scrubbed.items["private-1"].catalog == "unknown"
		and scrubbed.step == "unknown"
		and scrubbed.job
		and scrubbed.job.template == "unknown",
	"Unapproved subjects escaped allowlist"
)
local noReceipt = Profile.new(56)
local noReceiptBefore = Changes.capture(noReceipt)
noReceipt.jobs.active = {
	id = "private-job",
	sequence = 1,
	templateId = "paint-tutorial-v1",
	status = "Completed",
	receipt = nil,
}
noReceipt.revision += 1
assert(
	not has(Changes.diff(noReceiptBefore, Changes.capture(noReceipt)), "job_completed"),
	"Unreceipted job was logged as paid"
)
print(
	"ProfileChanges: confirmed milestones, deltas, no-op/replay, capture copy, rollback and isolation passed"
)
