--!strict
local Profile = require("./Profile")
local Economy = require("./Economy")
local Painting = require("./Painting")
local Jobs = {}
function Jobs.accept(p: Profile.Profile, id: string): boolean
	local old = p.jobs.active
	if
		not Profile.identifier(id)
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
		templateId = "paint-tutorial-v1",
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
	if work.phase ~= "Ready" then
		return false
	end
	local old = job.status
	job.status = "ReadyForInspection"
	if Economy.completeJob(p, job.id, now) == nil then
		job.status = old
		return false
	end
	return true
end
return Jobs
