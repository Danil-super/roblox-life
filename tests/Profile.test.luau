--!strict
local Profile = require("../src/server/Domain/Profile")
local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print("PASS", name)
end

test("fresh profiles have zero dollars and independent collections", function()
	local first, second = Profile.new(123), Profile.new(456)
	assert(
		first.schemaVersion == 3 and first.wallet.dollars == 0,
		"Expected first.schemaVersion == 3 and first.wallet.dollars == 0"
	)
	assert(
		first.housing.roomTemplateId == "StarterDormTemplate_v1",
		'Expected first.housing.roomTemplateId == "StarterDormTemplate_v1"'
	)
	first.wallet.dollars = 250
	assert(
		second.wallet.dollars == 0 and first.inventory ~= second.inventory,
		"Expected second.wallet.dollars == 0 and first.inventory ~= second.inventory"
	)
	assert(
		first.recentOperations ~= second.recentOperations,
		"Expected first.recentOperations ~= second.recentOperations"
	)
end)

test("decode never replaces missing or invalid data with a usable default", function()
	for _, raw in { false, "broken", 15, {} } do
		local result, reason = Profile.decode(raw, 123)
		assert(result == nil and reason ~= nil, "Expected result == nil and reason ~= nil")
	end
	local missing, reason = Profile.decode(nil, 123)
	assert(
		missing == nil and reason == "Missing",
		'Expected missing == nil and reason == "Missing"'
	)
end)

test("copy and decode preserve data without sharing writable state", function()
	local original = Profile.new(123)
	original.wallet.dollars = 250
	local decoded = Profile.decode(original, 123)
	assert(
		decoded ~= nil and decoded.wallet.dollars == 250,
		"Expected decoded ~= nil and decoded.wallet.dollars == 250"
	)
	decoded.wallet.dollars = 70
	assert(original.wallet.dollars == 250, "Expected original.wallet.dollars == 250")
	local copy = Profile.copy(original)
	copy.progression.paintingXP = 50
	assert(original.progression.paintingXP == 0, "Expected original.progression.paintingXP == 0")
end)

test("mismatching owner and future schema are blocked", function()
	local raw = Profile.new(123)
	assert(Profile.decode(raw, 456) == nil, "Expected Profile.decode(raw, 456) == nil")
	raw.schemaVersion = 999
	local result, reason = Profile.decode(raw, 123)
	assert(
		result == nil and reason == "UnsupportedVersion",
		'Expected result == nil and reason == "UnsupportedVersion"'
	)
end)

test("negative, fractional and non-finite balances are rejected", function()
	for _, amount in { -1, 0.5, math.huge, -math.huge, 0 / 0, 1000000001 } do
		local raw = Profile.new(123)
		raw.wallet.dollars = amount
		assert(Profile.decode(raw, 123) == nil, "Expected Profile.decode(raw, 123) == nil")
	end
end)

test("schema one onboarding migrates without losing dollars or inventory", function()
	local current = Profile.new(123)
	current.wallet.dollars = 250
	local legacy = {
		schemaVersion = 1,
		userId = current.userId,
		revision = current.revision,
		wallet = current.wallet,
		progression = current.progression,
		inventory = current.inventory,
		housing = current.housing,
		jobs = current.jobs,
		recentOperations = current.recentOperations,
		onboarding = { firstPaintJobDone = true, firstFurniturePlaced = false },
	}
	local migrated = Profile.decode(legacy, 123)
	assert(
		migrated ~= nil and migrated.schemaVersion == 3,
		"Expected migrated ~= nil and migrated.schemaVersion == 3"
	)
	assert(
		migrated.wallet.dollars == 250 and migrated.onboarding.step == "BUY",
		'Expected migrated.wallet.dollars == 250 and migrated.onboarding.step == "BUY"'
	)
	assert(not migrated.onboarding.completed, "Expected not migrated.onboarding.completed")
	assert(legacy.schemaVersion == 1, "Expected legacy.schemaVersion == 1")
end)

test("invalid nested placement and unknown fields are rejected", function()
	local raw = Profile.new(123)
	raw.inventory["item-1"] = {
		catalogItemId = "floor-plant-v1",
		modelVersion = 1,
		acquiredAt = 1,
		purchaseOperationId = "purchase:one",
		paidDollars = 180,
	}
	raw.housing.placements["item-1"] =
		{ x = 0 / 0, y = 0, z = 0, rotationY = 0, roomTemplateVersion = 1 }
	assert(Profile.decode(raw, 123) == nil, "Expected Profile.decode(raw, 123) == nil")
	assert(
		Profile.decode({ schemaVersion = 2, userId = 123, injected = function() end }, 123) == nil,
		"Expected Profile.decode({ schemaVersion = 2, userId = 123, injected = function() end }, 123) == nil"
	)
end)

