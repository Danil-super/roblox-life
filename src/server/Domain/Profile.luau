--!strict
local Config = require("./EconomyConfig")

export type Receipt = {
	operationId: string,
	kind: "Reward" | "Purchase",
	subjectId: string,
	dollarsDelta: number,
	xpDelta: number,
	itemInstanceId: string?,
	at: number,
}
export type Item = {
	catalogItemId: string,
	modelVersion: number,
	acquiredAt: number,
	purchaseOperationId: string,
	paidDollars: number,
}
export type Placement = {
	x: number,
	y: number,
	z: number,
	rotationY: number,
	roomTemplateVersion: number,
}
export type Job = {
	id: string,
	sequence: number,
	templateId: string,
	status: string,
	receipt: Receipt?,
}
export type Profile = {
	schemaVersion: number,
	userId: number,
	revision: number,
	wallet: { dollars: number },
	progression: { xp: number, paintingXP: number, reputation: number },
	inventory: { [string]: Item },
	housing: {
		roomTemplateId: string,
		roomTemplateVersion: number,
		revision: number,
		placements: { [string]: Placement },
	},
	jobs: { issuedSequence: number, settledSequence: number, completedCount: number, active: Job? },
	onboarding: { step: string, completed: boolean },
	recentOperations: { Receipt },
}
type Data = { [string]: unknown }
local Profile = {}
local steps = {
	INTRO = 1,
	JOB_LIST = 2,
	ACCEPT = 3,
	NAVIGATE = 4,
	INSPECT = 5,
	PREPARE = 6,
	PAINT = 7,
	SUBMIT = 8,
	BUY = 9,
	PLACE = 10,
	DONE = 11,
}

function Profile.integer(value: unknown, minimum: number, maximum: number): boolean
	return type(value) == "number"
		and value == value
		and value >= minimum
		and value <= maximum
		and value % 1 == 0
end

function Profile.identifier(value: unknown): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= 96
		and string.match(value, "^[%w_:%-]+$") ~= nil
end

local function purchaseOperation(value: unknown): boolean
	if type(value) ~= "string" or string.sub(value, 1, 9) ~= "purchase:" then
		return false
	end
	local requestId = string.sub(value, 10)
	return #requestId <= 80 and Profile.identifier(requestId)
end

local function asMap(raw: unknown, allowed: { string }?): Data?
	if type(raw) ~= "table" then
		return nil
	end
	local source = raw :: Data
	local data: Data = {}
	local count = 0
	local permitted: { [string]: boolean } = {}
	local keys: { string } = allowed or {}
	for _, key in keys do
		permitted[key] = true
	end
	-- Raw iteration/copy ignores __iter and __index on non-JSON test inputs.
	for key, value in next, source do
		count += 1
		if
			type(key) ~= "string"
			or count > Config.maxItems
			or (allowed ~= nil and not permitted[key])
		then
			return nil
		end
		data[key] = value
	end
	return data
end

local function receipt(raw: unknown): Receipt?
	local r = asMap(
		raw,
		{ "operationId", "kind", "subjectId", "dollarsDelta", "xpDelta", "itemInstanceId", "at" }
	)
	if
		r == nil
		or not Profile.identifier(r.operationId)
		or not Profile.identifier(r.subjectId)
		or (r.kind ~= "Reward" and r.kind ~= "Purchase")
		or not Profile.integer(r.dollarsDelta, -Config.maxDollars, Config.maxDollars)
		or not Profile.integer(r.xpDelta, 0, 1000000000)
		or not Profile.integer(r.at, 0, 9007199254740991)
		or (r.itemInstanceId ~= nil and not Profile.identifier(r.itemInstanceId))
	then
		return nil
	end
	if r.kind == "Reward" then
		if (r.dollarsDelta :: number) < 0 or r.itemInstanceId ~= nil then
			return nil
		end
	elseif (r.dollarsDelta :: number) > 0 or r.xpDelta ~= 0 or r.itemInstanceId == nil then
		return nil
	end
	return {
		operationId = r.operationId :: string,
		kind = r.kind :: "Reward" | "Purchase",
		subjectId = r.subjectId :: string,
		dollarsDelta = r.dollarsDelta :: number,
		xpDelta = r.xpDelta :: number,
		itemInstanceId = r.itemInstanceId :: string?,
		at = r.at :: number,
	}
end

function Profile.new(userId: number): Profile
	assert(Profile.integer(userId, 1, 9007199254740991), "A positive Roblox UserId is required")
	return {
		schemaVersion = 2,
		userId = userId,
		revision = 0,
		wallet = { dollars = 0 },
		progression = { xp = 0, paintingXP = 0, reputation = 0 },
		inventory = {},
		housing = {
			roomTemplateId = "StarterDormTemplate_v1",
			roomTemplateVersion = 1,
			revision = 0,
			placements = {},
		},
		jobs = { issuedSequence = 0, settledSequence = 0, completedCount = 0, active = nil },
		onboarding = { step = "INTRO", completed = false },
		recentOperations = {},
	}
