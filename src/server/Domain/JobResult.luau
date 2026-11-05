--!strict
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
type Summary = {
	jobId: string,
	operationId: string,
	dollars: number,
	xp: number,
	primaryColorId: string?,
	secondaryColorId: string?,
	finish: Profile.PaintFinish?,
}
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
	local contract = Config.contracts[job.templateId]
	return {
		finish = if job.finish
			then {
				columns = job.finish.columns,
				rows = job.finish.rows,
				masks = table.clone(job.finish.masks),
			}
			else nil,
		primaryColorId = if contract then contract.colorId else nil,
		secondaryColorId = if contract then contract.secondaryColorId else nil,
		jobId = job.id,
		operationId = receipt.operationId,
		dollars = receipt.dollarsDelta,
		xp = receipt.xpDelta,
	}
end
return table.freeze(Result)
