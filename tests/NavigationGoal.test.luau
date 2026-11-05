--!strict
local Goal = require("../src/shared/NavigationGoal")
local function required(value: Goal.Goal?): Goal.Goal
	return assert(value, "Expected a selected navigation goal")
end
local job: Goal.Job = {
	available = true,
	phase = "Inspect",
	jobId = "j1",
	workId = "w1",
	destination = { 0, 3, 72 },
	clientKey = "residentNina",
}
local client = required(Goal.job(job, false))
assert(
	client.kind == "Job"
		and client.labelKey == "residentNina"
		and client.areaKey == "clientApartment",
	"Meeting target wrong"
)
assert(not client.near and client.available and client.key == "j1:w1", "Job identity/status wrong")
job.phase = "Prepare"
assert(
	required(Goal.job(job, true)).labelKey == "workWall" and required(Goal.job(job, true)).near,
	"Preparation did not target wall"
)
job.phase = "Completed"
assert(
	Goal.job(job, true) == nil and Goal.job(nil, false) == nil,
	"Finished/missing job invented goal"
)
job.phase = "Offer"
assert(Goal.job(job, false) == nil, "Unaccepted offer navigated")
local shop = required(Goal.shop(true, { available = true, nearShop = false }, { 32, 3, 2 }))
assert(
	shop.kind == "Shop" and shop.areaKey == "shopTitle" and shop.labelKey == "shopTitle",
	"Shop label wrong"
)
assert(shop.available and not shop.near and shop.key == "shop", "Shop identity/status wrong")
assert(
	Goal.shop(false, { available = true, nearShop = true }, { 32, 3, 2 }) == nil,
	"Cancelled shop retained goal"
)
local waiting = required(Goal.shop(true, nil, { 32, 3, 2 }))
assert(not waiting.available and not waiting.near, "Missing confirmation invented arrival")
local busy = required(Goal.shop(true, { available = false, nearShop = true }, { 32, 3, 2 }))
assert(not busy.available and busy.near, "Busy snapshot became interactive")
local arrived = required(Goal.shop(true, { available = true, nearShop = true }, { 32, 3, 2 }))
assert(arrived.near and arrived.available, "Confirmed arrival missing")
job.phase = "Ready"
assert(
	required(Goal.job(job, false)).kind == "Job"
		and required(Goal.job(job, false)).labelKey == "residentNina",
	"Handover target lost"
)
assert(
	job.workId == "w1" and assert(job.destination, "Job destination lost")[3] == 72,
	"Shop selection changed job"
)
print(
	"NavigationGoal: job phases, shop selection/arrival/unavailable, independent unchanged job passed"
)
