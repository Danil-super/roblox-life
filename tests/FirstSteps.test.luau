--!strict
local Guide = require("../src/shared/FirstSteps")
local function facts(phase: string): Guide.Facts
	return { completed = false, paid = false, ownsFurniture = false, phase = phase }
end
local waiting = Guide.evaluate(nil)
assert(
	waiting.status == "Waiting" and waiting.current == nil,
	"Missing profile invented a first step"
)
local expected: { [string]: number } =
	{ Offer = 0, Inspect = 1, Prepare = 2, ChooseMaterial = 2, Painting = 3, Ready = 4 }
for phase, count in expected do
	local p = Guide.evaluate(facts(phase))
	assert(
		p.completed == count and p.total == 7,
		"Runtime phase mapped to wrong progress: " .. phase
	)
	assert(p.current == p.steps[count + 1].id, "Current step does not match incomplete milestone")
end
assert(Guide.evaluate(facts("Offer")).current == "job", "Cancelled work did not restore job choice")
local f = facts("Completed")
f.paid = true
assert(Guide.evaluate(f).current == "buy", "Paid work did not lead to purchase")
f.ownsFurniture = true
assert(Guide.evaluate(f).current == "place", "Owned item did not lead to placement")
f.completed = true
local done = Guide.evaluate(f)
assert(
	done.status == "Done" and done.completed == 7 and done.current == nil,
	"Confirmed completion missing"
)
f.ownsFurniture = false
f.phase = "Inspect"
assert(Guide.evaluate(f).status == "Done", "Replay/storage/new job erased historical completion")
local isolated = Guide.evaluate(facts("Offer"))
isolated.steps[1].titleKey = "tampered"
assert(
	Guide.evaluate(facts("Offer")).steps[1].titleKey ~= "tampered",
	"UI projection mutated definitions"
)
print(
	"FirstSteps: confirmed phases, cancellation, purchase, placement, history and isolation passed"
)
