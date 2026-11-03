--!strict
local Profile = require("../src/server/Domain/Profile")
local Economy = require("../src/server/Domain/Economy")
local passed = 0
local function test(name: string, run: () -> ()): ()
	run()
	passed += 1
	print("PASS", name)
end
local function ready(userId: number): Profile.Profile
	local profile = Profile.new(userId)
	profile.jobs.issuedSequence = 1
	profile.jobs.active = {
		id = "job-1",
		sequence = 1,
		templateId = "paint-tutorial-v1",
		status = "ReadyForInspection",
	}
	return profile
end

test("one accepted completion awards configured dollars and progression", function()
	local profile = ready(1)
	local receipt = Economy.completeJob(profile, "job-1", 100)
	assert(
		receipt ~= nil and receipt.dollarsDelta == 250,
		"Expected receipt ~= nil and receipt.dollarsDelta == 250"
	)
	assert(
		profile.wallet.dollars == 250 and profile.progression.paintingXP == 50,
		"Expected profile.wallet.dollars == 250 and profile.progression.paintingXP == 50"
	)
	assert(
		profile.jobs.completedCount == 1 and profile.jobs.settledSequence == 1,
		"Expected profile.jobs.completedCount == 1 and profile.jobs.settledSequence == 1"
	)
	assert(
		profile.onboarding.step == "BUY" and Profile.decode(profile, 1) ~= nil,
		'Expected profile.onboarding.step == "BUY" and Profile.decode(profile, 1) ~= nil'
	)
	receipt.dollarsDelta = 999
	local duplicate = Economy.completeJob(profile, "job-1", 200)
	assert(
		duplicate ~= nil and duplicate.dollarsDelta == 250 and duplicate.at == 100,
		"Expected duplicate ~= nil and duplicate.dollarsDelta == 250 and duplicate.at == 100"
	)
	assert(
		profile.wallet.dollars == 250 and profile.progression.xp == 50,
		"Expected profile.wallet.dollars == 250 and profile.progression.xp == 50"
	)
end)

test("wrong job, phase, replayed sequence and non-finite timestamp do not pay", function()
	local profile = ready(1)
	assert(
		Economy.completeJob(profile, "other-job", 100) == nil,
		'Expected Economy.completeJob(profile, "other-job", 100) == nil'
	)
	assert(
		Economy.completeJob(profile, "job-1", 0 / 0) == nil,
		'Expected Economy.completeJob(profile, "job-1", 0 / 0) == nil'
	)
	local job = profile.jobs.active
	assert(job ~= nil, "Expected job ~= nil")
	job.status = "InProgress"
	assert(
		Economy.completeJob(profile, "job-1", 100) == nil,
		'Expected Economy.completeJob(profile, "job-1", 100) == nil'
	)
	job.status = "ReadyForInspection"
	profile.jobs.settledSequence = 1
	assert(
		Economy.completeJob(profile, "job-1", 100) == nil,
		'Expected Economy.completeJob(profile, "job-1", 100) == nil'
	)
	assert(
		profile.wallet.dollars == 0 and #profile.recentOperations == 0,
		"Expected profile.wallet.dollars == 0 and #profile.recentOperations == 0"
	)
end)

test("overflow and unknown template leave all state unchanged", function()
	local profile = ready(1)
	profile.wallet.dollars = 999999999
	assert(
		Economy.completeJob(profile, "job-1", 100) == nil,
		'Expected Economy.completeJob(profile, "job-1", 100) == nil'
	)
	assert(
		profile.progression.xp == 0 and profile.jobs.completedCount == 0,
		"Expected profile.progression.xp == 0 and profile.jobs.completedCount == 0"
	)
	local job = profile.jobs.active
	assert(job ~= nil, "Expected job ~= nil")
	job.templateId = "unknown"
	profile.wallet.dollars = 0
	assert(
		Economy.completeJob(profile, "job-1", 100) == nil,
		'Expected Economy.completeJob(profile, "job-1", 100) == nil'
	)
end)

test("purchase uses server price and duplicate request returns same owned instance", function()
	local profile = ready(1)
	assert(
		Economy.completeJob(profile, "job-1", 100) ~= nil,
		'Expected Economy.completeJob(profile, "job-1", 100) ~= nil'
	)
	local receipt = Economy.purchase(profile, "request-1", "floor-plant-v1", "item-1", 101)
	assert(
		receipt ~= nil and receipt.itemInstanceId == "item-1" and receipt.dollarsDelta == -180,
		'Expected receipt ~= nil and receipt.itemInstanceId == "item-1" and receipt.dollarsDelta == -180'
	)
	local duplicate = Economy.purchase(profile, "request-1", "floor-plant-v1", "new-server-id", 200)
	assert(
		duplicate ~= nil and duplicate.itemInstanceId == "item-1" and duplicate.at == 101,
		'Expected duplicate ~= nil and duplicate.itemInstanceId == "item-1" and duplicate.at == 101'
	)
	assert(
		profile.wallet.dollars == 70 and profile.inventory["new-server-id"] == nil,
		'Expected profile.wallet.dollars == 70 and profile.inventory["new-server-id"] == nil'
	)
	assert(
		profile.onboarding.step == "PLACE" and Profile.decode(profile, 1) ~= nil,
		'Expected profile.onboarding.step == "PLACE" and Profile.decode(profile, 1) ~= nil'
	)
end)

