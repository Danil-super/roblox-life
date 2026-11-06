--!strict
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
type Size = { width: number, height: number }
type Summary = {
	sizes: { Size }?,
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
function Result.read(profile: Profile.Profile, geometry: { Size }?): Summary?
	local job = profile.jobs.active
	if job == nil or job.status ~= "Completed" then
		return nil
	end
	local receipt = job.receipt
	if receipt == nil or receipt.kind ~= "Reward" or receipt.subjectId ~= job.id then
		return nil
	end
	local sizes: { Size }? = nil
	if geometry and job.finish and #geometry == #job.finish.masks then
		local valid = true
		local copy: { Size } = {}
		for _, size in geometry do
			if
				not (
					size.width >= 1
					and size.width <= 64
					and size.height >= 1
					and size.height <= 64
				)
			then
				valid = false
				break
			end
			table.insert(copy, { width = size.width, height = size.height })
		end
		if valid then
			sizes = copy
		end
	end
	local contract = Config.contracts[job.templateId]
	return {
		sizes = sizes,
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