test("decoder ignores table metamethods and rejects sparse receipt arrays", function()
	local raw = Profile.new(123)
	local wrapped = setmetatable(raw, {
		__iter = function(): ()
			error("Untrusted iterator executed")
		end,
		__index = function(): ()
			error("Untrusted field lookup executed")
		end,
	})
	assert(
		Profile.decode(wrapped, 123) ~= nil,
		"Raw profile data must decode without invoking metamethods"
	)
	local entry: Profile.Receipt = {
		operationId = "job:one",
		kind = "Reward",
		subjectId = "one",
		dollarsDelta = 250,
		xpDelta = 50,
		at = 1,
	}
	raw.recentOperations = { [1] = entry, [3] = table.clone(entry), [6] = table.clone(entry) }
	raw.recentOperations[3].operationId = "job:three"
	raw.recentOperations[6].operationId = "job:six"
	assert(
		Profile.decode(raw, 123) == nil,
		"Sparse journals must be rejected regardless of table length"
	)
end)

test("onboarding completion and job counters must be coherent", function()
	local raw = Profile.new(123)
	raw.onboarding.completed = true
	assert(Profile.decode(raw, 123) == nil, "Expected Profile.decode(raw, 123) == nil")
	raw.onboarding.completed = false
	raw.jobs.settledSequence = 10
	assert(Profile.decode(raw, 123) == nil, "Expected Profile.decode(raw, 123) == nil")
end)

test("purchase receipts must agree with permanently owned inventory", function()
	local raw = Profile.new(123)
	raw.wallet.dollars = 1000
	local purchase: Profile.Receipt = {
		operationId = "purchase:one",
		kind = "Purchase",
		subjectId = "floor-plant-v1",
		dollarsDelta = -180,
		xpDelta = 0,
		itemInstanceId = "item-1",
		at = 1,
	}
	raw.recentOperations = { purchase }
	assert(
		Profile.decode(raw, 123) == nil,
		"Missing purchased item must block the profile, not permit a second debit"
	)
	raw.inventory["item-1"] = {
		catalogItemId = "floor-plant-v1",
		modelVersion = 1,
		acquiredAt = 1,
		purchaseOperationId = "purchase:one",
		paidDollars = 180,
	}
	assert(Profile.decode(raw, 123) ~= nil, "Matching purchase proof must load")
	raw.inventory["item-1"].purchaseOperationId, purchase.operationId = "job:one", "job:one"
	assert(
		Profile.decode(raw, 123) == nil,
		"Purchase operation ids must never collide with reward ids"
	)
	raw.inventory["item-1"].purchaseOperationId, purchase.operationId =
		"purchase:one", "purchase:one"
	for _, field in { "catalogItemId", "purchaseOperationId", "paidDollars", "acquiredAt" } do
		local item = raw.inventory["item-1"]
		local original = table.clone(item)
		if field == "catalogItemId" then
			item.catalogItemId = "other"
		elseif field == "purchaseOperationId" then
			item.purchaseOperationId = "purchase:other"
		elseif field == "paidDollars" then
			item.paidDollars = 1
		else
			item.acquiredAt = 2
		end
		assert(
			Profile.decode(raw, 123) == nil,
			"Mismatching purchase proof must be rejected: " .. field
		)
		raw.inventory["item-1"] = original
	end
end)

test("current job cannot disagree with its reward history", function()
	local raw = Profile.new(123)
	local reward: Profile.Receipt = {
		operationId = "job:one",
		kind = "Reward",
		subjectId = "one",
		dollarsDelta = 250,
		xpDelta = 50,
		at = 1,
	}
	raw.jobs.issuedSequence, raw.jobs.settledSequence, raw.jobs.completedCount = 2, 1, 1
	local job: Profile.Job = {
		id = "one",
		sequence = 2,
		templateId = "paint-tutorial-v1",
		status = "ReadyForInspection",
	}
	raw.jobs.active, raw.recentOperations = job, { reward }
	assert(Profile.decode(raw, 123) == nil, "Previously rewarded job id cannot be issued again")
	job.status, job.receipt, raw.jobs.settledSequence = "Completed", table.clone(reward), 2
	assert(Profile.decode(raw, 123) ~= nil, "Matching current completion proof must load")
	local saved = job.receipt
	assert(saved ~= nil, "Fixture must contain receipt")
	saved.dollarsDelta = 251
	assert(Profile.decode(raw, 123) == nil, "Current completion and journal must agree")
end)

print(string.format("%d profile tests passed", passed))