test(
	"insufficient funds, bad ids, unknown product and instance collision reject atomically",
	function()
		local profile = Profile.new(1)
		assert(
			Economy.purchase(profile, "one", "floor-plant-v1", "item-1", 1) == nil,
			'Expected Economy.purchase(profile, "one", "floor-plant-v1", "item-1", 1) == nil'
		)
		profile.wallet.dollars = 1000
		assert(
			Economy.purchase(profile, "bad request", "floor-plant-v1", "item-1", 1) == nil,
			'Expected Economy.purchase(profile, "bad request", "floor-plant-v1", "item-1", 1) == nil'
		)
		assert(
			Economy.purchase(profile, "one", "unknown", "item-1", 1) == nil,
			'Expected Economy.purchase(profile, "one", "unknown", "item-1", 1) == nil'
		)
		assert(
			Economy.purchase(profile, "one", "floor-plant-v1", "item-1", math.huge) == nil,
			'Expected Economy.purchase(profile, "one", "floor-plant-v1", "item-1", math.huge) == nil'
		)
		assert(
			profile.wallet.dollars == 1000 and next(profile.inventory) == nil,
			"Expected profile.wallet.dollars == 1000 and next(profile.inventory) == nil"
		)
		assert(
			Economy.purchase(profile, "one", "floor-plant-v1", "item-1", 1) ~= nil,
			'Expected Economy.purchase(profile, "one", "floor-plant-v1", "item-1", 1) ~= nil'
		)
		assert(
			Economy.purchase(profile, "two", "floor-plant-v1", "item-1", 2) == nil,
			'Expected Economy.purchase(profile, "two", "floor-plant-v1", "item-1", 2) == nil'
		)
		assert(
			Economy.purchase(profile, "one", "unknown", "item-2", 2) == nil,
			'Expected Economy.purchase(profile, "one", "unknown", "item-2", 2) == nil'
		)
		assert(
			profile.wallet.dollars == 820 and profile.inventory["item-2"] == nil,
			'Expected profile.wallet.dollars == 820 and profile.inventory["item-2"] == nil'
		)
	end
)

test("bounded receipt journal is not the only replay protection", function()
	local profile = ready(1)
	assert(
		Economy.completeJob(profile, "job-1", 1) ~= nil,
		'Expected Economy.completeJob(profile, "job-1", 1) ~= nil'
	)
	profile.wallet.dollars = 100000
	for i = 1, 70 do
		assert(
			Economy.purchase(profile, "buy-" .. i, "floor-plant-v1", "item-" .. i, i) ~= nil,
			'Expected Economy.purchase(profile, "buy-" .. i, "floor-plant-v1", "item-" .. i, i) ~= nil'
		)
	end
	assert(#profile.recentOperations == 64, "Expected #profile.recentOperations == 64")
	local balance = profile.wallet.dollars
	assert(
		Economy.completeJob(profile, "job-1", 999) ~= nil,
		'Expected Economy.completeJob(profile, "job-1", 999) ~= nil'
	)
	local purchase = Economy.purchase(profile, "buy-1", "floor-plant-v1", "retry-id", 999)
	assert(
		purchase ~= nil and purchase.itemInstanceId == "item-1",
		'Expected purchase ~= nil and purchase.itemInstanceId == "item-1"'
	)
	assert(
		profile.wallet.dollars == balance and profile.jobs.completedCount == 1,
		"Expected profile.wallet.dollars == balance and profile.jobs.completedCount == 1"
	)
	assert(Profile.decode(profile, 1) ~= nil, "Expected Profile.decode(profile, 1) ~= nil")
end)

test("players remain independent and finished onboarding does not regress", function()
	local first, second = ready(1), ready(2)
	first.onboarding.step, first.onboarding.completed = "DONE", true
	assert(
		Economy.completeJob(first, "job-1", 1) ~= nil,
		'Expected Economy.completeJob(first, "job-1", 1) ~= nil'
	)
	assert(
		Economy.purchase(first, "one", "floor-plant-v1", "item-1", 2) ~= nil,
		'Expected Economy.purchase(first, "one", "floor-plant-v1", "item-1", 2) ~= nil'
	)
	assert(
		second.wallet.dollars == 0 and next(second.inventory) == nil,
		"Expected second.wallet.dollars == 0 and next(second.inventory) == nil"
	)
	assert(
		first.onboarding.step == "DONE" and first.onboarding.completed,
		'Expected first.onboarding.step == "DONE" and first.onboarding.completed'
	)
end)

test("inventory and revision limits reject before any debit", function()
	local profile = ready(1)
	profile.wallet.dollars = 1000000
	for i = 1, 256 do
		assert(
			Economy.purchase(profile, "buy-" .. i, "floor-plant-v1", "item-" .. i, i) ~= nil,
			"Purchases up to the inventory limit must succeed"
		)
	end
	local balance = profile.wallet.dollars
	assert(
		Economy.purchase(profile, "overflow", "floor-plant-v1", "extra", 300) == nil,
		"Full inventory must reject"
	)
	assert(
		profile.wallet.dollars == balance and profile.inventory.extra == nil,
		"Rejected purchase must not mutate"
	)
	profile = ready(1)
	profile.wallet.dollars, profile.revision = 500, 9007199254740991
	assert(
		Economy.completeJob(profile, "job-1", 1) == nil,
		"Revision must not overflow during reward"
	)
	assert(
		Economy.purchase(profile, "one", "floor-plant-v1", "item", 1) == nil,
		"Revision must not overflow during purchase"
	)
	assert(
		profile.wallet.dollars == 500 and profile.progression.xp == 0,
		"Overflow must leave state unchanged"
	)
end)

print(string.format("%d economy tests passed", passed))
