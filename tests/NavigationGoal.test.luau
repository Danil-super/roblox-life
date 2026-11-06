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
local homeState: Goal.Home =
	{ available = true, nearHome = false, homeName = "Home_1", origin = { 64, 0, 128 } }
local home = required(Goal.home(true, homeState))
assert(
	home.kind == "Home" and home.key == "home:Home_1" and home.roomName == "Home_1",
	"Wrong home identity"
)
assert(
	home.destination[1] == 64 and home.destination[2] == 3 and home.destination[3] == 128,
	"Home target not inside owned room"
)
assert(
	home.labelKey == "home" and home.areaKey == "home" and home.available and not home.near,
	"Home labels/confirmation missing"
)
home.destination[1] = -999
assert(homeState.origin[1] == 64, "Renderer changed confirmed origin")
assert(
	Goal.home(false, homeState) == nil and Goal.home(true, nil) == nil,
	"Missing/cancelled home invented target"
)
homeState.nearHome = true
homeState.available = false
local unavailable = required(Goal.home(true, homeState))
assert(
	unavailable.near and not unavailable.available,
	"Busy home became interactive or invented arrival"
)
homeState.available = true
assert(required(Goal.home(true, homeState)).near, "Confirmed home arrival lost")
homeState.homeName = ""
assert(Goal.home(true, homeState) == nil, "Missing owned room invented goal")
homeState.homeName = "Home_1"
for _, origin in
	{
		{},
		{ 0, 0 },
		{ 0, 0, 0, 0 },
		{ 0 / 0, 0, 0 },
		{ 0, math.huge, 0 },
		{ 0, 0, -math.huge },
		{ 1e6, 0, 0 },
		{ 0, -1e6, 0 },
	}
do
	homeState.origin = origin
	assert(Goal.home(true, homeState) == nil, "Invalid room origin reached pathfinding")
end
local other = required(
	Goal.home(
		true,
		{ available = true, nearHome = false, homeName = "Home_2", origin = { 192, 0, 128 } }
	)
)
assert(
	other.key ~= home.key and other.destination[1] == 192 and job.workId == "w1",
	"Independent home changed job/another goal"
)
print(
	"NavigationGoal: home origin/identity/copy, selection/arrival/unavailable/invalid and independence passed"
)
