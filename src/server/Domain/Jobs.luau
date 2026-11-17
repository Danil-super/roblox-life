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
	perfectBonus: number,
	clientKey: string,
	secondaryColorId: string?,
	needsCleaning: boolean,
}
local Jobs = {}
function Jobs.needsCleaning(templateId: string): boolean
	local contract = Config.contracts[templateId]
	return contract ~= nil and contract.minXP >= 120
end
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
				perfectBonus = Economy.perfectTip(id),
				clientKey = contract.clientKey,
				secondaryColorId = contract.secondaryColorId,
				needsCleaning = Jobs.needsCleaning(id),
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
	job.status, job.checkpoint = "Abandoned", nil
	p.jobs.settledSequence = job.sequence
	p.revision += 1
	return true
end
local function improvesMask(original: string, updated: string): boolean
	if original == updated then
		return false
	end
	for i = 1, #original do
		if original:sub(i, i) == "1" and updated:sub(i, i) ~= "1" then
			return false
		end
	end
	return true
end
function Jobs.checkpoint(p: Profile.Profile, work: Painting.State, now: number): boolean
	local job = p.jobs.active
	if
		job == nil
		or job.id ~= work.jobId
		or job.status == "Completed"
		or job.status == "Abandoned"
	then
		return false
	end
	local contract = Config.contracts[job.templateId]
	if contract == nil or Painting.total(work) ~= (if contract.secondaryColorId then 2 else 1) then
		return false
	end
	local color = if Painting.surface(work) == 2
		then contract.secondaryColorId
		else contract.colorId
	if work.config.colorId ~= color then
		return false
	end
	local saved = Painting.checkpoint(work, now)
	if saved == nil then
		return false
	end
	local previous = job.checkpoint
	local touchUpBase = work.touchUpBase
	if previous and Painting.validCheckpoint(work, previous) then
		local expected = #previous.masks + (if touchUpBase then 0 else 1)
		if #saved.masks ~= expected then
			return false
		end
		for i, mask in previous.masks do
			if touchUpBase and i == expected then
				if touchUpBase ~= mask or not improvesMask(mask, saved.masks[i]) then
					return false
				end
			elseif saved.masks[i] ~= mask then
				return false
			end
		end
	elseif touchUpBase or #saved.masks ~= 1 then
		return false
	end
	job.checkpoint = saved
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
	local perfect = true
	for _, mask in finish.masks do
		perfect = perfect and string.find(mask, "0", 1, true) == nil
	end
	if Economy.completeJob(p, job.id, now, perfect) == nil then
		job.status = old
		return false
	end
	job.finish = finish
	return true
end
return Jobs
