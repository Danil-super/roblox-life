--!strict
local Plan = require("../src/shared/JobWorkPlan")
local Types = require("../src/shared/JobTypes")
local function snapshot(phase: string): Types.Snapshot
	return {
		available = true,
		phase = phase,
		jobId = "job-one",
		workId = "work-one",
		sequence = 1,
		mask = "",
		count = 0,
		reward = 250,
		near = false,
	}
end
for current, phase in { "Inspect", "Prepare", "ChooseMaterial", "Painting", "Ready" } do
	local p = Plan.evaluate(snapshot(phase), true)
	assert(p and p.current == current and #p.states == 5, "Wrong current work step")
	for step, state in p.states do
		local expected = if step < current
			then "Done"
			elseif step == current then "Current"
			else "Next"
		assert(state == expected, "Step advanced without confirmed phase")
	end
	assert(p.percent == (if phase == "Painting" then 0 else nil), "Coverage shown outside painting")
end
local s = snapshot("Painting")
for _, count in { 0, 76, 77, 96, math.huge, 0 / 0 } do
	s.count = count
	local p = Plan.evaluate(s, true)
	assert(
		p and p.current == 4 and p.states[4] == "Current" and p.states[5] == "Next",
		"Coverage accepted work"
	)
	assert(
		p.noteKey
			== (if count == 77 or count == 96 then "workPlanReviewHint" else "workPlanPaintHint"),
		"Coverage hint boundary incorrect"
	)
end
s = snapshot("SurfaceReady")
s.surfaceIndex, s.surfaceTotal = 1, 2
local checked = Plan.evaluate(s, true)
assert(
	checked
		and checked.current == 0
		and checked.states[4] == "Done"
		and checked.states[5] == "Next"
		and checked.percent == nil,
	"First wall presented as final handover"
)
s.phase, s.surfaceIndex = "ChooseMaterial", 2
local second = Plan.evaluate(s, true)
assert(
	second and second.current == 3 and second.states[4] == "Next",
	"Next wall retained previous completion"
)
assert(checked.current == 0 and checked.states[4] == "Done", "Projection mutated previous wall")
s.phase = "Ready"
assert(Plan.evaluate(s, true) ~= nil, "Final wall not ready for client")
s.surfaceIndex = 1
assert(Plan.evaluate(s, true) == nil, "Incomplete scope enabled handover")
for _, phase in { "Offer", "Completed", "Unknown" } do
	assert(not Plan.evaluate(snapshot(phase), true), "Inactive job invented work plan")
end
assert(
	not Plan.evaluate(nil, true) and not Plan.evaluate(snapshot("Inspect"), false),
	"Unready plan visible"
)
s = snapshot("Inspect")
s.available = false
assert(not Plan.evaluate(s, true), "Unavailable plan visible")
s.available, s.workId = true, ""
assert(not Plan.evaluate(s, true), "Missing work identity accepted")
s.workId, s.jobId = "work-one", ""
assert(not Plan.evaluate(s, true), "Missing job identity accepted")
s.jobId = "job-one"
for _, index in { 0, -1, 1.5, 3, math.huge, 0 / 0 } do
	s.surfaceIndex, s.surfaceTotal = index, 2
	assert(not Plan.evaluate(s, true), "Invalid wall index accepted")
end
for _, total in { 0, 1.5, 3, math.huge, 0 / 0 } do
	s.surfaceIndex, s.surfaceTotal = 1, total
	assert(not Plan.evaluate(s, true), "Unsupported scope accepted")
end
s = snapshot("SurfaceReady")
assert(not Plan.evaluate(s, true), "Single wall invented next surface")
local playerOne, playerTwo = snapshot("Painting"), snapshot("Inspect")
playerOne.count = 96
local one, two = Plan.evaluate(playerOne, true), Plan.evaluate(playerTwo, true)
assert(
	one and two and one.current == 4 and two.current == 1 and one.states ~= two.states,
	"Players shared plan state"
)
print(
	"JobWorkPlan: confirmed steps, coverage boundaries, two-wall transition, invalid state and isolation passed"
)