end

function Profile.decode(raw: unknown, userId: number): (Profile?, string?)
	if raw == nil then
		return nil, "Missing"
	end
	local root = asMap(raw, {
		"schemaVersion",
		"userId",
		"revision",
		"wallet",
		"progression",
		"inventory",
		"housing",
		"jobs",
		"onboarding",
		"recentOperations",
	})
	if root == nil then
		return nil, "Corrupt"
	end
	if root.schemaVersion ~= 1 and root.schemaVersion ~= 2 then
		return nil, "UnsupportedVersion"
	end
	if
		root.userId ~= userId
		or not Profile.integer(userId, 1, 9007199254740991)
		or not Profile.integer(root.revision, 0, 9007199254740991)
	then
		return nil, "Corrupt"
	end
	local wallet = asMap(root.wallet, { "dollars" })
	local progression = asMap(root.progression, { "xp", "paintingXP", "reputation" })
	local inventory = asMap(root.inventory, nil)
	local housing =
		asMap(root.housing, { "roomTemplateId", "roomTemplateVersion", "revision", "placements" })
	local jobs =
		asMap(root.jobs, { "issuedSequence", "settledSequence", "completedCount", "active" })
	if
		wallet == nil
		or not Profile.integer(wallet.dollars, 0, Config.maxDollars)
		or progression == nil
		or inventory == nil
		or housing == nil
		or jobs == nil
	then
		return nil, "Corrupt"
	end
	local profile = Profile.new(userId)
	profile.revision, profile.wallet.dollars = root.revision :: number, wallet.dollars :: number
	for _, name in { "xp", "paintingXP", "reputation" } do
		if not Profile.integer(progression[name], 0, 1000000000) then
			return nil, "Corrupt"
		end
	end
	profile.progression = {
		xp = progression.xp :: number,
		paintingXP = progression.paintingXP :: number,
		reputation = progression.reputation :: number,
	}
	local purchaseIds: { [string]: boolean } = {}
	for id, rawItem in inventory do
		local item = asMap(
			rawItem,
			{ "catalogItemId", "modelVersion", "acquiredAt", "purchaseOperationId", "paidDollars" }
		)
		if
			not Profile.identifier(id)
			or item == nil
			or not Profile.identifier(item.catalogItemId)
			or not purchaseOperation(item.purchaseOperationId)
			or not Profile.integer(item.modelVersion, 1, 1000000)
			or not Profile.integer(item.acquiredAt, 0, 9007199254740991)
			or not Profile.integer(item.paidDollars, 0, Config.maxDollars)
		then
			return nil, "Corrupt"
		end
		local operationId = item.purchaseOperationId :: string
		if purchaseIds[operationId] then
			return nil, "Corrupt"
		end
		purchaseIds[operationId] = true
		profile.inventory[id] = {
			catalogItemId = item.catalogItemId :: string,
			modelVersion = item.modelVersion :: number,
			acquiredAt = item.acquiredAt :: number,
			purchaseOperationId = operationId,
			paidDollars = item.paidDollars :: number,
		}
	end
	local placements = asMap(housing.placements, nil)
	if
		placements == nil
		or not Profile.identifier(housing.roomTemplateId)
		or not Profile.integer(housing.roomTemplateVersion, 1, 1000000)
		or not Profile.integer(housing.revision, 0, 9007199254740991)
	then
		return nil, "Corrupt"
	end
	profile.housing.roomTemplateId, profile.housing.roomTemplateVersion =
		housing.roomTemplateId :: string, housing.roomTemplateVersion :: number
	profile.housing.revision = housing.revision :: number
	for id, rawPlacement in placements do
		local p = asMap(rawPlacement, { "x", "y", "z", "rotationY", "roomTemplateVersion" })
		if profile.inventory[id] == nil or p == nil then
			return nil, "Corrupt"
		end
		for _, field in { "x", "y", "z", "rotationY" } do
			local value = p[field]
			if type(value) ~= "number" or value ~= value or math.abs(value) > 10000 then
				return nil, "Corrupt"
			end
		end
		if not Profile.integer(p.roomTemplateVersion, 1, 1000000) then
			return nil, "Corrupt"
		end
		profile.housing.placements[id] = {
			x = p.x :: number,
			y = p.y :: number,
			z = p.z :: number,
			rotationY = p.rotationY :: number,
			roomTemplateVersion = p.roomTemplateVersion :: number,
		}
	end
	for _, field in { "issuedSequence", "settledSequence", "completedCount" } do
		if not Profile.integer(jobs[field], 0, 9007199254740991) then
			return nil, "Corrupt"
		end
	end
	profile.jobs.issuedSequence, profile.jobs.settledSequence =
		jobs.issuedSequence :: number, jobs.settledSequence :: number
	profile.jobs.completedCount = jobs.completedCount :: number
	if
		profile.jobs.settledSequence > profile.jobs.issuedSequence
		or profile.jobs.completedCount > profile.jobs.settledSequence
	then
		return nil, "Corrupt"
	end
	if jobs.active ~= nil then
		local job = asMap(jobs.active, { "id", "sequence", "templateId", "status", "receipt" })
		local statuses = {
			Accepted = true,
			Travelling = true,
			InProgress = true,
			ReadyForInspection = true,
			Completed = true,
			Abandoned = true,
		}
		if
			job == nil
			or not Profile.identifier(job.id)
			or not Profile.identifier(job.templateId)
			or not Profile.integer(job.sequence, 1, profile.jobs.issuedSequence)
			or job.sequence ~= profile.jobs.issuedSequence
			or type(job.status) ~= "string"
			or not statuses[job.status]
		then
			return nil, "Corrupt"
		end
		local jobReceipt = if job.receipt ~= nil then receipt(job.receipt) else nil
		if job.status == "Completed" then
			if
				jobReceipt == nil
				or jobReceipt.kind ~= "Reward"
				or jobReceipt.subjectId ~= job.id
				or jobReceipt.operationId ~= "job:" .. (job.id :: string)
				or profile.jobs.settledSequence ~= job.sequence
			then
				return nil, "Corrupt"
			end
		elseif job.receipt ~= nil then
			return nil, "Corrupt"
		end
		profile.jobs.active = {
			id = job.id :: string,
			sequence = job.sequence :: number,
			templateId = job.templateId :: string,
			status = job.status :: string,
			receipt = jobReceipt,
		}
	end
	local onboarding = asMap(
		root.onboarding,
		if root.schemaVersion == 1
			then { "firstPaintJobDone", "firstFurniturePlaced" }
			else { "step", "completed" }
	)
	if onboarding == nil then
		return nil, "Corrupt"
	end
	if root.schemaVersion == 1 then
		if
			type(onboarding.firstPaintJobDone) ~= "boolean"
			or type(onboarding.firstFurniturePlaced) ~= "boolean"
		then
			return nil, "Corrupt"
		end
		profile.onboarding.step = if onboarding.firstFurniturePlaced
			then "DONE"
			elseif onboarding.firstPaintJobDone then "BUY"
			else "INTRO"
		profile.onboarding.completed = onboarding.firstFurniturePlaced :: boolean
	else
		if
			type(onboarding.step) ~= "string"
			or steps[onboarding.step] == nil
			or type(onboarding.completed) ~= "boolean"
			or onboarding.completed ~= (onboarding.step == "DONE")
		then
			return nil, "Corrupt"
		end
		profile.onboarding =
			{ step = onboarding.step :: string, completed = onboarding.completed :: boolean }
	end
	if type(root.recentOperations) ~= "table" then
		return nil, "Corrupt"
	end
	local recent = root.recentOperations :: { [number]: unknown }
	local count = 0
	local operations: { [string]: boolean } = {}
	for index, rawReceipt in next, recent do
		count += 1
		local r = receipt(rawReceipt)
		if
			count > Config.maxRecentOperations
			or not Profile.integer(index, 1, Config.maxRecentOperations)
			or r == nil
			or operations[r.operationId]
		then
			return nil, "Corrupt"
		end
		if r.kind == "Purchase" then
			local item = if r.itemInstanceId ~= nil
				then profile.inventory[r.itemInstanceId]
				else nil
			if
				item == nil
				or item.purchaseOperationId ~= r.operationId
				or item.catalogItemId ~= r.subjectId
				or item.paidDollars ~= -r.dollarsDelta
				or item.acquiredAt ~= r.at
			then
				return nil, "Corrupt"
			end
		elseif r.operationId ~= "job:" .. r.subjectId then
			return nil, "Corrupt"
		end
		local currentJob = profile.jobs.active
		if r.kind == "Reward" and currentJob ~= nil and currentJob.id == r.subjectId then
			local proof = currentJob.receipt
			if
				currentJob.status ~= "Completed"
				or proof == nil
				or proof.operationId ~= r.operationId
				or proof.dollarsDelta ~= r.dollarsDelta
				or proof.xpDelta ~= r.xpDelta
				or proof.at ~= r.at
			then
				return nil, "Corrupt"
			end
		end
		operations[r.operationId] = true
		profile.recentOperations[index] = r
	end
	for index = 1, count do
		if profile.recentOperations[index] == nil then
			return nil, "Corrupt"
		end
	end
	return profile, nil
end

function Profile.copy(profile: Profile): Profile
	local copy, reason = Profile.decode(profile, profile.userId)
	assert(copy ~= nil, reason or "Invalid profile")
	return copy
end

return table.freeze(Profile)
