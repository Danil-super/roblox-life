--!strict
local Profile = require("./Profile")
type Summary = { jobId: string, operationId: string, dollars: number, xp: number }
local Result = {}
-- Read-only projection of an already confirmed profile, independent of runtime work.
function Result.read(profile: Profile.Profile): Summary?
	local job = profile.jobs.active
	if job == nil or job.status ~= "Completed" then
		return nil
	end
	local receipt = job.receipt
	if receipt == nil or receipt.kind ~= "Reward" or receipt.subjectId ~= job.id then
		return nil
	end
	return {
		jobId = job.id,
		operationId = receipt.operationId,
		dollars = receipt.dollarsDelta,
		xp = receipt.xpDelta,
	}
end
return table.freeze(Result)
