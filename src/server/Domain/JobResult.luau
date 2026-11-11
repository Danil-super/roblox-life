--!strict
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
local Economy = require("./Economy")
type Size = { width: number, height: number }
type Summary = {
	sizes: { Size }?,
	jobId: string,
	operationId: string,
	dollars: number,
	xp: number,
	baseDollars: number?,
	perfectBonus: number?,
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
	local base = Config.rewards[job.templateId]
	local difference = if base then receipt.dollarsDelta - base.dollars else -1
	local breakdown = base ~= nil
		and (difference == 0 or difference == Economy.perfectTip(job.templateId))
	return {
		baseDollars = if breakdown and base then base.dollars else nil,
		perfectBonus = if breakdown then difference else nil,
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
