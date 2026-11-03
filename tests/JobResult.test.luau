--!strict
local Profile = require("../src/server/Domain/Profile")
local Economy = require("../src/server/Domain/Economy")
local Result = require("../src/server/Domain/JobResult")
local function completed(owner: number, id: string): Profile.Profile
	local p = Profile.new(owner)
	p.jobs.issuedSequence = 1
	p.jobs.active =
		{ id = id, sequence = 1, templateId = "paint-tutorial-v1", status = "ReadyForInspection" }
	assert(Economy.completeJob(p, id, 100) ~= nil, "Fixture reward failed")
	return p
end
assert(Result.read(Profile.new(1)) == nil, "New profile has a result")
local p = completed(1, "paint-a")
local summary = Result.read(p)
assert(summary ~= nil and summary.dollars == 250 and summary.xp == 50, "Wrong confirmed reward")
assert(summary.jobId == "paint-a" and summary.operationId == "job:paint-a", "Wrong result identity")
local revision = p.revision
p.wallet.dollars = 70
local again = Result.read(p)
assert(again ~= nil and again.dollars == 250 and again.xp == 50, "Result used current balance")
assert(p.wallet.dollars == 70 and p.revision == revision, "Reading result mutated profile")
summary.dollars = 999
assert(again.dollars == 250, "Projection returned shared mutable state")
local other = Result.read(completed(2, "paint-b"))
assert(
	other ~= nil and other.jobId == "paint-b" and again.jobId == "paint-a",
	"Players share result"
)
local job = p.jobs.active
assert(job ~= nil and job.receipt ~= nil, "Receipt missing")
job.status = "Abandoned"
assert(Result.read(p) == nil, "Cancelled job displayed a reward")
job.status = "Accepted"
assert(Result.read(p) == nil, "Pending job displayed a reward")
job.status = "Completed"
job.receipt.kind = "Purchase"
assert(Result.read(p) == nil, "Purchase presented as job result")
job.receipt.kind = "Reward"
job.receipt.subjectId = "different-job"
assert(Result.read(p) == nil, "Mismatched receipt accepted")
job.receipt = nil
assert(Result.read(p) == nil, "Missing receipt accepted")
print("JobResult: 8 confirmed/read-only/isolation/rejection scenarios passed")
