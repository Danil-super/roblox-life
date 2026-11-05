--!strict
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
export type Pose = { x: number, z: number, rotationY: number }
export type Item = { catalog: string, paid: number, pose: Pose? }
export type Job = {
	id: string,
	template: string,
	status: string,
	receipt: boolean,
	dollars: number,
	xp: number,
}
export type State = {
	revision: number,
	dollars: number,
	xp: number,
	step: string,
	job: Job?,
	items: { [string]: Item },
}
export type Change = { event: string, subject: string?, amount: number?, xp: number? }
export type Batch = {
	revision: number,
	dollarsDelta: number,
	xpDelta: number,
	changes: { Change },
	omitted: number,
}
local Changes = {}
local steps: { [string]: boolean } = {
	INTRO = true,
	JOB_LIST = true,
	ACCEPT = true,
	NAVIGATE = true,
	INSPECT = true,
	PREPARE = true,
	PAINT = true,
	SUBMIT = true,
	BUY = true,
	PLACE = true,
	DONE = true,
}
local function subject(value: string, allowed: { [string]: boolean }): string
	return if allowed[value] then value else "unknown"
end
function Changes.capture(p: Profile.Profile): State
	local items: { [string]: Item } = {}
	for id, item in p.inventory do
		local pose = p.housing.placements[id]
		items[id] = {
			catalog = if Config.catalog[item.catalogItemId] then item.catalogItemId else "unknown",
			paid = item.paidDollars,
			pose = if pose then { x = pose.x, z = pose.z, rotationY = pose.rotationY } else nil,
		}
	end
	local active = p.jobs.active
	local job: Job? = nil
	if active then
		local receipt = active.receipt
		job = {
			id = active.id,
			template = if Config.contracts[active.templateId] then active.templateId else "unknown",
			status = active.status,
			receipt = receipt ~= nil,
			dollars = if receipt then receipt.dollarsDelta else 0,
			xp = if receipt then receipt.xpDelta else 0,
		}
	end
	return {
		revision = p.revision,
		dollars = p.wallet.dollars,
		xp = p.progression.paintingXP,
		step = subject(p.onboarding.step, steps),
		job = job,
		items = items,
	}
end
function Changes.diff(before: State?, after: State): Batch?
	-- Loading/replaying a profile is a baseline, never another transaction.
	if before == nil or after.revision <= before.revision then
		return nil
	end
	local batch: Batch = {
		revision = after.revision,
		dollarsDelta = after.dollars - before.dollars,
		xpDelta = after.xp - before.xp,
		changes = {},
		omitted = 0,
	}
	local function add(change: Change): ()
		if #batch.changes < 8 then
			table.insert(batch.changes, change)
		else
			batch.omitted += 1
		end
	end
	local job, old = after.job, before.job
	if job then
		local same = old ~= nil and old.id == job.id
		if not same and job.status == "Accepted" then
			add({ event = "job_accepted", subject = job.template })
		end
		if
			job.status == "Completed"
			and job.receipt
			and (not same or (old and not old.receipt))
		then
			add({
				event = "job_completed",
				subject = job.template,
				amount = job.dollars,
				xp = job.xp,
			})
		elseif job.status == "Abandoned" and (not same or (old and old.status ~= "Abandoned")) then
			add({ event = "job_abandoned", subject = job.template })
		end
	end
	if before.step ~= after.step then
		add({
			event = if after.step == "DONE" then "onboarding_completed" else "onboarding_step",
			subject = after.step,
		})
	end
	local ids: { string } = {}
	for id in after.items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local item, previous = after.items[id], before.items[id]
		if previous == nil then
			add({ event = "furniture_purchased", subject = item.catalog, amount = item.paid })
		end
		local pose = item.pose
		local prior = if previous then previous.pose else nil
		if pose and not prior then
			add({ event = "furniture_placed", subject = item.catalog })
		elseif prior and not pose then
			add({ event = "furniture_stored", subject = item.catalog })
		elseif
			pose
			and prior
			and (pose.x ~= prior.x or pose.z ~= prior.z or pose.rotationY ~= prior.rotationY)
		then
			add({ event = "furniture_moved", subject = item.catalog })
		end
	end
	return if #batch.changes > 0
			or batch.dollarsDelta ~= 0
			or batch.xpDelta ~= 0
		then batch
		else nil
end
return table.freeze(Changes)
