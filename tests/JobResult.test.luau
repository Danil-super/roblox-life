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

local shaped = completed(3, "shaped")
local active = assert(shaped.jobs.active, "Fixture missing")
active.finish = { columns = 12, rows = 8, masks = { string.rep("1", 96) } }
local savedFinish = assert(active.finish, "Missing finish")
local geometry = { { width = 16, height = 6 } }
local projected = assert(Result.read(shaped, geometry), "Confirmed geometry result missing")
local sizes = assert(projected.sizes, "Runtime result lost geometry")
geometry[1].width = 8
assert(sizes[1].width == 16, "Result shares runtime geometry")
sizes[1].height = 64
assert(
	geometry[1].height == 6 and savedFinish.masks[1] == string.rep("1", 96),
	"Renderer mutated work/profile"
)
assert(
	assert(Result.read(shaped), "Missing result").sizes == nil,
	"Reload invented historical dimensions"
)
for _, bad in
	{
		{},
		{ { width = 16, height = 6 }, { width = 8, height = 8 } },
		{ { width = 0 / 0, height = 6 } },
		{ { width = 16, height = math.huge } },
	}
do
	assert(
		assert(Result.read(shaped, bad), "Result missing").sizes == nil,
		"Invalid dimensions reached renderer"
	)
end
active.status = "Accepted"
assert(Result.read(shaped, geometry) == nil, "Geometry manufactured a receipt")
print(
	"JobResult: runtime-only copied geometry, reload fallback, bounds and confirmed receipt guard passed"
)
