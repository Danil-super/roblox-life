--!strict
local Profile = require("./Profile")
local Economy = require("./Economy")
local Painting = require("./Painting")
local Config = require("./EconomyConfig")
export type Offer = {
	id: string,
	titleKey: string,
	briefKey: string,
	colorId: string,
	requiredXP: number,
	unlocked: boolean,
	reward: number,
	xp: number,
	clientKey: string,
	secondaryColorId: string?,
}
local Jobs = {}
function Jobs.offers(p: Profile.Profile?): { Offer }
	local result: { Offer } = {}
	for id, contract in Config.contracts do
		if contract.offered then
			local reward = Config.rewards[id]
			table.insert(result, {
				id = id,
				titleKey = contract.titleKey,
				briefKey = contract.briefKey,
				colorId = contract.colorId,
				requiredXP = contract.minXP,
				unlocked = p ~= nil and p.progression.paintingXP >= contract.minXP,
				reward = reward.dollars,
				xp = reward.xp,
				clientKey = contract.clientKey,
				secondaryColorId = contract.secondaryColorId,
			})
		end
	end
	table.sort(result, function(a: Offer, b: Offer): boolean
		return if a.requiredXP == b.requiredXP then a.id < b.id else a.requiredXP < b.requiredXP
	end)
	return result
end
function Jobs.accept(p: Profile.Profile, id: string, offerId: string?): boolean
	local old = p.jobs.active
	local templateId = offerId or "paint-tutorial-v1"
	local contract = Config.contracts[templateId]
	if
		not Profile.identifier(id)
		or contract == nil
		or not contract.offered
		or p.progression.paintingXP < contract.minXP
		or #id > 80
		or p.jobs.issuedSequence >= 1000000000
		or (
			old ~= nil
			and (old.id == id or (old.status ~= "Completed" and old.status ~= "Abandoned"))
		)
	then
		return false
	end
	p.jobs.issuedSequence += 1
	p.jobs.active = {
		id = id,
		sequence = p.jobs.issuedSequence,
		templateId = templateId,
		status = "Accepted",
	}
	if p.onboarding.step == "INTRO" or p.onboarding.step == "JOB_LIST" then
		p.onboarding.step = "NAVIGATE"
	end
	p.revision += 1
	return true
end
function Jobs.cancel(p: Profile.Profile, id: string): boolean
	local job = p.jobs.active
	if job == nil or job.id ~= id or job.status == "Completed" then
		return false
	end
	job.status = "Abandoned"
	p.jobs.settledSequence = job.sequence
	p.revision += 1
	return true
end
function Jobs.submit(
	p: Profile.Profile,
	work: Painting.State,
	now: number,
	eligible: boolean
): boolean
	local job = p.jobs.active
	if not eligible or job == nil or job.id ~= work.jobId or job.status == "Abandoned" then
		return false
	end
	if job.status == "Completed" then
		return Economy.completeJob(p, job.id, now) ~= nil
	end
	local contract = Config.contracts[job.templateId]
	local total = if contract and contract.secondaryColorId then 2 else 1
	if not Painting.allReady(work) or Painting.total(work) ~= total then
		return false
	end
	local finish = Painting.finish(work)
	if finish == nil then
		return false
	end
	local old = job.status
	job.status = "ReadyForInspection"
	if Economy.completeJob(p, job.id, now) == nil then
		job.status = old
		return false
	end
	job.finish = finish
	return true
end
return Jobs
