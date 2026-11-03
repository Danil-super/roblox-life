--!strict
-- Pure server rules. Call only on an exclusively owned, validated profile.
-- Persistence must commit the entire resulting profile atomically before acknowledging success.
local Profile = require("./Profile")
local Config = require("./EconomyConfig")
type ProfileData = Profile.Profile
type Receipt = Profile.Receipt
local Economy = {}
local LIMIT = 1000000000

local function record(profile: ProfileData, receipt: Receipt): Receipt
	table.insert(profile.recentOperations, table.clone(receipt))
	if #profile.recentOperations > Config.maxRecentOperations then
		table.remove(profile.recentOperations, 1)
	end
	profile.revision += 1
	return table.clone(receipt)
end

function Economy.completeJob(profile: ProfileData, jobId: string, now: number): (Receipt?, string?)
	if
		not Profile.identifier(jobId)
		or #jobId > 80
		or not Profile.integer(now, 0, 9007199254740991)
	then
		return nil, "InvalidRequest"
	end
	local job = profile.jobs.active
	if job == nil or job.id ~= jobId then
		return nil, "WrongJob"
	end
	if job.status == "Completed" and job.receipt ~= nil then
		return table.clone(job.receipt), nil
	end
	if job.status ~= "ReadyForInspection" or job.sequence <= profile.jobs.settledSequence then
		return nil, "NotReady"
	end
	local reward = Config.rewards[job.templateId]
	if reward == nil then
		return nil, "UnknownTemplate"
	end
	if
		profile.revision >= 9007199254740991
		or profile.wallet.dollars + reward.dollars > Config.maxDollars
		or profile.progression.xp + reward.xp > LIMIT
		or profile.progression.paintingXP + reward.xp > LIMIT
		or profile.progression.reputation + reward.reputation > LIMIT
	then
		return nil, "LimitReached"
	end
	local receipt: Receipt = {
		operationId = "job:" .. jobId,
		kind = "Reward",
		subjectId = jobId,
		dollarsDelta = reward.dollars,
		xpDelta = reward.xp,
		at = now,
	}
	-- No yielding between checks, money and permanent completion proof.
	profile.wallet.dollars += reward.dollars
	profile.progression.xp += reward.xp
	profile.progression.paintingXP += reward.xp
	profile.progression.reputation += reward.reputation
	profile.jobs.completedCount += 1
	profile.jobs.settledSequence = job.sequence
	job.status, job.receipt = "Completed", table.clone(receipt)
	if not profile.onboarding.completed and profile.onboarding.step ~= "PLACE" then
		profile.onboarding.step = "BUY"
	end
	return record(profile, receipt), nil
end

function Economy.purchase(
	profile: ProfileData,
	requestId: string,
	catalogId: string,
	itemInstanceId: string,
	now: number
): (Receipt?, string?)
	if
		not Profile.identifier(requestId)
		or #requestId > 80
		or not Profile.identifier(catalogId)
		or not Profile.identifier(itemInstanceId)
		or not Profile.integer(now, 0, 9007199254740991)
	then
		return nil, "InvalidRequest"
	end
	local operationId = "purchase:" .. requestId
	local count = 0
	for ownedId, item in profile.inventory do
		count += 1
		if item.purchaseOperationId == operationId then
			if item.catalogItemId ~= catalogId then
				return nil, "OperationConflict"
			end
			return {
				operationId = operationId,
				kind = "Purchase",
				subjectId = catalogId,
				dollarsDelta = -item.paidDollars,
				xpDelta = 0,
				itemInstanceId = ownedId,
				at = item.acquiredAt,
			},
				nil
		end
	end
	local product = Config.catalog[catalogId]
	if product == nil then
		return nil, "UnknownProduct"
	end
	if count >= Config.maxItems or profile.inventory[itemInstanceId] ~= nil then
		return nil, "InventoryConflict"
	end
	if profile.revision >= 9007199254740991 then
		return nil, "LimitReached"
	end
	if profile.wallet.dollars < product.dollars then
		return nil, "InsufficientFunds"
	end
	local receipt: Receipt = {
		operationId = operationId,
		kind = "Purchase",
		subjectId = catalogId,
		dollarsDelta = -product.dollars,
		xpDelta = 0,
		itemInstanceId = itemInstanceId,
		at = now,
	}
	profile.wallet.dollars -= product.dollars
	profile.inventory[itemInstanceId] = {
		catalogItemId = catalogId,
		modelVersion = product.modelVersion,
		acquiredAt = now,
		purchaseOperationId = operationId,
		paidDollars = product.dollars,
	}
	if not profile.onboarding.completed then
		profile.onboarding.step = "PLACE"
	end
	return record(profile, receipt), nil
end

return Economy
